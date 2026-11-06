import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/recipes/recipe_repository.dart';
import 'package:repforge/domain/recipes/recipes.dart';

/// A recently logged food or recipe, resolved to its current record.
sealed class RecentItem {
  const RecentItem();
}

final class RecentFood extends RecentItem {
  const RecentFood(this.food);
  final Food food;
}

final class RecentRecipe extends RecentItem {
  const RecentRecipe(this.recipe);
  final Recipe recipe;
}

/// Use case: the foods and recipes logged most recently (NUT-014), newest
/// first, one per distinct source. A source that no longer exists (deleted
/// food or recipe) is skipped; history keeps its snapshot regardless.
final class LoadRecentItems {
  const LoadRecentItems({
    required this.log,
    required this.foods,
    required this.recipes,
  });

  /// How many recent items the add flow shows.
  static const defaultLimit = 10;

  /// How many logged sources are examined, so that skipped (deleted) ones
  /// do not leave the list short.
  static const _window = 60;

  final FoodLogRepository log;
  final FoodRepository foods;
  final RecipeRepository recipes;

  Future<Result<List<RecentItem>>> call({int limit = defaultLimit}) async {
    try {
      final sources = await log.recentSources(limit: _window);
      final items = <RecentItem>[];
      for (final s in sources) {
        if (items.length >= limit) break;
        final recipeId = s.recipeId;
        final foodId = s.foodId;
        if (recipeId != null) {
          final r = await recipes.byId(recipeId);
          if (r != null) items.add(RecentRecipe(r));
        } else if (foodId != null) {
          final f = await foods.byId(foodId);
          if (f != null) items.add(RecentFood(f));
        }
      }
      return Ok(items);
    } on Exception catch (e) {
      return Err(StorageError('Could not load recent items.', cause: e));
    }
  }
}
