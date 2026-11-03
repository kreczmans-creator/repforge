// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'training.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$Exercise {

 String get id; String get name; ExerciseType get type; String get category; String get primaryMuscle; DateTime get createdAt; DateTime get updatedAt; List<String> get secondaryMuscles; List<String> get equipment; bool get isCustom; bool get archived;
/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExerciseCopyWith<Exercise> get copyWith => _$ExerciseCopyWithImpl<Exercise>(this as Exercise, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Exercise;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Exercise&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.type, _this.type) || other.type == _this.type)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.primaryMuscle, _this.primaryMuscle) || other.primaryMuscle == _this.primaryMuscle)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&const DeepCollectionEquality().equals(other.secondaryMuscles, _this.secondaryMuscles)&&const DeepCollectionEquality().equals(other.equipment, _this.equipment)&&(identical(other.isCustom, _this.isCustom) || other.isCustom == _this.isCustom)&&(identical(other.archived, _this.archived) || other.archived == _this.archived));
}


@override
int get hashCode {
  final _this = this as Exercise;
  return Object.hash(runtimeType,_this.id,_this.name,_this.type,_this.category,_this.primaryMuscle,_this.createdAt,_this.updatedAt,const DeepCollectionEquality().hash(_this.secondaryMuscles),const DeepCollectionEquality().hash(_this.equipment),_this.isCustom,_this.archived);
}

@override
String toString() {
  final _this = this as Exercise;
  return 'Exercise(id: ${_this.id}, name: ${_this.name}, type: ${_this.type}, category: ${_this.category}, primaryMuscle: ${_this.primaryMuscle}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, secondaryMuscles: ${_this.secondaryMuscles}, equipment: ${_this.equipment}, isCustom: ${_this.isCustom}, archived: ${_this.archived})';
}


}

/// @nodoc
abstract mixin class $ExerciseCopyWith<$Res>  {
  factory $ExerciseCopyWith(Exercise value, $Res Function(Exercise) _then) = _$ExerciseCopyWithImpl;
@useResult
$Res call({
 String id, String name, ExerciseType type, String category, String primaryMuscle, DateTime createdAt, DateTime updatedAt, List<String> secondaryMuscles, List<String> equipment, bool isCustom, bool archived
});




}
/// @nodoc
class _$ExerciseCopyWithImpl<$Res>
    implements $ExerciseCopyWith<$Res> {
  _$ExerciseCopyWithImpl(this._self, this._then);

  final Exercise _self;
  final $Res Function(Exercise) _then;

/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? type = null,Object? category = null,Object? primaryMuscle = null,Object? createdAt = null,Object? updatedAt = null,Object? secondaryMuscles = null,Object? equipment = null,Object? isCustom = null,Object? archived = null,}) {
  return _then(Exercise(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ExerciseType,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,primaryMuscle: null == primaryMuscle ? _self.primaryMuscle : primaryMuscle // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,secondaryMuscles: null == secondaryMuscles ? _self.secondaryMuscles : secondaryMuscles // ignore: cast_nullable_to_non_nullable
as List<String>,equipment: null == equipment ? _self.equipment : equipment // ignore: cast_nullable_to_non_nullable
as List<String>,isCustom: null == isCustom ? _self.isCustom : isCustom // ignore: cast_nullable_to_non_nullable
as bool,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [Exercise].
extension ExercisePatterns on Exercise {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Exercise value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Exercise() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Exercise value)  $default,){
final _that = this;
switch (_that) {
case _Exercise():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Exercise value)?  $default,){
final _that = this;
switch (_that) {
case _Exercise() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  ExerciseType type,  String category,  String primaryMuscle,  DateTime createdAt,  DateTime updatedAt,  List<String> secondaryMuscles,  List<String> equipment,  bool isCustom,  bool archived)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Exercise() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.category,_that.primaryMuscle,_that.createdAt,_that.updatedAt,_that.secondaryMuscles,_that.equipment,_that.isCustom,_that.archived);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  ExerciseType type,  String category,  String primaryMuscle,  DateTime createdAt,  DateTime updatedAt,  List<String> secondaryMuscles,  List<String> equipment,  bool isCustom,  bool archived)  $default,) {final _that = this;
switch (_that) {
case _Exercise():
return $default(_that.id,_that.name,_that.type,_that.category,_that.primaryMuscle,_that.createdAt,_that.updatedAt,_that.secondaryMuscles,_that.equipment,_that.isCustom,_that.archived);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  ExerciseType type,  String category,  String primaryMuscle,  DateTime createdAt,  DateTime updatedAt,  List<String> secondaryMuscles,  List<String> equipment,  bool isCustom,  bool archived)?  $default,) {final _that = this;
switch (_that) {
case _Exercise() when $default != null:
return $default(_that.id,_that.name,_that.type,_that.category,_that.primaryMuscle,_that.createdAt,_that.updatedAt,_that.secondaryMuscles,_that.equipment,_that.isCustom,_that.archived);case _:
  return null;

}
}

}

/// @nodoc


class _Exercise implements Exercise {
  const _Exercise({required this.id, required this.name, required this.type, required this.category, required this.primaryMuscle, required this.createdAt, required this.updatedAt,  List<String> secondaryMuscles = const <String>[],  List<String> equipment = const <String>[], this.isCustom = false, this.archived = false}): _secondaryMuscles = secondaryMuscles,_equipment = equipment;
  

@override final  String id;
@override final  String name;
@override final  ExerciseType type;
@override final  String category;
@override final  String primaryMuscle;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
 final  List<String> _secondaryMuscles;
@override@JsonKey() List<String> get secondaryMuscles {
  if (_secondaryMuscles is EqualUnmodifiableListView) return _secondaryMuscles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_secondaryMuscles);
}

 final  List<String> _equipment;
@override@JsonKey() List<String> get equipment {
  if (_equipment is EqualUnmodifiableListView) return _equipment;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_equipment);
}

@override@JsonKey() final  bool isCustom;
@override@JsonKey() final  bool archived;

/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExerciseCopyWith<_Exercise> get copyWith => __$ExerciseCopyWithImpl<_Exercise>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Exercise&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.type, type) || other.type == type)&&(identical(other.category, category) || other.category == category)&&(identical(other.primaryMuscle, primaryMuscle) || other.primaryMuscle == primaryMuscle)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&const DeepCollectionEquality().equals(other.secondaryMuscles, _secondaryMuscles)&&const DeepCollectionEquality().equals(other.equipment, _equipment)&&(identical(other.isCustom, isCustom) || other.isCustom == isCustom)&&(identical(other.archived, archived) || other.archived == archived));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,type,category,primaryMuscle,createdAt,updatedAt,const DeepCollectionEquality().hash(_secondaryMuscles),const DeepCollectionEquality().hash(_equipment),isCustom,archived);
}

@override
String toString() {
    return 'Exercise(id: $id, name: $name, type: $type, category: $category, primaryMuscle: $primaryMuscle, createdAt: $createdAt, updatedAt: $updatedAt, secondaryMuscles: $secondaryMuscles, equipment: $equipment, isCustom: $isCustom, archived: $archived)';
}


}

