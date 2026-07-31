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

  // ---------------------------------------------------------------------------
  // Per-file state maps
  // ---------------------------------------------------------------------------

  /// Latest known td.File state per fileId (updated by UpdateFile listener).
  final Map<int, td.File> _fileStates = {};

  /// Active TDLib download offset per fileId. Set by setDownloadOffset() and
  /// by the auto-shift logic in _handleRequest().
  final Map<int, int> _activeDownloadOffsets = {};

  /// downloadedSize value at the moment setDownloadOffset() was called. Used to
  /// compute the "delta" of bytes downloaded since the offset was set, which
  /// gives us the available range [activeOffset, activeOffset + delta).
  final Map<int, int> _downloadedSizeAtOffsets = {};

  /// Active HTTP request offsets per fileId. Used by the auto-shift logic to
  /// detect concurrent requests for different byte ranges.
  final Map<int, Map<int, int>> _activeRequestOffsets = {};

  /// Last-active timestamps per (fileId, reqId). Used to determine if an
  /// earlier request is still actively reading or has stalled.
  final Map<int, Map<int, DateTime>> _requestLastActive = {};

  /// Completers that, when completed, abort all active HTTP requests for the
  /// given fileId. Used by abortActiveRequests() to free the MPV reader thread
  /// when the user seeks.
  final Map<int, List<Completer<void>>> _abortCompleters = {};

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  int getActiveDownloadOffset(int fileId) => _activeDownloadOffsets[fileId] ?? 0;

  int getDownloadedSizeAtOffset(int fileId) =>
      _downloadedSizeAtOffsets[fileId] ?? 0;

  void _cacheFileState(int fileId, td.File file) {
    _fileStates[fileId] = file;
  }

  /// Returns true if the byte range [start, end] is already downloaded and
  /// available for reading. This is the case when:
  ///   - The file is fully downloaded (prefix covers the whole range), OR
  ///   - The range is within the active download window.
  bool isRangeDownloaded(int fileId, int start, int end) {
    final file = _fileStates[fileId];
    if (file == null) return false;

    if (file.local.isDownloadingCompleted) return true;

    final prefixSize = file.local.downloadedPrefixSize;
    if (end < prefixSize) return true;

    final activeOffset = _activeDownloadOffsets[fileId] ?? 0;
    final baseDownloaded = _downloadedSizeAtOffsets[fileId] ?? 0;
    final downloadedDelta = (file.local.downloadedSize - baseDownloaded).clamp(
      0,
      file.expectedSize,
    );
    final activeRangeEnd = activeOffset + downloadedDelta;

    if (start >= activeOffset && end <= activeRangeEnd) return true;

    return false;
  }

  void abortActiveRequests(int fileId) {
    final completers = _abortCompleters[fileId];
    if (completers != null) {
      Log.i('Proxy: Aborting ${completers.length} active requests for file $fileId to free mpv thread');
      for (final c in completers) {
        if (!c.isCompleted) c.complete();
      }
      completers.clear();
    }
  }

  StreamingProxyService(this._tdlibService) {
    _updatesSub = _tdlibService.updates.listen((event) {
      if (event is td.UpdateFile) {
        _cacheFileState(event.file.id, event.file);
      }
    });
  }

  Future<void> start() async {
    if (_startCompleter != null && !_startCompleter!.isCompleted) {
      return _startCompleter!.future;
    }
    if (_server != null) return; // Already running

    _startCompleter = Completer<void>();
    try {
      try {
        _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        _boundAddress = InternetAddress.loopbackIPv4;
      } catch (e) {
        _server = await HttpServer.bind(InternetAddress.loopbackIPv6, 0);
        _boundAddress = InternetAddress.loopbackIPv6;
      }
      _server!.autoCompress = false;
      _server!.idleTimeout = const Duration(seconds: 30);
      _port = _server!.port;
      Log.i('Local HTTP Streaming Proxy started on port $_port');
      _server!.listen(
        _handleRequest,
        onError: (e) {
          Log.e('HTTP Proxy server error', e);
        },
      );
      if (!_startCompleter!.isCompleted) {
        _startCompleter!.complete();
      }
    } catch (e, stack) {
      _port = -1;
      Log.e('Failed to start HTTP Proxy server', e, stack);
      if (!_startCompleter!.isCompleted) {
        _startCompleter!.completeError(e, stack);
      }
    }
  }

  void setDownloadOffset(int fileId, int offset, int currentDownloadedSize) {
    _activeDownloadOffsets[fileId] = offset;
    _downloadedSizeAtOffsets[fileId] = currentDownloadedSize;
    Log.i(
      'Proxy updated offset for file $fileId: offset=$offset, baseDownloadedSize=$currentDownloadedSize',
    );
  }

  String getProxyUrl(int fileId, {String? fileName}) {
    if (_port <= 0) {
      throw StateError(
        'Streaming proxy is not running (port=$_port). Cannot serve fileId=$fileId.',
      );
    }
    final q = fileName != null && fileName.isNotEmpty
        ? 'fileId=$fileId&name=${Uri.encodeComponent(fileName)}'
        : 'fileId=$fileId';
    final host = _boundAddress == InternetAddress.loopbackIPv6 ? '[::1]' : '127.0.0.1';
    return 'http://$host:$_port/stream?$q';
  }

  Map<String, String> getAuthHeaders() => {
        'Authorization': 'Bearer $_authToken',
      };

  td.File? getCachedFile(int fileId) => _fileStates[fileId];

  Future<void> stop() async {
    await _updatesSub?.cancel();
    _updatesSub = null;
    await _server?.close(force: true);
    _server = null;

    for (final completers in _abortCompleters.values) {
      for (final c in completers) {
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

  // ---------------------------------------------------------------------------
  // HTTP request handler
  // ---------------------------------------------------------------------------

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.uri.path != '/stream') {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      bool constantTimeEquals(String a, String b) {
        if (a.length != b.length) return false;
        final aBytes = utf8.encode(a);
        final bBytes = utf8.encode(b);
        var diff = 0;
        for (var i = 0; i < aBytes.length; i++) {
          diff |= aBytes[i] ^ bBytes[i];
        }
        return diff == 0;
      }

      final authHeader = request.headers.value('Authorization');
      if (!constantTimeEquals(authHeader ?? '', 'Bearer $_authToken')) {
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
      DateTime? lastFetchTime;

      Future<td.File?> fetchFile() async {
        if (tdFile != null) {
          if (tdFile!.local.isDownloadingCompleted) return tdFile;
          if (lastFetchTime != null &&
              DateTime.now().difference(lastFetchTime!) <
                  const Duration(seconds: 2)) {
            return tdFile;
          }
        }
        try {
          final res = await _tdlibService.sendAsync(td.GetFile(fileId: fileId));
          if (res is td.File) {
            tdFile = res;
            _cacheFileState(fileId, res);
            lastFetchTime = DateTime.now();
          }
        } catch (e) {
          Log.e('Proxy failed to get file info for fileId=$fileId', e);
        }
        return tdFile;
      }

      await fetchFile();

      if (tdFile == null) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }

      final totalSize = tdFile!.expectedSize;
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
          if (parsedStart != null &&
              parsedStart >= 0 &&
              parsedStart < totalSize) {
            start = parsedStart;
          }
          if (parts.length > 1 && parts[1].isNotEmpty) {
            final parsedEnd = int.tryParse(parts[1]);
            if (parsedEnd != null &&
                parsedEnd >= start &&
                parsedEnd < totalSize) {
              end = parsedEnd;
            }
          }
        }
      }

      final reqId = _nextReqId++;
      await _stateLock.synchronized(() {
        _activeRequestOffsets.putIfAbsent(fileId, () => {})[reqId] = start;
        _requestLastActive.putIfAbsent(fileId, () => {})[reqId] =
            DateTime.now();
      });

      final abortCompleter = Completer<void>();
      _abortCompleters.putIfAbsent(fileId, () => []).add(abortCompleter);

      try {
        // ----------------------------------------------------------------------
        // AUTO-SHIFT LOGIC (v2.13.6 — REWRITTEN)
        //
        // Old v17 logic had a critical bug: when no download was active for the
        // file (activeOffset=0, baseDownloaded=0, prefixSize=0), the conditions
        // `isOutBefore = start < activeOffset` and `isOutAfter = start > activeRangeEnd + 3MB`
        // were BOTH false, so no download was triggered. The proxy just waited
        // for bytes that would never arrive (until the 20s timeout kicked in).
        //
        // This caused metadata extraction to fail/timeout for files that hadn't
        // been opened in the player yet — quality badges stayed as "..." forever.
        //
        // New logic: if the requested range is NOT within the downloaded prefix
        // AND NOT within the active download window, trigger a TDLib download at
        // the requested offset. This covers:
        //   1. No active download at all (metadata extraction path)
        //   2. Request is before the active download window (user rewound)
        //   3. Request is far ahead of the active download window (user skipped)
        // ----------------------------------------------------------------------
        try {
          final res = await fetchFile();
          if (res != null) {
            final isCompleted = res.local.isDownloadingCompleted;
            final prefixSize = res.local.downloadedPrefixSize;
            final activeOffset = _activeDownloadOffsets[fileId] ?? 0;
            final baseDownloaded = _downloadedSizeAtOffsets[fileId] ?? 0;
            final downloadedDelta = (res.local.downloadedSize - baseDownloaded)
                .clamp(0, res.expectedSize);
            final activeRangeEnd = activeOffset + downloadedDelta;

            const graceBuffer = 1 * 1024 * 1024;
            const forwardThreshold = 3 * 1024 * 1024;

            // Is the requested start within the already-downloaded prefix?
            final isWithinPrefix = start < prefixSize;
            // Is the requested start within the active download window
            // (with a small forward threshold to absorb MPV's read-ahead)?
            final isWithinActiveRange =
                start >= activeOffset && start <= activeRangeEnd + forwardThreshold;

            // Detect whether another request for an earlier offset is in flight
            // — if so, let that request handle the shift to avoid duplicate
            // DownloadFile calls.
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

            final isTailQuery =
                res.expectedSize > 20 * 1024 * 1024 &&
                start >= res.expectedSize - 15 * 1024 * 1024;

            final noActiveDownload =
                activeOffset == 0 && baseDownloaded == 0 && prefixSize == 0;

            // Decision: should we shift?
            //   - Yes if no download is active at all (NEW in v2.13.6)
            //   - Yes if start is BEFORE the active window (rewind)
            //   - Yes if start is far AFTER the active window AND no earlier
            //     request is handling it (or it's a tail query)
            final shouldShift = !isCompleted &&
                !isWithinPrefix &&
                !isWithinActiveRange &&
                (noActiveDownload ||
                    start < activeOffset ||
                    (start > activeRangeEnd + forwardThreshold &&
                        (!hasEarlierRequest || isTailQuery)));

            if (shouldShift) {
              final shiftOffset = (start - graceBuffer).clamp(
                0,
                res.expectedSize,
              );

              Log.i(
                'Proxy shifting TDLib download offset for file $fileId to $shiftOffset '
                '(requested range: $start-$end, prefixSize: $prefixSize, '
                'activeOffset: $activeOffset, activeRangeEnd: $activeRangeEnd, '
                'noActiveDownload: $noActiveDownload)',
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
          Log.w('Proxy failed to check or auto-shift download offset: $e');
        }

        // Set response headers
        request.response.headers.set(HttpHeaders.acceptRangesHeader, 'bytes');

        final queryName = request.uri.queryParameters['name'];
        ContentType contentType = ContentType(
          'video',
          'mp4',
        ); // Default fallback mime

        final localPath = tdFile!.local.path.toLowerCase();
        final targetName = (queryName ?? '').toLowerCase();

        if (localPath.endsWith('.mkv') || targetName.endsWith('.mkv')) {
          contentType = ContentType('video', 'x-matroska');
        } else if (localPath.endsWith('.webm') ||
            targetName.endsWith('.webm')) {
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
          request.response.headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-$end/$totalSize',
          );
        } else {
          request.response.statusCode = HttpStatus.ok;
        }

        final responseLength = (end - start + 1).clamp(0, totalSize);
        request.response.headers.contentLength = responseLength;

        // OPTIMIZATION 1: If file is fully completed on disk, stream it directly using native piping
        if (tdFile!.local.isDownloadingCompleted) {
          final file = File(tdFile!.local.path);
          if (await file.exists()) {
            try {
              await request.response.addStream(file.openRead(start, end + 1));
            } catch (e) {
              Log.w(
                'Proxy direct completed streaming error for file $fileId: $e',
              );
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
          String filePath = tdFile!.local.path;
          if (filePath.isEmpty || !await File(filePath).exists()) {
            // Wait up to 10 seconds (100 attempts * 100ms) for the file path to resolve and the file to be created on disk by TDLib
            int fileWaitAttempts = 0;
            while (fileWaitAttempts < 100 &&
                (filePath.isEmpty || !await File(filePath).exists())) {
              await Future.delayed(const Duration(milliseconds: 100));
              try {
                final res = await fetchFile();
                if (res != null) {
                  filePath = res.local.path;
                }
              } catch (_) {}
              fileWaitAttempts++;
            }
          }

          final file = File(filePath);
          if (!await file.exists()) {
            Log.e(
              'Proxy error: local file does not exist after waiting: $filePath',
            );
            request.response.statusCode = HttpStatus.notFound;
            await request.response.close();
            return;
          }

          raf = await file.open(mode: FileMode.read);
          int sentBytes = 0;
          int currentOffset = start;

          // Cache file state to avoid excessive TDLib JSON IPC calls
          td.File currentFile = _fileStates[fileId] ?? tdFile!;

          bool clientDisconnected = false;
          request.response.done.then((_) {
            clientDisconnected = true;
          }).catchError((_) {
            clientDisconnected = true;
          });

          final fileUpdateCompleters = <Completer<void>>[];
          final fileSub = _tdlibService.updates.listen((event) {
            if (event is td.UpdateFile && event.file.id == fileId) {
              currentFile = event.file;
              _cacheFileState(fileId, event.file);
              final pending = List.of(fileUpdateCompleters);
              fileUpdateCompleters.clear();
              for (final c in pending) {
                if (!c.isCompleted) c.complete();
              }
            }
          });

          List<int>? preReadBytes;
          try {
            while (sentBytes < responseLength) {
              final chunkNeeded = (responseLength - sentBytes).clamp(
                0,
                _chunkSize,
              );
              if (chunkNeeded <= 0) break;

              final targetEndOffset = currentOffset + chunkNeeded;

              bool isAvailable = false;
              int activeOffset = _activeDownloadOffsets[fileId] ?? 0;
              int baseDownloaded = _downloadedSizeAtOffsets[fileId] ?? 0;

              if (_fileStates[fileId] != null) {
                currentFile = _fileStates[fileId]!;
              }

              if (currentFile.local.downloadedPrefixSize >= targetEndOffset) {
                isAvailable = true;
              } else if (currentOffset >= activeOffset) {
                final downloadedDelta =
                    (currentFile.local.downloadedSize - baseDownloaded).clamp(
                      0,
                      currentFile.expectedSize,
                    );
                final availableRangeEnd = activeOffset + downloadedDelta;
                if (targetEndOffset <= availableRangeEnd) {
                  isAvailable = true;
                }
              }

              if (!isAvailable) {
                // ------------------------------------------------------------------
                // v2.13.6 — Re-trigger DownloadFile if we've been waiting too long.
                //
                // The inner-loop auto-shift was disabled in v17 to avoid fighting
                // with MPV's parallel requests. But this left a gap: if the
                // per-request shift above (around line 350) didn't trigger
                // (because the active range looked OK at request start) but
                // TDLib stalled, we'd wait forever.
                //
                // The 20s timeout below already re-triggers DownloadFile, but
                // 20s is too long. We keep 20s as the cap, but the re-trigger
                // logic itself is unchanged.
                // ------------------------------------------------------------------

                bool waitSuccess = false;
                final availableCompleter = Completer<void>();
                fileUpdateCompleters.add(availableCompleter);

                try {
                  await Future.any([
                    availableCompleter.future,
                    request.response.done,
                    abortCompleter.future,
                  ]).timeout(const Duration(seconds: 20));

                  if (!clientDisconnected && !abortCompleter.isCompleted) {
                    waitSuccess = true;
                  }
                } on TimeoutException {
                  if (!currentFile.local.isDownloadingCompleted &&
                      !clientDisconnected) {
                    Log.w(
                      'Streaming proxy: re-triggering DownloadFile for file $fileId at offset $activeOffset (waiting for $currentOffset)',
                    );
                    _tdlibService.send(
                      td.DownloadFile(
                        fileId: fileId,
                        priority: 1,
                        offset: activeOffset,
                        limit: 0,
                        synchronous: false,
                      ),
                    );
                  }
                }

                if (clientDisconnected) {
                  Log.i(
                    'Proxy: client disconnected while waiting for bytes for file $fileId.',
                  );
                  break;
                }
                
                if (abortCompleter.isCompleted) {
                  Log.i('Proxy: request aborted manually for file $fileId.');
                  break;
                }

                if (!waitSuccess) {
                  Log.w(
                    'Proxy timed out waiting for bytes ($currentOffset to $targetEndOffset) for file $fileId',
                  );
                  break;
                }
                continue; // Re-evaluate isAvailable on next loop
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

              if (abortCompleter.isCompleted) {
                Log.i('Proxy: request aborted manually during read for file $fileId.');
                break;
              }

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
          } finally {
            fileSub.cancel();
          }
        } catch (e) {
          Log.w('Proxy streaming connection terminated: $e');
        } finally {
          if (raf != null) {
            try {
              await raf.close();
            } catch (_) {}
          }
          // If the request was aborted, remove Content-Length header 
          // before closing to prevent HttpException about content size 
          // mismatch. The HttpServer checks Content-Length vs actual 
          // bytes written and throws if they don't match.
          if (abortCompleter.isCompleted) {
            try {
              request.response.headers.removeAll(HttpHeaders.contentLengthHeader);
            } catch (_) {}
          }
          try {
            await request.response.close();
          } catch (_) {}
        }
      } finally {
        _abortCompleters[fileId]?.remove(abortCompleter);
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
