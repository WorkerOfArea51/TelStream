import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';

class VideoSettings {
  final int doubleTapSeekDuration;
  final bool savePositionOnQuit;
  final bool autoplayNextVideo;
  final bool volumeNormalization;
  final bool pitchCorrection;
  final String seekbarStyle;
  final bool dynamicSpeedOverlay;
  final bool horizontalSwipeToSeek;
  final bool volumeGestures;
  final bool brightnessGestures;
  final bool pinchToZoom;

  const VideoSettings({
    this.doubleTapSeekDuration = 10,
    this.savePositionOnQuit = true,
    this.autoplayNextVideo = true,
    this.volumeNormalization = false,
    this.pitchCorrection = true,
    this.seekbarStyle = 'Standard',
    this.dynamicSpeedOverlay = true,
    this.horizontalSwipeToSeek = true,
    this.volumeGestures = true,
    this.brightnessGestures = true,
    this.pinchToZoom = true,
  });

  VideoSettings copyWith({
    int? doubleTapSeekDuration,
    bool? savePositionOnQuit,
    bool? autoplayNextVideo,
    bool? volumeNormalization,
    bool? pitchCorrection,
    String? seekbarStyle,
    bool? dynamicSpeedOverlay,
    bool? horizontalSwipeToSeek,
    bool? volumeGestures,
    bool? brightnessGestures,
    bool? pinchToZoom,
  }) {
    return VideoSettings(
      doubleTapSeekDuration: doubleTapSeekDuration ?? this.doubleTapSeekDuration,
      savePositionOnQuit: savePositionOnQuit ?? this.savePositionOnQuit,
      autoplayNextVideo: autoplayNextVideo ?? this.autoplayNextVideo,
      volumeNormalization: volumeNormalization ?? this.volumeNormalization,
      pitchCorrection: pitchCorrection ?? this.pitchCorrection,
      seekbarStyle: seekbarStyle ?? this.seekbarStyle,
      dynamicSpeedOverlay: dynamicSpeedOverlay ?? this.dynamicSpeedOverlay,
      horizontalSwipeToSeek: horizontalSwipeToSeek ?? this.horizontalSwipeToSeek,
      volumeGestures: volumeGestures ?? this.volumeGestures,
      brightnessGestures: brightnessGestures ?? this.brightnessGestures,
      pinchToZoom: pinchToZoom ?? this.pinchToZoom,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'doubleTapSeekDuration': doubleTapSeekDuration,
      'savePositionOnQuit': savePositionOnQuit,
      'autoplayNextVideo': autoplayNextVideo,
      'volumeNormalization': volumeNormalization,
      'pitchCorrection': pitchCorrection,
      'seekbarStyle': seekbarStyle,
      'dynamicSpeedOverlay': dynamicSpeedOverlay,
      'horizontalSwipeToSeek': horizontalSwipeToSeek,
      'volumeGestures': volumeGestures,
      'brightnessGestures': brightnessGestures,
      'pinchToZoom': pinchToZoom,
    };
  }

  factory VideoSettings.fromJson(Map<String, dynamic> json) {
    return VideoSettings(
      doubleTapSeekDuration: json['doubleTapSeekDuration'] ?? 10,
      savePositionOnQuit: json['savePositionOnQuit'] ?? true,
      autoplayNextVideo: json['autoplayNextVideo'] ?? true,
      volumeNormalization: json['volumeNormalization'] ?? false,
      pitchCorrection: json['pitchCorrection'] ?? true,
      seekbarStyle: json['seekbarStyle'] ?? 'Standard',
      dynamicSpeedOverlay: json['dynamicSpeedOverlay'] ?? true,
      horizontalSwipeToSeek: json['horizontalSwipeToSeek'] ?? true,
      volumeGestures: json['volumeGestures'] ?? true,
      brightnessGestures: json['brightnessGestures'] ?? true,
      pinchToZoom: json['pinchToZoom'] ?? true,
    );
  }
}

class VideoSettingsNotifier extends Notifier<VideoSettings> {
  @override
  VideoSettings build() {
    final storageService = ref.read(storageServiceProvider);
    final rawSettings = storageService.getVideoSettings();
    if (rawSettings.isNotEmpty) {
      return VideoSettings.fromJson(rawSettings);
    }
    return const VideoSettings();
  }

  void updateSettings(VideoSettings newSettings) {
    state = newSettings;
    ref.read(storageServiceProvider).updateVideoSettings(state.toJson());
  }
}

final videoSettingsProvider = NotifierProvider<VideoSettingsNotifier, VideoSettings>(() {
  return VideoSettingsNotifier();
});
