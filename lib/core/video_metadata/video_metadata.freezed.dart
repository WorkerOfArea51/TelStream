// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_metadata.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VideoMetadata {

 int get width; int get height; int get durationMillis; VideoContainer get container; String? get codecHint;
/// Create a copy of VideoMetadata
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoMetadataCopyWith<VideoMetadata> get copyWith => _$VideoMetadataCopyWithImpl<VideoMetadata>(this as VideoMetadata, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoMetadata&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.durationMillis, durationMillis) || other.durationMillis == durationMillis)&&(identical(other.container, container) || other.container == container)&&(identical(other.codecHint, codecHint) || other.codecHint == codecHint));
}


@override
int get hashCode => Object.hash(runtimeType,width,height,durationMillis,container,codecHint);

@override
String toString() {
  return 'VideoMetadata(width: $width, height: $height, durationMillis: $durationMillis, container: $container, codecHint: $codecHint)';
}


}

/// @nodoc
abstract mixin class $VideoMetadataCopyWith<$Res>  {
  factory $VideoMetadataCopyWith(VideoMetadata value, $Res Function(VideoMetadata) _then) = _$VideoMetadataCopyWithImpl;
@useResult
$Res call({
 int width, int height, int durationMillis, VideoContainer container, String? codecHint
});




}
/// @nodoc
class _$VideoMetadataCopyWithImpl<$Res>
    implements $VideoMetadataCopyWith<$Res> {
  _$VideoMetadataCopyWithImpl(this._self, this._then);

  final VideoMetadata _self;
  final $Res Function(VideoMetadata) _then;

/// Create a copy of VideoMetadata
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? width = null,Object? height = null,Object? durationMillis = null,Object? container = null,Object? codecHint = freezed,}) {
  return _then(_self.copyWith(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,durationMillis: null == durationMillis ? _self.durationMillis : durationMillis // ignore: cast_nullable_to_non_nullable
as int,container: null == container ? _self.container : container // ignore: cast_nullable_to_non_nullable
as VideoContainer,codecHint: freezed == codecHint ? _self.codecHint : codecHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoMetadata].
extension VideoMetadataPatterns on VideoMetadata {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoMetadata value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoMetadata() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoMetadata value)  $default,){
final _that = this;
switch (_that) {
case _VideoMetadata():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoMetadata value)?  $default,){
final _that = this;
switch (_that) {
case _VideoMetadata() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int width,  int height,  int durationMillis,  VideoContainer container,  String? codecHint)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoMetadata() when $default != null:
return $default(_that.width,_that.height,_that.durationMillis,_that.container,_that.codecHint);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int width,  int height,  int durationMillis,  VideoContainer container,  String? codecHint)  $default,) {final _that = this;
switch (_that) {
case _VideoMetadata():
return $default(_that.width,_that.height,_that.durationMillis,_that.container,_that.codecHint);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int width,  int height,  int durationMillis,  VideoContainer container,  String? codecHint)?  $default,) {final _that = this;
switch (_that) {
case _VideoMetadata() when $default != null:
return $default(_that.width,_that.height,_that.durationMillis,_that.container,_that.codecHint);case _:
  return null;

}
}

}

/// @nodoc


class _VideoMetadata extends VideoMetadata {
  const _VideoMetadata({required this.width, required this.height, required this.durationMillis, required this.container, this.codecHint}): super._();
  

@override final  int width;
@override final  int height;
@override final  int durationMillis;
@override final  VideoContainer container;
@override final  String? codecHint;

/// Create a copy of VideoMetadata
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoMetadataCopyWith<_VideoMetadata> get copyWith => __$VideoMetadataCopyWithImpl<_VideoMetadata>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoMetadata&&(identical(other.width, width) || other.width == width)&&(identical(other.height, height) || other.height == height)&&(identical(other.durationMillis, durationMillis) || other.durationMillis == durationMillis)&&(identical(other.container, container) || other.container == container)&&(identical(other.codecHint, codecHint) || other.codecHint == codecHint));
}


@override
int get hashCode => Object.hash(runtimeType,width,height,durationMillis,container,codecHint);

@override
String toString() {
  return 'VideoMetadata(width: $width, height: $height, durationMillis: $durationMillis, container: $container, codecHint: $codecHint)';
}


}

/// @nodoc
abstract mixin class _$VideoMetadataCopyWith<$Res> implements $VideoMetadataCopyWith<$Res> {
  factory _$VideoMetadataCopyWith(_VideoMetadata value, $Res Function(_VideoMetadata) _then) = __$VideoMetadataCopyWithImpl;
@override @useResult
$Res call({
 int width, int height, int durationMillis, VideoContainer container, String? codecHint
});




}
/// @nodoc
class __$VideoMetadataCopyWithImpl<$Res>
    implements _$VideoMetadataCopyWith<$Res> {
  __$VideoMetadataCopyWithImpl(this._self, this._then);

  final _VideoMetadata _self;
  final $Res Function(_VideoMetadata) _then;

/// Create a copy of VideoMetadata
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? width = null,Object? height = null,Object? durationMillis = null,Object? container = null,Object? codecHint = freezed,}) {
  return _then(_VideoMetadata(
width: null == width ? _self.width : width // ignore: cast_nullable_to_non_nullable
as int,height: null == height ? _self.height : height // ignore: cast_nullable_to_non_nullable
as int,durationMillis: null == durationMillis ? _self.durationMillis : durationMillis // ignore: cast_nullable_to_non_nullable
as int,container: null == container ? _self.container : container // ignore: cast_nullable_to_non_nullable
as VideoContainer,codecHint: freezed == codecHint ? _self.codecHint : codecHint // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
