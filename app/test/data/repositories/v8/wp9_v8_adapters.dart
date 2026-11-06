import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:repforge/data/db/app_database.dart' as v7;
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:repforge/data/mappers/training_mappers.dart';
import 'package:repforge/data/repositories/v8/drift_library_repository_v8.dart';
import 'package:repforge/domain/core/transactor.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/personal_records.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';

/// Test-only adapters of the WP 9 repository ports over schema v8 (WP 8
/// sub-stage 3b-8). They let the **real, unchanged** WP 9 use cases run
/// against a v8 database, so the contract tests can show that a blocked
/// exercise never enters new work and that WP 9 behaves as before
/// otherwise.
///
/// Not production code and not the 3d integration: the production switch
/// is a separate, owner-authorised change.
///
/// Fidelity: the tables the adapters read and write (`workout_plans`,
/// `plan_exercises`, `workout_sessions`, `session_exercises`,
/// `session_sets`, `scheduled_workouts`) are byte-identical in v7 and v8
/// except the TRN-020 clause of `session_sets`. Rows are therefore mapped
/// with the production `TrainingMappers` and `ScheduleMappers` through the
/// v7 table definitions (a never-opened `AppDatabase` supplies only the
/// table metadata), and the queries mirror the production repositories.
final class Wp9OverV8 {
  Wp9OverV8(this.db, this.library)
    : _meta = v7.AppDatabase(NativeDatabase.memory());

  final AppDatabaseV8 db;
  final DriftLibraryRepositoryV8 library;

  /// v7 table metadata for row mapping only; never opened.
  final v7.AppDatabase _meta;

  late final ExerciseRepository exercises = V8ExerciseRepositoryAdapter(
    library,
  );
  late final WorkoutPlanRepository plans = _V8PlanAdapter(db, _meta);
  late final WorkoutSessionRepository sessions = _V8SessionAdapter(db, _meta);
  late final ScheduledWorkoutRepository scheduled = _V8ScheduleAdapter(
    db,
    _meta,
  );
  late final Transactor transactor = _V8Transactor(db);

  Future<void> dispose() => _meta.close();
}

/// The WP 9 [ExerciseRepository] port over [DriftLibraryRepositoryV8].
///
/// `byId` returns null (WP 9: "missing") for an exercise that is blocked,
/// deleted, unreadable, or not representable as a WP 9 `Exercise` (a target
/// or item outside the WP 9 taxonomy). This mirrors v7, whose mapper hides
/// every such exercise (`TrainingMappers.exerciseToEntity` returns null), and
/// it is the only signal the unchanged WP 9 port offers: `StartSkipReason`
/// knows `archived` and `missing`, not `blocked` (WS6 register C-2: the 3d
/// presentation of a blocked exercise is an owner decision). A retired
/// exercise is presented as archived (unavailable for new work, resolvable
/// for history). Writes are not part of the contract and are refused.
final class V8ExerciseRepositoryAdapter implements ExerciseRepository {
  V8ExerciseRepositoryAdapter(this.library);

  final DriftLibraryRepositoryV8 library;

  @override
  Future<Exercise?> byId(String id) async {
    final stored = await library.byId(id);
    if (stored == null) return null;
    final a = stored.availability;
    if (a.isDeleted || a.isBlocked) return null;
    final e = stored.exercise;
    return e == null ? null : toWp9(e, archived: a.archived || a.isRetired);
  }

