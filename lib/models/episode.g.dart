// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'episode.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Episode _$EpisodeFromJson(Map<String, dynamic> json) => _Episode(
  title: json['title'] as String,
  sources:
      (json['sources'] as List<dynamic>?)
          ?.map((e) => VideoSource.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
  isMetadataExtracted: json['isMetadataExtracted'] as bool? ?? false,
);

Map<String, dynamic> _$EpisodeToJson(_Episode instance) => <String, dynamic>{
  'title': instance.title,
  'sources': instance.sources,
  'isMetadataExtracted': instance.isMetadataExtracted,
};
