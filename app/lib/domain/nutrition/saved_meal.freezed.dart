// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'saved_meal.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SavedMealItem {

 String get id; String get name; Quantity get quantity; NutrientAmounts get nutrients; DataProvenance get provenance; int get sortOrder; String? get foodId; String? get recipeId;
/// Create a copy of SavedMealItem
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SavedMealItemCopyWith<SavedMealItem> get copyWith => _$SavedMealItemCopyWithImpl<SavedMealItem>(this as SavedMealItem, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SavedMealItem;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SavedMealItem&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity)&&(identical(other.nutrients, _this.nutrients) || other.nutrients == _this.nutrients)&&(identical(other.provenance, _this.provenance) || other.provenance == _this.provenance)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.foodId, _this.foodId) || other.foodId == _this.foodId)&&(identical(other.recipeId, _this.recipeId) || other.recipeId == _this.recipeId));
}


@override
int get hashCode {
  final _this = this as SavedMealItem;
  return Object.hash(runtimeType,_this.id,_this.name,_this.quantity,_this.nutrients,_this.provenance,_this.sortOrder,_this.foodId,_this.recipeId);
}

@override
String toString() {
  final _this = this as SavedMealItem;
  return 'SavedMealItem(id: ${_this.id}, name: ${_this.name}, quantity: ${_this.quantity}, nutrients: ${_this.nutrients}, provenance: ${_this.provenance}, sortOrder: ${_this.sortOrder}, foodId: ${_this.foodId}, recipeId: ${_this.recipeId})';
}


}

/// @nodoc
abstract mixin class $SavedMealItemCopyWith<$Res>  {
  factory $SavedMealItemCopyWith(SavedMealItem value, $Res Function(SavedMealItem) _then) = _$SavedMealItemCopyWithImpl;
@useResult
$Res call({
 String id, String name, Quantity quantity, NutrientAmounts nutrients, DataProvenance provenance, int sortOrder, String? foodId, String? recipeId
});


$NutrientAmountsCopyWith<$Res> get nutrients;

}
/// @nodoc
class _$SavedMealItemCopyWithImpl<$Res>
    implements $SavedMealItemCopyWith<$Res> {
  _$SavedMealItemCopyWithImpl(this._self, this._then);

  final SavedMealItem _self;
  final $Res Function(SavedMealItem) _then;

/// Create a copy of SavedMealItem
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? quantity = null,Object? nutrients = null,Object? provenance = null,Object? sortOrder = null,Object? foodId = freezed,Object? recipeId = freezed,}) {
  return _then(SavedMealItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Quantity,nutrients: null == nutrients ? _self.nutrients : nutrients // ignore: cast_nullable_to_non_nullable
as NutrientAmounts,provenance: null == provenance ? _self.provenance : provenance // ignore: cast_nullable_to_non_nullable
as DataProvenance,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,foodId: freezed == foodId ? _self.foodId : foodId // ignore: cast_nullable_to_non_nullable
as String?,recipeId: freezed == recipeId ? _self.recipeId : recipeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of SavedMealItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientAmountsCopyWith<$Res> get nutrients {
  
  return $NutrientAmountsCopyWith<$Res>(_self.nutrients, (value) {
    return _then(_self.copyWith(nutrients: value));
  });
}
}


/// Adds pattern-matching-related methods to [SavedMealItem].
extension SavedMealItemPatterns on SavedMealItem {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SavedMealItem value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SavedMealItem() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SavedMealItem value)  $default,){
final _that = this;
switch (_that) {
case _SavedMealItem():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SavedMealItem value)?  $default,){
final _that = this;
switch (_that) {
case _SavedMealItem() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  Quantity quantity,  NutrientAmounts nutrients,  DataProvenance provenance,  int sortOrder,  String? foodId,  String? recipeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SavedMealItem() when $default != null:
return $default(_that.id,_that.name,_that.quantity,_that.nutrients,_that.provenance,_that.sortOrder,_that.foodId,_that.recipeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  Quantity quantity,  NutrientAmounts nutrients,  DataProvenance provenance,  int sortOrder,  String? foodId,  String? recipeId)  $default,) {final _that = this;
switch (_that) {
case _SavedMealItem():
return $default(_that.id,_that.name,_that.quantity,_that.nutrients,_that.provenance,_that.sortOrder,_that.foodId,_that.recipeId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  Quantity quantity,  NutrientAmounts nutrients,  DataProvenance provenance,  int sortOrder,  String? foodId,  String? recipeId)?  $default,) {final _that = this;
switch (_that) {
case _SavedMealItem() when $default != null:
return $default(_that.id,_that.name,_that.quantity,_that.nutrients,_that.provenance,_that.sortOrder,_that.foodId,_that.recipeId);case _:
  return null;

}
}

}

/// @nodoc


class _SavedMealItem implements SavedMealItem {
  const _SavedMealItem({required this.id, required this.name, required this.quantity, required this.nutrients, required this.provenance, required this.sortOrder, this.foodId, this.recipeId});
  

@override final  String id;
@override final  String name;
@override final  Quantity quantity;
@override final  NutrientAmounts nutrients;
@override final  DataProvenance provenance;
@override final  int sortOrder;
@override final  String? foodId;
@override final  String? recipeId;

/// Create a copy of SavedMealItem
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SavedMealItemCopyWith<_SavedMealItem> get copyWith => __$SavedMealItemCopyWithImpl<_SavedMealItem>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SavedMealItem&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.nutrients, nutrients) || other.nutrients == nutrients)&&(identical(other.provenance, provenance) || other.provenance == provenance)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.foodId, foodId) || other.foodId == foodId)&&(identical(other.recipeId, recipeId) || other.recipeId == recipeId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,quantity,nutrients,provenance,sortOrder,foodId,recipeId);
}