/// @nodoc
abstract mixin class _$ExerciseCopyWith<$Res> implements $ExerciseCopyWith<$Res> {
  factory _$ExerciseCopyWith(_Exercise value, $Res Function(_Exercise) _then) = __$ExerciseCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, ExerciseType type, String category, String primaryMuscle, DateTime createdAt, DateTime updatedAt, List<String> secondaryMuscles, List<String> equipment, bool isCustom, bool archived
});




}
/// @nodoc
class __$ExerciseCopyWithImpl<$Res>
    implements _$ExerciseCopyWith<$Res> {
  __$ExerciseCopyWithImpl(this._self, this._then);

  final _Exercise _self;
  final $Res Function(_Exercise) _then;

/// Create a copy of Exercise
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? type = null,Object? category = null,Object? primaryMuscle = null,Object? createdAt = null,Object? updatedAt = null,Object? secondaryMuscles = null,Object? equipment = null,Object? isCustom = null,Object? archived = null,}) {
  return _then(_Exercise(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as ExerciseType,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,primaryMuscle: null == primaryMuscle ? _self.primaryMuscle : primaryMuscle // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,secondaryMuscles: null == secondaryMuscles ? _self._secondaryMuscles : secondaryMuscles // ignore: cast_nullable_to_non_nullable
as List<String>,equipment: null == equipment ? _self._equipment : equipment // ignore: cast_nullable_to_non_nullable
as List<String>,isCustom: null == isCustom ? _self.isCustom : isCustom // ignore: cast_nullable_to_non_nullable
as bool,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

/// @nodoc
mixin _$Exertion {

 ExertionScale get scale; double get value;
/// Create a copy of Exertion
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ExertionCopyWith<Exertion> get copyWith => _$ExertionCopyWithImpl<Exertion>(this as Exertion, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Exertion;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Exertion&&(identical(other.scale, _this.scale) || other.scale == _this.scale)&&(identical(other.value, _this.value) || other.value == _this.value));
}


@override
int get hashCode {
  final _this = this as Exertion;
  return Object.hash(runtimeType,_this.scale,_this.value);
}

@override
String toString() {
  final _this = this as Exertion;
  return 'Exertion(scale: ${_this.scale}, value: ${_this.value})';
}


}

/// @nodoc
abstract mixin class $ExertionCopyWith<$Res>  {
  factory $ExertionCopyWith(Exertion value, $Res Function(Exertion) _then) = _$ExertionCopyWithImpl;
@useResult
$Res call({
 ExertionScale scale, double value
});




}
/// @nodoc
class _$ExertionCopyWithImpl<$Res>
    implements $ExertionCopyWith<$Res> {
  _$ExertionCopyWithImpl(this._self, this._then);

  final Exertion _self;
  final $Res Function(Exertion) _then;

/// Create a copy of Exertion
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? scale = null,Object? value = null,}) {
  return _then(Exertion(
scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as ExertionScale,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [Exertion].
extension ExertionPatterns on Exertion {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Exertion value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Exertion() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Exertion value)  $default,){
final _that = this;
switch (_that) {
case _Exertion():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Exertion value)?  $default,){
final _that = this;
switch (_that) {
case _Exertion() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ExertionScale scale,  double value)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Exertion() when $default != null:
return $default(_that.scale,_that.value);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ExertionScale scale,  double value)  $default,) {final _that = this;
switch (_that) {
case _Exertion():
return $default(_that.scale,_that.value);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ExertionScale scale,  double value)?  $default,) {final _that = this;
switch (_that) {
case _Exertion() when $default != null:
return $default(_that.scale,_that.value);case _:
  return null;

}
}

}

/// @nodoc


class _Exertion implements Exertion {
  const _Exertion({required this.scale, required this.value});
  

@override final  ExertionScale scale;
@override final  double value;

/// Create a copy of Exertion
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ExertionCopyWith<_Exertion> get copyWith => __$ExertionCopyWithImpl<_Exertion>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Exertion&&(identical(other.scale, scale) || other.scale == scale)&&(identical(other.value, value) || other.value == value));
}


@override
int get hashCode {
    return Object.hash(runtimeType,scale,value);
}

@override
String toString() {
    return 'Exertion(scale: $scale, value: $value)';
}


}

