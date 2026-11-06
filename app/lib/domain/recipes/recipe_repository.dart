import 'package:repforge/domain/recipes/recipes.dart';

abstract interface class RecipeRepository {
  Stream<List<Recipe>> watchAll();
  Future<Recipe?> byId(String id);

  /// True when a recipe with [id] exists, INCLUDING a soft-deleted one (the
  /// legacy importer must not re-create a recipe the user deleted).
  Future<bool> exists(String id);

  /// Inserts or replaces the recipe with its ingredients and substitutes in
  /// one transaction. Upserting a soft-deleted id keeps it deleted.
  Future<void> upsert(Recipe recipe);
  Future<void> delete(String id);
  Future<void> setFavourite(String id, {required bool favourite});
}
