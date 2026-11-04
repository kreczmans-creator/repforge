import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/units/units.dart';

part 'nutrition.freezed.dart';

/// Where a nutrient value came from (requirement GEN: provenance labelling).
/// `crowdsourced` is data from a community database such as Open Food
/// Facts: label-derived but not verified by RepForge.
enum DataProvenance { verified, userEntered, estimated, crowdsourced }

/// Meal slot for the daily diary.
enum MealSlot { breakfast, lunch, dinner, snack }

/// The nutrients whose absence is tracked individually. Energy is always
/// known, so it is not listed.
enum Nutrient { proteinG, carbsG, fatG, fibreG }

/// Energy and macronutrients for some amount of food.
///
/// Energy is always known. Protein, carbohydrate, fat and fibre are `null`
/// when the source did not state them: unknown is never the same as zero
/// (NUT-007, NUT-021) and is never invented.
@freezed
abstract class NutrientAmounts with _$NutrientAmounts {
  const factory NutrientAmounts({
    required double kcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? fibreG,
  }) = _NutrientAmounts;

  const NutrientAmounts._();

  /// All nutrients known and zero.
  static const zero = NutrientAmounts(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0);

  /// Sum of the KNOWN values of each nutrient; a nutrient is null only when
  /// neither side knows it.
  NutrientAmounts operator +(NutrientAmounts o) => NutrientAmounts(
    kcal: kcal + o.kcal,
    proteinG: _add(proteinG, o.proteinG),
    carbsG: _add(carbsG, o.carbsG),
    fatG: _add(fatG, o.fatG),
    fibreG: _add(fibreG, o.fibreG),
  );

  /// Multiplies every known value by [factor]; unknown stays unknown.
  NutrientAmounts scaled(double factor) => NutrientAmounts(
    kcal: kcal * factor,
    proteinG: proteinG == null ? null : proteinG! * factor,
    carbsG: carbsG == null ? null : carbsG! * factor,
    fatG: fatG == null ? null : fatG! * factor,
    fibreG: fibreG == null ? null : fibreG! * factor,
  );

  /// The value of [nutrient], or null when unknown.
  double? valueOf(Nutrient nutrient) => switch (nutrient) {
    Nutrient.proteinG => proteinG,
    Nutrient.carbsG => carbsG,
    Nutrient.fatG => fatG,
    Nutrient.fibreG => fibreG,
  };

  /// Sums a list with the semantics of [+]; an empty list is [zero]. Use
  /// [NutrientTotals] when the caller needs to know what was unknown.
  static NutrientAmounts sum(Iterable<NutrientAmounts> items) {
    final it = items.iterator;
    if (!it.moveNext()) return zero;
    var total = it.current;
    while (it.moveNext()) {
      total = total + it.current;
    }
    return total;
  }

  static double? _add(double? a, double? b) =>
      (a == null && b == null) ? null : (a ?? 0) + (b ?? 0);
}

/// The total of several [NutrientAmounts] that does not hide gaps: [known] is
/// the sum of the values that were known, and [unknownCount] says how many
/// inputs lacked each nutrient, so the UI can show "80 g, 1 entry unknown"
/// instead of presenting a partial sum as complete.
@immutable
class NutrientTotals {
  /// Builds the totals of [items].
  factory NutrientTotals.of(Iterable<NutrientAmounts> items) {
    final list = items.toList(growable: false);
    final unknown = {
      for (final n in Nutrient.values)
        n: list.where((a) => a.valueOf(n) == null).length,
    };
    return NutrientTotals._(
      known: NutrientAmounts.sum(list),
      inputCount: list.length,
      unknownByNutrient: Map.unmodifiable(unknown),
    );
  }

  /// Adds several totals together: known values are summed and unknown
  /// counts are added per nutrient.
  factory NutrientTotals.combine(Iterable<NutrientTotals> parts) {
    final list = parts.toList(growable: false);
    return NutrientTotals._(
      known: NutrientAmounts.sum(list.map((t) => t.known)),
      inputCount: list.fold(0, (a, t) => a + t.inputCount),
      unknownByNutrient: {
        for (final n in Nutrient.values)
          n: list.fold(0, (a, t) => a + t.unknownCount(n)),
      },
    );
  }

  const NutrientTotals._({
    required this.known,
    required this.inputCount,
    required this.unknownByNutrient,
  });

  /// Totals of nothing: zero everywhere, no unknowns.
  static const empty = NutrientTotals._(
    known: NutrientAmounts.zero,
    inputCount: 0,
    unknownByNutrient: {
      Nutrient.proteinG: 0,
      Nutrient.carbsG: 0,
      Nutrient.fatG: 0,
      Nutrient.fibreG: 0,
    },
  );

  /// Sum of the known values; a nutrient is null only when no input knew it.
  final NutrientAmounts known;

  /// How many inputs were summed.
  final int inputCount;

  /// Unknown count per nutrient (read-only).
  final Map<Nutrient, int> unknownByNutrient;

  /// Number of inputs where [nutrient] was unknown.
  int unknownCount(Nutrient nutrient) => unknownByNutrient[nutrient]!;

