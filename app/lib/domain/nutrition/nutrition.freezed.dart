// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'nutrition.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$NutrientAmounts {

 double get kcal; double? get proteinG; double? get carbsG; double? get fatG; double? get fibreG;
/// Create a copy of NutrientAmounts
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NutrientAmountsCopyWith<NutrientAmounts> get copyWith => _$NutrientAmountsCopyWithImpl<NutrientAmounts>(this as NutrientAmounts, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as NutrientAmounts;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NutrientAmounts&&(identical(other.kcal, _this.kcal) || other.kcal == _this.kcal)&&(identical(other.proteinG, _this.proteinG) || other.proteinG == _this.proteinG)&&(identical(other.carbsG, _this.carbsG) || other.carbsG == _this.carbsG)&&(identical(other.fatG, _this.fatG) || other.fatG == _this.fatG)&&(identical(other.fibreG, _this.fibreG) || other.fibreG == _this.fibreG));
}


@override
int get hashCode {
  final _this = this as NutrientAmounts;
  return Object.hash(runtimeType,_this.kcal,_this.proteinG,_this.carbsG,_this.fatG,_this.fibreG);
}

@override
String toString() {
  final _this = this as NutrientAmounts;
  return 'NutrientAmounts(kcal: ${_this.kcal}, proteinG: ${_this.proteinG}, carbsG: ${_this.carbsG}, fatG: ${_this.fatG}, fibreG: ${_this.fibreG})';
}


}

/// @nodoc
abstract mixin class $NutrientAmountsCopyWith<$Res>  {
  factory $NutrientAmountsCopyWith(NutrientAmounts value, $Res Function(NutrientAmounts) _then) = _$NutrientAmountsCopyWithImpl;
@useResult
$Res call({
 double kcal, double? proteinG, double? carbsG, double? fatG, double? fibreG
});




}
/// @nodoc
class _$NutrientAmountsCopyWithImpl<$Res>
    implements $NutrientAmountsCopyWith<$Res> {
  _$NutrientAmountsCopyWithImpl(this._self, this._then);

  final NutrientAmounts _self;
  final $Res Function(NutrientAmounts) _then;

/// Create a copy of NutrientAmounts
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kcal = null,Object? proteinG = freezed,Object? carbsG = freezed,Object? fatG = freezed,Object? fibreG = freezed,}) {
  return _then(NutrientAmounts(
kcal: null == kcal ? _self.kcal : kcal // ignore: cast_nullable_to_non_nullable
as double,proteinG: freezed == proteinG ? _self.proteinG : proteinG // ignore: cast_nullable_to_non_nullable
as double?,carbsG: freezed == carbsG ? _self.carbsG : carbsG // ignore: cast_nullable_to_non_nullable
as double?,fatG: freezed == fatG ? _self.fatG : fatG // ignore: cast_nullable_to_non_nullable
as double?,fibreG: freezed == fibreG ? _self.fibreG : fibreG // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}

}


/// Adds pattern-matching-related methods to [NutrientAmounts].
extension NutrientAmountsPatterns on NutrientAmounts {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NutrientAmounts value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NutrientAmounts() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NutrientAmounts value)  $default,){
final _that = this;
switch (_that) {
case _NutrientAmounts():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NutrientAmounts value)?  $default,){
final _that = this;
switch (_that) {
case _NutrientAmounts() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( double kcal,  double? proteinG,  double? carbsG,  double? fatG,  double? fibreG)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NutrientAmounts() when $default != null:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( double kcal,  double? proteinG,  double? carbsG,  double? fatG,  double? fibreG)  $default,) {final _that = this;
switch (_that) {
case _NutrientAmounts():
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( double kcal,  double? proteinG,  double? carbsG,  double? fatG,  double? fibreG)?  $default,) {final _that = this;
switch (_that) {
case _NutrientAmounts() when $default != null:
return $default(_that.kcal,_that.proteinG,_that.carbsG,_that.fatG,_that.fibreG);case _:
  return null;

}
}

}

/// @nodoc


class _NutrientAmounts extends NutrientAmounts {
  const _NutrientAmounts({required this.kcal, this.proteinG, this.carbsG, this.fatG, this.fibreG}): super._();
  

@override final  double kcal;
@override final  double? proteinG;
@override final  double? carbsG;
@override final  double? fatG;
@override final  double? fibreG;

/// Create a copy of NutrientAmounts
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NutrientAmountsCopyWith<_NutrientAmounts> get copyWith => __$NutrientAmountsCopyWithImpl<_NutrientAmounts>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _NutrientAmounts&&(identical(other.kcal, kcal) || other.kcal == kcal)&&(identical(other.proteinG, proteinG) || other.proteinG == proteinG)&&(identical(other.carbsG, carbsG) || other.carbsG == carbsG)&&(identical(other.fatG, fatG) || other.fatG == fatG)&&(identical(other.fibreG, fibreG) || other.fibreG == fibreG));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kcal,proteinG,carbsG,fatG,fibreG);
}

