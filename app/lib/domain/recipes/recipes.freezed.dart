// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recipes.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RecipeSubstitute {

 String get name; Quantity get quantity; NutrientProfile get per100; String? get foodId;
/// Create a copy of RecipeSubstitute
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecipeSubstituteCopyWith<RecipeSubstitute> get copyWith => _$RecipeSubstituteCopyWithImpl<RecipeSubstitute>(this as RecipeSubstitute, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RecipeSubstitute;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecipeSubstitute&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity)&&(identical(other.per100, _this.per100) || other.per100 == _this.per100)&&(identical(other.foodId, _this.foodId) || other.foodId == _this.foodId));
}


@override
int get hashCode {
  final _this = this as RecipeSubstitute;
  return Object.hash(runtimeType,_this.name,_this.quantity,_this.per100,_this.foodId);
}

@override
String toString() {
  final _this = this as RecipeSubstitute;
  return 'RecipeSubstitute(name: ${_this.name}, quantity: ${_this.quantity}, per100: ${_this.per100}, foodId: ${_this.foodId})';
}


}

/// @nodoc
abstract mixin class $RecipeSubstituteCopyWith<$Res>  {
  factory $RecipeSubstituteCopyWith(RecipeSubstitute value, $Res Function(RecipeSubstitute) _then) = _$RecipeSubstituteCopyWithImpl;
@useResult
$Res call({
 String name, Quantity quantity, NutrientProfile per100, String? foodId
});


$NutrientProfileCopyWith<$Res> get per100;

}
/// @nodoc
class _$RecipeSubstituteCopyWithImpl<$Res>
    implements $RecipeSubstituteCopyWith<$Res> {
  _$RecipeSubstituteCopyWithImpl(this._self, this._then);

  final RecipeSubstitute _self;
  final $Res Function(RecipeSubstitute) _then;

/// Create a copy of RecipeSubstitute
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? quantity = null,Object? per100 = null,Object? foodId = freezed,}) {
  return _then(RecipeSubstitute(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Quantity,per100: null == per100 ? _self.per100 : per100 // ignore: cast_nullable_to_non_nullable
as NutrientProfile,foodId: freezed == foodId ? _self.foodId : foodId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of RecipeSubstitute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientProfileCopyWith<$Res> get per100 {
  
  return $NutrientProfileCopyWith<$Res>(_self.per100, (value) {
    return _then(_self.copyWith(per100: value));
  });
}
}


/// Adds pattern-matching-related methods to [RecipeSubstitute].
extension RecipeSubstitutePatterns on RecipeSubstitute {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecipeSubstitute value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecipeSubstitute() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecipeSubstitute value)  $default,){
final _that = this;
switch (_that) {
case _RecipeSubstitute():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecipeSubstitute value)?  $default,){
final _that = this;
switch (_that) {
case _RecipeSubstitute() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  Quantity quantity,  NutrientProfile per100,  String? foodId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecipeSubstitute() when $default != null:
return $default(_that.name,_that.quantity,_that.per100,_that.foodId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  Quantity quantity,  NutrientProfile per100,  String? foodId)  $default,) {final _that = this;
switch (_that) {
case _RecipeSubstitute():
return $default(_that.name,_that.quantity,_that.per100,_that.foodId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  Quantity quantity,  NutrientProfile per100,  String? foodId)?  $default,) {final _that = this;
switch (_that) {
case _RecipeSubstitute() when $default != null:
return $default(_that.name,_that.quantity,_that.per100,_that.foodId);case _:
  return null;

}
}

}

/// @nodoc


class _RecipeSubstitute extends RecipeSubstitute {
  const _RecipeSubstitute({required this.name, required this.quantity, required this.per100, this.foodId}): super._();
  

@override final  String name;
@override final  Quantity quantity;
@override final  NutrientProfile per100;
@override final  String? foodId;

/// Create a copy of RecipeSubstitute
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecipeSubstituteCopyWith<_RecipeSubstitute> get copyWith => __$RecipeSubstituteCopyWithImpl<_RecipeSubstitute>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecipeSubstitute&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.per100, per100) || other.per100 == per100)&&(identical(other.foodId, foodId) || other.foodId == foodId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,name,quantity,per100,foodId);
}

@override
String toString() {
    return 'RecipeSubstitute(name: $name, quantity: $quantity, per100: $per100, foodId: $foodId)';
}


}

