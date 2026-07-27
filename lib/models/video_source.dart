import 'dart:convert';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tdlib/td_api.dart' as td;
import '../core/utils/td_json_util.dart';

part 'video_source.freezed.dart';
part 'video_source.g.dart';

class TdMessageConverter implements JsonConverter<td.Message, Map<String, dynamic>> {
  const TdMessageConverter();

  @override
  td.Message fromJson(Map<String, dynamic> json) {
    final map = TdJsonUtil.sanitize(json);
    return td.convertToObject(jsonEncode(map)) as td.Message;
  }

  @override
  Map<String, dynamic> toJson(td.Message object) {
    return object.toJson();
  }
}

@freezed
abstract class VideoSource with _$VideoSource {
  const factory VideoSource({
    @TdMessageConverter() required td.Message message,
    required String qualityLabel,
    required int width,
    required int height,
  }) = _VideoSource;

  factory VideoSource.fromJson(Map<String, dynamic> json) => _$VideoSourceFromJson(json);
}
