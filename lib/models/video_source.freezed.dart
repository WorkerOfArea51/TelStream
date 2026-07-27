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

 int get messageId; int get chatId; int get fileSizeBytes; String get fileName; String get mimeType; DateTime get receivedAt; VideoMetadata? get metadata;
/// Create a copy of VideoSource
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoSourceCopyWith<VideoSource> get copyWith => _$VideoSourceCopyWithImpl<VideoSource>(this as VideoSource, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoSource&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.receivedAt, receivedAt) || other.receivedAt == receivedAt)&&(identical(other.metadata, metadata) || other.metadata == metadata));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,chatId,fileSizeBytes,fileName,mimeType,receivedAt,metadata);

@override
String toString() {
  return 'VideoSource(messageId: $messageId, chatId: $chatId, fileSizeBytes: $fileSizeBytes, fileName: $fileName, mimeType: $mimeType, receivedAt: $receivedAt, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class $VideoSourceCopyWith<$Res>  {
  factory $VideoSourceCopyWith(VideoSource value, $Res Function(VideoSource) _then) = _$VideoSourceCopyWithImpl;
@useResult
$Res call({
 int messageId, int chatId, int fileSizeBytes, String fileName, String mimeType, DateTime receivedAt, VideoMetadata? metadata
});


$VideoMetadataCopyWith<$Res>? get metadata;

}
/// @nodoc
class _$VideoSourceCopyWithImpl<$Res>
    implements $VideoSourceCopyWith<$Res> {
  _$VideoSourceCopyWithImpl(this._self, this._then);

  final VideoSource _self;
  final $Res Function(VideoSource) _then;

/// Create a copy of VideoSource
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? messageId = null,Object? chatId = null,Object? fileSizeBytes = null,Object? fileName = null,Object? mimeType = null,Object? receivedAt = null,Object? metadata = freezed,}) {
  return _then(_self.copyWith(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,fileSizeBytes: null == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,receivedAt: null == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as DateTime,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as VideoMetadata?,
  ));
}
/// Create a copy of VideoSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VideoMetadataCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $VideoMetadataCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int messageId,  int chatId,  int fileSizeBytes,  String fileName,  String mimeType,  DateTime receivedAt,  VideoMetadata? metadata)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoSource() when $default != null:
return $default(_that.messageId,_that.chatId,_that.fileSizeBytes,_that.fileName,_that.mimeType,_that.receivedAt,_that.metadata);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int messageId,  int chatId,  int fileSizeBytes,  String fileName,  String mimeType,  DateTime receivedAt,  VideoMetadata? metadata)  $default,) {final _that = this;
switch (_that) {
case _VideoSource():
return $default(_that.messageId,_that.chatId,_that.fileSizeBytes,_that.fileName,_that.mimeType,_that.receivedAt,_that.metadata);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int messageId,  int chatId,  int fileSizeBytes,  String fileName,  String mimeType,  DateTime receivedAt,  VideoMetadata? metadata)?  $default,) {final _that = this;
switch (_that) {
case _VideoSource() when $default != null:
return $default(_that.messageId,_that.chatId,_that.fileSizeBytes,_that.fileName,_that.mimeType,_that.receivedAt,_that.metadata);case _:
  return null;

}
}

}

/// @nodoc


class _VideoSource extends VideoSource {
  const _VideoSource({required this.messageId, required this.chatId, required this.fileSizeBytes, required this.fileName, required this.mimeType, required this.receivedAt, this.metadata}): super._();
  

@override final  int messageId;
@override final  int chatId;
@override final  int fileSizeBytes;
@override final  String fileName;
@override final  String mimeType;
@override final  DateTime receivedAt;
@override final  VideoMetadata? metadata;

/// Create a copy of VideoSource
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoSourceCopyWith<_VideoSource> get copyWith => __$VideoSourceCopyWithImpl<_VideoSource>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoSource&&(identical(other.messageId, messageId) || other.messageId == messageId)&&(identical(other.chatId, chatId) || other.chatId == chatId)&&(identical(other.fileSizeBytes, fileSizeBytes) || other.fileSizeBytes == fileSizeBytes)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.mimeType, mimeType) || other.mimeType == mimeType)&&(identical(other.receivedAt, receivedAt) || other.receivedAt == receivedAt)&&(identical(other.metadata, metadata) || other.metadata == metadata));
}


@override
int get hashCode => Object.hash(runtimeType,messageId,chatId,fileSizeBytes,fileName,mimeType,receivedAt,metadata);

@override
String toString() {
  return 'VideoSource(messageId: $messageId, chatId: $chatId, fileSizeBytes: $fileSizeBytes, fileName: $fileName, mimeType: $mimeType, receivedAt: $receivedAt, metadata: $metadata)';
}


}

/// @nodoc
abstract mixin class _$VideoSourceCopyWith<$Res> implements $VideoSourceCopyWith<$Res> {
  factory _$VideoSourceCopyWith(_VideoSource value, $Res Function(_VideoSource) _then) = __$VideoSourceCopyWithImpl;
@override @useResult
$Res call({
 int messageId, int chatId, int fileSizeBytes, String fileName, String mimeType, DateTime receivedAt, VideoMetadata? metadata
});


@override $VideoMetadataCopyWith<$Res>? get metadata;

}
/// @nodoc
class __$VideoSourceCopyWithImpl<$Res>
    implements _$VideoSourceCopyWith<$Res> {
  __$VideoSourceCopyWithImpl(this._self, this._then);

  final _VideoSource _self;
  final $Res Function(_VideoSource) _then;

/// Create a copy of VideoSource
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? messageId = null,Object? chatId = null,Object? fileSizeBytes = null,Object? fileName = null,Object? mimeType = null,Object? receivedAt = null,Object? metadata = freezed,}) {
  return _then(_VideoSource(
messageId: null == messageId ? _self.messageId : messageId // ignore: cast_nullable_to_non_nullable
as int,chatId: null == chatId ? _self.chatId : chatId // ignore: cast_nullable_to_non_nullable
as int,fileSizeBytes: null == fileSizeBytes ? _self.fileSizeBytes : fileSizeBytes // ignore: cast_nullable_to_non_nullable
as int,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,mimeType: null == mimeType ? _self.mimeType : mimeType // ignore: cast_nullable_to_non_nullable
as String,receivedAt: null == receivedAt ? _self.receivedAt : receivedAt // ignore: cast_nullable_to_non_nullable
as DateTime,metadata: freezed == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as VideoMetadata?,
  ));
}

/// Create a copy of VideoSource
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$VideoMetadataCopyWith<$Res>? get metadata {
    if (_self.metadata == null) {
    return null;
  }

  return $VideoMetadataCopyWith<$Res>(_self.metadata!, (value) {
    return _then(_self.copyWith(metadata: value));
  });
}
}

// dart format on