/// @nodoc
abstract mixin class _$RecipeSubstituteCopyWith<$Res> implements $RecipeSubstituteCopyWith<$Res> {
  factory _$RecipeSubstituteCopyWith(_RecipeSubstitute value, $Res Function(_RecipeSubstitute) _then) = __$RecipeSubstituteCopyWithImpl;
@override @useResult
$Res call({
 String name, Quantity quantity, NutrientProfile per100, String? foodId
});


@override $NutrientProfileCopyWith<$Res> get per100;

}
/// @nodoc
class __$RecipeSubstituteCopyWithImpl<$Res>
    implements _$RecipeSubstituteCopyWith<$Res> {
  __$RecipeSubstituteCopyWithImpl(this._self, this._then);

  final _RecipeSubstitute _self;
  final $Res Function(_RecipeSubstitute) _then;

/// Create a copy of RecipeSubstitute
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? quantity = null,Object? per100 = null,Object? foodId = freezed,}) {
  return _then(_RecipeSubstitute(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Quantity,per100: null == per100 ? _self.per100 : per100 // ignore: cast_nullable_to_non_nullable
as NutrientProfile,foodId: freezed == foodId ? _self.foodId : foodId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of RecipeSubstitute
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientProfileCopyWith<$Res> get per100 {
  
  return $NutrientProfileCopyWith<$Res>(_self.per100, (value) {
    return _then(_self.copyWith(per100: value));
  });
}
}

/// @nodoc
mixin _$RecipeIngredient {

 String get id; String get name; Quantity get quantity; int get sortOrder; String? get foodId; NutrientProfile? get per100; String? get note; String? get servingLabel; double? get servingCount; List<RecipeSubstitute> get substitutes;
/// Create a copy of RecipeIngredient
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecipeIngredientCopyWith<RecipeIngredient> get copyWith => _$RecipeIngredientCopyWithImpl<RecipeIngredient>(this as RecipeIngredient, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RecipeIngredient;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecipeIngredient&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.foodId, _this.foodId) || other.foodId == _this.foodId)&&(identical(other.per100, _this.per100) || other.per100 == _this.per100)&&(identical(other.note, _this.note) || other.note == _this.note)&&(identical(other.servingLabel, _this.servingLabel) || other.servingLabel == _this.servingLabel)&&(identical(other.servingCount, _this.servingCount) || other.servingCount == _this.servingCount)&&const DeepCollectionEquality().equals(other.substitutes, _this.substitutes));
}


@override
int get hashCode {
  final _this = this as RecipeIngredient;
  return Object.hash(runtimeType,_this.id,_this.name,_this.quantity,_this.sortOrder,_this.foodId,_this.per100,_this.note,_this.servingLabel,_this.servingCount,const DeepCollectionEquality().hash(_this.substitutes));
}

@override
String toString() {
  final _this = this as RecipeIngredient;
  return 'RecipeIngredient(id: ${_this.id}, name: ${_this.name}, quantity: ${_this.quantity}, sortOrder: ${_this.sortOrder}, foodId: ${_this.foodId}, per100: ${_this.per100}, note: ${_this.note}, servingLabel: ${_this.servingLabel}, servingCount: ${_this.servingCount}, substitutes: ${_this.substitutes})';
}


}

/// @nodoc
abstract mixin class $RecipeIngredientCopyWith<$Res>  {
  factory $RecipeIngredientCopyWith(RecipeIngredient value, $Res Function(RecipeIngredient) _then) = _$RecipeIngredientCopyWithImpl;
@useResult
$Res call({
 String id, String name, Quantity quantity, int sortOrder, String? foodId, NutrientProfile? per100, String? note, String? servingLabel, double? servingCount, List<RecipeSubstitute> substitutes
});


$NutrientProfileCopyWith<$Res>? get per100;

}
/// @nodoc
class _$RecipeIngredientCopyWithImpl<$Res>
    implements $RecipeIngredientCopyWith<$Res> {
  _$RecipeIngredientCopyWithImpl(this._self, this._then);

  final RecipeIngredient _self;
  final $Res Function(RecipeIngredient) _then;

/// Create a copy of RecipeIngredient
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? quantity = null,Object? sortOrder = null,Object? foodId = freezed,Object? per100 = freezed,Object? note = freezed,Object? servingLabel = freezed,Object? servingCount = freezed,Object? substitutes = null,}) {
  return _then(RecipeIngredient(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Quantity,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,foodId: freezed == foodId ? _self.foodId : foodId // ignore: cast_nullable_to_non_nullable
as String?,per100: freezed == per100 ? _self.per100 : per100 // ignore: cast_nullable_to_non_nullable
as NutrientProfile?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,servingLabel: freezed == servingLabel ? _self.servingLabel : servingLabel // ignore: cast_nullable_to_non_nullable
as String?,servingCount: freezed == servingCount ? _self.servingCount : servingCount // ignore: cast_nullable_to_non_nullable
as double?,substitutes: null == substitutes ? _self.substitutes : substitutes // ignore: cast_nullable_to_non_nullable
as List<RecipeSubstitute>,
  ));
}
/// Create a copy of RecipeIngredient
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientProfileCopyWith<$Res>? get per100 {
    if (_self.per100 == null) {
    return null;
  }

  return $NutrientProfileCopyWith<$Res>(_self.per100!, (value) {
    return _then(_self.copyWith(per100: value));
  });
}
}


