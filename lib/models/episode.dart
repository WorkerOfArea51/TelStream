import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tdlib/td_api.dart' as td;
import 'video_source.dart';

part 'episode.freezed.dart';
part 'episode.g.dart';

@freezed
abstract class Episode with _$Episode {
  const factory Episode({
    required String title,
    @Default([]) List<VideoSource> sources,
    @Default(false) bool isMetadataExtracted,
  }) = _Episode;

  const Episode._();

  factory Episode.fromJson(Map<String, dynamic> json) => _$EpisodeFromJson(json);

  /// Helper to get the best quality source (highest resolution)
  VideoSource? get bestSource {
    if (sources.isEmpty) return null;
    return sources.reduce((curr, next) => (curr.height > next.height) ? curr : next);
  }

  /// Original representation for fallback compat (returns best source message)
  td.Message? get message => bestSource?.message;
}
