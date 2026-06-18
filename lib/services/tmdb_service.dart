import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/anime_models.dart';
import 'storage_service.dart';
import '../core/logger.dart';

final tmdbServiceProvider = Provider<TmdbService>((ref) {
  return TmdbService(ref.watch(storageServiceProvider));
});

class TmdbService {
  final StorageService _storageService;
  static const String _defaultApiKey = '829f046ef3294326127b407137f62c0a';

  TmdbService(this._storageService);

  String get _apiKey {
    final customKey = _storageService.getTmdbApiKey();
    if (customKey != null && customKey.isNotEmpty) {
      return customKey;
    }
    return _defaultApiKey;
  }

  // Normalizes series title by removing common release tags, audio details and quality tags
  String _cleanTitleForSearch(String title) {
    var clean = title.trim();
    // Remove resolution patterns like [1080p], (720p), etc.
    clean = clean.replaceAll(RegExp(r'[\[\(]\d{3,4}p[\]\)]', caseSensitive: false), '');
    // Remove audio tags like Dual Audio, Multi Audio, Multi-Audio, Dual-Audio
    clean = clean.replaceAll(RegExp(r'(Dual|Multi)[-\s]Audio', caseSensitive: false), '');
    // Remove dynamic range and encode tags
    clean = clean.replaceAll(RegExp(r'(10bit|x265|hevc|x264|h264|bdrip|web-rip|webrip)', caseSensitive: false), '');
    // Remove square brackets and parentheses content
    clean = clean.replaceAll(RegExp(r'\[[^\]]*\]'), '');
    clean = clean.replaceAll(RegExp(r'\([^)]*\)'), '');
    
    // Remove season suffixes like ": Season 1", "Season 1", "S1", "S01", ": S1", " - Season 1", etc.
    clean = clean.replaceAll(RegExp(r'[-\s:]+\s*(Season\s+\d+|S\d+)', caseSensitive: false), '');

    // Strip trailing colons, hyphens, and whitespace
    clean = clean.replaceAll(RegExp(r'[\s\-:]+$'), '');

    // Clean multiple spaces and special characters
    clean = clean.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return clean;
  }

  // Fetch or search series/movie metadata from TMDB
  Future<TmdbSeriesMetadata?> fetchMetadata(String seriesName) async {
    final cacheKey = 'tmdb_series_$seriesName';
    final cached = _storageService.getTmdbCache(cacheKey);
    if (cached != null) {
      try {
        return TmdbSeriesMetadata.fromJson(cached);
      } catch (e) {
        Log.e('Failed to parse cached TMDB series metadata for $seriesName', e);
      }
    }

    final query = _cleanTitleForSearch(seriesName);
    if (query.isEmpty) return null;

    try {
      final url = Uri.parse(
        'https://api.themoviedb.org/3/search/multi?api_key=$_apiKey&query=${Uri.encodeComponent(query)}&language=en-US'
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] as List?;
        if (results != null && results.isNotEmpty) {
          // Find first matching movie or tv result
          final match = results.firstWhere(
            (r) => r['media_type'] == 'tv' || r['media_type'] == 'movie',
            orElse: () => results.first,
          );

          final isTv = match['media_type'] == 'tv' || match['name'] != null;
          final title = (match[isTv ? 'name' : 'title'] ?? seriesName) as String;
          final overview = (match['overview'] ?? '') as String;
          final posterPath = match['poster_path'] as String?;
          final backdropPath = match['backdrop_path'] as String?;
          final rating = (match['vote_average'] as num?)?.toDouble() ?? 0.0;
          final releaseDate = (match[isTv ? 'first_air_date' : 'release_date'] ?? '') as String;
          final genreIds = List<int>.from(match['genre_ids'] ?? []);
          final tmdbId = match['id'] as int;

          // Convert genre IDs to names (hardcoded common genres list to avoid dynamic fetching overhead)
          final genres = _mapGenreIds(genreIds);

          final metadata = TmdbSeriesMetadata(
            title: title,
            overview: overview,
            posterPath: posterPath != null ? 'https://image.tmdb.org/t/p/w500$posterPath' : null,
            backdropPath: backdropPath != null ? 'https://image.tmdb.org/t/p/w1280$backdropPath' : null,
            rating: rating,
            releaseDate: releaseDate,
            genres: genres,
            tmdbId: tmdbId,
          );

          await _storageService.setTmdbCache(cacheKey, metadata.toJson());
          return metadata;
        }
      }
    } catch (e, stack) {
      Log.e('Failed to fetch TMDB series metadata for $seriesName', e, stack);
    }
    return null;
  }

  // Fetch season episodes list with summaries and stills
  Future<List<TmdbEpisodeMetadata>> fetchSeasonEpisodes(int tmdbId, int seasonNumber) async {
    final cacheKey = 'tmdb_episodes_${tmdbId}_$seasonNumber';
    final cached = _storageService.getTmdbCache(cacheKey);
    if (cached != null) {
      try {
        final list = cached as List;
        return list.map((item) => TmdbEpisodeMetadata.fromJson(item)).toList();
      } catch (e) {
        Log.e('Failed to parse cached TMDB episodes list', e);
      }
    }

    try {
      final url = Uri.parse(
        'https://api.themoviedb.org/3/tv/$tmdbId/season/$seasonNumber?api_key=$_apiKey&language=en-US'
      );
      final response = await http.get(url).timeout(const Duration(seconds: 6));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final episodes = data['episodes'] as List?;
        if (episodes != null) {
          final List<TmdbEpisodeMetadata> episodeList = [];
          for (final ep in episodes) {
            final epNum = ep['episode_number'] as int;
            final epName = (ep['name'] ?? 'Episode $epNum') as String;
            final overview = (ep['overview'] ?? '') as String;
            final stillPath = ep['still_path'] as String?;

            episodeList.add(TmdbEpisodeMetadata(
              episodeNumber: epNum,
              title: epName,
              overview: overview,
              stillPath: stillPath != null ? 'https://image.tmdb.org/t/p/w300$stillPath' : null,
            ));
          }

          final jsonList = episodeList.map((e) => e.toJson()).toList();
          await _storageService.setTmdbCache(cacheKey, jsonList);
          return episodeList;
        }
      }
    } catch (e) {
      Log.w('Failed to fetch TMDB season episodes for tv_id=$tmdbId season=$seasonNumber: $e');
    }
    return [];
  }

  List<String> _mapGenreIds(List<int> ids) {
    const genreMap = {
      28: 'Action',
      12: 'Adventure',
      16: 'Animation',
      35: 'Comedy',
      80: 'Crime',
      99: 'Documentary',
      18: 'Drama',
      10751: 'Family',
      14: 'Fantasy',
      36: 'History',
      27: 'Horror',
      10402: 'Music',
      9648: 'Mystery',
      10749: 'Romance',
      878: 'Sci-Fi',
      10770: 'TV Movie',
      53: 'Thriller',
      10752: 'War',
      37: 'Western',
      10759: 'Action & Adventure',
      10762: 'Kids',
      10763: 'News',
      10764: 'Reality',
      10765: 'Sci-Fi & Fantasy',
      10766: 'Soap',
      10767: 'Talk',
      10768: 'War & Politics',
    };
    return ids.map((id) => genreMap[id] ?? 'Other').where((g) => g != 'Other').toList();
  }
}