@override
String toString() {
    return 'SavedMealItem(id: $id, name: $name, quantity: $quantity, nutrients: $nutrients, provenance: $provenance, sortOrder: $sortOrder, foodId: $foodId, recipeId: $recipeId)';
}


}

/// @nodoc
abstract mixin class _$SavedMealItemCopyWith<$Res> implements $SavedMealItemCopyWith<$Res> {
  factory _$SavedMealItemCopyWith(_SavedMealItem value, $Res Function(_SavedMealItem) _then) = __$SavedMealItemCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, Quantity quantity, NutrientAmounts nutrients, DataProvenance provenance, int sortOrder, String? foodId, String? recipeId
});


@override $NutrientAmountsCopyWith<$Res> get nutrients;

}
/// @nodoc
class __$SavedMealItemCopyWithImpl<$Res>
    implements _$SavedMealItemCopyWith<$Res> {
  __$SavedMealItemCopyWithImpl(this._self, this._then);

  final _SavedMealItem _self;
  final $Res Function(_SavedMealItem) _then;

/// Create a copy of SavedMealItem
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? quantity = null,Object? nutrients = null,Object? provenance = null,Object? sortOrder = null,Object? foodId = freezed,Object? recipeId = freezed,}) {
  return _then(_SavedMealItem(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Quantity,nutrients: null == nutrients ? _self.nutrients : nutrients // ignore: cast_nullable_to_non_nullable
as NutrientAmounts,provenance: null == provenance ? _self.provenance : provenance // ignore: cast_nullable_to_non_nullable
as DataProvenance,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,foodId: freezed == foodId ? _self.foodId : foodId // ignore: cast_nullable_to_non_nullable
as String?,recipeId: freezed == recipeId ? _self.recipeId : recipeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of SavedMealItem
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientAmountsCopyWith<$Res> get nutrients {
  
  return $NutrientAmountsCopyWith<$Res>(_self.nutrients, (value) {
    return _then(_self.copyWith(nutrients: value));
  });
}
}

/// @nodoc
mixin _$SavedMeal {

 String get id; String get name; List<SavedMealItem> get items; DateTime get createdAt; DateTime get updatedAt; MealSlot? get defaultMeal;
/// Create a copy of SavedMeal
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SavedMealCopyWith<SavedMeal> get copyWith => _$SavedMealCopyWithImpl<SavedMeal>(this as SavedMeal, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as SavedMeal;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SavedMeal&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&const DeepCollectionEquality().equals(other.items, _this.items)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.defaultMeal, _this.defaultMeal) || other.defaultMeal == _this.defaultMeal));
}


@override
int get hashCode {
  final _this = this as SavedMeal;
  return Object.hash(runtimeType,_this.id,_this.name,const DeepCollectionEquality().hash(_this.items),_this.createdAt,_this.updatedAt,_this.defaultMeal);
}

@override
String toString() {
  final _this = this as SavedMeal;
  return 'SavedMeal(id: ${_this.id}, name: ${_this.name}, items: ${_this.items}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, defaultMeal: ${_this.defaultMeal})';
}


}