/// @nodoc
abstract mixin class _$ExertionCopyWith<$Res> implements $ExertionCopyWith<$Res> {
  factory _$ExertionCopyWith(_Exertion value, $Res Function(_Exertion) _then) = __$ExertionCopyWithImpl;
@override @useResult
$Res call({
 ExertionScale scale, double value
});




}
/// @nodoc
class __$ExertionCopyWithImpl<$Res>
    implements _$ExertionCopyWith<$Res> {
  __$ExertionCopyWithImpl(this._self, this._then);

  final _Exertion _self;
  final $Res Function(_Exertion) _then;

/// Create a copy of Exertion
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? scale = null,Object? value = null,}) {
  return _then(_Exertion(
scale: null == scale ? _self.scale : scale // ignore: cast_nullable_to_non_nullable
as ExertionScale,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc
mixin _$SetData {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is SetData);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'SetData()';
}


}

/// @nodoc
class $SetDataCopyWith<$Res>  {
$SetDataCopyWith(SetData _, $Res Function(SetData) __);
}


/// Adds pattern-matching-related methods to [SetData].
extension SetDataPatterns on SetData {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( WeightedSet value)?  weighted,TResult Function( BodyweightSet value)?  bodyweight,TResult Function( AssistedSet value)?  assisted,TResult Function( TimedSet value)?  timed,TResult Function( DistanceSet value)?  distance,TResult Function( CardioSet value)?  cardio,required TResult orElse(),}){
final _that = this;
switch (_that) {
case WeightedSet() when weighted != null:
return weighted(_that);case BodyweightSet() when bodyweight != null:
return bodyweight(_that);case AssistedSet() when assisted != null:
return assisted(_that);case TimedSet() when timed != null:
return timed(_that);case DistanceSet() when distance != null:
return distance(_that);case CardioSet() when cardio != null:
return cardio(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( WeightedSet value)  weighted,required TResult Function( BodyweightSet value)  bodyweight,required TResult Function( AssistedSet value)  assisted,required TResult Function( TimedSet value)  timed,required TResult Function( DistanceSet value)  distance,required TResult Function( CardioSet value)  cardio,}){
final _that = this;
switch (_that) {
case WeightedSet():
return weighted(_that);case BodyweightSet():
return bodyweight(_that);case AssistedSet():
return assisted(_that);case TimedSet():
return timed(_that);case DistanceSet():
return distance(_that);case CardioSet():
return cardio(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( WeightedSet value)?  weighted,TResult? Function( BodyweightSet value)?  bodyweight,TResult? Function( AssistedSet value)?  assisted,TResult? Function( TimedSet value)?  timed,TResult? Function( DistanceSet value)?  distance,TResult? Function( CardioSet value)?  cardio,}){
final _that = this;
switch (_that) {
case WeightedSet() when weighted != null:
return weighted(_that);case BodyweightSet() when bodyweight != null:
return bodyweight(_that);case AssistedSet() when assisted != null:
return assisted(_that);case TimedSet() when timed != null:
return timed(_that);case DistanceSet() when distance != null:
return distance(_that);case CardioSet() when cardio != null:
return cardio(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( LoadKg load,  int reps)?  weighted,TResult Function( int reps,  LoadKg? addedLoad)?  bodyweight,TResult Function( int reps,  LoadKg assistance)?  assisted,TResult Function( Duration duration)?  timed,TResult Function( double metres,  Duration? duration)?  distance,TResult Function( Duration duration,  double? metres,  int? averageHeartRate)?  cardio,required TResult orElse(),}) {final _that = this;
switch (_that) {
case WeightedSet() when weighted != null:
return weighted(_that.load,_that.reps);case BodyweightSet() when bodyweight != null:
return bodyweight(_that.reps,_that.addedLoad);case AssistedSet() when assisted != null:
return assisted(_that.reps,_that.assistance);case TimedSet() when timed != null:
return timed(_that.duration);case DistanceSet() when distance != null:
return distance(_that.metres,_that.duration);case CardioSet() when cardio != null:
return cardio(_that.duration,_that.metres,_that.averageHeartRate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( LoadKg load,  int reps)  weighted,required TResult Function( int reps,  LoadKg? addedLoad)  bodyweight,required TResult Function( int reps,  LoadKg assistance)  assisted,required TResult Function( Duration duration)  timed,required TResult Function( double metres,  Duration? duration)  distance,required TResult Function( Duration duration,  double? metres,  int? averageHeartRate)  cardio,}) {final _that = this;
switch (_that) {
case WeightedSet():
return weighted(_that.load,_that.reps);case BodyweightSet():
return bodyweight(_that.reps,_that.addedLoad);case AssistedSet():
return assisted(_that.reps,_that.assistance);case TimedSet():
return timed(_that.duration);case DistanceSet():
return distance(_that.metres,_that.duration);case CardioSet():
return cardio(_that.duration,_that.metres,_that.averageHeartRate);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( LoadKg load,  int reps)?  weighted,TResult? Function( int reps,  LoadKg? addedLoad)?  bodyweight,TResult? Function( int reps,  LoadKg assistance)?  assisted,TResult? Function( Duration duration)?  timed,TResult? Function( double metres,  Duration? duration)?  distance,TResult? Function( Duration duration,  double? metres,  int? averageHeartRate)?  cardio,}) {final _that = this;
switch (_that) {
case WeightedSet() when weighted != null:
return weighted(_that.load,_that.reps);case BodyweightSet() when bodyweight != null:
return bodyweight(_that.reps,_that.addedLoad);case AssistedSet() when assisted != null:
return assisted(_that.reps,_that.assistance);case TimedSet() when timed != null:
return timed(_that.duration);case DistanceSet() when distance != null:
return distance(_that.metres,_that.duration);case CardioSet() when cardio != null:
return cardio(_that.duration,_that.metres,_that.averageHeartRate);case _:
  return null;

}
}

}

/// @nodoc


class WeightedSet extends SetData {
  const WeightedSet({required this.load, required this.reps}): super._();
  

 final  LoadKg load;
 final  int reps;

/// Create a copy of SetData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeightedSetCopyWith<WeightedSet> get copyWith => _$WeightedSetCopyWithImpl<WeightedSet>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is WeightedSet&&(identical(other.load, load) || other.load == load)&&(identical(other.reps, reps) || other.reps == reps));
}


@override
int get hashCode {
    return Object.hash(runtimeType,load,reps);
}

@override
String toString() {
    return 'SetData.weighted(load: $load, reps: $reps)';
}


}

/// @nodoc
abstract mixin class $WeightedSetCopyWith<$Res> implements $SetDataCopyWith<$Res> {
  factory $WeightedSetCopyWith(WeightedSet value, $Res Function(WeightedSet) _then) = _$WeightedSetCopyWithImpl;
@useResult
$Res call({
 LoadKg load, int reps
});




}
/// @nodoc
class _$WeightedSetCopyWithImpl<$Res>
    implements $WeightedSetCopyWith<$Res> {
  _$WeightedSetCopyWithImpl(this._self, this._then);

  final WeightedSet _self;
  final $Res Function(WeightedSet) _then;

/// Create a copy of SetData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? load = null,Object? reps = null,}) {
  return _then(WeightedSet(
load: null == load ? _self.load : load // ignore: cast_nullable_to_non_nullable
as LoadKg,reps: null == reps ? _self.reps : reps // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc


class BodyweightSet extends SetData {
  const BodyweightSet({required this.reps, this.addedLoad}): super._();
  

 final  int reps;
 final  LoadKg? addedLoad;

/// Create a copy of SetData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BodyweightSetCopyWith<BodyweightSet> get copyWith => _$BodyweightSetCopyWithImpl<BodyweightSet>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BodyweightSet&&(identical(other.reps, reps) || other.reps == reps)&&(identical(other.addedLoad, addedLoad) || other.addedLoad == addedLoad));
}


@override
int get hashCode {
    return Object.hash(runtimeType,reps,addedLoad);
}

@override
String toString() {
    return 'SetData.bodyweight(reps: $reps, addedLoad: $addedLoad)';
}


}

/// @nodoc
abstract mixin class $BodyweightSetCopyWith<$Res> implements $SetDataCopyWith<$Res> {
  factory $BodyweightSetCopyWith(BodyweightSet value, $Res Function(BodyweightSet) _then) = _$BodyweightSetCopyWithImpl;
@useResult
$Res call({
 int reps, LoadKg? addedLoad
});




}
/// @nodoc
class _$BodyweightSetCopyWithImpl<$Res>
    implements $BodyweightSetCopyWith<$Res> {
  _$BodyweightSetCopyWithImpl(this._self, this._then);

  final BodyweightSet _self;
  final $Res Function(BodyweightSet) _then;

/// Create a copy of SetData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reps = null,Object? addedLoad = freezed,}) {
  return _then(BodyweightSet(
reps: null == reps ? _self.reps : reps // ignore: cast_nullable_to_non_nullable
as int,addedLoad: freezed == addedLoad ? _self.addedLoad : addedLoad // ignore: cast_nullable_to_non_nullable
as LoadKg?,
  ));
}


}

/// @nodoc


class AssistedSet extends SetData {
  const AssistedSet({required this.reps, required this.assistance}): super._();
  

 final  int reps;
 final  LoadKg assistance;

/// Create a copy of SetData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AssistedSetCopyWith<AssistedSet> get copyWith => _$AssistedSetCopyWithImpl<AssistedSet>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is AssistedSet&&(identical(other.reps, reps) || other.reps == reps)&&(identical(other.assistance, assistance) || other.assistance == assistance));
}


@override
int get hashCode {
    return Object.hash(runtimeType,reps,assistance);
}

@override
String toString() {
    return 'SetData.assisted(reps: $reps, assistance: $assistance)';
}


}

/// @nodoc
abstract mixin class $AssistedSetCopyWith<$Res> implements $SetDataCopyWith<$Res> {
  factory $AssistedSetCopyWith(AssistedSet value, $Res Function(AssistedSet) _then) = _$AssistedSetCopyWithImpl;
@useResult
$Res call({
 int reps, LoadKg assistance
});




}
/// @nodoc
class _$AssistedSetCopyWithImpl<$Res>
    implements $AssistedSetCopyWith<$Res> {
  _$AssistedSetCopyWithImpl(this._self, this._then);

  final AssistedSet _self;
  final $Res Function(AssistedSet) _then;

/// Create a copy of SetData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? reps = null,Object? assistance = null,}) {
  return _then(AssistedSet(
reps: null == reps ? _self.reps : reps // ignore: cast_nullable_to_non_nullable
as int,assistance: null == assistance ? _self.assistance : assistance // ignore: cast_nullable_to_non_nullable
as LoadKg,
  ));
}


}

/// @nodoc


class TimedSet extends SetData {
  const TimedSet({required this.duration}): super._();
  

