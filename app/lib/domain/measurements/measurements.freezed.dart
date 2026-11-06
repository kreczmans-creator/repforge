// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'measurements.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$MeasurementValue {





@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is MeasurementValue);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
    return 'MeasurementValue()';
}


}

/// @nodoc
class $MeasurementValueCopyWith<$Res>  {
$MeasurementValueCopyWith(MeasurementValue _, $Res Function(MeasurementValue) __);
}


/// Adds pattern-matching-related methods to [MeasurementValue].
extension MeasurementValuePatterns on MeasurementValue {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( WeightValue value)?  kg,TResult Function( LengthValue value)?  cm,required TResult orElse(),}){
final _that = this;
switch (_that) {
case WeightValue() when kg != null:
return kg(_that);case LengthValue() when cm != null:
return cm(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( WeightValue value)  kg,required TResult Function( LengthValue value)  cm,}){
final _that = this;
switch (_that) {
case WeightValue():
return kg(_that);case LengthValue():
return cm(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( WeightValue value)?  kg,TResult? Function( LengthValue value)?  cm,}){
final _that = this;
switch (_that) {
case WeightValue() when kg != null:
return kg(_that);case LengthValue() when cm != null:
return cm(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( Kilograms kg)?  kg,TResult Function( Centimetres cm)?  cm,required TResult orElse(),}) {final _that = this;
switch (_that) {
case WeightValue() when kg != null:
return kg(_that.kg);case LengthValue() when cm != null:
return cm(_that.cm);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( Kilograms kg)  kg,required TResult Function( Centimetres cm)  cm,}) {final _that = this;
switch (_that) {
case WeightValue():
return kg(_that.kg);case LengthValue():
return cm(_that.cm);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( Kilograms kg)?  kg,TResult? Function( Centimetres cm)?  cm,}) {final _that = this;
switch (_that) {
case WeightValue() when kg != null:
return kg(_that.kg);case LengthValue() when cm != null:
return cm(_that.cm);case _:
  return null;

}
}

}

/// @nodoc


class WeightValue extends MeasurementValue {
  const WeightValue(this.kg): super._();
  

 final  Kilograms kg;

/// Create a copy of MeasurementValue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$WeightValueCopyWith<WeightValue> get copyWith => _$WeightValueCopyWithImpl<WeightValue>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is WeightValue&&(identical(other.kg, kg) || other.kg == kg));
}


@override
int get hashCode {
    return Object.hash(runtimeType,kg);
}

@override
String toString() {
    return 'MeasurementValue.kg(kg: $kg)';
}


}

/// @nodoc
abstract mixin class $WeightValueCopyWith<$Res> implements $MeasurementValueCopyWith<$Res> {
  factory $WeightValueCopyWith(WeightValue value, $Res Function(WeightValue) _then) = _$WeightValueCopyWithImpl;
@useResult
$Res call({
 Kilograms kg
});




}
/// @nodoc
class _$WeightValueCopyWithImpl<$Res>
    implements $WeightValueCopyWith<$Res> {
  _$WeightValueCopyWithImpl(this._self, this._then);

  final WeightValue _self;
  final $Res Function(WeightValue) _then;

/// Create a copy of MeasurementValue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? kg = null,}) {
  return _then(WeightValue(
null == kg ? _self.kg : kg // ignore: cast_nullable_to_non_nullable
as Kilograms,
  ));
}


}

/// @nodoc


class LengthValue extends MeasurementValue {
  const LengthValue(this.cm): super._();
  

 final  Centimetres cm;

/// Create a copy of MeasurementValue
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LengthValueCopyWith<LengthValue> get copyWith => _$LengthValueCopyWithImpl<LengthValue>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is LengthValue&&(identical(other.cm, cm) || other.cm == cm));
}


@override
int get hashCode {
    return Object.hash(runtimeType,cm);
}

@override
String toString() {
    return 'MeasurementValue.cm(cm: $cm)';
}


}

/// @nodoc
abstract mixin class $LengthValueCopyWith<$Res> implements $MeasurementValueCopyWith<$Res> {
  factory $LengthValueCopyWith(LengthValue value, $Res Function(LengthValue) _then) = _$LengthValueCopyWithImpl;
@useResult
$Res call({
 Centimetres cm
});




}
/// @nodoc
class _$LengthValueCopyWithImpl<$Res>
    implements $LengthValueCopyWith<$Res> {
  _$LengthValueCopyWithImpl(this._self, this._then);

  final LengthValue _self;
  final $Res Function(LengthValue) _then;

/// Create a copy of MeasurementValue
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? cm = null,}) {
  return _then(LengthValue(
null == cm ? _self.cm : cm // ignore: cast_nullable_to_non_nullable
as Centimetres,
  ));
}


}

/// @nodoc
mixin _$Measurement {

 String get id; MeasurementSite get site; MeasurementValue get value; DateTime get recordedAt; DateTime get createdAt; DateTime get updatedAt; String? get note;
/// Create a copy of Measurement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MeasurementCopyWith<Measurement> get copyWith => _$MeasurementCopyWithImpl<Measurement>(this as Measurement, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as Measurement;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Measurement&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.site, _this.site) || other.site == _this.site)&&(identical(other.value, _this.value) || other.value == _this.value)&&(identical(other.recordedAt, _this.recordedAt) || other.recordedAt == _this.recordedAt)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.note, _this.note) || other.note == _this.note));
}


@override
int get hashCode {
  final _this = this as Measurement;
  return Object.hash(runtimeType,_this.id,_this.site,_this.value,_this.recordedAt,_this.createdAt,_this.updatedAt,_this.note);
}

