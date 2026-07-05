import 'package:tdlib/td_api.dart' as td;
import '../services/storage_service.dart';
import '../../core/utils/td_json_util.dart';

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

  factory AnimeSeason.fromJson(Map<String, dynamic> json) {
    td.Message parseMessage(dynamic raw) {
      final map = TdJsonUtil.sanitize(raw as Map<String, dynamic>);
      return td.Message.fromJson(map);
    }
    return AnimeSeason(
      fullTitle: json['fullTitle'] as String,
      seasonName: json['seasonName'] as String,
      posterMessage: parseMessage(json['posterMessage']),
      episodes: (json['episodes'] as List).map((e) => parseMessage(e)).toList(),
    );
  }

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
      String? fileName;
      if (ep.content is td.MessageVideo) {
        fileName = (ep.content as td.MessageVideo).video.fileName;
      } else if (ep.content is td.MessageDocument) {
        fileName = (ep.content as td.MessageDocument).document.fileName;
      }
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