 final  Duration duration;

/// Create a copy of SetData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TimedSetCopyWith<TimedSet> get copyWith => _$TimedSetCopyWithImpl<TimedSet>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is TimedSet&&(identical(other.duration, duration) || other.duration == duration));
}


@override
int get hashCode {
    return Object.hash(runtimeType,duration);
}

@override
String toString() {
    return 'SetData.timed(duration: $duration)';
}


}

/// @nodoc
abstract mixin class $TimedSetCopyWith<$Res> implements $SetDataCopyWith<$Res> {
  factory $TimedSetCopyWith(TimedSet value, $Res Function(TimedSet) _then) = _$TimedSetCopyWithImpl;
@useResult
$Res call({
 Duration duration
});




}
/// @nodoc
class _$TimedSetCopyWithImpl<$Res>
    implements $TimedSetCopyWith<$Res> {
  _$TimedSetCopyWithImpl(this._self, this._then);

  final TimedSet _self;
  final $Res Function(TimedSet) _then;

/// Create a copy of SetData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? duration = null,}) {
  return _then(TimedSet(
duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,
  ));
}


}

/// @nodoc


class DistanceSet extends SetData {
  const DistanceSet({required this.metres, this.duration}): super._();
  

 final  double metres;
 final  Duration? duration;

/// Create a copy of SetData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DistanceSetCopyWith<DistanceSet> get copyWith => _$DistanceSetCopyWithImpl<DistanceSet>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is DistanceSet&&(identical(other.metres, metres) || other.metres == metres)&&(identical(other.duration, duration) || other.duration == duration));
}


@override
int get hashCode {
    return Object.hash(runtimeType,metres,duration);
}

@override
String toString() {
    return 'SetData.distance(metres: $metres, duration: $duration)';
}


}

/// @nodoc
abstract mixin class $DistanceSetCopyWith<$Res> implements $SetDataCopyWith<$Res> {
  factory $DistanceSetCopyWith(DistanceSet value, $Res Function(DistanceSet) _then) = _$DistanceSetCopyWithImpl;
@useResult
$Res call({
 double metres, Duration? duration
});




}
/// @nodoc
class _$DistanceSetCopyWithImpl<$Res>
    implements $DistanceSetCopyWith<$Res> {
  _$DistanceSetCopyWithImpl(this._self, this._then);

  final DistanceSet _self;
  final $Res Function(DistanceSet) _then;

/// Create a copy of SetData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? metres = null,Object? duration = freezed,}) {
  return _then(DistanceSet(
metres: null == metres ? _self.metres : metres // ignore: cast_nullable_to_non_nullable
as double,duration: freezed == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration?,
  ));
}


}

/// @nodoc


class CardioSet extends SetData {
  const CardioSet({required this.duration, this.metres, this.averageHeartRate}): super._();
  

 final  Duration duration;
 final  double? metres;
 final  int? averageHeartRate;

/// Create a copy of SetData
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CardioSetCopyWith<CardioSet> get copyWith => _$CardioSetCopyWithImpl<CardioSet>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is CardioSet&&(identical(other.duration, duration) || other.duration == duration)&&(identical(other.metres, metres) || other.metres == metres)&&(identical(other.averageHeartRate, averageHeartRate) || other.averageHeartRate == averageHeartRate));
}


@override
int get hashCode {
    return Object.hash(runtimeType,duration,metres,averageHeartRate);
}

@override
String toString() {
    return 'SetData.cardio(duration: $duration, metres: $metres, averageHeartRate: $averageHeartRate)';
}


}

