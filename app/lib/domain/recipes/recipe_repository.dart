import 'package:repforge/domain/recipes/recipes.dart';

abstract interface class RecipeRepository {
  Stream<List<Recipe>> watchAll();
  Future<Recipe?> byId(String id);
  Future<void> upsert(Recipe recipe);
  Future<void> delete(String id);
  Future<void> setFavourite(String id, {required bool favourite});
}
