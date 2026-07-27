import 'package:freezed_annotation/freezed_annotation.dart';
import '../core/video_metadata/video_metadata.dart';

part 'video_source.freezed.dart';

@freezed
abstract class VideoSource with _$VideoSource {
  const factory VideoSource({
    required int messageId,
    required int chatId,
    required int fileSizeBytes,
    required String fileName,
    required String mimeType,
    required DateTime receivedAt,
    VideoMetadata? metadata,
  }) = _VideoSource;

  const VideoSource._();

  /// Convenience getter — derives from metadata, never stored.
  String get qualityLabel {
    if (metadata != null && metadata!.height > 0) {
      return metadata!.qualityLabel;
    }
    return 'Unknown';
  }

  /// Sort rank — higher = better quality. -1 means metadata not yet extracted.
  int get qualityRank => metadata?.height ?? -1;

  /// True when this source has confirmed real metadata (not just a guess).
  bool get hasMetadata => metadata != null && metadata!.height > 0;

  factory VideoSource.fromFlatJson(Map<String, dynamic> json) {
    return VideoSource(
      messageId: json['messageId'] as int,
      chatId: json['chatId'] as int,
      fileSizeBytes: json['fileSizeBytes'] as int? ?? 0,
      fileName: json['fileName'] as String? ?? '',
      mimeType: json['mimeType'] as String? ?? '',
      receivedAt: DateTime.tryParse(json['receivedAt'] as String? ?? '') ?? DateTime.now(),
      metadata: json['metadata'] != null
          ? VideoMetadata.fromFlatJson(json['metadata'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toFlatJson() {
    return {
      'messageId': messageId,
      'chatId': chatId,
      'fileSizeBytes': fileSizeBytes,
      'fileName': fileName,
      'mimeType': mimeType,
      'receivedAt': receivedAt.toIso8601String(),
      if (metadata != null) 'metadata': metadata!.toFlatJson(),
    };
  }
}
