import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/recipes/recipe_repository.dart';
import 'package:repforge/domain/recipes/recipes.dart';

/// Use case: save a recipe (RCP-001, RCP-009(2)).
///
/// Tidies the input (trimmed name, blank steps and notes dropped), validates
/// it with [validateRecipe], stamps `updatedAt` (and `createdAt` for a new
/// recipe) and upserts the recipe with its ingredients and substitutes in one
/// transaction.
final class SaveRecipe {
  const SaveRecipe({
    required this.recipes,
    required this.clock,
    required this.newId,
  });

  final RecipeRepository recipes;
  final Clock clock;
  final IdGenerator newId;

  /// Saves [recipe] over the stored recipe with the same id (overwrite), or
  /// creates it. With [saveAsNew] the recipe is stored as a different record:
  /// new recipe id, new ingredient ids, not a favourite, created now. That is
  /// how a scaled view becomes a recipe and the original stays unchanged.
  Future<Result<Recipe>> call(Recipe recipe, {bool saveAsNew = false}) async {
    final now = clock.now().toUtc();
    var next = _tidy(recipe);
    try {
      if (saveAsNew) {
        next = next.copyWith(
          id: newId(),
          favourite: false,
          createdAt: now,
          ingredients: [
            for (final i in next.ingredients) i.copyWith(id: newId()),
          ],
        );
      } else {
        final existing = await recipes.byId(next.id);
        next = next.copyWith(createdAt: existing?.createdAt ?? now);
      }
      next = next.copyWith(updatedAt: now);
      if (validateRecipe(next) case Err(:final error)) return Err(error);
      await recipes.upsert(next);
    } on Exception catch (e) {
      return Err(StorageError('Could not save the recipe.', cause: e));
    }
    return Ok(next);
  }

  static Recipe _tidy(Recipe r) {
    List<String> clean(List<String> l) => [
      for (final s in l)
        if (s.trim().isNotEmpty) s.trim(),
    ];
    return r.copyWith(
      name: r.name.trim(),
      prepSteps: clean(r.prepSteps),
      cookSteps: clean(r.cookSteps),
      ingredientNotes: clean(r.ingredientNotes),
    );
  }
}

/// Use case: delete a recipe (soft delete). Diary entries logged from it keep
/// their snapshot and their recipe id (RCP-013).
final class DeleteRecipe {
  const DeleteRecipe({required this.recipes});

  final RecipeRepository recipes;

  Future<Result<void>> call(String id) async {
    try {
      if (await recipes.byId(id) == null) {
        return const Err(NotFoundError('That recipe no longer exists.'));
      }
      await recipes.delete(id);
    } on Exception catch (e) {
      return Err(StorageError('Could not delete the recipe.', cause: e));
    }
    return const Ok(null);
  }
}

/// Use case: set or clear the favourite flag (RCP-011).
final class ToggleFavourite {
  const ToggleFavourite({required this.recipes});

  final RecipeRepository recipes;

  /// Flips the stored flag, or sets it to [favourite] when given. Returns
  /// the new value.
  Future<Result<bool>> call(String id, {bool? favourite}) async {
    try {
      final recipe = await recipes.byId(id);
      if (recipe == null) {
        return const Err(NotFoundError('That recipe no longer exists.'));
      }
      final next = favourite ?? !recipe.favourite;
      await recipes.setFavourite(id, favourite: next);
      return Ok(next);
    } on Exception catch (e) {
      return Err(StorageError('Could not update the favourite.', cause: e));
    }
  }
}
