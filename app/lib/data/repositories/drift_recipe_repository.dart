import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/group_by.dart';
import 'package:repforge/data/mappers/nutrition_mappers.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/recipes/recipe_repository.dart';
import 'package:repforge/domain/recipes/recipes.dart';

/// drift-backed [RecipeRepository] over `recipes` and `recipe_ingredients`.
final class DriftRecipeRepository implements RecipeRepository {
  DriftRecipeRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  Future<List<Recipe>> _hydrate(List<RecipeRow> rows) async {
    if (rows.isEmpty) return const [];
    final ingredients = await (_db.select(
      _db.recipeIngredients,
    )..where((i) => i.recipeId.isIn(rows.map((r) => r.id)))).get();
    final byRecipe = groupByParent(ingredients, (i) => i.recipeId);
    return [
      for (final row in rows) ?recipeFromRow(row, byRecipe[row.id] ?? const []),
    ];
  }

  @override
  Stream<List<Recipe>> watchAll() {
    final query = _db.select(_db.recipes)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.recipes, _db.recipeIngredients},
        )
        .watch()
        .asyncMap((_) async {
          final rows = await query.get();
          return await _hydrate(rows);
        });
  }

  @override
  Future<Recipe?> byId(String id) async {
    final rows = await (_db.select(
      _db.recipes,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).get();
    return (await _hydrate(rows)).firstOrNull;
  }

  @override
  Future<void> upsert(Recipe recipe) => _db.transaction(() async {
    await _db.into(_db.recipes).insertOnConflictUpdate(recipeToRow(recipe));
    await (_db.delete(
      _db.recipeIngredients,
    )..where((i) => i.recipeId.equals(recipe.id))).go();
    await _db.batch(
      (b) => b.insertAll(_db.recipeIngredients, ingredientRows(recipe)),
    );
  });

  @override
  Future<void> delete(String id) async {
    final now = _clock.now().toUtc();
    await (_db.update(_db.recipes)
          ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
        .write(RecipesCompanion(deletedAt: Value(now), updatedAt: Value(now)));
  }

  @override
  Future<void> setFavourite(String id, {required bool favourite}) async {
    final now = _clock.now().toUtc();
    await (_db.update(
      _db.recipes,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      RecipesCompanion(favourite: Value(favourite), updatedAt: Value(now)),
    );
  }
}
