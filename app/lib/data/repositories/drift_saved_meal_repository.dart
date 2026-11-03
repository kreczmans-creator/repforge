import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/group_by.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/saved_meal.dart';
import 'package:repforge/domain/nutrition/saved_meal_repository.dart';
import 'package:repforge/domain/units/units.dart';

/// drift-backed [SavedMealRepository] over `saved_meals` and
/// `saved_meal_items`.
final class DriftSavedMealRepository implements SavedMealRepository {
  DriftSavedMealRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  Future<List<SavedMeal>> _hydrate(List<SavedMealRow> rows) async {
    if (rows.isEmpty) return const [];
    final items = await (_db.select(
      _db.savedMealItems,
    )..where((i) => i.savedMealId.isIn(rows.map((r) => r.id)))).get();
    final byMeal = groupByParent(items, (i) => i.savedMealId);
    return [
      for (final row in rows) _mealFromRow(row, byMeal[row.id] ?? const []),
    ];
  }

  @override
  Stream<List<SavedMeal>> watchAll() {
    final query = _db.select(_db.savedMeals)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return _db
        .customSelect(
          'SELECT 1',
          readsFrom: {_db.savedMeals, _db.savedMealItems},
        )
        .watch()
        .asyncMap((_) async {
          final rows = await query.get();
          return await _hydrate(rows);
        });
  }

  @override
  Future<SavedMeal?> byId(String id) async {
    final rows = await (_db.select(
      _db.savedMeals,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).get();
    return (await _hydrate(rows)).firstOrNull;
  }

  @override
  Future<void> upsert(SavedMeal meal) => _db.transaction(() async {
    await _db
        .into(_db.savedMeals)
        .insertOnConflictUpdate(
          SavedMealsCompanion.insert(
            id: meal.id,
            name: meal.name,
            defaultMeal: Value(meal.defaultMeal?.name),
            createdAt: meal.createdAt,
            updatedAt: meal.updatedAt,
          ),
        );
    await (_db.delete(
      _db.savedMealItems,
    )..where((i) => i.savedMealId.equals(meal.id))).go();
    await _db.batch(
      (b) => b.insertAll(_db.savedMealItems, [
        for (final i in meal.items) _itemToRow(meal.id, i),
      ]),
    );
  });

  @override
  Future<void> delete(String id) async {
    final now = _clock.now().toUtc();
    await (_db.update(
      _db.savedMeals,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      SavedMealsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }
}

SavedMeal _mealFromRow(SavedMealRow row, List<SavedMealItemRow> itemRows) {
  final sorted = [...itemRows]
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  // Lenient: a bad item row is skipped, the meal itself is still returned.
  return SavedMeal(
    id: row.id,
    name: row.name,
    defaultMeal: MealSlot.values.asNameMap()[row.defaultMeal],
    items: [for (final r in sorted) ?_itemFromRow(r)],
    createdAt: row.createdAt,
    updatedAt: row.updatedAt,
  );
}

SavedMealItem? _itemFromRow(SavedMealItemRow r) {
  final unit = ReferenceUnit.values.asNameMap()[r.unit];
  final provenance = DataProvenance.values.asNameMap()[r.provenance];
  if (unit == null || provenance == null) return null;
  final quantity = switch (Quantity.of(r.amount, unit)) {
    Ok(:final value) => value,
    Err() => null,
  };
  if (quantity == null) return null;
  return SavedMealItem(
    id: r.id,
    name: r.name,
    foodId: r.foodId,
    recipeId: r.recipeId,
    quantity: quantity,
    nutrients: NutrientAmounts(
      kcal: r.kcal,
      proteinG: r.proteinG,
      carbsG: r.carbsG,
      fatG: r.fatG,
      fibreG: r.fibreG,
    ),
    provenance: provenance,
    sortOrder: r.sortOrder,
  );
}

SavedMealItemsCompanion _itemToRow(String mealId, SavedMealItem i) =>
    SavedMealItemsCompanion.insert(
      id: i.id,
      savedMealId: mealId,
      name: i.name,
      foodId: Value(i.foodId),
      recipeId: Value(i.recipeId),
      amount: i.quantity.amount,
      unit: i.quantity.unit.name,
      sortOrder: i.sortOrder,
      kcal: i.nutrients.kcal,
      proteinG: i.nutrients.proteinG,
      carbsG: i.nutrients.carbsG,
      fatG: i.nutrients.fatG,
      fibreG: Value(i.nutrients.fibreG),
      provenance: i.provenance.name,
    );
