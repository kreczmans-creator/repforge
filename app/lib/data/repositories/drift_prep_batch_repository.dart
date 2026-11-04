import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/planning_mappers.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/planning/prep_batch.dart';

/// drift-backed [PrepBatchRepository] over `prep_batches`.
final class DriftPrepBatchRepository implements PrepBatchRepository {
  DriftPrepBatchRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  static List<PrepBatch> _map(List<PrepBatchRow> rows) => [
    for (final r in rows) ?prepBatchFromRow(r),
  ];

  @override
  Stream<List<PrepBatch>> watchActive() =>
      (_db.select(_db.prepBatches)
            ..where(
              (t) =>
                  t.deletedAt.isNull() &
                  t.portionsRemaining.isBiggerThanValue(0),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.preparedAt)]))
          .watch()
          .map(_map);

  @override
  Stream<List<PrepBatch>> watchForRecipe(String recipeId) =>
      (_db.select(_db.prepBatches)
            ..where((t) => t.deletedAt.isNull() & t.recipeId.equals(recipeId))
            ..orderBy([(t) => OrderingTerm.desc(t.preparedAt)]))
          .watch()
          .map(_map);

  @override
  Future<PrepBatch?> byId(String id) async {
    final row = await (_db.select(
      _db.prepBatches,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : prepBatchFromRow(row);
  }

  @override
  Future<void> upsert(PrepBatch batch) => _db
      .into(_db.prepBatches)
      .insertOnConflictUpdate(
        prepBatchToCompanion(batch, updatedAt: _clock.now().toUtc()),
      );

  @override
  Future<void> delete(String id) async {
    final now = _clock.now().toUtc();
    await (_db.update(
      _db.prepBatches,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      PrepBatchesCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  @override
  Future<ConsumeOutcome> consume(
    String id,
    double portions, {
    Future<void> Function()? alongside,
  }) async {
    // Returning from inside the transaction commits; throwing rolls back.
    return await _db.transaction(() async {
      final row =
          await (_db.select(_db.prepBatches)
                ..where((t) => t.id.equals(id) & t.deletedAt.isNull()))
              .getSingleOrNull();
      if (row == null) return ConsumeOutcome.notFound;
      // Portion counts are exact to 0.01 (spec §2.1): count in integer
      // hundredths so 0.75 then 1.25 from 2 leaves exactly 0, never below 0.
      final left =
          (row.portionsRemaining * 100).round() - (portions * 100).round();
      if (left < 0) return ConsumeOutcome.insufficient;
      final remaining = left / 100;
      await (_db.update(_db.prepBatches)..where((t) => t.id.equals(id))).write(
        PrepBatchesCompanion(
          portionsRemaining: Value(remaining),
          updatedAt: Value(_clock.now().toUtc()),
        ),
      );
      if (alongside != null) await alongside();
      return ConsumeOutcome.consumed;
    });
  }
}
