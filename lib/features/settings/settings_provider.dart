import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import '../../core/logger.dart';
import '../../services/storage_service.dart';

part 'settings_provider.freezed.dart';
part 'settings_provider.g.dart';

@freezed
abstract class PlayerLayoutSettings with _$PlayerLayoutSettings {
  const factory PlayerLayoutSettings({
    @Default('Grid') String animeLayout,
    @Default('Grid') String moviesLayout,
    @Default('Grid') String webSeriesLayout,
    @Default('Standard') String seekbarStyle,
    @Default(true) bool dynamicSpeedOverlay,
    @Default(false) bool showStatsForNerds,
  }) = _PlayerLayoutSettings;

  factory PlayerLayoutSettings.fromJson(Map<String, dynamic> json) => _$PlayerLayoutSettingsFromJson(json);
}

@freezed
abstract class GestureSettings with _$GestureSettings {
  const factory GestureSettings({
    @Default(10) int doubleTapSeekDuration,
    @Default(true) bool horizontalSwipeToSeek,
    @Default(true) bool volumeGestures,
    @Default(true) bool brightnessGestures,
    @Default(true) bool pinchToZoom,
    @Default('Brightness') String leftSwipeGesture,
    @Default('Volume') String rightSwipeGesture,
    @Default(1.5) double longPressSpeed,
    @Default('Normal') String gestureSensitivity,
    @Default(true) bool longPressVibration,
  }) = _GestureSettings;

  factory GestureSettings.fromJson(Map<String, dynamic> json) => _$GestureSettingsFromJson(json);
}

@freezed
abstract class AudioSettings with _$AudioSettings {
  const factory AudioSettings({
    @Default(false) bool volumeNormalization,
    @Default(true) bool pitchCorrection,
    @Default(false) bool dynamicRangeCompression,
    @Default(false) bool equalizerEnabled,
    @Default([0.0, 0.0, 0.0, 0.0, 0.0]) List<double> equalizerBands,
    @Default('Flat') String equalizerPreset,
  }) = _AudioSettings;

  factory AudioSettings.fromJson(Map<String, dynamic> json) => _$AudioSettingsFromJson(json);
}

@freezed
abstract class SubtitleSettings with _$SubtitleSettings {
  const factory SubtitleSettings({
    @Default('flutter') String subtitleRendererMode,
    @Default('opensubtitles') String preferredSubtitleProvider,
    @Default(20.0) double subtitleFontSize,
    @Default('#FFFFFF') String subtitleColor,
    @Default(0.0) double subtitleDelay,
    @Default('Roboto') String subtitleFont,
    @Default(84.0) double subtitleBottomMargin,
    @Default(0.0) double subtitleHorizontalOffset,
  }) = _SubtitleSettings;

  factory SubtitleSettings.fromJson(Map<String, dynamic> json) => _$SubtitleSettingsFromJson(json);
}

@freezed
abstract class CacheSettings with _$CacheSettings {
  const factory CacheSettings({
    @Default(2048) int cacheLimitMb,
    @Default(7) int cacheTtlDays,
  }) = _CacheSettings;

  factory CacheSettings.fromJson(Map<String, dynamic> json) => _$CacheSettingsFromJson(json);
}

@freezed
abstract class VideoSettings with _$VideoSettings {
  const VideoSettings._();

  const factory VideoSettings({
    @Default(PlayerLayoutSettings()) PlayerLayoutSettings layout,
    @Default(GestureSettings()) GestureSettings gestures,
    @Default(AudioSettings()) AudioSettings audio,
    @Default(SubtitleSettings()) SubtitleSettings subtitles,
    @Default(CacheSettings()) CacheSettings cache,
    @Default(true) bool savePositionOnQuit,
    @Default(true) bool autoplayNextVideo,
    @Default('Balanced') String streamingProfile,
    @Default(false) bool downloadSchedulerEnabled,
    @Default(2) int downloadStartHour,
    @Default(6) int downloadEndHour,
    @Default('') String customMpvOptions,
    @Default('Unlimited') String downloadSpeedLimit,
    @Default('disabled') String progressSyncMode,
    @Default(false) bool rememberSpeed,
    @Default(false) bool wifiOnlyDownloads,
    @Default('auto') String hardwareDecoderMode,
  }) = _VideoSettings;

