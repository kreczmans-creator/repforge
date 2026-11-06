import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';

part 'recipes.freezed.dart';

/// An alternative food for one ingredient (RCP-010): a food link, its
/// quantity and a per-100 nutrient snapshot taken when the substitute was
/// recorded. [per100] carries the provenance and is in the same reference
/// unit as [quantity] (checked by [validateRecipe]).
@freezed
abstract class RecipeSubstitute with _$RecipeSubstitute {
  const factory RecipeSubstitute({
    required String name,
    required Quantity quantity,
    required NutrientProfile per100,
    String? foodId,
  }) = _RecipeSubstitute;

  const RecipeSubstitute._();

  /// Nutrients of the substitute quantity, or null if the units disagree.
  NutrientAmounts? get nutrients => switch (per100.forQuantity(quantity)) {
    Ok(:final value) => value,
    Err() => null,
  };
}

/// One ingredient line. [per100] is a snapshot of the linked food's profile
/// (or null when the ingredient is free text and cannot be calculated).
///
/// [quantity] is the canonical amount in g or ml and the only value used in
/// calculation. [servingLabel] and [servingCount] record how the user entered
/// it ("2 slices" of a food with a 35 g slice); they are display only.
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
    String? servingLabel,
    double? servingCount,
    @Default(<RecipeSubstitute>[]) List<RecipeSubstitute> substitutes,
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

/// Whether a recipe may be frozen (RCP-005). [unknown] is the default: the
/// app makes no safety claim until the user states one (D04 OQ-13).
enum FreezingSuitability { yes, no, unknown }

/// Recipe (RCP-001..). Per-portion nutrition is computed from ingredients when
/// all are calculable and there are no ingredient notes; otherwise the
/// declared estimate is used and labelled.
/// All nutrition rules follow `docs/nutrition-calculation-spec.md` §7.5, §8
/// and §9.
@freezed
abstract class Recipe with _$Recipe {
  const factory Recipe({
    required String id,
    required String name,
    required String category,

    /// Number of portions the recipe makes (greater than 0; a user save needs
    /// 1 or more, RCP-001). Fractional when derived from weights (RCP-008).
    required double portions,
    required List<RecipeIngredient> ingredients,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default('') String description,

    /// Ordered preparation instructions (RCP-003).
    @Default(<String>[]) List<String> prepSteps,

    /// Ordered cooking instructions (RCP-003).
    @Default(<String>[]) List<String> cookSteps,
    int? prepMinutes,
    int? cookMinutes,
    String? storage,
    @Default(FreezingSuitability.unknown) FreezingSuitability freezing,
    String? reheating,
    @Default(false) bool favourite,

    /// Cooked yield W in grams as entered by the user (RCP-008(2)).
    double? totalWeightG,

    /// Weight w of one portion in grams (RCP-008(2)).
    double? portionWeightG,
    NutrientAmounts? declaredPerPortion,
    String? nutritionNote,

    /// Free-text ingredient lines of an imported recipe. Never calculated.
    @Default(<String>[]) List<String> ingredientNotes,
  }) = _Recipe;

  const Recipe._();

  /// Preparation plus cooking minutes (RCP-004(2)); null when neither is
  /// set. An unset part counts as 0.
  int? get totalMinutes => (prepMinutes == null && cookMinutes == null)
      ? null
      : (prepMinutes ?? 0) + (cookMinutes ?? 0);

  bool get allIngredientsCalculable =>
      ingredients.isNotEmpty && ingredients.every((i) => i.nutrients != null);

  /// True when the per-portion nutrition is computed from the ingredients
  /// (spec §8.3): at least one linked ingredient, every one calculable, and
  /// no free-text ingredient notes. A note is an ingredient the app cannot
  /// calculate, so a recipe with notes is incomplete and keeps its declared
  /// values; blank notes are ignored.
  bool get isComputed =>
      allIngredientsCalculable &&
      !ingredientNotes.any((n) => n.trim().isNotEmpty);

  RecipeNutritionSource get nutritionSource => isComputed
      ? RecipeNutritionSource.computed
      : RecipeNutritionSource.declared;

