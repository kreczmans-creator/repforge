// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'goals.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Goal {

 String get id; GoalKind get kind; double get target; DateTime get startDate; DateTime get createdAt; DateTime get updatedAt; MeasurementSite? get site; DateTime? get endDate; bool get active;
/// Create a copy of Goal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$GoalCopyWith<Goal> get copyWith => _$GoalCopyWithImpl<Goal>(this as Goal, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Goal;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Goal&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.target, _this.target) || other.target == _this.target)&&(identical(other.startDate, _this.startDate) || other.startDate == _this.startDate)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.site, _this.site) || other.site == _this.site)&&(identical(other.endDate, _this.endDate) || other.endDate == _this.endDate)&&(identical(other.active, _this.active) || other.active == _this.active));
}


@override
int get hashCode {
  final _this = this as Goal;
  return Object.hash(runtimeType,_this.id,_this.kind,_this.target,_this.startDate,_this.createdAt,_this.updatedAt,_this.site,_this.endDate,_this.active);
}

@override
String toString() {
  final _this = this as Goal;
  return 'Goal(id: ${_this.id}, kind: ${_this.kind}, target: ${_this.target}, startDate: ${_this.startDate}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, site: ${_this.site}, endDate: ${_this.endDate}, active: ${_this.active})';
}


}

/// @nodoc
abstract mixin class $GoalCopyWith<$Res>  {
  factory $GoalCopyWith(Goal value, $Res Function(Goal) _then) = _$GoalCopyWithImpl;
@useResult
$Res call({
 String id, GoalKind kind, double target, DateTime startDate, DateTime createdAt, DateTime updatedAt, MeasurementSite? site, DateTime? endDate, bool active
});




}
/// @nodoc
class _$GoalCopyWithImpl<$Res>
    implements $GoalCopyWith<$Res> {
  _$GoalCopyWithImpl(this._self, this._then);

  final Goal _self;
  final $Res Function(Goal) _then;

/// Create a copy of Goal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? kind = null,Object? target = null,Object? startDate = null,Object? createdAt = null,Object? updatedAt = null,Object? site = freezed,Object? endDate = freezed,Object? active = null,}) {
  return _then(Goal(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as GoalKind,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as double,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,site: freezed == site ? _self.site : site // ignore: cast_nullable_to_non_nullable
as MeasurementSite?,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Goal].
extension GoalPatterns on Goal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Goal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Goal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Goal value)  $default,){
final _that = this;
switch (_that) {
case _Goal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Goal value)?  $default,){
final _that = this;
switch (_that) {
case _Goal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  GoalKind kind,  double target,  DateTime startDate,  DateTime createdAt,  DateTime updatedAt,  MeasurementSite? site,  DateTime? endDate,  bool active)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Goal() when $default != null:
return $default(_that.id,_that.kind,_that.target,_that.startDate,_that.createdAt,_that.updatedAt,_that.site,_that.endDate,_that.active);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  GoalKind kind,  double target,  DateTime startDate,  DateTime createdAt,  DateTime updatedAt,  MeasurementSite? site,  DateTime? endDate,  bool active)  $default,) {final _that = this;
switch (_that) {
case _Goal():
return $default(_that.id,_that.kind,_that.target,_that.startDate,_that.createdAt,_that.updatedAt,_that.site,_that.endDate,_that.active);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  GoalKind kind,  double target,  DateTime startDate,  DateTime createdAt,  DateTime updatedAt,  MeasurementSite? site,  DateTime? endDate,  bool active)?  $default,) {final _that = this;
switch (_that) {
case _Goal() when $default != null:
return $default(_that.id,_that.kind,_that.target,_that.startDate,_that.createdAt,_that.updatedAt,_that.site,_that.endDate,_that.active);case _:
  return null;

}
}

}

/// @nodoc


class _Goal implements Goal {
  const _Goal({required this.id, required this.kind, required this.target, required this.startDate, required this.createdAt, required this.updatedAt, this.site, this.endDate, this.active = true});
  

@override final  String id;
@override final  GoalKind kind;
@override final  double target;
@override final  DateTime startDate;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  MeasurementSite? site;
@override final  DateTime? endDate;
@override@JsonKey() final  bool active;

/// Create a copy of Goal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$GoalCopyWith<_Goal> get copyWith => __$GoalCopyWithImpl<_Goal>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Goal&&(identical(other.id, id) || other.id == id)&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.target, target) || other.target == target)&&(identical(other.startDate, startDate) || other.startDate == startDate)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.site, site) || other.site == site)&&(identical(other.endDate, endDate) || other.endDate == endDate)&&(identical(other.active, active) || other.active == active));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,kind,target,startDate,createdAt,updatedAt,site,endDate,active);
}

@override
String toString() {
    return 'Goal(id: $id, kind: $kind, target: $target, startDate: $startDate, createdAt: $createdAt, updatedAt: $updatedAt, site: $site, endDate: $endDate, active: $active)';
}


}

/// @nodoc
abstract mixin class _$GoalCopyWith<$Res> implements $GoalCopyWith<$Res> {
  factory _$GoalCopyWith(_Goal value, $Res Function(_Goal) _then) = __$GoalCopyWithImpl;
@override @useResult
$Res call({
 String id, GoalKind kind, double target, DateTime startDate, DateTime createdAt, DateTime updatedAt, MeasurementSite? site, DateTime? endDate, bool active
});




}
/// @nodoc
class __$GoalCopyWithImpl<$Res>
    implements _$GoalCopyWith<$Res> {
  __$GoalCopyWithImpl(this._self, this._then);

  final _Goal _self;
  final $Res Function(_Goal) _then;

/// Create a copy of Goal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? kind = null,Object? target = null,Object? startDate = null,Object? createdAt = null,Object? updatedAt = null,Object? site = freezed,Object? endDate = freezed,Object? active = null,}) {
  return _then(_Goal(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as GoalKind,target: null == target ? _self.target : target // ignore: cast_nullable_to_non_nullable
as double,startDate: null == startDate ? _self.startDate : startDate // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,site: freezed == site ? _self.site : site // ignore: cast_nullable_to_non_nullable
as MeasurementSite?,endDate: freezed == endDate ? _self.endDate : endDate // ignore: cast_nullable_to_non_nullable
as DateTime?,active: null == active ? _self.active : active // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
