import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/logger.dart';
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
  final String animeLayout;
  final String moviesLayout;
  final String webSeriesLayout;
  final String preferredSubtitleProvider;
  final String customMpvOptions;
  final bool showStatsForNerds;
  final double subtitleFontSize;
  final String subtitleColor;
  final double subtitleDelay;
  final String subtitleFont;
  final String downloadSpeedLimit;
  final String progressSyncMode;
  final double subtitleBottomMargin;
  final double subtitleHorizontalOffset;
  final bool rememberSpeed;
  final bool longPressVibration;

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
    this.subtitleRendererMode = 'flutter',
    this.dynamicRangeCompression = false,
    this.equalizerEnabled = false,
    this.equalizerBands = const [0.0, 0.0, 0.0, 0.0, 0.0],
    this.equalizerPreset = 'Flat',
    this.longPressSpeed = 1.5,
    this.gestureSensitivity = 'Normal',
    this.animeLayout = 'Grid',
    this.moviesLayout = 'Grid',
    this.webSeriesLayout = 'Grid',
    this.preferredSubtitleProvider = 'opensubtitles',
    this.customMpvOptions = '',
    this.showStatsForNerds = false,
    this.subtitleFontSize = 45.0,
    this.subtitleColor = '#FFFFFF',
    this.subtitleDelay = 0.0,
    this.subtitleFont = 'Roboto',
    this.downloadSpeedLimit = 'Unlimited',
    this.progressSyncMode = 'disabled',
    this.subtitleBottomMargin = 84.0,
    this.subtitleHorizontalOffset = 0.0,
    this.rememberSpeed = false,
    this.longPressVibration = true,
  });

  String getLayoutForCategory(String categoryTitle) {
    switch (categoryTitle.toLowerCase()) {
      case 'anime':
        return animeLayout;
      case 'movies':
        return moviesLayout;
      case 'web series':
        return webSeriesLayout;
      default:
        return 'Grid';
    }
  }

  VideoSettings copyWithLayoutForCategory(String categoryTitle, String layout) {
    switch (categoryTitle.toLowerCase()) {
      case 'anime':
        return copyWith(animeLayout: layout);
      case 'movies':
        return copyWith(moviesLayout: layout);
      case 'web series':
        return copyWith(webSeriesLayout: layout);
      default:
        return this;
    }
  }

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
    String? animeLayout,
    String? moviesLayout,
    String? webSeriesLayout,
    String? preferredSubtitleProvider,
    String? customMpvOptions,
    bool? showStatsForNerds,
    double? subtitleFontSize,
    String? subtitleColor,
    double? subtitleDelay,
    String? subtitleFont,
    String? downloadSpeedLimit,
    String? progressSyncMode,
    double? subtitleBottomMargin,
    double? subtitleHorizontalOffset,
    bool? rememberSpeed,
    bool? longPressVibration,
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
      animeLayout: animeLayout ?? this.animeLayout,
      moviesLayout: moviesLayout ?? this.moviesLayout,
      webSeriesLayout: webSeriesLayout ?? this.webSeriesLayout,
      preferredSubtitleProvider: preferredSubtitleProvider ?? this.preferredSubtitleProvider,
      customMpvOptions: customMpvOptions ?? this.customMpvOptions,
      showStatsForNerds: showStatsForNerds ?? this.showStatsForNerds,
      subtitleFontSize: subtitleFontSize ?? this.subtitleFontSize,
      subtitleColor: subtitleColor ?? this.subtitleColor,
      subtitleDelay: subtitleDelay ?? this.subtitleDelay,
      subtitleFont: subtitleFont ?? this.subtitleFont,
      downloadSpeedLimit: downloadSpeedLimit ?? this.downloadSpeedLimit,
      progressSyncMode: progressSyncMode ?? this.progressSyncMode,
      subtitleBottomMargin: subtitleBottomMargin ?? this.subtitleBottomMargin,
      subtitleHorizontalOffset: subtitleHorizontalOffset ?? this.subtitleHorizontalOffset,
      rememberSpeed: rememberSpeed ?? this.rememberSpeed,
      longPressVibration: longPressVibration ?? this.longPressVibration,
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
      'animeLayout': animeLayout,
      'moviesLayout': moviesLayout,
      'webSeriesLayout': webSeriesLayout,
      'preferredSubtitleProvider': preferredSubtitleProvider,
      'customMpvOptions': customMpvOptions,
      'showStatsForNerds': showStatsForNerds,
      'subtitleFontSize': subtitleFontSize,
      'subtitleColor': subtitleColor,
      'subtitleDelay': subtitleDelay,
      'subtitleFont': subtitleFont,
      'downloadSpeedLimit': downloadSpeedLimit,
      'progressSyncMode': progressSyncMode,
      'subtitleBottomMargin': subtitleBottomMargin,
      'subtitleHorizontalOffset': subtitleHorizontalOffset,
      'rememberSpeed': rememberSpeed,
      'longPressVibration': longPressVibration,
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
      subtitleRendererMode: json['subtitleRendererMode'] ?? 'flutter',
      dynamicRangeCompression: json['dynamicRangeCompression'] ?? false,
      equalizerEnabled: json['equalizerEnabled'] ?? false,
      equalizerBands: (json['equalizerBands'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [0.0, 0.0, 0.0, 0.0, 0.0],
      equalizerPreset: json['equalizerPreset'] ?? 'Flat',
      longPressSpeed: (json['longPressSpeed'] as num?)?.toDouble() ?? 1.5,
      gestureSensitivity: json['gestureSensitivity'] ?? 'Normal',
      animeLayout: json['animeLayout'] ?? json['libraryLayout'] ?? 'Grid',
      moviesLayout: json['moviesLayout'] ?? json['libraryLayout'] ?? 'Grid',
      webSeriesLayout: json['webSeriesLayout'] ?? json['libraryLayout'] ?? 'Grid',
      preferredSubtitleProvider: json['preferredSubtitleProvider'] ?? 'opensubtitles',
      customMpvOptions: json['customMpvOptions'] ?? '',
      showStatsForNerds: json['showStatsForNerds'] ?? false,
      subtitleFontSize: (json['subtitleFontSize'] as num?)?.toDouble() ?? 45.0,
      subtitleColor: json['subtitleColor'] ?? '#FFFFFF',
      subtitleDelay: (json['subtitleDelay'] as num?)?.toDouble() ?? 0.0,
      subtitleFont: json['subtitleFont'] ?? 'Roboto',
      downloadSpeedLimit: json['downloadSpeedLimit'] ?? 'Unlimited',
      progressSyncMode: json['progressSyncMode'] ?? 'disabled',
      subtitleBottomMargin: (json['subtitleBottomMargin'] as num?)?.toDouble() ?? 84.0,
      subtitleHorizontalOffset: (json['subtitleHorizontalOffset'] as num?)?.toDouble() ?? 0.0,
      rememberSpeed: json['rememberSpeed'] ?? false,
      longPressVibration: json['longPressVibration'] ?? true,
    );
  }