@override
String toString() {
    return 'NutrientAmounts(kcal: $kcal, proteinG: $proteinG, carbsG: $carbsG, fatG: $fatG, fibreG: $fibreG)';
}


}

/// @nodoc
abstract mixin class _$NutrientAmountsCopyWith<$Res> implements $NutrientAmountsCopyWith<$Res> {
  factory _$NutrientAmountsCopyWith(_NutrientAmounts value, $Res Function(_NutrientAmounts) _then) = __$NutrientAmountsCopyWithImpl;
@override @useResult
$Res call({
 double kcal, double? proteinG, double? carbsG, double? fatG, double? fibreG
});




}
/// @nodoc
class __$NutrientAmountsCopyWithImpl<$Res>
    implements _$NutrientAmountsCopyWith<$Res> {
  __$NutrientAmountsCopyWithImpl(this._self, this._then);

  final _NutrientAmounts _self;
  final $Res Function(_NutrientAmounts) _then;

/// Create a copy of NutrientAmounts
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kcal = null,Object? proteinG = freezed,Object? carbsG = freezed,Object? fatG = freezed,Object? fibreG = freezed,}) {
  return _then(_NutrientAmounts(
kcal: null == kcal ? _self.kcal : kcal // ignore: cast_nullable_to_non_nullable
as double,proteinG: freezed == proteinG ? _self.proteinG : proteinG // ignore: cast_nullable_to_non_nullable
as double?,carbsG: freezed == carbsG ? _self.carbsG : carbsG // ignore: cast_nullable_to_non_nullable
as double?,fatG: freezed == fatG ? _self.fatG : fatG // ignore: cast_nullable_to_non_nullable
as double?,fibreG: freezed == fibreG ? _self.fibreG : fibreG // ignore: cast_nullable_to_non_nullable
as double?,
  ));
}


}

/// @nodoc
mixin _$NutrientProfile {

 ReferenceUnit get per100; NutrientAmounts get per100Amounts; DataProvenance get provenance;
/// Create a copy of NutrientProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$NutrientProfileCopyWith<NutrientProfile> get copyWith => _$NutrientProfileCopyWithImpl<NutrientProfile>(this as NutrientProfile, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as NutrientProfile;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is NutrientProfile&&(identical(other.per100, _this.per100) || other.per100 == _this.per100)&&(identical(other.per100Amounts, _this.per100Amounts) || other.per100Amounts == _this.per100Amounts)&&(identical(other.provenance, _this.provenance) || other.provenance == _this.provenance));
}


@override
int get hashCode {
  final _this = this as NutrientProfile;
  return Object.hash(runtimeType,_this.per100,_this.per100Amounts,_this.provenance);
}

@override
String toString() {
  final _this = this as NutrientProfile;
  return 'NutrientProfile(per100: ${_this.per100}, per100Amounts: ${_this.per100Amounts}, provenance: ${_this.provenance})';
}


}