@override
String toString() {
  final _this = this as Measurement;
  return 'Measurement(id: ${_this.id}, site: ${_this.site}, value: ${_this.value}, recordedAt: ${_this.recordedAt}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, note: ${_this.note})';
}


}

/// @nodoc
abstract mixin class $MeasurementCopyWith<$Res>  {
  factory $MeasurementCopyWith(Measurement value, $Res Function(Measurement) _then) = _$MeasurementCopyWithImpl;
@useResult
$Res call({
 String id, MeasurementSite site, MeasurementValue value, DateTime recordedAt, DateTime createdAt, DateTime updatedAt, String? note
});


$MeasurementValueCopyWith<$Res> get value;

}
/// @nodoc
class _$MeasurementCopyWithImpl<$Res>
    implements $MeasurementCopyWith<$Res> {
  _$MeasurementCopyWithImpl(this._self, this._then);

  final Measurement _self;
  final $Res Function(Measurement) _then;

/// Create a copy of Measurement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? site = null,Object? value = null,Object? recordedAt = null,Object? createdAt = null,Object? updatedAt = null,Object? note = freezed,}) {
  return _then(Measurement(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,site: null == site ? _self.site : site // ignore: cast_nullable_to_non_nullable
as MeasurementSite,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as MeasurementValue,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Measurement
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MeasurementValueCopyWith<$Res> get value {
  
  return $MeasurementValueCopyWith<$Res>(_self.value, (value) {
    return _then(_self.copyWith(value: value));
  });
}
}


/// Adds pattern-matching-related methods to [Measurement].
extension MeasurementPatterns on Measurement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Measurement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Measurement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Measurement value)  $default,){
final _that = this;
switch (_that) {
case _Measurement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Measurement value)?  $default,){
final _that = this;
switch (_that) {
case _Measurement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  MeasurementSite site,  MeasurementValue value,  DateTime recordedAt,  DateTime createdAt,  DateTime updatedAt,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Measurement() when $default != null:
return $default(_that.id,_that.site,_that.value,_that.recordedAt,_that.createdAt,_that.updatedAt,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  MeasurementSite site,  MeasurementValue value,  DateTime recordedAt,  DateTime createdAt,  DateTime updatedAt,  String? note)  $default,) {final _that = this;
switch (_that) {
case _Measurement():
return $default(_that.id,_that.site,_that.value,_that.recordedAt,_that.createdAt,_that.updatedAt,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  MeasurementSite site,  MeasurementValue value,  DateTime recordedAt,  DateTime createdAt,  DateTime updatedAt,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _Measurement() when $default != null:
return $default(_that.id,_that.site,_that.value,_that.recordedAt,_that.createdAt,_that.updatedAt,_that.note);case _:
  return null;

}
}

}

/// @nodoc


class _Measurement implements Measurement {
  const _Measurement({required this.id, required this.site, required this.value, required this.recordedAt, required this.createdAt, required this.updatedAt, this.note});
  

@override final  String id;
@override final  MeasurementSite site;
@override final  MeasurementValue value;
@override final  DateTime recordedAt;
@override final  DateTime createdAt;
@override final  DateTime updatedAt;
@override final  String? note;

/// Create a copy of Measurement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MeasurementCopyWith<_Measurement> get copyWith => __$MeasurementCopyWithImpl<_Measurement>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Measurement&&(identical(other.id, id) || other.id == id)&&(identical(other.site, site) || other.site == site)&&(identical(other.value, value) || other.value == value)&&(identical(other.recordedAt, recordedAt) || other.recordedAt == recordedAt)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.note, note) || other.note == note));
}


@override
int get hashCode {
    return Object.hash(runtimeType,id,site,value,recordedAt,createdAt,updatedAt,note);
}

@override
String toString() {
    return 'Measurement(id: $id, site: $site, value: $value, recordedAt: $recordedAt, createdAt: $createdAt, updatedAt: $updatedAt, note: $note)';
}


}

/// @nodoc
abstract mixin class _$MeasurementCopyWith<$Res> implements $MeasurementCopyWith<$Res> {
  factory _$MeasurementCopyWith(_Measurement value, $Res Function(_Measurement) _then) = __$MeasurementCopyWithImpl;
@override @useResult
$Res call({
 String id, MeasurementSite site, MeasurementValue value, DateTime recordedAt, DateTime createdAt, DateTime updatedAt, String? note
});


@override $MeasurementValueCopyWith<$Res> get value;

}
/// @nodoc
class __$MeasurementCopyWithImpl<$Res>
    implements _$MeasurementCopyWith<$Res> {
  __$MeasurementCopyWithImpl(this._self, this._then);

  final _Measurement _self;
  final $Res Function(_Measurement) _then;

/// Create a copy of Measurement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? site = null,Object? value = null,Object? recordedAt = null,Object? createdAt = null,Object? updatedAt = null,Object? note = freezed,}) {
  return _then(_Measurement(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,site: null == site ? _self.site : site // ignore: cast_nullable_to_non_nullable
as MeasurementSite,value: null == value ? _self.value : value // ignore: cast_nullable_to_non_nullable
as MeasurementValue,recordedAt: null == recordedAt ? _self.recordedAt : recordedAt // ignore: cast_nullable_to_non_nullable
as DateTime,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Measurement
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$MeasurementValueCopyWith<$Res> get value {
  
  return $MeasurementValueCopyWith<$Res>(_self.value, (value) {
    return _then(_self.copyWith(value: value));
  });
}
}

// dart format on
