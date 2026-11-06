import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/db/drift_transactor.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_scheduled_workout_repository.dart';
import 'package:repforge/data/repositories/drift_training_split_repository.dart';
import 'package:repforge/data/repositories/drift_workout_plan_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/plan_use_cases.dart';
import 'package:repforge/features/training/application/record_set.dart';
import 'package:repforge/features/training/application/records_use_cases.dart';
import 'package:repforge/features/training/application/schedule_use_cases.dart';
import 'package:repforge/features/training/application/session_use_cases.dart';

import '../../helpers/seed_session.dart';

/// Regression tests for the independent review of WP 9 stage 1 (F1 to F10).

final _now = DateTime.utc(2026, 11, 5, 10);
final _clock = FixedClock(_now);
final _t = DateTime.utc(2026, 11, 1, 9);

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final error) => fail('expected Ok, got ${error.message}'),
};

AppError _err<T>(Result<T> r) => switch (r) {
  Err(:final error) => error,
  Ok() => fail('expected Err'),
};

LoadKg _kg(double v) => LoadKg.fromStored(v);
SetData _w(double kg, int reps) => SetData.weighted(load: _kg(kg), reps: reps);

Exercise _ex(String id, {ExerciseType type = ExerciseType.weighted}) =>
    Exercise(
      id: id,
      name: 'Name $id',
      type: type,
      category: ExerciseCategory.push,
      primaryMuscle: MuscleGroup.chest,
      createdAt: _t,
      updatedAt: _t,
    );

/// A scheduled-workout repository that fails on the [failOn]th upsert.
class _FailingScheduled implements ScheduledWorkoutRepository {
  _FailingScheduled(this.inner, this.failOn);
  final ScheduledWorkoutRepository inner;
  final int failOn;
  int upserts = 0;

  @override
  Future<void> upsert(ScheduledWorkout workout) async {
    upserts++;
    if (upserts == failOn) throw StateError('disk full');
    await inner.upsert(workout);
  }

  @override
  Future<ScheduledWorkout?> byId(String id) => inner.byId(id);
  @override
  Future<List<ScheduledWorkout>> forPlan(String planId) =>
      inner.forPlan(planId);
  @override
  Future<List<ScheduledWorkout>> inRange(DateTime from, DateTime to) =>
      inner.inRange(from, to);
  @override
  Stream<List<ScheduledWorkout>> watchRange(DateTime from, DateTime to) =>
      inner.watchRange(from, to);
}