/// @nodoc
abstract mixin class $NutrientProfileCopyWith<$Res>  {
  factory $NutrientProfileCopyWith(NutrientProfile value, $Res Function(NutrientProfile) _then) = _$NutrientProfileCopyWithImpl;
@useResult
$Res call({
 ReferenceUnit per100, NutrientAmounts per100Amounts, DataProvenance provenance
});


$NutrientAmountsCopyWith<$Res> get per100Amounts;

}
/// @nodoc
class _$NutrientProfileCopyWithImpl<$Res>
    implements $NutrientProfileCopyWith<$Res> {
  _$NutrientProfileCopyWithImpl(this._self, this._then);

  final NutrientProfile _self;
  final $Res Function(NutrientProfile) _then;

/// Create a copy of NutrientProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? per100 = null,Object? per100Amounts = null,Object? provenance = null,}) {
  return _then(NutrientProfile(
per100: null == per100 ? _self.per100 : per100 // ignore: cast_nullable_to_non_nullable
as ReferenceUnit,per100Amounts: null == per100Amounts ? _self.per100Amounts : per100Amounts // ignore: cast_nullable_to_non_nullable
as NutrientAmounts,provenance: null == provenance ? _self.provenance : provenance // ignore: cast_nullable_to_non_nullable
as DataProvenance,
  ));
}
/// Create a copy of NutrientProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientAmountsCopyWith<$Res> get per100Amounts {
  
  return $NutrientAmountsCopyWith<$Res>(_self.per100Amounts, (value) {
    return _then(_self.copyWith(per100Amounts: value));
  });
}
}


/// Adds pattern-matching-related methods to [NutrientProfile].
extension NutrientProfilePatterns on NutrientProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _NutrientProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _NutrientProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _NutrientProfile value)  $default,){
final _that = this;
switch (_that) {
case _NutrientProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _NutrientProfile value)?  $default,){
final _that = this;
switch (_that) {
case _NutrientProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( ReferenceUnit per100,  NutrientAmounts per100Amounts,  DataProvenance provenance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _NutrientProfile() when $default != null:
return $default(_that.per100,_that.per100Amounts,_that.provenance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( ReferenceUnit per100,  NutrientAmounts per100Amounts,  DataProvenance provenance)  $default,) {final _that = this;
switch (_that) {
case _NutrientProfile():
return $default(_that.per100,_that.per100Amounts,_that.provenance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( ReferenceUnit per100,  NutrientAmounts per100Amounts,  DataProvenance provenance)?  $default,) {final _that = this;
switch (_that) {
case _NutrientProfile() when $default != null:
return $default(_that.per100,_that.per100Amounts,_that.provenance);case _:
  return null;

}
}

}

/// @nodoc


class _NutrientProfile extends NutrientProfile {
  const _NutrientProfile({required this.per100, required this.per100Amounts, required this.provenance}): super._();
  

@override final  ReferenceUnit per100;
@override final  NutrientAmounts per100Amounts;
@override final  DataProvenance provenance;

/// Create a copy of NutrientProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$NutrientProfileCopyWith<_NutrientProfile> get copyWith => __$NutrientProfileCopyWithImpl<_NutrientProfile>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _NutrientProfile&&(identical(other.per100, per100) || other.per100 == per100)&&(identical(other.per100Amounts, per100Amounts) || other.per100Amounts == per100Amounts)&&(identical(other.provenance, provenance) || other.provenance == provenance));
}


@override
int get hashCode {
    return Object.hash(runtimeType,per100,per100Amounts,provenance);
}

@override
String toString() {
    return 'NutrientProfile(per100: $per100, per100Amounts: $per100Amounts, provenance: $provenance)';
}


}

/// @nodoc
abstract mixin class _$NutrientProfileCopyWith<$Res> implements $NutrientProfileCopyWith<$Res> {
  factory _$NutrientProfileCopyWith(_NutrientProfile value, $Res Function(_NutrientProfile) _then) = __$NutrientProfileCopyWithImpl;
@override @useResult
$Res call({
 ReferenceUnit per100, NutrientAmounts per100Amounts, DataProvenance provenance
});


@override $NutrientAmountsCopyWith<$Res> get per100Amounts;

}
/// @nodoc
class __$NutrientProfileCopyWithImpl<$Res>
    implements _$NutrientProfileCopyWith<$Res> {
  __$NutrientProfileCopyWithImpl(this._self, this._then);

  final _NutrientProfile _self;
  final $Res Function(_NutrientProfile) _then;

/// Create a copy of NutrientProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? per100 = null,Object? per100Amounts = null,Object? provenance = null,}) {
  return _then(_NutrientProfile(
per100: null == per100 ? _self.per100 : per100 // ignore: cast_nullable_to_non_nullable
as ReferenceUnit,per100Amounts: null == per100Amounts ? _self.per100Amounts : per100Amounts // ignore: cast_nullable_to_non_nullable
as NutrientAmounts,provenance: null == provenance ? _self.provenance : provenance // ignore: cast_nullable_to_non_nullable
as DataProvenance,
  ));
}

/// Create a copy of NutrientProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientAmountsCopyWith<$Res> get per100Amounts {
  
  return $NutrientAmountsCopyWith<$Res>(_self.per100Amounts, (value) {
    return _then(_self.copyWith(per100Amounts: value));
  });
}
}

/// @nodoc
mixin _$ServingSize {

 String get label; Quantity get quantity;
/// Create a copy of ServingSize
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServingSizeCopyWith<ServingSize> get copyWith => _$ServingSizeCopyWithImpl<ServingSize>(this as ServingSize, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ServingSize;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServingSize&&(identical(other.label, _this.label) || other.label == _this.label)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity));
}


