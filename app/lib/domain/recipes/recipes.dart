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
      return NutrientAmounts.sum(ingredients.map((i) => i.nutrients!))
          .scaled(1 / portions);
    }
    return declaredPerPortion;
  }

  DataProvenance get provenance => allIngredientsCalculable
      ? (ingredients.every(
              (i) => i.per100!.provenance == DataProvenance.verified,
            )
            ? DataProvenance.verified
            : DataProvenance.userEntered)
      : DataProvenance.estimated;

  /// Nutrition for [portionCount] portions (RCP portion scaling).
  NutrientAmounts? forPortions(double portionCount) =>
      perPortion?.scaled(portionCount);
}
