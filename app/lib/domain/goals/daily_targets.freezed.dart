// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'daily_targets.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DailyTargets {

 double? get kcal; double? get proteinG; double? get carbsG; double? get fatG; double? get fibreG;
/// Create a copy of DailyTargets
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailyTargetsCopyWith<DailyTargets> get copyWith => _$DailyTargetsCopyWithImpl<DailyTargets>(this as DailyTargets, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DailyTargets;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailyTargets&&(identical(other.kcal, _this.kcal) || other.kcal == _this.kcal)&&(identical(other.proteinG, _this.proteinG) || other.proteinG == _this.proteinG)&&(identical(other.carbsG, _this.carbsG) || other.carbsG == _this.carbsG)&&(identical(other.fatG, _this.fatG) || other.fatG == _this.fatG)&&(identical(other.fibreG, _this.fibreG) || other.fibreG == _this.fibreG));
}


@override
int get hashCode {
  final _this = this as DailyTargets;
  return Object.hash(runtimeType,_this.kcal,_this.proteinG,_this.carbsG,_this.fatG,_this.fibreG);
}

@override
String toString() {
  final _this = this as DailyTargets;
  return 'DailyTargets(kcal: ${_this.kcal}, proteinG: ${_this.proteinG}, carbsG: ${_this.carbsG}, fatG: ${_this.fatG}, fibreG: ${_this.fibreG})';
}


}

/// @nodoc
abstract mixin class $DailyTargetsCopyWith<$Res>  {
  factory $DailyTargetsCopyWith(DailyTargets value, $Res Function(DailyTargets) _then) = _$DailyTargetsCopyWithImpl;
@useResult
$Res call({
 double? kcal, double? proteinG, double? carbsG, double? fatG, double? fibreG
});




}
/// @nodoc
class _$DailyTargetsCopyWithImpl<$Res>
    implements $DailyTargetsCopyWith<$Res> {
  _$DailyTargetsCopyWithImpl(this._self, this._then);

  final DailyTargets _self;
  final $Res Function(DailyTargets) _then;

/// Create a copy of DailyTargets
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kcal = freezed,Object? proteinG = freezed,Object? carbsG = freezed,Object? fatG = freezed,Object? fibreG = freezed,}) {
  return _then(DailyTargets(
kcal: freezed == kcal ? _self.kcal : kcal // ignore: cast_nullable_to_non_nullable
as double?,proteinG: freezed == proteinG ? _self.proteinG : proteinG // ignore: cast_nullable_to_non_nullable
as double?,carbsG: freezed == carbsG ? _self.carbsG : carbsG // ignore: cast_nullable_to_non_nullable
as double?,fatG: freezed == fatG ? _self.fatG : fatG // ignore: cast_nullable_to_non_nullable
as double?,fibreG: freezed == fibreG ? _self.fibreG : fibreG // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [DailyTargets].
extension DailyTargetsPatterns on DailyTargets {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailyTargets value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailyTargets() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailyTargets value)  $default,){
final _that = this;
switch (_that) {
case _DailyTargets():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailyTargets value)?  $default,){
final _that = this;
switch (_that) {
case _DailyTargets() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double? kcal,  double? proteinG,  double? carbsG,  double? fatG,  double? fibreG)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailyTargets() when $default != null:
return $default(_that.kcal,_that.proteinG,_that.carbsG,_that.fatG,_that.fibreG);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double? kcal,  double? proteinG,  double? carbsG,  double? fatG,  double? fibreG)  $default,) {final _that = this;
switch (_that) {
case _DailyTargets():
return $default(_that.kcal,_that.proteinG,_that.carbsG,_that.fatG,_that.fibreG);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double? kcal,  double? proteinG,  double? carbsG,  double? fatG,  double? fibreG)?  $default,) {final _that = this;
switch (_that) {
case _DailyTargets() when $default != null:
return $default(_that.kcal,_that.proteinG,_that.carbsG,_that.fatG,_that.fibreG);case _:
  return null;

}
}

}

/// @nodoc


