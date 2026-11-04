import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';

part 'recipes.freezed.dart';

/// One ingredient line. [per100] is a snapshot of the linked food's profile
/// (or null when the ingredient is free text and cannot be calculated).
@freezed
abstract class RecipeIngredient with _$RecipeIngredient {
  const factory RecipeIngredient({
    required String id,
    required String name,
    required Quantity quantity,
    required int sortOrder,
    String? foodId,
    NutrientProfile? per100,
    String? note,
  }) = _RecipeIngredient;

  const RecipeIngredient._();

  /// Nutrients contributed by this ingredient, or null if not calculable.
  NutrientAmounts? get nutrients {
    final p = per100;
    if (p == null) return null;
    return switch (p.forQuantity(quantity)) {
      Ok(:final value) => value,
      Err() => null,
    };
  }
}

/// How a recipe's per-portion nutrition was obtained.
enum RecipeNutritionSource {
  /// Computed from every ingredient's linked food.
  computed,

  /// Entered or estimated per portion (seed recipes); flagged estimated.
  declared,
}

/// Recipe (RCP-001..). Per-portion nutrition is computed from ingredients when
/// all are calculable; otherwise the declared estimate is used and labelled.
@freezed
abstract class Recipe with _$Recipe {
  const factory Recipe({
    required String id,
    required String name,
    required String category,
    required int portions,
    required List<RecipeIngredient> ingredients,
    required List<String> methodSteps,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default('') String description,
    int? prepMinutes,
    int? cookMinutes,
    String? storage,
    @Default(false) bool freezerFriendly,
    String? reheating,
    @Default(false) bool favourite,
    NutrientAmounts? declaredPerPortion,
    String? nutritionNote,
  }) = _Recipe;

  const Recipe._();

  bool get allIngredientsCalculable =>
      ingredients.isNotEmpty && ingredients.every((i) => i.nutrients != null);

  RecipeNutritionSource get nutritionSource => allIngredientsCalculable
      ? RecipeNutritionSource.computed
      : RecipeNutritionSource.declared;

  /// Nutrition per portion, or null when neither computed nor declared.
  NutrientAmounts? get perPortion {
    if (portions <= 0) return null;
    if (allIngredientsCalculable) {
      // A nutrient that any ingredient does not state stays unknown for the
      // recipe: a partial sum would pass as a complete total.
      final totals = NutrientTotals.of(ingredients.map((i) => i.nutrients!));
      final k = totals.known;
      return NutrientAmounts(
        kcal: k.kcal,
        proteinG: totals.unknownProteinCount > 0 ? null : k.proteinG,
        carbsG: totals.unknownCarbsCount > 0 ? null : k.carbsG,
        fatG: totals.unknownFatCount > 0 ? null : k.fatG,
        fibreG: totals.unknownFibreCount > 0 ? null : k.fibreG,
      ).scaled(1 / portions);
    }
    return declaredPerPortion;
  }

  /// Weakest provenance of the computed nutrition (calculation
  /// specification §8): the weakest ingredient snapshot label, or
  /// `estimated` when the recipe falls back to its declared values.
  DataProvenance get provenance {
    if (!allIngredientsCalculable) return DataProvenance.estimated;
    return weakestProvenance(ingredients.map((i) => i.per100!.provenance))!;
  }

  /// Nutrition for [portionCount] portions (RCP portion scaling).
  NutrientAmounts? forPortions(double portionCount) =>
      perPortion?.scaled(portionCount);
}
