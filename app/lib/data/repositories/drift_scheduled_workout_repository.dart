import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/mappers/training_mappers.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training_repository.dart';

/// drift-backed [ScheduledWorkoutRepository] over `scheduled_workouts`.
final class DriftScheduledWorkoutRepository
    implements ScheduledWorkoutRepository {
  DriftScheduledWorkoutRepository(this._db);

  final AppDatabase _db;

  SimpleSelectStatement<$ScheduledWorkoutsTable, ScheduledWorkoutRow> _range(
    DateTime from,
    DateTime to,
  ) => _db.select(_db.scheduledWorkouts)
    ..where(
      (t) =>
          t.deletedAt.isNull() &
          t.day.isBiggerOrEqualValue(scheduleDayKey(from)) &
          t.day.isSmallerOrEqualValue(scheduleDayKey(to)),
    )
    ..orderBy([
      (t) => OrderingTerm.asc(t.day),
      (t) => OrderingTerm.asc(t.createdAt),
      (t) => OrderingTerm.asc(t.id),
    ]);

  static List<ScheduledWorkout> _map(List<ScheduledWorkoutRow> rows) => [
    for (final r in rows) ?ScheduleMappers.toEntity(r),
  ];

  @override
  Future<List<ScheduledWorkout>> inRange(DateTime from, DateTime to) async =>
      _map(await _range(from, to).get());

  @override
  Stream<List<ScheduledWorkout>> watchRange(DateTime from, DateTime to) =>
      _range(from, to).watch().map(_map);

  @override
  Future<ScheduledWorkout?> byId(String id) async {
    final row = await (_db.select(
      _db.scheduledWorkouts,
    )..where((t) => t.id.equals(id) & t.deletedAt.isNull())).getSingleOrNull();
    return row == null ? null : ScheduleMappers.toEntity(row);
  }

  @override
  Future<List<ScheduledWorkout>> forPlan(String planId) async => _map(
    await (_db.select(
      _db.scheduledWorkouts,
    )..where((t) => t.planId.equals(planId) & t.deletedAt.isNull())).get(),
  );

  @override
  Future<void> upsert(ScheduledWorkout workout) => _db
      .into(_db.scheduledWorkouts)
      .insertOnConflictUpdate(ScheduleMappers.toRow(workout));
}
