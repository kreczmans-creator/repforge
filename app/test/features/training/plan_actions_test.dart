import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_workout_plan_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/plan_actions.dart';
import 'package:repforge/features/training/application/plan_use_cases.dart';

final _t = DateTime.utc(2026, 11, 1, 9);
final _clock = FixedClock(DateTime.utc(2026, 11, 5, 10));

Exercise _ex(String id, ExerciseType type) => Exercise(
  id: id,
  name: 'Name $id',
  type: type,
  category: ExerciseCategory.push,
  primaryMuscle: MuscleGroup.chest,
  createdAt: _t,
  updatedAt: _t,
);

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final error) => fail('expected Ok, got ${error.message}'),
};

void main() {
  late AppDatabase db;
  late DriftExerciseRepository exercises;
  late DriftWorkoutPlanRepository plans;
  late DriftWorkoutSessionRepository sessions;
  var n = 0;
  String newId() => 'id${n++}';

  DuplicatePlan duplicate() =>
      DuplicatePlan(plans: plans, clock: _clock, newId: newId);
  SaveSessionAsPlan saveAsPlan() => SaveSessionAsPlan(
    sessions: sessions,
    savePlan: SavePlan(
      plans: plans,
      exercises: exercises,
      clock: _clock,
      newId: newId,
    ),
  );

  setUp(() async {
    db = AppDatabase.inMemory();
    n = 0;
    exercises = DriftExerciseRepository(db, clock: _clock);
    plans = DriftWorkoutPlanRepository(db, clock: _clock);
    sessions = DriftWorkoutSessionRepository(db, clock: _clock);
    await exercises.upsert(_ex('bench', ExerciseType.weighted));
    await exercises.upsert(_ex('plank', ExerciseType.timed));
    await exercises.upsert(_ex('run', ExerciseType.distance));
    await exercises.upsert(_ex('bike', ExerciseType.cardio));
    await exercises.upsert(_ex('pull', ExerciseType.bodyweight));
  });
  tearDown(() => db.close());

  Future<void> sessionWith(
    String id,
    List<({String exerciseId, List<(SetData, int?)> sets})> entries,
  ) async {
    await sessions.upsert(
      WorkoutSession(
        id: id,
        name: 'Push day',
        startedAt: _t,
        createdAt: _t,
        updatedAt: _t,
      ),
    );
    for (var i = 0; i < entries.length; i++) {
      final entryId = '$id-e$i';
      await sessions.addExercise(
        SessionExercise(
          id: entryId,
          sessionId: id,
          exerciseId: entries[i].exerciseId,
          position: i,
        ),
      );
      for (var j = 0; j < entries[i].sets.length; j++) {
        final (data, rest) = entries[i].sets[j];
        await sessions.addSet(
          SessionSet(
            id: '$entryId-s$j',
            sessionId: id,
            exerciseId: entries[i].exerciseId,
            exerciseOrder: i,
            setOrder: j,
            data: data,
            completed: true,
            restSeconds: rest,
            sessionExerciseId: entryId,
          ),
        );
      }
    }
  }

  SetData w(int reps) =>
      SetData.weighted(load: LoadKg.fromStored(60), reps: reps);

  group('DuplicatePlan', () {
    test('copies exercises and prescriptions under new ids, named (copy), '
        'unarchived and unscheduled', () async {
      await plans.upsert(
        WorkoutPlan(
          id: 'p1',
          name: 'Upper A',
          archived: true,
          scheduledWeekdays: const [1, 4],
          createdAt: _t,
          updatedAt: _t,
          exercises: const [
            PlanExercise(
              id: 'pe1',
              exerciseId: 'bench',
              sortOrder: 0,
              targetSets: 4,
              repsMin: 6,
              repsMax: 8,
              restSeconds: 120,
            ),
            PlanExercise(
              id: 'pe2',
              exerciseId: 'plank',
              sortOrder: 1,
              targetSets: 3,
              targetDuration: Duration(seconds: 45),
            ),
          ],
        ),
      );
      final copy = _ok(await duplicate()('p1'));
      expect(copy.id, isNot('p1'));
      expect(copy.name, 'Upper A (copy)');
      expect(copy.archived, isFalse);
      expect(copy.scheduledWeekdays, isEmpty);
      expect(copy.exercises.map((e) => e.id), isNot(contains('pe1')));
      expect(copy.exercises.map((e) => e.id).toSet(), hasLength(2));
      expect(
        copy.exercises.map(
          (e) => (e.exerciseId, e.targetSets, e.repsMin, e.repsMax),
        ),
        [('bench', 4, 6, 8), ('plank', 3, null, null)],
      );
      expect(copy.exercises[0].restSeconds, 120);
      expect(copy.exercises[1].targetDuration, const Duration(seconds: 45));
      final stored = (await plans.byId(copy.id))!;
      expect(stored.name, 'Upper A (copy)');
      // The original is untouched.
      final original = (await plans.byId('p1'))!;
      expect(original.archived, isTrue);
      expect(original.scheduledWeekdays, [1, 4]);
      expect(original.exercises.first.id, 'pe1');
    });

    test('a missing plan is reported', () async {
      final r = await duplicate()('nope');
      expect(r, isA<Err<WorkoutPlan>>());
    });
  });

  group('DeletePlan', () {
    test(
      'removes the plan; a session keeps its planId and still loads',
      () async {
        await plans.upsert(
          WorkoutPlan(id: 'p1', name: 'Upper', createdAt: _t, updatedAt: _t),
        );
        await sessions.upsert(
          WorkoutSession(
            id: 's1',
            name: 'Upper',
            planId: 'p1',
            startedAt: _t,
            endedAt: _t.add(const Duration(hours: 1)),
            createdAt: _t,
            updatedAt: _t,
          ),
        );
        _ok(await DeletePlan(plans: plans)('p1'));
        expect(await plans.byId('p1'), isNull);
        final s = (await sessions.byId('s1'))!;
        expect(s.planId, 'p1');
        expect(s.name, 'Upper');
      },
    );

    test('a missing plan is reported', () async {
      final r = await DeletePlan(plans: plans)('nope');
      expect(r, isA<Err<void>>());
    });
  });

  group('SaveSessionAsPlan', () {
    test(
      'derives sets, rep range and common rest per entry, in order',
      () async {
        await sessionWith('s1', [
          (exerciseId: 'bench', sets: [(w(8), 90), (w(6), 120), (w(7), 120)]),
          (
            exerciseId: 'pull',
            sets: [(const SetData.bodyweight(reps: 10), null)],
          ),
        ]);
        final plan = _ok(await saveAsPlan()('s1'));
        expect(plan.name, 'Push day');
        expect(plan.archived, isFalse);
        expect(plan.exercises.map((e) => e.exerciseId), ['bench', 'pull']);
        final bench = plan.exercises[0];
        expect(bench.targetSets, 3);
        expect(bench.repsMin, 6);
        expect(bench.repsMax, 8);
        expect(bench.restSeconds, 120);
        expect(bench.targetDuration, isNull);
        final pull = plan.exercises[1];
        expect((pull.targetSets, pull.repsMin, pull.repsMax), (1, 10, 10));
        expect(pull.restSeconds, isNull);
        expect((await plans.byId(plan.id))!.exercises, hasLength(2));
      },
    );

    test('timed uses the longest duration, distance the greatest metres, '
        'cardio both', () async {
      await sessionWith('s1', [
        (
          exerciseId: 'plank',
          sets: [
            (const SetData.timed(duration: Duration(seconds: 30)), null),
            (const SetData.timed(duration: Duration(seconds: 50)), null),
          ],
        ),
        (
          exerciseId: 'run',
          sets: [
            (const SetData.distance(metres: 800), null),
            (const SetData.distance(metres: 1200), null),
          ],
        ),
        (
          exerciseId: 'bike',
          sets: [
            (
              const SetData.cardio(
                duration: Duration(minutes: 20),
                metres: 8000,
              ),
              null,
            ),
          ],
        ),
      ]);
      final plan = _ok(await saveAsPlan()('s1', name: 'Mixed'));
      expect(plan.name, 'Mixed');
      final plank = plan.exercises[0];
      expect(plank.targetSets, 2);
      expect(plank.targetDuration, const Duration(seconds: 50));
      expect(plank.repsMin, isNull);
      final run = plan.exercises[1];
      expect(run.targetMetres, 1200);
      expect(run.targetDuration, isNull);
      final bike = plan.exercises[2];
      expect(bike.targetDuration, const Duration(minutes: 20));
      expect(bike.targetMetres, 8000);
    });

    test('entries without sets are skipped', () async {
      await sessionWith('s1', [
        (exerciseId: 'bench', sets: []),
        (exerciseId: 'pull', sets: [(const SetData.bodyweight(reps: 5), null)]),
      ]);
      final plan = _ok(await saveAsPlan()('s1'));
      expect(plan.exercises.map((e) => e.exerciseId), ['pull']);
    });

    test('a session with no sets is refused and no plan is stored', () async {
      await sessionWith('s1', [(exerciseId: 'bench', sets: [])]);
      final r = await saveAsPlan()('s1');
      expect(r, isA<Err<WorkoutPlan>>());
      expect((r as Err<WorkoutPlan>).error, isA<ValidationError>());
      expect(await plans.watchAll().first, isEmpty);
    });

    test('a missing session is reported', () async {
      final r = await saveAsPlan()('nope');
      expect(r, isA<Err<WorkoutPlan>>());
    });
  });
}
