import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synchronized/synchronized.dart';
import 'package:tdlib/td_api.dart' as td;
import 'tdlib_service.dart';
import '../core/logger.dart';

final streamingProxyServiceProvider = Provider<StreamingProxyService>((ref) {
  final tdlibService = ref.watch(tdlibServiceProvider);
  final proxy = StreamingProxyService(tdlibService);
  proxy.start();
  ref.onDispose(() {
    proxy.stop();
  });
  return proxy;
});

class StreamingProxyService {
  final TdlibService _tdlibService;
  HttpServer? _server;
  int _port = 0;
  final Completer<void> _startCompleter = Completer<void>();

  final _stateLock = Lock();
  final String _authToken = base64Url.encode(List<int>.generate(32, (i) => Random.secure().nextInt(256)));
  int _nextReqId = 0;

  Future<void> get onReady => _startCompleter.future;

  // Track active download offset state per fileId
  final Map<int, int> _activeDownloadOffsets = {};
  final Map<int, int> _downloadedSizeAtOffsets = {};
  final Map<int, td.File> _fileStates = {};

  // Track active HTTP request offsets per fileId to prevent prefetch thrashing
  final Map<int, Map<int, int>> _activeRequestOffsets = {};

  // Track last active timestamp of read/write per fileId and request offset to classify idle connections
  final Map<int, Map<int, DateTime>> _requestLastActive = {};

  int getActiveDownloadOffset(int fileId) => _activeDownloadOffsets[fileId] ?? 0;
  int getDownloadedSizeAtOffset(int fileId) => _downloadedSizeAtOffsets[fileId] ?? 0;

  bool isRangeDownloaded(int fileId, int start, int end) {
    final tdFile = _fileStates[fileId];
    if (tdFile == null) return false;
    if (tdFile.local.isDownloadingCompleted) return true;

    final prefixSize = tdFile.local.downloadedPrefixSize;
    if (end <= prefixSize) return true;

    final activeOffset = _activeDownloadOffsets[fileId] ?? 0;
    final baseDownloaded = _downloadedSizeAtOffsets[fileId] ?? 0;
    final downloadedDelta = tdFile.local.downloadedSize - baseDownloaded;
    final activeRangeEnd = activeOffset + (downloadedDelta > 0 ? downloadedDelta : tdFile.local.downloadedSize);

    if (start >= activeOffset && end <= activeRangeEnd) return true;

    return false;
  }

  StreamingProxyService(this._tdlibService) {
    _tdlibService.updates.listen((event) {
      if (event is td.UpdateFile) {
        _fileStates[event.file.id] = event.file;
      }
    });
  }

  Future<void> start() async {
    try {
      _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _port = _server!.port;
      Log.i('Local HTTP Streaming Proxy started on port $_port');
      _server!.listen(_handleRequest, onError: (e) {
        Log.e('HTTP Proxy server error', e);
      });
      if (!_startCompleter.isCompleted) {
        _startCompleter.complete();
      }
    } catch (e, stack) {
      Log.e('Failed to start HTTP Proxy server', e, stack);
      if (!_startCompleter.isCompleted) {
        _startCompleter.completeError(e, stack);
      }
    }
  }

  void setDownloadOffset(int fileId, int offset, int currentDownloadedSize) {
    _activeDownloadOffsets[fileId] = offset;
    _downloadedSizeAtOffsets[fileId] = currentDownloadedSize;
    Log.i('Proxy updated offset for file $fileId: offset=$offset, baseDownloadedSize=$currentDownloadedSize');
  }

  String getProxyUrl(int fileId, {String? fileName}) {
    final q = fileName != null && fileName.isNotEmpty
        ? 'fileId=$fileId&name=${Uri.encodeComponent(fileName)}'
        : 'fileId=$fileId';
    return 'http://127.0.0.1:$_port/stream?$q&token=$_authToken';
  }