class _DailyTargets extends DailyTargets {
  const _DailyTargets({this.kcal, this.proteinG, this.carbsG, this.fatG, this.fibreG}): super._();
  

@override final  double? kcal;
@override final  double? proteinG;
@override final  double? carbsG;
@override final  double? fatG;
@override final  double? fibreG;

/// Create a copy of DailyTargets
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailyTargetsCopyWith<_DailyTargets> get copyWith => __$DailyTargetsCopyWithImpl<_DailyTargets>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailyTargets&&(identical(other.kcal, kcal) || other.kcal == kcal)&&(identical(other.proteinG, proteinG) || other.proteinG == proteinG)&&(identical(other.carbsG, carbsG) || other.carbsG == carbsG)&&(identical(other.fatG, fatG) || other.fatG == fatG)&&(identical(other.fibreG, fibreG) || other.fibreG == fibreG));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kcal,proteinG,carbsG,fatG,fibreG);
}

@override
String toString() {
    return 'DailyTargets(kcal: $kcal, proteinG: $proteinG, carbsG: $carbsG, fatG: $fatG, fibreG: $fibreG)';
}


}

/// @nodoc
abstract mixin class _$DailyTargetsCopyWith<$Res> implements $DailyTargetsCopyWith<$Res> {
  factory _$DailyTargetsCopyWith(_DailyTargets value, $Res Function(_DailyTargets) _then) = __$DailyTargetsCopyWithImpl;
@override @useResult
$Res call({
 double? kcal, double? proteinG, double? carbsG, double? fatG, double? fibreG
});




}
/// @nodoc
class __$DailyTargetsCopyWithImpl<$Res>
    implements _$DailyTargetsCopyWith<$Res> {
  __$DailyTargetsCopyWithImpl(this._self, this._then);

  final _DailyTargets _self;
  final $Res Function(_DailyTargets) _then;

/// Create a copy of DailyTargets
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kcal = freezed,Object? proteinG = freezed,Object? carbsG = freezed,Object? fatG = freezed,Object? fibreG = freezed,}) {
  return _then(_DailyTargets(
kcal: freezed == kcal ? _self.kcal : kcal // ignore: cast_nullable_to_non_nullable
as double?,proteinG: freezed == proteinG ? _self.proteinG : proteinG // ignore: cast_nullable_to_non_nullable
as double?,carbsG: freezed == carbsG ? _self.carbsG : carbsG // ignore: cast_nullable_to_non_nullable
as double?,fatG: freezed == fatG ? _self.fatG : fatG // ignore: cast_nullable_to_non_nullable
as double?,fibreG: freezed == fibreG ? _self.fibreG : fibreG // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc
mixin _$DailySummary {

 String get day; NutrientAmounts get intake; DailyTargets get targets; int get entryCount;
/// Create a copy of DailySummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DailySummaryCopyWith<DailySummary> get copyWith => _$DailySummaryCopyWithImpl<DailySummary>(this as DailySummary, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as DailySummary;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DailySummary&&(identical(other.day, _this.day) || other.day == _this.day)&&(identical(other.intake, _this.intake) || other.intake == _this.intake)&&(identical(other.targets, _this.targets) || other.targets == _this.targets)&&(identical(other.entryCount, _this.entryCount) || other.entryCount == _this.entryCount));
}


@override
int get hashCode {
  final _this = this as DailySummary;
  return Object.hash(runtimeType,_this.day,_this.intake,_this.targets,_this.entryCount);
}

@override
String toString() {
  final _this = this as DailySummary;
  return 'DailySummary(day: ${_this.day}, intake: ${_this.intake}, targets: ${_this.targets}, entryCount: ${_this.entryCount})';
}


}

/// @nodoc
abstract mixin class $DailySummaryCopyWith<$Res>  {
  factory $DailySummaryCopyWith(DailySummary value, $Res Function(DailySummary) _then) = _$DailySummaryCopyWithImpl;
@useResult
$Res call({
 String day, NutrientAmounts intake, DailyTargets targets, int entryCount
});


$NutrientAmountsCopyWith<$Res> get intake;$DailyTargetsCopyWith<$Res> get targets;

}
/// @nodoc
class _$DailySummaryCopyWithImpl<$Res>
    implements $DailySummaryCopyWith<$Res> {
  _$DailySummaryCopyWithImpl(this._self, this._then);

  final DailySummary _self;
  final $Res Function(DailySummary) _then;

/// Create a copy of DailySummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? day = null,Object? intake = null,Object? targets = null,Object? entryCount = null,}) {
  return _then(DailySummary(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as String,intake: null == intake ? _self.intake : intake // ignore: cast_nullable_to_non_nullable
as NutrientAmounts,targets: null == targets ? _self.targets : targets // ignore: cast_nullable_to_non_nullable
as DailyTargets,entryCount: null == entryCount ? _self.entryCount : entryCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of DailySummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientAmountsCopyWith<$Res> get intake {
  
  return $NutrientAmountsCopyWith<$Res>(_self.intake, (value) {
    return _then(_self.copyWith(intake: value));
  });
}/// Create a copy of DailySummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DailyTargetsCopyWith<$Res> get targets {
  
  return $DailyTargetsCopyWith<$Res>(_self.targets, (value) {
    return _then(_self.copyWith(targets: value));
  });
}
}


/// Adds pattern-matching-related methods to [DailySummary].
extension DailySummaryPatterns on DailySummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DailySummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DailySummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DailySummary value)  $default,){
final _that = this;
switch (_that) {
case _DailySummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DailySummary value)?  $default,){
final _that = this;
switch (_that) {
case _DailySummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String day,  NutrientAmounts intake,  DailyTargets targets,  int entryCount)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DailySummary() when $default != null:
return $default(_that.day,_that.intake,_that.targets,_that.entryCount);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String day,  NutrientAmounts intake,  DailyTargets targets,  int entryCount)  $default,) {final _that = this;
switch (_that) {
case _DailySummary():
return $default(_that.day,_that.intake,_that.targets,_that.entryCount);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String day,  NutrientAmounts intake,  DailyTargets targets,  int entryCount)?  $default,) {final _that = this;
switch (_that) {
case _DailySummary() when $default != null:
return $default(_that.day,_that.intake,_that.targets,_that.entryCount);case _:
  return null;

}
}

}

