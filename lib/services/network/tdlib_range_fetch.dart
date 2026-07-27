import 'dart:io';
import 'dart:typed_data';
import 'package:tdlib/td_api.dart' as td;
import '../streaming_proxy_service.dart';
import '../../core/logger.dart';

class TdlibRangeFetch {
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

    // Check if fully downloaded locally
    if (tdFile.local.isDownloadingCompleted && tdFile.local.path.isNotEmpty) {
      final file = File(tdFile.local.path);
      if (await file.exists()) {
        try {
          final raf = await file.open(mode: FileMode.read);
          final data = await raf.read(bytes);
          await raf.close();
          return data;
        } catch (e, st) {
          Log.e('Failed to read local video file prefix', e, st);
        }
      }
    }

    // Attempt HTTP range request via proxy
    HttpClient? client;
    try {
      final url = proxyService.getProxyUrl(tdFile.id);
      final headers = proxyService.getAuthHeaders();
      
      client = HttpClient();
      client.connectionTimeout = const Duration(seconds: 10);
      
      final request = await client.getUrl(Uri.parse(url));
      headers.forEach((key, value) {
        request.headers.add(key, value);
      });
      request.headers.add('Range', 'bytes=0-${bytes - 1}');
      
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode == HttpStatus.ok || response.statusCode == HttpStatus.partialContent) {
        final builder = BytesBuilder();
        await for (final chunk in response) {
          builder.add(chunk);
          if (builder.length >= bytes) break;
        }
        
        final result = builder.toBytes();
        if (result.length > bytes) {
          return result.sublist(0, bytes);
        }
        return result;
      } else {
        Log.w('Proxy range request failed for file ${tdFile.id} with status: ${response.statusCode}');
      }
    } catch (e, st) {
      Log.e('Proxy range request failed for file ${tdFile.id}', e, st);
    } finally {
      client?.close(force: true);
    }

    return null;
  }
}
