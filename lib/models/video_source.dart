import 'dart:convert';
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

    /// Base64-encoded JPEG minithumbnail from TDLib (instant display, no network).
    /// Null for messages where Telegram didn't generate a thumbnail.
    @Default(null) String? minithumbnailData,

    /// TDLib file ID of the full-quality thumbnail (typically 320x180+ JPEG).
    /// Null when Telegram didn't generate a thumbnail for this message.
    /// Used by TdThumbnail widget to download and display the full thumbnail.
    @Default(null) int? thumbnailFileId,

    /// TDLib-provided duration in seconds (only for MessageVideo, null for
    /// MessageDocument). Used as a fallback when container parsing hasn't
    /// completed yet.
    @Default(null) int? tdlibDurationSeconds,
  }) = _VideoSource;

  const VideoSource._();

  /// Convenience getter — derives from metadata, never stored.
  String get qualityLabel {
    if (metadata != null && metadata!.height > 0) {
      if (metadata!.container == VideoContainer.unknown) {
        return '...';
      }
      return metadata!.qualityLabel;
    }
    return 'Unknown';
  }

  /// Sort rank — higher = better quality. -1 means metadata not yet extracted.
  int get qualityRank => metadata?.height ?? -1;

  /// True when this source has confirmed real metadata (not just a guess).
  bool get hasMetadata => metadata != null && metadata!.height > 0 && metadata!.container != VideoContainer.unknown;

  /// Returns the best-known duration in milliseconds. Prefers container-parsed
  /// metadata; falls back to TDLib's duration for MessageVideo.
  int get durationMillis {
    final meta = metadata;
    if (meta != null && meta.durationMillis > 0) return meta.durationMillis;
    final td = tdlibDurationSeconds;
    if (td != null && td > 0) return td * 1000;
    return 0;
  }

  /// Decoded minithumbnail bytes, or null if not available.
  List<int>? get minithumbnailBytes {
    final data = minithumbnailData;
    if (data == null || data.isEmpty) return null;
    try {
      return base64Decode(data);
    } catch (_) {
      return null;
    }
  }

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
      minithumbnailData: json['minithumbnailData'] as String?,
      thumbnailFileId: json['thumbnailFileId'] as int?,
      tdlibDurationSeconds: json['tdlibDurationSeconds'] as int?,
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
      if (minithumbnailData != null) 'minithumbnailData': minithumbnailData,
      if (thumbnailFileId != null) 'thumbnailFileId': thumbnailFileId,
      if (tdlibDurationSeconds != null) 'tdlibDurationSeconds': tdlibDurationSeconds,
    };
  }
}