@override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VideoSettings &&
      other.doubleTapSeekDuration == doubleTapSeekDuration &&
      other.savePositionOnQuit == savePositionOnQuit &&
      other.autoplayNextVideo == autoplayNextVideo &&
      other.volumeNormalization == volumeNormalization &&
      other.pitchCorrection == pitchCorrection &&
      other.seekbarStyle == seekbarStyle &&
      other.dynamicSpeedOverlay == dynamicSpeedOverlay &&
      other.horizontalSwipeToSeek == horizontalSwipeToSeek &&
      other.volumeGestures == volumeGestures &&
      other.brightnessGestures == brightnessGestures &&
      other.pinchToZoom == pinchToZoom &&
      other.cacheLimitMb == cacheLimitMb &&
      other.cacheTtlDays == cacheTtlDays &&
      other.streamingProfile == streamingProfile &&
      other.leftSwipeGesture == leftSwipeGesture &&
      other.rightSwipeGesture == rightSwipeGesture &&
      other.downloadSchedulerEnabled == downloadSchedulerEnabled &&
      other.downloadStartHour == downloadStartHour &&
      other.downloadEndHour == downloadEndHour &&
      other.subtitleRendererMode == subtitleRendererMode &&
      other.dynamicRangeCompression == dynamicRangeCompression &&
      other.equalizerEnabled == equalizerEnabled &&
      const ListEquality().equals(other.equalizerBands, equalizerBands) &&
      other.equalizerPreset == equalizerPreset &&
      other.longPressSpeed == longPressSpeed &&
      other.gestureSensitivity == gestureSensitivity &&
      other.animeLayout == animeLayout &&
      other.moviesLayout == moviesLayout &&
      other.webSeriesLayout == webSeriesLayout &&
      other.preferredSubtitleProvider == preferredSubtitleProvider &&
      other.customMpvOptions == customMpvOptions &&
      other.showStatsForNerds == showStatsForNerds &&
      other.subtitleFontSize == subtitleFontSize &&
      other.subtitleColor == subtitleColor &&
      other.subtitleDelay == subtitleDelay &&
      other.subtitleFont == subtitleFont &&
      other.downloadSpeedLimit == downloadSpeedLimit &&
      other.progressSyncMode == progressSyncMode &&
      other.subtitleBottomMargin == subtitleBottomMargin &&
      other.subtitleHorizontalOffset == subtitleHorizontalOffset &&
      other.rememberSpeed == rememberSpeed &&
      other.longPressVibration == longPressVibration;
  }

  @override
  int get hashCode {
    return Object.hashAll([doubleTapSeekDuration, savePositionOnQuit, autoplayNextVideo, volumeNormalization, pitchCorrection, seekbarStyle, dynamicSpeedOverlay, horizontalSwipeToSeek, volumeGestures, brightnessGestures, pinchToZoom, cacheLimitMb, cacheTtlDays, streamingProfile, leftSwipeGesture, rightSwipeGesture, downloadSchedulerEnabled, downloadStartHour, downloadEndHour, subtitleRendererMode, dynamicRangeCompression, equalizerEnabled, equalizerBands, equalizerPreset, longPressSpeed, gestureSensitivity, animeLayout, moviesLayout, webSeriesLayout, preferredSubtitleProvider, customMpvOptions, showStatsForNerds, subtitleFontSize, subtitleColor, subtitleDelay, subtitleFont, downloadSpeedLimit, progressSyncMode, subtitleBottomMargin, subtitleHorizontalOffset, rememberSpeed, longPressVibration, ]);
  }
}

