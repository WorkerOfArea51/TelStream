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

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'posterUrl': posterUrl,
      'synopsis': synopsis,
    };
  }

  factory RelatedContent.fromJson(Map<String, dynamic> json) {
    return RelatedContent(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      posterUrl: json['posterUrl'] ?? '',
      synopsis: json['synopsis'] ?? '',
    );
  }
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

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'synopsis': synopsis,
      'posterUrl': posterUrl,
      'backdropUrl': backdropUrl,
      'releaseYear': releaseYear,
      'genres': genres,
      'cast': cast,
      'maturityRating': maturityRating,
      'trailerYoutubeId': trailerYoutubeId,
      'status': status,
      'runtime': runtime,
      'productionCompanies': productionCompanies,
      'userScore': userScore,
      'rank': rank,
      'source': source,
      'airedDates': airedDates,
      'episodesCount': episodesCount,
      'spokenLanguages': spokenLanguages,
      'budgetRevenue': budgetRevenue,
      'director': director,
      'writers': writers,
      'imdbId': imdbId,
      'malId': malId,
      'recommendations': recommendations.map((e) => e.toJson()).toList(),
    };
  }

  factory SeriesMetadata.fromJson(Map<String, dynamic> json) {
    return SeriesMetadata(
      title: json['title'] ?? '',
      synopsis: json['synopsis'] ?? '',
      posterUrl: json['posterUrl'] ?? '',
      backdropUrl: json['backdropUrl'] ?? '',
      releaseYear: json['releaseYear'] ?? '',
      genres: List<String>.from(json['genres'] ?? []),
      cast: json['cast'] ?? '',
      maturityRating: json['maturityRating'] ?? '',
      trailerYoutubeId: json['trailerYoutubeId'] ?? '',
      status: json['status'] ?? '',
      runtime: json['runtime'] ?? '',
      productionCompanies: json['productionCompanies'] ?? '',
      userScore: json['userScore'] ?? '',
      rank: json['rank'] ?? '',
      source: json['source'] ?? '',
      airedDates: json['airedDates'] ?? '',
      episodesCount: json['episodesCount'] ?? '',
      spokenLanguages: json['spokenLanguages'] ?? '',
      budgetRevenue: json['budgetRevenue'] ?? '',
      director: json['director'] ?? '',
      writers: json['writers'] ?? '',
      imdbId: json['imdbId'] ?? '',
      malId: json['malId'] ?? '',
      recommendations: (json['recommendations'] as List?)
              ?.map((e) => RelatedContent.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

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
      status: '',
      runtime: '',
      productionCompanies: '',
      userScore: '',
      rank: '',
      source: '',
      airedDates: '',
      episodesCount: '',
      spokenLanguages: '',
      budgetRevenue: '',
      director: '',
      writers: '',
      imdbId: '',
      malId: '',
      recommendations: const [],
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
      final isJwt = Constants.tmdbApiKey.length > 50;
      final authHeaders = isJwt ? {'Authorization': 'Bearer ${Constants.tmdbApiKey}', 'Accept': 'application/json'} : {'Accept': 'application/json'};
      final queryParam = isJwt ? '' : '&api_key=${Constants.tmdbApiKey}';

      // Step 1: Find TMDB ID from IMDB ID
      final findUrl = Uri.parse('$_tmdbBaseUrl/find/$imdbId?external_source=imdb_id$queryParam');
      final findRes = await http.get(findUrl, headers: authHeaders);
      if (findRes.statusCode != 200) {
        Log.e('TMDB Find API failed with status ${findRes.statusCode}');
        return null;
      }

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
      final detailsUrl = Uri.parse('$_tmdbBaseUrl/$type/$tmdbId?append_to_response=videos,credits,content_ratings,release_dates,recommendations$queryParam');
      final detailsRes = await http.get(detailsUrl, headers: authHeaders);
      if (detailsRes.statusCode != 200) {
        Log.e('TMDB Details API failed with status ${detailsRes.statusCode}');
        return null;
      }

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

  /// Fetches season-specific metadata from TMDB.
  /// Uses the show's IMDB ID to find the TMDB ID, then fetches
  /// /tv/{tmdb_id}/season/{seasonNumber} for season-specific data.
  Future<SeriesMetadata?> fetchTmdbSeasonByImdbId(String imdbId, int seasonNumber) async {
    final cacheKey = '${imdbId}_season_$seasonNumber';
    if (_cache.containsKey(cacheKey)) return _cache[cacheKey];
    
    if (Constants.tmdbApiKey == 'YOUR_TMDB_API_KEY' || Constants.tmdbApiKey.isEmpty) {
      Log.e('TMDB API Key is missing. Cannot fetch season metadata.');
      return null;
    }

    try {
      final isJwt = Constants.tmdbApiKey.length > 50;
      final authHeaders = isJwt 
          ? {'Authorization': 'Bearer ${Constants.tmdbApiKey}', 'Accept': 'application/json'} 
          : {'Accept': 'application/json'};
      final queryParam = isJwt ? '' : '&api_key=${Constants.tmdbApiKey}';

      // Step 1: Find TMDB ID from IMDB ID
      final findUrl = Uri.parse('$_tmdbBaseUrl/find/$imdbId?external_source=imdb_id$queryParam');
      final findRes = await http.get(findUrl, headers: authHeaders);
      if (findRes.statusCode != 200) {
        Log.e('TMDB Find API failed with status ${findRes.statusCode}');
        return null;
      }

      final findData = jsonDecode(findRes.body);
      int? tmdbId;

      if (findData['tv_results'] != null && findData['tv_results'].isNotEmpty) {
        tmdbId = findData['tv_results'][0]['id'];
      } else {
        return null;
      }

      // Step 2: Fetch season-specific details
      final seasonUrl = Uri.parse('$_tmdbBaseUrl/tv/$tmdbId/season/$seasonNumber?append_to_response=credits,images,videos$queryParam');
      final seasonRes = await http.get(seasonUrl, headers: authHeaders);
      if (seasonRes.statusCode != 200) {
        Log.e('TMDB Season API failed with status ${seasonRes.statusCode}');
        // Fallback to show-level metadata
        return await fetchTmdbByImdbId(imdbId);
      }

      final data = jsonDecode(seasonRes.body);

      // Also fetch show-level data for fallback fields (genres, content rating)
      final showUrl = Uri.parse('$_tmdbBaseUrl/tv/$tmdbId?append_to_response=content_ratings,recommendations,credits,videos$queryParam');
      final showRes = await http.get(showUrl, headers: authHeaders);
      Map<String, dynamic>? showData;
      if (showRes.statusCode == 200) {
        showData = jsonDecode(showRes.body);
      }

      // Extract season-specific data
      String posterPath = data['poster_path'] ?? '';
      String backdropPath = (data['images']?['backdrops']?.isNotEmpty ?? false) 
          ? (data['images']['backdrops'][0]['file_path'] ?? '') 
          : '';
      
      String overview = data['overview'] ?? '';
      if (overview.isEmpty && showData != null) {
        overview = showData['overview'] ?? '';
      }

      String airDate = data['air_date'] ?? '';
      String releaseYear = airDate.isNotEmpty ? airDate.substring(0, 4) : '';

      // Extract trailer
      String trailerId = '';
      if (data['videos'] != null && data['videos']['results'] != null) {
        final List videos = data['videos']['results'];
        final trailer = videos.firstWhere(
          (v) => v['site'] == 'YouTube' && v['type'] == 'Trailer',
          orElse: () => videos.isNotEmpty ? videos.first : null,
        );
        if (trailer != null) {
          trailerId = trailer['key'] ?? '';
        }
      }

      // Extract cast from season credits
      List<String> castList = [];
      if (data['credits'] != null && data['credits']['cast'] != null) {
        final List cast = data['credits']['cast'];
        for (int i = 0; i < cast.length && i < 15; i++) {
          castList.add(cast[i]['name'] ?? '');
        }
      }

      // Extract genres from show-level data (seasons don't have genres)
      List<String> genres = [];
      if (showData != null && showData['genres'] != null) {
        for (final g in showData['genres']) {
          genres.add(g['name'] ?? '');
        }
      }

      // Extract maturity rating from show-level data
      String maturityRating = '';
      if (showData != null && showData['content_ratings'] != null && 
          showData['content_ratings']['results'] != null) {
        final List ratings = showData['content_ratings']['results'];
        if (ratings.isNotEmpty) {
          maturityRating = ratings[0]['rating'] ?? '';
        }
      }

      // Extract recommendations from show-level data
      List<RelatedContent> recommendations = [];
      if (showData != null && showData['recommendations'] != null && 
          showData['recommendations']['results'] != null) {
        final List recs = showData['recommendations']['results'];
        for (int i = 0; i < recs.length && i < 10; i++) {
          final r = recs[i];
          recommendations.add(RelatedContent(
            id: r['id'] ?? 0,
            title: r['name'] ?? r['title'] ?? '',
            posterUrl: r['poster_path'] != null ? 'https://image.tmdb.org/t/p/w500${r['poster_path']}' : '',
            synopsis: r['overview'] ?? '',
          ));
        }
      }

      // Extract director and writers from show-level credits
      String director = '';
      List<String> writers = [];
      if (showData != null && showData['credits'] != null) {
        final credits = showData['credits'];
        if (credits['crew'] != null) {
          for (final crew in credits['crew']) {
            final job = crew['job'] ?? '';
            if (job == 'Director' && director.isEmpty) {
              director = crew['name'] ?? '';
            }
            if (job == 'Writer' || job == 'Screenplay' || job == 'Story') {
              final name = crew['name'] ?? '';
              if (name.isNotEmpty && !writers.contains(name)) {
                writers.add(name);
              }
            }
          }
        }
      }

      // Extract status, runtime, episodes count from show-level data
      String status = showData?['status'] ?? '';
      String runtime = '';
      if (showData != null) {
        final numSeasons = showData['number_of_seasons'] ?? 0;
        final numEpisodes = showData['number_of_episodes'] ?? 0;
        if (numSeasons > 0 && numEpisodes > 0) {
          runtime = '$numSeasons Seasons, $numEpisodes Episodes';
        }
      }
      
      // Episode count for this season
      String episodesCount = '';
      if (data['episodes'] != null) {
        final episodeList = data['episodes'] as List;
        episodesCount = '${episodeList.length} Episodes';
      }

      // Extract user score from show-level data
      String userScore = '';
      if (showData != null && showData['vote_average'] != null) {
        final score = (showData['vote_average'] as num).toDouble();
        if (score > 0) {
          userScore = '${score.toStringAsFixed(1)}/10';
        }
      }

      // Extract air dates
      String airedDates = '';
      if (data['air_date'] != null) {
        airedDates = data['air_date'];
      }

      final metadata = SeriesMetadata(
        title: data['name'] ?? '',
        synopsis: overview,
        posterUrl: posterPath.isNotEmpty ? 'https://image.tmdb.org/t/p/w500$posterPath' : '',
        backdropUrl: backdropPath.isNotEmpty ? 'https://image.tmdb.org/t/p/original$backdropPath' : '',
        releaseYear: releaseYear,
        genres: genres,
        cast: castList.join(', '),
        director: director,
        writers: writers.join(', '),
        status: status,
        runtime: runtime,
        episodesCount: episodesCount,
        userScore: userScore,
        maturityRating: maturityRating,
        trailerYoutubeId: trailerId,
        imdbId: imdbId,
        malId: '',
        recommendations: recommendations,
        rank: '',
        airedDates: airedDates,
      );

      _cache[cacheKey] = metadata;
      return metadata;
    } catch (e, stackTrace) {
      Log.e('Error fetching TMDB season metadata for $imdbId season $seasonNumber', e, stackTrace);
      // Fallback to show-level metadata
      return await fetchTmdbByImdbId(imdbId);
    }
  }

  Future<SeriesMetadata?> fetchJikanByMalId(String malId) async {
    if (_cache.containsKey(malId)) return _cache[malId];
    
    try {
      final url = Uri.parse('$_jikanBaseUrl/anime/$malId/full');
      http.Response? res;
      for (int attempt = 0; attempt < 3; attempt++) {
        res = await http.get(url);
        if (res.statusCode == 429 || res.statusCode >= 500) {
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
            continue;
          }
        }
        break;
      }
      if (res == null || res.statusCode != 200) return null;

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
        http.Response? recRes;
        for (int attempt = 0; attempt < 3; attempt++) {
          recRes = await http.get(recUrl);
          if (recRes.statusCode == 429 || recRes.statusCode >= 500) {
            if (attempt < 2) {
              await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
              continue;
            }
          }
          break;
        }
        if (recRes != null && recRes.statusCode == 200) {
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

      String castStr = '';
      try {
        final castUrl = Uri.parse('$_jikanBaseUrl/anime/$malId/characters');
        http.Response? castRes;
        for (int attempt = 0; attempt < 3; attempt++) {
          castRes = await http.get(castUrl);
          if (castRes.statusCode == 429 || castRes.statusCode >= 500) {
            if (attempt < 2) {
              await Future.delayed(Duration(milliseconds: 1000 * (attempt + 1)));
              continue;
            }
          }
          break;
        }
        if (castRes != null && castRes.statusCode == 200) {
          final castJson = jsonDecode(castRes.body);
          if (castJson['data'] != null) {
            final List c = castJson['data'];
            List<String> actors = [];
            for (int i = 0; i < c.length && actors.length < 8; i++) {
              final character = c[i]['character'];
              final voiceActors = c[i]['voice_actors'] as List?;
              String actorName = '';
              if (voiceActors != null && voiceActors.isNotEmpty) {
                 final jpActor = voiceActors.firstWhere(
                   (v) => v['language'] == 'Japanese', 
                   orElse: () => voiceActors.first
                 );
                 if (jpActor['person'] != null) {
                   actorName = jpActor['person']['name'] ?? '';
                 }
              }
              if (actorName.isNotEmpty) {
                if (actorName.contains(',')) {
                  final parts = actorName.split(',');
                  if (parts.length == 2) {
                    actorName = '${parts[1].trim()} ${parts[0].trim()}';
                  }
                }
                actors.add(actorName.trim());
              } else if (character != null && character['name'] != null) {
                String charName = character['name'];
                if (charName.contains(',')) {
                  final parts = charName.split(',');
                  if (parts.length == 2) {
                    charName = '${parts[1].trim()} ${parts[0].trim()}';
                  }
                }
                actors.add(charName.trim());
              }
            }
            if (actors.isNotEmpty) {
              castStr = actors.join(', ');
            }
          }
        }
      } catch (e) {
        Log.e('Failed to fetch Jikan cast', e);
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
        cast: castStr, 
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