/// @nodoc
abstract mixin class $SavedMealCopyWith<$Res>  {
  factory $SavedMealCopyWith(SavedMeal value, $Res Function(SavedMeal) _then) = _$SavedMealCopyWithImpl;
@useResult
$Res call({
 String id, String name, List<SavedMealItem> items, DateTime createdAt, DateTime updatedAt, MealSlot? defaultMeal
});




}
/// @nodoc
class _$SavedMealCopyWithImpl<$Res>
    implements $SavedMealCopyWith<$Res> {
  _$SavedMealCopyWithImpl(this._self, this._then);

  final SavedMeal _self;
  final $Res Function(SavedMeal) _then;

/// Create a copy of SavedMeal
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? items = null,Object? createdAt = null,Object? updatedAt = null,Object? defaultMeal = freezed,}) {
  return _then(SavedMeal(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<SavedMealItem>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,defaultMeal: freezed == defaultMeal ? _self.defaultMeal : defaultMeal // ignore: cast_nullable_to_non_nullable
as MealSlot?,
  ));
}

}


/// Adds pattern-matching-related methods to [SavedMeal].
extension SavedMealPatterns on SavedMeal {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SavedMeal value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SavedMeal() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SavedMeal value)  $default,){
final _that = this;
switch (_that) {
case _SavedMeal():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SavedMeal value)?  $default,){
final _that = this;
switch (_that) {
case _SavedMeal() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  List<SavedMealItem> items,  DateTime createdAt,  DateTime updatedAt,  MealSlot? defaultMeal)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SavedMeal() when $default != null:
return $default(_that.id,_that.name,_that.items,_that.createdAt,_that.updatedAt,_that.defaultMeal);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  List<SavedMealItem> items,  DateTime createdAt,  DateTime updatedAt,  MealSlot? defaultMeal)  $default,) {final _that = this;
switch (_that) {
case _SavedMeal():
return $default(_that.id,_that.name,_that.items,_that.createdAt,_that.updatedAt,_that.defaultMeal);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  List<SavedMealItem> items,  DateTime createdAt,  DateTime updatedAt,  MealSlot? defaultMeal)?  $default,) {final _that = this;
switch (_that) {
case _SavedMeal() when $default != null:
return $default(_that.id,_that.name,_that.items,_that.createdAt,_that.updatedAt,_that.defaultMeal);case _:
  return null;

}
}

}

/// @nodoc


class _SavedMeal extends SavedMeal {
  const _SavedMeal({required this.id, required this.name, required  List<SavedMealItem> items, required this.createdAt, required this.updatedAt, this.defaultMeal}): _items = items,super._();
  

@override final  String id;
@override final  String name;
 final  List<SavedMealItem> _items;
@override List<SavedMealItem> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  MealSlot? defaultMeal;

/// Create a copy of SavedMeal
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SavedMealCopyWith<_SavedMeal> get copyWith => __$SavedMealCopyWithImpl<_SavedMeal>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SavedMeal&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&const DeepCollectionEquality().equals(other.items, _items)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.defaultMeal, defaultMeal) || other.defaultMeal == defaultMeal));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,const DeepCollectionEquality().hash(_items),createdAt,updatedAt,defaultMeal);
}

@override
String toString() {
    return 'SavedMeal(id: $id, name: $name, items: $items, createdAt: $createdAt, updatedAt: $updatedAt, defaultMeal: $defaultMeal)';
}


}

/// @nodoc
abstract mixin class _$SavedMealCopyWith<$Res> implements $SavedMealCopyWith<$Res> {
  factory _$SavedMealCopyWith(_SavedMeal value, $Res Function(_SavedMeal) _then) = __$SavedMealCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, List<SavedMealItem> items, DateTime createdAt, DateTime updatedAt, MealSlot? defaultMeal
});




}
/// @nodoc
class __$SavedMealCopyWithImpl<$Res>
    implements _$SavedMealCopyWith<$Res> {
  __$SavedMealCopyWithImpl(this._self, this._then);

  final _SavedMeal _self;
  final $Res Function(_SavedMeal) _then;

/// Create a copy of SavedMeal
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? items = null,Object? createdAt = null,Object? updatedAt = null,Object? defaultMeal = freezed,}) {
  return _then(_SavedMeal(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<SavedMealItem>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,defaultMeal: freezed == defaultMeal ? _self.defaultMeal : defaultMeal // ignore: cast_nullable_to_non_nullable
as MealSlot?,
  ));
}


}

// dart format on
