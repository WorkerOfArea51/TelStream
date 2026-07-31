import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:synchronized/synchronized.dart';
import 'package:tdlib/td_api.dart' as td;
import 'tdlib_service.dart';
import '../core/logger.dart';

class StreamingProxyNotifier extends AsyncNotifier<StreamingProxyService> {
  @override
  Future<StreamingProxyService> build() async {
    final tdlibService = ref.watch(tdlibServiceProvider);
    final proxy = StreamingProxyService(tdlibService);
    
    ref.onDispose(() {
      proxy.stop();
    });

    try {
      await proxy.start();
    } catch (e, st) {
      Log.e('Failed to start StreamingProxyService', e, st);
      rethrow;
    }
    
    return proxy;
  }
}

final streamingProxyServiceProvider = AsyncNotifierProvider<StreamingProxyNotifier, StreamingProxyService>(
  StreamingProxyNotifier.new,
);

class StreamingProxyService {
  final TdlibService _tdlibService;
  HttpServer? _server;
  int _port = 0;
  Completer<void>? _startCompleter;
  StreamSubscription<td.TdObject>? _updatesSub;
  static final int _chunkSize =
      (Platform.isWindows || Platform.isLinux || Platform.isMacOS)
      ? 1024 * 1024
      : 128 * 1024;

  final _stateLock = Lock();
  static final String _authToken = base64Url.encode(
    List<int>.generate(32, (i) => Random.secure().nextInt(256)),
  );
  int _nextReqId = 0;
  InternetAddress _boundAddress = InternetAddress.loopbackIPv4;

  static bool isProxyUrl(String url) {
    return url.startsWith('http://127.0.0.1:') || url.startsWith('http://[::1]:');
  }

  Future<void> get onReady => _startCompleter!.future;

  // Track active download offset state per fileId
  final Map<int, int> _activeDownloadOffsets = {};
  final Map<int, int> _downloadedSizeAtOffsets = {};
  final Map<int, td.File> _fileStates = <int, td.File>{};
  static const int _maxFileStateEntries = 32;

  void _cacheFileState(int fileId, td.File file) {
    _fileStates.remove(fileId);
    _fileStates[fileId] = file;
    if (_fileStates.length > _maxFileStateEntries) {
      _fileStates.remove(_fileStates.keys.first);
    }
  }

  // Track active HTTP request offsets per fileId to prevent prefetch thrashing
  final Map<int, Map<int, int>> _activeRequestOffsets = {};

  // Track last active timestamp of read/write per fileId and request offset to classify idle connections
  final Map<int, Map<int, DateTime>> _requestLastActive = {};

  final Map<int, List<Completer<void>>> _abortCompleters = {};

  int getActiveDownloadOffset(int fileId) =>
      _activeDownloadOffsets[fileId] ?? 0;
  int getDownloadedSizeAtOffset(int fileId) =>
      _downloadedSizeAtOffsets[fileId] ?? 0;

  bool isRangeDownloaded(int fileId, int start, int end) {
    final tdFile = _fileStates[fileId];
    if (tdFile == null) return false;
    if (tdFile.local.isDownloadingCompleted) return true;

    final prefixSize = tdFile.local.downloadedPrefixSize;
    if (end <= prefixSize) return true;

    final activeOffset = _activeDownloadOffsets[fileId] ?? 0;
    final baseDownloaded = _downloadedSizeAtOffsets[fileId] ?? 0;
    final downloadedDelta = (tdFile.local.downloadedSize - baseDownloaded)
        .clamp(0, tdFile.expectedSize);
    final activeRangeEnd = activeOffset + downloadedDelta;

    if (start >= activeOffset && end <= activeRangeEnd) return true;

    return false;
  }

  StreamingProxyService(this._tdlibService);

  int get port => _port;

