import 'package:tdlib/td_api.dart' as td;

class AnimeSeries {
  final String coreName;
  final List<AnimeSeason> seasons;
  TmdbSeriesMetadata? tmdbMetadata;

  AnimeSeries({required this.coreName, required this.seasons, this.tmdbMetadata});
}

class AnimeSeason {
  final String fullTitle;
  final String seasonName;
  final td.Message posterMessage; // The Photo message
  final List<td.Message> episodes; // The Video/Document messages

  AnimeSeason({
    required this.fullTitle,
    required this.seasonName,
    required this.posterMessage,
    required this.episodes,
  });
}

class TmdbSeriesMetadata {
  final String title;
  final String overview;
  final String? posterPath;
  final String? backdropPath;
  final double rating;
  final String releaseDate;
  final List<String> genres;
  final int tmdbId;

  TmdbSeriesMetadata({
    required this.title,
    required this.overview,
    this.posterPath,
    this.backdropPath,
    required this.rating,
    required this.releaseDate,
    required this.genres,
    required this.tmdbId,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'overview': overview,
    'posterPath': posterPath,
    'backdropPath': backdropPath,
    'rating': rating,
    'releaseDate': releaseDate,
    'genres': genres,
    'tmdbId': tmdbId,
  };

  factory TmdbSeriesMetadata.fromJson(Map<String, dynamic> json) => TmdbSeriesMetadata(
    title: json['title'] as String,
    overview: json['overview'] as String,
    posterPath: json['posterPath'] as String?,
    backdropPath: json['backdropPath'] as String?,
    rating: (json['rating'] as num).toDouble(),
    releaseDate: json['releaseDate'] as String,
    genres: List<String>.from(json['genres'] ?? []),
    tmdbId: json['tmdbId'] as int,
  );
}

class TmdbEpisodeMetadata {
  final int episodeNumber;
  final String title;
  final String overview;
  final String? stillPath;

  TmdbEpisodeMetadata({
    required this.episodeNumber,
    required this.title,
    required this.overview,
    this.stillPath,
  });

  Map<String, dynamic> toJson() => {
    'episodeNumber': episodeNumber,
    'title': title,
    'overview': overview,
    'stillPath': stillPath,
  };

  factory TmdbEpisodeMetadata.fromJson(Map<String, dynamic> json) => TmdbEpisodeMetadata(
    episodeNumber: json['episodeNumber'] as int,
    title: json['title'] as String,
    overview: json['overview'] as String,
    stillPath: json['stillPath'] as String?,
  );
}