  /// The WP 9 view of a v8 exercise; null when a target or item is outside
  /// the WP 9 taxonomy (the 19 muscle ids and 21 equipment ids keep their
  /// names in v8, plan section 4 and IC-806).
  static Exercise? toWp9(CatalogueExercise e, {required bool archived}) {
    final muscles = MuscleGroup.values.asNameMap();
    final items = Equipment.values.asNameMap();
    final primaries = e.primaryTargets;
    if (primaries.isEmpty) return null;
    final primary = muscles[primaries.first.node.value];
    final secondary = [
      for (final t in e.secondaryTargets) muscles[t.node.value],
    ];
    final equipment = [for (final x in e.equipment) items[x.item.value]];
    if (primary == null ||
        secondary.contains(null) ||
        equipment.contains(null)) {
      return null;
    }
    return Exercise(
      id: e.id.value,
      name: e.name,
      type: e.type,
      category: e.category,
      primaryMuscle: primary,
      secondaryMuscles: [for (final m in secondary) m!],
      equipment: [for (final x in equipment) x!],
      aliases: e.aliases,
      supplied: e.isSystem,
      copiedFromId: e.copiedFromId?.value,
      archived: archived,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
  }

  @override
  Future<List<Exercise>> search(ExerciseQuery query) async => filterExercises([
    for (final e in await library.selectable()) ?toWp9(e, archived: false),
  ], query);

  @override
  Stream<List<Exercise>> watchLibrary(ExerciseQuery query) =>
      Stream.fromFuture(search(query));

  @override
  Stream<List<Exercise>> watchAll({bool includeArchived = false}) =>
      Stream.fromFuture(search(const ExerciseQuery()));

  @override
  Future<bool> exists(String id) async => await library.byId(id) != null;

  @override
  Future<void> upsert(Exercise exercise) =>
      throw UnsupportedError('read-only adapter');

  @override
  Future<bool> archive(String id, {required bool archived}) =>
      throw UnsupportedError('read-only adapter');

  @override
  Future<bool> delete(String id) => throw UnsupportedError('read-only adapter');
}

final class _V8Transactor implements Transactor {
  _V8Transactor(this.db);

  final AppDatabaseV8 db;

  @override
  Future<T> run<T>(Future<T> Function() action) => db.transaction(action);
}

final class _V8PlanAdapter implements WorkoutPlanRepository {
  _V8PlanAdapter(this.db, this.meta);

  final AppDatabaseV8 db;
  final v7.AppDatabase meta;

  @override
  Future<WorkoutPlan?> byId(String id) async {
    final row = await db
        .customSelect(
          'SELECT * FROM workout_plans WHERE id = ? AND deleted_at IS NULL',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    final children = await db
        .customSelect(
          'SELECT * FROM plan_exercises WHERE plan_id = ?',
          variables: [Variable<String>(id)],
        )
        .get();
    return TrainingMappers.planToEntity(meta.workoutPlans.map(row.data), [
      for (final c in children) meta.planExercises.map(c.data),
    ]);
  }

  @override
  Future<bool> usesExercise(String exerciseId) async =>
      (await db
              .customSelect(
                'SELECT 1 FROM plan_exercises pe JOIN workout_plans p '
                'ON p.id = pe.plan_id WHERE pe.exercise_id = ? '
                'AND p.deleted_at IS NULL LIMIT 1',
                variables: [Variable<String>(exerciseId)],
              )
              .get())
          .isNotEmpty;

  @override
  Stream<List<WorkoutPlan>> watchAll({bool includeArchived = false}) =>
      throw UnsupportedError('not part of the contract');

  @override
  Future<void> upsert(WorkoutPlan plan) =>
      throw UnsupportedError('not part of the contract');

  @override
  Future<void> delete(String id) =>
      throw UnsupportedError('not part of the contract');
}

final class _V8SessionAdapter implements WorkoutSessionRepository {
  _V8SessionAdapter(this.db, this.meta);

  final AppDatabaseV8 db;
  final v7.AppDatabase meta;

  @override
  Future<void> upsert(WorkoutSession session) => db
      .into(db.workoutSessions)
      .insertOnConflictUpdate(
        RawValuesInsertable(
          TrainingMappers.sessionToRow(session).toColumns(true),
        ),
      );

  @override
  Future<void> addExercise(SessionExercise entry) async {
    final session = await db
        .customSelect(
          'SELECT 1 FROM workout_sessions WHERE id = ? AND deleted_at IS NULL',
          variables: [Variable<String>(entry.sessionId)],
        )
        .getSingleOrNull();
    if (session == null) {
      throw StateError('Session ${entry.sessionId} does not exist.');
    }
    await db
        .into(db.sessionExercises)
        .insert(
          RawValuesInsertable(
            TrainingMappers.sessionExerciseToRow(entry).toColumns(true),
          ),
        );
  }