/// Adds pattern-matching-related methods to [RecipeIngredient].
extension RecipeIngredientPatterns on RecipeIngredient {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecipeIngredient value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecipeIngredient() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecipeIngredient value)  $default,){
final _that = this;
switch (_that) {
case _RecipeIngredient():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecipeIngredient value)?  $default,){
final _that = this;
switch (_that) {
case _RecipeIngredient() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  Quantity quantity,  int sortOrder,  String? foodId,  NutrientProfile? per100,  String? note,  String? servingLabel,  double? servingCount,  List<RecipeSubstitute> substitutes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecipeIngredient() when $default != null:
return $default(_that.id,_that.name,_that.quantity,_that.sortOrder,_that.foodId,_that.per100,_that.note,_that.servingLabel,_that.servingCount,_that.substitutes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  Quantity quantity,  int sortOrder,  String? foodId,  NutrientProfile? per100,  String? note,  String? servingLabel,  double? servingCount,  List<RecipeSubstitute> substitutes)  $default,) {final _that = this;
switch (_that) {
case _RecipeIngredient():
return $default(_that.id,_that.name,_that.quantity,_that.sortOrder,_that.foodId,_that.per100,_that.note,_that.servingLabel,_that.servingCount,_that.substitutes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  Quantity quantity,  int sortOrder,  String? foodId,  NutrientProfile? per100,  String? note,  String? servingLabel,  double? servingCount,  List<RecipeSubstitute> substitutes)?  $default,) {final _that = this;
switch (_that) {
case _RecipeIngredient() when $default != null:
return $default(_that.id,_that.name,_that.quantity,_that.sortOrder,_that.foodId,_that.per100,_that.note,_that.servingLabel,_that.servingCount,_that.substitutes);case _:
  return null;

}
}

}

/// @nodoc


class _RecipeIngredient extends RecipeIngredient {
  const _RecipeIngredient({required this.id, required this.name, required this.quantity, required this.sortOrder, this.foodId, this.per100, this.note, this.servingLabel, this.servingCount,  List<RecipeSubstitute> substitutes = const <RecipeSubstitute>[]}): _substitutes = substitutes,super._();
  

@override final  String id;
@override final  String name;
@override final  Quantity quantity;
@override final  int sortOrder;
@override final  String? foodId;
@override final  NutrientProfile? per100;
@override final  String? note;
@override final  String? servingLabel;
@override final  double? servingCount;
 final  List<RecipeSubstitute> _substitutes;
@override@JsonKey() List<RecipeSubstitute> get substitutes {
  if (_substitutes is EqualUnmodifiableListView) return _substitutes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_substitutes);
}


/// Create a copy of RecipeIngredient
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecipeIngredientCopyWith<_RecipeIngredient> get copyWith => __$RecipeIngredientCopyWithImpl<_RecipeIngredient>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecipeIngredient&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.foodId, foodId) || other.foodId == foodId)&&(identical(other.per100, per100) || other.per100 == per100)&&(identical(other.note, note) || other.note == note)&&(identical(other.servingLabel, servingLabel) || other.servingLabel == servingLabel)&&(identical(other.servingCount, servingCount) || other.servingCount == servingCount)&&const DeepCollectionEquality().equals(other.substitutes, _substitutes));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,quantity,sortOrder,foodId,per100,note,servingLabel,servingCount,const DeepCollectionEquality().hash(_substitutes));
}

@override
String toString() {
    return 'RecipeIngredient(id: $id, name: $name, quantity: $quantity, sortOrder: $sortOrder, foodId: $foodId, per100: $per100, note: $note, servingLabel: $servingLabel, servingCount: $servingCount, substitutes: $substitutes)';
}


}