class VideoSettingsNotifier extends Notifier<VideoSettings> {
  @override
  VideoSettings build() {
    final storageService = ref.read(storageServiceProvider);
    final rawSettings = storageService.getVideoSettings();
    final animeLayout = storageService.getAnimeLayout();
    final moviesLayout = storageService.getMoviesLayout();
    final webSeriesLayout = storageService.getWebSeriesLayout();

    if (rawSettings.isNotEmpty) {
      final updatedJson = Map<String, dynamic>.from(rawSettings);
      if (!updatedJson.containsKey('subtitleFontSize')) {
        updatedJson['subtitleFontSize'] = storageService.getSubtitleFontSize();
      }
      if (!updatedJson.containsKey('subtitleColor')) {
        updatedJson['subtitleColor'] = storageService.getSubtitleColor();
      }
      if (!updatedJson.containsKey('subtitleDelay')) {
        updatedJson['subtitleDelay'] = storageService.getSubtitleDelay();
      }
      if (!updatedJson.containsKey('subtitleFont')) {
        updatedJson['subtitleFont'] = storageService.getSubtitleFont();
      }
      if (!updatedJson.containsKey('downloadSpeedLimit')) {
        updatedJson['downloadSpeedLimit'] = 'Unlimited';
      }
      if (!updatedJson.containsKey('progressSyncMode')) {
        updatedJson['progressSyncMode'] = 'disabled';
      }
      updatedJson['animeLayout'] = animeLayout;
      updatedJson['moviesLayout'] = moviesLayout;
      updatedJson['webSeriesLayout'] = webSeriesLayout;
      try {
        return VideoSettings.fromJson(updatedJson);
      } catch (e, stack) {
        Log.e('Failed to parse VideoSettings from storage, using defaults', e, stack);
      }
    }
    return VideoSettings(
      subtitleFontSize: storageService.getSubtitleFontSize(),
      subtitleColor: storageService.getSubtitleColor(),
      subtitleDelay: storageService.getSubtitleDelay(),
      subtitleFont: storageService.getSubtitleFont(),
      downloadSpeedLimit: 'Unlimited',
      progressSyncMode: 'disabled',
      animeLayout: animeLayout,
      moviesLayout: moviesLayout,
      webSeriesLayout: webSeriesLayout,
    );
  }

  void updateSettings(VideoSettings newSettings) {
    state = newSettings;
    final storage = ref.read(storageServiceProvider);
    storage.updateVideoSettingsBatch(state.toJson(), state.animeLayout, state.moviesLayout, state.webSeriesLayout);
  }
}

final videoSettingsProvider = NotifierProvider<VideoSettingsNotifier, VideoSettings>(() {
  return VideoSettingsNotifier();
});
