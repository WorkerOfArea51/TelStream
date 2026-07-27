import 'dart:convert';
import 'package:tdlib/td_api.dart' as td;
import '../services/storage_service.dart';
import '../../core/utils/td_json_util.dart';
import 'episode.dart';
import '../services/episode_grouper.dart';

class AnimeSeries {
  final String coreName;
  final List<AnimeSeason> seasons;

  AnimeSeries({required this.coreName, required this.seasons});

  Map<String, dynamic> toJson() => {
        'coreName': coreName,
        'seasons': seasons.map((s) => s.toJson()).toList(),
      };

  factory AnimeSeries.fromJson(Map<String, dynamic> json) => AnimeSeries(
        coreName: json['coreName'] as String,
        seasons: (json['seasons'] as List)
            .map((s) => AnimeSeason.fromJson(s as Map<String, dynamic>))
            .toList(),
      );
}

class AnimeSeason {
  static final RegExp _yearRegex = RegExp(r'(?<!\d)(19\d{2}|20[0-4]\d)(?!\d)');
  static final int _currentYearUpperBound = DateTime.now().year + 1;

  final String fullTitle;
  final String seasonName;
  td.Message posterMessage; // The Photo message
  final List<Episode> episodes;

  AnimeSeason({
    required this.fullTitle,
    required this.seasonName,
    required this.posterMessage,
    required this.episodes,
  });

  Map<String, dynamic> toJson() => {
        'fullTitle': fullTitle,
        'seasonName': seasonName,
        'posterMessage': posterMessage.toJson(),
        'episodes': episodes.map((e) => e.toFlatJson()).toList(),
      };

  factory AnimeSeason.fromJson(Map<String, dynamic> json) {
    td.Message parseMessage(dynamic raw) {
      final map = TdJsonUtil.sanitize(raw as Map<String, dynamic>);
      return td.convertToObject(jsonEncode(map)) as td.Message;
    }
    
    final rawEpisodes = json['episodes'] as List;
    bool needsMigration = false;
    List<td.Message> legacyMessages = [];
    
    // Migration trigger 1: old cache format with raw td.Message objects
    if (rawEpisodes.isNotEmpty && rawEpisodes.first is Map<String, dynamic> && rawEpisodes.first.containsKey('@type')) {
       needsMigration = true;
       for (var e in rawEpisodes) {
           legacyMessages.add(parseMessage(e));
       }
    }
    
    // Migration trigger 2: episodes missing the new minithumbnailData field
    // (added in v2.13.1). Force re-grouping to populate thumbnails.
    if (!needsMigration && rawEpisodes.isNotEmpty) {
      final firstEp = rawEpisodes.first as Map<String, dynamic>;
      if (!firstEp.containsKey('sources')) {
        needsMigration = true;
      } else {
        final sources = firstEp['sources'] as List;
        if (sources.isNotEmpty) {
          final firstSource = sources.first as Map<String, dynamic>;
          if (!firstSource.containsKey('minithumbnailData')) {
            needsMigration = true;
          }
        }
      }
    }
    
    // If migration is needed but we don't have legacy messages, we need to
    // signal that the cache should be rebuilt from network. For now, just
    // parse what we have — the UI will show placeholders until refresh.
    if (needsMigration && legacyMessages.isEmpty && rawEpisodes.isNotEmpty) {
      // Cache is in Episode.fromFlatJson format but missing new fields.
      // Parse normally — thumbnails will appear after the next network sync.
      needsMigration = false;
    }

    List<Episode> episodesList;
    if (needsMigration) {
       episodesList = EpisodeGrouper.groupEpisodes(legacyMessages);
    } else {
       episodesList = rawEpisodes.map((e) => Episode.fromFlatJson(e as Map<String, dynamic>)).toList();
    }

    return AnimeSeason(
      fullTitle: json['fullTitle'] as String,
      seasonName: json['seasonName'] as String,
      posterMessage: parseMessage(json['posterMessage']),
      episodes: episodesList,
    );
  }

  AnimeSeason copyWith({
    String? fullTitle,
    String? seasonName,
    td.Message? posterMessage,
    List<Episode>? episodes,
  }) {
    return AnimeSeason(
      fullTitle: fullTitle ?? this.fullTitle,
      seasonName: seasonName ?? this.seasonName,
      posterMessage: posterMessage ?? this.posterMessage,
      episodes: episodes ?? this.episodes,
    );
  }

  int? getReleaseYear(StorageService storage) {
    final cached = storage.getSeasonReleaseYear(fullTitle);
    return (cached != null && cached > 0 && cached <= _currentYearUpperBound)
        ? cached
        : null;
  }

  int? computeReleaseYear(StorageService storage) {
    final cached = getReleaseYear(storage);
    if (cached != null) return cached;

    int? extractYear(String source) {
      final match = _yearRegex.firstMatch(source);
      if (match == null) return null;
      final yr = int.tryParse(match.group(1)!);
      if (yr == null || yr > _currentYearUpperBound) return null;
      return yr;
    }

    final fromTitle = extractYear(fullTitle);
    if (fromTitle != null) {
      storage.setSeasonReleaseYear(fullTitle, fromTitle);
      return fromTitle;
    }

    for (final ep in episodes) {
      final fileName = ep.defaultSource?.fileName;
      if (fileName != null && fileName.isNotEmpty) {
        final fromEp = extractYear(fileName);
        if (fromEp != null) {
          storage.setSeasonReleaseYear(fullTitle, fromEp);
          return fromEp;
        }
      }
    }
    return null;
  }
}
