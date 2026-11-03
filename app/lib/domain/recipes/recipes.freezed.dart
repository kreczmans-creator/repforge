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
mixin _$RecipeIngredient {

 String get id; String get name; Quantity get quantity; int get sortOrder; String? get foodId; NutrientProfile? get per100; String? get note;
/// Create a copy of RecipeIngredient
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecipeIngredientCopyWith<RecipeIngredient> get copyWith => _$RecipeIngredientCopyWithImpl<RecipeIngredient>(this as RecipeIngredient, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as RecipeIngredient;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecipeIngredient&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.foodId, _this.foodId) || other.foodId == _this.foodId)&&(identical(other.per100, _this.per100) || other.per100 == _this.per100)&&(identical(other.note, _this.note) || other.note == _this.note));
}


@override
int get hashCode {
  final _this = this as RecipeIngredient;
  return Object.hash(runtimeType,_this.id,_this.name,_this.quantity,_this.sortOrder,_this.foodId,_this.per100,_this.note);
}

@override
String toString() {
  final _this = this as RecipeIngredient;
  return 'RecipeIngredient(id: ${_this.id}, name: ${_this.name}, quantity: ${_this.quantity}, sortOrder: ${_this.sortOrder}, foodId: ${_this.foodId}, per100: ${_this.per100}, note: ${_this.note})';
}


}

/// @nodoc
abstract mixin class $RecipeIngredientCopyWith<$Res>  {
  factory $RecipeIngredientCopyWith(RecipeIngredient value, $Res Function(RecipeIngredient) _then) = _$RecipeIngredientCopyWithImpl;
@useResult
$Res call({
 String id, String name, Quantity quantity, int sortOrder, String? foodId, NutrientProfile? per100, String? note
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? quantity = null,Object? sortOrder = null,Object? foodId = freezed,Object? per100 = freezed,Object? note = freezed,}) {
  return _then(RecipeIngredient(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Quantity,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,foodId: freezed == foodId ? _self.foodId : foodId // ignore: cast_nullable_to_non_nullable
as String?,per100: freezed == per100 ? _self.per100 : per100 // ignore: cast_nullable_to_non_nullable
as NutrientProfile?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  Quantity quantity,  int sortOrder,  String? foodId,  NutrientProfile? per100,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecipeIngredient() when $default != null:
return $default(_that.id,_that.name,_that.quantity,_that.sortOrder,_that.foodId,_that.per100,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  Quantity quantity,  int sortOrder,  String? foodId,  NutrientProfile? per100,  String? note)  $default,) {final _that = this;
switch (_that) {
case _RecipeIngredient():
return $default(_that.id,_that.name,_that.quantity,_that.sortOrder,_that.foodId,_that.per100,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  Quantity quantity,  int sortOrder,  String? foodId,  NutrientProfile? per100,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _RecipeIngredient() when $default != null:
return $default(_that.id,_that.name,_that.quantity,_that.sortOrder,_that.foodId,_that.per100,_that.note);case _:
  return null;

}
}

}

/// @nodoc


class _RecipeIngredient extends RecipeIngredient {
  const _RecipeIngredient({required this.id, required this.name, required this.quantity, required this.sortOrder, this.foodId, this.per100, this.note}): super._();
  

@override final  String id;
@override final  String name;
@override final  Quantity quantity;
@override final  int sortOrder;
@override final  String? foodId;
@override final  NutrientProfile? per100;
@override final  String? note;

/// Create a copy of RecipeIngredient
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecipeIngredientCopyWith<_RecipeIngredient> get copyWith => __$RecipeIngredientCopyWithImpl<_RecipeIngredient>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecipeIngredient&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.foodId, foodId) || other.foodId == foodId)&&(identical(other.per100, per100) || other.per100 == per100)&&(identical(other.note, note) || other.note == note));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,quantity,sortOrder,foodId,per100,note);
}

@override
String toString() {
    return 'RecipeIngredient(id: $id, name: $name, quantity: $quantity, sortOrder: $sortOrder, foodId: $foodId, per100: $per100, note: $note)';
}


}

