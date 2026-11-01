import 'package:flutter/foundation.dart' show immutable;
import 'package:repforge/domain/core/result.dart';

/// A body mass in kilograms, stored to one decimal place.
///
/// Range follows requirement BCM-001: 20.0 kg to 500.0 kg inclusive.
@immutable
final class Kilograms implements Comparable<Kilograms> {
  const Kilograms._(this.value);

  /// Rebuilds from a stored value that was validated when written.
  ///
  /// Throws if the stored value is outside the accepted range, which would
  /// indicate database corruption rather than user error.
  factory Kilograms.fromStored(double stored) {
    final result = of(stored);
    return switch (result) {
      Ok(:final value) => value,
      Err(:final error) => throw StateError(
        'Stored weight $stored is invalid: ${error.message}',
      ),
    };
  }

  /// Lowest accepted body weight.
  static const double min = 20;

  /// Highest accepted body weight.
  static const double max = 500;

  /// Numeric value in kg, already rounded to 0.1 kg.
  final double value;

  /// Builds a validated instance from a number.
  static Result<Kilograms> of(double raw) {
    if (raw.isNaN || raw.isInfinite) {
      return const Err(
        ValidationError('Weight must be a number.', field: 'weightKg'),
      );
    }
    final rounded = (raw * 10).roundToDouble() / 10;
    if (rounded < min || rounded > max) {
      return const Err(
        ValidationError(
          'Weight must be between 20.0 kg and 500.0 kg.',
          field: 'weightKg',
        ),
      );
    }
    return Ok(Kilograms._(rounded));
  }

  /// Parses user text such as `82.4` or ` 82,4 ` (comma accepted).
  static Result<Kilograms> parse(String text) {
    final cleaned = text.trim().replaceAll(',', '.');
    if (cleaned.isEmpty) {
      return const Err(
        ValidationError('Enter a weight in kg.', field: 'weightKg'),
      );
    }
    final parsed = double.tryParse(cleaned);
    if (parsed == null) {
      return const Err(
        ValidationError('Weight must be a number.', field: 'weightKg'),
      );
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
