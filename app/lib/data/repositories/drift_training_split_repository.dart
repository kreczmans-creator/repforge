import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/group_by.dart';
import 'package:repforge/data/mappers/training_mappers.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';

/// drift-backed [TrainingSplitRepository] over `training_splits` and
/// `split_days`.
final class DriftTrainingSplitRepository implements TrainingSplitRepository {
  DriftTrainingSplitRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  @override
  Stream<List<TrainingSplit>> watchAll() {
    final q = _db.select(_db.trainingSplits)
      ..where((t) => t.deletedAt.isNull())
      ..orderBy([
        (t) => OrderingTerm.asc(t.sortOrder),
        (t) => OrderingTerm.asc(t.name),
      ]);
    return q.watch().asyncMap(_load);
  }

  @override
  Future<TrainingSplit?> byId(String id) async {
    final row = await (_db.select(
      _db.trainingSplits,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return null;
    return (await _load([row])).firstOrNull;
  }

  @override
  Future<void> upsert(TrainingSplit split) => _db.transaction(() async {
    await _db
        .into(_db.trainingSplits)
        .insertOnConflictUpdate(TrainingMappers.splitToRow(split));
    await (_db.delete(
      _db.splitDays,
    )..where((t) => t.splitId.equals(split.id))).go();
    await _db.batch(
      (b) => b.insertAll(_db.splitDays, TrainingMappers.splitDaysToRows(split)),
    );
  });

  @override
  Future<void> delete(String id) async {
    final now = _clock.now().toUtc();
    await (_db.update(
      _db.trainingSplits,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      TrainingSplitsCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<List<TrainingSplit>> _load(List<TrainingSplitRow> rows) async {
    if (rows.isEmpty) return const [];
    final days = await (_db.select(
      _db.splitDays,
    )..where((t) => t.splitId.isIn(rows.map((r) => r.id)))).get();
    final bySplit = groupByParent(days, (d) => d.splitId);
    return [
      for (final r in rows)
        TrainingMappers.splitToEntity(r, bySplit[r.id] ?? const []),
    ];
  }
}