  Future<void> start() async {
    if (_server != null) return;
    _startCompleter = Completer<void>();
    try {
      _server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        0,
        shared: false,
      );
      _port = _server!.port;
      _boundAddress = _server!.address;
      Log.i('Local HTTP Streaming Proxy started on port $_port');

      _updatesSub = _tdlibService.updates.listen((event) {
        if (event is td.UpdateFile) {
          _cacheFileState(event.file.id, event.file);
        }
      });

      _startCompleter!.complete();
      _server!.listen(_handleRequest, onError: (e, st) {
        Log.e('Proxy server error', e, st);
      });
    } catch (e, st) {
      Log.e('Failed to start proxy server', e, st);
      if (!_startCompleter!.isCompleted) {
        _startCompleter!.completeError(e, st);
      }
      rethrow;
    }
  }

  String getProxyUrl(int fileId, {String? fileName}) {
    final name = fileName != null
        ? '?fileId=$fileId&name=${Uri.encodeComponent(fileName)}'
        : '?fileId=$fileId';
    return 'http://${_boundAddress.host}:$_port/stream$name';
  }

  Map<String, String> getAuthHeaders() => {
    'Authorization': 'Bearer $_authToken',
  };

  td.File? getCachedFile(int fileId) => _fileStates[fileId];

  void setDownloadOffset(int fileId, int offset, int downloadedSizeAtOffset) {
    _activeDownloadOffsets[fileId] = offset;
    _downloadedSizeAtOffsets[fileId] = downloadedSizeAtOffset;
  }

  void abortActiveRequests(int fileId) {
    final list = _abortCompleters.remove(fileId);
    if (list != null) {
      for (final c in list) {
        if (!c.isCompleted) c.complete();
      }
    }
  }

  Future<void> stop() async {
    await _updatesSub?.cancel();
    _updatesSub = null;
    await _server?.close(force: true);
    _server = null;
    for (final list in _abortCompleters.values) {
      for (final c in list) {
        if (!c.isCompleted) c.complete();
      }
    }
    _abortCompleters.clear();
_fileStates.clear();
    _activeDownloadOffsets.clear();
    _downloadedSizeAtOffsets.clear();
    _activeRequestOffsets.clear();
    _requestLastActive.clear();
    Log.i('Local HTTP Streaming Proxy stopped');
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.uri.path != '/stream') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      if (request.headers.value('Authorization') != 'Bearer $_authToken') {
        request.response.statusCode = HttpStatus.unauthorized;
        await request.response.close();
        return;
      }

      final fileIdStr = request.uri.queryParameters['fileId'];
      final fileId = int.tryParse(fileIdStr ?? '');
      if (fileId == null) {
        request.response.statusCode = HttpStatus.badRequest;
        await request.response.close();
        return;
      }

      final rangeHeader = request.headers.value('Range');
      int start = 0;
      int? end;
      if (rangeHeader != null && rangeHeader.startsWith('bytes=')) {
        final rangePart = rangeHeader.substring(6);
        final parts = rangePart.split('-');
        start = int.tryParse(parts[0]) ?? 0;
        if (parts.length > 1 && parts[1].isNotEmpty) {
          end = int.tryParse(parts[1]);
        }
      }

      final reqId = _nextReqId++;
      await _stateLock.synchronized(() {
        _activeRequestOffsets.putIfAbsent(fileId, () => {});
        _activeRequestOffsets[fileId]![reqId] = start;
        _requestLastActive.putIfAbsent(fileId, () => {});
        _requestLastActive[fileId]![reqId] = DateTime.now();
      });

      final abortCompleter = Completer<void>();
      _abortCompleters.putIfAbsent(fileId, () => []).add(abortCompleter);

      try {
        // Auto-detect and shift TDLib download offset if the requested range is outside our current download buffer
        try {
          final res = await fetchFile();
          if (res != null) {
            _cacheFileState(fileId, res);

            final prefixSize = res.local.downloadedPrefixSize;
            final activeOffset = _activeDownloadOffsets[fileId] ?? 0;
            final baseDownloaded = _downloadedSizeAtOffsets[fileId] ?? 0;
            final downloadedDelta = (res.local.downloadedSize - baseDownloaded)
                .clamp(0, res.expectedSize);
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
                (isOutBefore ||
                    (isOutAfter && (!hasEarlierRequest || isTailQuery)))) {
              final shiftOffset = (start - graceBuffer).clamp(
                0,
                res.expectedSize,
              );

              Log.i(
                'Proxy auto-shifting TDLib download offset for file $fileId to $shiftOffset (requested range: $start-$end, prefixSize: $prefixSize, activeOffset: $activeOffset, activeRangeEnd: $activeRangeEnd)',
              );

              setDownloadOffset(fileId, shiftOffset, res.local.downloadedSize);

              _tdlibService.send(
                td.DownloadFile(
                  fileId: fileId,
                  priority: 1,
                  offset: shiftOffset,
                  limit: 0,
                  synchronous: false,
                ),
              );
            }
          }
        } catch (e) {
          Log.e('Error during auto-shift check: $e');
        }

        await _serveRange(
          request: request,
          fileId: fileId,
          reqId: reqId,
          start: start,
          end: end,
          abortCompleter: abortCompleter,
        );
      } finally {
        await _stateLock.synchronized(() {
          _activeRequestOffsets[fileId]?.remove(reqId);
          _requestLastActive[fileId]?.remove(reqId);
        });
        final list = _abortCompleters[fileId];
        if (list != null) {
          list.remove(abortCompleter);
        }
      }
    } catch (e, st) {
      Log.e('Proxy _handleRequest error', e, st);
      try {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      } catch (_) {}
    }
  }

  bool get isCompleted => false;

  Future<td.File?> fetchFile() async {
    try {
      final res = await _tdlibService.sendAsync(
        td.GetFile(fileId: 0),
      );
      if (res is td.File) return res;
    } catch (_) {}
    return null;
  }

  Future<void> _serveRange({
    required HttpRequest request,
    required int fileId,
    required int reqId,
    required int start,
    required int? end,
    required Completer<void> abortCompleter,
  }) async {
    td.File? tdFile = _fileStates[fileId];

    if (tdFile == null) {
      try {
        final res = await _tdlibService.sendAsync(td.GetFile(fileId: fileId));
        if (res is td.File) {
          tdFile = res;
          _cacheFileState(fileId, res);
        }
      } catch (e) {
        Log.e('Proxy: Failed to fetch file $fileId from TDLib', e);
      }
    }

    if (tdFile == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }

    final totalSize = tdFile.expectedSize;
    if (end == null || end >= totalSize) {
      end = totalSize - 1;
    }

    if (start >= totalSize) {
      request.response.statusCode = HttpStatus.requestedRangeNotSatisfiable;
      request.response.headers.add('Content-Range', 'bytes */$totalSize');
      await request.response.close();
      return;
    }

    final mimeType = _guessMimeType(tdFile);
    final contentLength = end - start + 1;

    request.response.statusCode = HttpStatus.partialContent;
    request.response.headers.add('Content-Type', mimeType);
    request.response.headers.add('Content-Length', contentLength);
    request.response.headers.add('Content-Range', 'bytes $start-$end/$totalSize');
    request.response.headers.add('Accept-Ranges', 'bytes');

    // Check if the range is already fully downloaded
    bool isAvailable = false;
    final prefixSize = tdFile.local.downloadedPrefixSize;
    if (tdFile.local.isDownloadingCompleted) {
      isAvailable = true;
    } else if (end < prefixSize) {
      isAvailable = true;
    } else {
      final activeOffset = _activeDownloadOffsets[fileId] ?? 0;
      final baseDownloaded = _downloadedSizeAtOffsets[fileId] ?? 0;
      final downloadedDelta = (tdFile.local.downloadedSize - baseDownloaded)
          .clamp(0, tdFile.expectedSize);
      final activeRangeEnd = activeOffset + downloadedDelta;
      if (start >= activeOffset && end < activeRangeEnd) {
        isAvailable = true;
      }
    }

    if (isAvailable) {
      await _serveFromDisk(
        request: request,
        tdFile: tdFile,
        start: start,
        end: end,
        fileId: fileId,
        reqId: reqId,
        abortCompleter: abortCompleter,
      );
    } else {
      await _serveWithWait(
        request: request,
        tdFile: tdFile,
        start: start,
        end: end,
        fileId: fileId,
        reqId: reqId,
        abortCompleter: abortCompleter,
      );
    }
  }

  String _guessMimeType(td.File tdFile) {
    final ext = tdFile.local.path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp4':
        return 'video/mp4';
      case 'mkv':
        return 'video/x-matroska';
      case 'webm':
        return 'video/webm';
      case 'avi':
        return 'video/x-msvideo';
      default:
        return 'video/mp4';
    }
  }

  Future<void> _serveFromDisk({
    required HttpRequest request,
    required td.File tdFile,
    required int start,
    required int end,
    required int fileId,
    required int reqId,
    required Completer<void> abortCompleter,
  }) async {
    if (tdFile.local.path.isEmpty) {
      await _serveWithWait(
        request: request,
        tdFile: tdFile,
        start: start,
        end: end,
        fileId: fileId,
        reqId: reqId,
        abortCompleter: abortCompleter,
      );
      return;
    }

    final file = File(tdFile.local.path);
    if (!await file.exists()) {
      await _serveWithWait(
        request: request,
        tdFile: tdFile,
        start: start,
        end: end,
        fileId: fileId,
        reqId: reqId,
        abortCompleter: abortCompleter,
      );
      return;
    }

    try {
      final raf = await file.open(mode: FileMode.read);
      await raf.setPosition(start);

      final totalToSend = end - start + 1;
      var sent = 0;

      try {
        while (sent < totalToSend && !abortCompleter.isCompleted) {
          final remaining = totalToSend - sent;
          final toRead = remaining < _chunkSize ? remaining : _chunkSize;
          final data = await raf.read(toRead);

          if (data.isEmpty) break;

          await _stateLock.synchronized(() {
            _requestLastActive.putIfAbsent(fileId, () => {});
            _requestLastActive[fileId]![reqId] = DateTime.now();
          });

          request.response.add(data);
          sent += data.length;
        }
      } finally {
        await raf.close();
      }

      await request.response.flush();
      await request.response.close();
    } catch (e, st) {
      Log.e('Proxy _serveFromDisk error for file $fileId', e, st);
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<void> _serveWithWait({
    required HttpRequest request,
    required td.File tdFile,
    required int start,
    required int end,
    required int fileId,
    required int reqId,
    required Completer<void> abortCompleter,
  }) async {
    // Wait for the requested range to become available
    var currentFile = tdFile;
    var currentOffset = start;

    while (currentOffset <= end && !abortCompleter.isCompleted) {
      bool isAvailable = false;

      if (currentFile.local.isDownloadingCompleted) {
        isAvailable = true;
      } else {
        final prefixSize = currentFile.local.downloadedPrefixSize;
        if (currentOffset < prefixSize) {
          isAvailable = true;
        } else {
          final activeOffset = _activeDownloadOffsets[fileId] ?? 0;
          final baseDownloaded = _downloadedSizeAtOffsets[fileId] ?? 0;
          final downloadedDelta =
              (currentFile.local.downloadedSize - baseDownloaded)
                  .clamp(0, currentFile.expectedSize);
          final activeRangeEnd = activeOffset + downloadedDelta;
          if (currentOffset >= activeOffset && currentOffset < activeRangeEnd) {
            isAvailable = true;
          }
        }
      }

      if (!isAvailable) {
        // DISABLED: This continuous monitoring loop fights with mpv's simultaneous
        // requests for different byte ranges (start for playback, end for MOOV atom),
        // causing an infinite shift loop and ANR. The per-request shift above
        // (around line 342) is sufficient and only runs when mpv actually requests data.
        /*
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

        final isTailQuery =
            currentFile.expectedSize > 20 * 1024 * 1024 &&
            currentOffset >=
                currentFile.expectedSize - 15 * 1024 * 1024;

        final isOutBefore = currentOffset < activeOffset;
        final downloadedDelta =
            (currentFile.local.downloadedSize - baseDownloaded).clamp(
              0,
              currentFile.expectedSize,
            );
        final activeRangeEnd = activeOffset + downloadedDelta;
        final isOutAfter =
            currentOffset > activeRangeEnd + 3 * 1024 * 1024;
        if (isOutBefore ||
            (isOutAfter && (!hasEarlierRequest || isTailQuery))) {
          final shiftOffset = (currentOffset - 1 * 1024 * 1024).clamp(
            0,
            currentFile.expectedSize,
          );
          Log.i(
            'Proxy loop auto-shifting TDLib download for file $fileId to $shiftOffset (currentOffset: $currentOffset, activeOffset: $activeOffset, activeRangeEnd: $activeRangeEnd)',
          );

          final currentDownloaded = currentFile.local.downloadedSize;
          setDownloadOffset(fileId, shiftOffset, currentDownloaded);

          _tdlibService.send(
            td.DownloadFile(
              fileId: fileId,
              priority: 1,
              offset: shiftOffset,
              limit: 0,
              synchronous: false,
            ),
          );

          activeOffset = shiftOffset;
          baseDownloaded = currentDownloaded;
        }
        */

        bool waitSuccess = false;
        final availableCompleter = Completer<void>();

        final sub = _tdlibService.updates.listen((event) {
          if (event is td.UpdateFile && event.file.id == fileId) {
            currentFile = event.file;
            _cacheFileState(fileId, event.file);

            if (event.file.local.isDownloadingCompleted) {
              if (!availableCompleter.isCompleted) {
                availableCompleter.complete();
              }
              return;
            }

            final prefixSize = event.file.local.downloadedPrefixSize;
            if (currentOffset < prefixSize) {
              if (!availableCompleter.isCompleted) {
                availableCompleter.complete();
              }
              return;
            }

            final activeOffset = _activeDownloadOffsets[fileId] ?? 0;
            final baseDownloaded = _downloadedSizeAtOffsets[fileId] ?? 0;
            final downloadedDelta =
                (event.file.local.downloadedSize - baseDownloaded)
                    .clamp(0, event.file.expectedSize);
            final activeRangeEnd = activeOffset + downloadedDelta;
            if (currentOffset >= activeOffset &&
                currentOffset < activeRangeEnd) {
              if (!availableCompleter.isCompleted) {
                availableCompleter.complete();
              }
            }
          }
        });

        // Re-trigger download if needed
        _tdlibService.send(
          td.DownloadFile(
            fileId: fileId,
            priority: 1,
            offset: currentOffset,
            limit: 0,
            synchronous: false,
          ),
        );

        try {
          await availableCompleter.future.timeout(
            const Duration(seconds: 20),
            onTimeout: () {
              Log.w('Proxy timed out waiting for file $fileId at offset $currentOffset — re-triggering download');
            },
          );
          waitSuccess = true;
        } catch (e) {
          Log.e('Proxy wait error for file $fileId: $e');
        } finally {
          await sub.cancel();
        }

        if (!waitSuccess && !abortCompleter.isCompleted) {
          // Try re-sending download request
          _tdlibService.send(
            td.DownloadFile(
              fileId: fileId,
              priority: 1,
              offset: currentOffset,
              limit: 0,
              synchronous: false,
            ),
          );
          await Future.delayed(const Duration(milliseconds: 500));
        }
        continue;
      }

      // Serve available data
      if (currentFile.local.path.isEmpty) {
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      final file = File(currentFile.local.path);
      if (!await file.exists()) {
        await Future.delayed(const Duration(milliseconds: 100));
        continue;
      }

      try {
        final raf = await file.open(mode: FileMode.read);
        await raf.setPosition(currentOffset);

        final remaining = end - currentOffset + 1;
        final toRead = remaining < _chunkSize ? remaining : _chunkSize;
        final data = await raf.read(toRead);
        await raf.close();

        if (data.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 100));
          continue;
        }

        await _stateLock.synchronized(() {
          _requestLastActive.putIfAbsent(fileId, () => {});
          _requestLastActive[fileId]![reqId] = DateTime.now();
        });

        request.response.add(data);
        await request.response.flush();

        currentOffset += data.length;
      } catch (e, st) {
        Log.e('Proxy _serveWithWait read error for file $fileId', e, st);
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    try {
      await request.response.flush();
      await request.response.close();
    } catch (_) {}
  }
}