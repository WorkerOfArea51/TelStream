import 'dart:async';
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tdlib/td_api.dart' as td;
import 'tdlib_service.dart';
import '../core/logger.dart';

final streamingProxyServiceProvider = Provider<StreamingProxyService>((ref) {
  final tdlibService = ref.watch(tdlibServiceProvider);
  final proxy = StreamingProxyService(tdlibService);
  proxy.start();
  return proxy;
});

class StreamingProxyService {
  final TdlibService _tdlibService;
  HttpServer? _server;
  int _port = 0;

  // Track active download offset state per fileId
  final Map<int, int> _activeDownloadOffsets = {};
  final Map<int, int> _downloadedSizeAtOffsets = {};
  final Map<int, td.File> _fileStates = {};

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
    } catch (e, stack) {
      Log.e('Failed to start HTTP Proxy server', e, stack);
    }
  }

  void setDownloadOffset(int fileId, int offset, int currentDownloadedSize) {
    _activeDownloadOffsets[fileId] = offset;
    _downloadedSizeAtOffsets[fileId] = currentDownloadedSize;
    Log.i('Proxy updated offset for file $fileId: offset=$offset, baseDownloadedSize=$currentDownloadedSize');
  }

  String getProxyUrl(int fileId) {
    return 'http://127.0.0.1:$_port/stream?fileId=$fileId';
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    Log.i('Local HTTP Streaming Proxy stopped');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (request.uri.path != '/stream') {
      request.response.statusCode = HttpStatus.notFound;
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
        start = int.tryParse(parts[0]) ?? 0;
        if (parts.length > 1 && parts[1].isNotEmpty) {
          end = int.tryParse(parts[1]) ?? end;
        }
      }
    }

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

        const graceBuffer = 5 * 1024 * 1024; // 5 MB lookbehind buffer to prevent seek/track-switch thrashing
        const forwardThreshold = 12 * 1024 * 1024; // 12 MB forward lookahead gap

        if (!isCompleted &&
            start > prefixSize &&
            (start < activeOffset || start > activeRangeEnd + forwardThreshold)) {
          final shiftOffset = (start - graceBuffer).clamp(0, res.expectedSize);
          
          Log.i('Proxy auto-shifting TDLib download offset for file $fileId to $shiftOffset (requested range: $start-$end, prefixSize: $prefixSize, activeOffset: $activeOffset, activeRangeEnd: $activeRangeEnd)');
          
          _tdlibService.send(td.CancelDownloadFile(
            fileId: fileId,
            onlyIfPending: false,
          ));
          
          setDownloadOffset(fileId, shiftOffset, res.local.downloadedSize);
          
          _tdlibService.send(td.DownloadFile(
            fileId: fileId,
            priority: 32,
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
    request.response.headers.contentType = ContentType('video', 'mp4'); // Default fallback mime

    if (rangeHeader != null) {
      request.response.statusCode = HttpStatus.partialContent;
      request.response.headers.set(HttpHeaders.contentRangeHeader, 'bytes $start-$end/$totalSize');
    } else {
      request.response.statusCode = HttpStatus.ok;
    }

    final responseLength = end - start + 1;
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
      final file = File(tdFile.local.path);
      if (!await file.exists()) {
        // Wait up to 1 second for the file to be created on disk by TDLib
        int fileWaitAttempts = 0;
        while (fileWaitAttempts < 10 && !await file.exists()) {
          await Future.delayed(const Duration(milliseconds: 100));
          fileWaitAttempts++;
        }
      }

      if (!await file.exists()) {
        Log.e('Proxy error: local file does not exist after waiting: ${file.path}');
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
        final chunkNeeded = (responseLength - sentBytes).clamp(0, 524288);
        if (chunkNeeded <= 0) break;

        final targetEndOffset = currentOffset + chunkNeeded;

        // Check if targetEndOffset is already available in our cached file info
        bool isAvailable = false;
        final activeOffset = _activeDownloadOffsets[fileId] ?? 0;
        final baseDownloaded = _downloadedSizeAtOffsets[fileId] ?? 0;

        // Update currentFile from memory cache if available
        if (_fileStates[fileId] != null) {
          currentFile = _fileStates[fileId]!;
        }

        if (currentOffset < activeOffset) {
          if (currentFile.local.downloadedPrefixSize >= targetEndOffset) {
            isAvailable = true;
          }
        } else {
          final downloadedDelta = currentFile.local.downloadedSize - baseDownloaded;
          final availableRangeEnd = activeOffset + downloadedDelta;
          if (targetEndOffset <= availableRangeEnd) {
            isAvailable = true;
          }
        }

        // If not ready, wait event-driven without polling TDLib
        if (!isAvailable) {
          final completer = Completer<void>();
          bool waitSuccess = false;

          final sub = _tdlibService.updates.listen((event) {
            if (event is td.UpdateFile && event.file.id == fileId) {
              currentFile = event.file;
              _fileStates[fileId] = event.file; // Update cache

              bool available = false;
              if (currentOffset < activeOffset) {
                if (event.file.local.downloadedPrefixSize >= targetEndOffset) {
                  available = true;
                }
              } else {
                final downloadedDelta = event.file.local.downloadedSize - baseDownloaded;
                final availableRangeEnd = activeOffset + downloadedDelta;
                if (targetEndOffset <= availableRangeEnd) {
                  available = true;
                }
              }

              if (available && !completer.isCompleted) {
                waitSuccess = true;
                completer.complete();
              }
            }
          });

          try {
            await completer.future.timeout(const Duration(seconds: 20));
          } catch (_) {
            // Timeout
          } finally {
            await sub.cancel();
          }

          if (!waitSuccess) {
            Log.w('Proxy timed out waiting for bytes ($currentOffset to $targetEndOffset) for file $fileId');
            break;
          }
        }

        // Read and write chunk using persistent RandomAccessFile
        await raf.setPosition(currentOffset);
        final bytes = await raf.read(chunkNeeded);
        if (bytes.isEmpty) break;

        request.response.add(bytes);
        await request.response.flush();
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
  }
}
