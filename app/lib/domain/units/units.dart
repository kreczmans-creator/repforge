import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/units/format.dart';

/// Unit of a [Quantity]: grams or millilitres (the reference basis of a
/// food's nutrients, per 100 g or per 100 ml) or, for a recipe logged by
/// portions (RCP-012), [portions].
///
/// [portions] is a count of a recipe's portions, not a measure: it is never
/// a food's reference unit, never an ingredient unit, and cannot be converted
/// to grams or millilitres without the recipe.
enum ReferenceUnit {
  grams('g'),
  millilitres('ml'),
  portions('portions');

  ReferenceUnit(this.symbol);
  final String symbol;

  /// True for [grams] and [millilitres], the only valid reference bases for
  /// foods and ingredients.
  bool get isMeasure => this != portions;

  /// Decimal places a quantity in this unit is entered, stored and shown to
  /// (spec §2.1): 0.01 for [portions], 0.1 for grams and millilitres.
  int get decimals => this == portions ? 2 : 1;
}

/// Unit system for display. Storage is always metric.
enum UnitSystem { metric, imperial }

/// Non-negative quantity in a [ReferenceUnit], e.g. 150 g or 250 ml.
@immutable
final class Quantity {
  const Quantity._(this.amount, this.unit);

  /// Rebuilds a stored value; throws on corruption.
  factory Quantity.fromStored(double amount, ReferenceUnit unit) =>
      switch (of(amount, unit)) {
        Ok(:final value) => value,
        Err(:final error) => throw StateError(error.message),
      };

  final double amount;
  final ReferenceUnit unit;

  /// Validates like [of] but keeps [amount] as given (no rounding).
  /// Only for derived values that must stay exact, such as a scaled recipe
  /// view (spec §9.4); a quantity the user enters goes through [of].
  static Result<Quantity> exact(double amount, ReferenceUnit unit) {
    final checked = of(amount, unit);
    return switch (checked) {
      Ok() => Ok(Quantity._(amount, unit)),
      Err() => checked,
    };
  }

  static Result<Quantity> of(double amount, ReferenceUnit unit) {
    if (amount.isNaN || amount.isInfinite || amount < 0) {
      return const Err(
        ValidationError('Quantity must be zero or more.', field: 'quantity'),
      );
    }
    if (amount > 100000) {
      return const Err(
        ValidationError(
          'Quantity is unrealistically large.',
          field: 'quantity',
        ),
      );
    }
    final scale = unit == ReferenceUnit.portions ? 100 : 10;
    final rounded = (amount * scale).roundToDouble() / scale;
    return Ok(Quantity._(rounded, unit));
  }

  /// "150 g", "1.25 portions", "2 portions": up to the unit's precision with
  /// no trailing zeros.
  String get label =>
      '${formatNumber(amount, maxDecimals: unit.decimals)} ${unit.symbol}';

  @override
  bool operator ==(Object other) =>
      other is Quantity && other.amount == amount && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);

  @override
  String toString() => 'Quantity($amount ${unit.symbol})';
}

/// Length in centimetres for body measurements (10.0–300.0, 0.1 steps).
@immutable
final class Centimetres {
  const Centimetres._(this.value);

  factory Centimetres.fromStored(double v) => switch (of(v)) {
    Ok(:final value) => value,
    Err(:final error) => throw StateError(error.message),
  };

  static const double min = 10;
  static const double max = 300;
  final double value;

  static Result<Centimetres> of(double raw) {
    if (raw.isNaN || raw.isInfinite) {
      return const Err(ValidationError('Enter a number.', field: 'cm'));
    }
    final rounded = (raw * 10).roundToDouble() / 10;
    if (rounded < min || rounded > max) {
      return const Err(
        ValidationError(
          'Measurement must be between 10.0 cm and 300.0 cm.',
          field: 'cm',
        ),
      );
    }
    return Ok(Centimetres._(rounded));
  }

  String get label => '${value.toStringAsFixed(1)} cm';

  @override
  bool operator ==(Object other) =>
      other is Centimetres && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Training load in kilograms (0–1000, 0.25 kg steps). Distinct from body
/// weight (`Kilograms`) which has a different valid range.
@immutable
final class LoadKg {
  const LoadKg._(this.value);

  factory LoadKg.fromStored(double v) => switch (of(v)) {
    Ok(:final value) => value,
    Err(:final error) => throw StateError(error.message),
  };

  static const double min = 0;
  static const double max = 1000;
  final double value;

  static Result<LoadKg> of(double raw) {
    if (raw.isNaN || raw.isInfinite) {
      return const Err(ValidationError('Enter a number.', field: 'loadKg'));
    }
    final rounded = (raw * 4).roundToDouble() / 4;
    if (rounded < min || rounded > max) {
      return const Err(
        ValidationError('Load must be between 0 and 1000 kg.', field: 'loadKg'),
      );
    }
    return Ok(LoadKg._(rounded));
  }

  String get label => '${formatNumber(value, maxDecimals: 2)} kg';

  @override
  bool operator ==(Object other) => other is LoadKg && other.value == value;

  @override
  int get hashCode => value.hashCode;
}

/// Display conversions. Storage stays metric; these are for presentation only.
abstract final class UnitConversion {
  static const double lbPerKg = 2.2046226218;
  static const double inPerCm = 0.3937007874;
  static const double flOzPerMl = 0.0351950652; // imperial fluid ounce
  static const double ozPerG = 0.0352739619;

  static double kgToLb(double kg) => kg * lbPerKg;
  static double lbToKg(double lb) => lb / lbPerKg;
  static double cmToIn(double cm) => cm * inPerCm;
  static double inToCm(double inches) => inches / inPerCm;
  static double gToOz(double g) => g * ozPerG;
  static double mlToFlOz(double ml) => ml * flOzPerMl;
}