  String getLayoutForCategory(String categoryTitle) {
    switch (categoryTitle.toLowerCase()) {
      case 'anime':
        return layout.animeLayout;
      case 'movies':
        return layout.moviesLayout;
      case 'web series':
        return layout.webSeriesLayout;
      default:
        return 'Grid';
    }
  }

  VideoSettings copyWithLayoutForCategory(String categoryTitle, String newLayout) {
    switch (categoryTitle.toLowerCase()) {
      case 'anime':
        return copyWith(layout: layout.copyWith(animeLayout: newLayout));
      case 'movies':
        return copyWith(layout: layout.copyWith(moviesLayout: newLayout));
      case 'web series':
        return copyWith(layout: layout.copyWith(webSeriesLayout: newLayout));
      default:
        return this;
    }
  }

  // Backwards compatibility with flat JSON
  factory VideoSettings.fromFlatJson(Map<String, dynamic> json, String hardwareDecoderMode) {
    return VideoSettings(
      layout: PlayerLayoutSettings(
        animeLayout: json['animeLayout'] ?? json['libraryLayout'] ?? 'Grid',
        moviesLayout: json['moviesLayout'] ?? json['libraryLayout'] ?? 'Grid',
        webSeriesLayout: json['webSeriesLayout'] ?? json['libraryLayout'] ?? 'Grid',
        seekbarStyle: json['seekbarStyle'] ?? 'Standard',
        dynamicSpeedOverlay: json['dynamicSpeedOverlay'] ?? true,
        showStatsForNerds: json['showStatsForNerds'] ?? false,
      ),
      gestures: GestureSettings(
        doubleTapSeekDuration: json['doubleTapSeekDuration'] ?? 10,
        horizontalSwipeToSeek: json['horizontalSwipeToSeek'] ?? true,
        volumeGestures: json['volumeGestures'] ?? true,
        brightnessGestures: json['brightnessGestures'] ?? true,
        pinchToZoom: json['pinchToZoom'] ?? true,
        leftSwipeGesture: json['leftSwipeGesture'] ?? 'Brightness',
        rightSwipeGesture: json['rightSwipeGesture'] ?? 'Volume',
        longPressSpeed: (json['longPressSpeed'] as num?)?.toDouble() ?? 1.5,
        gestureSensitivity: json['gestureSensitivity'] ?? 'Normal',
        longPressVibration: json['longPressVibration'] ?? true,
      ),
      audio: AudioSettings(
        volumeNormalization: json['volumeNormalization'] ?? false,
        pitchCorrection: json['pitchCorrection'] ?? true,
        dynamicRangeCompression: json['dynamicRangeCompression'] ?? false,
        equalizerEnabled: json['equalizerEnabled'] ?? false,
        equalizerBands: (json['equalizerBands'] as List?)?.map((e) => (e as num).toDouble()).toList() ?? const [0.0, 0.0, 0.0, 0.0, 0.0],
        equalizerPreset: json['equalizerPreset'] ?? 'Flat',
      ),
      subtitles: SubtitleSettings(
        subtitleRendererMode: json['subtitleRendererMode'] ?? 'flutter',
        preferredSubtitleProvider: json['preferredSubtitleProvider'] ?? 'opensubtitles',
        subtitleFontSize: (json['subtitleFontSize'] as num?)?.toDouble() ?? 20.0,
        subtitleColor: json['subtitleColor'] ?? '#FFFFFF',
        subtitleDelay: (json['subtitleDelay'] as num?)?.toDouble() ?? 0.0,
        subtitleFont: json['subtitleFont'] ?? 'Roboto',
        subtitleBottomMargin: (json['subtitleBottomMargin'] as num?)?.toDouble() ?? 84.0,
        subtitleHorizontalOffset: (json['subtitleHorizontalOffset'] as num?)?.toDouble() ?? 0.0,
      ),
      cache: CacheSettings(
        cacheLimitMb: json['cacheLimitMb'] ?? 2048,
        cacheTtlDays: json['cacheTtlDays'] ?? 7,
      ),
      savePositionOnQuit: json['savePositionOnQuit'] ?? true,
      autoplayNextVideo: json['autoplayNextVideo'] ?? true,
      streamingProfile: json['streamingProfile'] ?? 'Balanced',
      downloadSchedulerEnabled: json['downloadSchedulerEnabled'] ?? false,
      downloadStartHour: json['downloadStartHour'] ?? 2,
      downloadEndHour: json['downloadEndHour'] ?? 6,
      customMpvOptions: json['customMpvOptions'] ?? '',
      downloadSpeedLimit: json['downloadSpeedLimit'] ?? 'Unlimited',
      progressSyncMode: json['progressSyncMode'] ?? 'disabled',
      rememberSpeed: json['rememberSpeed'] ?? false,
      wifiOnlyDownloads: json['wifiOnlyDownloads'] ?? false,
      hardwareDecoderMode: hardwareDecoderMode,
    );
  }

