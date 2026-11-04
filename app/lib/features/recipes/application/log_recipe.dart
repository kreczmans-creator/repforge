import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipe_repository.dart';
import 'package:repforge/domain/units/units.dart';

/// Use case: log a recipe to the diary by portions or by weight (RCP-012,
/// calculation specification §9.5).
///
/// The entry stores a nutrient snapshot (editing the recipe later never
/// changes it, RCP-013(1)), the recipe name, and the recipe id (RCP-013(2)).
/// Quantity representation:
/// - by portions: the quantity is the portion count in
///   [ReferenceUnit.portions] (1.5 portions of a 400 kcal recipe is 600
///   kcal), so name and portion count are both on the entry (RCP-012(2));
/// - by weight: the quantity is the grams logged; nutrients are the recipe
///   total × grams ÷ W.
/// Counts and grams are rounded to 0.1 at entry like every quantity (spec
/// §2.1) and the snapshot is calculated from the rounded value.
///
/// Per-portion nutrients that the recipe cannot state completely (§7.5) are
/// null in the snapshot. The provenance is the recipe's.
final class LogRecipe {
  const LogRecipe({
    required this.recipes,
    required this.log,
    required this.clock,
    required this.newId,
  });

  final RecipeRepository recipes;
  final FoodLogRepository log;
  final Clock clock;
  final IdGenerator newId;

  /// Logs [recipeId]. Give exactly one of [portions] and [grams].
  Future<Result<FoodLogEntry>> call({
    required String recipeId,
    required MealSlot meal,
    required String day,
    double? portions,
    double? grams,
    DateTime? loggedAt,
  }) async {
    if ((portions == null) == (grams == null)) {
      return const Err(
        ValidationError('Log either portions or grams.', field: 'quantity'),
      );
    }
    final byPortions = portions != null;
    final quantity = Quantity.of(
      portions ?? grams!,
      byPortions ? ReferenceUnit.portions : ReferenceUnit.grams,
    );
    if (quantity case Err(:final error)) return Err(error);
    final q = (quantity as Ok<Quantity>).value;
    if (q.amount == 0) {
      return const Err(
        ValidationError(
          'Enter an amount greater than zero.',
          field: 'quantity',
        ),
      );
    }
    try {
      final recipe = await recipes.byId(recipeId);
      if (recipe == null) {
        return const Err(NotFoundError('That recipe no longer exists.'));
      }
      final nutrients = byPortions
          ? recipe.nutritionForPortions(q.amount)
          : recipe.nutritionForWeight(q.amount);
      if (nutrients == null) {
        return Err(
          ValidationError(
            byPortions
                ? 'This recipe has no nutrition to log.'
                : 'Enter the recipe total weight to log it by weight.',
            field: byPortions ? 'recipe' : 'totalWeightG',
          ),
        );
      }
      final now = clock.now().toUtc();
      final entry = FoodLogEntry(
        id: newId(),
        day: day,
        meal: meal,
        name: recipe.name,
        recipeId: recipe.id,
        quantity: q,
        nutrients: nutrients,
        provenance: recipe.provenance,
        loggedAt: (loggedAt ?? now).toUtc(),
        createdAt: now,
        updatedAt: now,
      );
      await log.insert(entry);
      return Ok(entry);
    } on Exception catch (e) {
      return Err(StorageError('Could not log the recipe.', cause: e));
    }
  }
}