void main() {
  late AppDatabase db;
  late DriftExerciseRepository exercises;
  late DriftWorkoutSessionRepository sessions;
  late DriftWorkoutPlanRepository plans;
  late DriftTrainingSplitRepository splits;
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
    splits = DriftTrainingSplitRepository(db, clock: _clock);
    scheduled = DriftScheduledWorkoutRepository(db);
    transactor = DriftTransactor(db);
    record = RecordSet(exercises: exercises, sessions: sessions, newId: newId);
    for (final id in ['bench', 'squat', 'row']) {
      await exercises.upsert(_ex(id));
    }
    await exercises.upsert(_ex('plank', type: ExerciseType.timed));
  });
  tearDown(() => db.close());

  Future<WorkoutSession> reload(String id) async => (await sessions.byId(id))!;

  Future<WorkoutSession> emptySession() async => _ok<WorkoutSession>(
    await StartEmptySession(sessions: sessions, clock: _clock, newId: newId)(
      name: 'Today',
    ),
  );

  Future<SessionExercise> addEx(String session, String exercise) async =>
      _ok<SessionExercise>(
        await AddSessionExercise(
          sessions: sessions,
          exercises: exercises,
          newId: newId,
        )(sessionId: session, exerciseId: exercise),
      );

  Future<SessionSet> rec(
    String session,
    String exercise, {
    SetData? data,
    SetKind kind = SetKind.working,
    Exertion? exertion,
    int? restSeconds,
    String? note,
  }) async => _ok<SessionSet>(
    await recordFor(
      record,
      sessions,
      sessionId: session,
      exerciseId: exercise,
      data: data ?? _w(80, 5),
      kind: kind,
      exertion: exertion,
      restSeconds: restSeconds,
      note: note,
    ),
  );

  DeleteSession deleteSession() => DeleteSession(
    sessions: sessions,
    scheduled: scheduled,
    transactor: transactor,
    clock: _clock,
  );

  RestoreSession restoreSession() => RestoreSession(
    sessions: sessions,
    scheduled: scheduled,
    transactor: transactor,
    clock: _clock,
  );

  ScheduleOnDate onDate() => ScheduleOnDate(
    plans: plans,
    scheduled: scheduled,
    clock: _clock,
    newId: newId,
  );

  Future<void> plan(String id, {List<PlanExercise> exercises = const []}) =>
      plans.upsert(
        WorkoutPlan(
          id: id,
          name: 'Plan $id',
          createdAt: _t,
          updatedAt: _t,
          exercises: exercises,
        ),
      );

  Future<void> occurrence(
    String id,
    String planId,
    DateTime day, {
    ScheduleStatus status = ScheduleStatus.planned,
    ScheduleOrigin origin = ScheduleOrigin.date,
    String? sessionId,
  }) => scheduled.upsert(
    ScheduledWorkout(
      id: id,
      day: day,
      sourceDay: day,
      planId: planId,
      origin: origin,
      status: status,
      sessionId: sessionId,
      createdAt: _t,
      updatedAt: _t,
    ),
  );

  group('F1 the same exercise may appear in several entries', () {
    final repeatPlan = [
      const PlanExercise(
        id: 'p1',
        exerciseId: 'bench',
        sortOrder: 0,
        targetSets: 3,
        repsMin: 5,
        repsMax: 5,
      ),
      const PlanExercise(
        id: 'p2',
        exerciseId: 'row',
        sortOrder: 1,
        targetSets: 4,
      ),
      PlanExercise(
        id: 'p3',
        exerciseId: 'bench',
        sortOrder: 2,
        targetSets: 2,
        repsMin: 12,
        repsMax: 15,
        targetLoad: _kg(50),
      ),
    ];

    StartSessionFromPlan fromPlan() => StartSessionFromPlan(
      plans: plans,
      sessions: sessions,
      exercises: exercises,
      scheduled: scheduled,
      transactor: transactor,
      clock: _clock,
      newId: newId,
    );

    test('a plan with the same exercise twice keeps both, each with its own '
        'targets', () async {
      await plan('repeat', exercises: repeatPlan);
      final started = _ok(await fromPlan()(planId: 'repeat'));
      expect(started.warnings, isEmpty);
      expect(started.session.exercises.map((e) => e.exerciseId), [
        'bench',
        'row',
        'bench',
      ]);
      expect(started.prefill.map((p) => (p.exerciseId, p.targetSets)), [
        ('bench', 3),
        ('row', 4),
        ('bench', 2),
      ]);
      expect(started.prefill.last.targetLoadKg, 50);
      expect(
        started.prefill.map((p) => p.sessionExerciseId).toSet(),
        hasLength(3),
      );
      final stored = await reload(started.session.id);
      expect(stored.exercises.map((e) => e.position), [0, 1, 2]);
    });

    test('starting from a past session copies every entry', () async {
      final past = await emptySession();
      await addEx(past.id, 'bench');
      await addEx(past.id, 'row');
      await addEx(past.id, 'bench');
      final started = _ok(
        await StartSessionFromPast(
          sessions: sessions,
          exercises: exercises,
          transactor: transactor,
          clock: _clock,
          newId: newId,
        )(pastSessionId: past.id),
      );
      expect(started.session.exercises.map((e) => e.exerciseId), [
        'bench',
        'row',
        'bench',
      ]);
    });

    test('add accepts an exercise already in the session; replace accepts '
        'one present elsewhere but not the same one', () async {
      final s = await emptySession();
      final first = await addEx(s.id, 'bench');
      final second = await addEx(s.id, 'bench');
      expect(second.id, isNot(first.id));
      expect(second.position, 1);
      final row = await addEx(s.id, 'row');
      final replace = ReplaceSessionExercise(
        sessions: sessions,
        exercises: exercises,
        transactor: transactor,
        newId: newId,
      );
      final changed = _ok(
        await replace(
          sessionId: s.id,
          sessionExerciseId: row.id,
          newExerciseId: 'bench',
        ),
      );
      expect(changed.exerciseId, 'bench');
      expect(
        _err(
          await replace(
            sessionId: s.id,
            sessionExerciseId: first.id,
            newExerciseId: 'bench',
          ),
        ),
        isA<ValidationError>(),
      );
      expect((await reload(s.id)).exercises.map((e) => e.exerciseId), [
        'bench',
        'bench',
        'bench',
      ]);
    });

    test('RecordSet records against the named entry, so two entries of one '
        'exercise keep their own sets, orders and notes', () async {
      final s = await emptySession();
      final a1 = await addEx(s.id, 'bench');
      final b = await addEx(s.id, 'row');
      final a2 = await addEx(s.id, 'bench');
      Future<SessionSet> on(SessionExercise e, SetData d) async =>
          _ok<SessionSet>(
            await record(sessionId: s.id, sessionExerciseId: e.id, data: d),
          );
      final x1 = await on(a1, _w(100, 5));
      final x2 = await on(a2, _w(60, 12));
      final x3 = await on(a2, _w(60, 10));
      await on(b, _w(40, 10));
      final stored = await reload(s.id);
      final byId = {for (final x in stored.sets) x.id: x};
      expect(byId[x1.id]!.sessionExerciseId, a1.id);
      expect(
        [byId[x2.id]!.sessionExerciseId, byId[x2.id]!.exerciseOrder],
        [a2.id, 2],
      );
      expect([x2.setOrder, x3.setOrder], [0, 1]);
      expect(x1.setOrder, 0, reason: 'the first entry is not touched');
      // Removing the second entry leaves the first entry and its set.
      _ok(
        await RemoveSessionExercise(sessions: sessions, transactor: transactor)(
          sessionId: s.id,
          sessionExerciseId: a2.id,
        ),
      );
      expect((await reload(s.id)).sets.map((x) => x.id).toSet(), {
        x1.id,
        (await reload(s.id)).sets.firstWhere((x) => x.exerciseId == 'row').id,
      });
    });

    test('RecordSet validates against the entry exercise and refuses an '
        'unknown entry; nothing is stored', () async {
      final s = await emptySession();
      final plank = await addEx(s.id, 'plank');
      expect(
        _err(
          await record(
            sessionId: s.id,
            sessionExerciseId: plank.id,
            data: _w(80, 5),
          ),
        ),
        isA<ValidationError>(),
      );
      expect(
        _err(
          await record(
            sessionId: s.id,
            sessionExerciseId: 'nope',
            data: _w(80, 5),
          ),
        ),
        isA<NotFoundError>(),
      );
      expect((await reload(s.id)).sets, isEmpty);
    });
  });

  group('F2 EditSet keeps what is not changed', () {
    EditSet edit() => EditSet(exercises: exercises, sessions: sessions);

    test('a warm-up edited with new data stays a warm-up; exertion, rest and '
        'note are kept', () async {
      final s = await emptySession();
      final set = await rec(
        s.id,
        'bench',
        kind: SetKind.warmUp,
        exertion: const Exertion(scale: ExertionScale.rpe, value: 6),
        restSeconds: 75,
        note: 'easy',
      );
      final r = _ok(
        await edit()(
          sessionId: s.id,
          setId: set.id,
          data: _w(60, 8),
          completed: true,
        ),
      );
      expect(r.kind, SetKind.warmUp);
      final stored = (await reload(s.id)).sets.single;
      expect(stored.kind, SetKind.warmUp);
      expect(stored.data, _w(60, 8));
      expect(
        stored.exertion,
        const Exertion(scale: ExertionScale.rpe, value: 6),
      );
      expect(stored.restSeconds, 75);
      expect(stored.note, 'easy');
      // A warm-up still never makes a record.
      expect(
        _ok(await GetExerciseRecords(sessions: sessions)('bench')).recordSetIds,
        isEmpty,
      );
    });

    test('a value within the same scale is accepted; the scale cannot '
        'change and nothing is stored', () async {
      final s = await emptySession();
      final set = await rec(
        s.id,
        'bench',
        exertion: const Exertion(scale: ExertionScale.rpe, value: 7),
      );
      _ok(
        await edit()(
          sessionId: s.id,
          setId: set.id,
          data: _w(80, 5),
          completed: true,
          exertion: const Exertion(scale: ExertionScale.rpe, value: 9),
        ),
      );
      expect(
        (await reload(s.id)).sets.single.exertion,
        const Exertion(scale: ExertionScale.rpe, value: 9),
      );
      final refused = _err(
        await edit()(
          sessionId: s.id,
          setId: set.id,
          data: _w(90, 3),
          completed: true,
          exertion: const Exertion(scale: ExertionScale.rir, value: 2),
        ),
      );
      expect(refused, isA<ValidationError>());
      expect((refused as ValidationError).field, 'exertion');
      final stored = (await reload(s.id)).sets.single;
      expect(stored.data, _w(80, 5), reason: 'nothing was stored');
      expect(
        stored.exertion,
        const Exertion(scale: ExertionScale.rpe, value: 9),
      );
    });

    test('explicit clear flags remove exertion, rest and note; a value with '
        'its clear flag is refused; a set without exertion may take any '
        'scale', () async {
      final s = await emptySession();
      final set = await rec(
        s.id,
        'bench',
        exertion: const Exertion(scale: ExertionScale.rir, value: 2),
        restSeconds: 90,
        note: 'x',
      );
      _ok(
        await edit()(
          sessionId: s.id,
          setId: set.id,
          clearExertion: true,
          clearRest: true,
          clearNote: true,
        ),
      );
      final cleared = (await reload(s.id)).sets.single;
      expect(
        [cleared.exertion, cleared.restSeconds, cleared.note],
        [null, null, null],
      );
      expect(cleared.data, _w(80, 5), reason: 'data kept when omitted');
      _ok(
        await edit()(
          sessionId: s.id,
          setId: set.id,
          exertion: const Exertion(scale: ExertionScale.rpe, value: 8),
        ),
      );
      expect(
        _err(
          await edit()(
            sessionId: s.id,
            setId: set.id,
            note: 'a',
            clearNote: true,
          ),
        ),
        isA<ValidationError>(),
      );
    });
  });

  group('F3 scheduling on a date and un-skip', () {
    test('a skipped occurrence on the date does not block scheduling it '
        'again; a planned or done one does', () async {
      await plan('p');
      final day = DateTime(2026, 11, 9);
      await occurrence('skipped', 'p', day, status: ScheduleStatus.skipped);
      final created = _ok(await onDate()(planId: 'p', date: day));
      expect(created.status, ScheduleStatus.planned);
      final again = _err(await onDate()(planId: 'p', date: day));
      expect(again, isA<ValidationError>());
      expect(again.message, contains('planned or done'));
      await occurrence(
        'done',
        'p',
        DateTime(2026, 11, 10),
        status: ScheduleStatus.done,
      );
      expect(
        _err(await onDate()(planId: 'p', date: DateTime(2026, 11, 10))),
        isA<ValidationError>(),
      );
    });

    test('un-skip makes a skipped occurrence planned; refused when not '
        'skipped or when the date is now taken', () async {
      await plan('p');
      final day = DateTime(2026, 11, 9);
      await occurrence('s1', 'p', day, status: ScheduleStatus.skipped);
      final unskip = UnskipScheduledWorkout(
        scheduled: scheduled,
        clock: _clock,
      );
      expect(_err(await unskip('zzz')), isA<NotFoundError>());
      // The date is taken by another planned occurrence: refused.
      _ok(await onDate()(planId: 'p', date: day));
      expect(_err(await unskip('s1')), isA<ValidationError>());
      expect((await scheduled.byId('s1'))!.status, ScheduleStatus.skipped);
      // Free the date again: the other one is skipped, un-skip works.
      final other = (await scheduled.forPlan('p'))
          .firstWhere((o) => o.id != 's1');
      _ok(
        await SkipScheduledWorkout(scheduled: scheduled, clock: _clock)(
          other.id,
        ),
      );
      final restored = _ok(await unskip('s1'));
      expect(restored.status, ScheduleStatus.planned);
      expect((await scheduled.byId('s1'))!.status, ScheduleStatus.planned);
      // A planned one cannot be un-skipped.
      expect(_err(await unskip('s1')), isA<ValidationError>());
    });
  });

  group('F4 schedule generation is atomic', () {
    test(
      'a failure part-way through a weekday schedule stores nothing',
      () async {
        await plan('p');
        final failing = _FailingScheduled(scheduled, 3);
        final r = await ScheduleWeekdays(
          plans: plans,
          scheduled: failing,
          transactor: transactor,
          clock: _clock,
          newId: newId,
        )(planId: 'p', start: DateTime(2026, 11, 2), weekdays: const [1, 3]);
        expect(_err(r), isA<StorageError>());
        expect(failing.upserts, 3, reason: 'two rows were written before it');
        expect(await scheduled.forPlan('p'), isEmpty);
      },
    );

    test('a failure part-way through a split cycle stores nothing', () async {
      await plan('a');
      await plan('b');
      final split = _ok(
        await SaveSplit(
          splits: splits,
          plans: plans,
          clock: _clock,
          newId: newId,
        )(name: 'S', days: ['a', 'b', null]),
      );
      final failing = _FailingScheduled(scheduled, 5);
      final r = await ScheduleSplitCycle(
        splits: splits,
        plans: plans,
        scheduled: failing,
        transactor: transactor,
        clock: _clock,
        newId: newId,
      )(splitId: split.id, start: DateTime(2026, 11, 2));
      expect(_err(r), isA<StorageError>());
      expect(await scheduled.forPlan('a'), isEmpty);
      expect(await scheduled.forPlan('b'), isEmpty);
    });
  });

  group('F5 a UTC instant is dated by the local calendar', () {
    test('scheduleDate and scheduleDayKey convert UTC to local first', () {
      final instant = DateTime.utc(2026, 11, 5, 23, 30);
      final local = instant.toLocal();
      expect(
        scheduleDate(instant),
        DateTime(local.year, local.month, local.day),
      );
      expect(
        scheduleDayKey(instant),
        scheduleDayKey(DateTime(local.year, local.month, local.day)),
      );
      // A local value is taken as it is.
      final wall = DateTime(2026, 11, 5, 23, 30);
      expect(scheduleDate(wall), DateTime(2026, 11, 5));
    });
  });

  group('F6 weekly volume covers whole weeks', () {
    test('a mid-week range returns the full weeks it touches', () async {
      await sessions.upsert(
        WorkoutSession(
          id: 'mon',
          name: 'Mon',
          startedAt: DateTime(2026, 11, 2, 18).toUtc(),
          createdAt: _t,
          updatedAt: _t,
        ),
      );
      await sessions.upsert(
        WorkoutSession(
          id: 'fri',
          name: 'Fri',
          startedAt: DateTime(2026, 11, 6, 18).toUtc(),
          createdAt: _t,
          updatedAt: _t,
        ),
      );
      await rec('mon', 'bench');
      await rec('fri', 'bench');
      final volume = GetWeeklyVolume(sessions: sessions, exercises: exercises);
      // Wednesday to Thursday: touches the week of Mon 2 Nov only.
      final weeks = _ok(
        await volume(
          from: DateTime(2026, 11, 4),
          to: DateTime(2026, 11, 5),
          settings: const AppSettings(),
        ),
      );
      expect(weeks.map((w) => w.weekStart), [DateTime(2026, 11, 2)]);
      expect(weeks.single.total.loadKg, 800, reason: 'both sessions');
      // A range ending exactly on a week start does not add that week.
      final exact = _ok(
        await volume(
          from: DateTime(2026, 11, 2),
          to: DateTime(2026, 11, 9),
          settings: const AppSettings(),
        ),
      );
      expect(exact.map((w) => w.weekStart), [DateTime(2026, 11, 2)]);
    });
  });

  group('F7 personal record ties between sessions', () {
    test('equal start times: the earlier-created session holds the PR, '
        'whatever the ids', () async {
      final at = DateTime.utc(2026, 11, 3, 18);
      // Ids sort the other way round to the creation order.
      await sessions.upsert(
        WorkoutSession(
          id: 'zzz-first',
          name: 'First',
          startedAt: at,
          createdAt: DateTime.utc(2026, 11, 3, 18, 0, 1),
          updatedAt: _t,
        ),
      );
      await sessions.upsert(
        WorkoutSession(
          id: 'aaa-second',
          name: 'Second',
          startedAt: at,
          createdAt: DateTime.utc(2026, 11, 3, 18, 0, 5),
          updatedAt: _t,
        ),
      );
      final first = await rec('zzz-first', 'bench', data: _w(100, 5));
      final second = await rec('aaa-second', 'bench', data: _w(100, 5));
      final r = _ok(await GetExerciseRecords(sessions: sessions)('bench'));
      expect(r.recordSetIds, {first.id});
      expect(r.recordSetIds, isNot(contains(second.id)));
      expect(
        r.current.values.single.sessionId,
        'zzz-first',
        reason: 'the standing record is the earlier-created session',
      );
    });
  });

  group('F9 exercise history carries notes', () {
    test('session note and the entry notes of that exercise', () async {
      final s = await emptySession();
      final a1 = await addEx(s.id, 'bench');
      await addEx(s.id, 'row');
      final a2 = await addEx(s.id, 'bench');
      await rec(s.id, 'bench');
      _ok(
        await SetSessionNote(sessions: sessions, clock: _clock)(
          sessionId: s.id,
          note: 'slept badly',
        ),
      );
      final setNote = SetSessionExerciseNote(sessions: sessions);
      _ok(
        await setNote(sessionId: s.id, sessionExerciseId: a1.id, note: 'wrist'),
      );
      _ok(
        await setNote(
          sessionId: s.id,
          sessionExerciseId: a2.id,
          note: 'backoff',
        ),
      );
      final history = await sessions.sessionsForExercise('bench');
      expect(history.single.sessionNote, 'slept badly');
      expect(history.single.entryNotes, ['wrist', 'backoff']);
      expect(await sessions.sessionsForExercise('row'), isEmpty);
    });
  });

  group('F10 deleting a session releases its scheduled occurrence', () {
    test('delete releases the occurrence; restore links it again only while '
        'it is still the one this delete released', () async {
      await plan(
        'p',
        exercises: const [
          PlanExercise(
            id: 'pe',
            exerciseId: 'bench',
            sortOrder: 0,
            targetSets: 3,
          ),
        ],
      );
      final today = scheduleDate(_now);
      await occurrence('sw', 'p', today);
      final started = _ok(
        await StartSessionFromPlan(
          plans: plans,
          sessions: sessions,
          exercises: exercises,
          scheduled: scheduled,
          transactor: transactor,
          clock: _clock,
          newId: newId,
        )(planId: 'p', scheduledWorkoutId: 'sw'),
      );
      final sid = started.session.id;
      expect((await scheduled.byId('sw'))!.status, ScheduleStatus.done);

      _ok(await deleteSession()(sid));
      final released = (await scheduled.byId('sw'))!;
      expect(released.status, ScheduleStatus.planned);
      expect(released.sessionId, sid, reason: 'the released link is kept');

      // It can be started again from the occurrence.
      final again = _ok(
        await StartSessionFromPlan(
          plans: plans,
          sessions: sessions,
          exercises: exercises,
          scheduled: scheduled,
          transactor: transactor,
          clock: _clock,
          newId: newId,
        )(planId: 'p', scheduledWorkoutId: 'sw'),
      );
      // Restoring the first session finds the occurrence done by the second
      // one, so it is left alone.
      _ok(await restoreSession()(sid));
      expect((await scheduled.byId('sw'))!.sessionId, again.session.id);

      // Deleting the first again does not touch an occurrence linked to the
      // second. Deleting the second releases it to the second only, so
      // restoring the first leaves it planned; restoring the second re-links.
      _ok(await deleteSession()(sid));
      expect((await scheduled.byId('sw'))!.sessionId, again.session.id);
      _ok(await deleteSession()(again.session.id));
      expect((await scheduled.byId('sw'))!.status, ScheduleStatus.planned);
      _ok(await restoreSession()(sid));
      expect((await scheduled.byId('sw'))!.status, ScheduleStatus.planned);
      _ok(await restoreSession()(again.session.id));
      final relinked = (await scheduled.byId('sw'))!;
      expect(
        [relinked.status, relinked.sessionId],
        [ScheduleStatus.done, again.session.id],
      );
    });

    test('N1: an occurrence started a day late is re-linked by undo, so it '
        'cannot be started twice', () async {
      await plan('p');
      final yesterday = scheduleDate(_now).subtract(const Duration(days: 1));
      await occurrence('late', 'p', yesterday);
      final started = _ok(
        await StartSessionFromPlan(
          plans: plans,
          sessions: sessions,
          exercises: exercises,
          scheduled: scheduled,
          transactor: transactor,
          clock: _clock,
          newId: newId,
        )(planId: 'p', scheduledWorkoutId: 'late'),
      );
      final sid = started.session.id;
      _ok(await deleteSession()(sid));
      _ok(await restoreSession()(sid));
      final o = (await scheduled.byId('late'))!;
      expect([o.status, o.sessionId], [ScheduleStatus.done, sid]);
      final again = await StartSessionFromPlan(
        plans: plans,
        sessions: sessions,
        exercises: exercises,
        scheduled: scheduled,
        transactor: transactor,
        clock: _clock,
        newId: newId,
      )(planId: 'p', scheduledWorkoutId: 'late');
      expect(again, isA<Err<StartedSession>>());
    });

    test('N2: undoing the delete of a session started without an occurrence '
        'leaves an unrelated planned occurrence alone', () async {
      await plan('p');
      await occurrence('today', 'p', scheduleDate(_now));
      final started = _ok(
        await StartSessionFromPlan(
          plans: plans,
          sessions: sessions,
          exercises: exercises,
          scheduled: scheduled,
          transactor: transactor,
          clock: _clock,
          newId: newId,
        )(planId: 'p'),
      );
      _ok(await deleteSession()(started.session.id));
      _ok(await restoreSession()(started.session.id));
      final o = (await scheduled.byId('today'))!;
      expect([o.status, o.sessionId], [ScheduleStatus.planned, null]);
    });

    test('restore leaves an occurrence that is no longer planned alone, '
        'and a session without a plan is unaffected', () async {
      await plan('p');
      final today = scheduleDate(_now);
      final s = _ok(
        await StartEmptySession(
          sessions: sessions,
          clock: _clock,
          newId: newId,
        )(name: 'Free'),
      );
      _ok(await deleteSession()(s.id));
      _ok(await restoreSession()(s.id));
      await sessions.upsert(
        WorkoutSession(
          id: 'planned-session',
          name: 'P',
          planId: 'p',
          startedAt: _now,
          createdAt: _t,
          updatedAt: _t,
        ),
      );
      await occurrence('skipped', 'p', today, status: ScheduleStatus.skipped);
      _ok(await deleteSession()('planned-session'));
      _ok(await restoreSession()('planned-session'));
      expect((await scheduled.byId('skipped'))!.status, ScheduleStatus.skipped);
    });
  });
}