/// @nodoc
abstract mixin class _$RecipeIngredientCopyWith<$Res> implements $RecipeIngredientCopyWith<$Res> {
  factory _$RecipeIngredientCopyWith(_RecipeIngredient value, $Res Function(_RecipeIngredient) _then) = __$RecipeIngredientCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, Quantity quantity, int sortOrder, String? foodId, NutrientProfile? per100, String? note
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? quantity = null,Object? sortOrder = null,Object? foodId = freezed,Object? per100 = freezed,Object? note = freezed,}) {
  return _then(_RecipeIngredient(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Quantity,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,foodId: freezed == foodId ? _self.foodId : foodId // ignore: cast_nullable_to_non_nullable
as String?,per100: freezed == per100 ? _self.per100 : per100 // ignore: cast_nullable_to_non_nullable
as NutrientProfile?,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
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

 String get id; String get name; String get category; int get portions; List<RecipeIngredient> get ingredients; List<String> get methodSteps; DateTime get createdAt; DateTime get updatedAt; String get description; int? get prepMinutes; int? get cookMinutes; String? get storage; bool get freezerFriendly; String? get reheating; bool get favourite; NutrientAmounts? get declaredPerPortion; String? get nutritionNote;
/// Create a copy of Recipe
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecipeCopyWith<Recipe> get copyWith => _$RecipeCopyWithImpl<Recipe>(this as Recipe, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Recipe;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Recipe&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.category, _this.category) || other.category == _this.category)&&(identical(other.portions, _this.portions) || other.portions == _this.portions)&&const DeepCollectionEquality().equals(other.ingredients, _this.ingredients)&&const DeepCollectionEquality().equals(other.methodSteps, _this.methodSteps)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.prepMinutes, _this.prepMinutes) || other.prepMinutes == _this.prepMinutes)&&(identical(other.cookMinutes, _this.cookMinutes) || other.cookMinutes == _this.cookMinutes)&&(identical(other.storage, _this.storage) || other.storage == _this.storage)&&(identical(other.freezerFriendly, _this.freezerFriendly) || other.freezerFriendly == _this.freezerFriendly)&&(identical(other.reheating, _this.reheating) || other.reheating == _this.reheating)&&(identical(other.favourite, _this.favourite) || other.favourite == _this.favourite)&&(identical(other.declaredPerPortion, _this.declaredPerPortion) || other.declaredPerPortion == _this.declaredPerPortion)&&(identical(other.nutritionNote, _this.nutritionNote) || other.nutritionNote == _this.nutritionNote));
}


@override
int get hashCode {
  final _this = this as Recipe;
  return Object.hash(runtimeType,_this.id,_this.name,_this.category,_this.portions,const DeepCollectionEquality().hash(_this.ingredients),const DeepCollectionEquality().hash(_this.methodSteps),_this.createdAt,_this.updatedAt,_this.description,_this.prepMinutes,_this.cookMinutes,_this.storage,_this.freezerFriendly,_this.reheating,_this.favourite,_this.declaredPerPortion,_this.nutritionNote);
}

@override
String toString() {
  final _this = this as Recipe;
  return 'Recipe(id: ${_this.id}, name: ${_this.name}, category: ${_this.category}, portions: ${_this.portions}, ingredients: ${_this.ingredients}, methodSteps: ${_this.methodSteps}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, description: ${_this.description}, prepMinutes: ${_this.prepMinutes}, cookMinutes: ${_this.cookMinutes}, storage: ${_this.storage}, freezerFriendly: ${_this.freezerFriendly}, reheating: ${_this.reheating}, favourite: ${_this.favourite}, declaredPerPortion: ${_this.declaredPerPortion}, nutritionNote: ${_this.nutritionNote})';
}


}