/// @nodoc
abstract mixin class _$RecipeIngredientCopyWith<$Res> implements $RecipeIngredientCopyWith<$Res> {
  factory _$RecipeIngredientCopyWith(_RecipeIngredient value, $Res Function(_RecipeIngredient) _then) = __$RecipeIngredientCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, Quantity quantity, int sortOrder, String? foodId, NutrientProfile? per100, String? note, String? servingLabel, double? servingCount, List<RecipeSubstitute> substitutes
});


@override $NutrientProfileCopyWith<$Res>? get per100;

}
/// @nodoc
class __$RecipeIngredientCopyWithImpl<$Res>
    implements _$RecipeIngredientCopyWith<$Res> {
  __$RecipeIngredientCopyWithImpl(this._self, this._then);

  final _RecipeIngredient _self;
  final $Res Function(_RecipeIngredient) _then;

/// Create a copy of RecipeIngredient
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? quantity = null,Object? sortOrder = null,Object? foodId = freezed,Object? per100 = freezed,Object? note = freezed,Object? servingLabel = freezed,Object? servingCount = freezed,Object? substitutes = null,}) {
  return _then(_RecipeIngredient(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Quantity,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,foodId: freezed == foodId ? _self.foodId : foodId // ignore: cast_nullable_to_non_nullable
as String?,per100: freezed == per100 ? _self.per100 : per100 // ignore: cast_nullable_to_non_nullable
as NutrientProfile?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,servingLabel: freezed == servingLabel ? _self.servingLabel : servingLabel // ignore: cast_nullable_to_non_nullable
as String?,servingCount: freezed == servingCount ? _self.servingCount : servingCount // ignore: cast_nullable_to_non_nullable
as double?,substitutes: null == substitutes ? _self._substitutes : substitutes // ignore: cast_nullable_to_non_nullable
as List<RecipeSubstitute>,
  ));
}

/// Create a copy of RecipeIngredient
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientProfileCopyWith<$Res>? get per100 {
    if (_self.per100 == null) {
    return null;
  }

  return $NutrientProfileCopyWith<$Res>(_self.per100!, (value) {
    return _then(_self.copyWith(per100: value));
  });
}
}

/// @nodoc
mixin _$Recipe {

 String get id; String get name; String get category;/// Number of portions the recipe makes (greater than 0; a user save needs
/// 1 or more, RCP-001). Fractional when derived from weights (RCP-008).
 double get portions; List<RecipeIngredient> get ingredients; DateTime get createdAt; DateTime get updatedAt; String get description;/// Ordered preparation instructions (RCP-003).
 List<String> get prepSteps;/// Ordered cooking instructions (RCP-003).
 List<String> get cookSteps; int? get prepMinutes; int? get cookMinutes; String? get storage; FreezingSuitability get freezing; String? get reheating; bool get favourite;/// Cooked yield W in grams as entered by the user (RCP-008(2)).
 double? get totalWeightG;/// Weight w of one portion in grams (RCP-008(2)).
 double? get portionWeightG; NutrientAmounts? get declaredPerPortion; String? get nutritionNote;/// Free-text ingredient lines of an imported recipe. Never calculated.
 List<String> get ingredientNotes;
/// Create a copy of Recipe
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecipeCopyWith<Recipe> get copyWith => _$RecipeCopyWithImpl<Recipe>(this as Recipe, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Recipe;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Recipe&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.portions, _this.portions) || other.portions == _this.portions)&&const DeepCollectionEquality().equals(other.ingredients, _this.ingredients)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.description, _this.description) || other.description == _this.description)&&const DeepCollectionEquality().equals(other.prepSteps, _this.prepSteps)&&const DeepCollectionEquality().equals(other.cookSteps, _this.cookSteps)&&(identical(other.prepMinutes, _this.prepMinutes) || other.prepMinutes == _this.prepMinutes)&&(identical(other.cookMinutes, _this.cookMinutes) || other.cookMinutes == _this.cookMinutes)&&(identical(other.storage, _this.storage) || other.storage == _this.storage)&&(identical(other.freezing, _this.freezing) || other.freezing == _this.freezing)&&(identical(other.reheating, _this.reheating) || other.reheating == _this.reheating)&&(identical(other.favourite, _this.favourite) || other.favourite == _this.favourite)&&(identical(other.totalWeightG, _this.totalWeightG) || other.totalWeightG == _this.totalWeightG)&&(identical(other.portionWeightG, _this.portionWeightG) || other.portionWeightG == _this.portionWeightG)&&(identical(other.declaredPerPortion, _this.declaredPerPortion) || other.declaredPerPortion == _this.declaredPerPortion)&&(identical(other.nutritionNote, _this.nutritionNote) || other.nutritionNote == _this.nutritionNote)&&const DeepCollectionEquality().equals(other.ingredientNotes, _this.ingredientNotes));
}


