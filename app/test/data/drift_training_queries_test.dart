import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_training_split_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/nutrition/nutrition.dart' show DataProvenance;
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 3, 12));
final _t = DateTime.utc(2026, 11, 1, 8);

Exercise _ex(
  String id,
  String name, {
  ExerciseType type = ExerciseType.weighted,
  MuscleGroup primary = MuscleGroup.chest,
  List<MuscleGroup> secondary = const [],
  List<Equipment> equipment = const [],
  List<String> aliases = const [],
  bool supplied = false,
}) => Exercise(
  id: id,
  name: name,
  type: type,
  category: ExerciseCategory.push,
  primaryMuscle: primary,
  secondaryMuscles: secondary,
  equipment: equipment,
  aliases: aliases,
  supplied: supplied,
  createdAt: _t,
  updatedAt: _t,
);

SessionSet _set(
  String sessionId,
  String exerciseId,
  int exerciseOrder,
  int setOrder,
  SetData data, {
  bool completed = true,
  String? id,
}) => SessionSet(
  id: id ?? '$sessionId-$exerciseId-$exerciseOrder-$setOrder',
  sessionId: sessionId,
  exerciseId: exerciseId,
  exerciseOrder: exerciseOrder,
  setOrder: setOrder,
  data: data,
  completed: completed,
);

WorkoutSession _session(String id, DateTime startedAt, List<SessionSet> sets) =>
    WorkoutSession(
      id: id,
      name: 'Session $id',
      startedAt: startedAt,
      createdAt: _t,
      updatedAt: _t,
      sets: sets,
    );