@override
int get hashCode {
  final _this = this as ServingSize;
  return Object.hash(runtimeType,_this.label,_this.quantity);
}

@override
String toString() {
  final _this = this as ServingSize;
  return 'ServingSize(label: ${_this.label}, quantity: ${_this.quantity})';
}


}

/// @nodoc
abstract mixin class $ServingSizeCopyWith<$Res>  {
  factory $ServingSizeCopyWith(ServingSize value, $Res Function(ServingSize) _then) = _$ServingSizeCopyWithImpl;
@useResult
$Res call({
 String label, Quantity quantity
});




}
/// @nodoc
class _$ServingSizeCopyWithImpl<$Res>
    implements $ServingSizeCopyWith<$Res> {
  _$ServingSizeCopyWithImpl(this._self, this._then);

  final ServingSize _self;
  final $Res Function(ServingSize) _then;

/// Create a copy of ServingSize
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? label = null,Object? quantity = null,}) {
  return _then(ServingSize(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Quantity,
  ));
}

}


/// Adds pattern-matching-related methods to [ServingSize].
extension ServingSizePatterns on ServingSize {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServingSize value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServingSize() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServingSize value)  $default,){
final _that = this;
switch (_that) {
case _ServingSize():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServingSize value)?  $default,){
final _that = this;
switch (_that) {
case _ServingSize() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String label,  Quantity quantity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServingSize() when $default != null:
return $default(_that.label,_that.quantity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String label,  Quantity quantity)  $default,) {final _that = this;
switch (_that) {
case _ServingSize():
return $default(_that.label,_that.quantity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String label,  Quantity quantity)?  $default,) {final _that = this;
switch (_that) {
case _ServingSize() when $default != null:
return $default(_that.label,_that.quantity);case _:
  return null;

}
}

}

/// @nodoc


class _ServingSize implements ServingSize {
  const _ServingSize({required this.label, required this.quantity});
  

@override final  String label;
@override final  Quantity quantity;

/// Create a copy of ServingSize
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServingSizeCopyWith<_ServingSize> get copyWith => __$ServingSizeCopyWithImpl<_ServingSize>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServingSize&&(identical(other.label, label) || other.label == label)&&(identical(other.quantity, quantity) || other.quantity == quantity));
}


@override
int get hashCode {
    return Object.hash(runtimeType,label,quantity);
}

@override
String toString() {
    return 'ServingSize(label: $label, quantity: $quantity)';
}


}

/// @nodoc
abstract mixin class _$ServingSizeCopyWith<$Res> implements $ServingSizeCopyWith<$Res> {
  factory _$ServingSizeCopyWith(_ServingSize value, $Res Function(_ServingSize) _then) = __$ServingSizeCopyWithImpl;
@override @useResult
$Res call({
 String label, Quantity quantity
});




}
/// @nodoc
class __$ServingSizeCopyWithImpl<$Res>
    implements _$ServingSizeCopyWith<$Res> {
  __$ServingSizeCopyWithImpl(this._self, this._then);

  final _ServingSize _self;
  final $Res Function(_ServingSize) _then;

/// Create a copy of ServingSize
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? label = null,Object? quantity = null,}) {
  return _then(_ServingSize(
label: null == label ? _self.label : label // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Quantity,
  ));
}


}

