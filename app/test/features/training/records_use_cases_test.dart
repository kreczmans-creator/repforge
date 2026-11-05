import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/personal_records.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/record_set.dart';
import 'package:repforge/features/training/application/records_use_cases.dart';
import 'package:repforge/features/training/application/session_use_cases.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 5, 10));
final _t = DateTime.utc(2026, 11, 1, 9);

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final error) => fail('expected Ok, got ${error.message}'),
};

SetData _w(double kg, int reps) =>
    SetData.weighted(load: LoadKg.fromStored(kg), reps: reps);

void main() {
  late AppDatabase db;
  late DriftExerciseRepository exercises;
  late DriftWorkoutSessionRepository sessions;
  late RecordSet record;
  late GetExerciseRecords records;
  var n = 0;
  String newId() => 'id${n++}';

  setUp(() async {
    db = AppDatabase.inMemory();
    n = 0;
    exercises = DriftExerciseRepository(db, clock: _clock);
    sessions = DriftWorkoutSessionRepository(db, clock: _clock);
    record = RecordSet(exercises: exercises, sessions: sessions, newId: newId);
    records = GetExerciseRecords(sessions: sessions);
    await exercises.upsert(
      Exercise(
        id: 'bench',
        name: 'Bench',
        type: ExerciseType.weighted,
        category: ExerciseCategory.push,
        primaryMuscle: MuscleGroup.chest,
        secondaryMuscles: const [MuscleGroup.triceps],
        createdAt: _t,
        updatedAt: _t,
      ),
    );
  });
  tearDown(() => db.close());

  Future<void> session(String id, DateTime at) => sessions.upsert(
    WorkoutSession(
      id: id,
      name: id,
      startedAt: at,
      createdAt: _t,
      updatedAt: _t,
    ),
  );

  Future<SessionSet> rec(
    String sessionId,
    double kg,
    int reps, {
    SetKind kind = SetKind.working,
  }) async => _ok<SessionSet>(
    await record(
      sessionId: sessionId,
      exerciseId: 'bench',
      data: _w(kg, reps),
      kind: kind,
    ),
  );

  test('TRN-026(3): 82.5 x 5 over a previous best of 80 x 5 is a PR; editing '
      'it below 80 or deleting it removes the PR', () async {
    await session('old', DateTime.utc(2026, 10));
    await session('new', DateTime.utc(2026, 11));
    final prev = await rec('old', 80, 5);
    final fresh = await rec('new', 82.5, 5);

    var r = _ok(await records('bench'));
    expect(r.recordSetIds, {prev.id, fresh.id});
    expect(
      r.current[const PrKey(PrMeasure.heaviestAtReps, 5)]!.setId,
      fresh.id,
    );

    // Edit the new set to 77.5: no longer a PR, the old one stands.
    _ok(
      await EditSet(exercises: exercises, sessions: sessions)(
        sessionId: 'new',
        setId: fresh.id,
        data: _w(77.5, 5),
        completed: true,
      ),
    );
    r = _ok(await records('bench'));
    expect(r.recordSetIds, {prev.id});
    expect(r.current.values.single.value, 80);

    // Edit it back above, then delete it.
    _ok(
      await EditSet(exercises: exercises, sessions: sessions)(
        sessionId: 'new',
        setId: fresh.id,
        data: _w(85, 5),
        completed: true,
      ),
    );
    expect(_ok(await records('bench')).recordSetIds, {prev.id, fresh.id});
    _ok(await DeleteSet(sessions: sessions)(sessionId: 'new', setId: fresh.id));
    r = _ok(await records('bench'));
    expect(r.recordSetIds, {prev.id});
    expect(r.current.values.single.setId, prev.id);
  });

  test('deleting a whole session removes its records; restoring brings them '
      'back', () async {
    await session('s', DateTime.utc(2026, 11));
    final set = await rec('s', 100, 3);
    expect(_ok(await records('bench')).recordSetIds, {set.id});
    _ok(await DeleteSession(sessions: sessions)('s'));
    expect(_ok(await records('bench')).recordSetIds, isEmpty);
    _ok(await RestoreSession(sessions: sessions)('s'));
    expect(_ok(await records('bench')).recordSetIds, {set.id});
  });

  test('a warm-up never makes or blocks a record; changing the kind to '
      'working makes it count', () async {
    await session('s', DateTime.utc(2026, 11));
    final warm = await rec('s', 100, 5, kind: SetKind.warmUp);
    final work = await rec('s', 80, 5);
    expect(_ok(await records('bench')).recordSetIds, {work.id});
    _ok(
      await EditSet(exercises: exercises, sessions: sessions)(
        sessionId: 's',
        setId: warm.id,
        data: _w(100, 5),
        completed: true,
      ),
    );
    final r = _ok(await records('bench'));
    expect(r.recordSetIds, {warm.id});
  });

  test(
    'weekly volume uses the settings and ignores deleted sessions',
    () async {
      // Mon 2 Nov: 80x5 + 80x4. Sun 8 Nov 23:30 with a 4 h day start still
      // belongs to Sunday: same week.
      await session('mon', DateTime(2026, 11, 2, 18));
      await rec('mon', 80, 5);
      await rec('mon', 80, 4);
      await session('late', DateTime(2026, 11, 9, 1));
      await rec('late', 100, 3);
      await session('gone', DateTime(2026, 11, 3, 18));
      await rec('gone', 200, 5);
      _ok(await DeleteSession(sessions: sessions)('gone'));

      final volume = GetWeeklyVolume(sessions: sessions, exercises: exercises);
      final from = DateTime(2026, 10, 26);
      final to = DateTime(2026, 11, 30);

      var weeks = _ok(
        await volume(
          from: from,
          to: to,
          settings: const AppSettings(dayStartHour: 4),
        ),
      );
      expect(weeks.map((w) => w.weekStart), [DateTime(2026, 11, 2)]);
      expect(weeks.single.total.loadKg, 720 + 300);
      expect(weeks.single.byMuscle[MuscleGroup.chest]!.primary.loadKg, 1020);
      expect(
        weeks.single.byMuscle[MuscleGroup.triceps]!.secondary.loadKg,
        1020,
      );

      weeks = _ok(
        await volume(from: from, to: to, settings: const AppSettings()),
      );
      expect(weeks.map((w) => w.weekStart), [
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 9),
      ]);

      weeks = _ok(
        await volume(
          from: from,
          to: to,
          settings: const AppSettings(weekStartDay: 7),
        ),
      );
      // Sunday start: Mon 2 Nov is in the week from Sun 1 Nov.
      expect(weeks.first.weekStart, DateTime(2026, 11));
    },
  );

  test('read failures are StorageErrors', () async {
    await db.close();
    expect((await records('bench')).isErr, isTrue);
    expect(
      (await GetWeeklyVolume(sessions: sessions, exercises: exercises)(
        from: _t,
        to: _t,
        settings: const AppSettings(),
      )).isErr,
      isTrue,
    );
    db = AppDatabase.inMemory();
  });
}
