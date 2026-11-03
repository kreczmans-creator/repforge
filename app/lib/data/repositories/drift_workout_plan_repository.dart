import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/group_by.dart';
import 'package:repforge/data/mappers/training_mappers.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';

/// drift-backed [WorkoutPlanRepository] over `workout_plans` and
/// `plan_exercises`.
final class DriftWorkoutPlanRepository implements WorkoutPlanRepository {
  DriftWorkoutPlanRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  @override
  Stream<List<WorkoutPlan>> watchAll({bool includeArchived = false}) {
    final q = _db.select(_db.workoutPlans)
      ..where(
        (t) => includeArchived
            ? t.deletedAt.isNull()
            : t.deletedAt.isNull() & t.archived.equals(false),
      )
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    return q.watch().asyncMap(_load);
  }

  @override
  Future<WorkoutPlan?> byId(String id) async {
    final row = await (_db.select(
      _db.workoutPlans,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    if (row == null) return null;
    return (await _load([row])).firstOrNull;
  }

  @override
  Future<void> upsert(WorkoutPlan plan) => _db.transaction(() async {
    await _db
        .into(_db.workoutPlans)
        .insertOnConflictUpdate(TrainingMappers.planToRow(plan));
    await (_db.delete(
      _db.planExercises,
    )..where((t) => t.planId.equals(plan.id))).go();
    await _db.batch(
      (b) => b.insertAll(_db.planExercises, [
        for (final e in plan.exercises)
          TrainingMappers.planExerciseToRow(plan.id, e),
      ]),
    );
  });

  @override
  Future<void> delete(String id) async {
    final now = _clock.now().toUtc();
    await (_db.update(
      _db.workoutPlans,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).write(
      WorkoutPlansCompanion(deletedAt: Value(now), updatedAt: Value(now)),
    );
  }

  Future<List<WorkoutPlan>> _load(List<WorkoutPlanRow> rows) async {
    if (rows.isEmpty) return const [];
    final children =
        await (_db.select(_db.planExercises)
              ..where((t) => t.planId.isIn(rows.map((r) => r.id)))
              ..orderBy([(t) => OrderingTerm.asc(t.sortOrder)]))
            .get();
    final byPlan = groupByParent(children, (c) => c.planId);
    return [
      for (final r in rows)
        ?TrainingMappers.planToEntity(r, byPlan[r.id] ?? const []),
    ];
  }
}