/// @nodoc
abstract mixin class $RecipeCopyWith<$Res>  {
  factory $RecipeCopyWith(Recipe value, $Res Function(Recipe) _then) = _$RecipeCopyWithImpl;
@useResult
$Res call({
 String id, String name, String category, int portions, List<RecipeIngredient> ingredients, List<String> methodSteps, DateTime createdAt, DateTime updatedAt, String description, int? prepMinutes, int? cookMinutes, String? storage, bool freezerFriendly, String? reheating, bool favourite, NutrientAmounts? declaredPerPortion, String? nutritionNote
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
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? category = null,Object? portions = null,Object? ingredients = null,Object? methodSteps = null,Object? createdAt = null,Object? updatedAt = null,Object? description = null,Object? prepMinutes = freezed,Object? cookMinutes = freezed,Object? storage = freezed,Object? freezerFriendly = null,Object? reheating = freezed,Object? favourite = null,Object? declaredPerPortion = freezed,Object? nutritionNote = freezed,}) {
  return _then(Recipe(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,portions: null == portions ? _self.portions : portions // ignore: cast_nullable_to_non_nullable
as int,ingredients: null == ingredients ? _self.ingredients : ingredients // ignore: cast_nullable_to_non_nullable
as List<RecipeIngredient>,methodSteps: null == methodSteps ? _self.methodSteps : methodSteps // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,prepMinutes: freezed == prepMinutes ? _self.prepMinutes : prepMinutes // ignore: cast_nullable_to_non_nullable
as int?,cookMinutes: freezed == cookMinutes ? _self.cookMinutes : cookMinutes // ignore: cast_nullable_to_non_nullable
as int?,storage: freezed == storage ? _self.storage : storage // ignore: cast_nullable_to_non_nullable
as String?,freezerFriendly: null == freezerFriendly ? _self.freezerFriendly : freezerFriendly // ignore: cast_nullable_to_non_nullable
as bool,reheating: freezed == reheating ? _self.reheating : reheating // ignore: cast_nullable_to_non_nullable
as String?,favourite: null == favourite ? _self.favourite : favourite // ignore: cast_nullable_to_non_nullable
as bool,declaredPerPortion: freezed == declaredPerPortion ? _self.declaredPerPortion : declaredPerPortion // ignore: cast_nullable_to_non_nullable
as NutrientAmounts?,nutritionNote: freezed == nutritionNote ? _self.nutritionNote : nutritionNote // ignore: cast_nullable_to_non_nullable
as String?,
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String category,  int portions,  List<RecipeIngredient> ingredients,  List<String> methodSteps,  DateTime createdAt,  DateTime updatedAt,  String description,  int? prepMinutes,  int? cookMinutes,  String? storage,  bool freezerFriendly,  String? reheating,  bool favourite,  NutrientAmounts? declaredPerPortion,  String? nutritionNote)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Recipe() when $default != null:
return $default(_that.id,_that.name,_that.category,_that.portions,_that.ingredients,_that.methodSteps,_that.createdAt,_that.updatedAt,_that.description,_that.prepMinutes,_that.cookMinutes,_that.storage,_that.freezerFriendly,_that.reheating,_that.favourite,_that.declaredPerPortion,_that.nutritionNote);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String category,  int portions,  List<RecipeIngredient> ingredients,  List<String> methodSteps,  DateTime createdAt,  DateTime updatedAt,  String description,  int? prepMinutes,  int? cookMinutes,  String? storage,  bool freezerFriendly,  String? reheating,  bool favourite,  NutrientAmounts? declaredPerPortion,  String? nutritionNote)  $default,) {final _that = this;
switch (_that) {
case _Recipe():
return $default(_that.id,_that.name,_that.category,_that.portions,_that.ingredients,_that.methodSteps,_that.createdAt,_that.updatedAt,_that.description,_that.prepMinutes,_that.cookMinutes,_that.storage,_that.freezerFriendly,_that.reheating,_that.favourite,_that.declaredPerPortion,_that.nutritionNote);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String category,  int portions,  List<RecipeIngredient> ingredients,  List<String> methodSteps,  DateTime createdAt,  DateTime updatedAt,  String description,  int? prepMinutes,  int? cookMinutes,  String? storage,  bool freezerFriendly,  String? reheating,  bool favourite,  NutrientAmounts? declaredPerPortion,  String? nutritionNote)?  $default,) {final _that = this;
switch (_that) {
case _Recipe() when $default != null:
return $default(_that.id,_that.name,_that.category,_that.portions,_that.ingredients,_that.methodSteps,_that.createdAt,_that.updatedAt,_that.description,_that.prepMinutes,_that.cookMinutes,_that.storage,_that.freezerFriendly,_that.reheating,_that.favourite,_that.declaredPerPortion,_that.nutritionNote);case _:
  return null;

}
}

}

/// @nodoc


class _Recipe extends Recipe {
  const _Recipe({required this.id, required this.name, required this.category, required this.portions, required  List<RecipeIngredient> ingredients, required  List<String> methodSteps, required this.createdAt, required this.updatedAt, this.description = '', this.prepMinutes, this.cookMinutes, this.storage, this.freezerFriendly = false, this.reheating, this.favourite = false, this.declaredPerPortion, this.nutritionNote}): _ingredients = ingredients,_methodSteps = methodSteps,super._();
  

@override final  String id;
@override final  String name;
@override final  String category;
@override final  int portions;
 final  List<RecipeIngredient> _ingredients;
@override List<RecipeIngredient> get ingredients {
  if (_ingredients is EqualUnmodifiableListView) return _ingredients;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_ingredients);
}

 final  List<String> _methodSteps;
@override List<String> get methodSteps {
  if (_methodSteps is EqualUnmodifiableListView) return _methodSteps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_methodSteps);
}

@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override@JsonKey() final  String description;
@override final  int? prepMinutes;
@override final  int? cookMinutes;
@override final  String? storage;
@override@JsonKey() final  bool freezerFriendly;
@override final  String? reheating;
@override@JsonKey() final  bool favourite;
@override final  NutrientAmounts? declaredPerPortion;
@override final  String? nutritionNote;

