import 'dart:io';
import 'dart:typed_data';
import 'package:tdlib/td_api.dart' as td;
import '../streaming_proxy_service.dart';
import '../../core/logger.dart';

class TdlibRangeFetch {
  static HttpClient? _sharedClient;
  static HttpClient _client() {
    _sharedClient ??= HttpClient()
      ..connectionTimeout = const Duration(seconds: 15)
      ..idleTimeout = const Duration(seconds: 60);
    return _sharedClient!;
  }

  /// Closes the shared client. Call when the app is shutting down or when
  /// the proxy URL changes (e.g. user changed proxy settings).
  static void resetClient() {
    _sharedClient?.close(force: true);
    _sharedClient = null;
  }

  /// Fetch the first [bytes] bytes of the file referenced by [message].
  ///
  /// Resolution order (v2.13.6):
  ///   1. If the file is fully downloaded locally → read directly from disk.
  ///   2. If TDLib has already downloaded a prefix of at least [bytes] bytes
  ///      (via downloadedPrefixSize) → read directly from disk. This is the
  ///      key fix: in v17 we only read from disk when the file was FULLY
  ///      downloaded, which meant we always hit the HTTP path for streaming
  ///      files — even when TDLib had already cached the first 2 MB.
  ///   3. Otherwise, issue an HTTP range request via the streaming proxy.
  ///      The proxy will trigger a TDLib download at offset 0 if none is
  ///      active (fixed in v2.13.6 streaming_proxy_service.dart).
  static Future<Uint8List?> fetchPrefix(
    td.Message message,
    StreamingProxyService proxyService, {
    int bytes = 2097152,
  }) async {
    td.File? tdFile;
    if (message.content is td.MessageVideo) {
      tdFile = (message.content as td.MessageVideo).video.video;
    } else if (message.content is td.MessageDocument) {
      tdFile = (message.content as td.MessageDocument).document.document;
    }

    if (tdFile == null) return null;

    // ------------------------------------------------------------------
    // v2.13.6 — Read directly from disk when enough prefix is available.
    //
    // TDLib maintains a "downloaded prefix" (downloadedPrefixSize) which is
    // the number of bytes available from the START of the file, regardless
    // of the current download offset. If this prefix is >= bytes, we can
    // skip the HTTP roundtrip entirely and read from disk.
    //
    // This is the common case after the user has played or scrubbed through
    // a video — TDLib keeps the first few MB cached for fast re-open.
    // ------------------------------------------------------------------
    final hasEnoughPrefix = tdFile.local.downloadedPrefixSize >= bytes;
    final canReadFromDisk = tdFile.local.path.isNotEmpty &&
        (tdFile.local.isDownloadingCompleted || hasEnoughPrefix);

    if (canReadFromDisk) {
      final file = File(tdFile.local.path);
      if (await file.exists()) {
        try {
          final raf = await file.open(mode: FileMode.read);
          final data = await raf.read(bytes);
          await raf.close();
          if (data.length < bytes) {
            Log.d('Local prefix read returned partial data: ${data.length} / $bytes bytes '
                '(prefixSize=${tdFile.local.downloadedPrefixSize}, completed=${tdFile.local.isDownloadingCompleted})');
          } else {
            Log.d('Local prefix read returned full data: ${data.length} bytes');
          }
          // If we got partial data AND the file isn't fully downloaded,
          // we don't have enough to parse metadata. Fall through to HTTP.
          if (data.length >= bytes || tdFile.local.isDownloadingCompleted) {
            return data;
          }
          Log.d('Local prefix was partial and file is still downloading — falling through to HTTP');
        } catch (e, st) {
          Log.e('Failed to read local video file prefix', e, st);
        }
      }
    }

    // Attempt HTTP range request via proxy
    try {
      final url = proxyService.getProxyUrl(tdFile.id);
      final headers = proxyService.getAuthHeaders();

      final client = _client();

      final request = await client.getUrl(Uri.parse(url));
      headers.forEach((key, value) {
        request.headers.add(key, value);
      });
      request.headers.add('Range', 'bytes=0-${bytes - 1}');

      // 60s timeout — large files (1GB+) over slow connections can take
      // 30-50 seconds to serve 2MB through the proxy on first request
      // (TDLib needs to start the download + write bytes to disk).
      final response = await request.close().timeout(const Duration(seconds: 60));
      if (response.statusCode == HttpStatus.ok || response.statusCode == HttpStatus.partialContent) {
        final builder = BytesBuilder();
        await for (final chunk in response) {
          builder.add(chunk);
          if (builder.length >= bytes) break;
        }

        final result = builder.toBytes();
        Log.i('Proxy range prefix request received ${result.length} bytes (status: ${response.statusCode})');

        if (result.length > bytes) {
          return result.sublist(0, bytes);
        }
        return result;
      } else {
        Log.w('Proxy range request failed for file ${tdFile.id} with status: ${response.statusCode}');
      }
    } catch (e, st) {
      Log.e('Proxy range request failed for file ${tdFile.id}', e, st);
    }

    return null;
  }

