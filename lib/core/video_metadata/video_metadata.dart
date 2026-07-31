import 'package:freezed_annotation/freezed_annotation.dart';

part 'video_metadata.freezed.dart';

enum VideoContainer {
  mp4,
  mkv,
  webm,
  unknown
}

@freezed
abstract class VideoMetadata with _$VideoMetadata {
  const factory VideoMetadata({
    required int width,
    required int height,
    required int durationMillis,
    required VideoContainer container, // mp4 | mkv | webm | unknown
    String? codecHint,                 // 'h264', 'hevc', 'av1', 'vp9'
  }) = _VideoMetadata;

  const VideoMetadata._();

  factory VideoMetadata.unknown() => const VideoMetadata(
        width: 0,
        height: 0,
        durationMillis: 0,
        container: VideoContainer.unknown,
      );

  factory VideoMetadata.fromFlatJson(Map<String, dynamic> json) {
    return VideoMetadata(
      width: json['width'] as int? ?? 0,
      height: json['height'] as int? ?? 0,
      durationMillis: json['durationMillis'] as int? ?? 0,
      container: VideoContainer.values.firstWhere(
        (c) => c.name == (json['container'] as String?),
        orElse: () => VideoContainer.unknown,
      ),
      codecHint: json['codecHint'] as String?,
    );
  }

  Map<String, dynamic> toFlatJson() {
    return {
      'width': width,
      'height': height,
      'durationMillis': durationMillis,
      'container': container.name,
      if (codecHint != null) 'codecHint': codecHint,
    };
  }

  String get qualityLabel {
    final w = width;
    final h = height;
    if (w == 0 && h == 0) return 'Unknown';
    if (w >= 3840 || h >= 2160) return '2160p';
    if (w >= 2560 || h >= 1440) return '1440p';
    if (w >= 1920 || h >= 1080) return '1080p';
    if (w >= 1280 || h >= 720) return '720p';
    if (w >= 854 || h >= 480) return '480p';
    return '480p';
  }
}