  @override
  Future<List<SessionSet>> lastPerformance(String exerciseId) async {
    final sessions = await db
        .customSelect(
          'SELECT id FROM workout_sessions WHERE deleted_at IS NULL AND id IN '
          '(SELECT session_id FROM session_sets WHERE exercise_id = ? '
          'AND completed = 1) '
          'ORDER BY started_at DESC, created_at DESC, id ASC LIMIT 1',
          variables: [Variable<String>(exerciseId)],
        )
        .get();
    if (sessions.isEmpty) return const [];
    final rows = await db
        .customSelect(
          'SELECT * FROM session_sets WHERE exercise_id = ? AND completed = 1 '
          'AND session_id = ? ORDER BY exercise_order, set_order',
          variables: [
            Variable<String>(exerciseId),
            Variable<String>(sessions.single.read<String>('id')),
          ],
        )
        .get();
    return [
      for (final r in rows)
        ?TrainingMappers.sessionSetToEntity(meta.sessionSets.map(r.data)),
    ];
  }

  @override
  Future<WorkoutSession?> byId(String id, {bool includeDeleted = false}) async {
    final row = await db
        .customSelect(
          'SELECT * FROM workout_sessions WHERE id = ?'
          '${includeDeleted ? '' : ' AND deleted_at IS NULL'}',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    if (row == null) return null;
    final sets = await db
        .customSelect(
          'SELECT * FROM session_sets WHERE session_id = ?',
          variables: [Variable<String>(id)],
        )
        .get();
    final entries = await db
        .customSelect(
          'SELECT * FROM session_exercises WHERE session_id = ?',
          variables: [Variable<String>(id)],
        )
        .get();
    return TrainingMappers.sessionToEntity(
      meta.workoutSessions.map(row.data),
      [for (final r in sets) meta.sessionSets.map(r.data)],
      [for (final r in entries) meta.sessionExercises.map(r.data)],
    );
  }

  // Not used by the use cases under contract.
  Never _no() => throw UnsupportedError('not part of the contract');

  @override
  Stream<List<WorkoutSession>> watchAll({int limit = 100}) => _no();
  @override
  Future<List<WorkoutSession>> sessionsBetween(DateTime from, DateTime to) =>
      _no();
  @override
  Future<void> delete(String id) => _no();
  @override
  Future<bool> restore(String id) => _no();
  @override
  Future<void> addSet(SessionSet set, {SessionExercise? newEntry}) => _no();
  @override
  Future<bool> updateSet(SessionSet set) => _no();
  @override
  Future<bool> deleteSet(String setId) => _no();
  @override
  Future<bool> updateExercise(SessionExercise entry) => _no();
  @override
  Future<bool> removeExercise(String entryId) => _no();
  @override
  Future<void> setExerciseOrder(String sessionId, List<String> entryIds) =>
      _no();
  @override
  Future<List<SessionSet>> setsForExercise(String exerciseId) => _no();
  @override
  Future<List<PerformedSet>> performedSets(String exerciseId) => _no();
  @override
  Future<bool> hasHistory(String exerciseId) => _no();
  @override
  Future<List<ExerciseSessionHistory>> sessionsForExercise(
    String exerciseId, {
    int? limit,
    int offset = 0,
  }) => _no();
}

final class _V8ScheduleAdapter implements ScheduledWorkoutRepository {
  _V8ScheduleAdapter(this.db, this.meta);

  final AppDatabaseV8 db;
  final v7.AppDatabase meta;

  @override
  Future<ScheduledWorkout?> byId(String id) async {
    final row = await db
        .customSelect(
          'SELECT * FROM scheduled_workouts WHERE id = ? '
          'AND deleted_at IS NULL',
          variables: [Variable<String>(id)],
        )
        .getSingleOrNull();
    return row == null
        ? null
        : ScheduleMappers.toEntity(meta.scheduledWorkouts.map(row.data));
  }

  @override
  Future<void> upsert(ScheduledWorkout workout) => db
      .into(db.scheduledWorkouts)
      .insertOnConflictUpdate(
        RawValuesInsertable(ScheduleMappers.toRow(workout).toColumns(true)),
      );

  @override
  Future<List<ScheduledWorkout>> inRange(DateTime from, DateTime to) =>
      throw UnsupportedError('not part of the contract');
  @override
  Stream<List<ScheduledWorkout>> watchRange(DateTime from, DateTime to) =>
      throw UnsupportedError('not part of the contract');
  @override
  Future<List<ScheduledWorkout>> forPlan(String planId) =>
      throw UnsupportedError('not part of the contract');
}
