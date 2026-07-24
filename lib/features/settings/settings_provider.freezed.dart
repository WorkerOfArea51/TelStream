// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_provider.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PlayerLayoutSettings {

 String get animeLayout; String get moviesLayout; String get webSeriesLayout; String get seekbarStyle; bool get dynamicSpeedOverlay; bool get showStatsForNerds;
/// Create a copy of PlayerLayoutSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlayerLayoutSettingsCopyWith<PlayerLayoutSettings> get copyWith => _$PlayerLayoutSettingsCopyWithImpl<PlayerLayoutSettings>(this as PlayerLayoutSettings, _$identity);

  /// Serializes this PlayerLayoutSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlayerLayoutSettings&&(identical(other.animeLayout, animeLayout) || other.animeLayout == animeLayout)&&(identical(other.moviesLayout, moviesLayout) || other.moviesLayout == moviesLayout)&&(identical(other.webSeriesLayout, webSeriesLayout) || other.webSeriesLayout == webSeriesLayout)&&(identical(other.seekbarStyle, seekbarStyle) || other.seekbarStyle == seekbarStyle)&&(identical(other.dynamicSpeedOverlay, dynamicSpeedOverlay) || other.dynamicSpeedOverlay == dynamicSpeedOverlay)&&(identical(other.showStatsForNerds, showStatsForNerds) || other.showStatsForNerds == showStatsForNerds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,animeLayout,moviesLayout,webSeriesLayout,seekbarStyle,dynamicSpeedOverlay,showStatsForNerds);

@override
String toString() {
  return 'PlayerLayoutSettings(animeLayout: $animeLayout, moviesLayout: $moviesLayout, webSeriesLayout: $webSeriesLayout, seekbarStyle: $seekbarStyle, dynamicSpeedOverlay: $dynamicSpeedOverlay, showStatsForNerds: $showStatsForNerds)';
}


}