/// @nodoc
mixin _$Food {

 String get id; String get name; NutrientProfile get profile; FoodSource get source; DateTime get createdAt; DateTime get updatedAt; String? get brand; String? get barcode; List<ServingSize> get servings;
/// Create a copy of Food
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FoodCopyWith<Food> get copyWith => _$FoodCopyWithImpl<Food>(this as Food, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Food;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Food&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.profile, _this.profile) || other.profile == _this.profile)&&(identical(other.source, _this.source) || other.source == _this.source)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.brand, _this.brand) || other.brand == _this.brand)&&(identical(other.barcode, _this.barcode) || other.barcode == _this.barcode)&&const DeepCollectionEquality().equals(other.servings, _this.servings));
}


@override
int get hashCode {
  final _this = this as Food;
  return Object.hash(runtimeType,_this.id,_this.name,_this.profile,_this.source,_this.createdAt,_this.updatedAt,_this.brand,_this.barcode,const DeepCollectionEquality().hash(_this.servings));
}

@override
String toString() {
  final _this = this as Food;
  return 'Food(id: ${_this.id}, name: ${_this.name}, profile: ${_this.profile}, source: ${_this.source}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, brand: ${_this.brand}, barcode: ${_this.barcode}, servings: ${_this.servings})';
}


}

/// @nodoc
abstract mixin class $FoodCopyWith<$Res>  {
  factory $FoodCopyWith(Food value, $Res Function(Food) _then) = _$FoodCopyWithImpl;
@useResult
$Res call({
 String id, String name, NutrientProfile profile, FoodSource source, DateTime createdAt, DateTime updatedAt, String? brand, String? barcode, List<ServingSize> servings
});


$NutrientProfileCopyWith<$Res> get profile;

}
/// @nodoc
class _$FoodCopyWithImpl<$Res>
    implements $FoodCopyWith<$Res> {
  _$FoodCopyWithImpl(this._self, this._then);

  final Food _self;
  final $Res Function(Food) _then;

/// Create a copy of Food
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? profile = null,Object? source = null,Object? createdAt = null,Object? updatedAt = null,Object? brand = freezed,Object? barcode = freezed,Object? servings = null,}) {
  return _then(Food(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as NutrientProfile,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as FoodSource,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,servings: null == servings ? _self.servings : servings // ignore: cast_nullable_to_non_nullable
as List<ServingSize>,
  ));
}
/// Create a copy of Food
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientProfileCopyWith<$Res> get profile {
  
  return $NutrientProfileCopyWith<$Res>(_self.profile, (value) {
    return _then(_self.copyWith(profile: value));
  });
}
}


/// Adds pattern-matching-related methods to [Food].
extension FoodPatterns on Food {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Food value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Food() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Food value)  $default,){
final _that = this;
switch (_that) {
case _Food():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Food value)?  $default,){
final _that = this;
switch (_that) {
case _Food() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  NutrientProfile profile,  FoodSource source,  DateTime createdAt,  DateTime updatedAt,  String? brand,  String? barcode,  List<ServingSize> servings)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Food() when $default != null:
return $default(_that.id,_that.name,_that.profile,_that.source,_that.createdAt,_that.updatedAt,_that.brand,_that.barcode,_that.servings);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  NutrientProfile profile,  FoodSource source,  DateTime createdAt,  DateTime updatedAt,  String? brand,  String? barcode,  List<ServingSize> servings)  $default,) {final _that = this;
switch (_that) {
case _Food():
return $default(_that.id,_that.name,_that.profile,_that.source,_that.createdAt,_that.updatedAt,_that.brand,_that.barcode,_that.servings);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  NutrientProfile profile,  FoodSource source,  DateTime createdAt,  DateTime updatedAt,  String? brand,  String? barcode,  List<ServingSize> servings)?  $default,) {final _that = this;
switch (_that) {
case _Food() when $default != null:
return $default(_that.id,_that.name,_that.profile,_that.source,_that.createdAt,_that.updatedAt,_that.brand,_that.barcode,_that.servings);case _:
  return null;

}
}

}

/// @nodoc


class _Food implements Food {
  const _Food({required this.id, required this.name, required this.profile, required this.source, required this.createdAt, required this.updatedAt, this.brand, this.barcode,  List<ServingSize> servings = const <ServingSize>[]}): _servings = servings;
  

@override final  String id;
@override final  String name;
@override final  NutrientProfile profile;
@override final  FoodSource source;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  String? brand;
@override final  String? barcode;
 final  List<ServingSize> _servings;
@override@JsonKey() List<ServingSize> get servings {
  if (_servings is EqualUnmodifiableListView) return _servings;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_servings);
}