/// @nodoc


class _DailySummary extends DailySummary {
  const _DailySummary({required this.day, required this.intake, required this.targets, required this.entryCount}): super._();
  

@override final  String day;
@override final  NutrientAmounts intake;
@override final  DailyTargets targets;
@override final  int entryCount;

/// Create a copy of DailySummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DailySummaryCopyWith<_DailySummary> get copyWith => __$DailySummaryCopyWithImpl<_DailySummary>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DailySummary&&(identical(other.day, day) || other.day == day)&&(identical(other.intake, intake) || other.intake == intake)&&(identical(other.targets, targets) || other.targets == targets)&&(identical(other.entryCount, entryCount) || other.entryCount == entryCount));
}


@override
int get hashCode {
    return Object.hash(runtimeType,day,intake,targets,entryCount);
}

@override
String toString() {
    return 'DailySummary(day: $day, intake: $intake, targets: $targets, entryCount: $entryCount)';
}


}

/// @nodoc
abstract mixin class _$DailySummaryCopyWith<$Res> implements $DailySummaryCopyWith<$Res> {
  factory _$DailySummaryCopyWith(_DailySummary value, $Res Function(_DailySummary) _then) = __$DailySummaryCopyWithImpl;
@override @useResult
$Res call({
 String day, NutrientAmounts intake, DailyTargets targets, int entryCount
});


@override $NutrientAmountsCopyWith<$Res> get intake;@override $DailyTargetsCopyWith<$Res> get targets;

}
/// @nodoc
class __$DailySummaryCopyWithImpl<$Res>
    implements _$DailySummaryCopyWith<$Res> {
  __$DailySummaryCopyWithImpl(this._self, this._then);

  final _DailySummary _self;
  final $Res Function(_DailySummary) _then;

/// Create a copy of DailySummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? day = null,Object? intake = null,Object? targets = null,Object? entryCount = null,}) {
  return _then(_DailySummary(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as String,intake: null == intake ? _self.intake : intake // ignore: cast_nullable_to_non_nullable
as NutrientAmounts,targets: null == targets ? _self.targets : targets // ignore: cast_nullable_to_non_nullable
as DailyTargets,entryCount: null == entryCount ? _self.entryCount : entryCount // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of DailySummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientAmountsCopyWith<$Res> get intake {
  
  return $NutrientAmountsCopyWith<$Res>(_self.intake, (value) {
    return _then(_self.copyWith(intake: value));
  });
}/// Create a copy of DailySummary
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DailyTargetsCopyWith<$Res> get targets {
  
  return $DailyTargetsCopyWith<$Res>(_self.targets, (value) {
    return _then(_self.copyWith(targets: value));
  });
}
}

// dart format on
