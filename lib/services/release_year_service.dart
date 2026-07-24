import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/logger.dart';
import '../core/secrets.dart';
import '../models/anime_models.dart';
import '../core/constants.dart';
import 'storage_service.dart';
import '../core/utils/title_normalizer.dart';

class ReleaseYearService {
  Future<void> fetchReleaseYearsInBackground(
    List<AnimeSeries> allSeries,
    ChannelCategory category,
    StorageService storage,
    void Function() onUpdateUI,
    void Function() onDone,
  ) async {
    try {
      final List<AnimeSeason> seasonsToFetch = [];
      final List<AnimeSeries> seriesCopy = List.from(allSeries);
      
      for (final series in seriesCopy) {
        for (final season in series.seasons) {
          final title = season.fullTitle;
          
          final cachedYear = storage.getSeasonReleaseYear(title);
          if (cachedYear != null && cachedYear != 0) {
            continue;
          }
          
          seasonsToFetch.add(season);
        }
      }

      if (seasonsToFetch.isEmpty) {
        onDone();
        return;
      }

      Log.i('Starting background release year fetch for ${seasonsToFetch.length} seasons in category ${category.title}');
      int updateCount = 0;

      for (final season in seasonsToFetch) {
        // Omitting pip block check since it's hard to port provider ref here, 
        // we can just run the loop slowly

        final title = season.fullTitle;
        final cleanTitle = TitleNormalizer.normalizeSeriesName(title, isMovie: category.title == 'Movies');
        int? fetchedYear;
        
        try {
          if (category.title == 'Anime') {
            fetchedYear = await fetchAnimeReleaseYearFromMal(cleanTitle);
          } else {
            fetchedYear = await fetchMediaReleaseYearFromTmdb(cleanTitle, category);
          }
        } catch (e, stack) {
          Log.e('Failed to fetch release year for: $cleanTitle (original: $title)', e, stack);
        }

        if (fetchedYear != null) {
          await storage.setSeasonReleaseYear(title, fetchedYear);
          Log.i('Cached release year for "$title": $fetchedYear');
          
          updateCount++;
          if (updateCount % 4 == 0 || season == seasonsToFetch.last) {
            onUpdateUI();
          }
        }

        await Future.delayed(const Duration(milliseconds: 1500));
      }
    } catch (e, stack) {
      Log.e('Error in background release year fetch loop', e, stack);
    } finally {
      onDone();
    }
  }

