import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/constants.dart';
import '../core/logger.dart';

class RelatedContent {
  final int id;
  final String title;
  final String posterUrl;
  final String synopsis;

  RelatedContent({
    required this.id,
    required this.title,
    required this.posterUrl,
    required this.synopsis,
  });
}

class SeriesMetadata {
  final String title;
  final String synopsis;
  final String posterUrl;
  final String backdropUrl;
  final String releaseYear;
  final List<String> genres;
  final String cast;
  final String maturityRating;
  final String trailerYoutubeId;
  final String status;
  final String runtime;
  final String productionCompanies;
  final String userScore;
  final String rank;
  final String source;
  final String airedDates;
  final String episodesCount;
  final String spokenLanguages;
  final String budgetRevenue;
  final String director;
  final String writers;
  final String imdbId;
  final String malId;
  final List<RelatedContent> recommendations;

  SeriesMetadata({
    required this.title,
    required this.synopsis,
    required this.posterUrl,
    required this.backdropUrl,
    required this.releaseYear,
    required this.genres,
    required this.cast,
    required this.maturityRating,
    required this.trailerYoutubeId,
    this.status = '',
    this.runtime = '',
    this.productionCompanies = '',
    this.userScore = '',
    this.rank = '',
    this.source = '',
    this.airedDates = '',
    this.episodesCount = '',
    this.spokenLanguages = '',
    this.budgetRevenue = '',
    this.director = '',
    this.writers = '',
    this.imdbId = '',
    this.malId = '',
    this.recommendations = const [],
  });

  factory SeriesMetadata.empty() {
    return SeriesMetadata(
      title: '',
      synopsis: '',
      posterUrl: '',
      backdropUrl: '',
      releaseYear: '',
      genres: [],
      cast: '',
      maturityRating: '',
      trailerYoutubeId: '',
    );
  }
}

class MetadataService {
  static const String _tmdbBaseUrl = 'https://api.themoviedb.org/3';
  static const String _jikanBaseUrl = 'https://api.jikan.moe/v4';
  
  static final Map<String, SeriesMetadata> _cache = {};

