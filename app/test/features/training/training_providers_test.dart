import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/records_use_cases.dart';
import 'package:repforge/features/training/application/schedule_use_cases.dart';
import 'package:repforge/features/training/application/session_use_cases.dart';
import 'package:repforge/features/training/application/training_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;
  var ids = 0;

  setUp(() {
    db = AppDatabase.inMemory();
    ids = 0;
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(
          FixedClock(DateTime.utc(2026, 11, 5, 9)),
        ),
        idGeneratorProvider.overrideWithValue(() => 'id${++ids}'),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('use cases are wired to the database', () async {
    final created = await container.read(saveCustomExerciseProvider)(
      name: 'Cable Fly',
      type: ExerciseType.weighted,
      category: ExerciseCategory.push,
      primaryMuscle: MuscleGroup.chest,
    );
    final id = (created as Ok<Exercise>).value.id;
    expect(
      (await container.read(copySuppliedExerciseProvider)(sourceId: id)).isErr,
      isTrue,
      reason: 'not supplied',
    );
    final plan = await container.read(savePlanProvider)(
      name: 'Push',
      planExercises: const [],
    );
    expect(plan.isOk, isTrue);
    final planId = (plan as Ok<WorkoutPlan>).value.id;
    expect(
      (await container.read(saveSplitProvider)(
        name: 'One',
        days: [planId, null],
      )).isOk,
      isTrue,
    );
    expect(
      (await container.read(recordSetProvider)(
        sessionId: 'none',
        exerciseId: id,
        data: SetData.weighted(load: LoadKg.fromStored(60), reps: 5),
      )).isErr,
      isTrue,
      reason: 'no such session',
    );
    expect((await container.read(archiveExerciseProvider)(id)).isOk, isTrue);
  });

  test('the library provider streams the filtered exercises', () async {
    await container.read(saveCustomExerciseProvider)(
      name: 'Cable Fly',
      type: ExerciseType.weighted,
      category: ExerciseCategory.push,
      primaryMuscle: MuscleGroup.chest,
    );
    final sub = container.listen(
      exerciseLibraryProvider(const ExerciseQuery(text: 'fly')),
      (_, _) {},
    );
    final list = await container.read(
      exerciseLibraryProvider(const ExerciseQuery(text: 'fly')).future,
    );
    expect(list.single.name, 'Cable Fly');
    sub.close();
    const none = ExerciseQuery(text: 'zzz');
    final sub2 = container.listen(exerciseLibraryProvider(none), (_, _) {});
    expect(await container.read(exerciseLibraryProvider(none).future), isEmpty);
    sub2.close();
  });

  test('WP 9 session, schedule and records use cases are wired', () async {
    final id = ((await container.read(saveCustomExerciseProvider)(
      name: 'Bench',
      type: ExerciseType.weighted,
      category: ExerciseCategory.push,
      primaryMuscle: MuscleGroup.chest,
    )) as Ok<Exercise>).value.id;
    final plan = ((await container.read(savePlanProvider)(
      name: 'Push A',
      planExercises: [
        PlanExercise(
          id: '',
          exerciseId: id,
          sortOrder: 0,
          targetSets: 3,
          repsMin: 8,
          repsMax: 10,
        ),
      ],
      scheduledWeekdays: const [1],
    )) as Ok<WorkoutPlan>).value;
    final scheduled = await container.read(scheduleWeekdaysProvider)(
      planId: plan.id,
      start: DateTime(2026, 11, 2),
    );
    expect((scheduled as Ok<ScheduleOutcome>).value.created, hasLength(8));
    final range = await container.read(scheduledWorkoutsInRangeProvider)(
      DateTime(2026, 11),
      DateTime(2026, 11, 30),
    );
    expect((range as Ok<List<ScheduledWorkout>>).value, hasLength(5));
    final first = range.value.first;

    final started = await container.read(startSessionFromPlanProvider)(
      planId: plan.id,
      scheduledWorkoutId: first.id,
    );
    final session = (started as Ok<StartedSession>).value.session;
    expect(session.exercises.single.exerciseId, id);
    final set = await container.read(recordSetProvider)(
      sessionId: session.id,
      exerciseId: id,
      data: SetData.weighted(load: LoadKg.fromStored(80), reps: 5),
    );
    expect(set.isOk, isTrue);
    final records = await container.read(getExerciseRecordsProvider)(id);
    expect((records as Ok<ExerciseRecords>).value.recordSetIds, hasLength(1));
    expect(
      (await container.read(finishSessionProvider)(session.id)).isOk,
      isTrue,
    );
    expect(
      (await container.read(deleteSessionProvider)(session.id)).isOk,
      isTrue,
    );
    expect(
      (await container.read(restoreSessionProvider)(session.id)).isOk,
      isTrue,
    );
    final empty = await container.read(startEmptySessionProvider)();
    expect(empty.isOk, isTrue);
    for (final p in [
      editSessionDetailsProvider,
      setSessionNoteProvider,
      setSessionExerciseNoteProvider,
      addSessionExerciseProvider,
      removeSessionExerciseProvider,
      replaceSessionExerciseProvider,
      reorderSessionExercisesProvider,
      editSetProvider,
      deleteSetProvider,
      scheduleOnDateProvider,
      scheduleSplitCycleProvider,
      moveScheduledWorkoutProvider,
      skipScheduledWorkoutProvider,
      getWeeklyVolumeProvider,
      startSessionFromPastProvider,
    ]) {
      expect(container.read(p), isNotNull);
    }
  });

  test(
    'the bundled exercise library asset is registered and imports',
    () async {
      final file = File('assets/seed/exercise_library.json');
      final r = await container.read(importExerciseLibraryProvider).call();
      if (!file.existsSync()) {
        expect(r.isErr, isTrue, reason: 'a missing asset is a typed failure');
        return;
      }
      expect(r.isOk, isTrue);
      final all = await container
          .read(exerciseRepositoryProvider)
          .search(const ExerciseQuery());
      expect(all, isNotEmpty);
      expect(all.every((e) => e.supplied), isTrue);
    },
  );
}
