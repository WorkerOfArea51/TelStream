import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import '../core/logger.dart';

final subtitleDownloaderServiceProvider = Provider<SubtitleDownloaderService>((ref) {
  return SubtitleDownloaderService();
});

class SubtitleMatch {
  final String id;
  final String fileName;
  final String downloadUrl;
  final String language;

  SubtitleMatch({
    required this.id,
    required this.fileName,
    required this.downloadUrl,
    required this.language,
  });
}

class SubtitleDownloaderService {
  Future<List<SubtitleMatch>> searchSubtitles(String query, {String lang = 'eng'}) async {
    try {
      final url = Uri.parse(
        'https://rest.opensubtitles.org/subtitles/search/query-${Uri.encodeComponent(query)}/sublanguageid-$lang'
      );
      
      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'TemporaryUserAgent',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List? data = json.decode(response.body);
        if (data != null) {
          final List<SubtitleMatch> results = [];
          for (final item in data) {
            final fileName = item['SubFileName'] as String?;
            final downloadUrl = item['SubDownloadLink'] as String?;
            final id = item['IDSubtitleFile'] as String?;
            final language = item['LanguageName'] as String? ?? 'English';
            
            if (fileName != null && downloadUrl != null) {
              results.add(SubtitleMatch(
                id: id ?? downloadUrl,
                fileName: fileName,
                downloadUrl: downloadUrl,
                language: language,
              ));
            }
          }
          return results;
        }
      } else if (response.statusCode == 429) {
        throw const HttpException('Too many requests. OpenSubtitles rate limit exceeded. Please try again later.');
      } else if (response.statusCode == 403) {
        throw const HttpException('Access denied. OpenSubtitles has blocked public queries. Please load a local subtitle file or try again later.');
      } else {
        throw HttpException('OpenSubtitles server returned error code ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Failed to search subtitles for query=$query', e);
      rethrow;
    }
    return [];
  }

  Future<String?> downloadSubtitle(String downloadUrl, String fileName) async {
    try {
      final response = await http.get(
        Uri.parse(downloadUrl),
        headers: {
          'User-Agent': 'TemporaryUserAgent',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        
        // OpenSubtitles links return gzipped data (GZIP header: 0x1f 0x8b)
        List<int> decodedBytes = bytes;
        if (downloadUrl.endsWith('.gz') || (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b)) {
          decodedBytes = gzip.decode(bytes);
        }

        final tempDir = await getTemporaryDirectory();
        final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
        final file = File('${tempDir.path}/$safeName');
        await file.writeAsBytes(decodedBytes);
        Log.i('Downloaded and saved subtitle to: ${file.path}');
        return file.path;
      } else {
        throw HttpException('Failed to download subtitle. Server returned code ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Failed to download subtitle from $downloadUrl', e);
      rethrow;
    }
  }
}