@override
int get hashCode {
  final _this = this as Recipe;
  return Object.hashAll([runtimeType,_this.id,_this.name,_this.category,_this.portions,const DeepCollectionEquality().hash(_this.ingredients),_this.createdAt,_this.updatedAt,_this.description,const DeepCollectionEquality().hash(_this.prepSteps),const DeepCollectionEquality().hash(_this.cookSteps),_this.prepMinutes,_this.cookMinutes,_this.storage,_this.freezing,_this.reheating,_this.favourite,_this.totalWeightG,_this.portionWeightG,_this.declaredPerPortion,_this.nutritionNote,const DeepCollectionEquality().hash(_this.ingredientNotes)]);
}

@override
String toString() {
  final _this = this as Recipe;
  return 'Recipe(id: ${_this.id}, name: ${_this.name}, category: ${_this.category}, portions: ${_this.portions}, ingredients: ${_this.ingredients}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, description: ${_this.description}, prepSteps: ${_this.prepSteps}, cookSteps: ${_this.cookSteps}, prepMinutes: ${_this.prepMinutes}, cookMinutes: ${_this.cookMinutes}, storage: ${_this.storage}, freezing: ${_this.freezing}, reheating: ${_this.reheating}, favourite: ${_this.favourite}, totalWeightG: ${_this.totalWeightG}, portionWeightG: ${_this.portionWeightG}, declaredPerPortion: ${_this.declaredPerPortion}, nutritionNote: ${_this.nutritionNote}, ingredientNotes: ${_this.ingredientNotes})';
}


}