  td.File? getCachedFile(int fileId) => _fileStates[fileId];

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    Log.i('Local HTTP Streaming Proxy stopped');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.uri.path != '/stream') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      if (request.uri.queryParameters['token'] != _authToken) {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }

    final fileIdStr = request.uri.queryParameters['fileId'];
    if (fileIdStr == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final fileId = int.tryParse(fileIdStr);
    if (fileId == null) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    // Retrieve file info from TDLib
    td.File? tdFile;
    try {
      final res = await _tdlibService.sendAsync(td.GetFile(fileId: fileId));
      if (res is td.File) {
        tdFile = res;
      }
    } catch (e) {
      Log.e('Proxy failed to get file info for fileId=$fileId', e);
    }

    if (tdFile == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final totalSize = tdFile.expectedSize;
    if (totalSize <= 0) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    // Parse Range Header
    final rangeHeader = request.headers.value(HttpHeaders.rangeHeader);
    int start = 0;
    int end = totalSize - 1;

    if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
      final parts = rangeHeader.substring(6).split('-');
      if (parts.isNotEmpty) {
        final parsedStart = int.tryParse(parts[0]);
        if (parsedStart != null && parsedStart >= 0 && parsedStart < totalSize) start = parsedStart;
        if (parts.length > 1 && parts[1].isNotEmpty) {
          final parsedEnd = int.tryParse(parts[1]);
          if (parsedEnd != null && parsedEnd >= start && parsedEnd < totalSize) end = parsedEnd;
        }
      }
    }

    final reqId = _nextReqId++;
    await _stateLock.synchronized(() {
      _activeRequestOffsets.putIfAbsent(fileId, () => {})[reqId] = start;
      _requestLastActive.putIfAbsent(fileId, () => {})[reqId] = DateTime.now();
    });

    try {
      // Auto-detect and shift TDLib download offset if the requested range is outside our current download buffer
      try {
        final res = await _tdlibService.sendAsync(td.GetFile(fileId: fileId));
        if (res is td.File) {
          final isCompleted = res.local.isDownloadingCompleted;
          final prefixSize = res.local.downloadedPrefixSize;
          final activeOffset = _activeDownloadOffsets[fileId] ?? 0;
          final baseDownloaded = _downloadedSizeAtOffsets[fileId] ?? 0;
          final downloadedDelta = (res.local.downloadedSize - baseDownloaded).clamp(0, res.expectedSize);
          final activeRangeEnd = activeOffset + downloadedDelta;

          const graceBuffer = 1 * 1024 * 1024;
          const forwardThreshold = 3 * 1024 * 1024;

          final isOutBefore = start < activeOffset;
          final isOutAfter = start > activeRangeEnd + forwardThreshold;

          final now = DateTime.now();
          bool hasEarlierRequest = false;
          await _stateLock.synchronized(() {
            final activeRequests = _activeRequestOffsets[fileId] ?? {};
            final lastActiveMap = _requestLastActive[fileId] ?? {};
            hasEarlierRequest = activeRequests.entries.any((entry) {
              if (entry.key == reqId) return false;
              if (entry.value >= start) return false;
              final lastActive = lastActiveMap[entry.key];
              if (lastActive == null) return true;
              return now.difference(lastActive).inMilliseconds < 800;
            });
          });

          final isTailQuery = res.expectedSize > 20 * 1024 * 1024 &&
              start >= res.expectedSize - 15 * 1024 * 1024;

          if (!isCompleted &&
              start >= prefixSize &&
              (isOutBefore || (isOutAfter && (!hasEarlierRequest || isTailQuery)))) {
            final shiftOffset = (start - graceBuffer).clamp(0, res.expectedSize);
            
            Log.i('Proxy auto-shifting TDLib download offset for file $fileId to $shiftOffset (requested range: $start-$end, prefixSize: $prefixSize, activeOffset: $activeOffset, activeRangeEnd: $activeRangeEnd)');
            
            setDownloadOffset(fileId, shiftOffset, res.local.downloadedSize);
            
            _tdlibService.send(td.DownloadFile(
              fileId: fileId,
              priority: 1,
              offset: shiftOffset,
              limit: 0,
              synchronous: false,
            ));
          }
        }
      } catch (e) {
        Log.w('Proxy failed to check or auto-shift download offset: $e');
      }

      // Set response headers
      request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');
      
      final queryName = request.uri.queryParameters['name'];
      ContentType contentType = ContentType('video', 'mp4'); // Default fallback mime
      final localPath = tdFile.local.path.toLowerCase();
      final targetName = (queryName ?? '').toLowerCase();
      
      if (localPath.endsWith('.mkv') || targetName.endsWith('.mkv')) {
        contentType = ContentType('video', 'x-matroska');
      } else if (localPath.endsWith('.webm') || targetName.endsWith('.webm')) {
        contentType = ContentType('video', 'webm');
      } else if (localPath.endsWith('.avi') || targetName.endsWith('.avi')) {
        contentType = ContentType('video', 'x-msvideo');
      } else if (localPath.endsWith('.mov') || targetName.endsWith('.mov')) {
        contentType = ContentType('video', 'quicktime');
      } else if (localPath.endsWith('.flv') || targetName.endsWith('.flv')) {
        contentType = ContentType('video', 'x-flv');
      } else if (localPath.endsWith('.m4v') || targetName.endsWith('.m4v')) {
        contentType = ContentType('video', 'x-m4v');
      } else if (localPath.endsWith('.3gp') || targetName.endsWith('.3gp')) {
        contentType = ContentType('video', '3gpp');
      }
      request.response.headers.contentType = contentType;

      if (rangeHeader != null) {
        request.response.statusCode = HttpStatus.partialContent;
        request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$totalSize');
      } else {
        request.response.statusCode = HttpStatus.ok;
      }

      final responseLength = (end - start + 1).clamp(0, totalSize);
      request.response.headers.contentLength = responseLength;

      // OPTIMIZATION 1: If file is fully completed on disk, stream it directly using native piping
      if (tdFile.local.isDownloadingCompleted) {
        final file = File(tdFile.local.path);
        if (await file.exists()) {
          try {
            await request.response.addStream(file.openRead(start, end + 1));
          } catch (e) {
            Log.w('Proxy direct completed streaming error for file $fileId: $e');
          } finally {
            try {
              await request.response.close();
            } catch (_) {}
          }
          return;
        }
      }

      // OPTIMIZATION 2: If the file is still downloading, open a single RandomAccessFile session
      RandomAccessFile? raf;
      try {
        String filePath = tdFile.local.path;
        if (filePath.isEmpty || !await File(filePath).exists()) {
          // Wait up to 10 seconds (100 attempts * 100ms) for the file path to resolve and the file to be created on disk by TDLib
          int fileWaitAttempts = 0;
          while (fileWaitAttempts < 100 && (filePath.isEmpty || !await File(filePath).exists())) {
            await Future.delayed(const Duration(milliseconds: 100));
            try {
              final res = await _tdlibService.sendAsync(td.GetFile(fileId: fileId));
              if (res is td.File) {
                _fileStates[fileId] = res;
                filePath = res.local.path;
              }
            } catch (_) {}
            fileWaitAttempts++;
          }
        }

        final file = File(filePath);
        if (!await file.exists()) {
          Log.e('Proxy error: local file does not exist after waiting: $filePath');
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          return;
        }

        raf = await file.open(mode: FileMode.read);
        int sentBytes = 0;
        int currentOffset = start;

        // Cache file state to avoid excessive TDLib JSON IPC calls
        td.File currentFile = _fileStates[fileId] ?? tdFile;

        while (sentBytes < responseLength) {
          final chunkNeeded = (responseLength - sentBytes).clamp(0, 131072); // Optimize chunk sizes to 128 KB for smooth streaming on 2.4GHz WiFi / mobile data
          if (chunkNeeded <= 0) break;

          final targetEndOffset = currentOffset + chunkNeeded;

          // Check if targetEndOffset is already available in our cached file info
          bool isAvailable = false;
          int activeOffset = _activeDownloadOffsets[fileId] ?? 0;
          int baseDownloaded = _downloadedSizeAtOffsets[fileId] ?? 0;

          // Update currentFile from memory cache if available
          if (_fileStates[fileId] != null) {
            currentFile = _fileStates[fileId]!;
          }

          // Global check: if the chunk lies entirely within the contiguous downloaded prefix, it is definitely available
          if (currentFile.local.downloadedPrefixSize >= targetEndOffset) {
            isAvailable = true;
          } else if (currentOffset >= activeOffset) {
            // Check active download delta
            final downloadedDelta = currentFile.local.downloadedSize - baseDownloaded;
            final availableRangeEnd = activeOffset + (downloadedDelta > 0 ? downloadedDelta : currentFile.local.downloadedSize);
            if (targetEndOffset <= availableRangeEnd) {
              isAvailable = true;
            }
          }

          List<int>? preReadBytes;
          // REMOVED: Unsafe zero-byte check that causes video corruption. We now rely strictly on TDLib's reported downloaded bounds.

          // If not ready, wait event-driven without polling TDLib
          if (!isAvailable) {
            // Check if we need to shift the active download because currentOffset is out of bounds
            if (!currentFile.local.isDownloadingCompleted) {
              final now = DateTime.now();
              bool hasEarlierRequest = false;
              await _stateLock.synchronized(() {
                final activeRequests = _activeRequestOffsets[fileId] ?? {};
                final lastActiveMap = _requestLastActive[fileId] ?? {};
                hasEarlierRequest = activeRequests.entries.any((entry) {
                  if (entry.key == reqId) return false;
                  if (entry.value >= currentOffset) return false;
                  final lastActive = lastActiveMap[entry.key];
                  if (lastActive == null) return true;
                  return now.difference(lastActive).inMilliseconds < 800;
                });
              });

              final isTailQuery = currentFile.expectedSize > 20 * 1024 * 1024 &&
                  currentOffset >= currentFile.expectedSize - 15 * 1024 * 1024;

              final isOutBefore = currentOffset < activeOffset;
              final downloadedDelta = (currentFile.local.downloadedSize - baseDownloaded).clamp(0, currentFile.expectedSize);
              final activeRangeEnd = activeOffset + downloadedDelta;
              final isOutAfter = currentOffset > activeRangeEnd + 3 * 1024 * 1024;

              if (isOutBefore || (isOutAfter && (!hasEarlierRequest || isTailQuery))) {
                final shiftOffset = (currentOffset - 1 * 1024 * 1024).clamp(0, currentFile.expectedSize);
                Log.i('Proxy loop auto-shifting TDLib download for file $fileId to $shiftOffset (currentOffset: $currentOffset, activeOffset: $activeOffset, activeRangeEnd: $activeRangeEnd)');
                
                final currentDownloaded = currentFile.local.downloadedSize;
                setDownloadOffset(fileId, shiftOffset, currentDownloaded);
                
                _tdlibService.send(td.DownloadFile(
                  fileId: fileId,
                  priority: 1,
                  offset: shiftOffset,
                  limit: 0,
                  synchronous: false,
                ));
                
                activeOffset = shiftOffset;
                baseDownloaded = currentDownloaded;
              }
            }

            bool waitSuccess = false;
            bool clientDisconnected = false;

            // Listen to client disconnect to abort waiting instantly and release resources
            request.response.done.then((_) {
              clientDisconnected = true;
            });

            // Resilient retry loop: single long-lived subscription
            bool available = false;
            StreamSubscription<td.TdObject>? fileSub;
            final availableCompleter = Completer<void>();

            fileSub = _tdlibService.updates.listen((event) {
              if (event is td.UpdateFile && event.file.id == fileId) {
                currentFile = event.file;
                _fileStates[fileId] = event.file; // Update cache

                bool checkAvailable = false;
                if (event.file.local.downloadedPrefixSize >= targetEndOffset) {
                  checkAvailable = true;
                } else if (currentOffset >= activeOffset) {
                  final downloadedDelta = event.file.local.downloadedSize - baseDownloaded;
                  final availableRangeEnd = activeOffset + (downloadedDelta > 0 ? downloadedDelta : event.file.local.downloadedSize);
                  if (targetEndOffset <= availableRangeEnd) {
                    checkAvailable = true;
                  }
                }

                if (checkAvailable) {
                  if (!availableCompleter.isCompleted) {
                    availableCompleter.complete();
                  }
                }
              }
            });

            try {
              // Wait up to 20 seconds, checking client disconnect status via done future separately
              await Future.any([
                availableCompleter.future,
                request.response.done, // Abort if client disconnects
              ]).timeout(const Duration(seconds: 20));

              if (!clientDisconnected) {
                available = true;
                waitSuccess = true;
              }
            } on TimeoutException {
              if (!currentFile.local.isDownloadingCompleted && !clientDisconnected) {
                Log.w('Streaming proxy: re-triggering DownloadFile for file $fileId at offset $activeOffset (waiting for $currentOffset)');
                _tdlibService.send(td.DownloadFile(
                  fileId: fileId,
                  priority: 1,
                  offset: activeOffset,
                  limit: 0,
                  synchronous: false,
                ));
              }
            } finally {
              await fileSub.cancel();
            }

            if (clientDisconnected) {
              Log.i('Proxy: client disconnected while waiting for bytes for file $fileId.');
              break;
            }

            if (!waitSuccess) {
              Log.w('Proxy timed out waiting for bytes ($currentOffset to $targetEndOffset) for file $fileId');
              break;
            }
          }

          // Read and write chunk using persistent RandomAccessFile or reuse pre-read bytes
          final List<int> bytes;
          if (preReadBytes != null) {
            bytes = preReadBytes;
            preReadBytes = null;
          } else {
            await raf.setPosition(currentOffset);
            bytes = await raf.read(chunkNeeded);
          }
          if (bytes.isEmpty) break;

          request.response.add(bytes);
          await request.response.flush();
          
          await _stateLock.synchronized(() {
            final lastActiveMap = _requestLastActive[fileId];
            if (lastActiveMap != null) {
              lastActiveMap[reqId] = DateTime.now();
            }
          });

          sentBytes += bytes.length;
          currentOffset += bytes.length;
        }
      } catch (e) {
        Log.w('Proxy streaming connection terminated: $e');
      } finally {
        if (raf != null) {
          try {
            await raf.close();
          } catch (_) {}
        }
        try {
          await request.response.close();
        } catch (_) {}
      }
    } finally {
      await _stateLock.synchronized(() {
        final activeRequests = _activeRequestOffsets[fileId];
        if (activeRequests != null) {
          activeRequests.remove(reqId);
          if (activeRequests.isEmpty) {
            _activeRequestOffsets.remove(fileId);
          }
        }
        
        final lastActiveMap = _requestLastActive[fileId];
        if (lastActiveMap != null) {
          lastActiveMap.remove(reqId);
          if (lastActiveMap.isEmpty) {
            _requestLastActive.remove(fileId);
          }
        }
      });
    }
    } catch (e, stack) {
      Log.e('Proxy unhandled exception in request handler', e, stack);
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }
}
