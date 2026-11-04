import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/features/recipes/application/import_legacy_recipes.dart';
import 'package:repforge/features/recipes/application/log_recipe.dart';
import 'package:repforge/features/recipes/application/save_recipe.dart';

/// Asset holding the legacy starter recipes (WP 7 decision 3).
const legacyRecipesAsset = 'assets/seed/legacy_recipes.json';

/// All recipes, ordered by name.
final recipesProvider = StreamProvider<List<Recipe>>(
  (ref) => ref.watch(recipeRepositoryProvider).watchAll(),
);

final saveRecipeProvider = Provider<SaveRecipe>(
  (ref) => SaveRecipe(
    recipes: ref.watch(recipeRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final deleteRecipeProvider = Provider<DeleteRecipe>(
  (ref) => DeleteRecipe(recipes: ref.watch(recipeRepositoryProvider)),
);

final toggleFavouriteProvider = Provider<ToggleFavourite>(
  (ref) => ToggleFavourite(recipes: ref.watch(recipeRepositoryProvider)),
);

final logRecipeProvider = Provider<LogRecipe>(
  (ref) => LogRecipe(
    recipes: ref.watch(recipeRepositoryProvider),
    log: ref.watch(foodLogRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

/// The one-time starter-recipe import. Run from the app bootstrap
/// (`main.dart`), never from a widget.
final importLegacyRecipesProvider = Provider<ImportLegacyRecipes>(
  (ref) => ImportLegacyRecipes(
    recipes: ref.watch(recipeRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
    loadJson: () => rootBundle.loadString(legacyRecipesAsset),
  ),
);
