import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive.dart';
import '../core/logger.dart';
import 'storage_service.dart';
import '../features/settings/settings_provider.dart';

final subtitleDownloaderServiceProvider = Provider<SubtitleDownloaderService>((ref) {
  return SubtitleDownloaderService(ref);
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
  final Ref _ref;
  SubtitleDownloaderService(this._ref);

  Future<List<SubtitleMatch>> searchSubtitles(String query, {String lang = 'eng'}) async {
    final settings = _ref.read(videoSettingsProvider);
    final provider = settings.preferredSubtitleProvider;
    final storage = _ref.read(storageServiceProvider);

    if (provider == 'subdl') {
      return _searchSubDL(query, lang: lang, apiKey: storage.getSubdlApiKey());
    } else {
      return _searchOpenSubtitles(query, lang: lang, apiKey: storage.getOpenSubtitlesApiKey());
    }
  }

  Future<List<SubtitleMatch>> _searchOpenSubtitles(String query, {required String lang, required String apiKey}) async {
    try {
      final Map<String, String> langMap = {
        'eng': 'en',
        'spa': 'es',
        'fre': 'fr',
        'ger': 'de',
        'ind': 'id',
        'ara': 'ar',
      };
      final lang2 = langMap[lang] ?? lang;

      final url = Uri.parse('https://api.opensubtitles.com/api/v1/subtitles?query=${Uri.encodeComponent(query)}&languages=$lang2');
      
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'User-Agent': 'TelStream v2.7.0',
      };
      if (apiKey.isNotEmpty) {
        headers['Api-Key'] = apiKey;
      }

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List? dataList = data['data'];
        if (dataList != null) {
          final List<SubtitleMatch> results = [];
          for (final item in dataList) {
            final attrs = item['attributes'] as Map<String, dynamic>?;
            if (attrs == null) continue;
            final files = attrs['files'] as List?;
            if (files == null || files.isEmpty) continue;
            
            final fileItem = files[0] as Map<String, dynamic>;
            final fileId = fileItem['file_id']?.toString();
            final fileName = fileItem['file_name'] as String? ?? attrs['release'] as String? ?? 'Subtitle.srt';
            final language = attrs['language'] as String? ?? 'English';

            if (fileId != null) {
              results.add(SubtitleMatch(
                id: fileId,
                fileName: fileName,
                downloadUrl: fileId, // Use fileId directly as downloadUrl for OpenSubtitles
                language: language,
              ));
            }
          }
          return results;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw const HttpException('Invalid/Missing OpenSubtitles API Key. Please configure it in Player Settings.');
      } else if (response.statusCode == 429) {
        throw const HttpException('Too many requests. OpenSubtitles rate limit exceeded. Please try again later.');
      } else {
        throw HttpException('OpenSubtitles server returned error code ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Failed to search OpenSubtitles for query=$query', e);
      rethrow;
    }
    return [];
  }

  Future<List<SubtitleMatch>> _searchSubDL(String query, {required String lang, required String apiKey}) async {
    if (apiKey.isEmpty) {
      throw const HttpException('SubDL API Key is required. Please configure it in Player Settings.');
    }

    try {
      final Map<String, String> langMap = {
        'eng': 'en',
        'spa': 'es',
        'fre': 'fr',
        'ger': 'de',
        'ind': 'id',
        'ara': 'ar',
      };
      final lang2 = langMap[lang] ?? lang;

      final url = Uri.https('api.subdl.com', '/api/v1/subtitles', {
        'api_key': apiKey,
        'film_name': query,
        'languages': lang2,
      });
      
      final response = await http.get(
        url,
        headers: {
          'Accept': 'application/json',
          'User-Agent': 'TelStream v2.7.0',
        },
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final bool status = data['status'] as bool? ?? false;
        final List? subtitlesList = data['subtitles'];
        
        if (status && subtitlesList != null) {
          final List<SubtitleMatch> results = [];
          for (final item in subtitlesList) {
            final fileName = item['name'] as String? ?? item['release_name'] as String? ?? 'Subtitle.srt';
            final downloadLink = item['download_link'] as String?;
            final language = item['lang'] as String? ?? 'English';
            
            if (downloadLink != null) {
              results.add(SubtitleMatch(
                id: downloadLink,
                fileName: fileName,
                downloadUrl: downloadLink,
                language: language,
              ));
            }
          }
          return results;
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw const HttpException('Invalid SubDL API Key. Please configure it in Player Settings.');
      } else if (response.statusCode == 429) {
        throw const HttpException('Too many requests. SubDL rate limit exceeded.');
      } else {
        throw HttpException('SubDL server returned error code ${response.statusCode}');
      }
    } catch (e) {
      Log.e('Failed to search SubDL for query=$query', e);
      rethrow;
    }
    return [];
  }

  Future<String?> downloadSubtitle(String downloadUrl, String fileName, {String? subtitleId}) async {
    try {
      final settings = _ref.read(videoSettingsProvider);
      final storage = _ref.read(storageServiceProvider);
      final provider = settings.preferredSubtitleProvider;
      
      List<int> bytes;

      if (provider == 'opensubtitles') {
        final fileIdStr = subtitleId ?? downloadUrl;
        final fileId = int.tryParse(fileIdStr);
        if (fileId == null) {
          throw const HttpException('Invalid OpenSubtitles file ID for download.');
        }

        final headers = {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'User-Agent': 'TelStream v2.7.0',
        };
        final openSubtitlesKey = storage.getOpenSubtitlesApiKey();
        if (openSubtitlesKey.isNotEmpty) {
          headers['Api-Key'] = openSubtitlesKey;
        }

        final downloadLinkResponse = await http.post(
          Uri.parse('https://api.opensubtitles.com/api/v1/download'),
          headers: headers,
          body: json.encode({'file_id': fileId}),
        ).timeout(const Duration(seconds: 10));

        if (downloadLinkResponse.statusCode == 200) {
          final Map<String, dynamic> linkData = json.decode(downloadLinkResponse.body);
          final link = linkData['link'] as String?;
          if (link == null) {
            throw const HttpException('OpenSubtitles returned an empty download link.');
          }

          final linkUri = Uri.parse(link);
          final allowedHosts = {'api.opensubtitles.com', 'opensubtitles.com', 'dl.opensubtitles.org'};
          if (!linkUri.isScheme('https') || !allowedHosts.contains(linkUri.host)) {
            throw HttpException('OpenSubtitles returned an untrusted download host: ${linkUri.host}');
          }

          final fileResponse = await http.get(linkUri, headers: {
            'User-Agent': 'TelStream v2.7.0',
          }).timeout(const Duration(seconds: 15));

          if (fileResponse.statusCode == 200) {
            bytes = fileResponse.bodyBytes;
          } else {
            throw HttpException('Failed to download subtitle file. Code: ${fileResponse.statusCode}');
          }
        } else if (downloadLinkResponse.statusCode == 401 || downloadLinkResponse.statusCode == 403) {
          throw const HttpException('Access Denied. Ensure your OpenSubtitles API key is configured and valid.');
        } else if (downloadLinkResponse.statusCode == 406) {
          throw const HttpException('OpenSubtitles download limit reached or not allowed without login.');
        } else {
          throw HttpException('OpenSubtitles download endpoint returned error code ${downloadLinkResponse.statusCode}');
        }
      } else {
        final uri = Uri.parse(downloadUrl);
        final downloadUri = uri.isAbsolute ? uri : Uri.parse('https://subdl.com$downloadUrl');

        final response = await http.get(
          downloadUri,
          headers: {
            'User-Agent': 'TelStream v2.7.0',
          },
        ).timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          if (response.headers['content-type']?.contains('application/json') == true ||
              (response.body.trim().startsWith('{') && response.body.contains('error'))) {
            throw const HttpException('SubDL API error or download limit reached (received JSON instead of subtitle file).');
          }
          bytes = response.bodyBytes;
        } else {
          throw HttpException('Failed to download SubDL subtitle. Code: ${response.statusCode}');
        }
      }

      List<int> decodedBytes = bytes;
      const maxDecompressedBytes = 50 * 1024 * 1024; // 50 MB hard cap

      if (bytes.length > maxDecompressedBytes) {
        throw const HttpException('Compressed subtitle payload exceeds 50MB input cap.');
      }

      if (downloadUrl.endsWith('.gz') || (bytes.length > 2 && bytes[0] == 0x1f && bytes[1] == 0x8b)) {
        final decoder = GZipDecoder();
        decodedBytes = decoder.decodeBytes(bytes, verify: true);
        if (decodedBytes.length > maxDecompressedBytes) {
          throw const HttpException('Decompressed GZIP size exceeds 50MB limit.');
        }
      }

      if (downloadUrl.endsWith('.zip') || (bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4B && bytes[2] == 0x03 && bytes[3] == 0x04)) {
        final archive = ZipDecoder().decodeBytes(bytes);
        bool found = false;
        for (final file in archive) {
          if (file.isFile && (file.name.endsWith('.srt') || file.name.endsWith('.vtt') || file.name.endsWith('.ass'))) {
            if (file.size > maxDecompressedBytes) {
              Log.w('Skipping oversized subtitle entry: ${file.name} (${file.size} bytes)');
              continue;
            }
            final content = file.content as List<int>;
            if (content.length > maxDecompressedBytes) {
              Log.w('Decompressed entry exceeds cap: ${file.name}');
              continue;
            }
            decodedBytes = content;
            fileName = file.name;
            found = true;
            break;
          }
        }
        if (!found) {
          throw const HttpException('No compatible subtitle files (.srt, .vtt, .ass) found inside the downloaded ZIP package.');
        }
      }

      // Validate the decoded content looks like a real subtitle file
      final contentStr = utf8.decode(decodedBytes, allowMalformed: true);
      final lowerExt = fileName.toLowerCase();
      final bool looksValid;
      if (lowerExt.endsWith('.vtt')) {
        looksValid = contentStr.trimLeft().startsWith('WEBVTT');
      } else if (lowerExt.endsWith('.srt')) {
        looksValid = contentStr.contains('-->') &&
            RegExp(r'^\d+\s*$', multiLine: true).hasMatch(contentStr);
      } else if (lowerExt.endsWith('.ass')) {
        looksValid = contentStr.contains('[Script Info]') ||
            contentStr.contains('[V4+ Styles]');
      } else {
        looksValid = contentStr.contains('-->') || contentStr.contains('WEBVTT');
      }
      // Reject HTML error pages
      final lowerContent = contentStr.trimLeft().toLowerCase();
      if (lowerContent.startsWith('<!doctype html') || lowerContent.startsWith('<html')) {
        throw HttpException(
          'Downloaded content is an HTML page, not a subtitle file. '
          'The provider may have returned an error page.'
        );
      }
      if (!looksValid) {
        throw HttpException(
          'Downloaded content does not look like a valid $lowerExt subtitle file. '
          'First 80 chars: "${contentStr.substring(0, contentStr.length < 80 ? contentStr.length : 80)}".'
        );
      }

      final tempDir = await getTemporaryDirectory();
      final safeName = fileName.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
      final file = File('${tempDir.path}/$safeName');
      await file.writeAsBytes(decodedBytes);
      Log.i('Downloaded and validated subtitle (${decodedBytes.length} bytes) to: ${file.path}');
      return file.path;
      
    } catch (e) {
      final safeUrl = Uri.tryParse(downloadUrl)?.replace(query: '').toString() ?? 'unknown_url';
      Log.e('Failed to download subtitle from $safeUrl', e);
      rethrow;
    }
  }
}