/// @nodoc
abstract mixin class $RecipeCopyWith<$Res>  {
  factory $RecipeCopyWith(Recipe value, $Res Function(Recipe) _then) = _$RecipeCopyWithImpl;
@useResult
$Res call({
 String id, String name, String category, double portions, List<RecipeIngredient> ingredients, DateTime createdAt, DateTime updatedAt, String description, List<String> prepSteps, List<String> cookSteps, int? prepMinutes, int? cookMinutes, String? storage, FreezingSuitability freezing, String? reheating, bool favourite, double? totalWeightG, double? portionWeightG, NutrientAmounts? declaredPerPortion, String? nutritionNote, List<String> ingredientNotes
});


$NutrientAmountsCopyWith<$Res>? get declaredPerPortion;

}
/// @nodoc
class _$RecipeCopyWithImpl<$Res>
    implements $RecipeCopyWith<$Res> {
  _$RecipeCopyWithImpl(this._self, this._then);

  final Recipe _self;
  final $Res Function(Recipe) _then;

/// Create a copy of Recipe
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? category = null,Object? portions = null,Object? ingredients = null,Object? createdAt = null,Object? updatedAt = null,Object? description = null,Object? prepSteps = null,Object? cookSteps = null,Object? prepMinutes = freezed,Object? cookMinutes = freezed,Object? storage = freezed,Object? freezing = null,Object? reheating = freezed,Object? favourite = null,Object? totalWeightG = freezed,Object? portionWeightG = freezed,Object? declaredPerPortion = freezed,Object? nutritionNote = freezed,Object? ingredientNotes = null,}) {
  return _then(Recipe(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,portions: null == portions ? _self.portions : portions // ignore: cast_nullable_to_non_nullable
as double,ingredients: null == ingredients ? _self.ingredients : ingredients // ignore: cast_nullable_to_non_nullable
as List<RecipeIngredient>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,prepSteps: null == prepSteps ? _self.prepSteps : prepSteps // ignore: cast_nullable_to_non_nullable
as List<String>,cookSteps: null == cookSteps ? _self.cookSteps : cookSteps // ignore: cast_nullable_to_non_nullable
as List<String>,prepMinutes: freezed == prepMinutes ? _self.prepMinutes : prepMinutes // ignore: cast_nullable_to_non_nullable
as int?,cookMinutes: freezed == cookMinutes ? _self.cookMinutes : cookMinutes // ignore: cast_nullable_to_non_nullable
as int?,storage: freezed == storage ? _self.storage : storage // ignore: cast_nullable_to_non_nullable
as String?,freezing: null == freezing ? _self.freezing : freezing // ignore: cast_nullable_to_non_nullable
as FreezingSuitability,reheating: freezed == reheating ? _self.reheating : reheating // ignore: cast_nullable_to_non_nullable
as String?,favourite: null == favourite ? _self.favourite : favourite // ignore: cast_nullable_to_non_nullable
as bool,totalWeightG: freezed == totalWeightG ? _self.totalWeightG : totalWeightG // ignore: cast_nullable_to_non_nullable
as double?,portionWeightG: freezed == portionWeightG ? _self.portionWeightG : portionWeightG // ignore: cast_nullable_to_non_nullable
as double?,declaredPerPortion: freezed == declaredPerPortion ? _self.declaredPerPortion : declaredPerPortion // ignore: cast_nullable_to_non_nullable
as NutrientAmounts?,nutritionNote: freezed == nutritionNote ? _self.nutritionNote : nutritionNote // ignore: cast_nullable_to_non_nullable
as String?,ingredientNotes: null == ingredientNotes ? _self.ingredientNotes : ingredientNotes // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}
/// Create a copy of Recipe
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientAmountsCopyWith<$Res>? get declaredPerPortion {
    if (_self.declaredPerPortion == null) {
    return null;
  }

  return $NutrientAmountsCopyWith<$Res>(_self.declaredPerPortion!, (value) {
    return _then(_self.copyWith(declaredPerPortion: value));
  });
}
}


/// Adds pattern-matching-related methods to [Recipe].
extension RecipePatterns on Recipe {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Recipe value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Recipe() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Recipe value)  $default,){
final _that = this;
switch (_that) {
case _Recipe():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Recipe value)?  $default,){
final _that = this;
switch (_that) {
case _Recipe() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String category,  double portions,  List<RecipeIngredient> ingredients,  DateTime createdAt,  DateTime updatedAt,  String description,  List<String> prepSteps,  List<String> cookSteps,  int? prepMinutes,  int? cookMinutes,  String? storage,  FreezingSuitability freezing,  String? reheating,  bool favourite,  double? totalWeightG,  double? portionWeightG,  NutrientAmounts? declaredPerPortion,  String? nutritionNote,  List<String> ingredientNotes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Recipe() when $default != null:
return $default(_that.id,_that.name,_that.category,_that.portions,_that.ingredients,_that.createdAt,_that.updatedAt,_that.description,_that.prepSteps,_that.cookSteps,_that.prepMinutes,_that.cookMinutes,_that.storage,_that.freezing,_that.reheating,_that.favourite,_that.totalWeightG,_that.portionWeightG,_that.declaredPerPortion,_that.nutritionNote,_that.ingredientNotes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String category,  double portions,  List<RecipeIngredient> ingredients,  DateTime createdAt,  DateTime updatedAt,  String description,  List<String> prepSteps,  List<String> cookSteps,  int? prepMinutes,  int? cookMinutes,  String? storage,  FreezingSuitability freezing,  String? reheating,  bool favourite,  double? totalWeightG,  double? portionWeightG,  NutrientAmounts? declaredPerPortion,  String? nutritionNote,  List<String> ingredientNotes)  $default,) {final _that = this;
switch (_that) {
case _Recipe():
return $default(_that.id,_that.name,_that.category,_that.portions,_that.ingredients,_that.createdAt,_that.updatedAt,_that.description,_that.prepSteps,_that.cookSteps,_that.prepMinutes,_that.cookMinutes,_that.storage,_that.freezing,_that.reheating,_that.favourite,_that.totalWeightG,_that.portionWeightG,_that.declaredPerPortion,_that.nutritionNote,_that.ingredientNotes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String category,  double portions,  List<RecipeIngredient> ingredients,  DateTime createdAt,  DateTime updatedAt,  String description,  List<String> prepSteps,  List<String> cookSteps,  int? prepMinutes,  int? cookMinutes,  String? storage,  FreezingSuitability freezing,  String? reheating,  bool favourite,  double? totalWeightG,  double? portionWeightG,  NutrientAmounts? declaredPerPortion,  String? nutritionNote,  List<String> ingredientNotes)?  $default,) {final _that = this;
switch (_that) {
case _Recipe() when $default != null:
return $default(_that.id,_that.name,_that.category,_that.portions,_that.ingredients,_that.createdAt,_that.updatedAt,_that.description,_that.prepSteps,_that.cookSteps,_that.prepMinutes,_that.cookMinutes,_that.storage,_that.freezing,_that.reheating,_that.favourite,_that.totalWeightG,_that.portionWeightG,_that.declaredPerPortion,_that.nutritionNote,_that.ingredientNotes);case _:
  return null;

}
}

}

/// @nodoc


class _Recipe extends Recipe {
  const _Recipe({required this.id, required this.name, required this.category, required this.portions, required  List<RecipeIngredient> ingredients, required this.createdAt, required this.updatedAt, this.description = '',  List<String> prepSteps = const <String>[],  List<String> cookSteps = const <String>[], this.prepMinutes, this.cookMinutes, this.storage, this.freezing = FreezingSuitability.unknown, this.reheating, this.favourite = false, this.totalWeightG, this.portionWeightG, this.declaredPerPortion, this.nutritionNote,  List<String> ingredientNotes = const <String>[]}): _ingredients = ingredients,_prepSteps = prepSteps,_cookSteps = cookSteps,_ingredientNotes = ingredientNotes,super._();
  

@override final  String id;
@override final  String name;
@override final  String category;
/// Number of portions the recipe makes (greater than 0; a user save needs
/// 1 or more, RCP-001). Fractional when derived from weights (RCP-008).
@override final  double portions;
 final  List<RecipeIngredient> _ingredients;
@override List<RecipeIngredient> get ingredients {
  if (_ingredients is EqualUnmodifiableListView) return _ingredients;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ingredients);
}

@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override@JsonKey() final  String description;
/// Ordered preparation instructions (RCP-003).
 final  List<String> _prepSteps;
/// Ordered preparation instructions (RCP-003).
@override@JsonKey() List<String> get prepSteps {
  if (_prepSteps is EqualUnmodifiableListView) return _prepSteps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_prepSteps);
}

/// Ordered cooking instructions (RCP-003).
 final  List<String> _cookSteps;
/// Ordered cooking instructions (RCP-003).
@override@JsonKey() List<String> get cookSteps {
  if (_cookSteps is EqualUnmodifiableListView) return _cookSteps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_cookSteps);
}