/// @nodoc
abstract mixin class $CardioSetCopyWith<$Res> implements $SetDataCopyWith<$Res> {
  factory $CardioSetCopyWith(CardioSet value, $Res Function(CardioSet) _then) = _$CardioSetCopyWithImpl;
@useResult
$Res call({
 Duration duration, double? metres, int? averageHeartRate
});




}
/// @nodoc
class _$CardioSetCopyWithImpl<$Res>
    implements $CardioSetCopyWith<$Res> {
  _$CardioSetCopyWithImpl(this._self, this._then);

  final CardioSet _self;
  final $Res Function(CardioSet) _then;

/// Create a copy of SetData
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? duration = null,Object? metres = freezed,Object? averageHeartRate = freezed,}) {
  return _then(CardioSet(
duration: null == duration ? _self.duration : duration // ignore: cast_nullable_to_non_nullable
as Duration,metres: freezed == metres ? _self.metres : metres // ignore: cast_nullable_to_non_nullable
as double?,averageHeartRate: freezed == averageHeartRate ? _self.averageHeartRate : averageHeartRate // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$SessionSet {

 String get id; String get sessionId; String get exerciseId; int get exerciseOrder; int get setOrder; SetData get data; bool get completed; Exertion? get exertion; int? get restSeconds; String? get note;
/// Create a copy of SessionSet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SessionSetCopyWith<SessionSet> get copyWith => _$SessionSetCopyWithImpl<SessionSet>(this as SessionSet, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SessionSet;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SessionSet&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sessionId, _this.sessionId) || other.sessionId == _this.sessionId)&&(identical(other.exerciseId, _this.exerciseId) || other.exerciseId == _this.exerciseId)&&(identical(other.exerciseOrder, _this.exerciseOrder) || other.exerciseOrder == _this.exerciseOrder)&&(identical(other.setOrder, _this.setOrder) || other.setOrder == _this.setOrder)&&(identical(other.data, _this.data) || other.data == _this.data)&&(identical(other.completed, _this.completed) || other.completed == _this.completed)&&(identical(other.exertion, _this.exertion) || other.exertion == _this.exertion)&&(identical(other.restSeconds, _this.restSeconds) || other.restSeconds == _this.restSeconds)&&(identical(other.note, _this.note) || other.note == _this.note));
}


@override
int get hashCode {
  final _this = this as SessionSet;
  return Object.hash(runtimeType,_this.id,_this.sessionId,_this.exerciseId,_this.exerciseOrder,_this.setOrder,_this.data,_this.completed,_this.exertion,_this.restSeconds,_this.note);
}

@override
String toString() {
  final _this = this as SessionSet;
  return 'SessionSet(id: ${_this.id}, sessionId: ${_this.sessionId}, exerciseId: ${_this.exerciseId}, exerciseOrder: ${_this.exerciseOrder}, setOrder: ${_this.setOrder}, data: ${_this.data}, completed: ${_this.completed}, exertion: ${_this.exertion}, restSeconds: ${_this.restSeconds}, note: ${_this.note})';
}


}

/// @nodoc
abstract mixin class $SessionSetCopyWith<$Res>  {
  factory $SessionSetCopyWith(SessionSet value, $Res Function(SessionSet) _then) = _$SessionSetCopyWithImpl;
@useResult
$Res call({
 String id, String sessionId, String exerciseId, int exerciseOrder, int setOrder, SetData data, bool completed, Exertion? exertion, int? restSeconds, String? note
});


$SetDataCopyWith<$Res> get data;$ExertionCopyWith<$Res>? get exertion;

}
/// @nodoc
class _$SessionSetCopyWithImpl<$Res>
    implements $SessionSetCopyWith<$Res> {
  _$SessionSetCopyWithImpl(this._self, this._then);

  final SessionSet _self;
  final $Res Function(SessionSet) _then;

/// Create a copy of SessionSet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sessionId = null,Object? exerciseId = null,Object? exerciseOrder = null,Object? setOrder = null,Object? data = null,Object? completed = null,Object? exertion = freezed,Object? restSeconds = freezed,Object? note = freezed,}) {
  return _then(SessionSet(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,exerciseId: null == exerciseId ? _self.exerciseId : exerciseId // ignore: cast_nullable_to_non_nullable
as String,exerciseOrder: null == exerciseOrder ? _self.exerciseOrder : exerciseOrder // ignore: cast_nullable_to_non_nullable
as int,setOrder: null == setOrder ? _self.setOrder : setOrder // ignore: cast_nullable_to_non_nullable
as int,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as SetData,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,exertion: freezed == exertion ? _self.exertion : exertion // ignore: cast_nullable_to_non_nullable
as Exertion?,restSeconds: freezed == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of SessionSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SetDataCopyWith<$Res> get data {
  
  return $SetDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}/// Create a copy of SessionSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExertionCopyWith<$Res>? get exertion {
    if (_self.exertion == null) {
    return null;
  }

  return $ExertionCopyWith<$Res>(_self.exertion!, (value) {
    return _then(_self.copyWith(exertion: value));
  });
}
}


/// Adds pattern-matching-related methods to [SessionSet].
extension SessionSetPatterns on SessionSet {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SessionSet value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SessionSet() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SessionSet value)  $default,){
final _that = this;
switch (_that) {
case _SessionSet():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SessionSet value)?  $default,){
final _that = this;
switch (_that) {
case _SessionSet() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String sessionId,  String exerciseId,  int exerciseOrder,  int setOrder,  SetData data,  bool completed,  Exertion? exertion,  int? restSeconds,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SessionSet() when $default != null:
return $default(_that.id,_that.sessionId,_that.exerciseId,_that.exerciseOrder,_that.setOrder,_that.data,_that.completed,_that.exertion,_that.restSeconds,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String sessionId,  String exerciseId,  int exerciseOrder,  int setOrder,  SetData data,  bool completed,  Exertion? exertion,  int? restSeconds,  String? note)  $default,) {final _that = this;
switch (_that) {
case _SessionSet():
return $default(_that.id,_that.sessionId,_that.exerciseId,_that.exerciseOrder,_that.setOrder,_that.data,_that.completed,_that.exertion,_that.restSeconds,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String sessionId,  String exerciseId,  int exerciseOrder,  int setOrder,  SetData data,  bool completed,  Exertion? exertion,  int? restSeconds,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _SessionSet() when $default != null:
return $default(_that.id,_that.sessionId,_that.exerciseId,_that.exerciseOrder,_that.setOrder,_that.data,_that.completed,_that.exertion,_that.restSeconds,_that.note);case _:
  return null;

}
}

}

/// @nodoc


class _SessionSet implements SessionSet {
  const _SessionSet({required this.id, required this.sessionId, required this.exerciseId, required this.exerciseOrder, required this.setOrder, required this.data, required this.completed, this.exertion, this.restSeconds, this.note});
  

@override final  String id;
@override final  String sessionId;
@override final  String exerciseId;
@override final  int exerciseOrder;
@override final  int setOrder;
@override final  SetData data;
@override final  bool completed;
@override final  Exertion? exertion;
@override final  int? restSeconds;
@override final  String? note;

/// Create a copy of SessionSet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SessionSetCopyWith<_SessionSet> get copyWith => __$SessionSetCopyWithImpl<_SessionSet>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SessionSet&&(identical(other.id, id) || other.id == id)&&(identical(other.sessionId, sessionId) || other.sessionId == sessionId)&&(identical(other.exerciseId, exerciseId) || other.exerciseId == exerciseId)&&(identical(other.exerciseOrder, exerciseOrder) || other.exerciseOrder == exerciseOrder)&&(identical(other.setOrder, setOrder) || other.setOrder == setOrder)&&(identical(other.data, data) || other.data == data)&&(identical(other.completed, completed) || other.completed == completed)&&(identical(other.exertion, exertion) || other.exertion == exertion)&&(identical(other.restSeconds, restSeconds) || other.restSeconds == restSeconds)&&(identical(other.note, note) || other.note == note));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,sessionId,exerciseId,exerciseOrder,setOrder,data,completed,exertion,restSeconds,note);
}

@override
String toString() {
    return 'SessionSet(id: $id, sessionId: $sessionId, exerciseId: $exerciseId, exerciseOrder: $exerciseOrder, setOrder: $setOrder, data: $data, completed: $completed, exertion: $exertion, restSeconds: $restSeconds, note: $note)';
}


}

/// @nodoc
abstract mixin class _$SessionSetCopyWith<$Res> implements $SessionSetCopyWith<$Res> {
  factory _$SessionSetCopyWith(_SessionSet value, $Res Function(_SessionSet) _then) = __$SessionSetCopyWithImpl;
@override @useResult
$Res call({
 String id, String sessionId, String exerciseId, int exerciseOrder, int setOrder, SetData data, bool completed, Exertion? exertion, int? restSeconds, String? note
});


@override $SetDataCopyWith<$Res> get data;@override $ExertionCopyWith<$Res>? get exertion;

}
/// @nodoc
class __$SessionSetCopyWithImpl<$Res>
    implements _$SessionSetCopyWith<$Res> {
  __$SessionSetCopyWithImpl(this._self, this._then);

  final _SessionSet _self;
  final $Res Function(_SessionSet) _then;

/// Create a copy of SessionSet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sessionId = null,Object? exerciseId = null,Object? exerciseOrder = null,Object? setOrder = null,Object? data = null,Object? completed = null,Object? exertion = freezed,Object? restSeconds = freezed,Object? note = freezed,}) {
  return _then(_SessionSet(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,sessionId: null == sessionId ? _self.sessionId : sessionId // ignore: cast_nullable_to_non_nullable
as String,exerciseId: null == exerciseId ? _self.exerciseId : exerciseId // ignore: cast_nullable_to_non_nullable
as String,exerciseOrder: null == exerciseOrder ? _self.exerciseOrder : exerciseOrder // ignore: cast_nullable_to_non_nullable
as int,setOrder: null == setOrder ? _self.setOrder : setOrder // ignore: cast_nullable_to_non_nullable
as int,data: null == data ? _self.data : data // ignore: cast_nullable_to_non_nullable
as SetData,completed: null == completed ? _self.completed : completed // ignore: cast_nullable_to_non_nullable
as bool,exertion: freezed == exertion ? _self.exertion : exertion // ignore: cast_nullable_to_non_nullable
as Exertion?,restSeconds: freezed == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of SessionSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SetDataCopyWith<$Res> get data {
  
  return $SetDataCopyWith<$Res>(_self.data, (value) {
    return _then(_self.copyWith(data: value));
  });
}/// Create a copy of SessionSet
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ExertionCopyWith<$Res>? get exertion {
    if (_self.exertion == null) {
    return null;
  }

  return $ExertionCopyWith<$Res>(_self.exertion!, (value) {
    return _then(_self.copyWith(exertion: value));
  });
}
}

/// @nodoc
mixin _$WorkoutSession {

 String get id; String get name; DateTime get startedAt; DateTime get createdAt; DateTime get updatedAt; String? get planId; DateTime? get endedAt; String get notes; List<SessionSet> get sets;
/// Create a copy of WorkoutSession
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutSessionCopyWith<WorkoutSession> get copyWith => _$WorkoutSessionCopyWithImpl<WorkoutSession>(this as WorkoutSession, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkoutSession;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkoutSession&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.planId, _this.planId) || other.planId == _this.planId)&&(identical(other.endedAt, _this.endedAt) || other.endedAt == _this.endedAt)&&(identical(other.notes, _this.notes) || other.notes == _this.notes)&&const DeepCollectionEquality().equals(other.sets, _this.sets));
}


@override
int get hashCode {
  final _this = this as WorkoutSession;
  return Object.hash(runtimeType,_this.id,_this.name,_this.startedAt,_this.createdAt,_this.updatedAt,_this.planId,_this.endedAt,_this.notes,const DeepCollectionEquality().hash(_this.sets));
}

@override
String toString() {
  final _this = this as WorkoutSession;
  return 'WorkoutSession(id: ${_this.id}, name: ${_this.name}, startedAt: ${_this.startedAt}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, planId: ${_this.planId}, endedAt: ${_this.endedAt}, notes: ${_this.notes}, sets: ${_this.sets})';
}


}

