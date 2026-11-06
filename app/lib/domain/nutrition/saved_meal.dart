import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';

part 'saved_meal.freezed.dart';

/// One item of a saved meal. [nutrients] is the snapshot for [quantity] (not
/// per 100), so logging the saved meal copies the item as-is.
@freezed
abstract class SavedMealItem with _$SavedMealItem {
  const factory SavedMealItem({
    required String id,
    required String name,
    required Quantity quantity,
    required NutrientAmounts nutrients,
    required DataProvenance provenance,
    required int sortOrder,
    String? foodId,
    String? recipeId,
  }) = _SavedMealItem;
}

/// A reusable meal: a named list of items that can be logged in one go.
@freezed
abstract class SavedMeal with _$SavedMeal {
  const factory SavedMeal({
    required String id,
    required String name,
    required List<SavedMealItem> items,
    required DateTime createdAt,
    required DateTime updatedAt,
    MealSlot? defaultMeal,
  }) = _SavedMeal;

  const SavedMeal._();

  /// Sum of the known values of the item snapshots, with unknown counts.
  NutrientTotals get nutrientTotals =>
      NutrientTotals.of(items.map((i) => i.nutrients));

  /// Sum of the known values of the item snapshots (see [nutrientTotals]).
  NutrientAmounts get totals => nutrientTotals.known;
}
