// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'video_source.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_VideoSource _$VideoSourceFromJson(Map<String, dynamic> json) => _VideoSource(
  message: const TdMessageConverter().fromJson(
    json['message'] as Map<String, dynamic>,
  ),
  qualityLabel: json['qualityLabel'] as String,
  width: (json['width'] as num).toInt(),
  height: (json['height'] as num).toInt(),
);

Map<String, dynamic> _$VideoSourceToJson(_VideoSource instance) =>
    <String, dynamic>{
      'message': const TdMessageConverter().toJson(instance.message),
      'qualityLabel': instance.qualityLabel,
      'width': instance.width,
      'height': instance.height,
    };
