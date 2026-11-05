import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/db/drift_transactor.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_scheduled_workout_repository.dart';
import 'package:repforge/data/repositories/drift_workout_plan_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/record_set.dart';
import 'package:repforge/features/training/application/session_use_cases.dart';

final _now = DateTime.utc(2026, 11, 5, 10);
final _clock = FixedClock(_now);
final _t = DateTime.utc(2026, 11, 1, 9);

LoadKg _kg(double v) => LoadKg.fromStored(v);
SetData _w(double kg, int reps) => SetData.weighted(load: _kg(kg), reps: reps);

Exercise _ex(
  String id, {
  ExerciseType type = ExerciseType.weighted,
  bool archived = false,
}) => Exercise(
  id: id,
  name: 'Name $id',
  type: type,
  category: ExerciseCategory.push,
  primaryMuscle: MuscleGroup.chest,
  createdAt: _t,
  updatedAt: _t,
  archived: archived,
);

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final error) => fail('expected Ok, got ${error.message}'),
};

AppError _err<T>(Result<T> r) {
  expect(r.isErr, isTrue);
  return (r as Err<T>).error;
}

void main() {
  late AppDatabase db;
  late DriftExerciseRepository exercises;
  late DriftWorkoutSessionRepository sessions;
  late DriftWorkoutPlanRepository plans;
  late DriftScheduledWorkoutRepository scheduled;
  late DriftTransactor transactor;
  late RecordSet record;
  var n = 0;
  String newId() => 'id${n++}';

  setUp(() async {
    db = AppDatabase.inMemory();
    n = 0;
    exercises = DriftExerciseRepository(db, clock: _clock);
    sessions = DriftWorkoutSessionRepository(db, clock: _clock);
    plans = DriftWorkoutPlanRepository(db, clock: _clock);
    scheduled = DriftScheduledWorkoutRepository(db);
    transactor = DriftTransactor(db);
    record = RecordSet(exercises: exercises, sessions: sessions, newId: newId);
    for (final id in ['bench', 'squat', 'row', 'fly']) {
      await exercises.upsert(_ex(id));
    }
  });
  tearDown(() => db.close());

  Future<WorkoutSession> reload(String id) async => (await sessions.byId(id))!;

  Future<WorkoutSession> emptySession() async => _ok<WorkoutSession>(
    await StartEmptySession(sessions: sessions, clock: _clock, newId: newId)(
      name: 'Today',
    ),
  );

  AddSessionExercise add() => AddSessionExercise(
    sessions: sessions,
    exercises: exercises,
    newId: newId,
  );

  Future<SessionExercise> addEx(String session, String exercise) async =>
      _ok<SessionExercise>(
        await add()(sessionId: session, exerciseId: exercise),
      );

  Future<SessionSet> rec(
    String session,
    String exercise, {
    SetData? data,
    SetKind kind = SetKind.working,
  }) async => _ok<SessionSet>(
    await record(
      sessionId: session,
      exerciseId: exercise,
      data: data ?? _w(80, 5),
      kind: kind,
    ),
  );

  group('TRN-016 start a session', () {
    test(
      'empty: a session named now with no exercises; blank name defaults',
      () async {
        final s = await emptySession();
        expect(s.name, 'Today');
        expect(s.startedAt, _now);
        expect(s.endedAt, isNull);
        expect(s.exercises, isEmpty);
        final blank = _ok(
          await StartEmptySession(
            sessions: sessions,
            clock: _clock,
            newId: newId,
          )(name: '  '),
        );
        expect(blank.name, 'Workout');
        expect((await reload(s.id)).name, 'Today');
      },
    );

    test(
      'empty: a name over 100 characters is refused and nothing stored',
      () async {
        final r = await StartEmptySession(
          sessions: sessions,
          clock: _clock,
          newId: newId,
        )(name: 'x' * 101);
        expect(_err(r), isA<ValidationError>());
        expect(await db.select(db.workoutSessions).get(), isEmpty);
      },
    );

    StartSessionFromPlan fromPlan() => StartSessionFromPlan(
      plans: plans,
      sessions: sessions,
      exercises: exercises,
      scheduled: scheduled,
      transactor: transactor,
      clock: _clock,
      newId: newId,
    );

    Future<void> savePlan({bool archived = false}) => plans.upsert(
      WorkoutPlan(
        id: 'plan',
        name: 'Push A',
        createdAt: _t,
        updatedAt: _t,
        archived: archived,
        exercises: [
          PlanExercise(
            id: 'pe1',
            exerciseId: 'bench',
            sortOrder: 0,
            targetSets: 3,
            repsMin: 8,
            repsMax: 10,
            targetLoad: _kg(80),
            restSeconds: 120,
          ),
          const PlanExercise(
            id: 'pe2',
            exerciseId: 'fly',
            sortOrder: 1,
            targetSets: 2,
          ),
        ],
      ),
    );

    test('from a plan: entries in plan order, targets and previous '
        'performance as pre-fill data, no sets stored (TRN-016(1))', () async {
      await savePlan();
      // Earlier performance of bench.
      await sessions.upsert(
        WorkoutSession(
          id: 'old',
          name: 'Old',
          startedAt: DateTime.utc(2026, 10, 20),
          createdAt: _t,
          updatedAt: _t,
        ),
      );
      _ok(
        await record(sessionId: 'old', exerciseId: 'bench', data: _w(77.5, 8)),
      );

      final started = _ok(await fromPlan()(planId: 'plan'));
      expect(started.session.name, 'Push A');
      expect(started.session.planId, 'plan');
      expect(started.session.startedAt, _now);
      expect(started.warnings, isEmpty);
      expect(started.prefill.map((p) => p.exerciseId), ['bench', 'fly']);
      final bench = started.prefill.first;
      expect(
        [bench.targetSets, bench.repsMin, bench.repsMax, bench.restSeconds],
        [3, 8, 10, 120],
      );
      expect(bench.targetLoadKg, 80);
      expect(bench.previous, hasLength(1));
      expect(
        bench.previous.single.data,
        isA<WeightedSet>().having((s) => s.load.value, 'load', 77.5),
      );
      expect(started.prefill.last.previous, isEmpty);
      expect(
        started.prefill.map((p) => p.sessionExerciseId),
        started.session.exercises.map((e) => e.id),
      );

      final stored = await reload(started.session.id);
      expect(stored.exercises.map((e) => (e.exerciseId, e.position)), [
        ('bench', 0),
        ('fly', 1),
      ]);
      expect(stored.sets, isEmpty, reason: 'nothing is stored as a set');
    });

    test('from a plan: an archived or deleted exercise is skipped with a '
        'warning and the plan is untouched', () async {
      await savePlan();
      await exercises.archive('fly', archived: true);
      final started = _ok(await fromPlan()(planId: 'plan'));
      expect(started.session.exercises.map((e) => e.exerciseId), ['bench']);
      expect(started.warnings, hasLength(1));
      expect(started.warnings.single.exerciseId, 'fly');
      expect(started.warnings.single.reason, StartSkipReason.archived);
      expect(started.warnings.single.exerciseName, 'Name fly');
      expect((await plans.byId('plan'))!.exercises, hasLength(2));

      await exercises.delete('bench');
      final again = _ok(await fromPlan()(planId: 'plan'));
      expect(again.session.exercises, isEmpty);
      expect(again.warnings.map((w) => w.reason), [
        StartSkipReason.missing,
        StartSkipReason.archived,
      ]);
    });

    test('from a plan: a missing or archived plan is refused, nothing '
        'stored', () async {
      expect(_err(await fromPlan()(planId: 'nope')), isA<NotFoundError>());
      await savePlan(archived: true);
      expect(_err(await fromPlan()(planId: 'plan')), isA<ValidationError>());
      expect(await db.select(db.workoutSessions).get(), isEmpty);
    });

    test('from a plan with a scheduled workout: marked done and linked in '
        'the same step; a wrong one is refused with nothing stored', () async {
      await savePlan();
      final w = ScheduledWorkout(
        id: 'sw',
        day: DateTime(2026, 11, 5),
        sourceDay: DateTime(2026, 11, 5),
        planId: 'plan',
        origin: ScheduleOrigin.date,
        status: ScheduleStatus.planned,
        createdAt: _t,
        updatedAt: _t,
      );
      await scheduled.upsert(w);
      await scheduled.upsert(
        ScheduledWorkout(
          id: 'other',
          day: DateTime(2026, 11, 6),
          sourceDay: DateTime(2026, 11, 6),
          planId: 'different',
          origin: ScheduleOrigin.date,
          status: ScheduleStatus.planned,
          createdAt: _t,
          updatedAt: _t,
        ),
      );
      expect(
        _err(await fromPlan()(planId: 'plan', scheduledWorkoutId: 'other')),
        isA<ValidationError>(),
      );
      expect(
        _err(await fromPlan()(planId: 'plan', scheduledWorkoutId: 'zzz')),
        isA<NotFoundError>(),
      );
      expect(await db.select(db.workoutSessions).get(), isEmpty);

      final started = _ok(
        await fromPlan()(planId: 'plan', scheduledWorkoutId: 'sw'),
      );
      final done = (await scheduled.byId('sw'))!;
      expect(done.status, ScheduleStatus.done);
      expect(done.sessionId, started.session.id);
      // Already done: a second start from it is refused.
      expect(
        _err(await fromPlan()(planId: 'plan', scheduledWorkoutId: 'sw')),
        isA<ValidationError>(),
      );
    });

    test('from a past session: same exercises and order, no sets or notes, '
        'previous performance as pre-fill', () async {
      final past = await emptySession();
      final bench = await addEx(past.id, 'bench');
      await addEx(past.id, 'squat');
      await rec(past.id, 'bench');
      _ok(
        await SetSessionExerciseNote(sessions: sessions)(
          sessionId: past.id,
          sessionExerciseId: bench.id,
          note: 'felt heavy',
        ),
      );
      _ok(
        await SetSessionNote(sessions: sessions, clock: _clock)(
          sessionId: past.id,
          note: 'session note',
        ),
      );
      final started = _ok(
        await StartSessionFromPast(
          sessions: sessions,
          exercises: exercises,
          transactor: transactor,
          clock: _clock,
          newId: newId,
        )(pastSessionId: past.id),
      );
      expect(started.session.id, isNot(past.id));
      expect(started.session.exercises.map((e) => e.exerciseId), [
        'bench',
        'squat',
      ]);
      expect(started.session.exercises.every((e) => e.note == null), isTrue);
      expect(started.session.notes, '');
      expect(started.prefill.first.previous, hasLength(1));
      expect(started.prefill.first.targetSets, isNull);
      final stored = await reload(started.session.id);
      expect(stored.sets, isEmpty);
    });

    test('from a past session: archived exercises are skipped with a '
        'warning; a missing session is refused', () async {
      final past = await emptySession();
      await addEx(past.id, 'bench');
      await addEx(past.id, 'squat');
      await exercises.archive('squat', archived: true);
      final start = StartSessionFromPast(
        sessions: sessions,
        exercises: exercises,
        transactor: transactor,
        clock: _clock,
        newId: newId,
      );
      final started = _ok(await start(pastSessionId: past.id));
      expect(started.session.exercises.map((e) => e.exerciseId), ['bench']);
      expect(started.warnings.single.exerciseId, 'squat');
      expect(_err(await start(pastSessionId: 'zzz')), isA<NotFoundError>());
      // A deleted past session cannot be copied.
      await sessions.delete(past.id);
      expect(_err(await start(pastSessionId: past.id)), isA<NotFoundError>());
    });
  });

  group('FinishSession and EditSessionDetails', () {
    test(
      'finish sets endedAt to now once; a second finish is refused',
      () async {
        final s = await emptySession();
        final finish = FinishSession(sessions: sessions, clock: _clock);
        final done = _ok(await finish(s.id));
        expect(done.endedAt, _now);
        expect((await reload(s.id)).endedAt, _now);
        expect(_err(await finish(s.id)), isA<ValidationError>());
        expect(_err(await finish('zzz')), isA<NotFoundError>());
      },
    );

    test(
      'finish never ends before the start (clock behind the start)',
      () async {
        final late = WorkoutSession(
          id: 'future',
          name: 'F',
          startedAt: _now.add(const Duration(hours: 1)),
          createdAt: _t,
          updatedAt: _t,
        );
        await sessions.upsert(late);
        final done = _ok(
          await FinishSession(sessions: sessions, clock: _clock)('future'),
        );
        expect(done.endedAt, late.startedAt);
      },
    );

    test('edit name and times; refusals store nothing', () async {
      final s = await emptySession();
      final edit = EditSessionDetails(sessions: sessions, clock: _clock);
      final start = DateTime.utc(2026, 11, 4, 18);
      final end = DateTime.utc(2026, 11, 4, 19, 15);
      final updated = _ok(
        await edit(
          sessionId: s.id,
          name: '  Leg day ',
          startedAt: start,
          endedAt: end,
        ),
      );
      expect(updated.name, 'Leg day');
      final stored = await reload(s.id);
      expect(
        [stored.name, stored.startedAt, stored.endedAt],
        ['Leg day', start, end],
      );

      expect(
        _err(await edit(sessionId: s.id, name: ' ', startedAt: start)),
        isA<ValidationError>(),
      );
      expect(
        _err(await edit(sessionId: s.id, name: 'x' * 101, startedAt: start)),
        isA<ValidationError>(),
      );
      expect(
        _err(
          await edit(
            sessionId: s.id,
            name: 'A',
            startedAt: end,
            endedAt: start,
          ),
        ),
        isA<ValidationError>(),
      );
      expect(
        _err(await edit(sessionId: 'zzz', name: 'A', startedAt: start)),
        isA<NotFoundError>(),
      );
      expect((await reload(s.id)).name, 'Leg day');
      // A null end puts the session back in progress.
      final open = _ok(
        await edit(sessionId: s.id, name: 'Leg day', startedAt: start),
      );
      expect(open.endedAt, isNull);
    });
  });

  group('TRN-023 notes', () {
    test('session note: trimmed, 4000 characters accepted, 4001 refused, '
        'blank clears', () async {
      final s = await emptySession();
      final setNote = SetSessionNote(sessions: sessions, clock: _clock);
      _ok(await setNote(sessionId: s.id, note: '  great  '));
      expect((await reload(s.id)).notes, 'great');
      _ok(await setNote(sessionId: s.id, note: 'x' * 4000));
      expect((await reload(s.id)).notes, hasLength(4000));
      expect(
        _err(await setNote(sessionId: s.id, note: 'x' * 4001)),
        isA<ValidationError>(),
      );
      expect((await reload(s.id)).notes, hasLength(4000));
      _ok(await setNote(sessionId: s.id, note: '   '));
      expect((await reload(s.id)).notes, '');
      expect(
        _err(await setNote(sessionId: 'zzz', note: 'a')),
        isA<NotFoundError>(),
      );
    });

    test('exercise note: stored on the entry, 2000+ characters accepted, '
        'over 4000 refused, blank clears', () async {
      final s = await emptySession();
      final e = await addEx(s.id, 'bench');
      final setNote = SetSessionExerciseNote(sessions: sessions);
      _ok(
        await setNote(
          sessionId: s.id,
          sessionExerciseId: e.id,
          note: 'y' * 2500,
        ),
      );
      expect((await reload(s.id)).exercises.single.note, hasLength(2500));
      expect(
        _err(
          await setNote(
            sessionId: s.id,
            sessionExerciseId: e.id,
            note: 'y' * 4001,
          ),
        ),
        isA<ValidationError>(),
      );
      expect((await reload(s.id)).exercises.single.note, hasLength(2500));
      _ok(await setNote(sessionId: s.id, sessionExerciseId: e.id, note: ''));
      expect((await reload(s.id)).exercises.single.note, isNull);
      expect(
        _err(
          await setNote(sessionId: s.id, sessionExerciseId: 'zzz', note: 'a'),
        ),
        isA<NotFoundError>(),
      );
    });
  });

  group('TRN-017 add, remove, replace, reorder', () {
    test('add puts the exercise last before any set exists', () async {
      final s = await emptySession();
      await addEx(s.id, 'bench');
      await addEx(s.id, 'squat');
      final stored = await reload(s.id);
      expect(stored.exercises.map((e) => (e.exerciseId, e.position)), [
        ('bench', 0),
        ('squat', 1),
      ]);
      expect(stored.sets, isEmpty);
    });

    test('add refuses a duplicate, an archived, a missing exercise and a '
        'missing session; nothing stored', () async {
      final s = await emptySession();
      await addEx(s.id, 'bench');
      await exercises.archive('fly', archived: true);
      expect(
        _err(await add()(sessionId: s.id, exerciseId: 'bench')),
        isA<ValidationError>(),
      );
      expect(
        _err(await add()(sessionId: s.id, exerciseId: 'fly')),
        isA<ValidationError>(),
      );
      expect(
        _err(await add()(sessionId: s.id, exerciseId: 'nope')),
        isA<NotFoundError>(),
      );
      expect(
        _err(await add()(sessionId: 'zzz', exerciseId: 'row')),
        isA<NotFoundError>(),
      );
      expect((await reload(s.id)).exercises, hasLength(1));
    });

    test('recording a set joins the entry added earlier and a set for a new '
        'exercise creates its entry last', () async {
      final s = await emptySession();
      final bench = await addEx(s.id, 'bench');
      await addEx(s.id, 'squat');
      final a = await rec(s.id, 'bench');
      final b = await rec(s.id, 'bench');
      final c = await rec(s.id, 'row');
      final stored = await reload(s.id);
      expect(stored.exercises.map((e) => e.exerciseId), [
        'bench',
        'squat',
        'row',
      ]);
      expect(a.sessionExerciseId, bench.id);
      expect([a.setOrder, b.setOrder], [0, 1]);
      expect(
        stored.sets.singleWhere((x) => x.id == c.id).sessionExerciseId,
        stored.exercises.last.id,
      );
      expect(stored.sets.singleWhere((x) => x.id == c.id).exerciseOrder, 2);
    });

    test('remove deletes the entry with its sets, renumbers the rest and '
        'reports the number of sets', () async {
      final s = await emptySession();
      await addEx(s.id, 'bench');
      final squat = await addEx(s.id, 'squat');
      await addEx(s.id, 'row');
      await rec(s.id, 'squat');
      await rec(s.id, 'squat');
      await rec(s.id, 'row');
      final count = _ok(
        await RemoveSessionExercise(sessions: sessions, transactor: transactor)(
          sessionId: s.id,
          sessionExerciseId: squat.id,
        ),
      );
      expect(count, 2);
      final stored = await reload(s.id);
      expect(stored.exercises.map((e) => (e.exerciseId, e.position)), [
        ('bench', 0),
        ('row', 1),
      ]);
      expect(stored.sets.map((x) => x.exerciseId), ['row']);
      expect(stored.sets.single.exerciseOrder, 1);
      expect(await sessions.hasHistory('squat'), isFalse);
    });

    test('remove refuses an entry that is not in the session', () async {
      final s = await emptySession();
      final other = await emptySession();
      final e = await addEx(other.id, 'bench');
      final remove = RemoveSessionExercise(
        sessions: sessions,
        transactor: transactor,
      );
      expect(
        _err(await remove(sessionId: s.id, sessionExerciseId: e.id)),
        isA<NotFoundError>(),
      );
      expect(
        _err(await remove(sessionId: 'zzz', sessionExerciseId: e.id)),
        isA<NotFoundError>(),
      );
      expect((await reload(other.id)).exercises, hasLength(1));
    });

    ReplaceSessionExercise replace() => ReplaceSessionExercise(
      sessions: sessions,
      exercises: exercises,
      transactor: transactor,
      newId: newId,
    );

    test('replace with no sets recorded changes the entry in place and keeps '
        'its note and position (TRN-017(1))', () async {
      final s = await emptySession();
      await addEx(s.id, 'bench');
      final squat = await addEx(s.id, 'squat');
      _ok(
        await SetSessionExerciseNote(sessions: sessions)(
          sessionId: s.id,
          sessionExerciseId: squat.id,
          note: 'keep',
        ),
      );
      final replaced = _ok(
        await replace()(
          sessionId: s.id,
          sessionExerciseId: squat.id,
          newExerciseId: 'row',
        ),
      );
      expect(replaced.id, squat.id);
      final stored = await reload(s.id);
      expect(stored.exercises.map((e) => (e.exerciseId, e.note)), [
        ('bench', null),
        ('row', 'keep'),
      ]);
    });

    test('replace after sets were recorded keeps those sets with the original '
        'exercise; the new exercise gets a new entry right after it', () async {
      final s = await emptySession();
      final bench = await addEx(s.id, 'bench');
      await addEx(s.id, 'squat');
      final done = await rec(s.id, 'bench');
      final replaced = _ok(
        await replace()(
          sessionId: s.id,
          sessionExerciseId: bench.id,
          newExerciseId: 'fly',
        ),
      );
      expect(replaced.exerciseId, 'fly');
      expect(replaced.position, 1);
      var stored = await reload(s.id);
      expect(stored.exercises.map((e) => (e.exerciseId, e.position)), [
        ('bench', 0),
        ('fly', 1),
        ('squat', 2),
      ]);
      expect(stored.sets.single.id, done.id);
      expect(stored.sets.single.exerciseId, 'bench');
      expect(stored.sets.single.sessionExerciseId, bench.id);
      // Further sets go to the new exercise.
      final next = await rec(s.id, 'fly');
      stored = await reload(s.id);
      expect(next.sessionExerciseId, replaced.id);
      expect(stored.sets.map((x) => x.exerciseId), ['bench', 'fly']);
    });

    test('replace refuses a duplicate, the same, an archived, a missing '
        'exercise or entry; nothing changes', () async {
      final s = await emptySession();
      final bench = await addEx(s.id, 'bench');
      await addEx(s.id, 'squat');
      await exercises.archive('fly', archived: true);
      for (final (newId_, matcher) in [
        ('squat', isA<ValidationError>()),
        ('bench', isA<ValidationError>()),
        ('fly', isA<ValidationError>()),
        ('nope', isA<NotFoundError>()),
      ]) {
        expect(
          _err(
            await replace()(
              sessionId: s.id,
              sessionExerciseId: bench.id,
              newExerciseId: newId_,
            ),
          ),
          matcher,
          reason: newId_,
        );
      }
      expect(
        _err(
          await replace()(
            sessionId: s.id,
            sessionExerciseId: 'zzz',
            newExerciseId: 'row',
          ),
        ),
        isA<NotFoundError>(),
      );
      expect((await reload(s.id)).exercises.map((e) => e.exerciseId), [
        'bench',
        'squat',
      ]);
    });

    test(
      'reorder changes the stored order and the sets follow (TRN-017(2))',
      () async {
        final s = await emptySession();
        await addEx(s.id, 'bench');
        await addEx(s.id, 'squat');
        await addEx(s.id, 'row');
        await rec(s.id, 'row');
        await rec(s.id, 'bench');
        final reorder = ReorderSessionExercises(sessions: sessions);
        final out = _ok(await reorder(sessionId: s.id, from: 2, to: 0));
        expect(out.map((e) => (e.exerciseId, e.position)), [
          ('row', 0),
          ('bench', 1),
          ('squat', 2),
        ]);
        final stored = await reload(s.id);
        expect(stored.exercises.map((e) => e.exerciseId), [
          'row',
          'bench',
          'squat',
        ]);
        expect(stored.sets.map((x) => (x.exerciseId, x.exerciseOrder)), [
          ('row', 0),
          ('bench', 1),
        ]);
      },
    );

    test(
      'reorder refuses an index outside the list and stores nothing',
      () async {
        final s = await emptySession();
        await addEx(s.id, 'bench');
        await addEx(s.id, 'squat');
        final reorder = ReorderSessionExercises(sessions: sessions);
        expect(
          _err(await reorder(sessionId: s.id, from: 0, to: 5)),
          isA<ValidationError>(),
        );
        expect(
          _err(await reorder(sessionId: 'zzz', from: 0, to: 1)),
          isA<NotFoundError>(),
        );
        expect((await reload(s.id)).exercises.map((e) => e.exerciseId), [
          'bench',
          'squat',
        ]);
      },
    );
  });

  group('TRN-019 set kind', () {
    test(
      'a set defaults to working and keeps the kind it is recorded with',
      () async {
        final s = await emptySession();
        final a = await rec(s.id, 'bench');
        final b = await rec(s.id, 'bench', kind: SetKind.warmUp);
        final c = await rec(s.id, 'bench', kind: SetKind.failure);
        final stored = (await reload(s.id)).sets;
        expect(a.kind, SetKind.working);
        expect(stored.map((x) => x.kind), [
          SetKind.working,
          SetKind.warmUp,
          SetKind.failure,
        ]);
        expect([b.setOrder, c.setOrder], [1, 2]);
      },
    );
  });

  group('TRN-024 edit and delete', () {
    EditSet edit() => EditSet(exercises: exercises, sessions: sessions);

    test('edit a set: same validation as RecordSet, kind and values change, '
        'entry and order stay', () async {
      final s = await emptySession();
      final set = await rec(s.id, 'bench');
      final updated = _ok(
        await edit()(
          sessionId: s.id,
          setId: set.id,
          data: _w(82.5, 6),
          completed: true,
          kind: SetKind.failure,
          exertion: const Exertion(scale: ExertionScale.rpe, value: 9.5),
          restSeconds: 150,
          note: ' pushed ',
        ),
      );
      expect(updated.kind, SetKind.failure);
      final stored = (await reload(s.id)).sets.single;
      expect(stored.data, _w(82.5, 6));
      expect(stored.note, 'pushed');
      expect(stored.restSeconds, 150);
      expect(stored.exertion?.value, 9.5);
      expect(
        [stored.sessionExerciseId, stored.exerciseOrder, stored.setOrder],
        [set.sessionExerciseId, set.exerciseOrder, set.setOrder],
      );
    });

    test(
      'edit refuses what RecordSet refuses; the stored set is unchanged',
      () async {
        final s = await emptySession();
        final set = await rec(s.id, 'bench');
        Future<Result<SessionSet>> tryEdit({
          SetData? data,
          Exertion? exertion,
          int? rest,
          String? note,
        }) => edit()(
          sessionId: s.id,
          setId: set.id,
          data: data ?? _w(90, 5),
          completed: true,
          exertion: exertion,
          restSeconds: rest,
          note: note,
        );
        expect(
          _err(
            await tryEdit(
              data: const SetData.timed(duration: Duration(seconds: 5)),
            ),
          ),
          isA<ValidationError>(),
          reason: 'type must match the exercise',
        );
        expect(
          _err(await tryEdit(data: _w(90, 0))),
          isA<ValidationError>(),
          reason: 'reps 1-100',
        );
        expect(
          _err(
            await tryEdit(
              exertion: const Exertion(scale: ExertionScale.rpe, value: 11),
            ),
          ),
          isA<ValidationError>(),
          reason: 'validExertion',
        );
        expect(_err(await tryEdit(rest: 4000)), isA<ValidationError>());
        expect(_err(await tryEdit(note: 'n' * 4001)), isA<ValidationError>());
        expect(
          _err(
            await edit()(
              sessionId: s.id,
              setId: 'zzz',
              data: _w(90, 5),
              completed: true,
            ),
          ),
          isA<NotFoundError>(),
        );
        expect(
          _err(
            await edit()(
              sessionId: 'zzz',
              setId: set.id,
              data: _w(90, 5),
              completed: true,
            ),
          ),
          isA<NotFoundError>(),
        );
        expect((await reload(s.id)).sets.single.data, _w(80, 5));
      },
    );

    test('a set of an archived or deleted exercise can still be edited '
        '(history stays editable)', () async {
      final s = await emptySession();
      final set = await rec(s.id, 'bench');
      await exercises.archive('bench', archived: true);
      _ok(
        await edit()(
          sessionId: s.id,
          setId: set.id,
          data: _w(85, 5),
          completed: true,
        ),
      );
      await exercises.delete('bench');
      _ok(
        await edit()(
          sessionId: s.id,
          setId: set.id,
          data: _w(87.5, 5),
          completed: true,
        ),
      );
      expect((await reload(s.id)).sets.single.data, _w(87.5, 5));
      // The type still has to match what the set already is.
      expect(
        _err(
          await edit()(
            sessionId: s.id,
            setId: set.id,
            data: const SetData.timed(duration: Duration(seconds: 5)),
            completed: true,
          ),
        ),
        isA<ValidationError>(),
      );
    });

    test('delete a set removes only that set', () async {
      final s = await emptySession();
      final a = await rec(s.id, 'bench');
      final b = await rec(s.id, 'bench');
      final delete = DeleteSet(sessions: sessions);
      _ok(await delete(sessionId: s.id, setId: a.id));
      expect((await reload(s.id)).sets.map((x) => x.id), [b.id]);
      expect(
        _err(await delete(sessionId: s.id, setId: a.id)),
        isA<NotFoundError>(),
      );
      expect(
        _err(await delete(sessionId: 'zzz', setId: b.id)),
        isA<NotFoundError>(),
      );
      expect((await reload(s.id)).sets, hasLength(1));
    });

    test('delete a session is a soft delete; restore brings it back whole at '
        'any time (TRN-024(2))', () async {
      final s = await emptySession();
      await addEx(s.id, 'bench');
      await rec(s.id, 'bench');
      _ok(await DeleteSession(sessions: sessions)(s.id));
      expect(await sessions.byId(s.id), isNull);
      expect(await sessions.watchAll().first, isEmpty);
      expect(await sessions.hasHistory('bench'), isFalse);
      final row = await db.select(db.workoutSessions).getSingle();
      expect(row.deletedAt, isNotNull, reason: 'nothing is hard-deleted');
      expect(await db.select(db.sessionSets).get(), hasLength(1));
      expect(await db.select(db.sessionExercises).get(), hasLength(1));
      // Deleting again, or editing a deleted session, finds nothing.
      expect(
        _err(await DeleteSession(sessions: sessions)(s.id)),
        isA<NotFoundError>(),
      );

      final restored = _ok(await RestoreSession(sessions: sessions)(s.id));
      expect(restored.sets, hasLength(1));
      expect(restored.exercises, hasLength(1));
      expect(await sessions.hasHistory('bench'), isTrue);
      expect(
        (await db.select(db.workoutSessions).getSingle()).deletedAt,
        isNull,
      );
      // Restoring a session that is not deleted, or unknown, is refused.
      expect(
        _err(await RestoreSession(sessions: sessions)(s.id)),
        isA<NotFoundError>(),
      );
      expect(
        _err(await RestoreSession(sessions: sessions)('zzz')),
        isA<NotFoundError>(),
      );
    });
  });
}
