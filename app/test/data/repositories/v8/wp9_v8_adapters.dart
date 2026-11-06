import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:repforge/data/db/app_database.dart' as v7;
import 'package:repforge/data/db/drift_transactor.dart';
import 'package:repforge/data/repositories/drift_scheduled_workout_repository.dart';
import 'package:repforge/data/repositories/drift_workout_plan_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/data/repositories/v8/drift_library_repository_v8.dart';
import 'package:repforge/data/repositories/v8/v8_exercise_read_port.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';

/// Test wiring of the WP 9 ports over a v8 database file (WP 8 sub-stage
/// 3b-8), so the **real, unchanged** WP 9 use cases run against v8:
/// - exercises: the production-side `V8ExerciseReadPort`
///   (`lib/data/repositories/v8/`), the mapping 3d will reuse;
/// - plans, sessions, scheduled workouts: the **production** WP 9
///   repositories, unchanged, on a second connection to the same file
///   ([TrainingTablesView]). Their tables (`workout_plans`,
///   `plan_exercises`, `workout_sessions`, `session_exercises`,
///   `session_sets`, `scheduled_workouts`) are the same in v7 and v8 except
///   the TRN-020 clause of `session_sets`, which v8 enforces on every write.
///
/// Not production wiring: the production switch is a separate,
/// owner-authorised change.
final class Wp9OverV8 {
  Wp9OverV8._(this.view, this.exercises, Clock clock)
    : plans = DriftWorkoutPlanRepository(view, clock: clock),
      sessions = DriftWorkoutSessionRepository(view, clock: clock),
      scheduled = DriftScheduledWorkoutRepository(view),
      transactor = DriftTransactor(view);

  /// Opens the view on [file]; the v8 exercises come from [library].
  factory Wp9OverV8.open(
    File file,
    DriftLibraryRepositoryV8 library,
    Clock clock,
  ) => Wp9OverV8._(
    TrainingTablesView(NativeDatabase(file)),
    V8ExerciseReadPort(library),
    clock,
  );

  final TrainingTablesView view;
  final V8ExerciseReadPort exercises;
  final WorkoutPlanRepository plans;
  final WorkoutSessionRepository sessions;
  final ScheduledWorkoutRepository scheduled;
  final DriftTransactor transactor;

  Future<void> dispose() => view.close();
}

/// The production v7 database classes opened on a **v8** file, used only
/// for the WP 9 training tables, which v8 keeps unchanged. It never
/// migrates: `schemaVersion` is 8 (the file's), and creation or upgrade
/// throws. Its `exercises` class (v7 columns) is never queried.
final class TrainingTablesView extends v7.AppDatabase {
  TrainingTablesView(super.e);

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) => throw StateError('the view never creates a database'),
    onUpgrade: (m, from, to) =>
        throw StateError('the view never migrates ($from → $to)'),
    beforeOpen: (details) async {
      if (details.wasCreated || details.versionBefore != 8) {
        throw StateError('the view opens only a v8 file');
      }
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );
}

/// An [ExerciseRepository] that reads through [reads] and records writes
/// instead of performing them: for `CopySuppliedExercise`, whose write
/// side (`upsert`) is not part of 3b, so the contract test can compare the
/// exercise WP 9 would store.
final class RecordingExerciseWrites implements ExerciseRepository {
  RecordingExerciseWrites(this.reads);

  final ExerciseRepository reads;
  final List<Exercise> upserts = [];

  @override
  Future<Exercise?> byId(String id) => reads.byId(id);
  @override
  Future<bool> exists(String id) => reads.exists(id);
  @override
  Future<List<Exercise>> search(ExerciseQuery query) => reads.search(query);
  @override
  Stream<List<Exercise>> watchLibrary(ExerciseQuery query) =>
      reads.watchLibrary(query);
  @override
  Stream<List<Exercise>> watchAll({bool includeArchived = false}) =>
      reads.watchAll(includeArchived: includeArchived);
  @override
  Future<void> upsert(Exercise exercise) async => upserts.add(exercise);
  @override
  Future<bool> archive(String id, {required bool archived}) =>
      throw UnsupportedError('not part of the contract');
  @override
  Future<bool> delete(String id) =>
      throw UnsupportedError('not part of the contract');
}