  /// Fetch the last [bytes] bytes of the file referenced by [message].
  /// Used to find the moov atom in MP4 files where it's stored at the end.
  static Future<Uint8List?> fetchSuffix(
    td.Message message,
    StreamingProxyService proxyService, {
    int bytes = 2097152,
  }) async {
    td.File? tdFile;
    if (message.content is td.MessageVideo) {
      tdFile = (message.content as td.MessageVideo).video.video;
    } else if (message.content is td.MessageDocument) {
      tdFile = (message.content as td.MessageDocument).document.document;
    }

    if (tdFile == null || tdFile.expectedSize <= 0) return null;

    final totalSize = tdFile.expectedSize;
    // If the whole file fits in our fetch window, the prefix already contained
    // everything — fetching the suffix would just repeat the same request.
    if (totalSize <= bytes) return null;

    final startByte = totalSize - bytes;

    // ------------------------------------------------------------------
    // v2.13.6 — Read directly from disk when the file is fully downloaded.
    // We can't use downloadedPrefixSize here because the suffix is at the
    // END of the file, and TDLib's prefix is from the START.
    // ------------------------------------------------------------------
    if (tdFile.local.isDownloadingCompleted && tdFile.local.path.isNotEmpty) {
      final file = File(tdFile.local.path);
      if (await file.exists()) {
        try {
          final raf = await file.open(mode: FileMode.read);
          await raf.setPosition(startByte);
          final data = await raf.read(bytes);
          await raf.close();
          if (data.length < bytes) {
            Log.d('Local suffix read returned partial data: ${data.length} / $bytes bytes');
          } else {
            Log.d('Local suffix read returned full data: ${data.length} bytes');
          }
          return data;
        } catch (e, st) {
          Log.e('Failed to read local video file suffix', e, st);
        }
      }
    }

    // Attempt HTTP range request via proxy
    try {
      final url = proxyService.getProxyUrl(tdFile.id);
      final headers = proxyService.getAuthHeaders();

      final client = _client();

      final request = await client.getUrl(Uri.parse(url));
      headers.forEach((key, value) {
        request.headers.add(key, value);
      });
      request.headers.add('Range', 'bytes=$startByte-${totalSize - 1}');

      // 60s timeout — suffix requests are slower because the proxy must
      // seek to the end of the file (TDLib may need to download from
      // scratch if the suffix isn't cached).
      final response = await request.close().timeout(const Duration(seconds: 60));
      if (response.statusCode == HttpStatus.ok || response.statusCode == HttpStatus.partialContent) {
        final builder = BytesBuilder();
        await for (final chunk in response) {
          builder.add(chunk);
          if (builder.length >= bytes) break;
        }

        final result = builder.toBytes();
        Log.i('Proxy range suffix request received ${result.length} bytes (status: ${response.statusCode})');

        if (result.length > bytes) {
          return result.sublist(0, bytes);
        }
        return result;
      } else {
        Log.w('Proxy range suffix request failed for file ${tdFile.id} with status: ${response.statusCode}');
      }
    } catch (e, st) {
      Log.e('Proxy range suffix request failed for file ${tdFile.id}', e, st);
    }

    return null;
  }
}
