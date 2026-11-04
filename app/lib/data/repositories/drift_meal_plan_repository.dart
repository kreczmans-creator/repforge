import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/planning_mappers.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/planning/meal_plan.dart';

/// drift-backed [MealPlanRepository] over `meal_plan_items`.
final class DriftMealPlanRepository implements MealPlanRepository {
  DriftMealPlanRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  static List<MealPlanItem> _map(List<MealPlanItemRow> rows) => [
    for (final r in rows) ?mealPlanItemFromRow(r),
  ];

  @override
  Stream<List<MealPlanItem>> watchDay(String day) =>
      (_db.select(_db.mealPlanItems)
            ..where((t) => t.deletedAt.isNull() & t.day.equals(day))
            ..orderBy([
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .watch()
          .map(_map);

  @override
  Stream<List<MealPlanItem>> watchRange(String fromDay, String toDay) =>
      (_db.select(_db.mealPlanItems)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.day.isBiggerOrEqualValue(fromDay) &
                  t.day.isSmallerOrEqualValue(toDay),
            )
            ..orderBy([
              (t) => OrderingTerm.asc(t.day),
              (t) => OrderingTerm.asc(t.sortOrder),
              (t) => OrderingTerm.asc(t.createdAt),
            ]))
          .watch()
          .map(_map);

  @override
  Future<MealPlanItem?> byId(String id) async {
    final row = await (_db.select(
      _db.mealPlanItems,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : mealPlanItemFromRow(row);
  }

  @override
  Future<void> upsert(MealPlanItem item) => _db
      .into(_db.mealPlanItems)
      .insertOnConflictUpdate(
        mealPlanItemToCompanion(item, updatedAt: _clock.now().toUtc()),
      );

  @override
  Future<void> delete(String id) async {
    final now = _clock.now().toUtc();
    await (_db.update(
      _db.mealPlanItems,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      MealPlanItemsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  @override
  Future<void> markEaten(String id, List<String> entryIds) async {
    await (_db.update(
      _db.mealPlanItems,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      MealPlanItemsCompanion(
        eatenEntryId: Value(entryIds.isEmpty ? null : joinEntryIds(entryIds)),
        updatedAt: Value(_clock.now().toUtc()),
      ),
    );
  }
}