/// @nodoc
abstract mixin class $WorkoutSessionCopyWith<$Res>  {
  factory $WorkoutSessionCopyWith(WorkoutSession value, $Res Function(WorkoutSession) _then) = _$WorkoutSessionCopyWithImpl;
@useResult
$Res call({
 String id, String name, DateTime startedAt, DateTime createdAt, DateTime updatedAt, String? planId, DateTime? endedAt, String notes, List<SessionSet> sets
});




}
/// @nodoc
class _$WorkoutSessionCopyWithImpl<$Res>
    implements $WorkoutSessionCopyWith<$Res> {
  _$WorkoutSessionCopyWithImpl(this._self, this._then);

  final WorkoutSession _self;
  final $Res Function(WorkoutSession) _then;

/// Create a copy of WorkoutSession
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? startedAt = null,Object? createdAt = null,Object? updatedAt = null,Object? planId = freezed,Object? endedAt = freezed,Object? notes = null,Object? sets = null,}) {
  return _then(WorkoutSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,planId: freezed == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,sets: null == sets ? _self.sets : sets // ignore: cast_nullable_to_non_nullable
as List<SessionSet>,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkoutSession].
extension WorkoutSessionPatterns on WorkoutSession {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkoutSession value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkoutSession() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkoutSession value)  $default,){
final _that = this;
switch (_that) {
case _WorkoutSession():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkoutSession value)?  $default,){
final _that = this;
switch (_that) {
case _WorkoutSession() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  DateTime startedAt,  DateTime createdAt,  DateTime updatedAt,  String? planId,  DateTime? endedAt,  String notes,  List<SessionSet> sets)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkoutSession() when $default != null:
return $default(_that.id,_that.name,_that.startedAt,_that.createdAt,_that.updatedAt,_that.planId,_that.endedAt,_that.notes,_that.sets);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  DateTime startedAt,  DateTime createdAt,  DateTime updatedAt,  String? planId,  DateTime? endedAt,  String notes,  List<SessionSet> sets)  $default,) {final _that = this;
switch (_that) {
case _WorkoutSession():
return $default(_that.id,_that.name,_that.startedAt,_that.createdAt,_that.updatedAt,_that.planId,_that.endedAt,_that.notes,_that.sets);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  DateTime startedAt,  DateTime createdAt,  DateTime updatedAt,  String? planId,  DateTime? endedAt,  String notes,  List<SessionSet> sets)?  $default,) {final _that = this;
switch (_that) {
case _WorkoutSession() when $default != null:
return $default(_that.id,_that.name,_that.startedAt,_that.createdAt,_that.updatedAt,_that.planId,_that.endedAt,_that.notes,_that.sets);case _:
  return null;

}
}

}

/// @nodoc


class _WorkoutSession implements WorkoutSession {
  const _WorkoutSession({required this.id, required this.name, required this.startedAt, required this.createdAt, required this.updatedAt, this.planId, this.endedAt, this.notes = '',  List<SessionSet> sets = const <SessionSet>[]}): _sets = sets;
  

@override final  String id;
@override final  String name;
@override final  DateTime startedAt;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  String? planId;
@override final  DateTime? endedAt;
@override@JsonKey() final  String notes;
 final  List<SessionSet> _sets;
@override@JsonKey() List<SessionSet> get sets {
  if (_sets is EqualUnmodifiableListView) return _sets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_sets);
}


/// Create a copy of WorkoutSession
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutSessionCopyWith<_WorkoutSession> get copyWith => __$WorkoutSessionCopyWithImpl<_WorkoutSession>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkoutSession&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.planId, planId) || other.planId == planId)&&(identical(other.endedAt, endedAt) || other.endedAt == endedAt)&&(identical(other.notes, notes) || other.notes == notes)&&const DeepCollectionEquality().equals(other.sets, _sets));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,startedAt,createdAt,updatedAt,planId,endedAt,notes,const DeepCollectionEquality().hash(_sets));
}

@override
String toString() {
    return 'WorkoutSession(id: $id, name: $name, startedAt: $startedAt, createdAt: $createdAt, updatedAt: $updatedAt, planId: $planId, endedAt: $endedAt, notes: $notes, sets: $sets)';
}


}

/// @nodoc
abstract mixin class _$WorkoutSessionCopyWith<$Res> implements $WorkoutSessionCopyWith<$Res> {
  factory _$WorkoutSessionCopyWith(_WorkoutSession value, $Res Function(_WorkoutSession) _then) = __$WorkoutSessionCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, DateTime startedAt, DateTime createdAt, DateTime updatedAt, String? planId, DateTime? endedAt, String notes, List<SessionSet> sets
});




}
/// @nodoc
class __$WorkoutSessionCopyWithImpl<$Res>
    implements _$WorkoutSessionCopyWith<$Res> {
  __$WorkoutSessionCopyWithImpl(this._self, this._then);

  final _WorkoutSession _self;
  final $Res Function(_WorkoutSession) _then;

/// Create a copy of WorkoutSession
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? startedAt = null,Object? createdAt = null,Object? updatedAt = null,Object? planId = freezed,Object? endedAt = freezed,Object? notes = null,Object? sets = null,}) {
  return _then(_WorkoutSession(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,planId: freezed == planId ? _self.planId : planId // ignore: cast_nullable_to_non_nullable
as String?,endedAt: freezed == endedAt ? _self.endedAt : endedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,notes: null == notes ? _self.notes : notes // ignore: cast_nullable_to_non_nullable
as String,sets: null == sets ? _self._sets : sets // ignore: cast_nullable_to_non_nullable
as List<SessionSet>,
  ));
}


}

/// @nodoc
mixin _$PlanExercise {

 String get id; String get exerciseId; int get sortOrder; int get targetSets; int? get targetReps; LoadKg? get targetLoad; Duration? get targetDuration; int? get restSeconds;
/// Create a copy of PlanExercise
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PlanExerciseCopyWith<PlanExercise> get copyWith => _$PlanExerciseCopyWithImpl<PlanExercise>(this as PlanExercise, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as PlanExercise;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PlanExercise&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.exerciseId, _this.exerciseId) || other.exerciseId == _this.exerciseId)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.targetSets, _this.targetSets) || other.targetSets == _this.targetSets)&&(identical(other.targetReps, _this.targetReps) || other.targetReps == _this.targetReps)&&(identical(other.targetLoad, _this.targetLoad) || other.targetLoad == _this.targetLoad)&&(identical(other.targetDuration, _this.targetDuration) || other.targetDuration == _this.targetDuration)&&(identical(other.restSeconds, _this.restSeconds) || other.restSeconds == _this.restSeconds));
}