/// Create a copy of Food
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FoodCopyWith<_Food> get copyWith => __$FoodCopyWithImpl<_Food>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Food&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.profile, profile) || other.profile == profile)&&(identical(other.source, source) || other.source == source)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.brand, brand) || other.brand == brand)&&(identical(other.barcode, barcode) || other.barcode == barcode)&&const DeepCollectionEquality().equals(other.servings, _servings));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,name,profile,source,createdAt,updatedAt,brand,barcode,const DeepCollectionEquality().hash(_servings));
}

@override
String toString() {
    return 'Food(id: $id, name: $name, profile: $profile, source: $source, createdAt: $createdAt, updatedAt: $updatedAt, brand: $brand, barcode: $barcode, servings: $servings)';
}


}

/// @nodoc
abstract mixin class _$FoodCopyWith<$Res> implements $FoodCopyWith<$Res> {
  factory _$FoodCopyWith(_Food value, $Res Function(_Food) _then) = __$FoodCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, NutrientProfile profile, FoodSource source, DateTime createdAt, DateTime updatedAt, String? brand, String? barcode, List<ServingSize> servings
});


@override $NutrientProfileCopyWith<$Res> get profile;

}
/// @nodoc
class __$FoodCopyWithImpl<$Res>
    implements _$FoodCopyWith<$Res> {
  __$FoodCopyWithImpl(this._self, this._then);

  final _Food _self;
  final $Res Function(_Food) _then;

/// Create a copy of Food
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? profile = null,Object? source = null,Object? createdAt = null,Object? updatedAt = null,Object? brand = freezed,Object? barcode = freezed,Object? servings = null,}) {
  return _then(_Food(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,profile: null == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as NutrientProfile,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as FoodSource,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,brand: freezed == brand ? _self.brand : brand // ignore: cast_nullable_to_non_nullable
as String?,barcode: freezed == barcode ? _self.barcode : barcode // ignore: cast_nullable_to_non_nullable
as String?,servings: null == servings ? _self._servings : servings // ignore: cast_nullable_to_non_nullable
as List<ServingSize>,
  ));
}

/// Create a copy of Food
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientProfileCopyWith<$Res> get profile {
  
  return $NutrientProfileCopyWith<$Res>(_self.profile, (value) {
    return _then(_self.copyWith(profile: value));
  });
}
}

/// @nodoc
mixin _$FoodLogEntry {

 String get id;/// Local calendar day `YYYY-MM-DD` the entry belongs to.
 String get day; MealSlot get meal; String get name; Quantity get quantity; NutrientAmounts get nutrients; DataProvenance get provenance; DateTime get loggedAt; DateTime get createdAt; DateTime get updatedAt; String? get foodId; String? get recipeId;
/// Create a copy of FoodLogEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FoodLogEntryCopyWith<FoodLogEntry> get copyWith => _$FoodLogEntryCopyWithImpl<FoodLogEntry>(this as FoodLogEntry, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as FoodLogEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FoodLogEntry&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.day, _this.day) || other.day == _this.day)&&(identical(other.meal, _this.meal) || other.meal == _this.meal)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.quantity, _this.quantity) || other.quantity == _this.quantity)&&(identical(other.nutrients, _this.nutrients) || other.nutrients == _this.nutrients)&&(identical(other.provenance, _this.provenance) || other.provenance == _this.provenance)&&(identical(other.loggedAt, _this.loggedAt) || other.loggedAt == _this.loggedAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.foodId, _this.foodId) || other.foodId == _this.foodId)&&(identical(other.recipeId, _this.recipeId) || other.recipeId == _this.recipeId));
}


@override
int get hashCode {
  final _this = this as FoodLogEntry;
  return Object.hash(runtimeType,_this.id,_this.day,_this.meal,_this.name,_this.quantity,_this.nutrients,_this.provenance,_this.loggedAt,_this.createdAt,_this.updatedAt,_this.foodId,_this.recipeId);
}

