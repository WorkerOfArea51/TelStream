import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'storage_service.dart';
import '../core/logger.dart';

final trackerServiceProvider = Provider<TrackerService>((ref) {
  return TrackerService(ref.watch(storageServiceProvider));
});

class TrackerService {
  final StorageService _storage;
  TrackerService(this._storage);

  // --- AniList Syncing ---

  Future<int?> searchAnilistId(String name) async {
    final cached = _storage.getAnilistIdForSeries(name);
    if (cached != null) return cached;

    try {
      const url = 'https://graphql.anilist.co';
      const query = r'''
        query ($search: String) {
          Media (search: $search, type: ANIME) {
            id
            title {
              english
              romaji
            }
          }
        }
      ''';

      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'variables': {'search': name},
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final id = data['data']?['Media']?['id'] as int?;
        if (id != null) {
          await _storage.setAnilistIdForSeries(name, id);
          return id;
        }
      }
    } catch (e) {
      Log.w('AniList search failed for $name: $e');
    }
    return null;
  }

  Future<bool> updateAnilistProgress(int mediaId, int episode, {String status = 'CURRENT'}) async {
    final token = _storage.getAnilistToken();
    if (token == null || token.isEmpty) return false;

    try {
      const url = 'https://graphql.anilist.co';
      const mutation = r'''
        mutation ($mediaId: Int, $progress: Int, $status: MediaListStatus) {
          SaveMediaListEntry (mediaId: $mediaId, progress: $progress, status: $status) {
            id
            progress
            status
          }
        }
      ''';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: json.encode({
          'query': mutation,
          'variables': {
            'mediaId': mediaId,
            'progress': episode,
            'status': status,
          },
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        Log.i('AniList updated progress successfully for mediaId=$mediaId to ep=$episode');
        return true;
      } else {
        Log.w('AniList progress update returned error status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      Log.e('AniList progress update failed', e);
    }
    return false;
  }

  // --- MyAnimeList Syncing ---

  Future<int?> searchMalId(String name) async {
    final cached = _storage.getMalIdForSeries(name);
    if (cached != null) return cached;

    try {
      final url = Uri.parse('https://api.myanimelist.net/v2/anime?q=${Uri.encodeComponent(name)}&limit=1');
      final token = _storage.getMalToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        headers['X-MAL-CLIENT-ID'] = '829f046ef3294326127b407137f62c0a'; // Default client ID
      }

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final firstItem = (data['data'] as List?)?.first;
        final id = firstItem?['node']?['id'] as int?;
        if (id != null) {
          await _storage.setMalIdForSeries(name, id);
          return id;
        }
      }
    } catch (e) {
      Log.w('MAL search failed for $name: $e');
    }
    return null;
  }

  Future<bool> updateMalProgress(int animeId, int episode, {String status = 'watching'}) async {
    final token = _storage.getMalToken();
    if (token == null || token.isEmpty) return false;

    try {
      final url = Uri.parse('https://api.myanimelist.net/v2/anime/$animeId/my_list_status');
      final response = await http.put(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'num_watched_episodes': episode.toString(),
          'status': status,
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        Log.i('MAL updated progress successfully for animeId=$animeId to ep=$episode');
        return true;
      } else {
        Log.w('MAL progress update returned error status: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      Log.e('MAL progress update failed', e);
    }
    return false;
  }

  // --- Trakt.tv Syncing ---

  Future<String?> searchTraktId(String name) async {
    final cached = _storage.getTraktIdForSeries(name);
    if (cached != null) return cached;

    try {
      final url = Uri.parse('https://api.trakt.tv/search/show?query=${Uri.encodeComponent(name)}');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'trakt-api-version': '2',
          'trakt-api-key': '05553e1be851c22a76f7df2b8a7c29be60cb5038ecbe6e80b2a7587dfb38ea47', // System default Trakt key
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List data = json.decode(response.body);
        if (data.isNotEmpty) {
          final id = data.first['show']?['ids']?['slug'] as String?;
          if (id != null) {
            await _storage.setTraktIdForSeries(name, id);
            return id;
          }
        }
      }
    } catch (e) {
      Log.w('Trakt search failed for $name: $e');
    }
    return null;
  }

  Future<bool> updateTraktProgress(String showSlug, int season, int episode, double progressPercent) async {
    final token = _storage.getTraktToken();
    if (token == null || token.isEmpty) return false;

    try {
      final url = Uri.parse('https://api.trakt.tv/scrobble/stop');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
          'trakt-api-version': '2',
          'trakt-api-key': '05553e1be851c22a76f7df2b8a7c29be60cb5038ecbe6e80b2a7587dfb38ea47',
        },
        body: json.encode({
          'show': {'ids': {'slug': showSlug}},
          'episode': {'season': season, 'number': episode},
          'progress': progressPercent,
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 201 || response.statusCode == 200) {
        Log.i('Trakt updated scrobble successfully for $showSlug S${season}E$episode to $progressPercent%');
        return true;
      }
    } catch (e) {
      Log.e('Trakt progress update failed', e);
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> searchAnilistList(String name) async {
    try {
      const url = 'https://graphql.anilist.co';
      const query = r'''
        query ($search: String) {
          Page (page: 1, perPage: 10) {
            media (search: $search, type: ANIME) {
              id
              title {
                english
                romaji
                userPreferred
              }
            }
          }
        }
      ''';
      final response = await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'query': query,
          'variables': {'search': name},
        }),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['data']?['Page']?['media'] as List?;
        if (list != null) {
          return list.map((item) {
            final titleObj = item['title'];
            final displayTitle = titleObj['english'] ?? titleObj['userPreferred'] ?? titleObj['romaji'] ?? 'Unknown';
            return {
              'id': item['id'],
              'title': displayTitle,
            };
          }).toList().cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      Log.w('AniList list search failed for $name: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> searchMalList(String name) async {
    try {
      final url = Uri.parse('https://api.myanimelist.net/v2/anime?q=${Uri.encodeComponent(name)}&limit=10');
      final token = _storage.getMalToken();
      final headers = <String, String>{};
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      } else {
        headers['X-MAL-CLIENT-ID'] = '829f046ef3294326127b407137f62c0a';
      }

      final response = await http.get(url, headers: headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final list = data['data'] as List?;
        if (list != null) {
          return list.map((item) {
            final node = item['node'];
            return {
              'id': node['id'],
              'title': node['title'] ?? 'Unknown',
            };
          }).toList().cast<Map<String, dynamic>>();
        }
      }
    } catch (e) {
      Log.w('MAL list search failed for $name: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> searchTraktList(String name) async {
    try {
      final url = Uri.parse('https://api.trakt.tv/search/show?query=${Uri.encodeComponent(name)}&limit=10');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'trakt-api-version': '2',
          'trakt-api-key': '05553e1be851c22a76f7df2b8a7c29be60cb5038ecbe6e80b2a7587dfb38ea47',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final List list = json.decode(response.body);
        return list.map((item) {
          final show = item['show'];
          final ids = show?['ids'] ?? {};
          final displayTitle = show?['title'] ?? 'Unknown';
          final year = show?['year']?.toString() ?? '';
          return {
            'id': ids['slug'] ?? ids['trakt']?.toString() ?? '',
            'title': year.isNotEmpty ? '$displayTitle ($year)' : displayTitle,
          };
        }).toList().cast<Map<String, dynamic>>();
      }
    } catch (e) {
      Log.w('Trakt list search failed for $name: $e');
    }
    return [];
  }
}
