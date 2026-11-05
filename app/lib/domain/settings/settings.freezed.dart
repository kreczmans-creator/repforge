// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AppSettings {

 UnitSystem get units; ThemePreference get theme; ExertionScale get exertionScale;/// Hour (0–23) at which a new diary day starts; 0 = local midnight.
 int get dayStartHour;/// 1 = Monday … 7 = Sunday.
 int get weekStartDay;/// Rest-timer length in seconds when the exercise plans none (TRN-021),
/// 0 to 3600.
 int get defaultRestSeconds;/// Whether the rest timer may post a local notification when it ends
/// (TRN-022, PLT-007). Off until the user opts in.
 bool get restTimerNotifications;
/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AppSettingsCopyWith<AppSettings> get copyWith => _$AppSettingsCopyWithImpl<AppSettings>(this as AppSettings, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as AppSettings;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AppSettings&&(identical(other.units, _this.units) || other.units == _this.units)&&(identical(other.theme, _this.theme) || other.theme == _this.theme)&&(identical(other.exertionScale, _this.exertionScale) || other.exertionScale == _this.exertionScale)&&(identical(other.dayStartHour, _this.dayStartHour) || other.dayStartHour == _this.dayStartHour)&&(identical(other.weekStartDay, _this.weekStartDay) || other.weekStartDay == _this.weekStartDay)&&(identical(other.defaultRestSeconds, _this.defaultRestSeconds) || other.defaultRestSeconds == _this.defaultRestSeconds)&&(identical(other.restTimerNotifications, _this.restTimerNotifications) || other.restTimerNotifications == _this.restTimerNotifications));
}


@override
int get hashCode {
  final _this = this as AppSettings;
  return Object.hash(runtimeType,_this.units,_this.theme,_this.exertionScale,_this.dayStartHour,_this.weekStartDay,_this.defaultRestSeconds,_this.restTimerNotifications);
}

@override
String toString() {
  final _this = this as AppSettings;
  return 'AppSettings(units: ${_this.units}, theme: ${_this.theme}, exertionScale: ${_this.exertionScale}, dayStartHour: ${_this.dayStartHour}, weekStartDay: ${_this.weekStartDay}, defaultRestSeconds: ${_this.defaultRestSeconds}, restTimerNotifications: ${_this.restTimerNotifications})';
}


}

/// @nodoc
abstract mixin class $AppSettingsCopyWith<$Res>  {
  factory $AppSettingsCopyWith(AppSettings value, $Res Function(AppSettings) _then) = _$AppSettingsCopyWithImpl;
@useResult
$Res call({
 UnitSystem units, ThemePreference theme, ExertionScale exertionScale, int dayStartHour, int weekStartDay, int defaultRestSeconds, bool restTimerNotifications
});




}
/// @nodoc
class _$AppSettingsCopyWithImpl<$Res>
    implements $AppSettingsCopyWith<$Res> {
  _$AppSettingsCopyWithImpl(this._self, this._then);

  final AppSettings _self;
  final $Res Function(AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? units = null,Object? theme = null,Object? exertionScale = null,Object? dayStartHour = null,Object? weekStartDay = null,Object? defaultRestSeconds = null,Object? restTimerNotifications = null,}) {
  return _then(AppSettings(
units: null == units ? _self.units : units // ignore: cast_nullable_to_non_nullable
as UnitSystem,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as ThemePreference,exertionScale: null == exertionScale ? _self.exertionScale : exertionScale // ignore: cast_nullable_to_non_nullable
as ExertionScale,dayStartHour: null == dayStartHour ? _self.dayStartHour : dayStartHour // ignore: cast_nullable_to_non_nullable
as int,weekStartDay: null == weekStartDay ? _self.weekStartDay : weekStartDay // ignore: cast_nullable_to_non_nullable
as int,defaultRestSeconds: null == defaultRestSeconds ? _self.defaultRestSeconds : defaultRestSeconds // ignore: cast_nullable_to_non_nullable
as int,restTimerNotifications: null == restTimerNotifications ? _self.restTimerNotifications : restTimerNotifications // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [AppSettings].
extension AppSettingsPatterns on AppSettings {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AppSettings value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AppSettings value)  $default,){
final _that = this;
switch (_that) {
case _AppSettings():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AppSettings value)?  $default,){
final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( UnitSystem units,  ThemePreference theme,  ExertionScale exertionScale,  int dayStartHour,  int weekStartDay,  int defaultRestSeconds,  bool restTimerNotifications)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.units,_that.theme,_that.exertionScale,_that.dayStartHour,_that.weekStartDay,_that.defaultRestSeconds,_that.restTimerNotifications);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( UnitSystem units,  ThemePreference theme,  ExertionScale exertionScale,  int dayStartHour,  int weekStartDay,  int defaultRestSeconds,  bool restTimerNotifications)  $default,) {final _that = this;
switch (_that) {
case _AppSettings():
return $default(_that.units,_that.theme,_that.exertionScale,_that.dayStartHour,_that.weekStartDay,_that.defaultRestSeconds,_that.restTimerNotifications);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( UnitSystem units,  ThemePreference theme,  ExertionScale exertionScale,  int dayStartHour,  int weekStartDay,  int defaultRestSeconds,  bool restTimerNotifications)?  $default,) {final _that = this;
switch (_that) {
case _AppSettings() when $default != null:
return $default(_that.units,_that.theme,_that.exertionScale,_that.dayStartHour,_that.weekStartDay,_that.defaultRestSeconds,_that.restTimerNotifications);case _:
  return null;

}
}

}

/// @nodoc


class _AppSettings implements AppSettings {
  const _AppSettings({this.units = UnitSystem.metric, this.theme = ThemePreference.dark, this.exertionScale = ExertionScale.rpe, this.dayStartHour = 0, this.weekStartDay = 1, this.defaultRestSeconds = 90, this.restTimerNotifications = false});
  

@override@JsonKey() final  UnitSystem units;
@override@JsonKey() final  ThemePreference theme;
@override@JsonKey() final  ExertionScale exertionScale;
/// Hour (0–23) at which a new diary day starts; 0 = local midnight.
@override@JsonKey() final  int dayStartHour;
/// 1 = Monday … 7 = Sunday.
@override@JsonKey() final  int weekStartDay;
/// Rest-timer length in seconds when the exercise plans none (TRN-021),
/// 0 to 3600.
@override@JsonKey() final  int defaultRestSeconds;
/// Whether the rest timer may post a local notification when it ends
/// (TRN-022, PLT-007). Off until the user opts in.
@override@JsonKey() final  bool restTimerNotifications;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AppSettingsCopyWith<_AppSettings> get copyWith => __$AppSettingsCopyWithImpl<_AppSettings>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _AppSettings&&(identical(other.units, units) || other.units == units)&&(identical(other.theme, theme) || other.theme == theme)&&(identical(other.exertionScale, exertionScale) || other.exertionScale == exertionScale)&&(identical(other.dayStartHour, dayStartHour) || other.dayStartHour == dayStartHour)&&(identical(other.weekStartDay, weekStartDay) || other.weekStartDay == weekStartDay)&&(identical(other.defaultRestSeconds, defaultRestSeconds) || other.defaultRestSeconds == defaultRestSeconds)&&(identical(other.restTimerNotifications, restTimerNotifications) || other.restTimerNotifications == restTimerNotifications));
}


