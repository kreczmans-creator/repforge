import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart' show DataProvenance;
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/record_set.dart';

import '../../helpers/seed_session.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 5, 10));
final _t = DateTime.utc(2026, 11, 5, 9);

LoadKg _kg(double v) => LoadKg.fromStored(v);

Exercise _ex(String id, ExerciseType type) => Exercise(
  id: id,
  name: id,
  type: type,
  category: ExerciseCategory.push,
  primaryMuscle: MuscleGroup.chest,
  createdAt: _t,
  updatedAt: _t,
);

void main() {
  late AppDatabase db;
  late DriftExerciseRepository exercises;
  late DriftWorkoutSessionRepository sessions;
  late RecordSet record;
  var n = 0;

  setUp(() async {
    db = AppDatabase.inMemory();
    exercises = DriftExerciseRepository(db, clock: _clock);
    sessions = DriftWorkoutSessionRepository(db, clock: _clock);
    n = 0;
    record = RecordSet(
      exercises: exercises,
      sessions: sessions,
      newId: () => 'set-${n++}',
    );
    for (final type in ExerciseType.values) {
      await exercises.upsert(_ex(type.name, type));
    }
    await seedSession(
      sessions,
      WorkoutSession(
        id: 's',
        name: 'Today',
        startedAt: _t,
        createdAt: _t,
        updatedAt: _t,
      ),
    );
  });
  tearDown(() => db.close());

  Future<Result<SessionSet>> rec(
    String exerciseId,
    SetData data, {
    Exertion? exertion,
    int? restSeconds,
    String? note,
  }) => recordFor(
    record,
    sessions,
    sessionId: 's',
    exerciseId: exerciseId,
    data: data,
    exertion: exertion,
    restSeconds: restSeconds,
    note: note,
  );

  Future<SessionSet> storedBack(String id) async =>
      (await sessions.byId('s'))!.sets.singleWhere((s) => s.id == id);

  group('a set of each type is stored and read back with the right fields '
      '(D06 acceptance)', () {
    test('weighted: 80 kg x 5 (TRN-002)', () async {
      final r = await rec('weighted', SetData.weighted(load: _kg(80), reps: 5));
      final back = await storedBack((r as Ok<SessionSet>).value.id);
      expect(back.data, isA<WeightedSet>());
      expect((back.data as WeightedSet).load.value, 80);
      expect((back.data as WeightedSet).reps, 5);
      final row = await db.select(db.sessionSets).getSingle();
      expect(
        [row.type, row.loadKg, row.reps, row.assistanceKg, row.durationSec],
        ['weighted', 80, 5, null, null],
      );
      expect(
        [row.metres, row.averageHeartRate, row.energyKcal],
        [null, null, null],
      );
    });

    test(
      'bodyweight: 12 reps without and 8 reps with 10 kg (TRN-003)',
      () async {
        await rec('bodyweight', const SetData.bodyweight(reps: 12));
        await rec(
          'bodyweight',
          SetData.bodyweight(reps: 8, addedLoad: _kg(10)),
        );
        final rows = await db.select(db.sessionSets).get();
        expect(rows.map((r) => [r.type, r.reps, r.loadKg, r.assistanceKg]), [
          ['bodyweight', 12, null, null],
          ['bodyweight', 8, 10, null],
        ]);
      },
    );

    test('assisted: 6 reps with 20 kg assistance (TRN-004)', () async {
      await rec('assisted', SetData.assisted(reps: 6, assistance: _kg(20)));
      final row = await db.select(db.sessionSets).getSingle();
      expect(
        [row.type, row.reps, row.assistanceKg, row.loadKg],
        ['assisted', 6, 20, null],
      );
    });

    test('timed: 90 s plank, and 45 s with 5 kg added (TRN-005)', () async {
      await rec('timed', const SetData.timed(duration: Duration(seconds: 90)));
      await rec(
        'timed',
        SetData.timed(duration: const Duration(seconds: 45), addedLoad: _kg(5)),
      );
      final back = (await sessions.byId('s'))!.sets.map((s) => s.data).toList();
      expect((back[0] as TimedSet).duration, const Duration(seconds: 90));
      expect((back[0] as TimedSet).addedLoad, isNull);
      expect((back[1] as TimedSet).addedLoad!.value, 5);
      final rows = await db.select(db.sessionSets).get();
      expect(rows.map((r) => [r.durationSec, r.loadKg, r.reps]), [
        [90, null, null],
        [45, 5, null],
      ]);
    });

    test('distance: 400 m, optionally with a duration (TRN-006)', () async {
      await rec('distance', const SetData.distance(metres: 400));
      await rec(
        'distance',
        const SetData.distance(metres: 1250, duration: Duration(minutes: 6)),
      );
      final rows = await db.select(db.sessionSets).get();
      expect(rows.map((r) => [r.metres, r.durationSec, r.reps, r.loadKg]), [
        [400, null, null, null],
        [1250, 360, null, null],
      ]);
    });

    test('cardio: 30 minutes with no distance is valid; energy keeps its '
        'label (TRN-007)', () async {
      await rec(
        'cardio',
        const SetData.cardio(duration: Duration(minutes: 30)),
      );
      await rec(
        'cardio',
        const SetData.cardio(
          duration: Duration(minutes: 30),
          metres: 5000,
          averageHeartRate: 145,
          energyKcal: 320,
          energyProvenance: DataProvenance.estimated,
        ),
      );
      final rows = await db.select(db.sessionSets).get();
      expect(rows[0].energyKcal, isNull);
      expect(rows[0].energyProvenance, isNull);
      expect(rows[1].durationSec, 1800);
      expect([rows[1].metres, rows[1].averageHeartRate], [5000, 145]);
      expect(
        [rows[1].energyKcal, rows[1].energyProvenance],
        [320, 'estimated'],
      );
      final back = (await sessions.byId('s'))!.sets.last.data as CardioSet;
      expect(back.energyProvenance, DataProvenance.estimated);
    });
  });

  group('invalid combinations are rejected and nothing is stored', () {
    Future<void> rejected(
      String exerciseId,
      SetData data, {
      Exertion? exertion,
      String? field,
    }) async {
      final r = await rec(exerciseId, data, exertion: exertion);
      expect(r.isErr, isTrue, reason: '$data');
      if (field != null) {
        expect(((r as Err).error as ValidationError).field, field);
      }
      expect(await db.select(db.sessionSets).get(), isEmpty);
    }

    test('a weighted set on a timed exercise', () async {
      await rejected(
        'timed',
        SetData.weighted(load: _kg(60), reps: 5),
        field: 'type',
      );
    });

    test('0 and 101 repetitions', () async {
      await rejected(
        'weighted',
        SetData.weighted(load: _kg(60), reps: 0),
        field: 'reps',
      );
      await rejected(
        'weighted',
        SetData.weighted(load: _kg(60), reps: 101),
        field: 'reps',
      );
      await rejected('bodyweight', const SetData.bodyweight(reps: 0));
    });

    test('a negative load and a 0.1 kg step are rejected on entry and '
        'nothing is stored (TRN-002(2))', () async {
      // Input built from raw numbers the way a form would: a value that
      // does not become a LoadKg never reaches RecordSet.
      Future<Result<SessionSet>> enter(double raw) {
        final load = LoadKg.of(raw);
        if (load case Err(:final error)) return Future.value(Err(error));
        return rec(
          'weighted',
          SetData.weighted(load: (load as Ok<LoadKg>).value, reps: 5),
        );
      }

      for (final raw in [80.1, -0.1, -5.0, 100.1, 0.1]) {
        final r = await enter(raw);
        expect(r.isErr, isTrue, reason: '$raw');
        expect(((r as Err).error as ValidationError).field, 'loadKg');
      }
      expect(await db.select(db.sessionSets).get(), isEmpty);

      final ok = await enter(80.25);
      final stored = (ok as Ok<SessionSet>).value;
      expect((stored.data as WeightedSet).load.value, 80.25);
      expect((await db.select(db.sessionSets).getSingle()).loadKg, 80.25);
    });

    test('a zero duration and zero metres', () async {
      await rejected('timed', const SetData.timed(duration: Duration.zero));
      await rejected('distance', const SetData.distance(metres: 0));
      await rejected(
        'cardio',
        const SetData.cardio(duration: Duration.zero),
        field: 'duration',
      );
    });

    test('heart rate 300', () async {
      await rejected(
        'cardio',
        const SetData.cardio(
          duration: Duration(minutes: 10),
          averageHeartRate: 300,
        ),
        field: 'averageHeartRate',
      );
    });

    test('energy needs a user-entered or estimated label and cannot be '
        'negative', () async {
      await rejected(
        'cardio',
        const SetData.cardio(duration: Duration(minutes: 10), energyKcal: 200),
        field: 'energyProvenance',
      );
      await rejected(
        'cardio',
        const SetData.cardio(
          duration: Duration(minutes: 10),
          energyKcal: 200,
          energyProvenance: DataProvenance.verified,
        ),
        field: 'energyProvenance',
      );
      await rejected(
        'cardio',
        const SetData.cardio(
          duration: Duration(minutes: 10),
          energyKcal: -1,
          energyProvenance: DataProvenance.userEntered,
        ),
        field: 'energyKcal',
      );
    });

    test(
      'exertion out of range for its scale (validExertion on write)',
      () async {
        final set = SetData.weighted(load: _kg(60), reps: 5);
        await rejected(
          'weighted',
          set,
          exertion: const Exertion(scale: ExertionScale.rpe, value: 11),
          field: 'exertion',
        );
        await rejected(
          'weighted',
          set,
          exertion: const Exertion(scale: ExertionScale.rpe, value: 8.2),
        );
        await rejected(
          'weighted',
          set,
          exertion: const Exertion(scale: ExertionScale.rir, value: -1),
        );
        for (final bad in [6.0, 7.5, 2.5, -1.0]) {
          await rejected(
            'weighted',
            set,
            exertion: Exertion(scale: ExertionScale.rir, value: bad),
            field: 'exertion',
          );
        }
        for (final bad in [0.5, 10.5]) {
          await rejected(
            'weighted',
            set,
            exertion: Exertion(scale: ExertionScale.rpe, value: bad),
            field: 'exertion',
          );
        }
        for (final good in [
          const Exertion(scale: ExertionScale.rir, value: 3),
          const Exertion(scale: ExertionScale.rpe, value: 7.5),
        ]) {
          expect((await rec('weighted', set, exertion: good)).isOk, isTrue);
        }
        await db.delete(db.sessionSets).go();
        final ok = await rec(
          'weighted',
          set,
          exertion: const Exertion(scale: ExertionScale.rpe, value: 8.5),
          restSeconds: 120,
          note: '  felt good ',
        );
        final stored = (ok as Ok<SessionSet>).value;
        expect(stored.exertion!.value, 8.5);
        final back = await storedBack(stored.id);
        expect(
          back.exertion,
          const Exertion(scale: ExertionScale.rpe, value: 8.5),
        );
        expect(back.restSeconds, 120);
        expect(back.note, 'felt good');
      },
    );

    test('rest outside 0 to 3600 s', () async {
      final r = await rec(
        'weighted',
        SetData.weighted(load: _kg(60), reps: 5),
        restSeconds: 4000,
      );
      expect(r.isErr, isTrue);
      expect(await db.select(db.sessionSets).get(), isEmpty);
    });
  });

  group('exercise and session checks', () {
    final set = SetData.weighted(load: _kg(60), reps: 5);

    test('an archived exercise is refused; restoring it allows sets', () async {
      await exercises.archive('weighted', archived: true);
      final r = await rec('weighted', set);
      expect(r.isErr, isTrue);
      expect(((r as Err).error as ValidationError).field, 'exerciseId');
      await exercises.archive('weighted', archived: false);
      expect((await rec('weighted', set)).isOk, isTrue);
    });

    test(
      'a deleted or unknown exercise and an unknown session are not found',
      () async {
        await exercises.delete('weighted');
        expect(
          ((await rec('weighted', set)) as Err).error,
          isA<NotFoundError>(),
        );
        expect(((await rec('nope', set)) as Err).error, isA<NotFoundError>());
        final r = await recordFor(
          record,
          sessions,
          sessionId: 'missing',
          exerciseId: 'bodyweight',
          data: const SetData.bodyweight(reps: 5),
        );
        expect((r as Err).error, isA<NotFoundError>());
      },
    );

    test('exercise and set order follow the session', () async {
      final a1 = (await rec('weighted', set) as Ok<SessionSet>).value;
      final b1 = (await rec(
        'bodyweight',
        const SetData.bodyweight(reps: 5),
      ) as Ok<SessionSet>).value;
      final a2 = (await rec('weighted', set) as Ok<SessionSet>).value;
      expect([a1.exerciseOrder, a1.setOrder], [0, 0]);
      expect([b1.exerciseOrder, b1.setOrder], [1, 0]);
      expect([a2.exerciseOrder, a2.setOrder], [0, 1]);
      expect(a1.completed, isTrue);
    });

    test('a storage failure becomes a StorageError', () async {
      await db.close();
      final r = await rec('weighted', set);
      expect((r as Err).error, isA<StorageError>());
      db = AppDatabase.inMemory();
    });
  });
}
