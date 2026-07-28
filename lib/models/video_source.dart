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
  /// Best-known quality label. Always returns a label when height is known,
  /// even if the container hasn't been parsed yet (TDLib-provided dimensions
  /// are usually accurate enough for a badge).
  ///
  /// Returns:
  ///   - "1080p" / "720p" / etc. when height > 0 (regardless of container)
  ///   - "Unknown" when height is 0
  String get qualityLabel {
    final meta = metadata;
    if (meta != null && meta.height > 0) {
      // Use VideoMetadata.qualityLabel, which derives from width/height.
      // This works for both confirmed (container known) and unconfirmed
      // (container unknown, TDLib-provided) metadata.
      return meta.qualityLabel;
    }
    return 'Unknown';
  }

  /// Sort rank — higher = better quality. -1 means metadata not yet extracted.
  int get qualityRank => metadata?.height ?? -1;

  /// True when this source has dimensions (width AND height > 0), regardless
  /// of whether the container has been parsed. Used to decide whether to show
  /// a quality badge and whether to count this source in
  /// `Episode.hasMultipleQualities`.
  ///
  /// Container-parsed metadata is "more confirmed" but TDLib-provided metadata
  /// is still reliable enough for badge display.
  bool get hasMetadata => metadata != null && metadata!.height > 0;

  /// True when the container type has been confirmed by parsing the file header.
  /// Use this to decide whether to show a "confirmed" indicator in the UI
  /// (e.g. a checkmark next to the quality badge).
  bool get isContainerParsed => metadata != null && metadata!.container != VideoContainer.unknown;

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
