import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/units/plain_decimal.dart';

/// A body mass in kilograms, stored to one decimal place.
///
/// Range follows requirement BCM-001: 20.0 kg to 500.0 kg inclusive, in steps
/// of 0.1 kg. `of` and `parse` are the strict input constructors: an
/// out-of-range or off-step value (80.05) is rejected, never rounded.
/// `fromStored` and `tryFromStored` read stored values for the data layer
/// only (guarded by the architecture test) with the same strict rule; they
/// never snap (legacy values are reported, not corrected).
@immutable
final class Kilograms implements Comparable<Kilograms> {
  const Kilograms._(this.value);

  /// Rebuilds from a stored value that was validated when written.
  ///
  /// Throws if the stored value is out of range or off-step, which indicates
  /// legacy or corrupt data rather than user error. Not for user input.
  factory Kilograms.fromStored(double stored) =>
      tryFromStored(stored) ??
      (throw StateError('Stored weight $stored is invalid.'));

  /// Lowest accepted body weight.
  static const double min = 20;

  /// Highest accepted body weight.
  static const double max = 500;

  static const double _tolerance = 1e-9;

  /// Numeric value in kg, a multiple of 0.1 kg.
  final double value;

  /// Read of a stored value: the strict rule of [of] (range and 0.1 step, only
  /// 1e-9 of float noise tolerated). Never snaps: an off-step or out-of-range
  /// stored value is null so the caller reports it instead of correcting it.
  static Kilograms? tryFromStored(double raw) => switch (of(raw)) {
    Ok(:final value) => value,
    Err() => null,
  };

  /// Validates typed input: finite, a multiple of 0.1 kg (within 1e-9 for
  /// floating-point noise) and 20.0 to 500.0 kg. Rejects, never rounds.
  static Result<Kilograms> of(double raw) {
    if (raw.isNaN || raw.isInfinite) {
      return const Err(ValidationError('Enter a number.', field: 'weightKg'));
    }
    final steps = (raw * 10).roundToDouble();
    if ((raw * 10 - steps).abs() > _tolerance) {
      return const Err(
        ValidationError('Use steps of 0.1 kg.', field: 'weightKg'),
      );
    }
    final snapped = steps / 10;
    if (snapped < min || snapped > max) {
      return const Err(
        ValidationError(
          'Enter a value from 20.0 to 500.0 kg.',
          field: 'weightKg',
        ),
      );
    }
    return Ok(Kilograms._(snapped));
  }

  /// Parses user text such as `82.4` or ` 82,4 ` (comma accepted). Plain
  /// decimals only: `1e2` and `+80` are rejected.
  static Result<Kilograms> parse(String text) {
    if (text.trim().isEmpty) {
      return const Err(
        ValidationError('Enter a weight in kg.', field: 'weightKg'),
      );
    }
    final parsed = parsePlainDecimal(text);
    if (parsed == null) {
      return const Err(ValidationError('Enter a number.', field: 'weightKg'));
    }
    return of(parsed);
  }

  /// Display form, e.g. `82.4 kg`.
  String get label => '${value.toStringAsFixed(1)} kg';

  @override
  int compareTo(Kilograms other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) => other is Kilograms && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'Kilograms($value)';
}