  /// Nutrition per portion, or null when neither computed nor declared.
  ///
  /// This is the value snapshotted into the diary: a nutrient that any
  /// ingredient does not state is null (spec §7.5), never a partial sum.
  /// Use [perPortionTotals] to show the partial sum.
  NutrientAmounts? get perPortion {
    if (portions <= 0) return null;
    if (isComputed) {
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

  /// Per-portion nutrition for the recipe view (spec §7.5, RCP-007(2)): the
  /// sum of the KNOWN values divided by [portions], with how many
  /// ingredients did not state each nutrient, so an incomplete nutrient shows
  /// its partial sum labelled "incomplete" instead of a total presented as
  /// complete. For a declared recipe the single input is the declared
  /// estimate. Null when there is no nutrition or [portions] is not positive.
  NutrientTotals? get perPortionTotals {
    if (portions <= 0) return null;
    if (isComputed) {
      return NutrientTotals.of(ingredients.map((i) => i.nutrients!))
          .dividedBy(portions);
    }
    final declared = declaredPerPortion;
    return declared == null ? null : NutrientTotals.of([declared]);
  }

  /// Total cooked weight W in grams (spec §9.3): the weight the user entered,
  /// otherwise the sum of the ingredient grams when every ingredient is in
  /// grams, otherwise null (a millilitre ingredient has no known mass).
  double? get effectiveTotalWeightG {
    final explicit = totalWeightG;
    if (explicit != null) return explicit;
    if (ingredients.isEmpty) return null;
    var sum = 0.0;
    for (final i in ingredients) {
      if (i.quantity.unit != ReferenceUnit.grams) return null;
      sum += i.quantity.amount;
    }
    return sum;
  }

  /// Portions derived from weights: W ÷ w (spec §9.3, RCP-008(2)); fractional
  /// values are kept. Null unless both weights are known and positive.
  double? get derivedPortions =>
      portionsByWeight(effectiveTotalWeightG, portionWeightG);

  /// Weakest provenance of the computed nutrition (calculation
  /// specification §8): the weakest ingredient snapshot label, or
  /// `estimated` when the recipe falls back to its declared values.
  DataProvenance get provenance {
    if (!isComputed) return DataProvenance.estimated;
    return weakestProvenance(ingredients.map((i) => i.per100!.provenance))!;
  }

  /// Nutrition for [portionCount] portions (spec §9.5): per portion × n.
  /// Null when the recipe has no nutrition.
  NutrientAmounts? nutritionForPortions(double portionCount) =>
      perPortion?.scaled(portionCount);

  /// Alias of [nutritionForPortions].
  NutrientAmounts? forPortions(double portionCount) =>
      nutritionForPortions(portionCount);

  /// Nutrition for [grams] of the cooked recipe (spec §9.5): recipe total ×
  /// grams ÷ W, where the total is per portion × portions (so a nutrient
  /// incomplete in the recipe stays unknown). Null without nutrition or
  /// without a known W.
  NutrientAmounts? nutritionForWeight(double grams) {
    final w = effectiveTotalWeightG;
    if (w == null || w <= 0) return null;
    return perPortion?.scaled(portions * grams / w);
  }

  /// How many portions [grams] of the cooked recipe are (grams × portions ÷
  /// W; 450 g of a 1200 g, 4-portion recipe is 1.5). Null without a known W.
  double? portionsForWeight(double grams) {
    final w = effectiveTotalWeightG;
    if (w == null || w <= 0) return null;
    return portions * grams / w;
  }

  /// A scaled VIEW of this recipe (RCP-009, spec §9.4): every ingredient and
  /// substitute quantity, the portion count and an explicit total weight are
  /// multiplied by [factor], so the per-portion values stay the same.
  /// Nothing is persisted; the saved recipe changes only through "save as
  /// new" or "overwrite". Scaled quantities are kept exactly, not rounded
  /// (spec §9.4), so the per-portion values are unchanged; round only for
  /// display. Fails for a non-positive or non-finite
  /// factor or a quantity beyond the supported range.
  Result<Recipe> scaledBy(double factor) {
    if (factor.isNaN || factor.isInfinite || factor <= 0) {
      return const Err(
        ValidationError(
          'Scale factor must be greater than zero.',
          field: 'factor',
        ),
      );
    }
    Result<Quantity> scale(Quantity q) =>
        Quantity.exact(q.amount * factor, q.unit);
    final scaledIngredients = <RecipeIngredient>[];
    for (final i in ingredients) {
      final q = scale(i.quantity);
      if (q case Err(:final error)) return Err(error);
      final subs = <RecipeSubstitute>[];
      for (final s in i.substitutes) {
        final sq = scale(s.quantity);
        if (sq case Err(:final error)) return Err(error);
        subs.add(s.copyWith(quantity: (sq as Ok<Quantity>).value));
      }
      scaledIngredients.add(
        i.copyWith(
          quantity: (q as Ok<Quantity>).value,
          servingCount: i.servingCount == null
              ? null
              : i.servingCount! * factor,
          substitutes: subs,
        ),
      );
    }
    return Ok(
      copyWith(
        ingredients: scaledIngredients,
        portions: portions * factor,
        totalWeightG: totalWeightG == null ? null : totalWeightG! * factor,
      ),
    );
  }

  /// [scaledBy] the factor that makes the recipe [target] portions
  /// (target ÷ portions, spec §9.4).
  Result<Recipe> scaleToPortions(double target) {
    if (portions <= 0) {
      return const Err(
        ValidationError('The recipe has no portions.', field: 'portions'),
      );
    }
    return scaledBy(target / portions);
  }

  /// [scaledBy] the factor that makes the cooked total [targetG] grams
  /// (target ÷ W, spec §9.4). Fails when W is unknown.
  Result<Recipe> scaleToWeight(double targetG) {
    final w = effectiveTotalWeightG;
    if (w == null || w <= 0) {
      return const Err(
        ValidationError(
          'Enter the recipe total weight to scale by weight.',
          field: 'totalWeightG',
        ),
      );
    }
    return scaledBy(targetG / w);
  }

  /// The recipe as it would be with substitute [substituteIndex] of
  /// ingredient [ingredientId] in place of that ingredient (RCP-010(2)). A
  /// view only: the ingredient keeps its id, position and note and takes the
  /// substitute's food, name, quantity and snapshot.
  Result<Recipe> withSubstitution(String ingredientId, int substituteIndex) {
    RecipeIngredient? ingredient;
    for (final i in ingredients) {
      if (i.id == ingredientId) ingredient = i;
    }
    if (ingredient == null) {
      return const Err(NotFoundError('No such ingredient.'));
    }
    if (substituteIndex < 0 ||
        substituteIndex >= ingredient.substitutes.length) {
      return const Err(NotFoundError('No such substitute.'));
    }
    final sub = ingredient.substitutes[substituteIndex];
    final swapped = ingredient.copyWith(
      name: sub.name,
      foodId: sub.foodId,
      quantity: sub.quantity,
      per100: sub.per100,
      servingLabel: null,
      servingCount: null,
    );
    return Ok(
      copyWith(
        ingredients: [
          for (final i in ingredients)
            if (i.id == ingredientId) swapped else i,
        ],
      ),
    );
  }

  /// Energy per portion with the substitute minus energy per portion of this
  /// recipe (RCP-010(2): "the difference in kcal per portion against the
  /// original"). Null when the ingredient or substitute does not exist, or
  /// when this recipe's nutrition is not computed from its ingredients (a
  /// declared estimate cannot be compared with a computed figure).
  double? kcalPerPortionDelta(String ingredientId, int substituteIndex) {
    if (!isComputed) return null;
    final view = withSubstitution(ingredientId, substituteIndex);
    if (view is! Ok<Recipe>) return null;
    final before = perPortion?.kcal;
    final after = view.value.perPortion?.kcal;
    if (before == null || after == null) return null;
    return after - before;
  }
}

/// Portions from weights (spec §9.3): total weight W ÷ portion weight w.
/// Null unless both are present and positive.
double? portionsByWeight(double? totalWeightG, double? portionWeightG) {
  if (totalWeightG == null || portionWeightG == null) return null;
  if (totalWeightG <= 0 || portionWeightG <= 0) return null;
  return totalWeightG / portionWeightG;
}

/// Validates a recipe for a user save. Returns the recipe unchanged or the
/// first rule broken:
/// - a non-blank name (RCP-001);
/// - 1 or more portions (RCP-001(1));
/// - at least one linked ingredient, or, for a recipe with declared
///   nutrition, at least one ingredient note (RCP-001, WP 7 decision 4);
/// - every ingredient references a food and has a quantity greater than 0 in
///   g or ml matching its food snapshot (RCP-002, decision 4);
/// - substitutes have a name, a positive quantity in their snapshot's unit;
/// - preparation and cooking minutes are whole minutes 0–1440 (RCP-004(1));
/// - total and portion weight greater than 0 when set (RCP-008(2)).
Result<Recipe> validateRecipe(Recipe recipe) {
  ValidationError fail(String message, String field) =>
      ValidationError(message, field: field);
  if (recipe.name.trim().isEmpty) {
    return Err(fail('Enter a recipe name.', 'name'));
  }
  if (recipe.portions.isNaN ||
      recipe.portions.isInfinite ||
      recipe.portions < 1) {
    return Err(fail('A recipe needs 1 or more portions.', 'portions'));
  }
  final hasNotes = recipe.ingredientNotes.any((n) => n.trim().isNotEmpty);
  if (recipe.ingredients.isEmpty &&
      !(hasNotes && recipe.declaredPerPortion != null)) {
    return Err(fail('Add at least one ingredient.', 'ingredients'));
  }
  for (final i in recipe.ingredients) {
    if (i.foodId == null) {
      return Err(fail('"${i.name}" must be linked to a food.', 'ingredients'));
    }
    if (!i.quantity.unit.isMeasure) {
      return Err(fail('"${i.name}" needs an amount in g or ml.', 'quantity'));
    }
    if (i.quantity.amount <= 0) {
      return Err(
        fail('Enter an amount greater than zero for "${i.name}".', 'quantity'),
      );
    }
    final p = i.per100;
    if (p != null && p.per100 != i.quantity.unit) {
      return Err(
        fail(
          '"${i.name}" is measured in ${p.per100.symbol}; '
              'enter the amount in ${p.per100.symbol}.',
          'quantity',
        ),
      );
    }
    final count = i.servingCount;
    if (count != null && (count.isNaN || count.isInfinite || count <= 0)) {
      return Err(
        fail('Serving count for "${i.name}" must be above 0.', 'quantity'),
      );
    }
    for (final s in i.substitutes) {
      if (s.name.trim().isEmpty) {
        return Err(fail('A substitute for "${i.name}" needs a name.', 'name'));
      }
      if (!s.quantity.unit.isMeasure || s.quantity.amount <= 0) {
        return Err(
          fail(
            'Enter an amount in g or ml above zero for substitute '
                '"${s.name}".',
            'quantity',
          ),
        );
      }
      if (s.per100.per100 != s.quantity.unit) {
        return Err(
          fail(
            'Substitute "${s.name}" is measured in '
                '${s.per100.per100.symbol}; enter the amount in '
                '${s.per100.per100.symbol}.',
            'quantity',
          ),
        );
      }
    }
  }
  for (final (minutes, field) in [
    (recipe.prepMinutes, 'prepMinutes'),
    (recipe.cookMinutes, 'cookMinutes'),
  ]) {
    if (minutes != null && (minutes < 0 || minutes > 1440)) {
      return Err(fail('Enter whole minutes from 0 to 1440.', field));
    }
  }
  for (final (grams, field) in [
    (recipe.totalWeightG, 'totalWeightG'),
    (recipe.portionWeightG, 'portionWeightG'),
  ]) {
    if (grams != null && (grams.isNaN || grams.isInfinite || grams <= 0)) {
      return Err(fail('Enter a weight greater than zero.', field));
    }
  }
  return Ok(recipe);
}
