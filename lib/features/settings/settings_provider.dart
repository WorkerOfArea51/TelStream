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
  final int cacheLimitMb;
  final int cacheTtlDays;
  final String streamingProfile;
  final String leftSwipeGesture;
  final String rightSwipeGesture;
  final bool downloadSchedulerEnabled;
  final int downloadStartHour;
  final int downloadEndHour;
  final String subtitleRendererMode;
  final bool dynamicRangeCompression;
  final bool equalizerEnabled;
  final List<double> equalizerBands;
  final String equalizerPreset;
  final double longPressSpeed;
  final String gestureSensitivity;
  final String libraryLayout;

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
    this.cacheLimitMb = 2048, // 2GB default
    this.cacheTtlDays = 7,     // 7 days default
    this.streamingProfile = 'Balanced',
    this.leftSwipeGesture = 'Brightness',
    this.rightSwipeGesture = 'Volume',
    this.downloadSchedulerEnabled = false,
    this.downloadStartHour = 2,
    this.downloadEndHour = 6,
    this.subtitleRendererMode = 'native',
    this.dynamicRangeCompression = false,
    this.equalizerEnabled = false,
    this.equalizerBands = const [0.0, 0.0, 0.0, 0.0, 0.0],
    this.equalizerPreset = 'Flat',
    this.longPressSpeed = 1.5,
    this.gestureSensitivity = 'Normal',
    this.libraryLayout = 'Grid',
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
    int? cacheLimitMb,
    int? cacheTtlDays,
    String? streamingProfile,
    String? leftSwipeGesture,
    String? rightSwipeGesture,
    bool? downloadSchedulerEnabled,
    int? downloadStartHour,
    int? downloadEndHour,
    String? subtitleRendererMode,
    bool? dynamicRangeCompression,
    bool? equalizerEnabled,
    List<double>? equalizerBands,
    String? equalizerPreset,
    double? longPressSpeed,
    String? gestureSensitivity,
    String? libraryLayout,
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
      cacheLimitMb: cacheLimitMb ?? this.cacheLimitMb,
      cacheTtlDays: cacheTtlDays ?? this.cacheTtlDays,
      streamingProfile: streamingProfile ?? this.streamingProfile,
      leftSwipeGesture: leftSwipeGesture ?? this.leftSwipeGesture,
      rightSwipeGesture: rightSwipeGesture ?? this.rightSwipeGesture,
      downloadSchedulerEnabled: downloadSchedulerEnabled ?? this.downloadSchedulerEnabled,
      downloadStartHour: downloadStartHour ?? this.downloadStartHour,
      downloadEndHour: downloadEndHour ?? this.downloadEndHour,
      subtitleRendererMode: subtitleRendererMode ?? this.subtitleRendererMode,
      dynamicRangeCompression: dynamicRangeCompression ?? this.dynamicRangeCompression,
      equalizerEnabled: equalizerEnabled ?? this.equalizerEnabled,
      equalizerBands: equalizerBands ?? this.equalizerBands,
      equalizerPreset: equalizerPreset ?? this.equalizerPreset,
      longPressSpeed: longPressSpeed ?? this.longPressSpeed,
      gestureSensitivity: gestureSensitivity ?? this.gestureSensitivity,
      libraryLayout: libraryLayout ?? this.libraryLayout,
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
      'cacheLimitMb': cacheLimitMb,
      'cacheTtlDays': cacheTtlDays,
      'streamingProfile': streamingProfile,
      'leftSwipeGesture': leftSwipeGesture,
      'rightSwipeGesture': rightSwipeGesture,
      'downloadSchedulerEnabled': downloadSchedulerEnabled,
      'downloadStartHour': downloadStartHour,
      'downloadEndHour': downloadEndHour,
      'subtitleRendererMode': subtitleRendererMode,
      'dynamicRangeCompression': dynamicRangeCompression,
      'equalizerEnabled': equalizerEnabled,
      'equalizerBands': equalizerBands,
      'equalizerPreset': equalizerPreset,
      'longPressSpeed': longPressSpeed,
      'gestureSensitivity': gestureSensitivity,
      'libraryLayout': libraryLayout,
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
      cacheLimitMb: json['cacheLimitMb'] ?? 2048,
      cacheTtlDays: json['cacheTtlDays'] ?? 7,
      streamingProfile: json['streamingProfile'] ?? 'Balanced',
      leftSwipeGesture: json['leftSwipeGesture'] ?? 'Brightness',
      rightSwipeGesture: json['rightSwipeGesture'] ?? 'Volume',
      downloadSchedulerEnabled: json['downloadSchedulerEnabled'] ?? false,
      downloadStartHour: json['downloadStartHour'] ?? 2,
      downloadEndHour: json['downloadEndHour'] ?? 6,
      subtitleRendererMode: json['subtitleRendererMode'] ?? 'native',
      dynamicRangeCompression: json['dynamicRangeCompression'] ?? false,
      equalizerEnabled: json['equalizerEnabled'] ?? false,
      equalizerBands: (json['equalizerBands'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [0.0, 0.0, 0.0, 0.0, 0.0],
      equalizerPreset: json['equalizerPreset'] ?? 'Flat',
      longPressSpeed: (json['longPressSpeed'] as num?)?.toDouble() ?? 1.5,
      gestureSensitivity: json['gestureSensitivity'] ?? 'Normal',
      libraryLayout: json['libraryLayout'] ?? 'Grid',
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