@override
int get hashCode {
  final _this = this as PlanExercise;
  return Object.hash(runtimeType,_this.id,_this.exerciseId,_this.sortOrder,_this.targetSets,_this.targetReps,_this.targetLoad,_this.targetDuration,_this.restSeconds);
}

@override
String toString() {
  final _this = this as PlanExercise;
  return 'PlanExercise(id: ${_this.id}, exerciseId: ${_this.exerciseId}, sortOrder: ${_this.sortOrder}, targetSets: ${_this.targetSets}, targetReps: ${_this.targetReps}, targetLoad: ${_this.targetLoad}, targetDuration: ${_this.targetDuration}, restSeconds: ${_this.restSeconds})';
}


}

/// @nodoc
abstract mixin class $PlanExerciseCopyWith<$Res>  {
  factory $PlanExerciseCopyWith(PlanExercise value, $Res Function(PlanExercise) _then) = _$PlanExerciseCopyWithImpl;
@useResult
$Res call({
 String id, String exerciseId, int sortOrder, int targetSets, int? targetReps, LoadKg? targetLoad, Duration? targetDuration, int? restSeconds
});




}
/// @nodoc
class _$PlanExerciseCopyWithImpl<$Res>
    implements $PlanExerciseCopyWith<$Res> {
  _$PlanExerciseCopyWithImpl(this._self, this._then);

  final PlanExercise _self;
  final $Res Function(PlanExercise) _then;

/// Create a copy of PlanExercise
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? exerciseId = null,Object? sortOrder = null,Object? targetSets = null,Object? targetReps = freezed,Object? targetLoad = freezed,Object? targetDuration = freezed,Object? restSeconds = freezed,}) {
  return _then(PlanExercise(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,exerciseId: null == exerciseId ? _self.exerciseId : exerciseId // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,targetSets: null == targetSets ? _self.targetSets : targetSets // ignore: cast_nullable_to_non_nullable
as int,targetReps: freezed == targetReps ? _self.targetReps : targetReps // ignore: cast_nullable_to_non_nullable
as int?,targetLoad: freezed == targetLoad ? _self.targetLoad : targetLoad // ignore: cast_nullable_to_non_nullable
as LoadKg?,targetDuration: freezed == targetDuration ? _self.targetDuration : targetDuration // ignore: cast_nullable_to_non_nullable
as Duration?,restSeconds: freezed == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [PlanExercise].
extension PlanExercisePatterns on PlanExercise {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PlanExercise value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PlanExercise() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PlanExercise value)  $default,){
final _that = this;
switch (_that) {
case _PlanExercise():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PlanExercise value)?  $default,){
final _that = this;
switch (_that) {
case _PlanExercise() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String exerciseId,  int sortOrder,  int targetSets,  int? targetReps,  LoadKg? targetLoad,  Duration? targetDuration,  int? restSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PlanExercise() when $default != null:
return $default(_that.id,_that.exerciseId,_that.sortOrder,_that.targetSets,_that.targetReps,_that.targetLoad,_that.targetDuration,_that.restSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String exerciseId,  int sortOrder,  int targetSets,  int? targetReps,  LoadKg? targetLoad,  Duration? targetDuration,  int? restSeconds)  $default,) {final _that = this;
switch (_that) {
case _PlanExercise():
return $default(_that.id,_that.exerciseId,_that.sortOrder,_that.targetSets,_that.targetReps,_that.targetLoad,_that.targetDuration,_that.restSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String exerciseId,  int sortOrder,  int targetSets,  int? targetReps,  LoadKg? targetLoad,  Duration? targetDuration,  int? restSeconds)?  $default,) {final _that = this;
switch (_that) {
case _PlanExercise() when $default != null:
return $default(_that.id,_that.exerciseId,_that.sortOrder,_that.targetSets,_that.targetReps,_that.targetLoad,_that.targetDuration,_that.restSeconds);case _:
  return null;

}
}

}

/// @nodoc


class _PlanExercise implements PlanExercise {
  const _PlanExercise({required this.id, required this.exerciseId, required this.sortOrder, required this.targetSets, this.targetReps, this.targetLoad, this.targetDuration, this.restSeconds});
  

@override final  String id;
@override final  String exerciseId;
@override final  int sortOrder;
@override final  int targetSets;
@override final  int? targetReps;
@override final  LoadKg? targetLoad;
@override final  Duration? targetDuration;
@override final  int? restSeconds;

/// Create a copy of PlanExercise
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PlanExerciseCopyWith<_PlanExercise> get copyWith => __$PlanExerciseCopyWithImpl<_PlanExercise>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _PlanExercise&&(identical(other.id, id) || other.id == id)&&(identical(other.exerciseId, exerciseId) || other.exerciseId == exerciseId)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.targetSets, targetSets) || other.targetSets == targetSets)&&(identical(other.targetReps, targetReps) || other.targetReps == targetReps)&&(identical(other.targetLoad, targetLoad) || other.targetLoad == targetLoad)&&(identical(other.targetDuration, targetDuration) || other.targetDuration == targetDuration)&&(identical(other.restSeconds, restSeconds) || other.restSeconds == restSeconds));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,exerciseId,sortOrder,targetSets,targetReps,targetLoad,targetDuration,restSeconds);
}

@override
String toString() {
    return 'PlanExercise(id: $id, exerciseId: $exerciseId, sortOrder: $sortOrder, targetSets: $targetSets, targetReps: $targetReps, targetLoad: $targetLoad, targetDuration: $targetDuration, restSeconds: $restSeconds)';
}


}

/// @nodoc
abstract mixin class _$PlanExerciseCopyWith<$Res> implements $PlanExerciseCopyWith<$Res> {
  factory _$PlanExerciseCopyWith(_PlanExercise value, $Res Function(_PlanExercise) _then) = __$PlanExerciseCopyWithImpl;
@override @useResult
$Res call({
 String id, String exerciseId, int sortOrder, int targetSets, int? targetReps, LoadKg? targetLoad, Duration? targetDuration, int? restSeconds
});




}
/// @nodoc
class __$PlanExerciseCopyWithImpl<$Res>
    implements _$PlanExerciseCopyWith<$Res> {
  __$PlanExerciseCopyWithImpl(this._self, this._then);

  final _PlanExercise _self;
  final $Res Function(_PlanExercise) _then;

/// Create a copy of PlanExercise
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? exerciseId = null,Object? sortOrder = null,Object? targetSets = null,Object? targetReps = freezed,Object? targetLoad = freezed,Object? targetDuration = freezed,Object? restSeconds = freezed,}) {
  return _then(_PlanExercise(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,exerciseId: null == exerciseId ? _self.exerciseId : exerciseId // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,targetSets: null == targetSets ? _self.targetSets : targetSets // ignore: cast_nullable_to_non_nullable
as int,targetReps: freezed == targetReps ? _self.targetReps : targetReps // ignore: cast_nullable_to_non_nullable
as int?,targetLoad: freezed == targetLoad ? _self.targetLoad : targetLoad // ignore: cast_nullable_to_non_nullable
as LoadKg?,targetDuration: freezed == targetDuration ? _self.targetDuration : targetDuration // ignore: cast_nullable_to_non_nullable
as Duration?,restSeconds: freezed == restSeconds ? _self.restSeconds : restSeconds // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

/// @nodoc
mixin _$WorkoutPlan {

 String get id; String get name; DateTime get createdAt; DateTime get updatedAt; String? get split; List<int> get scheduledWeekdays; List<PlanExercise> get exercises; bool get archived;
/// Create a copy of WorkoutPlan
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WorkoutPlanCopyWith<WorkoutPlan> get copyWith => _$WorkoutPlanCopyWithImpl<WorkoutPlan>(this as WorkoutPlan, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as WorkoutPlan;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is WorkoutPlan&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.split, _this.split) || other.split == _this.split)&&const DeepCollectionEquality().equals(other.scheduledWeekdays, _this.scheduledWeekdays)&&const DeepCollectionEquality().equals(other.exercises, _this.exercises)&&(identical(other.archived, _this.archived) || other.archived == _this.archived));
}


@override
int get hashCode {
  final _this = this as WorkoutPlan;
  return Object.hash(runtimeType,_this.id,_this.name,_this.createdAt,_this.updatedAt,_this.split,const DeepCollectionEquality().hash(_this.scheduledWeekdays),const DeepCollectionEquality().hash(_this.exercises),_this.archived);
}

@override
String toString() {
  final _this = this as WorkoutPlan;
  return 'WorkoutPlan(id: ${_this.id}, name: ${_this.name}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, split: ${_this.split}, scheduledWeekdays: ${_this.scheduledWeekdays}, exercises: ${_this.exercises}, archived: ${_this.archived})';
}


}

