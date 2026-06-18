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

  StreamingProxyService(this._tdlibService);

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

    try {
      int sentBytes = 0;
      int currentOffset = start;

      while (sentBytes < responseLength) {
        // Read in chunks of 512KB to keep buffer flowing smoothly
        final chunkNeeded = (responseLength - sentBytes).clamp(0, 524288);
        if (chunkNeeded <= 0) break;

        final targetEndOffset = currentOffset + chunkNeeded;

        // Wait for TDLib to download the needed bytes
        bool isCached = await _waitForBytes(fileId, targetEndOffset, currentOffset);
        if (!isCached) {
          Log.w('Proxy timed out waiting for bytes ($currentOffset to $targetEndOffset) for file $fileId');
          break;
        }

        final freshRes = await _tdlibService.sendAsync(td.GetFile(fileId: fileId));
        if (freshRes is! td.File || freshRes.local.path.isEmpty) {
          Log.w('Proxy error: local file path is empty');
          break;
        }

        final file = File(freshRes.local.path);
        if (!await file.exists()) {
          Log.w('Proxy error: local file does not exist: ${file.path}');
          break;
        }

        final raf = await file.open(mode: FileMode.read);
        try {
          await raf.setPosition(currentOffset);
          final bytes = await raf.read(chunkNeeded);
          if (bytes.isEmpty) {
            break;
          }
          request.response.add(bytes);
          await request.response.flush();
          sentBytes += bytes.length;
          currentOffset += bytes.length;
        } finally {
          await raf.close();
        }
      }
    } catch (e) {
      Log.w('Proxy streaming connection terminated: $e');
    } finally {
      try {
        await request.response.close();
      } catch (_) {}
    }
  }

  Future<bool> _waitForBytes(int fileId, int targetOffset, int startOffset) async {
    int attempts = 0;
    while (attempts < 200) { // Max 20 seconds
      try {
        final res = await _tdlibService.sendAsync(td.GetFile(fileId: fileId));
        if (res is td.File) {
          if (res.local.isDownloadingCompleted) {
            return true;
          }

          final activeOffset = _activeDownloadOffsets[fileId] ?? 0;
          final baseDownloaded = _downloadedSizeAtOffsets[fileId] ?? 0;

          if (startOffset < activeOffset) {
            // Request is before active download offset. Check contiguous downloaded prefix.
            if (res.local.downloadedPrefixSize >= targetOffset) {
              return true;
            }
          } else {
            // Request is within or after active download offset.
            final downloadedDelta = res.local.downloadedSize - baseDownloaded;
            final availableRangeEnd = activeOffset + downloadedDelta;
            if (targetOffset <= availableRangeEnd) {
              return true;
            }
          }
        }
      } catch (e) {
        Log.w('Proxy file checking error: $e');
      }

      await Future.delayed(const Duration(milliseconds: 100));
      attempts++;
    }
    return false;
  }
}
