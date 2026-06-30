import 'package:tdlib/td_api.dart' as td;
import '../services/storage_service.dart';

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

  Map<String, dynamic> toJson() => {
        'fullTitle': fullTitle,
        'seasonName': seasonName,
        'posterMessage': posterMessage.toJson(),
        'episodes': episodes.map((e) => e.toJson()).toList(),
      };

  factory AnimeSeason.fromJson(Map<String, dynamic> json) => AnimeSeason(
        fullTitle: json['fullTitle'] as String,
        seasonName: json['seasonName'] as String,
        posterMessage: td.Message.fromJson(json['posterMessage'] as Map<String, dynamic>),
        episodes: (json['episodes'] as List)
            .map((e) => td.Message.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  AnimeSeason copyWith({
    String? fullTitle,
    String? seasonName,
    td.Message? posterMessage,
    List<td.Message>? episodes,
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
    if (cached != null && cached > 0) return cached;

    // Try parsing from fullTitle
    final match = RegExp(r'(?<!\d)(19\d\d|20\d\d)(?!\d)').firstMatch(fullTitle);
    if (match != null) {
      final yr = int.tryParse(match.group(1)!);
      if (yr != null) {
        storage.setSeasonReleaseYear(fullTitle, yr);
        return yr;
      }
    }

    // Try parsing from episodes filenames
    for (final ep in episodes) {
      String? fileName;
      if (ep.content is td.MessageVideo) {
        fileName = (ep.content as td.MessageVideo).video.fileName;
      } else if (ep.content is td.MessageDocument) {
        fileName = (ep.content as td.MessageDocument).document.fileName;
      }
      if (fileName != null && fileName.isNotEmpty) {
        final epMatch = RegExp(r'(?<!\d)(19\d\d|20\d\d)(?!\d)').firstMatch(fileName);
        if (epMatch != null) {
          final yr = int.tryParse(epMatch.group(1)!);
          if (yr != null) {
            storage.setSeasonReleaseYear(fullTitle, yr);
            return yr;
          }
        }
      }
    }
    return null;
  }
}