/// @nodoc
abstract mixin class $WorkoutPlanCopyWith<$Res>  {
  factory $WorkoutPlanCopyWith(WorkoutPlan value, $Res Function(WorkoutPlan) _then) = _$WorkoutPlanCopyWithImpl;
@useResult
$Res call({
 String id, String name, DateTime createdAt, DateTime updatedAt, String? split, List<int> scheduledWeekdays, List<PlanExercise> exercises, bool archived
});




}
/// @nodoc
class _$WorkoutPlanCopyWithImpl<$Res>
    implements $WorkoutPlanCopyWith<$Res> {
  _$WorkoutPlanCopyWithImpl(this._self, this._then);

  final WorkoutPlan _self;
  final $Res Function(WorkoutPlan) _then;

/// Create a copy of WorkoutPlan
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? createdAt = null,Object? updatedAt = null,Object? split = freezed,Object? scheduledWeekdays = null,Object? exercises = null,Object? archived = null,}) {
  return _then(WorkoutPlan(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,split: freezed == split ? _self.split : split // ignore: cast_nullable_to_non_nullable
as String?,scheduledWeekdays: null == scheduledWeekdays ? _self.scheduledWeekdays : scheduledWeekdays // ignore: cast_nullable_to_non_nullable
as List<int>,exercises: null == exercises ? _self.exercises : exercises // ignore: cast_nullable_to_non_nullable
as List<PlanExercise>,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [WorkoutPlan].
extension WorkoutPlanPatterns on WorkoutPlan {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _WorkoutPlan value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _WorkoutPlan() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _WorkoutPlan value)  $default,){
final _that = this;
switch (_that) {
case _WorkoutPlan():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _WorkoutPlan value)?  $default,){
final _that = this;
switch (_that) {
case _WorkoutPlan() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  DateTime createdAt,  DateTime updatedAt,  String? split,  List<int> scheduledWeekdays,  List<PlanExercise> exercises,  bool archived)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _WorkoutPlan() when $default != null:
return $default(_that.id,_that.name,_that.createdAt,_that.updatedAt,_that.split,_that.scheduledWeekdays,_that.exercises,_that.archived);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  DateTime createdAt,  DateTime updatedAt,  String? split,  List<int> scheduledWeekdays,  List<PlanExercise> exercises,  bool archived)  $default,) {final _that = this;
switch (_that) {
case _WorkoutPlan():
return $default(_that.id,_that.name,_that.createdAt,_that.updatedAt,_that.split,_that.scheduledWeekdays,_that.exercises,_that.archived);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  DateTime createdAt,  DateTime updatedAt,  String? split,  List<int> scheduledWeekdays,  List<PlanExercise> exercises,  bool archived)?  $default,) {final _that = this;
switch (_that) {
case _WorkoutPlan() when $default != null:
return $default(_that.id,_that.name,_that.createdAt,_that.updatedAt,_that.split,_that.scheduledWeekdays,_that.exercises,_that.archived);case _:
  return null;

}
}

}

/// @nodoc


class _WorkoutPlan implements WorkoutPlan {
  const _WorkoutPlan({required this.id, required this.name, required this.createdAt, required this.updatedAt, this.split,  List<int> scheduledWeekdays = const <int>[],  List<PlanExercise> exercises = const <PlanExercise>[], this.archived = false}): _scheduledWeekdays = scheduledWeekdays,_exercises = exercises;
  

@override final  String id;
@override final  String name;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  String? split;
 final  List<int> _scheduledWeekdays;
@override@JsonKey() List<int> get scheduledWeekdays {
  if (_scheduledWeekdays is EqualUnmodifiableListView) return _scheduledWeekdays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_scheduledWeekdays);
}

 final  List<PlanExercise> _exercises;
@override@JsonKey() List<PlanExercise> get exercises {
  if (_exercises is EqualUnmodifiableListView) return _exercises;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_exercises);
}

@override@JsonKey() final  bool archived;

/// Create a copy of WorkoutPlan
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$WorkoutPlanCopyWith<_WorkoutPlan> get copyWith => __$WorkoutPlanCopyWithImpl<_WorkoutPlan>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _WorkoutPlan&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.split, split) || other.split == split)&&const DeepCollectionEquality().equals(other.scheduledWeekdays, _scheduledWeekdays)&&const DeepCollectionEquality().equals(other.exercises, _exercises)&&(identical(other.archived, archived) || other.archived == archived));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,createdAt,updatedAt,split,const DeepCollectionEquality().hash(_scheduledWeekdays),const DeepCollectionEquality().hash(_exercises),archived);
}

@override
String toString() {
    return 'WorkoutPlan(id: $id, name: $name, createdAt: $createdAt, updatedAt: $updatedAt, split: $split, scheduledWeekdays: $scheduledWeekdays, exercises: $exercises, archived: $archived)';
}


}

/// @nodoc
abstract mixin class _$WorkoutPlanCopyWith<$Res> implements $WorkoutPlanCopyWith<$Res> {
  factory _$WorkoutPlanCopyWith(_WorkoutPlan value, $Res Function(_WorkoutPlan) _then) = __$WorkoutPlanCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, DateTime createdAt, DateTime updatedAt, String? split, List<int> scheduledWeekdays, List<PlanExercise> exercises, bool archived
});




}
/// @nodoc
class __$WorkoutPlanCopyWithImpl<$Res>
    implements _$WorkoutPlanCopyWith<$Res> {
  __$WorkoutPlanCopyWithImpl(this._self, this._then);

  final _WorkoutPlan _self;
  final $Res Function(_WorkoutPlan) _then;

/// Create a copy of WorkoutPlan
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? createdAt = null,Object? updatedAt = null,Object? split = freezed,Object? scheduledWeekdays = null,Object? exercises = null,Object? archived = null,}) {
  return _then(_WorkoutPlan(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,split: freezed == split ? _self.split : split // ignore: cast_nullable_to_non_nullable
as String?,scheduledWeekdays: null == scheduledWeekdays ? _self._scheduledWeekdays : scheduledWeekdays // ignore: cast_nullable_to_non_nullable
as List<int>,exercises: null == exercises ? _self._exercises : exercises // ignore: cast_nullable_to_non_nullable
as List<PlanExercise>,archived: null == archived ? _self.archived : archived // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
