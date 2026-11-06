import 'package:meta/meta.dart';

/// Structural equality for the immutable library value types.
///
/// Lists and maps compare element by element; sets compare as sets; every
/// other value uses `==`. Kept in the domain so the types need no package.
bool deepEquals(Object? a, Object? b) {
  if (identical(a, b)) return true;
  if (a is List<Object?> && b is List<Object?>) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (!deepEquals(a[i], b[i])) return false;
    }
    return true;
  }
  if (a is Map<Object?, Object?> && b is Map<Object?, Object?>) {
    if (a.length != b.length) return false;
    for (final entry in a.entries) {
      if (!b.containsKey(entry.key)) return false;
      if (!deepEquals(entry.value, b[entry.key])) return false;
    }
    return true;
  }
  if (a is Set<Object?> && b is Set<Object?>) {
    return a.length == b.length && a.every(b.contains);
  }
  return a == b;
}

/// Hash consistent with [deepEquals].
int deepHash(Object? value) {
  if (value is List<Object?>) return Object.hashAll(value.map(deepHash));
  if (value is Map<Object?, Object?>) {
    var h = 0;
    for (final e in value.entries) {
      h += Object.hash(deepHash(e.key), deepHash(e.value));
    }
    return h;
  }
  if (value is Set<Object?>) {
    var h = 0;
    for (final e in value) {
      h += deepHash(e);
    }
    return h;
  }
  return value.hashCode;
}

/// Base for value types: equality and hash derive from [props].
@immutable
abstract class ValueObject {
  const ValueObject();

  /// The fields that define the value.
  List<Object?> get props;

  @override
  bool operator ==(Object other) =>
      other is ValueObject &&
      other.runtimeType == runtimeType &&
      deepEquals(props, other.props);

  @override
  int get hashCode => Object.hash(runtimeType, deepHash(props));
}
