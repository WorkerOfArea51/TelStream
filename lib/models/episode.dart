import 'package:freezed_annotation/freezed_annotation.dart';
import 'video_source.dart';

part 'episode.freezed.dart';

@freezed
abstract class Episode with _$Episode {
  const factory Episode({
    required String title,
    @Default([]) List<VideoSource> sources,
    @Default(false) bool isMetadataExtracted,
    int? episodeNumber,
  }) = _Episode;

  const Episode._();

  /// Best source = highest confirmed metadata, else first source.
  VideoSource? get defaultSource {
    if (sources.isEmpty) return null;
    final withMeta = sources.where((s) => s.hasMetadata).toList();
    if (withMeta.isNotEmpty) {
      withMeta.sort((a, b) => b.qualityRank.compareTo(a.qualityRank));
      return withMeta.first;
    }
    return sources.first;
  }

  /// Sorted highest-quality first.
  List<VideoSource> get sortedSources {
    return [...sources]..sort((a, b) => b.qualityRank.compareTo(a.qualityRank));
  }

  /// True only when there are 2+ sources with non-zero height AND their
  /// quality labels differ.
  ///
  /// This uses the relaxed `VideoSource.hasMetadata` (height > 0, regardless
  /// of container type), so the gear icon appears immediately for grouped
  /// movies — even before container parsing has completed.
  ///
  /// If all sources have height 0 (metadata extraction hasn't run), this
  /// returns false. That's correct: we can't claim "multiple qualities" if
  /// we don't know any dimensions.
  ///
  /// Also handles the edge case where all sources have the same height
  /// (e.g. two copies of the same 1080p encode) — that's NOT multiple
  /// qualities, so we return false.
  bool get hasMultipleQualities {
    if (sources.length < 2) return false;
    final labels = sources
        .where((s) => s.hasQualityLabel)
        .map((s) => s.qualityLabel)
        .toSet();
    return labels.length > 1;
  }

  /// For backwards compat — many call sites expect a single messageId / chatId.
  int? get messageId => defaultSource?.messageId;
  int? get chatId => defaultSource?.chatId;

  factory Episode.fromFlatJson(Map<String, dynamic> json) {
    final sourcesRaw = json['sources'] as List? ?? [];
    return Episode(
      title: json['title'] as String? ?? '',
      sources: sourcesRaw
          .map((s) => VideoSource.fromFlatJson(s as Map<String, dynamic>))
          .toList(),
      isMetadataExtracted: json['isMetadataExtracted'] as bool? ?? false,
      episodeNumber: json['episodeNumber'] as int?,
    );
  }

  Map<String, dynamic> toFlatJson() {
    return {
      'title': title,
      'sources': sources.map((s) => s.toFlatJson()).toList(),
      'isMetadataExtracted': isMetadataExtracted,
      if (episodeNumber != null) 'episodeNumber': episodeNumber,
    };
  }
}