/// @nodoc
abstract mixin class $PlayerLayoutSettingsCopyWith<$Res>  {
  factory $PlayerLayoutSettingsCopyWith(PlayerLayoutSettings value, $Res Function(PlayerLayoutSettings) _then) = _$PlayerLayoutSettingsCopyWithImpl;
@useResult
$Res call({
 String animeLayout, String moviesLayout, String webSeriesLayout, String seekbarStyle, bool dynamicSpeedOverlay, bool showStatsForNerds
});




}
/// @nodoc
class _$PlayerLayoutSettingsCopyWithImpl<$Res>
    implements $PlayerLayoutSettingsCopyWith<$Res> {
  _$PlayerLayoutSettingsCopyWithImpl(this._self, this._then);

  final PlayerLayoutSettings _self;
  final $Res Function(PlayerLayoutSettings) _then;

/// Create a copy of PlayerLayoutSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? animeLayout = null,Object? moviesLayout = null,Object? webSeriesLayout = null,Object? seekbarStyle = null,Object? dynamicSpeedOverlay = null,Object? showStatsForNerds = null,}) {
  return _then(_self.copyWith(
animeLayout: null == animeLayout ? _self.animeLayout : animeLayout // ignore: cast_nullable_to_non_nullable
as String,moviesLayout: null == moviesLayout ? _self.moviesLayout : moviesLayout // ignore: cast_nullable_to_non_nullable
as String,webSeriesLayout: null == webSeriesLayout ? _self.webSeriesLayout : webSeriesLayout // ignore: cast_nullable_to_non_nullable
as String,seekbarStyle: null == seekbarStyle ? _self.seekbarStyle : seekbarStyle // ignore: cast_nullable_to_non_nullable
as String,dynamicSpeedOverlay: null == dynamicSpeedOverlay ? _self.dynamicSpeedOverlay : dynamicSpeedOverlay // ignore: cast_nullable_to_non_nullable
as bool,showStatsForNerds: null == showStatsForNerds ? _self.showStatsForNerds : showStatsForNerds // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [PlayerLayoutSettings].
extension PlayerLayoutSettingsPatterns on PlayerLayoutSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlayerLayoutSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlayerLayoutSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlayerLayoutSettings value)  $default,){
final _that = this;
switch (_that) {
case _PlayerLayoutSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlayerLayoutSettings value)?  $default,){
final _that = this;
switch (_that) {
case _PlayerLayoutSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String animeLayout,  String moviesLayout,  String webSeriesLayout,  String seekbarStyle,  bool dynamicSpeedOverlay,  bool showStatsForNerds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlayerLayoutSettings() when $default != null:
return $default(_that.animeLayout,_that.moviesLayout,_that.webSeriesLayout,_that.seekbarStyle,_that.dynamicSpeedOverlay,_that.showStatsForNerds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String animeLayout,  String moviesLayout,  String webSeriesLayout,  String seekbarStyle,  bool dynamicSpeedOverlay,  bool showStatsForNerds)  $default,) {final _that = this;
switch (_that) {
case _PlayerLayoutSettings():
return $default(_that.animeLayout,_that.moviesLayout,_that.webSeriesLayout,_that.seekbarStyle,_that.dynamicSpeedOverlay,_that.showStatsForNerds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String animeLayout,  String moviesLayout,  String webSeriesLayout,  String seekbarStyle,  bool dynamicSpeedOverlay,  bool showStatsForNerds)?  $default,) {final _that = this;
switch (_that) {
case _PlayerLayoutSettings() when $default != null:
return $default(_that.animeLayout,_that.moviesLayout,_that.webSeriesLayout,_that.seekbarStyle,_that.dynamicSpeedOverlay,_that.showStatsForNerds);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PlayerLayoutSettings implements PlayerLayoutSettings {
  const _PlayerLayoutSettings({this.animeLayout = 'Grid', this.moviesLayout = 'Grid', this.webSeriesLayout = 'Grid', this.seekbarStyle = 'Standard', this.dynamicSpeedOverlay = true, this.showStatsForNerds = false});
  factory _PlayerLayoutSettings.fromJson(Map<String, dynamic> json) => _$PlayerLayoutSettingsFromJson(json);

@override@JsonKey() final  String animeLayout;
@override@JsonKey() final  String moviesLayout;
@override@JsonKey() final  String webSeriesLayout;
@override@JsonKey() final  String seekbarStyle;
@override@JsonKey() final  bool dynamicSpeedOverlay;
@override@JsonKey() final  bool showStatsForNerds;

/// Create a copy of PlayerLayoutSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlayerLayoutSettingsCopyWith<_PlayerLayoutSettings> get copyWith => __$PlayerLayoutSettingsCopyWithImpl<_PlayerLayoutSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PlayerLayoutSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlayerLayoutSettings&&(identical(other.animeLayout, animeLayout) || other.animeLayout == animeLayout)&&(identical(other.moviesLayout, moviesLayout) || other.moviesLayout == moviesLayout)&&(identical(other.webSeriesLayout, webSeriesLayout) || other.webSeriesLayout == webSeriesLayout)&&(identical(other.seekbarStyle, seekbarStyle) || other.seekbarStyle == seekbarStyle)&&(identical(other.dynamicSpeedOverlay, dynamicSpeedOverlay) || other.dynamicSpeedOverlay == dynamicSpeedOverlay)&&(identical(other.showStatsForNerds, showStatsForNerds) || other.showStatsForNerds == showStatsForNerds));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,animeLayout,moviesLayout,webSeriesLayout,seekbarStyle,dynamicSpeedOverlay,showStatsForNerds);

@override
String toString() {
  return 'PlayerLayoutSettings(animeLayout: $animeLayout, moviesLayout: $moviesLayout, webSeriesLayout: $webSeriesLayout, seekbarStyle: $seekbarStyle, dynamicSpeedOverlay: $dynamicSpeedOverlay, showStatsForNerds: $showStatsForNerds)';
}


}

/// @nodoc
abstract mixin class _$PlayerLayoutSettingsCopyWith<$Res> implements $PlayerLayoutSettingsCopyWith<$Res> {
  factory _$PlayerLayoutSettingsCopyWith(_PlayerLayoutSettings value, $Res Function(_PlayerLayoutSettings) _then) = __$PlayerLayoutSettingsCopyWithImpl;
@override @useResult
$Res call({
 String animeLayout, String moviesLayout, String webSeriesLayout, String seekbarStyle, bool dynamicSpeedOverlay, bool showStatsForNerds
});




}
/// @nodoc
class __$PlayerLayoutSettingsCopyWithImpl<$Res>
    implements _$PlayerLayoutSettingsCopyWith<$Res> {
  __$PlayerLayoutSettingsCopyWithImpl(this._self, this._then);

  final _PlayerLayoutSettings _self;
  final $Res Function(_PlayerLayoutSettings) _then;

/// Create a copy of PlayerLayoutSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? animeLayout = null,Object? moviesLayout = null,Object? webSeriesLayout = null,Object? seekbarStyle = null,Object? dynamicSpeedOverlay = null,Object? showStatsForNerds = null,}) {
  return _then(_PlayerLayoutSettings(
animeLayout: null == animeLayout ? _self.animeLayout : animeLayout // ignore: cast_nullable_to_non_nullable
as String,moviesLayout: null == moviesLayout ? _self.moviesLayout : moviesLayout // ignore: cast_nullable_to_non_nullable
as String,webSeriesLayout: null == webSeriesLayout ? _self.webSeriesLayout : webSeriesLayout // ignore: cast_nullable_to_non_nullable
as String,seekbarStyle: null == seekbarStyle ? _self.seekbarStyle : seekbarStyle // ignore: cast_nullable_to_non_nullable
as String,dynamicSpeedOverlay: null == dynamicSpeedOverlay ? _self.dynamicSpeedOverlay : dynamicSpeedOverlay // ignore: cast_nullable_to_non_nullable
as bool,showStatsForNerds: null == showStatsForNerds ? _self.showStatsForNerds : showStatsForNerds // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$GestureSettings {

 int get doubleTapSeekDuration; bool get horizontalSwipeToSeek; bool get volumeGestures; bool get brightnessGestures; bool get pinchToZoom; String get leftSwipeGesture; String get rightSwipeGesture; double get longPressSpeed; String get gestureSensitivity; bool get longPressVibration;
/// Create a copy of GestureSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GestureSettingsCopyWith<GestureSettings> get copyWith => _$GestureSettingsCopyWithImpl<GestureSettings>(this as GestureSettings, _$identity);

  /// Serializes this GestureSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is GestureSettings&&(identical(other.doubleTapSeekDuration, doubleTapSeekDuration) || other.doubleTapSeekDuration == doubleTapSeekDuration)&&(identical(other.horizontalSwipeToSeek, horizontalSwipeToSeek) || other.horizontalSwipeToSeek == horizontalSwipeToSeek)&&(identical(other.volumeGestures, volumeGestures) || other.volumeGestures == volumeGestures)&&(identical(other.brightnessGestures, brightnessGestures) || other.brightnessGestures == brightnessGestures)&&(identical(other.pinchToZoom, pinchToZoom) || other.pinchToZoom == pinchToZoom)&&(identical(other.leftSwipeGesture, leftSwipeGesture) || other.leftSwipeGesture == leftSwipeGesture)&&(identical(other.rightSwipeGesture, rightSwipeGesture) || other.rightSwipeGesture == rightSwipeGesture)&&(identical(other.longPressSpeed, longPressSpeed) || other.longPressSpeed == longPressSpeed)&&(identical(other.gestureSensitivity, gestureSensitivity) || other.gestureSensitivity == gestureSensitivity)&&(identical(other.longPressVibration, longPressVibration) || other.longPressVibration == longPressVibration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,doubleTapSeekDuration,horizontalSwipeToSeek,volumeGestures,brightnessGestures,pinchToZoom,leftSwipeGesture,rightSwipeGesture,longPressSpeed,gestureSensitivity,longPressVibration);

@override
String toString() {
  return 'GestureSettings(doubleTapSeekDuration: $doubleTapSeekDuration, horizontalSwipeToSeek: $horizontalSwipeToSeek, volumeGestures: $volumeGestures, brightnessGestures: $brightnessGestures, pinchToZoom: $pinchToZoom, leftSwipeGesture: $leftSwipeGesture, rightSwipeGesture: $rightSwipeGesture, longPressSpeed: $longPressSpeed, gestureSensitivity: $gestureSensitivity, longPressVibration: $longPressVibration)';
}


}

/// @nodoc
abstract mixin class $GestureSettingsCopyWith<$Res>  {
  factory $GestureSettingsCopyWith(GestureSettings value, $Res Function(GestureSettings) _then) = _$GestureSettingsCopyWithImpl;
@useResult
$Res call({
 int doubleTapSeekDuration, bool horizontalSwipeToSeek, bool volumeGestures, bool brightnessGestures, bool pinchToZoom, String leftSwipeGesture, String rightSwipeGesture, double longPressSpeed, String gestureSensitivity, bool longPressVibration
});




}
/// @nodoc
class _$GestureSettingsCopyWithImpl<$Res>
    implements $GestureSettingsCopyWith<$Res> {
  _$GestureSettingsCopyWithImpl(this._self, this._then);

  final GestureSettings _self;
  final $Res Function(GestureSettings) _then;

/// Create a copy of GestureSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? doubleTapSeekDuration = null,Object? horizontalSwipeToSeek = null,Object? volumeGestures = null,Object? brightnessGestures = null,Object? pinchToZoom = null,Object? leftSwipeGesture = null,Object? rightSwipeGesture = null,Object? longPressSpeed = null,Object? gestureSensitivity = null,Object? longPressVibration = null,}) {
  return _then(_self.copyWith(
doubleTapSeekDuration: null == doubleTapSeekDuration ? _self.doubleTapSeekDuration : doubleTapSeekDuration // ignore: cast_nullable_to_non_nullable
as int,horizontalSwipeToSeek: null == horizontalSwipeToSeek ? _self.horizontalSwipeToSeek : horizontalSwipeToSeek // ignore: cast_nullable_to_non_nullable
as bool,volumeGestures: null == volumeGestures ? _self.volumeGestures : volumeGestures // ignore: cast_nullable_to_non_nullable
as bool,brightnessGestures: null == brightnessGestures ? _self.brightnessGestures : brightnessGestures // ignore: cast_nullable_to_non_nullable
as bool,pinchToZoom: null == pinchToZoom ? _self.pinchToZoom : pinchToZoom // ignore: cast_nullable_to_non_nullable
as bool,leftSwipeGesture: null == leftSwipeGesture ? _self.leftSwipeGesture : leftSwipeGesture // ignore: cast_nullable_to_non_nullable
as String,rightSwipeGesture: null == rightSwipeGesture ? _self.rightSwipeGesture : rightSwipeGesture // ignore: cast_nullable_to_non_nullable
as String,longPressSpeed: null == longPressSpeed ? _self.longPressSpeed : longPressSpeed // ignore: cast_nullable_to_non_nullable
as double,gestureSensitivity: null == gestureSensitivity ? _self.gestureSensitivity : gestureSensitivity // ignore: cast_nullable_to_non_nullable
as String,longPressVibration: null == longPressVibration ? _self.longPressVibration : longPressVibration // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [GestureSettings].
extension GestureSettingsPatterns on GestureSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _GestureSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _GestureSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _GestureSettings value)  $default,){
final _that = this;
switch (_that) {
case _GestureSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _GestureSettings value)?  $default,){
final _that = this;
switch (_that) {
case _GestureSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int doubleTapSeekDuration,  bool horizontalSwipeToSeek,  bool volumeGestures,  bool brightnessGestures,  bool pinchToZoom,  String leftSwipeGesture,  String rightSwipeGesture,  double longPressSpeed,  String gestureSensitivity,  bool longPressVibration)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _GestureSettings() when $default != null:
return $default(_that.doubleTapSeekDuration,_that.horizontalSwipeToSeek,_that.volumeGestures,_that.brightnessGestures,_that.pinchToZoom,_that.leftSwipeGesture,_that.rightSwipeGesture,_that.longPressSpeed,_that.gestureSensitivity,_that.longPressVibration);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int doubleTapSeekDuration,  bool horizontalSwipeToSeek,  bool volumeGestures,  bool brightnessGestures,  bool pinchToZoom,  String leftSwipeGesture,  String rightSwipeGesture,  double longPressSpeed,  String gestureSensitivity,  bool longPressVibration)  $default,) {final _that = this;
switch (_that) {
case _GestureSettings():
return $default(_that.doubleTapSeekDuration,_that.horizontalSwipeToSeek,_that.volumeGestures,_that.brightnessGestures,_that.pinchToZoom,_that.leftSwipeGesture,_that.rightSwipeGesture,_that.longPressSpeed,_that.gestureSensitivity,_that.longPressVibration);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int doubleTapSeekDuration,  bool horizontalSwipeToSeek,  bool volumeGestures,  bool brightnessGestures,  bool pinchToZoom,  String leftSwipeGesture,  String rightSwipeGesture,  double longPressSpeed,  String gestureSensitivity,  bool longPressVibration)?  $default,) {final _that = this;
switch (_that) {
case _GestureSettings() when $default != null:
return $default(_that.doubleTapSeekDuration,_that.horizontalSwipeToSeek,_that.volumeGestures,_that.brightnessGestures,_that.pinchToZoom,_that.leftSwipeGesture,_that.rightSwipeGesture,_that.longPressSpeed,_that.gestureSensitivity,_that.longPressVibration);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _GestureSettings implements GestureSettings {
  const _GestureSettings({this.doubleTapSeekDuration = 10, this.horizontalSwipeToSeek = true, this.volumeGestures = true, this.brightnessGestures = true, this.pinchToZoom = true, this.leftSwipeGesture = 'Brightness', this.rightSwipeGesture = 'Volume', this.longPressSpeed = 1.5, this.gestureSensitivity = 'Normal', this.longPressVibration = true});
  factory _GestureSettings.fromJson(Map<String, dynamic> json) => _$GestureSettingsFromJson(json);

@override@JsonKey() final  int doubleTapSeekDuration;
@override@JsonKey() final  bool horizontalSwipeToSeek;
@override@JsonKey() final  bool volumeGestures;
@override@JsonKey() final  bool brightnessGestures;
@override@JsonKey() final  bool pinchToZoom;
@override@JsonKey() final  String leftSwipeGesture;
@override@JsonKey() final  String rightSwipeGesture;
@override@JsonKey() final  double longPressSpeed;
@override@JsonKey() final  String gestureSensitivity;
@override@JsonKey() final  bool longPressVibration;

/// Create a copy of GestureSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GestureSettingsCopyWith<_GestureSettings> get copyWith => __$GestureSettingsCopyWithImpl<_GestureSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$GestureSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _GestureSettings&&(identical(other.doubleTapSeekDuration, doubleTapSeekDuration) || other.doubleTapSeekDuration == doubleTapSeekDuration)&&(identical(other.horizontalSwipeToSeek, horizontalSwipeToSeek) || other.horizontalSwipeToSeek == horizontalSwipeToSeek)&&(identical(other.volumeGestures, volumeGestures) || other.volumeGestures == volumeGestures)&&(identical(other.brightnessGestures, brightnessGestures) || other.brightnessGestures == brightnessGestures)&&(identical(other.pinchToZoom, pinchToZoom) || other.pinchToZoom == pinchToZoom)&&(identical(other.leftSwipeGesture, leftSwipeGesture) || other.leftSwipeGesture == leftSwipeGesture)&&(identical(other.rightSwipeGesture, rightSwipeGesture) || other.rightSwipeGesture == rightSwipeGesture)&&(identical(other.longPressSpeed, longPressSpeed) || other.longPressSpeed == longPressSpeed)&&(identical(other.gestureSensitivity, gestureSensitivity) || other.gestureSensitivity == gestureSensitivity)&&(identical(other.longPressVibration, longPressVibration) || other.longPressVibration == longPressVibration));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,doubleTapSeekDuration,horizontalSwipeToSeek,volumeGestures,brightnessGestures,pinchToZoom,leftSwipeGesture,rightSwipeGesture,longPressSpeed,gestureSensitivity,longPressVibration);

@override
String toString() {
  return 'GestureSettings(doubleTapSeekDuration: $doubleTapSeekDuration, horizontalSwipeToSeek: $horizontalSwipeToSeek, volumeGestures: $volumeGestures, brightnessGestures: $brightnessGestures, pinchToZoom: $pinchToZoom, leftSwipeGesture: $leftSwipeGesture, rightSwipeGesture: $rightSwipeGesture, longPressSpeed: $longPressSpeed, gestureSensitivity: $gestureSensitivity, longPressVibration: $longPressVibration)';
}


}

/// @nodoc
abstract mixin class _$GestureSettingsCopyWith<$Res> implements $GestureSettingsCopyWith<$Res> {
  factory _$GestureSettingsCopyWith(_GestureSettings value, $Res Function(_GestureSettings) _then) = __$GestureSettingsCopyWithImpl;
@override @useResult
$Res call({
 int doubleTapSeekDuration, bool horizontalSwipeToSeek, bool volumeGestures, bool brightnessGestures, bool pinchToZoom, String leftSwipeGesture, String rightSwipeGesture, double longPressSpeed, String gestureSensitivity, bool longPressVibration
});




}
/// @nodoc
class __$GestureSettingsCopyWithImpl<$Res>
    implements _$GestureSettingsCopyWith<$Res> {
  __$GestureSettingsCopyWithImpl(this._self, this._then);

  final _GestureSettings _self;
  final $Res Function(_GestureSettings) _then;

/// Create a copy of GestureSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? doubleTapSeekDuration = null,Object? horizontalSwipeToSeek = null,Object? volumeGestures = null,Object? brightnessGestures = null,Object? pinchToZoom = null,Object? leftSwipeGesture = null,Object? rightSwipeGesture = null,Object? longPressSpeed = null,Object? gestureSensitivity = null,Object? longPressVibration = null,}) {
  return _then(_GestureSettings(
doubleTapSeekDuration: null == doubleTapSeekDuration ? _self.doubleTapSeekDuration : doubleTapSeekDuration // ignore: cast_nullable_to_non_nullable
as int,horizontalSwipeToSeek: null == horizontalSwipeToSeek ? _self.horizontalSwipeToSeek : horizontalSwipeToSeek // ignore: cast_nullable_to_non_nullable
as bool,volumeGestures: null == volumeGestures ? _self.volumeGestures : volumeGestures // ignore: cast_nullable_to_non_nullable
as bool,brightnessGestures: null == brightnessGestures ? _self.brightnessGestures : brightnessGestures // ignore: cast_nullable_to_non_nullable
as bool,pinchToZoom: null == pinchToZoom ? _self.pinchToZoom : pinchToZoom // ignore: cast_nullable_to_non_nullable
as bool,leftSwipeGesture: null == leftSwipeGesture ? _self.leftSwipeGesture : leftSwipeGesture // ignore: cast_nullable_to_non_nullable
as String,rightSwipeGesture: null == rightSwipeGesture ? _self.rightSwipeGesture : rightSwipeGesture // ignore: cast_nullable_to_non_nullable
as String,longPressSpeed: null == longPressSpeed ? _self.longPressSpeed : longPressSpeed // ignore: cast_nullable_to_non_nullable
as double,gestureSensitivity: null == gestureSensitivity ? _self.gestureSensitivity : gestureSensitivity // ignore: cast_nullable_to_non_nullable
as String,longPressVibration: null == longPressVibration ? _self.longPressVibration : longPressVibration // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}


/// @nodoc
mixin _$AudioSettings {

 bool get volumeNormalization; bool get pitchCorrection; bool get dynamicRangeCompression; bool get equalizerEnabled; List<double> get equalizerBands; String get equalizerPreset;
/// Create a copy of AudioSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AudioSettingsCopyWith<AudioSettings> get copyWith => _$AudioSettingsCopyWithImpl<AudioSettings>(this as AudioSettings, _$identity);

  /// Serializes this AudioSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AudioSettings&&(identical(other.volumeNormalization, volumeNormalization) || other.volumeNormalization == volumeNormalization)&&(identical(other.pitchCorrection, pitchCorrection) || other.pitchCorrection == pitchCorrection)&&(identical(other.dynamicRangeCompression, dynamicRangeCompression) || other.dynamicRangeCompression == dynamicRangeCompression)&&(identical(other.equalizerEnabled, equalizerEnabled) || other.equalizerEnabled == equalizerEnabled)&&const DeepCollectionEquality().equals(other.equalizerBands, equalizerBands)&&(identical(other.equalizerPreset, equalizerPreset) || other.equalizerPreset == equalizerPreset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,volumeNormalization,pitchCorrection,dynamicRangeCompression,equalizerEnabled,const DeepCollectionEquality().hash(equalizerBands),equalizerPreset);

@override
String toString() {
  return 'AudioSettings(volumeNormalization: $volumeNormalization, pitchCorrection: $pitchCorrection, dynamicRangeCompression: $dynamicRangeCompression, equalizerEnabled: $equalizerEnabled, equalizerBands: $equalizerBands, equalizerPreset: $equalizerPreset)';
}


}

/// @nodoc
abstract mixin class $AudioSettingsCopyWith<$Res>  {
  factory $AudioSettingsCopyWith(AudioSettings value, $Res Function(AudioSettings) _then) = _$AudioSettingsCopyWithImpl;
@useResult
$Res call({
 bool volumeNormalization, bool pitchCorrection, bool dynamicRangeCompression, bool equalizerEnabled, List<double> equalizerBands, String equalizerPreset
});




}
/// @nodoc
class _$AudioSettingsCopyWithImpl<$Res>
    implements $AudioSettingsCopyWith<$Res> {
  _$AudioSettingsCopyWithImpl(this._self, this._then);

  final AudioSettings _self;
  final $Res Function(AudioSettings) _then;

/// Create a copy of AudioSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? volumeNormalization = null,Object? pitchCorrection = null,Object? dynamicRangeCompression = null,Object? equalizerEnabled = null,Object? equalizerBands = null,Object? equalizerPreset = null,}) {
  return _then(_self.copyWith(
volumeNormalization: null == volumeNormalization ? _self.volumeNormalization : volumeNormalization // ignore: cast_nullable_to_non_nullable
as bool,pitchCorrection: null == pitchCorrection ? _self.pitchCorrection : pitchCorrection // ignore: cast_nullable_to_non_nullable
as bool,dynamicRangeCompression: null == dynamicRangeCompression ? _self.dynamicRangeCompression : dynamicRangeCompression // ignore: cast_nullable_to_non_nullable
as bool,equalizerEnabled: null == equalizerEnabled ? _self.equalizerEnabled : equalizerEnabled // ignore: cast_nullable_to_non_nullable
as bool,equalizerBands: null == equalizerBands ? _self.equalizerBands : equalizerBands // ignore: cast_nullable_to_non_nullable
as List<double>,equalizerPreset: null == equalizerPreset ? _self.equalizerPreset : equalizerPreset // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [AudioSettings].
extension AudioSettingsPatterns on AudioSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AudioSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AudioSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AudioSettings value)  $default,){
final _that = this;
switch (_that) {
case _AudioSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AudioSettings value)?  $default,){
final _that = this;
switch (_that) {
case _AudioSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( bool volumeNormalization,  bool pitchCorrection,  bool dynamicRangeCompression,  bool equalizerEnabled,  List<double> equalizerBands,  String equalizerPreset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AudioSettings() when $default != null:
return $default(_that.volumeNormalization,_that.pitchCorrection,_that.dynamicRangeCompression,_that.equalizerEnabled,_that.equalizerBands,_that.equalizerPreset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( bool volumeNormalization,  bool pitchCorrection,  bool dynamicRangeCompression,  bool equalizerEnabled,  List<double> equalizerBands,  String equalizerPreset)  $default,) {final _that = this;
switch (_that) {
case _AudioSettings():
return $default(_that.volumeNormalization,_that.pitchCorrection,_that.dynamicRangeCompression,_that.equalizerEnabled,_that.equalizerBands,_that.equalizerPreset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( bool volumeNormalization,  bool pitchCorrection,  bool dynamicRangeCompression,  bool equalizerEnabled,  List<double> equalizerBands,  String equalizerPreset)?  $default,) {final _that = this;
switch (_that) {
case _AudioSettings() when $default != null:
return $default(_that.volumeNormalization,_that.pitchCorrection,_that.dynamicRangeCompression,_that.equalizerEnabled,_that.equalizerBands,_that.equalizerPreset);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _AudioSettings implements AudioSettings {
  const _AudioSettings({this.volumeNormalization = false, this.pitchCorrection = true, this.dynamicRangeCompression = false, this.equalizerEnabled = false, final  List<double> equalizerBands = const [0.0, 0.0, 0.0, 0.0, 0.0], this.equalizerPreset = 'Flat'}): _equalizerBands = equalizerBands;
  factory _AudioSettings.fromJson(Map<String, dynamic> json) => _$AudioSettingsFromJson(json);

@override@JsonKey() final  bool volumeNormalization;
@override@JsonKey() final  bool pitchCorrection;
@override@JsonKey() final  bool dynamicRangeCompression;
@override@JsonKey() final  bool equalizerEnabled;
 final  List<double> _equalizerBands;
@override@JsonKey() List<double> get equalizerBands {
  if (_equalizerBands is EqualUnmodifiableListView) return _equalizerBands;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_equalizerBands);
}

@override@JsonKey() final  String equalizerPreset;

/// Create a copy of AudioSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AudioSettingsCopyWith<_AudioSettings> get copyWith => __$AudioSettingsCopyWithImpl<_AudioSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$AudioSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AudioSettings&&(identical(other.volumeNormalization, volumeNormalization) || other.volumeNormalization == volumeNormalization)&&(identical(other.pitchCorrection, pitchCorrection) || other.pitchCorrection == pitchCorrection)&&(identical(other.dynamicRangeCompression, dynamicRangeCompression) || other.dynamicRangeCompression == dynamicRangeCompression)&&(identical(other.equalizerEnabled, equalizerEnabled) || other.equalizerEnabled == equalizerEnabled)&&const DeepCollectionEquality().equals(other._equalizerBands, _equalizerBands)&&(identical(other.equalizerPreset, equalizerPreset) || other.equalizerPreset == equalizerPreset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,volumeNormalization,pitchCorrection,dynamicRangeCompression,equalizerEnabled,const DeepCollectionEquality().hash(_equalizerBands),equalizerPreset);

@override
String toString() {
  return 'AudioSettings(volumeNormalization: $volumeNormalization, pitchCorrection: $pitchCorrection, dynamicRangeCompression: $dynamicRangeCompression, equalizerEnabled: $equalizerEnabled, equalizerBands: $equalizerBands, equalizerPreset: $equalizerPreset)';
}


}

/// @nodoc
abstract mixin class _$AudioSettingsCopyWith<$Res> implements $AudioSettingsCopyWith<$Res> {
  factory _$AudioSettingsCopyWith(_AudioSettings value, $Res Function(_AudioSettings) _then) = __$AudioSettingsCopyWithImpl;
@override @useResult
$Res call({
 bool volumeNormalization, bool pitchCorrection, bool dynamicRangeCompression, bool equalizerEnabled, List<double> equalizerBands, String equalizerPreset
});




}
/// @nodoc
class __$AudioSettingsCopyWithImpl<$Res>
    implements _$AudioSettingsCopyWith<$Res> {
  __$AudioSettingsCopyWithImpl(this._self, this._then);

  final _AudioSettings _self;
  final $Res Function(_AudioSettings) _then;

/// Create a copy of AudioSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? volumeNormalization = null,Object? pitchCorrection = null,Object? dynamicRangeCompression = null,Object? equalizerEnabled = null,Object? equalizerBands = null,Object? equalizerPreset = null,}) {
  return _then(_AudioSettings(
volumeNormalization: null == volumeNormalization ? _self.volumeNormalization : volumeNormalization // ignore: cast_nullable_to_non_nullable
as bool,pitchCorrection: null == pitchCorrection ? _self.pitchCorrection : pitchCorrection // ignore: cast_nullable_to_non_nullable
as bool,dynamicRangeCompression: null == dynamicRangeCompression ? _self.dynamicRangeCompression : dynamicRangeCompression // ignore: cast_nullable_to_non_nullable
as bool,equalizerEnabled: null == equalizerEnabled ? _self.equalizerEnabled : equalizerEnabled // ignore: cast_nullable_to_non_nullable
as bool,equalizerBands: null == equalizerBands ? _self._equalizerBands : equalizerBands // ignore: cast_nullable_to_non_nullable
as List<double>,equalizerPreset: null == equalizerPreset ? _self.equalizerPreset : equalizerPreset // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$SubtitleSettings {

 String get subtitleRendererMode; String get preferredSubtitleProvider; double get subtitleFontSize; String get subtitleColor; double get subtitleDelay; String get subtitleFont; double get subtitleBottomMargin; double get subtitleHorizontalOffset;
/// Create a copy of SubtitleSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubtitleSettingsCopyWith<SubtitleSettings> get copyWith => _$SubtitleSettingsCopyWithImpl<SubtitleSettings>(this as SubtitleSettings, _$identity);

  /// Serializes this SubtitleSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubtitleSettings&&(identical(other.subtitleRendererMode, subtitleRendererMode) || other.subtitleRendererMode == subtitleRendererMode)&&(identical(other.preferredSubtitleProvider, preferredSubtitleProvider) || other.preferredSubtitleProvider == preferredSubtitleProvider)&&(identical(other.subtitleFontSize, subtitleFontSize) || other.subtitleFontSize == subtitleFontSize)&&(identical(other.subtitleColor, subtitleColor) || other.subtitleColor == subtitleColor)&&(identical(other.subtitleDelay, subtitleDelay) || other.subtitleDelay == subtitleDelay)&&(identical(other.subtitleFont, subtitleFont) || other.subtitleFont == subtitleFont)&&(identical(other.subtitleBottomMargin, subtitleBottomMargin) || other.subtitleBottomMargin == subtitleBottomMargin)&&(identical(other.subtitleHorizontalOffset, subtitleHorizontalOffset) || other.subtitleHorizontalOffset == subtitleHorizontalOffset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,subtitleRendererMode,preferredSubtitleProvider,subtitleFontSize,subtitleColor,subtitleDelay,subtitleFont,subtitleBottomMargin,subtitleHorizontalOffset);

@override
String toString() {
  return 'SubtitleSettings(subtitleRendererMode: $subtitleRendererMode, preferredSubtitleProvider: $preferredSubtitleProvider, subtitleFontSize: $subtitleFontSize, subtitleColor: $subtitleColor, subtitleDelay: $subtitleDelay, subtitleFont: $subtitleFont, subtitleBottomMargin: $subtitleBottomMargin, subtitleHorizontalOffset: $subtitleHorizontalOffset)';
}


}

/// @nodoc
abstract mixin class $SubtitleSettingsCopyWith<$Res>  {
  factory $SubtitleSettingsCopyWith(SubtitleSettings value, $Res Function(SubtitleSettings) _then) = _$SubtitleSettingsCopyWithImpl;
@useResult
$Res call({
 String subtitleRendererMode, String preferredSubtitleProvider, double subtitleFontSize, String subtitleColor, double subtitleDelay, String subtitleFont, double subtitleBottomMargin, double subtitleHorizontalOffset
});




}
/// @nodoc
class _$SubtitleSettingsCopyWithImpl<$Res>
    implements $SubtitleSettingsCopyWith<$Res> {
  _$SubtitleSettingsCopyWithImpl(this._self, this._then);

  final SubtitleSettings _self;
  final $Res Function(SubtitleSettings) _then;

/// Create a copy of SubtitleSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? subtitleRendererMode = null,Object? preferredSubtitleProvider = null,Object? subtitleFontSize = null,Object? subtitleColor = null,Object? subtitleDelay = null,Object? subtitleFont = null,Object? subtitleBottomMargin = null,Object? subtitleHorizontalOffset = null,}) {
  return _then(_self.copyWith(
subtitleRendererMode: null == subtitleRendererMode ? _self.subtitleRendererMode : subtitleRendererMode // ignore: cast_nullable_to_non_nullable
as String,preferredSubtitleProvider: null == preferredSubtitleProvider ? _self.preferredSubtitleProvider : preferredSubtitleProvider // ignore: cast_nullable_to_non_nullable
as String,subtitleFontSize: null == subtitleFontSize ? _self.subtitleFontSize : subtitleFontSize // ignore: cast_nullable_to_non_nullable
as double,subtitleColor: null == subtitleColor ? _self.subtitleColor : subtitleColor // ignore: cast_nullable_to_non_nullable
as String,subtitleDelay: null == subtitleDelay ? _self.subtitleDelay : subtitleDelay // ignore: cast_nullable_to_non_nullable
as double,subtitleFont: null == subtitleFont ? _self.subtitleFont : subtitleFont // ignore: cast_nullable_to_non_nullable
as String,subtitleBottomMargin: null == subtitleBottomMargin ? _self.subtitleBottomMargin : subtitleBottomMargin // ignore: cast_nullable_to_non_nullable
as double,subtitleHorizontalOffset: null == subtitleHorizontalOffset ? _self.subtitleHorizontalOffset : subtitleHorizontalOffset // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [SubtitleSettings].
extension SubtitleSettingsPatterns on SubtitleSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubtitleSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubtitleSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubtitleSettings value)  $default,){
final _that = this;
switch (_that) {
case _SubtitleSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubtitleSettings value)?  $default,){
final _that = this;
switch (_that) {
case _SubtitleSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String subtitleRendererMode,  String preferredSubtitleProvider,  double subtitleFontSize,  String subtitleColor,  double subtitleDelay,  String subtitleFont,  double subtitleBottomMargin,  double subtitleHorizontalOffset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubtitleSettings() when $default != null:
return $default(_that.subtitleRendererMode,_that.preferredSubtitleProvider,_that.subtitleFontSize,_that.subtitleColor,_that.subtitleDelay,_that.subtitleFont,_that.subtitleBottomMargin,_that.subtitleHorizontalOffset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String subtitleRendererMode,  String preferredSubtitleProvider,  double subtitleFontSize,  String subtitleColor,  double subtitleDelay,  String subtitleFont,  double subtitleBottomMargin,  double subtitleHorizontalOffset)  $default,) {final _that = this;
switch (_that) {
case _SubtitleSettings():
return $default(_that.subtitleRendererMode,_that.preferredSubtitleProvider,_that.subtitleFontSize,_that.subtitleColor,_that.subtitleDelay,_that.subtitleFont,_that.subtitleBottomMargin,_that.subtitleHorizontalOffset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String subtitleRendererMode,  String preferredSubtitleProvider,  double subtitleFontSize,  String subtitleColor,  double subtitleDelay,  String subtitleFont,  double subtitleBottomMargin,  double subtitleHorizontalOffset)?  $default,) {final _that = this;
switch (_that) {
case _SubtitleSettings() when $default != null:
return $default(_that.subtitleRendererMode,_that.preferredSubtitleProvider,_that.subtitleFontSize,_that.subtitleColor,_that.subtitleDelay,_that.subtitleFont,_that.subtitleBottomMargin,_that.subtitleHorizontalOffset);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubtitleSettings implements SubtitleSettings {
  const _SubtitleSettings({this.subtitleRendererMode = 'flutter', this.preferredSubtitleProvider = 'opensubtitles', this.subtitleFontSize = 20.0, this.subtitleColor = '#FFFFFF', this.subtitleDelay = 0.0, this.subtitleFont = 'Roboto', this.subtitleBottomMargin = 84.0, this.subtitleHorizontalOffset = 0.0});
  factory _SubtitleSettings.fromJson(Map<String, dynamic> json) => _$SubtitleSettingsFromJson(json);

@override@JsonKey() final  String subtitleRendererMode;
@override@JsonKey() final  String preferredSubtitleProvider;
@override@JsonKey() final  double subtitleFontSize;
@override@JsonKey() final  String subtitleColor;
@override@JsonKey() final  double subtitleDelay;
@override@JsonKey() final  String subtitleFont;
@override@JsonKey() final  double subtitleBottomMargin;
@override@JsonKey() final  double subtitleHorizontalOffset;

/// Create a copy of SubtitleSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubtitleSettingsCopyWith<_SubtitleSettings> get copyWith => __$SubtitleSettingsCopyWithImpl<_SubtitleSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubtitleSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubtitleSettings&&(identical(other.subtitleRendererMode, subtitleRendererMode) || other.subtitleRendererMode == subtitleRendererMode)&&(identical(other.preferredSubtitleProvider, preferredSubtitleProvider) || other.preferredSubtitleProvider == preferredSubtitleProvider)&&(identical(other.subtitleFontSize, subtitleFontSize) || other.subtitleFontSize == subtitleFontSize)&&(identical(other.subtitleColor, subtitleColor) || other.subtitleColor == subtitleColor)&&(identical(other.subtitleDelay, subtitleDelay) || other.subtitleDelay == subtitleDelay)&&(identical(other.subtitleFont, subtitleFont) || other.subtitleFont == subtitleFont)&&(identical(other.subtitleBottomMargin, subtitleBottomMargin) || other.subtitleBottomMargin == subtitleBottomMargin)&&(identical(other.subtitleHorizontalOffset, subtitleHorizontalOffset) || other.subtitleHorizontalOffset == subtitleHorizontalOffset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,subtitleRendererMode,preferredSubtitleProvider,subtitleFontSize,subtitleColor,subtitleDelay,subtitleFont,subtitleBottomMargin,subtitleHorizontalOffset);

@override
String toString() {
  return 'SubtitleSettings(subtitleRendererMode: $subtitleRendererMode, preferredSubtitleProvider: $preferredSubtitleProvider, subtitleFontSize: $subtitleFontSize, subtitleColor: $subtitleColor, subtitleDelay: $subtitleDelay, subtitleFont: $subtitleFont, subtitleBottomMargin: $subtitleBottomMargin, subtitleHorizontalOffset: $subtitleHorizontalOffset)';
}


}

/// @nodoc
abstract mixin class _$SubtitleSettingsCopyWith<$Res> implements $SubtitleSettingsCopyWith<$Res> {
  factory _$SubtitleSettingsCopyWith(_SubtitleSettings value, $Res Function(_SubtitleSettings) _then) = __$SubtitleSettingsCopyWithImpl;
@override @useResult
$Res call({
 String subtitleRendererMode, String preferredSubtitleProvider, double subtitleFontSize, String subtitleColor, double subtitleDelay, String subtitleFont, double subtitleBottomMargin, double subtitleHorizontalOffset
});




}
/// @nodoc
class __$SubtitleSettingsCopyWithImpl<$Res>
    implements _$SubtitleSettingsCopyWith<$Res> {
  __$SubtitleSettingsCopyWithImpl(this._self, this._then);

  final _SubtitleSettings _self;
  final $Res Function(_SubtitleSettings) _then;

/// Create a copy of SubtitleSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? subtitleRendererMode = null,Object? preferredSubtitleProvider = null,Object? subtitleFontSize = null,Object? subtitleColor = null,Object? subtitleDelay = null,Object? subtitleFont = null,Object? subtitleBottomMargin = null,Object? subtitleHorizontalOffset = null,}) {
  return _then(_SubtitleSettings(
subtitleRendererMode: null == subtitleRendererMode ? _self.subtitleRendererMode : subtitleRendererMode // ignore: cast_nullable_to_non_nullable
as String,preferredSubtitleProvider: null == preferredSubtitleProvider ? _self.preferredSubtitleProvider : preferredSubtitleProvider // ignore: cast_nullable_to_non_nullable
as String,subtitleFontSize: null == subtitleFontSize ? _self.subtitleFontSize : subtitleFontSize // ignore: cast_nullable_to_non_nullable
as double,subtitleColor: null == subtitleColor ? _self.subtitleColor : subtitleColor // ignore: cast_nullable_to_non_nullable
as String,subtitleDelay: null == subtitleDelay ? _self.subtitleDelay : subtitleDelay // ignore: cast_nullable_to_non_nullable
as double,subtitleFont: null == subtitleFont ? _self.subtitleFont : subtitleFont // ignore: cast_nullable_to_non_nullable
as String,subtitleBottomMargin: null == subtitleBottomMargin ? _self.subtitleBottomMargin : subtitleBottomMargin // ignore: cast_nullable_to_non_nullable
as double,subtitleHorizontalOffset: null == subtitleHorizontalOffset ? _self.subtitleHorizontalOffset : subtitleHorizontalOffset // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}


/// @nodoc
mixin _$CacheSettings {

 int get cacheLimitMb; int get cacheTtlDays;
/// Create a copy of CacheSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CacheSettingsCopyWith<CacheSettings> get copyWith => _$CacheSettingsCopyWithImpl<CacheSettings>(this as CacheSettings, _$identity);

  /// Serializes this CacheSettings to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CacheSettings&&(identical(other.cacheLimitMb, cacheLimitMb) || other.cacheLimitMb == cacheLimitMb)&&(identical(other.cacheTtlDays, cacheTtlDays) || other.cacheTtlDays == cacheTtlDays));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cacheLimitMb,cacheTtlDays);

@override
String toString() {
  return 'CacheSettings(cacheLimitMb: $cacheLimitMb, cacheTtlDays: $cacheTtlDays)';
}


}

/// @nodoc
abstract mixin class $CacheSettingsCopyWith<$Res>  {
  factory $CacheSettingsCopyWith(CacheSettings value, $Res Function(CacheSettings) _then) = _$CacheSettingsCopyWithImpl;
@useResult
$Res call({
 int cacheLimitMb, int cacheTtlDays
});




}
/// @nodoc
class _$CacheSettingsCopyWithImpl<$Res>
    implements $CacheSettingsCopyWith<$Res> {
  _$CacheSettingsCopyWithImpl(this._self, this._then);

  final CacheSettings _self;
  final $Res Function(CacheSettings) _then;

/// Create a copy of CacheSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? cacheLimitMb = null,Object? cacheTtlDays = null,}) {
  return _then(_self.copyWith(
cacheLimitMb: null == cacheLimitMb ? _self.cacheLimitMb : cacheLimitMb // ignore: cast_nullable_to_non_nullable
as int,cacheTtlDays: null == cacheTtlDays ? _self.cacheTtlDays : cacheTtlDays // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [CacheSettings].
extension CacheSettingsPatterns on CacheSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CacheSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CacheSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CacheSettings value)  $default,){
final _that = this;
switch (_that) {
case _CacheSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CacheSettings value)?  $default,){
final _that = this;
switch (_that) {
case _CacheSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int cacheLimitMb,  int cacheTtlDays)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CacheSettings() when $default != null:
return $default(_that.cacheLimitMb,_that.cacheTtlDays);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int cacheLimitMb,  int cacheTtlDays)  $default,) {final _that = this;
switch (_that) {
case _CacheSettings():
return $default(_that.cacheLimitMb,_that.cacheTtlDays);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int cacheLimitMb,  int cacheTtlDays)?  $default,) {final _that = this;
switch (_that) {
case _CacheSettings() when $default != null:
return $default(_that.cacheLimitMb,_that.cacheTtlDays);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _CacheSettings implements CacheSettings {
  const _CacheSettings({this.cacheLimitMb = 2048, this.cacheTtlDays = 7});
  factory _CacheSettings.fromJson(Map<String, dynamic> json) => _$CacheSettingsFromJson(json);

@override@JsonKey() final  int cacheLimitMb;
@override@JsonKey() final  int cacheTtlDays;

/// Create a copy of CacheSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CacheSettingsCopyWith<_CacheSettings> get copyWith => __$CacheSettingsCopyWithImpl<_CacheSettings>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CacheSettingsToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CacheSettings&&(identical(other.cacheLimitMb, cacheLimitMb) || other.cacheLimitMb == cacheLimitMb)&&(identical(other.cacheTtlDays, cacheTtlDays) || other.cacheTtlDays == cacheTtlDays));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,cacheLimitMb,cacheTtlDays);

@override
String toString() {
  return 'CacheSettings(cacheLimitMb: $cacheLimitMb, cacheTtlDays: $cacheTtlDays)';
}


}

/// @nodoc
abstract mixin class _$CacheSettingsCopyWith<$Res> implements $CacheSettingsCopyWith<$Res> {
  factory _$CacheSettingsCopyWith(_CacheSettings value, $Res Function(_CacheSettings) _then) = __$CacheSettingsCopyWithImpl;
@override @useResult
$Res call({
 int cacheLimitMb, int cacheTtlDays
});




}
/// @nodoc
class __$CacheSettingsCopyWithImpl<$Res>
    implements _$CacheSettingsCopyWith<$Res> {
  __$CacheSettingsCopyWithImpl(this._self, this._then);

  final _CacheSettings _self;
  final $Res Function(_CacheSettings) _then;

/// Create a copy of CacheSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? cacheLimitMb = null,Object? cacheTtlDays = null,}) {
  return _then(_CacheSettings(
cacheLimitMb: null == cacheLimitMb ? _self.cacheLimitMb : cacheLimitMb // ignore: cast_nullable_to_non_nullable
as int,cacheTtlDays: null == cacheTtlDays ? _self.cacheTtlDays : cacheTtlDays // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$VideoSettings {

 PlayerLayoutSettings get layout; GestureSettings get gestures; AudioSettings get audio; SubtitleSettings get subtitles; CacheSettings get cache; bool get savePositionOnQuit; bool get autoplayNextVideo; String get streamingProfile; bool get downloadSchedulerEnabled; int get downloadStartHour; int get downloadEndHour; String get customMpvOptions; String get downloadSpeedLimit; String get progressSyncMode; bool get rememberSpeed; bool get wifiOnlyDownloads; String get hardwareDecoderMode;
/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoSettingsCopyWith<VideoSettings> get copyWith => _$VideoSettingsCopyWithImpl<VideoSettings>(this as VideoSettings, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoSettings&&(identical(other.layout, layout) || other.layout == layout)&&(identical(other.gestures, gestures) || other.gestures == gestures)&&(identical(other.audio, audio) || other.audio == audio)&&(identical(other.subtitles, subtitles) || other.subtitles == subtitles)&&(identical(other.cache, cache) || other.cache == cache)&&(identical(other.savePositionOnQuit, savePositionOnQuit) || other.savePositionOnQuit == savePositionOnQuit)&&(identical(other.autoplayNextVideo, autoplayNextVideo) || other.autoplayNextVideo == autoplayNextVideo)&&(identical(other.streamingProfile, streamingProfile) || other.streamingProfile == streamingProfile)&&(identical(other.downloadSchedulerEnabled, downloadSchedulerEnabled) || other.downloadSchedulerEnabled == downloadSchedulerEnabled)&&(identical(other.downloadStartHour, downloadStartHour) || other.downloadStartHour == downloadStartHour)&&(identical(other.downloadEndHour, downloadEndHour) || other.downloadEndHour == downloadEndHour)&&(identical(other.customMpvOptions, customMpvOptions) || other.customMpvOptions == customMpvOptions)&&(identical(other.downloadSpeedLimit, downloadSpeedLimit) || other.downloadSpeedLimit == downloadSpeedLimit)&&(identical(other.progressSyncMode, progressSyncMode) || other.progressSyncMode == progressSyncMode)&&(identical(other.rememberSpeed, rememberSpeed) || other.rememberSpeed == rememberSpeed)&&(identical(other.wifiOnlyDownloads, wifiOnlyDownloads) || other.wifiOnlyDownloads == wifiOnlyDownloads)&&(identical(other.hardwareDecoderMode, hardwareDecoderMode) || other.hardwareDecoderMode == hardwareDecoderMode));
}


@override
int get hashCode => Object.hash(runtimeType,layout,gestures,audio,subtitles,cache,savePositionOnQuit,autoplayNextVideo,streamingProfile,downloadSchedulerEnabled,downloadStartHour,downloadEndHour,customMpvOptions,downloadSpeedLimit,progressSyncMode,rememberSpeed,wifiOnlyDownloads,hardwareDecoderMode);

@override
String toString() {
  return 'VideoSettings(layout: $layout, gestures: $gestures, audio: $audio, subtitles: $subtitles, cache: $cache, savePositionOnQuit: $savePositionOnQuit, autoplayNextVideo: $autoplayNextVideo, streamingProfile: $streamingProfile, downloadSchedulerEnabled: $downloadSchedulerEnabled, downloadStartHour: $downloadStartHour, downloadEndHour: $downloadEndHour, customMpvOptions: $customMpvOptions, downloadSpeedLimit: $downloadSpeedLimit, progressSyncMode: $progressSyncMode, rememberSpeed: $rememberSpeed, wifiOnlyDownloads: $wifiOnlyDownloads, hardwareDecoderMode: $hardwareDecoderMode)';
}


}

/// @nodoc
abstract mixin class $VideoSettingsCopyWith<$Res>  {
  factory $VideoSettingsCopyWith(VideoSettings value, $Res Function(VideoSettings) _then) = _$VideoSettingsCopyWithImpl;
@useResult
$Res call({
 PlayerLayoutSettings layout, GestureSettings gestures, AudioSettings audio, SubtitleSettings subtitles, CacheSettings cache, bool savePositionOnQuit, bool autoplayNextVideo, String streamingProfile, bool downloadSchedulerEnabled, int downloadStartHour, int downloadEndHour, String customMpvOptions, String downloadSpeedLimit, String progressSyncMode, bool rememberSpeed, bool wifiOnlyDownloads, String hardwareDecoderMode
});


$PlayerLayoutSettingsCopyWith<$Res> get layout;$GestureSettingsCopyWith<$Res> get gestures;$AudioSettingsCopyWith<$Res> get audio;$SubtitleSettingsCopyWith<$Res> get subtitles;$CacheSettingsCopyWith<$Res> get cache;

}
/// @nodoc
class _$VideoSettingsCopyWithImpl<$Res>
    implements $VideoSettingsCopyWith<$Res> {
  _$VideoSettingsCopyWithImpl(this._self, this._then);

  final VideoSettings _self;
  final $Res Function(VideoSettings) _then;

/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? layout = null,Object? gestures = null,Object? audio = null,Object? subtitles = null,Object? cache = null,Object? savePositionOnQuit = null,Object? autoplayNextVideo = null,Object? streamingProfile = null,Object? downloadSchedulerEnabled = null,Object? downloadStartHour = null,Object? downloadEndHour = null,Object? customMpvOptions = null,Object? downloadSpeedLimit = null,Object? progressSyncMode = null,Object? rememberSpeed = null,Object? wifiOnlyDownloads = null,Object? hardwareDecoderMode = null,}) {
  return _then(_self.copyWith(
layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as PlayerLayoutSettings,gestures: null == gestures ? _self.gestures : gestures // ignore: cast_nullable_to_non_nullable
as GestureSettings,audio: null == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as AudioSettings,subtitles: null == subtitles ? _self.subtitles : subtitles // ignore: cast_nullable_to_non_nullable
as SubtitleSettings,cache: null == cache ? _self.cache : cache // ignore: cast_nullable_to_non_nullable
as CacheSettings,savePositionOnQuit: null == savePositionOnQuit ? _self.savePositionOnQuit : savePositionOnQuit // ignore: cast_nullable_to_non_nullable
as bool,autoplayNextVideo: null == autoplayNextVideo ? _self.autoplayNextVideo : autoplayNextVideo // ignore: cast_nullable_to_non_nullable
as bool,streamingProfile: null == streamingProfile ? _self.streamingProfile : streamingProfile // ignore: cast_nullable_to_non_nullable
as String,downloadSchedulerEnabled: null == downloadSchedulerEnabled ? _self.downloadSchedulerEnabled : downloadSchedulerEnabled // ignore: cast_nullable_to_non_nullable
as bool,downloadStartHour: null == downloadStartHour ? _self.downloadStartHour : downloadStartHour // ignore: cast_nullable_to_non_nullable
as int,downloadEndHour: null == downloadEndHour ? _self.downloadEndHour : downloadEndHour // ignore: cast_nullable_to_non_nullable
as int,customMpvOptions: null == customMpvOptions ? _self.customMpvOptions : customMpvOptions // ignore: cast_nullable_to_non_nullable
as String,downloadSpeedLimit: null == downloadSpeedLimit ? _self.downloadSpeedLimit : downloadSpeedLimit // ignore: cast_nullable_to_non_nullable
as String,progressSyncMode: null == progressSyncMode ? _self.progressSyncMode : progressSyncMode // ignore: cast_nullable_to_non_nullable
as String,rememberSpeed: null == rememberSpeed ? _self.rememberSpeed : rememberSpeed // ignore: cast_nullable_to_non_nullable
as bool,wifiOnlyDownloads: null == wifiOnlyDownloads ? _self.wifiOnlyDownloads : wifiOnlyDownloads // ignore: cast_nullable_to_non_nullable
as bool,hardwareDecoderMode: null == hardwareDecoderMode ? _self.hardwareDecoderMode : hardwareDecoderMode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlayerLayoutSettingsCopyWith<$Res> get layout {
  
  return $PlayerLayoutSettingsCopyWith<$Res>(_self.layout, (value) {
    return _then(_self.copyWith(layout: value));
  });
}/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GestureSettingsCopyWith<$Res> get gestures {
  
  return $GestureSettingsCopyWith<$Res>(_self.gestures, (value) {
    return _then(_self.copyWith(gestures: value));
  });
}/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AudioSettingsCopyWith<$Res> get audio {
  
  return $AudioSettingsCopyWith<$Res>(_self.audio, (value) {
    return _then(_self.copyWith(audio: value));
  });
}/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubtitleSettingsCopyWith<$Res> get subtitles {
  
  return $SubtitleSettingsCopyWith<$Res>(_self.subtitles, (value) {
    return _then(_self.copyWith(subtitles: value));
  });
}/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CacheSettingsCopyWith<$Res> get cache {
  
  return $CacheSettingsCopyWith<$Res>(_self.cache, (value) {
    return _then(_self.copyWith(cache: value));
  });
}
}


/// Adds pattern-matching-related methods to [VideoSettings].
extension VideoSettingsPatterns on VideoSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoSettings value)  $default,){
final _that = this;
switch (_that) {
case _VideoSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoSettings value)?  $default,){
final _that = this;
switch (_that) {
case _VideoSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( PlayerLayoutSettings layout,  GestureSettings gestures,  AudioSettings audio,  SubtitleSettings subtitles,  CacheSettings cache,  bool savePositionOnQuit,  bool autoplayNextVideo,  String streamingProfile,  bool downloadSchedulerEnabled,  int downloadStartHour,  int downloadEndHour,  String customMpvOptions,  String downloadSpeedLimit,  String progressSyncMode,  bool rememberSpeed,  bool wifiOnlyDownloads,  String hardwareDecoderMode)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoSettings() when $default != null:
return $default(_that.layout,_that.gestures,_that.audio,_that.subtitles,_that.cache,_that.savePositionOnQuit,_that.autoplayNextVideo,_that.streamingProfile,_that.downloadSchedulerEnabled,_that.downloadStartHour,_that.downloadEndHour,_that.customMpvOptions,_that.downloadSpeedLimit,_that.progressSyncMode,_that.rememberSpeed,_that.wifiOnlyDownloads,_that.hardwareDecoderMode);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( PlayerLayoutSettings layout,  GestureSettings gestures,  AudioSettings audio,  SubtitleSettings subtitles,  CacheSettings cache,  bool savePositionOnQuit,  bool autoplayNextVideo,  String streamingProfile,  bool downloadSchedulerEnabled,  int downloadStartHour,  int downloadEndHour,  String customMpvOptions,  String downloadSpeedLimit,  String progressSyncMode,  bool rememberSpeed,  bool wifiOnlyDownloads,  String hardwareDecoderMode)  $default,) {final _that = this;
switch (_that) {
case _VideoSettings():
return $default(_that.layout,_that.gestures,_that.audio,_that.subtitles,_that.cache,_that.savePositionOnQuit,_that.autoplayNextVideo,_that.streamingProfile,_that.downloadSchedulerEnabled,_that.downloadStartHour,_that.downloadEndHour,_that.customMpvOptions,_that.downloadSpeedLimit,_that.progressSyncMode,_that.rememberSpeed,_that.wifiOnlyDownloads,_that.hardwareDecoderMode);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( PlayerLayoutSettings layout,  GestureSettings gestures,  AudioSettings audio,  SubtitleSettings subtitles,  CacheSettings cache,  bool savePositionOnQuit,  bool autoplayNextVideo,  String streamingProfile,  bool downloadSchedulerEnabled,  int downloadStartHour,  int downloadEndHour,  String customMpvOptions,  String downloadSpeedLimit,  String progressSyncMode,  bool rememberSpeed,  bool wifiOnlyDownloads,  String hardwareDecoderMode)?  $default,) {final _that = this;
switch (_that) {
case _VideoSettings() when $default != null:
return $default(_that.layout,_that.gestures,_that.audio,_that.subtitles,_that.cache,_that.savePositionOnQuit,_that.autoplayNextVideo,_that.streamingProfile,_that.downloadSchedulerEnabled,_that.downloadStartHour,_that.downloadEndHour,_that.customMpvOptions,_that.downloadSpeedLimit,_that.progressSyncMode,_that.rememberSpeed,_that.wifiOnlyDownloads,_that.hardwareDecoderMode);case _:
  return null;

}
}

}

/// @nodoc


class _VideoSettings extends VideoSettings {
  const _VideoSettings({this.layout = const PlayerLayoutSettings(), this.gestures = const GestureSettings(), this.audio = const AudioSettings(), this.subtitles = const SubtitleSettings(), this.cache = const CacheSettings(), this.savePositionOnQuit = true, this.autoplayNextVideo = true, this.streamingProfile = 'Balanced', this.downloadSchedulerEnabled = false, this.downloadStartHour = 2, this.downloadEndHour = 6, this.customMpvOptions = '', this.downloadSpeedLimit = 'Unlimited', this.progressSyncMode = 'disabled', this.rememberSpeed = false, this.wifiOnlyDownloads = false, this.hardwareDecoderMode = 'auto'}): super._();
  

@override@JsonKey() final  PlayerLayoutSettings layout;
@override@JsonKey() final  GestureSettings gestures;
@override@JsonKey() final  AudioSettings audio;
@override@JsonKey() final  SubtitleSettings subtitles;
@override@JsonKey() final  CacheSettings cache;
@override@JsonKey() final  bool savePositionOnQuit;
@override@JsonKey() final  bool autoplayNextVideo;
@override@JsonKey() final  String streamingProfile;
@override@JsonKey() final  bool downloadSchedulerEnabled;
@override@JsonKey() final  int downloadStartHour;
@override@JsonKey() final  int downloadEndHour;
@override@JsonKey() final  String customMpvOptions;
@override@JsonKey() final  String downloadSpeedLimit;
@override@JsonKey() final  String progressSyncMode;
@override@JsonKey() final  bool rememberSpeed;
@override@JsonKey() final  bool wifiOnlyDownloads;
@override@JsonKey() final  String hardwareDecoderMode;

/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoSettingsCopyWith<_VideoSettings> get copyWith => __$VideoSettingsCopyWithImpl<_VideoSettings>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoSettings&&(identical(other.layout, layout) || other.layout == layout)&&(identical(other.gestures, gestures) || other.gestures == gestures)&&(identical(other.audio, audio) || other.audio == audio)&&(identical(other.subtitles, subtitles) || other.subtitles == subtitles)&&(identical(other.cache, cache) || other.cache == cache)&&(identical(other.savePositionOnQuit, savePositionOnQuit) || other.savePositionOnQuit == savePositionOnQuit)&&(identical(other.autoplayNextVideo, autoplayNextVideo) || other.autoplayNextVideo == autoplayNextVideo)&&(identical(other.streamingProfile, streamingProfile) || other.streamingProfile == streamingProfile)&&(identical(other.downloadSchedulerEnabled, downloadSchedulerEnabled) || other.downloadSchedulerEnabled == downloadSchedulerEnabled)&&(identical(other.downloadStartHour, downloadStartHour) || other.downloadStartHour == downloadStartHour)&&(identical(other.downloadEndHour, downloadEndHour) || other.downloadEndHour == downloadEndHour)&&(identical(other.customMpvOptions, customMpvOptions) || other.customMpvOptions == customMpvOptions)&&(identical(other.downloadSpeedLimit, downloadSpeedLimit) || other.downloadSpeedLimit == downloadSpeedLimit)&&(identical(other.progressSyncMode, progressSyncMode) || other.progressSyncMode == progressSyncMode)&&(identical(other.rememberSpeed, rememberSpeed) || other.rememberSpeed == rememberSpeed)&&(identical(other.wifiOnlyDownloads, wifiOnlyDownloads) || other.wifiOnlyDownloads == wifiOnlyDownloads)&&(identical(other.hardwareDecoderMode, hardwareDecoderMode) || other.hardwareDecoderMode == hardwareDecoderMode));
}


@override
int get hashCode => Object.hash(runtimeType,layout,gestures,audio,subtitles,cache,savePositionOnQuit,autoplayNextVideo,streamingProfile,downloadSchedulerEnabled,downloadStartHour,downloadEndHour,customMpvOptions,downloadSpeedLimit,progressSyncMode,rememberSpeed,wifiOnlyDownloads,hardwareDecoderMode);

@override
String toString() {
  return 'VideoSettings(layout: $layout, gestures: $gestures, audio: $audio, subtitles: $subtitles, cache: $cache, savePositionOnQuit: $savePositionOnQuit, autoplayNextVideo: $autoplayNextVideo, streamingProfile: $streamingProfile, downloadSchedulerEnabled: $downloadSchedulerEnabled, downloadStartHour: $downloadStartHour, downloadEndHour: $downloadEndHour, customMpvOptions: $customMpvOptions, downloadSpeedLimit: $downloadSpeedLimit, progressSyncMode: $progressSyncMode, rememberSpeed: $rememberSpeed, wifiOnlyDownloads: $wifiOnlyDownloads, hardwareDecoderMode: $hardwareDecoderMode)';
}


}

/// @nodoc
abstract mixin class _$VideoSettingsCopyWith<$Res> implements $VideoSettingsCopyWith<$Res> {
  factory _$VideoSettingsCopyWith(_VideoSettings value, $Res Function(_VideoSettings) _then) = __$VideoSettingsCopyWithImpl;
@override @useResult
$Res call({
 PlayerLayoutSettings layout, GestureSettings gestures, AudioSettings audio, SubtitleSettings subtitles, CacheSettings cache, bool savePositionOnQuit, bool autoplayNextVideo, String streamingProfile, bool downloadSchedulerEnabled, int downloadStartHour, int downloadEndHour, String customMpvOptions, String downloadSpeedLimit, String progressSyncMode, bool rememberSpeed, bool wifiOnlyDownloads, String hardwareDecoderMode
});


@override $PlayerLayoutSettingsCopyWith<$Res> get layout;@override $GestureSettingsCopyWith<$Res> get gestures;@override $AudioSettingsCopyWith<$Res> get audio;@override $SubtitleSettingsCopyWith<$Res> get subtitles;@override $CacheSettingsCopyWith<$Res> get cache;

}
/// @nodoc
class __$VideoSettingsCopyWithImpl<$Res>
    implements _$VideoSettingsCopyWith<$Res> {
  __$VideoSettingsCopyWithImpl(this._self, this._then);

  final _VideoSettings _self;
  final $Res Function(_VideoSettings) _then;

/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? layout = null,Object? gestures = null,Object? audio = null,Object? subtitles = null,Object? cache = null,Object? savePositionOnQuit = null,Object? autoplayNextVideo = null,Object? streamingProfile = null,Object? downloadSchedulerEnabled = null,Object? downloadStartHour = null,Object? downloadEndHour = null,Object? customMpvOptions = null,Object? downloadSpeedLimit = null,Object? progressSyncMode = null,Object? rememberSpeed = null,Object? wifiOnlyDownloads = null,Object? hardwareDecoderMode = null,}) {
  return _then(_VideoSettings(
layout: null == layout ? _self.layout : layout // ignore: cast_nullable_to_non_nullable
as PlayerLayoutSettings,gestures: null == gestures ? _self.gestures : gestures // ignore: cast_nullable_to_non_nullable
as GestureSettings,audio: null == audio ? _self.audio : audio // ignore: cast_nullable_to_non_nullable
as AudioSettings,subtitles: null == subtitles ? _self.subtitles : subtitles // ignore: cast_nullable_to_non_nullable
as SubtitleSettings,cache: null == cache ? _self.cache : cache // ignore: cast_nullable_to_non_nullable
as CacheSettings,savePositionOnQuit: null == savePositionOnQuit ? _self.savePositionOnQuit : savePositionOnQuit // ignore: cast_nullable_to_non_nullable
as bool,autoplayNextVideo: null == autoplayNextVideo ? _self.autoplayNextVideo : autoplayNextVideo // ignore: cast_nullable_to_non_nullable
as bool,streamingProfile: null == streamingProfile ? _self.streamingProfile : streamingProfile // ignore: cast_nullable_to_non_nullable
as String,downloadSchedulerEnabled: null == downloadSchedulerEnabled ? _self.downloadSchedulerEnabled : downloadSchedulerEnabled // ignore: cast_nullable_to_non_nullable
as bool,downloadStartHour: null == downloadStartHour ? _self.downloadStartHour : downloadStartHour // ignore: cast_nullable_to_non_nullable
as int,downloadEndHour: null == downloadEndHour ? _self.downloadEndHour : downloadEndHour // ignore: cast_nullable_to_non_nullable
as int,customMpvOptions: null == customMpvOptions ? _self.customMpvOptions : customMpvOptions // ignore: cast_nullable_to_non_nullable
as String,downloadSpeedLimit: null == downloadSpeedLimit ? _self.downloadSpeedLimit : downloadSpeedLimit // ignore: cast_nullable_to_non_nullable
as String,progressSyncMode: null == progressSyncMode ? _self.progressSyncMode : progressSyncMode // ignore: cast_nullable_to_non_nullable
as String,rememberSpeed: null == rememberSpeed ? _self.rememberSpeed : rememberSpeed // ignore: cast_nullable_to_non_nullable
as bool,wifiOnlyDownloads: null == wifiOnlyDownloads ? _self.wifiOnlyDownloads : wifiOnlyDownloads // ignore: cast_nullable_to_non_nullable
as bool,hardwareDecoderMode: null == hardwareDecoderMode ? _self.hardwareDecoderMode : hardwareDecoderMode // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$PlayerLayoutSettingsCopyWith<$Res> get layout {
  
  return $PlayerLayoutSettingsCopyWith<$Res>(_self.layout, (value) {
    return _then(_self.copyWith(layout: value));
  });
}/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$GestureSettingsCopyWith<$Res> get gestures {
  
  return $GestureSettingsCopyWith<$Res>(_self.gestures, (value) {
    return _then(_self.copyWith(gestures: value));
  });
}/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AudioSettingsCopyWith<$Res> get audio {
  
  return $AudioSettingsCopyWith<$Res>(_self.audio, (value) {
    return _then(_self.copyWith(audio: value));
  });
}/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubtitleSettingsCopyWith<$Res> get subtitles {
  
  return $SubtitleSettingsCopyWith<$Res>(_self.subtitles, (value) {
    return _then(_self.copyWith(subtitles: value));
  });
}/// Create a copy of VideoSettings
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$CacheSettingsCopyWith<$Res> get cache {
  
  return $CacheSettingsCopyWith<$Res>(_self.cache, (value) {
    return _then(_self.copyWith(cache: value));
  });
}
}

// dart format on
