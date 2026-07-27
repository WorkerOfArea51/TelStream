// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'episode.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Episode {

 String get title; List<VideoSource> get sources; bool get isMetadataExtracted; int? get episodeNumber;
/// Create a copy of Episode
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$EpisodeCopyWith<Episode> get copyWith => _$EpisodeCopyWithImpl<Episode>(this as Episode, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Episode&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other.sources, sources)&&(identical(other.isMetadataExtracted, isMetadataExtracted) || other.isMetadataExtracted == isMetadataExtracted)&&(identical(other.episodeNumber, episodeNumber) || other.episodeNumber == episodeNumber));
}


@override
int get hashCode => Object.hash(runtimeType,title,const DeepCollectionEquality().hash(sources),isMetadataExtracted,episodeNumber);

@override
String toString() {
  return 'Episode(title: $title, sources: $sources, isMetadataExtracted: $isMetadataExtracted, episodeNumber: $episodeNumber)';
}


}

/// @nodoc
abstract mixin class $EpisodeCopyWith<$Res>  {
  factory $EpisodeCopyWith(Episode value, $Res Function(Episode) _then) = _$EpisodeCopyWithImpl;
@useResult
$Res call({
 String title, List<VideoSource> sources, bool isMetadataExtracted, int? episodeNumber
});




}
/// @nodoc
class _$EpisodeCopyWithImpl<$Res>
    implements $EpisodeCopyWith<$Res> {
  _$EpisodeCopyWithImpl(this._self, this._then);

  final Episode _self;
  final $Res Function(Episode) _then;

/// Create a copy of Episode
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? title = null,Object? sources = null,Object? isMetadataExtracted = null,Object? episodeNumber = freezed,}) {
  return _then(_self.copyWith(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,sources: null == sources ? _self.sources : sources // ignore: cast_nullable_to_non_nullable
as List<VideoSource>,isMetadataExtracted: null == isMetadataExtracted ? _self.isMetadataExtracted : isMetadataExtracted // ignore: cast_nullable_to_non_nullable
as bool,episodeNumber: freezed == episodeNumber ? _self.episodeNumber : episodeNumber // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Episode].
extension EpisodePatterns on Episode {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Episode value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Episode() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Episode value)  $default,){
final _that = this;
switch (_that) {
case _Episode():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Episode value)?  $default,){
final _that = this;
switch (_that) {
case _Episode() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String title,  List<VideoSource> sources,  bool isMetadataExtracted,  int? episodeNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Episode() when $default != null:
return $default(_that.title,_that.sources,_that.isMetadataExtracted,_that.episodeNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String title,  List<VideoSource> sources,  bool isMetadataExtracted,  int? episodeNumber)  $default,) {final _that = this;
switch (_that) {
case _Episode():
return $default(_that.title,_that.sources,_that.isMetadataExtracted,_that.episodeNumber);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String title,  List<VideoSource> sources,  bool isMetadataExtracted,  int? episodeNumber)?  $default,) {final _that = this;
switch (_that) {
case _Episode() when $default != null:
return $default(_that.title,_that.sources,_that.isMetadataExtracted,_that.episodeNumber);case _:
  return null;

}
}

}

/// @nodoc


class _Episode extends Episode {
  const _Episode({required this.title, final  List<VideoSource> sources = const [], this.isMetadataExtracted = false, this.episodeNumber}): _sources = sources,super._();
  

@override final  String title;
 final  List<VideoSource> _sources;
@override@JsonKey() List<VideoSource> get sources {
  if (_sources is EqualUnmodifiableListView) return _sources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sources);
}

@override@JsonKey() final  bool isMetadataExtracted;
@override final  int? episodeNumber;

/// Create a copy of Episode
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$EpisodeCopyWith<_Episode> get copyWith => __$EpisodeCopyWithImpl<_Episode>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Episode&&(identical(other.title, title) || other.title == title)&&const DeepCollectionEquality().equals(other._sources, _sources)&&(identical(other.isMetadataExtracted, isMetadataExtracted) || other.isMetadataExtracted == isMetadataExtracted)&&(identical(other.episodeNumber, episodeNumber) || other.episodeNumber == episodeNumber));
}


@override
int get hashCode => Object.hash(runtimeType,title,const DeepCollectionEquality().hash(_sources),isMetadataExtracted,episodeNumber);

@override
String toString() {
  return 'Episode(title: $title, sources: $sources, isMetadataExtracted: $isMetadataExtracted, episodeNumber: $episodeNumber)';
}


}

/// @nodoc
abstract mixin class _$EpisodeCopyWith<$Res> implements $EpisodeCopyWith<$Res> {
  factory _$EpisodeCopyWith(_Episode value, $Res Function(_Episode) _then) = __$EpisodeCopyWithImpl;
@override @useResult
$Res call({
 String title, List<VideoSource> sources, bool isMetadataExtracted, int? episodeNumber
});




}
/// @nodoc
class __$EpisodeCopyWithImpl<$Res>
    implements _$EpisodeCopyWith<$Res> {
  __$EpisodeCopyWithImpl(this._self, this._then);

  final _Episode _self;
  final $Res Function(_Episode) _then;

/// Create a copy of Episode
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? title = null,Object? sources = null,Object? isMetadataExtracted = null,Object? episodeNumber = freezed,}) {
  return _then(_Episode(
title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,sources: null == sources ? _self._sources : sources // ignore: cast_nullable_to_non_nullable
as List<VideoSource>,isMetadataExtracted: null == isMetadataExtracted ? _self.isMetadataExtracted : isMetadataExtracted // ignore: cast_nullable_to_non_nullable
as bool,episodeNumber: freezed == episodeNumber ? _self.episodeNumber : episodeNumber // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