/// Create a copy of Recipe
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecipeCopyWith<_Recipe> get copyWith => __$RecipeCopyWithImpl<_Recipe>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Recipe&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.category, category) || other.category == category)&&(identical(other.portions, portions) || other.portions == portions)&&const DeepCollectionEquality().equals(other.ingredients, _ingredients)&&const DeepCollectionEquality().equals(other.methodSteps, _methodSteps)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.description, description) || other.description == description)&&(identical(other.prepMinutes, prepMinutes) || other.prepMinutes == prepMinutes)&&(identical(other.cookMinutes, cookMinutes) || other.cookMinutes == cookMinutes)&&(identical(other.storage, storage) || other.storage == storage)&&(identical(other.freezerFriendly, freezerFriendly) || other.freezerFriendly == freezerFriendly)&&(identical(other.reheating, reheating) || other.reheating == reheating)&&(identical(other.favourite, favourite) || other.favourite == favourite)&&(identical(other.declaredPerPortion, declaredPerPortion) || other.declaredPerPortion == declaredPerPortion)&&(identical(other.nutritionNote, nutritionNote) || other.nutritionNote == nutritionNote));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,category,portions,const DeepCollectionEquality().hash(_ingredients),const DeepCollectionEquality().hash(_methodSteps),createdAt,updatedAt,description,prepMinutes,cookMinutes,storage,freezerFriendly,reheating,favourite,declaredPerPortion,nutritionNote);
}

@override
String toString() {
    return 'Recipe(id: $id, name: $name, category: $category, portions: $portions, ingredients: $ingredients, methodSteps: $methodSteps, createdAt: $createdAt, updatedAt: $updatedAt, description: $description, prepMinutes: $prepMinutes, cookMinutes: $cookMinutes, storage: $storage, freezerFriendly: $freezerFriendly, reheating: $reheating, favourite: $favourite, declaredPerPortion: $declaredPerPortion, nutritionNote: $nutritionNote)';
}


}

/// @nodoc
abstract mixin class _$RecipeCopyWith<$Res> implements $RecipeCopyWith<$Res> {
  factory _$RecipeCopyWith(_Recipe value, $Res Function(_Recipe) _then) = __$RecipeCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String category, int portions, List<RecipeIngredient> ingredients, List<String> methodSteps, DateTime createdAt, DateTime updatedAt, String description, int? prepMinutes, int? cookMinutes, String? storage, bool freezerFriendly, String? reheating, bool favourite, NutrientAmounts? declaredPerPortion, String? nutritionNote
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
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? category = null,Object? portions = null,Object? ingredients = null,Object? methodSteps = null,Object? createdAt = null,Object? updatedAt = null,Object? description = null,Object? prepMinutes = freezed,Object? cookMinutes = freezed,Object? storage = freezed,Object? freezerFriendly = null,Object? reheating = freezed,Object? favourite = null,Object? declaredPerPortion = freezed,Object? nutritionNote = freezed,}) {
  return _then(_Recipe(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as String,portions: null == portions ? _self.portions : portions // ignore: cast_nullable_to_non_nullable
as int,ingredients: null == ingredients ? _self._ingredients : ingredients // ignore: cast_nullable_to_non_nullable
as List<RecipeIngredient>,methodSteps: null == methodSteps ? _self._methodSteps : methodSteps // ignore: cast_nullable_to_non_nullable
as List<String>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,description: null == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String,prepMinutes: freezed == prepMinutes ? _self.prepMinutes : prepMinutes // ignore: cast_nullable_to_non_nullable
as int?,cookMinutes: freezed == cookMinutes ? _self.cookMinutes : cookMinutes // ignore: cast_nullable_to_non_nullable
as int?,storage: freezed == storage ? _self.storage : storage // ignore: cast_nullable_to_non_nullable
as String?,freezerFriendly: null == freezerFriendly ? _self.freezerFriendly : freezerFriendly // ignore: cast_nullable_to_non_nullable
as bool,reheating: freezed == reheating ? _self.reheating : reheating // ignore: cast_nullable_to_non_nullable
as String?,favourite: null == favourite ? _self.favourite : favourite // ignore: cast_nullable_to_non_nullable
as bool,declaredPerPortion: freezed == declaredPerPortion ? _self.declaredPerPortion : declaredPerPortion // ignore: cast_nullable_to_non_nullable
as NutrientAmounts?,nutritionNote: freezed == nutritionNote ? _self.nutritionNote : nutritionNote // ignore: cast_nullable_to_non_nullable
as String?,
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
