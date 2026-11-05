import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_scheduled_workout_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 5, 10));
final _t = DateTime.utc(2026, 11, 1, 9);

SessionSet _set(
  String id,
  String session,
  String exercise,
  int order,
  int setOrder, {
  String? entry,
  SetKind kind = SetKind.working,
}) => SessionSet(
  id: id,
  sessionId: session,
  exerciseId: exercise,
  exerciseOrder: order,
  setOrder: setOrder,
  data: SetData.weighted(load: LoadKg.fromStored(60), reps: 5),
  completed: true,
  kind: kind,
  sessionExerciseId: entry,
);

WorkoutSession _session(String id, DateTime at) => WorkoutSession(
  id: id,
  name: id,
  startedAt: at,
  createdAt: _t,
  updatedAt: _t,
);

SessionExercise _entry(String id, String session, String exercise, int pos) =>
    SessionExercise(
      id: id,
      sessionId: session,
      exerciseId: exercise,
      position: pos,
    );

void main() {
  late AppDatabase db;
  late DriftWorkoutSessionRepository repo;

  setUp(() async {
    db = AppDatabase.inMemory();
    repo = DriftWorkoutSessionRepository(db, clock: _clock);
    await repo.upsert(_session('s', _t));
  });
  tearDown(() => db.close());

  group('entries', () {
    test('an exercise entry can exist before any set and is read back in '
        'position order', () async {
      await repo.addExercise(_entry('b', 's', 'squat', 1));
      await repo.addExercise(_entry('a', 's', 'bench', 0));
      final s = (await repo.byId('s'))!;
      expect(s.exercises.map((e) => e.id), ['a', 'b']);
      expect(s.sets, isEmpty);
    });

    test(
      'addExercise and addSet refuse an unknown or deleted session',
      () async {
        await expectLater(
          repo.addExercise(_entry('x', 'nope', 'bench', 0)),
          throwsStateError,
        );
        await repo.delete('s');
        await expectLater(
          repo.addExercise(_entry('x', 's', 'bench', 0)),
          throwsStateError,
        );
        await expectLater(
          repo.addSet(_set('t', 's', 'bench', 0, 0)),
          throwsStateError,
        );
      },
    );

    test('addSet names an entry that exists, creates the entry named by '
        'newEntry, and refuses a wrong entry', () async {
      await repo.addExercise(_entry('a', 's', 'bench', 0));
      await repo.addSet(_set('t1', 's', 'bench', 7, 0, entry: 'a'));
      var s = (await repo.byId('s'))!;
      expect(s.sets.single.sessionExerciseId, 'a');
      expect(s.sets.single.exerciseOrder, 0, reason: 'mirrors the entry');

      await repo.addSet(
        _set('t2', 's', 'squat', 1, 0, entry: 'new'),
        newEntry: _entry('new', 's', 'squat', 1),
      );
      s = (await repo.byId('s'))!;
      expect(s.exercises.map((e) => e.id), ['a', 'new']);

      await expectLater(
        repo.addSet(_set('t3', 's', 'bench', 0, 1, entry: 'ghost')),
        throwsStateError,
      );
      await expectLater(
        repo.addSet(_set('t4', 's', 'squat', 0, 1, entry: 'a')),
        throwsStateError,
        reason: 'entry a is for another exercise',
      );
      await expectLater(
        repo.addSet(
          _set('t5', 's', 'squat', 0, 1),
          newEntry: _entry('e', 's', 'bench', 5),
        ),
        throwsStateError,
        reason: 'the new entry does not match the set',
      );
      expect((await repo.byId('s'))!.sets, hasLength(2));
    });

    test('a raw set with no entry creates one at its exercise order when '
        'free, otherwise last', () async {
      await repo.addSet(_set('a', 's', 'bench', 3, 0));
      await repo.addSet(_set('b', 's', 'squat', 3, 0));
      final s = (await repo.byId('s'))!;
      expect(s.exercises.map((e) => (e.exerciseId, e.position)), [
        ('bench', 3),
        ('squat', 4),
      ]);
      expect(s.sets.map((x) => x.exerciseOrder), [3, 4]);
    });

    test('updateExercise changes exercise and note; its sets follow, '
        'unknown entry returns false', () async {
      await repo.addExercise(_entry('a', 's', 'bench', 0));
      await repo.addSet(_set('t', 's', 'bench', 0, 0, entry: 'a'));
      expect(
        await repo.updateExercise(
          const SessionExercise(
            id: 'a',
            sessionId: 's',
            exerciseId: 'row',
            position: 0,
            note: 'n',
          ),
        ),
        isTrue,
      );
      final s = (await repo.byId('s'))!;
      expect(s.exercises.single.note, 'n');
      expect(s.sets.single.exerciseId, 'row');
      expect(await repo.updateExercise(_entry('zzz', 's', 'row', 0)), isFalse);
    });

    test('removeExercise deletes the entry and its sets only', () async {
      await repo.addSet(_set('a', 's', 'bench', 0, 0));
      await repo.addSet(_set('b', 's', 'squat', 1, 0));
      final entry = (await repo.byId('s'))!.exercises.first.id;
      expect(await repo.removeExercise(entry), isTrue);
      expect(await repo.removeExercise(entry), isFalse);
      final s = (await repo.byId('s'))!;
      expect(s.sets.map((x) => x.id), ['b']);
      expect(s.exercises.map((e) => e.exerciseId), ['squat']);
    });

    test('setExerciseOrder renumbers entries and their sets; a list that '
        'is not exactly the entries changes nothing', () async {
      await repo.addSet(_set('a', 's', 'bench', 0, 0));
      await repo.addSet(_set('b', 's', 'squat', 1, 0));
      await repo.addSet(_set('c', 's', 'row', 2, 0));
      var s = (await repo.byId('s'))!;
      final ids = s.exercises.map((e) => e.id).toList();
      await repo.setExerciseOrder('s', [ids[2], ids[0], ids[1]]);
      s = (await repo.byId('s'))!;
      expect(s.exercises.map((e) => (e.exerciseId, e.position)), [
        ('row', 0),
        ('bench', 1),
        ('squat', 2),
      ]);
      expect(s.sets.map((x) => (x.id, x.exerciseOrder)), [
        ('c', 0),
        ('a', 1),
        ('b', 2),
      ]);
      for (final bad in [
        [ids[0]],
        [ids[0], ids[0], ids[1]],
        [ids[0], ids[1], 'ghost'],
      ]) {
        await expectLater(repo.setExerciseOrder('s', bad), throwsStateError);
      }
      expect((await repo.byId('s'))!.exercises.map((e) => e.exerciseId), [
        'row',
        'bench',
        'squat',
      ]);
    });

    test('deleting the session row cascades to entries and sets', () async {
      await repo.addSet(_set('a', 's', 'bench', 0, 0));
      await db.customStatement("DELETE FROM workout_sessions WHERE id = 's'");
      expect(await db.select(db.sessionExercises).get(), isEmpty);
      expect(await db.select(db.sessionSets).get(), isEmpty);
    });
  });

  group('sets', () {
    test('set kind is stored per set', () async {
      await repo.addSet(_set('w', 's', 'bench', 0, 0, kind: SetKind.warmUp));
      await repo.addSet(_set('f', 's', 'bench', 0, 1, kind: SetKind.failure));
      final sets = (await repo.byId('s'))!.sets;
      expect(sets.map((x) => x.kind), [SetKind.warmUp, SetKind.failure]);
      expect((await db.select(db.sessionSets).get()).map((r) => r.setKind), [
        'warmUp',
        'failure',
      ]);
    });

    test('updateSet replaces the set but not its session, exercise, entry '
        'or order; false for an unknown set', () async {
      await repo.addSet(_set('a', 's', 'bench', 0, 0));
      final stored = (await repo.byId('s'))!.sets.single;
      expect(
        await repo.updateSet(
          stored.copyWith(
            data: SetData.weighted(load: LoadKg.fromStored(70), reps: 3),
            kind: SetKind.failure,
            note: 'x',
            exerciseId: 'other',
            sessionId: 'other',
            exerciseOrder: 9,
            sessionExerciseId: 'other',
          ),
        ),
        isTrue,
      );
      final after = (await repo.byId('s'))!.sets.single;
      expect(after.kind, SetKind.failure);
      expect(after.note, 'x');
      expect(after.data, isA<WeightedSet>());
      expect(
        [
          after.exerciseId,
          after.sessionId,
          after.exerciseOrder,
          after.sessionExerciseId,
        ],
        [
          stored.exerciseId,
          stored.sessionId,
          stored.exerciseOrder,
          stored.sessionExerciseId,
        ],
      );
      expect(await repo.updateSet(_set('zzz', 's', 'bench', 0, 0)), isFalse);
    });

    test('deleteSet removes one set and reports whether it existed', () async {
      await repo.addSet(_set('a', 's', 'bench', 0, 0));
      await repo.addSet(_set('b', 's', 'bench', 0, 1));
      expect(await repo.deleteSet('a'), isTrue);
      expect(await repo.deleteSet('a'), isFalse);
      expect((await repo.byId('s'))!.sets.map((x) => x.id), ['b']);
    });
  });

  group('soft delete, restore and range queries', () {
    test(
      'restore only affects a deleted session; byId can include deleted',
      () async {
        expect(await repo.restore('s'), isFalse);
        await repo.delete('s');
        expect(await repo.byId('s'), isNull);
        expect((await repo.byId('s', includeDeleted: true))!.id, 's');
        expect(await repo.restore('s'), isTrue);
        expect(await repo.restore('s'), isFalse);
        expect(await repo.byId('s'), isNotNull);
        expect(await repo.restore('zzz'), isFalse);
      },
    );

    test('sessionsBetween: start in [from, to), oldest first, deleted '
        'excluded, with sets', () async {
      await repo.upsert(_session('a', DateTime.utc(2026, 11, 2)));
      await repo.upsert(_session('b', DateTime.utc(2026, 11, 4)));
      await repo.upsert(_session('c', DateTime.utc(2026, 11, 6)));
      await repo.upsert(_session('d', DateTime.utc(2026, 11, 3)));
      await repo.addSet(_set('x', 'b', 'bench', 0, 0));
      await repo.delete('d');
      final list = await repo.sessionsBetween(
        DateTime.utc(2026, 11, 2),
        DateTime.utc(2026, 11, 6),
      );
      expect(list.map((s) => s.id), ['a', 'b']);
      expect(list.last.sets.single.id, 'x');
    });

    test('performedSets: completed sets of non-deleted sessions with the '
        'session start, oldest first', () async {
      await repo.upsert(_session('old', DateTime.utc(2026, 10)));
      await repo.upsert(_session('gone', DateTime.utc(2026, 10, 15)));
      await repo.addSet(_set('n', 's', 'bench', 0, 0));
      await repo.addSet(_set('o', 'old', 'bench', 0, 0));
      await repo.addSet(_set('g', 'gone', 'bench', 0, 0));
      await repo.addSet(_set('other', 'old', 'squat', 1, 0));
      await repo.addSet(
        _set('open', 'old', 'bench', 0, 1).copyWith(completed: false),
      );
      await repo.delete('gone');
      final performed = await repo.performedSets('bench');
      expect(performed.map((p) => p.set.id), ['o', 'n']);
      expect(performed.first.startedAt, DateTime.utc(2026, 10));
      expect(performed.first.sessionId, 'old');
    });
  });

  group('ScheduledWorkoutRepository', () {
    late DriftScheduledWorkoutRepository repo;
    setUp(() => repo = DriftScheduledWorkoutRepository(db));

    ScheduledWorkout w(String id, DateTime day, {String plan = 'p'}) =>
        ScheduledWorkout(
          id: id,
          day: day,
          sourceDay: day,
          planId: plan,
          origin: ScheduleOrigin.date,
          status: ScheduleStatus.planned,
          createdAt: _t,
          updatedAt: _t,
        );

    test(
      'stores local dates as YYYY-MM-DD and queries an inclusive range',
      () async {
        await repo.upsert(w('b', DateTime(2026, 11, 10)));
        await repo.upsert(w('a', DateTime(2026, 11, 2)));
        await repo.upsert(w('c', DateTime(2026, 12), plan: 'q'));
        final row = await (db.select(
          db.scheduledWorkouts,
        )..where((t) => t.id.equals('a'))).getSingle();
        expect(row.day, '2026-11-02');
        expect(row.origin, 'date');
        final inNov = await repo.inRange(
          DateTime(2026, 11),
          DateTime(2026, 11, 10),
        );
        expect(inNov.map((x) => x.id), ['a', 'b']);
        expect((await repo.forPlan('q')).map((x) => x.id), ['c']);
        expect((await repo.byId('b'))!.day, DateTime(2026, 11, 10));
        expect(await repo.byId('nope'), isNull);
      },
    );

    test('upsert replaces by id; a soft-deleted row is not read', () async {
      await repo.upsert(w('a', DateTime(2026, 11, 2)));
      await repo.upsert(
        w(
          'a',
          DateTime(2026, 11, 2),
        ).copyWith(status: ScheduleStatus.done, sessionId: 's'),
      );
      expect((await repo.byId('a'))!.status, ScheduleStatus.done);
      await db.customStatement(
        "UPDATE scheduled_workouts SET deleted_at = '2026-11-03T00:00:00.000Z'",
      );
      expect(await repo.byId('a'), isNull);
      expect(await repo.inRange(DateTime(2026), DateTime(2027)), isEmpty);
    });

    test('rows with a malformed date or unknown status are skipped', () async {
      await db.customStatement(
        'INSERT INTO scheduled_workouts (id, created_at, updated_at, day, '
        "source_day, plan_id, origin, status) VALUES ('bad', "
        "'2026-11-01T00:00:00.000Z', '2026-11-01T00:00:00.000Z', "
        "'2026-02-30', '2026-02-30', 'p', 'date', 'planned')",
      );
      expect(await repo.forPlan('p'), isEmpty);
    });
  });
}