@override final  int? prepMinutes;
@override final  int? cookMinutes;
@override final  String? storage;
@override@JsonKey() final  FreezingSuitability freezing;
@override final  String? reheating;
@override@JsonKey() final  bool favourite;
/// Cooked yield W in grams as entered by the user (RCP-008(2)).
@override final  double? totalWeightG;
/// Weight w of one portion in grams (RCP-008(2)).
@override final  double? portionWeightG;
@override final  NutrientAmounts? declaredPerPortion;
@override final  String? nutritionNote;
/// Free-text ingredient lines of an imported recipe. Never calculated.
 final  List<String> _ingredientNotes;
/// Free-text ingredient lines of an imported recipe. Never calculated.
@override@JsonKey() List<String> get ingredientNotes {
  if (_ingredientNotes is EqualUnmodifiableListView) return _ingredientNotes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ingredientNotes);
}


/// Create a copy of Recipe
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecipeCopyWith<_Recipe> get copyWith => __$RecipeCopyWithImpl<_Recipe>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Recipe&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.portions, portions) || other.portions == portions)&&const DeepCollectionEquality().equals(other.ingredients, _ingredients)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.description, description) || other.description == description)&&const DeepCollectionEquality().equals(other.prepSteps, _prepSteps)&&const DeepCollectionEquality().equals(other.cookSteps, _cookSteps)&&(identical(other.prepMinutes, prepMinutes) || other.prepMinutes == prepMinutes)&&(identical(other.cookMinutes, cookMinutes) || other.cookMinutes == cookMinutes)&&(identical(other.storage, storage) || other.storage == storage)&&(identical(other.freezing, freezing) || other.freezing == freezing)&&(identical(other.reheating, reheating) || other.reheating == reheating)&&(identical(other.favourite, favourite) || other.favourite == favourite)&&(identical(other.totalWeightG, totalWeightG) || other.totalWeightG == totalWeightG)&&(identical(other.portionWeightG, portionWeightG) || other.portionWeightG == portionWeightG)&&(identical(other.declaredPerPortion, declaredPerPortion) || other.declaredPerPortion == declaredPerPortion)&&(identical(other.nutritionNote, nutritionNote) || other.nutritionNote == nutritionNote)&&const DeepCollectionEquality().equals(other.ingredientNotes, _ingredientNotes));
}


@override
int get hashCode {
    return Object.hashAll([runtimeType,id,name,category,portions,const DeepCollectionEquality().hash(_ingredients),createdAt,updatedAt,description,const DeepCollectionEquality().hash(_prepSteps),const DeepCollectionEquality().hash(_cookSteps),prepMinutes,cookMinutes,storage,freezing,reheating,favourite,totalWeightG,portionWeightG,declaredPerPortion,nutritionNote,const DeepCollectionEquality().hash(_ingredientNotes)]);
}

