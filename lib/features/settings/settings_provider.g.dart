// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'settings_provider.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_PlayerLayoutSettings _$PlayerLayoutSettingsFromJson(
  Map<String, dynamic> json,
) => _PlayerLayoutSettings(
  animeLayout: json['animeLayout'] as String? ?? 'Grid',
  moviesLayout: json['moviesLayout'] as String? ?? 'Grid',
  webSeriesLayout: json['webSeriesLayout'] as String? ?? 'Grid',
  seekbarStyle: json['seekbarStyle'] as String? ?? 'Standard',
  dynamicSpeedOverlay: json['dynamicSpeedOverlay'] as bool? ?? true,
  showStatsForNerds: json['showStatsForNerds'] as bool? ?? false,
);

Map<String, dynamic> _$PlayerLayoutSettingsToJson(
  _PlayerLayoutSettings instance,
) => <String, dynamic>{
  'animeLayout': instance.animeLayout,
  'moviesLayout': instance.moviesLayout,
  'webSeriesLayout': instance.webSeriesLayout,
  'seekbarStyle': instance.seekbarStyle,
  'dynamicSpeedOverlay': instance.dynamicSpeedOverlay,
  'showStatsForNerds': instance.showStatsForNerds,
};

_GestureSettings _$GestureSettingsFromJson(Map<String, dynamic> json) =>
    _GestureSettings(
      doubleTapSeekDuration:
          (json['doubleTapSeekDuration'] as num?)?.toInt() ?? 10,
      horizontalSwipeToSeek: json['horizontalSwipeToSeek'] as bool? ?? true,
      volumeGestures: json['volumeGestures'] as bool? ?? true,
      brightnessGestures: json['brightnessGestures'] as bool? ?? true,
      pinchToZoom: json['pinchToZoom'] as bool? ?? true,
      leftSwipeGesture: json['leftSwipeGesture'] as String? ?? 'Brightness',
      rightSwipeGesture: json['rightSwipeGesture'] as String? ?? 'Volume',
      longPressSpeed: (json['longPressSpeed'] as num?)?.toDouble() ?? 1.5,
      gestureSensitivity: json['gestureSensitivity'] as String? ?? 'Normal',
      longPressVibration: json['longPressVibration'] as bool? ?? true,
    );

Map<String, dynamic> _$GestureSettingsToJson(_GestureSettings instance) =>
    <String, dynamic>{
      'doubleTapSeekDuration': instance.doubleTapSeekDuration,
      'horizontalSwipeToSeek': instance.horizontalSwipeToSeek,
      'volumeGestures': instance.volumeGestures,
      'brightnessGestures': instance.brightnessGestures,
      'pinchToZoom': instance.pinchToZoom,
      'leftSwipeGesture': instance.leftSwipeGesture,
      'rightSwipeGesture': instance.rightSwipeGesture,
      'longPressSpeed': instance.longPressSpeed,
      'gestureSensitivity': instance.gestureSensitivity,
      'longPressVibration': instance.longPressVibration,
    };

_AudioSettings _$AudioSettingsFromJson(Map<String, dynamic> json) =>
    _AudioSettings(
      volumeNormalization: json['volumeNormalization'] as bool? ?? false,
      pitchCorrection: json['pitchCorrection'] as bool? ?? true,
      dynamicRangeCompression:
          json['dynamicRangeCompression'] as bool? ?? false,
      equalizerEnabled: json['equalizerEnabled'] as bool? ?? false,
      equalizerBands:
          (json['equalizerBands'] as List<dynamic>?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [0.0, 0.0, 0.0, 0.0, 0.0],
      equalizerPreset: json['equalizerPreset'] as String? ?? 'Flat',
    );

Map<String, dynamic> _$AudioSettingsToJson(_AudioSettings instance) =>
    <String, dynamic>{
      'volumeNormalization': instance.volumeNormalization,
      'pitchCorrection': instance.pitchCorrection,
      'dynamicRangeCompression': instance.dynamicRangeCompression,
      'equalizerEnabled': instance.equalizerEnabled,
      'equalizerBands': instance.equalizerBands,
      'equalizerPreset': instance.equalizerPreset,
    };

_SubtitleSettings _$SubtitleSettingsFromJson(Map<String, dynamic> json) =>
    _SubtitleSettings(
      subtitleRendererMode:
          json['subtitleRendererMode'] as String? ?? 'flutter',
      preferredSubtitleProvider:
          json['preferredSubtitleProvider'] as String? ?? 'opensubtitles',
      subtitleFontSize: (json['subtitleFontSize'] as num?)?.toDouble() ?? 20.0,
      subtitleColor: json['subtitleColor'] as String? ?? '#FFFFFF',
      subtitleDelay: (json['subtitleDelay'] as num?)?.toDouble() ?? 0.0,
      subtitleFont: json['subtitleFont'] as String? ?? 'Roboto',
      subtitleBottomMargin:
          (json['subtitleBottomMargin'] as num?)?.toDouble() ?? 84.0,
      subtitleHorizontalOffset:
          (json['subtitleHorizontalOffset'] as num?)?.toDouble() ?? 0.0,
    );

Map<String, dynamic> _$SubtitleSettingsToJson(_SubtitleSettings instance) =>
    <String, dynamic>{
      'subtitleRendererMode': instance.subtitleRendererMode,
      'preferredSubtitleProvider': instance.preferredSubtitleProvider,
      'subtitleFontSize': instance.subtitleFontSize,
      'subtitleColor': instance.subtitleColor,
      'subtitleDelay': instance.subtitleDelay,
      'subtitleFont': instance.subtitleFont,
      'subtitleBottomMargin': instance.subtitleBottomMargin,
      'subtitleHorizontalOffset': instance.subtitleHorizontalOffset,
    };

_CacheSettings _$CacheSettingsFromJson(Map<String, dynamic> json) =>
    _CacheSettings(
      cacheLimitMb: (json['cacheLimitMb'] as num?)?.toInt() ?? 2048,
      cacheTtlDays: (json['cacheTtlDays'] as num?)?.toInt() ?? 7,
    );

Map<String, dynamic> _$CacheSettingsToJson(_CacheSettings instance) =>
    <String, dynamic>{
      'cacheLimitMb': instance.cacheLimitMb,
      'cacheTtlDays': instance.cacheTtlDays,
    };
