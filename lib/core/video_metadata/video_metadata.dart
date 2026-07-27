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
    switch (height) {
      case >= 2160: return '4K';
      case >= 1440: return '1440p';
      case >= 1080: return '1080p';
      case >= 720:  return '720p';
      case >= 480:  return '480p';
      case 0:       return 'Unknown';
      default:      return 'SD';
    }
  }
}
