import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 3, 12));
final _t = DateTime.utc(2026, 11, 1, 8);

LoadKg _kg(double v) => LoadKg.fromStored(v);

SessionSet _set(
  String sid,
  String id,
  int order,
  SetData data, {
  String exerciseId = 'ex',
  int exerciseOrder = 0,
  Exertion? exertion,
  int? rest,
  String? note,
  bool completed = true,
}) => SessionSet(
  id: id,
  sessionId: sid,
  exerciseId: exerciseId,
  exerciseOrder: exerciseOrder,
  setOrder: order,
  data: data,
  completed: completed,
  exertion: exertion,
  restSeconds: rest,
  note: note,
);

WorkoutSession _session(
  String id,
  DateTime startedAt,
  List<SessionSet> sets, {
  String name = 'Push',
}) => WorkoutSession(
  id: id,
  name: name,
  planId: 'plan',
  startedAt: startedAt,
  endedAt: startedAt.add(const Duration(hours: 1)),
  notes: 'felt good',
  sets: sets,
  createdAt: _t,
  updatedAt: _t,
);

void main() {
  late AppDatabase db;
  late DriftWorkoutSessionRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftWorkoutSessionRepository(db, clock: _clock);
  });
  tearDown(() => db.close());

  test('round-trips one set of each variant with all fields', () async {
    final sets = <SessionSet>[
      _set(
        's',
        '1',
        0,
        SetData.weighted(load: _kg(82.5), reps: 5),
        exertion: const Exertion(scale: ExertionScale.rpe, value: 8.5),
        rest: 180,
        note: 'top set',
      ),
      _set(
        's',
        '2',
        1,
        SetData.bodyweight(reps: 8, addedLoad: _kg(10)),
        exerciseOrder: 1,
        exertion: const Exertion(scale: ExertionScale.rir, value: 2),
      ),
      _set(
        's',
        '3',
        2,
        const SetData.bodyweight(reps: 12),
        exerciseOrder: 1,
        completed: false,
      ),
      _set(
        's',
        '4',
        0,
        SetData.assisted(reps: 6, assistance: _kg(20.25)),
        exerciseOrder: 2,
      ),
      _set(
        's',
        '5',
        0,
        const SetData.timed(duration: Duration(seconds: 90)),
        exerciseOrder: 3,
      ),
      _set(
        's',
        '6',
        0,
        const SetData.distance(metres: 40.5, duration: Duration(seconds: 12)),
        exerciseOrder: 4,
      ),
      _set('s', '7', 1, const SetData.distance(metres: 100), exerciseOrder: 4),
      _set(
        's',
        '8',
        0,
        const SetData.cardio(
          duration: Duration(minutes: 20),
          metres: 5000,
          averageHeartRate: 150,
        ),
        exerciseOrder: 5,
      ),
      _set(
        's',
        '9',
        1,
        const SetData.cardio(duration: Duration(minutes: 5)),
        exerciseOrder: 5,
      ),
    ];
    final session = _session('s', _t, sets);
    await repo.upsert(session);

    final loaded = await repo.byId('s');
    expect(loaded, session);
    expect(
      loaded!.sets.map((s) => s.data.type).toSet(),
      ExerciseType.values.toSet(),
    );
    expect((await repo.watchAll().first).single, session);
  });

  test('sets are read back ordered by exerciseOrder then setOrder', () async {
    final w = SetData.weighted(load: _kg(50), reps: 5);
    final session = _session('s', _t, [
      _set('s', 'c', 0, w, exerciseOrder: 1),
      _set('s', 'b', 1, w),
      _set('s', 'a', 0, w),
    ]);
    await repo.upsert(session);
    expect((await repo.byId('s'))!.sets.map((s) => s.id), ['a', 'b', 'c']);
  });

  test('upsert replaces child sets', () async {
    final w = SetData.weighted(load: _kg(50), reps: 5);
    await repo.upsert(
      _session('s', _t, [_set('s', 'a', 0, w), _set('s', 'b', 1, w)]),
    );
    final updated = _session('s', _t, [
      _set('s', 'c', 0, SetData.weighted(load: _kg(60), reps: 3)),
    ], name: 'Renamed');
    await repo.upsert(updated);
    expect(await repo.byId('s'), updated);
    expect(await db.select(db.sessionSets).get(), hasLength(1));
    expect(await db.select(db.workoutSessions).get(), hasLength(1));
  });

  test('watchAll is newest first and respects the limit', () async {
    for (var i = 0; i < 3; i++) {
      await repo.upsert(_session('s$i', _t.add(Duration(days: i)), const []));
    }
    expect((await repo.watchAll().first).map((s) => s.id), ['s2', 's1', 's0']);
    expect((await repo.watchAll(limit: 2).first).map((s) => s.id), [
      's2',
      's1',
    ]);
  });

  test('delete soft-deletes, stamps from clock, and is idempotent', () async {
    await repo.upsert(_session('s', _t, const []));
    await repo.delete('s');
    final first = (await db.select(db.workoutSessions).get()).single;
    expect(first.deletedAt, _clock.now());
    expect(await repo.byId('s'), isNull);
    expect(await repo.watchAll().first, isEmpty);

    await repo.delete('s');
    final second = (await db.select(db.workoutSessions).get()).single;
    expect(second.updatedAt, first.updatedAt);
    expect(second.deletedAt, first.deletedAt);
  });

  test(
    'setsForExercise is oldest first and excludes deleted sessions',
    () async {
      final w = SetData.weighted(load: _kg(50), reps: 5);
      // Insert newer session first to prove ordering is by startedAt.
      await repo.upsert(
        _session('new', _t.add(const Duration(days: 2)), [
          _set('new', 'n1', 0, w),
          _set('new', 'other', 1, w, exerciseId: 'different'),
        ]),
      );
      await repo.upsert(
        _session('old', _t, [_set('old', 'o2', 1, w), _set('old', 'o1', 0, w)]),
      );
      await repo.upsert(
        _session('gone', _t.add(const Duration(days: 1)), [
          _set('gone', 'g1', 0, w),
        ]),
      );
      await repo.delete('gone');

      final sets = await repo.setsForExercise('ex');
      expect(sets.map((s) => s.id), ['o1', 'o2', 'n1']);
    },
  );

  test(
    'the database refuses a set whose load is out of range (TD-25)',
    () async {
      await repo.upsert(
        _session('s', _t, [
          _set('s', 'ok', 0, SetData.weighted(load: _kg(50), reps: 5)),
        ]),
      );
      await expectLater(
        db
            .into(db.sessionSets)
            .insert(
              SessionSetsCompanion.insert(
                id: 'bad',
                sessionId: 's',
                exerciseId: 'ex',
                exerciseOrder: 0,
                setOrder: 1,
                type: 'weighted',
                loadKg: const Value(5000),
                reps: const Value(5),
              ),
            ),
        throwsA(anything),
      );
      expect((await repo.byId('s'))!.sets.map((s) => s.id), ['ok']);
      expect((await repo.setsForExercise('ex')).map((s) => s.id), ['ok']);
    },
  );

  test('skips a set with an unknown type or missing fields', () async {
    await repo.upsert(_session('s', _t, const []));
    for (final (id, type) in [('u', 'teleport'), ('m', 'weighted')]) {
      await db
          .into(db.sessionSets)
          .insert(
            SessionSetsCompanion.insert(
              id: id,
              sessionId: 's',
              exerciseId: 'ex',
              exerciseOrder: 0,
              setOrder: 0,
              type: type,
            ),
          );
    }
    expect((await repo.byId('s'))!.sets, isEmpty);
  });
}