@override
int get hashCode {
    return Object.hash(runtimeType,units,theme,exertionScale,dayStartHour,weekStartDay,defaultRestSeconds,restTimerNotifications);
}

@override
String toString() {
    return 'AppSettings(units: $units, theme: $theme, exertionScale: $exertionScale, dayStartHour: $dayStartHour, weekStartDay: $weekStartDay, defaultRestSeconds: $defaultRestSeconds, restTimerNotifications: $restTimerNotifications)';
}


}

/// @nodoc
abstract mixin class _$AppSettingsCopyWith<$Res> implements $AppSettingsCopyWith<$Res> {
  factory _$AppSettingsCopyWith(_AppSettings value, $Res Function(_AppSettings) _then) = __$AppSettingsCopyWithImpl;
@override @useResult
$Res call({
 UnitSystem units, ThemePreference theme, ExertionScale exertionScale, int dayStartHour, int weekStartDay, int defaultRestSeconds, bool restTimerNotifications
});




}
/// @nodoc
class __$AppSettingsCopyWithImpl<$Res>
    implements _$AppSettingsCopyWith<$Res> {
  __$AppSettingsCopyWithImpl(this._self, this._then);

  final _AppSettings _self;
  final $Res Function(_AppSettings) _then;

/// Create a copy of AppSettings
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? units = null,Object? theme = null,Object? exertionScale = null,Object? dayStartHour = null,Object? weekStartDay = null,Object? defaultRestSeconds = null,Object? restTimerNotifications = null,}) {
  return _then(_AppSettings(
units: null == units ? _self.units : units // ignore: cast_nullable_to_non_nullable
as UnitSystem,theme: null == theme ? _self.theme : theme // ignore: cast_nullable_to_non_nullable
as ThemePreference,exertionScale: null == exertionScale ? _self.exertionScale : exertionScale // ignore: cast_nullable_to_non_nullable
as ExertionScale,dayStartHour: null == dayStartHour ? _self.dayStartHour : dayStartHour // ignore: cast_nullable_to_non_nullable
as int,weekStartDay: null == weekStartDay ? _self.weekStartDay : weekStartDay // ignore: cast_nullable_to_non_nullable
as int,defaultRestSeconds: null == defaultRestSeconds ? _self.defaultRestSeconds : defaultRestSeconds // ignore: cast_nullable_to_non_nullable
as int,restTimerNotifications: null == restTimerNotifications ? _self.restTimerNotifications : restTimerNotifications // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
