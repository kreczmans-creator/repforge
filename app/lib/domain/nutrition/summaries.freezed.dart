// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'summaries.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$WeeklySummary {

 String get fromDay; String get toDay; Map<String, NutrientTotals> get dayTotals;
/// Create a copy of WeeklySummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeeklySummaryCopyWith<WeeklySummary> get copyWith => _$WeeklySummaryCopyWithImpl<WeeklySummary>(this as WeeklySummary, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WeeklySummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WeeklySummary&&(identical(other.fromDay, _this.fromDay) || other.fromDay == _this.fromDay)&&(identical(other.toDay, _this.toDay) || other.toDay == _this.toDay)&&const DeepCollectionEquality().equals(other.dayTotals, _this.dayTotals));
}


@override
int get hashCode {
  final _this = this as WeeklySummary;
  return Object.hash(runtimeType,_this.fromDay,_this.toDay,const DeepCollectionEquality().hash(_this.dayTotals));
}

@override
String toString() {
  final _this = this as WeeklySummary;
  return 'WeeklySummary(fromDay: ${_this.fromDay}, toDay: ${_this.toDay}, dayTotals: ${_this.dayTotals})';
}


}

/// @nodoc
abstract mixin class $WeeklySummaryCopyWith<$Res>  {
  factory $WeeklySummaryCopyWith(WeeklySummary value, $Res Function(WeeklySummary) _then) = _$WeeklySummaryCopyWithImpl;
@useResult
$Res call({
 String fromDay, String toDay, Map<String, NutrientTotals> dayTotals
});




}
/// @nodoc
class _$WeeklySummaryCopyWithImpl<$Res>
    implements $WeeklySummaryCopyWith<$Res> {
  _$WeeklySummaryCopyWithImpl(this._self, this._then);

  final WeeklySummary _self;
  final $Res Function(WeeklySummary) _then;

/// Create a copy of WeeklySummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fromDay = null,Object? toDay = null,Object? dayTotals = null,}) {
  return _then(WeeklySummary(
fromDay: null == fromDay ? _self.fromDay : fromDay // ignore: cast_nullable_to_non_nullable
as String,toDay: null == toDay ? _self.toDay : toDay // ignore: cast_nullable_to_non_nullable
as String,dayTotals: null == dayTotals ? _self.dayTotals : dayTotals // ignore: cast_nullable_to_non_nullable
as Map<String, NutrientTotals>,
  ));
}

}


/// Adds pattern-matching-related methods to [WeeklySummary].
extension WeeklySummaryPatterns on WeeklySummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WeeklySummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WeeklySummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WeeklySummary value)  $default,){
final _that = this;
switch (_that) {
case _WeeklySummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WeeklySummary value)?  $default,){
final _that = this;
switch (_that) {
case _WeeklySummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fromDay,  String toDay,  Map<String, NutrientTotals> dayTotals)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WeeklySummary() when $default != null:
return $default(_that.fromDay,_that.toDay,_that.dayTotals);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fromDay,  String toDay,  Map<String, NutrientTotals> dayTotals)  $default,) {final _that = this;
switch (_that) {
case _WeeklySummary():
return $default(_that.fromDay,_that.toDay,_that.dayTotals);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fromDay,  String toDay,  Map<String, NutrientTotals> dayTotals)?  $default,) {final _that = this;
switch (_that) {
case _WeeklySummary() when $default != null:
return $default(_that.fromDay,_that.toDay,_that.dayTotals);case _:
  return null;

}
}

}

/// @nodoc


class _WeeklySummary extends WeeklySummary {
  const _WeeklySummary({required this.fromDay, required this.toDay, required  Map<String, NutrientTotals> dayTotals}): _dayTotals = dayTotals,super._();
  

@override final  String fromDay;
@override final  String toDay;
 final  Map<String, NutrientTotals> _dayTotals;
@override Map<String, NutrientTotals> get dayTotals {
  if (_dayTotals is EqualUnmodifiableMapView) return _dayTotals;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_dayTotals);
}


/// Create a copy of WeeklySummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WeeklySummaryCopyWith<_WeeklySummary> get copyWith => __$WeeklySummaryCopyWithImpl<_WeeklySummary>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WeeklySummary&&(identical(other.fromDay, fromDay) || other.fromDay == fromDay)&&(identical(other.toDay, toDay) || other.toDay == toDay)&&const DeepCollectionEquality().equals(other.dayTotals, _dayTotals));
}


@override
int get hashCode {
    return Object.hash(runtimeType,fromDay,toDay,const DeepCollectionEquality().hash(_dayTotals));
}

@override
String toString() {
    return 'WeeklySummary(fromDay: $fromDay, toDay: $toDay, dayTotals: $dayTotals)';
}


}

/// @nodoc
abstract mixin class _$WeeklySummaryCopyWith<$Res> implements $WeeklySummaryCopyWith<$Res> {
  factory _$WeeklySummaryCopyWith(_WeeklySummary value, $Res Function(_WeeklySummary) _then) = __$WeeklySummaryCopyWithImpl;
@override @useResult
$Res call({
 String fromDay, String toDay, Map<String, NutrientTotals> dayTotals
});




}
/// @nodoc
class __$WeeklySummaryCopyWithImpl<$Res>
    implements _$WeeklySummaryCopyWith<$Res> {
  __$WeeklySummaryCopyWithImpl(this._self, this._then);

  final _WeeklySummary _self;
  final $Res Function(_WeeklySummary) _then;

/// Create a copy of WeeklySummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fromDay = null,Object? toDay = null,Object? dayTotals = null,}) {
  return _then(_WeeklySummary(
fromDay: null == fromDay ? _self.fromDay : fromDay // ignore: cast_nullable_to_non_nullable
as String,toDay: null == toDay ? _self.toDay : toDay // ignore: cast_nullable_to_non_nullable
as String,dayTotals: null == dayTotals ? _self._dayTotals : dayTotals // ignore: cast_nullable_to_non_nullable
as Map<String, NutrientTotals>,
  ));
}


}

// dart format on