  Future<SeriesMetadata?> fetchTmdbByImdbId(String imdbId) async {
    if (_cache.containsKey(imdbId)) return _cache[imdbId];
    
    if (Constants.tmdbApiKey == 'YOUR_TMDB_API_KEY' || Constants.tmdbApiKey.isEmpty) {
      Log.e('TMDB API Key is missing. Cannot fetch metadata.');
      return null;
    }

    try {
      // Step 1: Find TMDB ID from IMDB ID
      final findUrl = Uri.parse('$_tmdbBaseUrl/find/$imdbId?external_source=imdb_id&api_key=${Constants.tmdbApiKey}');
      final findRes = await http.get(findUrl);
      if (findRes.statusCode != 200) return null;

      final findData = jsonDecode(findRes.body);
      bool isMovie = false;
      int? tmdbId;

      if (findData['tv_results'] != null && findData['tv_results'].isNotEmpty) {
        tmdbId = findData['tv_results'][0]['id'];
        isMovie = false;
      } else if (findData['movie_results'] != null && findData['movie_results'].isNotEmpty) {
        tmdbId = findData['movie_results'][0]['id'];
        isMovie = true;
      } else {
        return null;
      }

      // Step 2: Fetch full details including videos and credits
      final type = isMovie ? 'movie' : 'tv';
      final detailsUrl = Uri.parse('$_tmdbBaseUrl/$type/$tmdbId?api_key=${Constants.tmdbApiKey}&append_to_response=videos,credits,content_ratings,release_dates,recommendations');
      final detailsRes = await http.get(detailsUrl);
      if (detailsRes.statusCode != 200) return null;

      final data = jsonDecode(detailsRes.body);

      // Extract trailer
      String trailerId = '';
      if (data['videos'] != null && data['videos']['results'] != null) {
        final List videos = data['videos']['results'];
        final trailer = videos.firstWhere(
          (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
          orElse: () => videos.isNotEmpty && videos.first['site'] == 'YouTube' ? videos.first : null,
        );
        if (trailer != null) {
          trailerId = trailer['key'] ?? '';
        }
      }

      // Extract cast, director, and writers
      List<String> castList = [];
      List<String> directors = [];
      List<String> writers = [];
      if (data['credits'] != null) {
        if (data['credits']['cast'] != null) {
          final List cast = data['credits']['cast'];
          for (int i = 0; i < cast.length && i < 6; i++) {
            castList.add(cast[i]['name']);
          }
        }
        if (data['credits']['crew'] != null) {
          final List crew = data['credits']['crew'];
          for (var member in crew) {
            if (member['job'] == 'Director') {
              directors.add(member['name']);
            } else if (member['department'] == 'Writing' || member['job'] == 'Screenplay' || member['job'] == 'Writer') {
              if (!writers.contains(member['name'])) {
                writers.add(member['name']);
              }
            }
          }
        }
      }

      // Extract rating
      String rating = 'NR';
      if (isMovie) {
        if (data['release_dates'] != null && data['release_dates']['results'] != null) {
          final List results = data['release_dates']['results'];
          final us = results.firstWhere((r) => r['iso_3166_1'] == 'US', orElse: () => null);
          if (us != null && us['release_dates'] != null && us['release_dates'].isNotEmpty) {
            rating = us['release_dates'][0]['certification'] ?? 'NR';
          }
        }
      } else {
        if (data['content_ratings'] != null && data['content_ratings']['results'] != null) {
          final List results = data['content_ratings']['results'];
          final us = results.firstWhere((r) => r['iso_3166_1'] == 'US', orElse: () => null);
          if (us != null) {
            rating = us['rating'] ?? 'NR';
          }
        }
      }
      if (rating.isEmpty) rating = 'NR';

      // Genres
      List<String> genres = [];
      if (data['genres'] != null) {
        final List g = data['genres'];
        genres = g.map((e) => e['name'].toString()).toList();
      }

      final dateStr = isMovie ? (data['release_date'] ?? '') : (data['first_air_date'] ?? '');
      final year = dateStr.isNotEmpty && dateStr.length >= 4 ? dateStr.substring(0, 4) : '';
      
      final status = data['status'] ?? '';
      
      String runtime = '';
      if (isMovie && data['runtime'] != null && data['runtime'] > 0) {
        runtime = '${data['runtime']} min';
      } else if (!isMovie && data['episode_run_time'] != null && data['episode_run_time'].isNotEmpty) {
        runtime = '${data['episode_run_time'][0]} min/ep';
      } else if (!isMovie && data['number_of_seasons'] != null) {
        runtime = '${data['number_of_seasons']} Seasons, ${data['number_of_episodes']} Episodes';
      }

      String productionCompanies = '';
      if (data['production_companies'] != null) {
        final List pc = data['production_companies'];
        productionCompanies = pc.map((e) => e['name'].toString()).join(', ');
      }

      List<RelatedContent> recs = [];
      if (data['recommendations'] != null && data['recommendations']['results'] != null) {
        final List r = data['recommendations']['results'];
        for (var rec in r) {
          if (rec['poster_path'] != null) {
            recs.add(RelatedContent(
              id: rec['id'] ?? 0,
              title: rec['title'] ?? rec['name'] ?? '',
              posterUrl: 'https://image.tmdb.org/t/p/w500${rec['poster_path']}',
              synopsis: rec['overview'] ?? '',
            ));
          }
        }
      }

      String userScore = '';
      if (data['vote_average'] != null) {
        userScore = '${(data['vote_average'] * 10).toInt()}%';
      }

      String spokenLanguages = '';
      if (data['spoken_languages'] != null) {
        final List sl = data['spoken_languages'];
        spokenLanguages = sl.map((e) => e['english_name'] ?? e['name']).join(', ');
      }

      String budgetRevenue = '';
      if (isMovie && data['budget'] != null && data['budget'] > 0) {
        budgetRevenue = 'Budget: \$${(data['budget'] / 1000000).toStringAsFixed(1)}M';
        if (data['revenue'] != null && data['revenue'] > 0) {
          budgetRevenue += ' / Box Office: \$${(data['revenue'] / 1000000).toStringAsFixed(1)}M';
        }
      }

      final metadata = SeriesMetadata(
        title: isMovie ? (data['title'] ?? data['original_title']) : (data['name'] ?? data['original_name']),
        synopsis: data['overview'] ?? '',
        posterUrl: data['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${data['poster_path']}' : '',
        backdropUrl: data['backdrop_path'] != null ? 'https://image.tmdb.org/t/p/original${data['backdrop_path']}' : '',
        releaseYear: year,
        genres: genres,
        cast: castList.join(', '),
        maturityRating: rating,
        trailerYoutubeId: trailerId,
        status: status,
        runtime: runtime,
        productionCompanies: productionCompanies,
        userScore: userScore,
        spokenLanguages: spokenLanguages,
        budgetRevenue: budgetRevenue,
        director: directors.join(', '),
        writers: writers.join(', '),
        imdbId: imdbId,
        recommendations: recs,
      );
      _cache[imdbId] = metadata;
      return metadata;
    } catch (e) {
      Log.e('Failed to fetch TMDB details', e);
      return null;
    }
  }

  Future<SeriesMetadata?> fetchJikanByMalId(String malId) async {
    if (_cache.containsKey(malId)) return _cache[malId];
    
    try {
      final url = Uri.parse('$_jikanBaseUrl/anime/$malId/full');
      final res = await http.get(url);
      if (res.statusCode != 200) return null;

      final json = jsonDecode(res.body);
      final data = json['data'];

      if (data == null) return null;

      String trailerId = '';
      if (data['trailer'] != null) {
        if (data['trailer']['youtube_id'] != null) {
          trailerId = data['trailer']['youtube_id'];
        } else if (data['trailer']['embed_url'] != null) {
          final embedUrl = data['trailer']['embed_url'].toString();
          final match = RegExp(r'embed\/([a-zA-Z0-9_-]+)').firstMatch(embedUrl);
          if (match != null && match.groupCount >= 1) {
            trailerId = match.group(1)!;
          }
        }
      }

      List<String> genres = [];
      if (data['genres'] != null) {
        final List g = data['genres'];
        genres = g.map((e) => e['name'].toString()).toList();
      }

      final dateStr = data['aired'] != null ? (data['aired']['from'] ?? '') : '';
      final year = dateStr.isNotEmpty && dateStr.length >= 4 ? dateStr.substring(0, 4) : '';
      
      final status = data['status'] ?? '';
      final runtime = data['duration'] ?? '';
      
      String productionCompanies = '';
      if (data['studios'] != null) {
        final List st = data['studios'];
        productionCompanies = st.map((e) => e['name'].toString()).join(', ');
      }

      List<RelatedContent> recs = [];
      try {
        final recUrl = Uri.parse('$_jikanBaseUrl/anime/$malId/recommendations');
        final recRes = await http.get(recUrl);
        if (recRes.statusCode == 200) {
          final recJson = jsonDecode(recRes.body);
          if (recJson['data'] != null) {
            final List r = recJson['data'];
            for (int i = 0; i < r.length && i < 10; i++) {
              final entry = r[i]['entry'];
              if (entry != null) {
                recs.add(RelatedContent(
                  id: entry['mal_id'] ?? 0,
                  title: entry['title'] ?? '',
                  posterUrl: entry['images']?['jpg']?['large_image_url'] ?? '',
                  synopsis: '',
                ));
              }
            }
          }
        }
      } catch (e) {
        Log.e('Failed to fetch Jikan recommendations', e);
      }
      
      String userScore = '';
      if (data['score'] != null) {
        userScore = '${data['score']} / 10';
      }

      String rank = '';
      if (data['rank'] != null) {
        rank = '#${data['rank']}';
      }

      String source = data['source'] ?? '';
      
      String airedDates = '';
      if (data['aired'] != null && data['aired']['string'] != null) {
        airedDates = data['aired']['string'];
      }

      String episodesCount = '';
      if (data['episodes'] != null) {
        episodesCount = '${data['episodes']} Episodes';
      }

      final metadata = SeriesMetadata(
        title: data['title_english'] ?? data['title'] ?? '',
        synopsis: data['synopsis'] ?? '',
        posterUrl: data['images']?['jpg']?['large_image_url'] ?? '',
        backdropUrl: trailerId.isNotEmpty ? 'https://img.youtube.com/vi/$trailerId/maxresdefault.jpg' : (data['images']?['jpg']?['large_image_url'] ?? ''), // Jikan has no backdrop
        releaseYear: year,
        genres: genres,
        cast: 'Anime Cast', 
        maturityRating: data['rating'] ?? 'NR',
        trailerYoutubeId: trailerId,
        status: status,
        runtime: runtime,
        productionCompanies: productionCompanies,
        userScore: userScore,
        rank: rank,
        source: source,
        airedDates: airedDates,
        episodesCount: episodesCount,
        malId: malId,
        recommendations: recs,
      );
      _cache[malId] = metadata;
      return metadata;
    } catch (e) {
      Log.e('Failed to fetch Jikan details', e);
      return null;
    }
  }

  static String? extractImdbId(String url) {
    final match = RegExp(r'title\/(tt\d+)').firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    if (url.startsWith('tt')) return url;
    return null;
  }

  static List<String> extractAllImdbIds(String text) {
    final matches = RegExp(r'title\/(tt\d+)').allMatches(text);
    final ids = matches.map((m) => m.group(1)!).toList();
    if (ids.isEmpty) {
      // split by whitespace/comma and check if any starts with tt
      final parts = text.split(RegExp(r'[\s,]+'));
      for (var p in parts) {
        if (p.startsWith('tt')) ids.add(p);
      }
    }
    return ids;
  }

  static String? extractMalId(String url) {
    final match = RegExp(r'anime\/(\d+)').firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      return match.group(1);
    }
    if (int.tryParse(url) != null) return url;
    return null;
  }

  static List<String> extractAllMalIds(String text) {
    final matches = RegExp(r'anime\/(\d+)').allMatches(text);
    final ids = matches.map((m) => m.group(1)!).toList();
    if (ids.isEmpty) {
      final parts = text.split(RegExp(r'[\s,]+'));
      for (var p in parts) {
        if (int.tryParse(p) != null) ids.add(p);
      }
    }
    return ids;
  }
}