  Future<int?> fetchAnimeReleaseYearFromMal(String title) async {
    try {
      final query = Uri.encodeComponent(title);
      final url = 'https://api.jikan.moe/v4/anime?q=$query&limit=1';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['data'] != null && (data['data'] as List).isNotEmpty) {
          final anime = data['data'][0];
          int? year;
          if (anime['year'] != null) {
            year = anime['year'] as int?;
          }
          if (year == null && anime['aired'] != null) {
            final prop = anime['aired']['prop'];
            if (prop != null && prop['from'] != null) {
              year = prop['from']['year'] as int?;
            }
            if (year == null && anime['aired']['from'] != null) {
              final fromStr = anime['aired']['from'] as String;
              year = DateTime.tryParse(fromStr)?.year;
            }
          }
          if (year != null) {
            return year;
          }
        }
        return 0; // No results found, cache 0
      } else if (response.statusCode == 404) {
        return 0; // Not found, cache 0
      } else {
        Log.w('Jikan API returned status code ${response.statusCode} for query "$title"');
        return null; // HTTP error, retry later
      }
    } catch (e, stack) {
      Log.e('Error calling Jikan API for query "$title"', e, stack);
      return null;
    }
  }

  Future<int?> fetchMediaReleaseYearFromTmdb(String title, ChannelCategory category) async {
    try {
      final apiKey = Secrets.tmdbApiKey;
      if (apiKey.isNotEmpty && apiKey != 'YOUR_TMDB_API_KEY') {
        final query = Uri.encodeComponent(title);
        final isMovie = category.title == 'Movies';
        final path = isMovie ? 'movie' : 'tv';
        final url = 'https://api.themoviedb.org/3/search/$path?api_key=$apiKey&query=$query&page=1';

        final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        
        if (response.statusCode == 200) {
          final Map<String, dynamic> data = json.decode(response.body);
          final List<dynamic>? results = data['results'];
          if (results != null && results.isNotEmpty) {
            final first = results[0];
            final dateStr = isMovie 
                ? first['release_date'] as String? 
                : first['first_air_date'] as String?;
                
            if (dateStr != null && dateStr.isNotEmpty) {
              final parts = dateStr.split('-');
              if (parts.isNotEmpty) {
                final year = int.tryParse(parts[0]);
                if (year != null && year > 0) {
                  Log.i('Successfully fetched release year from TMDB for $title: $year');
                  return year;
                }
              }
            }
          }
        } else {
          Log.w('TMDB API returned status code ${response.statusCode} for query "$title", falling back to Trakt');
        }
      } else {
        Log.w('TMDB API Key is placeholder, falling back to Trakt');
      }
    } catch (e) {
      Log.w('Error calling TMDB API for query "$title", falling back: $e');
    }

    // TVmaze Fallback for Web Series shows (No API key required)
    if (category.title == 'Web Series') {
      final tvmazeYear = await fetchMediaReleaseYearFromTvmaze(title);
      if (tvmazeYear != null) return tvmazeYear;
    }

    // Secondary fallback to Trakt
    return fetchMediaReleaseYearFromTraktFallback(title, category);
  }

  Future<int?> fetchMediaReleaseYearFromTvmaze(String title) async {
    try {
      final query = Uri.encodeComponent(title);
      final url = 'https://api.tvmaze.com/singlesearch/shows?q=$query';
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final premiered = data['premiered'] as String?;
        if (premiered != null && premiered.isNotEmpty) {
          final parts = premiered.split('-');
          if (parts.isNotEmpty) {
            final year = int.tryParse(parts[0]);
            if (year != null && year > 0) {
              Log.i('Successfully fetched release year from TVmaze for $title: $year');
              return year;
            }
          }
        }
        return -1; // Cache as -1 to indicate permanent skip (not found)
      } else if (response.statusCode == 404) {
        return -1; // Not found on TVmaze, permanent skip
      } else {
        Log.w('TVmaze returned status code ${response.statusCode} for query "$title"');
        return null; // Temporary HTTP error, retry later
      }
    } catch (e, stack) {
      Log.e('Error calling TVmaze API for query "$title"', e, stack);
      return null;
    }
  }

  Future<int?> fetchMediaReleaseYearFromTraktFallback(String title, ChannelCategory category) async {
    try {
      final query = Uri.encodeComponent(title);
      final type = category.title == 'Movies' ? 'movie' : 'show';
      final url = 'https://api.trakt.tv/search/$type?query=$query&limit=1';
      
      final headers = {
        'Content-Type': 'application/json',
        'trakt-api-version': '2',
        'trakt-api-key': Secrets.traktApiKey,
      };

      final response = await http.get(Uri.parse(url), headers: headers).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
          final first = data[0];
          if (first['type'] != null && first[first['type']] != null) {
            final media = first[first['type']];
            final year = media['year'] as int?;
            if (year != null && year > 0) {
              Log.i('Successfully fetched release year from Trakt fallback for $title: $year');
              return year;
            }
          }
        }
        return -1; // No results found, cache -1 to permanently skip
      } else if (response.statusCode == 404) {
        return -1; // Not found, cache -1 to permanently skip
      } else {
        Log.w('Trakt Fallback API returned status code ${response.statusCode} for query "$title"');
        return null; // HTTP error, retry later
      }
    } catch (e, stack) {
      Log.e('Error calling Trakt Fallback API for query "$title"', e, stack);
      return null;
    }
  }
}