@override
String toString() {
  final _this = this as FoodLogEntry;
  return 'FoodLogEntry(id: ${_this.id}, day: ${_this.day}, meal: ${_this.meal}, name: ${_this.name}, quantity: ${_this.quantity}, nutrients: ${_this.nutrients}, provenance: ${_this.provenance}, loggedAt: ${_this.loggedAt}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, foodId: ${_this.foodId}, recipeId: ${_this.recipeId})';
}


}

/// @nodoc
abstract mixin class $FoodLogEntryCopyWith<$Res>  {
  factory $FoodLogEntryCopyWith(FoodLogEntry value, $Res Function(FoodLogEntry) _then) = _$FoodLogEntryCopyWithImpl;
@useResult
$Res call({
 String id, String day, MealSlot meal, String name, Quantity quantity, NutrientAmounts nutrients, DataProvenance provenance, DateTime loggedAt, DateTime createdAt, DateTime updatedAt, String? foodId, String? recipeId
});


$NutrientAmountsCopyWith<$Res> get nutrients;

}
/// @nodoc
class _$FoodLogEntryCopyWithImpl<$Res>
    implements $FoodLogEntryCopyWith<$Res> {
  _$FoodLogEntryCopyWithImpl(this._self, this._then);

  final FoodLogEntry _self;
  final $Res Function(FoodLogEntry) _then;

/// Create a copy of FoodLogEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? day = null,Object? meal = null,Object? name = null,Object? quantity = null,Object? nutrients = null,Object? provenance = null,Object? loggedAt = null,Object? createdAt = null,Object? updatedAt = null,Object? foodId = freezed,Object? recipeId = freezed,}) {
  return _then(FoodLogEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as String,meal: null == meal ? _self.meal : meal // ignore: cast_nullable_to_non_nullable
as MealSlot,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Quantity,nutrients: null == nutrients ? _self.nutrients : nutrients // ignore: cast_nullable_to_non_nullable
as NutrientAmounts,provenance: null == provenance ? _self.provenance : provenance // ignore: cast_nullable_to_non_nullable
as DataProvenance,loggedAt: null == loggedAt ? _self.loggedAt : loggedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,foodId: freezed == foodId ? _self.foodId : foodId // ignore: cast_nullable_to_non_nullable
as String?,recipeId: freezed == recipeId ? _self.recipeId : recipeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of FoodLogEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientAmountsCopyWith<$Res> get nutrients {
  
  return $NutrientAmountsCopyWith<$Res>(_self.nutrients, (value) {
    return _then(_self.copyWith(nutrients: value));
  });
}
}


/// Adds pattern-matching-related methods to [FoodLogEntry].
extension FoodLogEntryPatterns on FoodLogEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FoodLogEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FoodLogEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FoodLogEntry value)  $default,){
final _that = this;
switch (_that) {
case _FoodLogEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FoodLogEntry value)?  $default,){
final _that = this;
switch (_that) {
case _FoodLogEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String day,  MealSlot meal,  String name,  Quantity quantity,  NutrientAmounts nutrients,  DataProvenance provenance,  DateTime loggedAt,  DateTime createdAt,  DateTime updatedAt,  String? foodId,  String? recipeId)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FoodLogEntry() when $default != null:
return $default(_that.id,_that.day,_that.meal,_that.name,_that.quantity,_that.nutrients,_that.provenance,_that.loggedAt,_that.createdAt,_that.updatedAt,_that.foodId,_that.recipeId);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String day,  MealSlot meal,  String name,  Quantity quantity,  NutrientAmounts nutrients,  DataProvenance provenance,  DateTime loggedAt,  DateTime createdAt,  DateTime updatedAt,  String? foodId,  String? recipeId)  $default,) {final _that = this;
switch (_that) {
case _FoodLogEntry():
return $default(_that.id,_that.day,_that.meal,_that.name,_that.quantity,_that.nutrients,_that.provenance,_that.loggedAt,_that.createdAt,_that.updatedAt,_that.foodId,_that.recipeId);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String day,  MealSlot meal,  String name,  Quantity quantity,  NutrientAmounts nutrients,  DataProvenance provenance,  DateTime loggedAt,  DateTime createdAt,  DateTime updatedAt,  String? foodId,  String? recipeId)?  $default,) {final _that = this;
switch (_that) {
case _FoodLogEntry() when $default != null:
return $default(_that.id,_that.day,_that.meal,_that.name,_that.quantity,_that.nutrients,_that.provenance,_that.loggedAt,_that.createdAt,_that.updatedAt,_that.foodId,_that.recipeId);case _:
  return null;

}
}

}