  Map<String, dynamic> toFlatJson() {
    return {
      'animeLayout': layout.animeLayout,
      'moviesLayout': layout.moviesLayout,
      'webSeriesLayout': layout.webSeriesLayout,
      'seekbarStyle': layout.seekbarStyle,
      'dynamicSpeedOverlay': layout.dynamicSpeedOverlay,
      'showStatsForNerds': layout.showStatsForNerds,

      'doubleTapSeekDuration': gestures.doubleTapSeekDuration,
      'horizontalSwipeToSeek': gestures.horizontalSwipeToSeek,
      'volumeGestures': gestures.volumeGestures,
      'brightnessGestures': gestures.brightnessGestures,
      'pinchToZoom': gestures.pinchToZoom,
      'leftSwipeGesture': gestures.leftSwipeGesture,
      'rightSwipeGesture': gestures.rightSwipeGesture,
      'longPressSpeed': gestures.longPressSpeed,
      'gestureSensitivity': gestures.gestureSensitivity,
      'longPressVibration': gestures.longPressVibration,

      'volumeNormalization': audio.volumeNormalization,
      'pitchCorrection': audio.pitchCorrection,
      'dynamicRangeCompression': audio.dynamicRangeCompression,
      'equalizerEnabled': audio.equalizerEnabled,
      'equalizerBands': audio.equalizerBands,
      'equalizerPreset': audio.equalizerPreset,

      'subtitleRendererMode': subtitles.subtitleRendererMode,
      'preferredSubtitleProvider': subtitles.preferredSubtitleProvider,
      'subtitleFontSize': subtitles.subtitleFontSize,
      'subtitleColor': subtitles.subtitleColor,
      'subtitleDelay': subtitles.subtitleDelay,
      'subtitleFont': subtitles.subtitleFont,
      'subtitleBottomMargin': subtitles.subtitleBottomMargin,
      'subtitleHorizontalOffset': subtitles.subtitleHorizontalOffset,

      'cacheLimitMb': cache.cacheLimitMb,
      'cacheTtlDays': cache.cacheTtlDays,

      'savePositionOnQuit': savePositionOnQuit,
      'autoplayNextVideo': autoplayNextVideo,
      'streamingProfile': streamingProfile,
      'downloadSchedulerEnabled': downloadSchedulerEnabled,
      'downloadStartHour': downloadStartHour,
      'downloadEndHour': downloadEndHour,
      'customMpvOptions': customMpvOptions,
      'downloadSpeedLimit': downloadSpeedLimit,
      'progressSyncMode': progressSyncMode,
      'rememberSpeed': rememberSpeed,
      'wifiOnlyDownloads': wifiOnlyDownloads,
    };
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
    final hardwareDec = storageService.getHardwareDecoderMode();

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
        return VideoSettings.fromFlatJson(updatedJson, hardwareDec);
      } catch (e, stack) {
        Log.e('Failed to parse VideoSettings from storage, using defaults', e, stack);
      }
    }

    // Default fallback
    final def = VideoSettings.fromFlatJson({}, hardwareDec);
    return def.copyWith(
      layout: def.layout.copyWith(
        animeLayout: animeLayout,
        moviesLayout: moviesLayout,
        webSeriesLayout: webSeriesLayout,
      ),
      subtitles: def.subtitles.copyWith(
        subtitleFontSize: storageService.getSubtitleFontSize(),
        subtitleColor: storageService.getSubtitleColor(),
        subtitleDelay: storageService.getSubtitleDelay(),
        subtitleFont: storageService.getSubtitleFont(),
      ),
    );
  }

  void updateSettings(VideoSettings newSettings) {
    state = newSettings;
    final storage = ref.read(storageServiceProvider);
    storage.updateVideoSettingsBatch(state.toFlatJson(), state.layout.animeLayout, state.layout.moviesLayout, state.layout.webSeriesLayout);
    storage.setHardwareDecoderMode(state.hardwareDecoderMode);
  }
}

final videoSettingsProvider = NotifierProvider<VideoSettingsNotifier, VideoSettings>(() {
  return VideoSettingsNotifier();
});
