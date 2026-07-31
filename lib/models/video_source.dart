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
    // STEP 1: Filename extraction (instant, no network)
    final fromFilename = _extractQualityFromFilename(fileName);
    if (fromFilename != null) return fromFilename;

    // STEP 2: Metadata bucketing (TDLib-provided or container-parsed)
    final meta = metadata;
    if (meta != null && (meta.width > 0 || meta.height > 0)) {
      return meta.qualityLabel;
    }

    // STEP 3: Unknown
    return 'Unknown';
  }

  /// Numeric rank for sorting sources by quality (higher = better).
  /// Derived from qualityLabel so it works even without metadata.
  int get qualityRank {
    const ranks = <String, int>{
      'Unknown': 0,
      'SD':      1,
      '240p':    2,
      '360p':    3,
      '480p':    4,
      '540p':    5,
      '720p':    6,
      '1080p':   7,
      '1440p':   8,
      '2160p':   9,
    };
    return ranks[qualityLabel] ?? 0;
  }

  /// True when this source has a usable quality label, either from filename
  /// or from metadata. Use this (instead of hasMetadata) to decide whether
  /// to show a quality badge and whether to count this source in
  /// Episode.hasMultipleQualities.
  bool get hasQualityLabel {
    return _extractQualityFromFilename(fileName) != null ||
           (metadata != null && metadata!.height > 0);
  }

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

  /// Extracts a quality label from a video filename.
  /// Returns null if no quality token is found.
  static String? _extractQualityFromFilename(String filename) {
    if (filename.isEmpty) return null;
    // Replace underscores with spaces so \b matches correctly
    final lower = filename.toLowerCase().replaceAll('_', ' ');

    // Ordered list of (regex, label) pairs. First match wins.
    final patterns = <(RegExp, String)>[
      (RegExp(r'\b2160p\b'),         '2160p'),
      (RegExp(r'\b4k\b'),            '2160p'),
      (RegExp(r'\buhd\b'),           '2160p'),
      (RegExp(r'\b1440p\b'),         '1440p'),
      (RegExp(r'\b2k\b'),            '1440p'),
      (RegExp(r'\b1080p\b'),         '1080p'),
      (RegExp(r'\bfhd\b'),           '1080p'),
      (RegExp(r'\b720p\b'),          '720p'),
      (RegExp(r'\bhd-ready\b'),      '720p'),
      (RegExp(r'\bhd\b'),            '720p'),
      (RegExp(r'\b540p\b'),          '540p'),
      (RegExp(r'\b480p\b'),          '480p'),
      (RegExp(r'\bsd\b'),            '480p'),
      (RegExp(r'\b360p\b'),          '360p'),
      (RegExp(r'\b240p\b'),          '240p'),
    ];

    for (final pattern in patterns) {
      if (pattern.$1.hasMatch(lower)) return pattern.$2;
    }
    return null;
  }
}