/// @nodoc


class _FoodLogEntry implements FoodLogEntry {
  const _FoodLogEntry({required this.id, required this.day, required this.meal, required this.name, required this.quantity, required this.nutrients, required this.provenance, required this.loggedAt, required this.createdAt, required this.updatedAt, this.foodId, this.recipeId});
  

@override final  String id;
/// Local calendar day `YYYY-MM-DD` the entry belongs to.
@override final  String day;
@override final  MealSlot meal;
@override final  String name;
@override final  Quantity quantity;
@override final  NutrientAmounts nutrients;
@override final  DataProvenance provenance;
@override final  DateTime loggedAt;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  String? foodId;
@override final  String? recipeId;

/// Create a copy of FoodLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FoodLogEntryCopyWith<_FoodLogEntry> get copyWith => __$FoodLogEntryCopyWithImpl<_FoodLogEntry>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FoodLogEntry&&(identical(other.id, id) || other.id == id)&&(identical(other.day, day) || other.day == day)&&(identical(other.meal, meal) || other.meal == meal)&&(identical(other.name, name) || other.name == name)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.nutrients, nutrients) || other.nutrients == nutrients)&&(identical(other.provenance, provenance) || other.provenance == provenance)&&(identical(other.loggedAt, loggedAt) || other.loggedAt == loggedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.foodId, foodId) || other.foodId == foodId)&&(identical(other.recipeId, recipeId) || other.recipeId == recipeId));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,day,meal,name,quantity,nutrients,provenance,loggedAt,createdAt,updatedAt,foodId,recipeId);
}

@override
String toString() {
    return 'FoodLogEntry(id: $id, day: $day, meal: $meal, name: $name, quantity: $quantity, nutrients: $nutrients, provenance: $provenance, loggedAt: $loggedAt, createdAt: $createdAt, updatedAt: $updatedAt, foodId: $foodId, recipeId: $recipeId)';
}


}

/// @nodoc
abstract mixin class _$FoodLogEntryCopyWith<$Res> implements $FoodLogEntryCopyWith<$Res> {
  factory _$FoodLogEntryCopyWith(_FoodLogEntry value, $Res Function(_FoodLogEntry) _then) = __$FoodLogEntryCopyWithImpl;
@override @useResult
$Res call({
 String id, String day, MealSlot meal, String name, Quantity quantity, NutrientAmounts nutrients, DataProvenance provenance, DateTime loggedAt, DateTime createdAt, DateTime updatedAt, String? foodId, String? recipeId
});


@override $NutrientAmountsCopyWith<$Res> get nutrients;

}
/// @nodoc
class __$FoodLogEntryCopyWithImpl<$Res>
    implements _$FoodLogEntryCopyWith<$Res> {
  __$FoodLogEntryCopyWithImpl(this._self, this._then);

  final _FoodLogEntry _self;
  final $Res Function(_FoodLogEntry) _then;

/// Create a copy of FoodLogEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? day = null,Object? meal = null,Object? name = null,Object? quantity = null,Object? nutrients = null,Object? provenance = null,Object? loggedAt = null,Object? createdAt = null,Object? updatedAt = null,Object? foodId = freezed,Object? recipeId = freezed,}) {
  return _then(_FoodLogEntry(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as String,meal: null == meal ? _self.meal : meal // ignore: cast_nullable_to_non_nullable
as MealSlot,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as Quantity,nutrients: null == nutrients ? _self.nutrients : nutrients // ignore: cast_nullable_to_non_nullable
as NutrientAmounts,provenance: null == provenance ? _self.provenance : provenance // ignore: cast_nullable_to_non_nullable
as DataProvenance,loggedAt: null == loggedAt ? _self.loggedAt : loggedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,foodId: freezed == foodId ? _self.foodId : foodId // ignore: cast_nullable_to_non_nullable
as String?,recipeId: freezed == recipeId ? _self.recipeId : recipeId // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of FoodLogEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$NutrientAmountsCopyWith<$Res> get nutrients {
  
  return $NutrientAmountsCopyWith<$Res>(_self.nutrients, (value) {
    return _then(_self.copyWith(nutrients: value));
  });
}
}

// dart format on