void main() {
  late AppDatabase db;
  late DriftExerciseRepository exercises;
  late DriftWorkoutSessionRepository sessions;
  late DriftTrainingSplitRepository splits;

  setUp(() {
    db = AppDatabase.inMemory();
    exercises = DriftExerciseRepository(db, clock: _clock);
    sessions = DriftWorkoutSessionRepository(db, clock: _clock);
    splits = DriftTrainingSplitRepository(db, clock: _clock);
  });
  tearDown(() => db.close());

  group('exercise library queries', () {
    setUp(() async {
      for (final e in [
        _ex(
          'bench',
          'Bench Press',
          secondary: const [MuscleGroup.triceps],
          equipment: const [Equipment.barbell, Equipment.bench],
          aliases: const ['Développé couché'],
          supplied: true,
        ),
        _ex(
          'dip',
          'Dip',
          type: ExerciseType.bodyweight,
          primary: MuscleGroup.triceps,
          secondary: const [MuscleGroup.chest],
          equipment: const [Equipment.dipBars],
        ),
        _ex('pushup', 'Push-up', type: ExerciseType.bodyweight),
      ]) {
        await exercises.upsert(e);
      }
    });

    test('search matches name and aliases, ignoring case and diacritics '
        '(TRN-008(3))', () async {
      expect(
        (await exercises.search(const ExerciseQuery(text: 'DEVELOPPE')))
            .map((e) => e.id),
        ['bench'],
      );
      expect(
        (await exercises.search(const ExerciseQuery(text: 'press')))
            .map((e) => e.id),
        ['bench'],
      );
    });

    test('muscle filter lists primary matches first (TRN-010(2))', () async {
      final r = await exercises.search(
        const ExerciseQuery(muscle: MuscleGroup.chest),
      );
      expect(r.map((e) => e.id), ['bench', 'pushup', 'dip']);
    });

    test('equipment filter is a subset test; bodyweight always shows '
        '(TRN-011(2))', () async {
      final r = await exercises.search(
        const ExerciseQuery(availableEquipment: {}),
      );
      expect(r.map((e) => e.id), ['pushup']);
      final full = await exercises.search(
        const ExerciseQuery(
          availableEquipment: {Equipment.barbell, Equipment.bench},
        ),
      );
      expect(full.map((e) => e.id), ['bench', 'pushup']);
    });

    test('watchLibrary re-emits when an exercise is archived', () async {
      final emissions = <List<String>>[];
      final sub = exercises
          .watchLibrary(const ExerciseQuery())
          .listen((l) => emissions.add([for (final e in l) e.id]));
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await exercises.archive('dip', archived: true);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await sub.cancel();
      expect(emissions.first, ['bench', 'dip', 'pushup']);
      expect(emissions.last, ['bench', 'pushup']);
    });

    test(
      'archived exercises are hidden unless asked for (TRN-012(2))',
      () async {
        await exercises.archive('dip', archived: true);
        expect(
          (await exercises.search(const ExerciseQuery())).map((e) => e.id),
          ['bench', 'pushup'],
        );
        expect(
          (await exercises.search(const ExerciseQuery(includeArchived: true)))
              .map((e) => e.id),
          ['bench', 'dip', 'pushup'],
        );
        expect((await exercises.byId('dip'))!.archived, isTrue);
      },
    );

    test(
      'round-trips supplied, aliases, copiedFromId and search key',
      () async {
        final copy = _ex(
          'copy',
          'My Bench',
          aliases: const ['Mine'],
        ).copyWith(copiedFromId: 'bench');
        await exercises.upsert(copy);
        final loaded = (await exercises.byId('copy'))!;
        expect(loaded, copy);
        expect(loaded.supplied, isFalse);
        expect(loaded.copiedFromId, 'bench');
        final row = await (db.select(
          db.exercises,
        )..where((t) => t.id.equals('bench'))).getSingle();
        expect(row.searchKey, 'bench press developpe couche');
        expect(row.supplied, isTrue);
      },
    );

    test('TD-23: archive and delete never touch a deleted row', () async {
      expect(await exercises.delete('dip'), isTrue);
      expect(await exercises.delete('dip'), isFalse);
      final before = await (db.select(
        db.exercises,
      )..where((t) => t.id.equals('dip'))).getSingle();
      expect(await exercises.archive('dip', archived: true), isFalse);
      final after = await (db.select(
        db.exercises,
      )..where((t) => t.id.equals('dip'))).getSingle();
      expect(after.archived, isFalse, reason: 'deleted row left alone');
      expect(after.updatedAt, before.updatedAt);
      expect(await exercises.archive('nope', archived: true), isFalse);
      expect(await exercises.byId('dip'), isNull);
      expect(await exercises.exists('dip'), isTrue, reason: 'row still exists');
      expect(await exercises.exists('missing'), isFalse);
    });
  });

  group('history queries', () {
    SetData w(double kg, int reps) =>
        SetData.weighted(load: LoadKg.fromStored(kg), reps: reps);

    setUp(() async {
      await exercises.upsert(_ex('bench', 'Bench Press'));
      await exercises.upsert(
        _ex('squat', 'Squat', primary: MuscleGroup.quadriceps),
      );
      await sessions.upsert(
        _session('s1', DateTime.utc(2026, 10, 1, 9), [
          _set('s1', 'bench', 0, 0, w(60, 8)),
          _set('s1', 'bench', 0, 1, w(60, 7)),
          _set('s1', 'squat', 1, 0, w(100, 5)),
        ]),
      );
      await sessions.upsert(
        _session('s2', DateTime.utc(2026, 10, 8, 9), [
          _set('s2', 'bench', 0, 0, w(62.5, 8)),
          _set('s2', 'bench', 0, 1, w(62.5, 6), completed: false),
        ]),
      );
      await sessions.upsert(
        _session('s3', DateTime.utc(2026, 10, 15, 9), [
          _set('s3', 'squat', 0, 0, w(105, 5)),
          _set('s3', 'bench', 1, 0, w(65, 5)),
          _set('s3', 'bench', 1, 1, w(65, 4)),
        ]),
      );
    });

    test(
      'sessionsForExercise: newest first, completed sets in order',
      () async {
        final h = await sessions.sessionsForExercise('bench');
        expect(h.map((s) => s.sessionId), ['s3', 's2', 's1']);
        expect(h.first.sessionName, 'Session s3');
        expect(h.first.startedAt, DateTime.utc(2026, 10, 15, 9));
        expect(h[0].sets.map((s) => s.setOrder), [0, 1]);
        expect(h[0].sets.map((s) => (s.data as WeightedSet).load.value), [
          65,
          65,
        ]);
        expect(
          h[1].sets,
          hasLength(1),
          reason: 'the unfinished set is left out',
        );
        expect(h[2].sets.map((s) => (s.data as WeightedSet).reps), [8, 7]);
        expect(
          (await sessions.sessionsForExercise('squat')).map((s) => s.sessionId),
          ['s3', 's1'],
        );
        expect(await sessions.sessionsForExercise('unknown'), isEmpty);
      },
    );

    test('sessionsForExercise pages (TRN-025(2))', () async {
      final first = await sessions.sessionsForExercise('bench', limit: 2);
      expect(first.map((s) => s.sessionId), ['s3', 's2']);
      final next = await sessions.sessionsForExercise(
        'bench',
        limit: 2,
        offset: 2,
      );
      expect(next.map((s) => s.sessionId), ['s1']);
    });

    test(
      'a session with only unfinished sets, or deleted, is not history',
      () async {
        await sessions.delete('s3');
        expect(
          (await sessions.sessionsForExercise('bench')).map((s) => s.sessionId),
          ['s2', 's1'],
        );
        await sessions.upsert(
          _session('s4', DateTime.utc(2026, 11), [
            _set('s4', 'bench', 0, 0, w(70, 3), completed: false),
          ]),
        );
        expect(
          (await sessions.sessionsForExercise('bench')).map((s) => s.sessionId),
          ['s2', 's1'],
        );
      },
    );

    test('lastPerformance is the most recent completed sets', () async {
      final last = await sessions.lastPerformance('bench');
      expect(last.map((s) => s.sessionId).toSet(), {'s3'});
      expect(last.map((s) => (s.data as WeightedSet).reps), [5, 4]);
      expect(await sessions.lastPerformance('unknown'), isEmpty);
      await sessions.delete('s3');
      expect(
        (await sessions.lastPerformance('bench')).map((s) => s.sessionId),
        ['s2'],
      );
    });

    test('hasHistory sees any set in a live session', () async {
      expect(await sessions.hasHistory('bench'), isTrue);
      expect(await sessions.hasHistory('unknown'), isFalse);
      await sessions.upsert(
        _session('s5', DateTime.utc(2026, 11, 2), [
          _set('s5', 'row', 0, 0, w(40, 5), completed: false),
        ]),
      );
      expect(await sessions.hasHistory('row'), isTrue);
      await sessions.delete('s5');
      expect(await sessions.hasHistory('row'), isFalse);
    });

    test(
      'an archived or deleted exercise keeps its history (TRN-012(2))',
      () async {
        await exercises.archive('bench', archived: true);
        expect(await sessions.sessionsForExercise('bench'), hasLength(3));
        await exercises.delete('bench');
        expect(await sessions.sessionsForExercise('bench'), hasLength(3));
        expect(await sessions.lastPerformance('bench'), isNotEmpty);
      },
    );

    test('addSet adds one set without touching the others, and needs a live '
        'session', () async {
      await sessions.addSet(_set('s2', 'bench', 0, 2, w(62.5, 5), id: 'extra'));
      final loaded = (await sessions.byId('s2'))!;
      expect(loaded.sets, hasLength(3));
      expect(loaded.sets.last.id, 'extra');
      expect(
        () => sessions.addSet(_set('nope', 'bench', 0, 0, w(1, 1))),
        throwsStateError,
      );
      await sessions.delete('s2');
      expect(
        () => sessions.addSet(_set('s2', 'bench', 0, 3, w(1, 1))),
        throwsStateError,
      );
    });

    test('a set of each type round-trips with the right fields', () async {
      final data = <SetData>[
        w(80, 5),
        SetData.bodyweight(reps: 8, addedLoad: LoadKg.fromStored(10)),
        const SetData.bodyweight(reps: 12),
        SetData.assisted(reps: 6, assistance: LoadKg.fromStored(20)),
        const SetData.timed(duration: Duration(seconds: 90)),
        SetData.timed(
          duration: const Duration(seconds: 45),
          addedLoad: LoadKg.fromStored(5),
        ),
        const SetData.distance(metres: 400, duration: Duration(seconds: 80)),
        const SetData.cardio(duration: Duration(minutes: 30)),
        const SetData.cardio(
          duration: Duration(minutes: 30),
          metres: 5000,
          averageHeartRate: 145,
          energyKcal: 320.5,
          energyProvenance: DataProvenance.userEntered,
        ),
      ];
      await sessions.upsert(
        _session('all', DateTime.utc(2026, 11), [
          for (var i = 0; i < data.length; i++)
            _set('all', 'x$i', i, 0, data[i]),
        ]),
      );
      final loaded = (await sessions.byId('all'))!;
      expect(loaded.sets.map((s) => s.data), data);
    });
  });

  group('training splits', () {
    TrainingSplit split(
      String id,
      String name,
      int order,
      List<String?> days,
    ) => TrainingSplit(
      id: id,
      name: name,
      sortOrder: order,
      days: [for (final d in days) SplitDay(planId: d)],
      createdAt: _t,
      updatedAt: _t,
    );

    test('a 7-day Upper/Lower cycle with rest days round-trips in order '
        '(TRN-014)', () async {
      final s = split('s', 'Upper/Lower', 0, [
        'upperA',
        'lowerA',
        null,
        'upperB',
        'lowerB',
        null,
        null,
      ]);
      await splits.upsert(s);
      final loaded = (await splits.byId('s'))!;
      expect(loaded, s);
      expect(loaded.cycleDays, 7);
      expect(loaded.days.map((d) => d.planId), [
        'upperA',
        'lowerA',
        null,
        'upperB',
        'lowerB',
        null,
        null,
      ]);
      expect(loaded.days[2].isRest, isTrue);
    });

    test('upsert replaces the days; list is ordered by sort order; delete '
        'is soft', () async {
      await splits.upsert(split('a', 'Zed', 1, ['p1', null]));
      await splits.upsert(split('b', 'Alpha', 0, ['p2']));
      expect((await splits.watchAll().first).map((s) => s.id), ['b', 'a']);
      await splits.upsert(split('a', 'Zed', 1, ['p1', 'p3', null, null]));
      expect((await splits.byId('a'))!.cycleDays, 4);
      expect(await db.select(db.splitDays).get(), hasLength(5));
      await splits.delete('a');
      expect(await splits.byId('a'), isNull);
      expect((await splits.watchAll().first).map((s) => s.id), ['b']);
    });

    test('the database refuses a cycle of 0 or 15 days', () async {
      for (final days in [0, 15]) {
        await expectLater(
          db
              .into(db.trainingSplits)
              .insert(
                TrainingSplitsCompanion.insert(
                  id: 'x$days',
                  name: 'X',
                  cycleDays: days,
                  createdAt: _t,
                  updatedAt: _t,
                ),
              ),
          throwsA(anything),
        );
      }
    });
  });

  test('the database refuses invalid training rows (TD-25)', () async {
    await sessions.upsert(_session('s', _t, const []));
    Future<void> insert({
      int? reps,
      double? load,
      int? duration,
      double? metres,
      int? hr,
      double? kcal,
      String? provenance,
    }) => db
        .into(db.sessionSets)
        .insert(
          SessionSetsCompanion.insert(
            id: 'x${reps}_${load}_${duration}_${metres}_${hr}_$kcal',
            sessionId: 's',
            exerciseId: 'e',
            exerciseOrder: 0,
            setOrder: 0,
            type: 'weighted',
            reps: Value(reps),
            loadKg: Value(load),
            durationSec: Value(duration),
            metres: Value(metres),
            averageHeartRate: Value(hr),
            energyKcal: Value(kcal),
            energyProvenance: Value(provenance),
          ),
        );
    await expectLater(insert(reps: 0), throwsA(anything));
    await expectLater(insert(reps: 101), throwsA(anything));
    await expectLater(insert(load: -1), throwsA(anything));
    await expectLater(insert(duration: 0), throwsA(anything));
    await expectLater(insert(metres: 0), throwsA(anything));
    await expectLater(insert(hr: 300), throwsA(anything));
    await expectLater(insert(kcal: 100), throwsA(anything));
    await expectLater(
      insert(kcal: 100, provenance: 'verified'),
      throwsA(anything),
    );
    await insert(reps: 100, load: 0, duration: 1, metres: 0.1, hr: 250);
    await insert(kcal: 0, provenance: 'estimated');
  });
}
