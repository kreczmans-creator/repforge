import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/nutrition_mappers.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';

/// drift-backed [FoodLogRepository] over `food_log_entries`.
final class DriftFoodLogRepository implements FoodLogRepository {
  DriftFoodLogRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  static List<FoodLogEntry> _map(List<FoodLogEntryRow> rows) => [
    for (final row in rows) ?logEntryFromRow(row),
  ];

  @override
  Stream<List<FoodLogEntry>> watchDay(String day) =>
      (_db.select(_db.foodLogEntries)
            ..where((t) => t.deletedAt.isNull() & t.day.equals(day))
            ..orderBy([(t) => OrderingTerm.desc(t.loggedAt)]))
          .watch()
          .map(_map);

  @override
  Future<List<FoodLogEntry>> forDays(String fromDay, String toDay) async {
    final rows =
        await (_db.select(_db.foodLogEntries)
              ..where(
                (t) =>
                    t.deletedAt.isNull() &
                    t.day.isBiggerOrEqualValue(fromDay) &
                    t.day.isSmallerOrEqualValue(toDay),
              )
              ..orderBy([
                (t) => OrderingTerm.asc(t.day),
                (t) => OrderingTerm.desc(t.loggedAt),
              ]))
            .get();
    return _map(rows);
  }

  @override
  Future<void> insert(FoodLogEntry entry) =>
      _db.into(_db.foodLogEntries).insert(logEntryToRow(entry));

  @override
  Future<void> insertAll(List<FoodLogEntry> entries) => _db.transaction(
    () => _db.batch(
      (b) => b.insertAll(_db.foodLogEntries, entries.map(logEntryToRow)),
    ),
  );

  @override
  Future<void> update(FoodLogEntry entry) async {
    final now = _clock.now().toUtc();
    final row = logEntryToRow(entry);
    await (_db.update(
      _db.foodLogEntries,
    )..where((t) => t.id.equals(entry.id) & t.deletedAt.isNull())).write(
      FoodLogEntriesCompanion(
        day: row.day,
        meal: row.meal,
        name: row.name,
        foodId: row.foodId,
        recipeId: row.recipeId,
        amount: row.amount,
        unit: row.unit,
        kcal: row.kcal,
        proteinG: row.proteinG,
        carbsG: row.carbsG,
        fatG: row.fatG,
        fibreG: row.fibreG,
        provenance: row.provenance,
        loggedAt: row.loggedAt,
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> delete(String id) async {
    final now = _clock.now().toUtc();
    await (_db.update(
      _db.foodLogEntries,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      FoodLogEntriesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  @override
  Future<List<RecentLogSource>> recentSources({int limit = 50}) async {
    // Read-only over existing columns. An entry is keyed by its recipe when
    // it has one, otherwise by its food. Timestamps are stored as UTC ISO-8601
    // text, so MAX orders them correctly.
    final rows = await _db
        .customSelect(
          'SELECT COALESCE(recipe_id, food_id) AS source_id, '
          '(recipe_id IS NOT NULL) AS is_recipe, '
          'MAX(logged_at) AS last_logged '
          'FROM food_log_entries '
          'WHERE deleted_at IS NULL '
          'AND (recipe_id IS NOT NULL OR food_id IS NOT NULL) '
          'GROUP BY source_id, is_recipe '
          'ORDER BY last_logged DESC, source_id ASC '
          'LIMIT ?1',
          variables: [Variable.withInt(limit)],
          readsFrom: {_db.foodLogEntries},
        )
        .get();
    return [
      for (final row in rows)
        RecentLogSource(
          foodId: row.read<bool>('is_recipe')
              ? null
              : row.read<String>('source_id'),
          recipeId: row.read<bool>('is_recipe')
              ? row.read<String>('source_id')
              : null,
          loggedAt: DateTime.parse(row.read<String>('last_logged')).toUtc(),
        ),
    ];
  }
}