  /// Inputs where protein was unknown.
  int get unknownProteinCount => unknownCount(Nutrient.proteinG);

  /// Inputs where carbohydrate was unknown.
  int get unknownCarbsCount => unknownCount(Nutrient.carbsG);

  /// Inputs where fat was unknown.
  int get unknownFatCount => unknownCount(Nutrient.fatG);

  /// Inputs where fibre was unknown.
  int get unknownFibreCount => unknownCount(Nutrient.fibreG);

  /// True when every nutrient was known in every input.
  bool get isComplete => unknownByNutrient.values.every((c) => c == 0);

  /// The totals divided by [divisor] (e.g. an average over days). Unknown
  /// counts are carried over unchanged.
  NutrientTotals dividedBy(double divisor) => NutrientTotals._(
    known: known.scaled(1 / divisor),
    inputCount: inputCount,
    unknownByNutrient: unknownByNutrient,
  );

  @override
  bool operator ==(Object other) =>
      other is NutrientTotals &&
      other.known == known &&
      other.inputCount == inputCount &&
      Nutrient.values.every(
        (n) => other.unknownByNutrient[n] == unknownByNutrient[n],
      );

  @override
  int get hashCode =>
      Object.hash(known, inputCount, Object.hashAll(unknownByNutrient.values));

  @override
  String toString() =>
      'NutrientTotals($known, inputs: $inputCount, '
      'unknown: $unknownByNutrient)';
}

/// Nutrients per 100 g or per 100 ml of a food, with provenance.
@freezed
abstract class NutrientProfile with _$NutrientProfile {
  const factory NutrientProfile({
    required ReferenceUnit per100,
    required NutrientAmounts per100Amounts,
    required DataProvenance provenance,
  }) = _NutrientProfile;

  const NutrientProfile._();

  /// Nutrients for [quantity], which must be in the same reference unit.
  /// Rule NUT-004: value per 100 × quantity ÷ 100.
  Result<NutrientAmounts> forQuantity(Quantity quantity) {
    if (quantity.unit != per100) {
      return Err(
        ValidationError(
          'This food is measured in ${per100.symbol}; '
          'enter the amount in ${per100.symbol}.',
          field: 'quantity',
        ),
      );
    }
    return Ok(per100Amounts.scaled(quantity.amount / 100));
  }
}

/// Validates nutrient inputs for a food (NUT, DAT-002): non-negative, and no
/// more than 100 g of any macronutrient per 100 g. Macros and fibre may be
/// null (unknown); a range is checked only when a value is present.
Result<NutrientAmounts> validateNutrientsPer100({
  required double kcal,
  double? proteinG,
  double? carbsG,
  double? fatG,
  double? fibreG,
}) {
  final values = {
    'kcal': kcal,
    'proteinG': ?proteinG,
    'carbsG': ?carbsG,
    'fatG': ?fatG,
    'fibreG': ?fibreG,
  };
  for (final e in values.entries) {
    if (e.value.isNaN || e.value.isInfinite || e.value < 0) {
      return Err(
        ValidationError('${e.key} must be zero or more.', field: e.key),
      );
    }
  }
  for (final k in ['proteinG', 'carbsG', 'fatG', 'fibreG']) {
    final v = values[k];
    if (v != null && v > 100) {
      return Err(ValidationError('$k cannot exceed 100 g per 100.', field: k));
    }
  }
  if (kcal > 900) {
    return const Err(
      ValidationError('Energy cannot exceed 900 kcal per 100.', field: 'kcal'),
    );
  }
  return Ok(
    NutrientAmounts(
      kcal: kcal,
      proteinG: proteinG,
      carbsG: carbsG,
      fatG: fatG,
      fibreG: fibreG,
    ),
  );
}

/// A named serving of a food, e.g. "1 slice = 35 g".
@freezed
abstract class ServingSize with _$ServingSize {
  const factory ServingSize({
    required String label,
    required Quantity quantity,
  }) = _ServingSize;
}

/// Where a food record originated.
enum FoodSource { userCreated, openFoodFacts, seed }

/// A food in the local database (NUT-004, NUT-005).
@freezed
abstract class Food with _$Food {
  const factory Food({
    required String id,
    required String name,
    required NutrientProfile profile,
    required FoodSource source,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? brand,
    String? barcode,
    @Default(<ServingSize>[]) List<ServingSize> servings,
  }) = _Food;
}

/// One logged item in the diary (NUT-001..003, NUT-010). Nutrients are
/// snapshotted at log time so later edits to the food do not rewrite history.
@freezed
abstract class FoodLogEntry with _$FoodLogEntry {
  const factory FoodLogEntry({
    required String id,

    /// Local calendar day `YYYY-MM-DD` the entry belongs to.
    required String day,
    required MealSlot meal,
    required String name,
    required Quantity quantity,
    required NutrientAmounts nutrients,
    required DataProvenance provenance,
    required DateTime loggedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? foodId,
    String? recipeId,
  }) = _FoodLogEntry;
}

/// Formats a local date as the diary day key.
String dayKey(DateTime local) {
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final d = local.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
