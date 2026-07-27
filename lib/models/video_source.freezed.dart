// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_source.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VideoSource {

@TdMessageConverter() td.Message get message; String get qualityLabel; int get width; int get height;
/// Create a copy of VideoSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoSourceCopyWith<VideoSource> get copyWith => _$VideoSourceCopyWithImpl<VideoSource>(this as VideoSource, _$identity);

  /// Serializes this VideoSource to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoSource&&(identical(other.message, message) || other.message == message)&&(identical(other.qualityLabel, qualityLabel) || other.qualityLabel == qualityLabel)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,qualityLabel,width,height);

@override
String toString() {
  return 'VideoSource(message: $message, qualityLabel: $qualityLabel, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class $VideoSourceCopyWith<$Res>  {
  factory $VideoSourceCopyWith(VideoSource value, $Res Function(VideoSource) _then) = _$VideoSourceCopyWithImpl;
@useResult
$Res call({
@TdMessageConverter() td.Message message, String qualityLabel, int width, int height
});




}
/// @nodoc
class _$VideoSourceCopyWithImpl<$Res>
    implements $VideoSourceCopyWith<$Res> {
  _$VideoSourceCopyWithImpl(this._self, this._then);

  final VideoSource _self;
  final $Res Function(VideoSource) _then;

/// Create a copy of VideoSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? message = null,Object? qualityLabel = null,Object? width = null,Object? height = null,}) {
  return _then(_self.copyWith(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as td.Message,qualityLabel: null == qualityLabel ? _self.qualityLabel : qualityLabel // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoSource].
extension VideoSourcePatterns on VideoSource {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoSource value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoSource() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoSource value)  $default,){
final _that = this;
switch (_that) {
case _VideoSource():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoSource value)?  $default,){
final _that = this;
switch (_that) {
case _VideoSource() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@TdMessageConverter()  td.Message message,  String qualityLabel,  int width,  int height)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoSource() when $default != null:
return $default(_that.message,_that.qualityLabel,_that.width,_that.height);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@TdMessageConverter()  td.Message message,  String qualityLabel,  int width,  int height)  $default,) {final _that = this;
switch (_that) {
case _VideoSource():
return $default(_that.message,_that.qualityLabel,_that.width,_that.height);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@TdMessageConverter()  td.Message message,  String qualityLabel,  int width,  int height)?  $default,) {final _that = this;
switch (_that) {
case _VideoSource() when $default != null:
return $default(_that.message,_that.qualityLabel,_that.width,_that.height);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VideoSource implements VideoSource {
  const _VideoSource({@TdMessageConverter() required this.message, required this.qualityLabel, required this.width, required this.height});
  factory _VideoSource.fromJson(Map<String, dynamic> json) => _$VideoSourceFromJson(json);

@override@TdMessageConverter() final  td.Message message;
@override final  String qualityLabel;
@override final  int width;
@override final  int height;

/// Create a copy of VideoSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoSourceCopyWith<_VideoSource> get copyWith => __$VideoSourceCopyWithImpl<_VideoSource>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VideoSourceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoSource&&(identical(other.message, message) || other.message == message)&&(identical(other.qualityLabel, qualityLabel) || other.qualityLabel == qualityLabel)&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,message,qualityLabel,width,height);

@override
String toString() {
  return 'VideoSource(message: $message, qualityLabel: $qualityLabel, width: $width, height: $height)';
}


}

/// @nodoc
abstract mixin class _$VideoSourceCopyWith<$Res> implements $VideoSourceCopyWith<$Res> {
  factory _$VideoSourceCopyWith(_VideoSource value, $Res Function(_VideoSource) _then) = __$VideoSourceCopyWithImpl;
@override @useResult
$Res call({
@TdMessageConverter() td.Message message, String qualityLabel, int width, int height
});




}
/// @nodoc
class __$VideoSourceCopyWithImpl<$Res>
    implements _$VideoSourceCopyWith<$Res> {
  __$VideoSourceCopyWithImpl(this._self, this._then);

  final _VideoSource _self;
  final $Res Function(_VideoSource) _then;

/// Create a copy of VideoSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? message = null,Object? qualityLabel = null,Object? width = null,Object? height = null,}) {
  return _then(_VideoSource(
message: null == message ? _self.message : message // ignore: cast_nullable_to_non_nullable
as td.Message,qualityLabel: null == qualityLabel ? _self.qualityLabel : qualityLabel // ignore: cast_nullable_to_non_nullable
as String,width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