@override
String toString() {
    return 'Recipe(id: $id, name: $name, category: $category, portions: $portions, ingredients: $ingredients, createdAt: $createdAt, updatedAt: $updatedAt, description: $description, prepSteps: $prepSteps, cookSteps: $cookSteps, prepMinutes: $prepMinutes, cookMinutes: $cookMinutes, storage: $storage, freezing: $freezing, reheating: $reheating, favourite: $favourite, totalWeightG: $totalWeightG, portionWeightG: $portionWeightG, declaredPerPortion: $declaredPerPortion, nutritionNote: $nutritionNote, ingredientNotes: $ingredientNotes)';
}


}

/// @nodoc
abstract mixin class _$RecipeCopyWith<$Res> implements $RecipeCopyWith<$Res> {
  factory _$RecipeCopyWith(_Recipe value, $Res Function(_Recipe) _then) = __$RecipeCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String category, double portions, List<RecipeIngredient> ingredients, DateTime createdAt, DateTime updatedAt, String description, List<String> prepSteps, List<String> cookSteps, int? prepMinutes, int? cookMinutes, String? storage, FreezingSuitability freezing, String? reheating, bool favourite, double? totalWeightG, double? portionWeightG, NutrientAmounts? declaredPerPortion, String? nutritionNote, List<String> ingredientNotes
});


@override $NutrientAmountsCopyWith<$Res>? get declaredPerPortion;

}
/// @nodoc
class __$RecipeCopyWithImpl<$Res>
    implements _$RecipeCopyWith<$Res> {
  __$RecipeCopyWithImpl(this._self, this._then);

  final _Recipe _self;
  final $Res Function(_Recipe) _then;

/// Create a copy of Recipe
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? category = null,Object? portions = null,Object? ingredients = null,Object? createdAt = null,Object? updatedAt = null,Object? description = null,Object? prepSteps = null,Object? cookSteps = null,Object? prepMinutes = freezed,Object? cookMinutes = freezed,Object? storage = freezed,Object? freezing = null,Object? reheating = freezed,Object? favourite = null,Object? totalWeightG = freezed,Object? portionWeightG = freezed,Object? declaredPerPortion = freezed,Object? nutritionNote = freezed,Object? ingredientNotes = null,}) {
  return _then(_Recipe(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,portions: null == portions ? _self.portions : portions // ignore: cast_nullable_to_non_nullable
as double,ingredients: null == ingredients ? _self._ingredients : ingredients // ignore: cast_nullable_to_non_nullable
as List<RecipeIngredient>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,prepSteps: null == prepSteps ? _self._prepSteps : prepSteps // ignore: cast_nullable_to_non_nullable
as List<String>,cookSteps: null == cookSteps ? _self._cookSteps : cookSteps // ignore: cast_nullable_to_non_nullable
as List<String>,prepMinutes: freezed == prepMinutes ? _self.prepMinutes : prepMinutes // ignore: cast_nullable_to_non_nullable
as int?,cookMinutes: freezed == cookMinutes ? _self.cookMinutes : cookMinutes // ignore: cast_nullable_to_non_nullable
as int?,storage: freezed == storage ? _self.storage : storage // ignore: cast_nullable_to_non_nullable
as String?,freezing: null == freezing ? _self.freezing : freezing // ignore: cast_nullable_to_non_nullable
as FreezingSuitability,reheating: freezed == reheating ? _self.reheating : reheating // ignore: cast_nullable_to_non_nullable
as String?,favourite: null == favourite ? _self.favourite : favourite // ignore: cast_nullable_to_non_nullable
as bool,totalWeightG: freezed == totalWeightG ? _self.totalWeightG : totalWeightG // ignore: cast_nullable_to_non_nullable
as double?,portionWeightG: freezed == portionWeightG ? _self.portionWeightG : portionWeightG // ignore: cast_nullable_to_non_nullable
as double?,declaredPerPortion: freezed == declaredPerPortion ? _self.declaredPerPortion : declaredPerPortion // ignore: cast_nullable_to_non_nullable
as NutrientAmounts?,nutritionNote: freezed == nutritionNote ? _self.nutritionNote : nutritionNote // ignore: cast_nullable_to_non_nullable
as String?,ingredientNotes: null == ingredientNotes ? _self._ingredientNotes : ingredientNotes // ignore: cast_nullable_to_non_nullable
as List<String>,
  ));
}

/// Create a copy of Recipe
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientAmountsCopyWith<$Res>? get declaredPerPortion {
    if (_self.declaredPerPortion == null) {
    return null;
  }

  return $NutrientAmountsCopyWith<$Res>(_self.declaredPerPortion!, (value) {
    return _then(_self.copyWith(declaredPerPortion: value));
  });
}
}

// dart format on
