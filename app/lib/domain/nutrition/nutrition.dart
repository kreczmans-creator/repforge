import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/units/units.dart';

part 'nutrition.freezed.dart';

/// Where a nutrient value came from (requirement GEN: provenance labelling).
enum DataProvenance { verified, userEntered, estimated }

/// Meal slot for the daily diary.
enum MealSlot { breakfast, lunch, dinner, snack }

/// Energy and macronutrients for some amount of food. Fibre is optional
/// because many sources omit it; it is never invented.
@freezed
abstract class NutrientAmounts with _$NutrientAmounts {
  const factory NutrientAmounts({
    required double kcal,
    required double proteinG,
    required double carbsG,
    required double fatG,
    double? fibreG,
  }) = _NutrientAmounts;

  const NutrientAmounts._();

  static const zero = NutrientAmounts(kcal: 0, proteinG: 0, carbsG: 0, fatG: 0);

  NutrientAmounts operator +(NutrientAmounts o) => NutrientAmounts(
    kcal: kcal + o.kcal,
    proteinG: proteinG + o.proteinG,
    carbsG: carbsG + o.carbsG,
    fatG: fatG + o.fatG,
    fibreG: (fibreG == null && o.fibreG == null)
        ? null
        : (fibreG ?? 0) + (o.fibreG ?? 0),
  );

  NutrientAmounts scaled(double factor) => NutrientAmounts(
    kcal: kcal * factor,
    proteinG: proteinG * factor,
    carbsG: carbsG * factor,
    fatG: fatG * factor,
    fibreG: fibreG == null ? null : fibreG! * factor,
  );

  /// Sums a list; an empty list is [zero].
  static NutrientAmounts sum(Iterable<NutrientAmounts> items) =>
      items.fold(zero, (a, b) => a + b);
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
/// more than 100 g of any macronutrient per 100 g.
Result<NutrientAmounts> validateNutrientsPer100({
  required double kcal,
  required double proteinG,
  required double carbsG,
  required double fatG,
  double? fibreG,
}) {
  final values = {
    'kcal': kcal,
    'proteinG': proteinG,
    'carbsG': carbsG,
    'fatG': fatG,
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
