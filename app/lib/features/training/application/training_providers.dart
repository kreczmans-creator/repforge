import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/exercise_use_cases.dart';
import 'package:repforge/features/training/application/import_exercise_library.dart';
import 'package:repforge/features/training/application/plan_use_cases.dart';
import 'package:repforge/features/training/application/record_set.dart';
import 'package:repforge/features/training/application/records_use_cases.dart';
import 'package:repforge/features/training/application/schedule_use_cases.dart';
import 'package:repforge/features/training/application/session_use_cases.dart';

/// Asset holding the bundled exercise library (WP 8, OQ-09).
const exerciseLibraryAsset = 'assets/seed/exercise_library.json';

/// The library filtered and ordered by a query (TRN-008..012).
// ignore: specify_nonobvious_property_types, the family type is not exported
final exerciseLibraryProvider = StreamProvider.autoDispose
    .family<List<Exercise>, ExerciseQuery>(
      (ref, query) => ref.watch(exerciseRepositoryProvider).watchLibrary(query),
    );

final saveCustomExerciseProvider = Provider<SaveCustomExercise>(
  (ref) => SaveCustomExercise(
    exercises: ref.watch(exerciseRepositoryProvider),
    sessions: ref.watch(workoutSessionRepositoryProvider),
    plans: ref.watch(workoutPlanRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final copySuppliedExerciseProvider = Provider<CopySuppliedExercise>(
  (ref) => CopySuppliedExercise(
    exercises: ref.watch(exerciseRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final archiveExerciseProvider = Provider<ArchiveExercise>(
  (ref) => ArchiveExercise(exercises: ref.watch(exerciseRepositoryProvider)),
);

final recordSetProvider = Provider<RecordSet>(
  (ref) => RecordSet(
    exercises: ref.watch(exerciseRepositoryProvider),
    sessions: ref.watch(workoutSessionRepositoryProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final savePlanProvider = Provider<SavePlan>(
  (ref) => SavePlan(
    plans: ref.watch(workoutPlanRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final saveSplitProvider = Provider<SaveSplit>(
  (ref) => SaveSplit(
    splits: ref.watch(trainingSplitRepositoryProvider),
    plans: ref.watch(workoutPlanRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

/// The one-time library import. Run from the app bootstrap (`main.dart`),
/// never from a widget.
final importExerciseLibraryProvider = Provider<ImportExerciseLibrary>(
  (ref) => ImportExerciseLibrary(
    exercises: ref.watch(exerciseRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
    loadJson: () => rootBundle.loadString(exerciseLibraryAsset),
  ),
);

final startEmptySessionProvider = Provider<StartEmptySession>(
  (ref) => StartEmptySession(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final startSessionFromPlanProvider = Provider<StartSessionFromPlan>(
  (ref) => StartSessionFromPlan(
    plans: ref.watch(workoutPlanRepositoryProvider),
    sessions: ref.watch(workoutSessionRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    scheduled: ref.watch(scheduledWorkoutRepositoryProvider),
    transactor: ref.watch(transactorProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final startSessionFromPastProvider = Provider<StartSessionFromPast>(
  (ref) => StartSessionFromPast(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    transactor: ref.watch(transactorProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final finishSessionProvider = Provider<FinishSession>(
  (ref) => FinishSession(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final editSessionDetailsProvider = Provider<EditSessionDetails>(
  (ref) => EditSessionDetails(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final setSessionNoteProvider = Provider<SetSessionNote>(
  (ref) => SetSessionNote(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final setSessionExerciseNoteProvider = Provider<SetSessionExerciseNote>(
  (ref) => SetSessionExerciseNote(
    sessions: ref.watch(workoutSessionRepositoryProvider),
  ),
);

final addSessionExerciseProvider = Provider<AddSessionExercise>(
  (ref) => AddSessionExercise(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final removeSessionExerciseProvider = Provider<RemoveSessionExercise>(
  (ref) => RemoveSessionExercise(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    transactor: ref.watch(transactorProvider),
  ),
);

final replaceSessionExerciseProvider = Provider<ReplaceSessionExercise>(
  (ref) => ReplaceSessionExercise(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    transactor: ref.watch(transactorProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final reorderSessionExercisesProvider = Provider<ReorderSessionExercises>(
  (ref) => ReorderSessionExercises(
    sessions: ref.watch(workoutSessionRepositoryProvider),
  ),
);

final editSetProvider = Provider<EditSet>(
  (ref) => EditSet(
    exercises: ref.watch(exerciseRepositoryProvider),
    sessions: ref.watch(workoutSessionRepositoryProvider),
  ),
);

final deleteSetProvider = Provider<DeleteSet>(
  (ref) => DeleteSet(sessions: ref.watch(workoutSessionRepositoryProvider)),
);

final deleteSessionProvider = Provider<DeleteSession>(
  (ref) => DeleteSession(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    scheduled: ref.watch(scheduledWorkoutRepositoryProvider),
    transactor: ref.watch(transactorProvider),
    clock: ref.watch(clockProvider),
  ),
);

final restoreSessionProvider = Provider<RestoreSession>(
  (ref) => RestoreSession(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    scheduled: ref.watch(scheduledWorkoutRepositoryProvider),
    transactor: ref.watch(transactorProvider),
    clock: ref.watch(clockProvider),
  ),
);

final scheduleOnDateProvider = Provider<ScheduleOnDate>(
  (ref) => ScheduleOnDate(
    plans: ref.watch(workoutPlanRepositoryProvider),
    scheduled: ref.watch(scheduledWorkoutRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final scheduleWeekdaysProvider = Provider<ScheduleWeekdays>(
  (ref) => ScheduleWeekdays(
    plans: ref.watch(workoutPlanRepositoryProvider),
    scheduled: ref.watch(scheduledWorkoutRepositoryProvider),
    transactor: ref.watch(transactorProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final scheduleSplitCycleProvider = Provider<ScheduleSplitCycle>(
  (ref) => ScheduleSplitCycle(
    splits: ref.watch(trainingSplitRepositoryProvider),
    plans: ref.watch(workoutPlanRepositoryProvider),
    scheduled: ref.watch(scheduledWorkoutRepositoryProvider),
    transactor: ref.watch(transactorProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final moveScheduledWorkoutProvider = Provider<MoveScheduledWorkout>(
  (ref) => MoveScheduledWorkout(
    scheduled: ref.watch(scheduledWorkoutRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final skipScheduledWorkoutProvider = Provider<SkipScheduledWorkout>(
  (ref) => SkipScheduledWorkout(
    scheduled: ref.watch(scheduledWorkoutRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final unskipScheduledWorkoutProvider = Provider<UnskipScheduledWorkout>(
  (ref) => UnskipScheduledWorkout(
    scheduled: ref.watch(scheduledWorkoutRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final scheduledWorkoutsInRangeProvider = Provider<ScheduledWorkoutsInRange>(
  (ref) => ScheduledWorkoutsInRange(
    scheduled: ref.watch(scheduledWorkoutRepositoryProvider),
  ),
);

final getExerciseRecordsProvider = Provider<GetExerciseRecords>(
  (ref) =>
      GetExerciseRecords(sessions: ref.watch(workoutSessionRepositoryProvider)),
);

final getWeeklyVolumeProvider = Provider<GetWeeklyVolume>(
  (ref) => GetWeeklyVolume(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
  ),
);
