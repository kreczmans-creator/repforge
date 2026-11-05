import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart' show DataProvenance;
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_validation.dart';
import 'package:repforge/domain/units/units.dart';

final _t = DateTime.utc(2026, 11);

LoadKg _kg(double v) => LoadKg.fromStored(v);

Exercise _ex(
  String id,
  String name, {
  ExerciseType type = ExerciseType.weighted,
  ExerciseCategory category = ExerciseCategory.push,
  MuscleGroup primary = MuscleGroup.chest,
  List<MuscleGroup> secondary = const [],
  List<Equipment> equipment = const [],
  List<String> aliases = const [],
  bool archived = false,
}) => Exercise(
  id: id,
  name: name,
  type: type,
  category: category,
  primaryMuscle: primary,
  secondaryMuscles: secondary,
  equipment: equipment,
  aliases: aliases,
  archived: archived,
  createdAt: _t,
  updatedAt: _t,
);

T _ok<T>(Result<T> r) => switch (r) {
  Ok(:final value) => value,
  Err(:final error) => fail('expected Ok, got ${error.message}'),
};

String? _field<T>(Result<T> r) => switch (r) {
  Err(:final error) =>
    error is ValidationError ? error.field : 'not-validation',
  Ok() => null,
};

void main() {
  group('taxonomy (docs/training-taxonomy.md)', () {
    test('has the documented sizes and identifiers', () {
      expect(ExerciseCategory.values.map((e) => e.name), [
        'push',
        'pull',
        'legs',
        'core',
        'fullBody',
        'cardio',
        'mobility',
      ]);
      expect(MuscleGroup.values, hasLength(19));
      expect(Equipment.values, hasLength(21));
      expect(MuscleGroup.values.map((e) => e.name), contains('frontDelts'));
      expect(Equipment.values.map((e) => e.name), contains('skippingRope'));
    });
  });

  group('parseDuration (TRN-005(2))', () {
    test('accepts mm:ss, h:mm:ss and plain seconds', () {
      expect(_ok(parseDuration('1:30')), const Duration(seconds: 90));
      expect(_ok(parseDuration('0:45')), const Duration(seconds: 45));
      expect(_ok(parseDuration('90:00')), const Duration(minutes: 90));
      expect(_ok(parseDuration('1:02:03')), const Duration(seconds: 3723));
      expect(_ok(parseDuration(' 90 ')), const Duration(seconds: 90));
      expect(_ok(parseDuration('7')), const Duration(seconds: 7));
    });

    test('rejects zero, malformed and out-of-range parts', () {
      for (final bad in [
        '',
        '  ',
        '0',
        '0:00',
        '0:0:0',
        '1:60',
        '1:2:60',
        '1:60:00',
        '1:2:3:4',
        'abc',
        '1:xx',
        '-5',
        '1.5',
        ':30',
        '1:',
        '1234567',
      ]) {
        expect(parseDuration(bad).isErr, isTrue, reason: bad);
      }
      expect(_field(parseDuration('0:00')), 'duration');
    });
  });

  group('formatDistance (TRN-006(2))', () {
    test('metres below 1000, kilometres from 1000', () {
      expect(formatDistance(400), '400 m');
      expect(formatDistance(999.5), '999.5 m');
      expect(formatDistance(1000), '1 km');
      expect(formatDistance(1234), '1.2 km');
      expect(formatDistance(1250), '1.3 km');
      expect(formatDistance(10000), '10 km');
      expect(formatDistance(42195), '42.2 km');
    });
  });

  group('exercise search (TRN-008(3))', () {
    test('normaliseExerciseSearch folds case, diacritics and spaces', () {
      expect(
        normaliseExerciseSearch('  Écarté   Haltères '),
        'ecarte halteres',
      );
      expect(normaliseExerciseSearch('BENCH'), 'bench');
    });

    final bench = _ex(
      'bench',
      'Bench Press',
      aliases: const ['Developpé couché', 'Flat Press'],
    );
    final fly = _ex('fly', 'Écarté couché');

    test('matches name and aliases ignoring case and diacritics', () {
      List<String> find(String q) => [
        for (final e in filterExercises([bench, fly], ExerciseQuery(text: q)))
          e.id,
      ];
      expect(find('bench'), ['bench']);
      expect(find('BENCH PRESS'), ['bench']);
      expect(find('developpe'), ['bench']);
      expect(find('développé'), ['bench']);
      expect(find('ecarte'), ['fly']);
      expect(find('écarté'), ['fly']);
      expect(find('couche'), ['bench', 'fly']);
      expect(find('flat'), ['bench']);
      expect(find('flat nothing'), isEmpty);
      expect(find(''), ['bench', 'fly']);
    });
  });

  group('validateExercise (TRN-012(1))', () {
    test('accepts and normalises', () {
      final r = _ok(
        validateExercise(
          _ex(
            'a',
            '  Cable Row ',
            secondary: const [MuscleGroup.biceps, MuscleGroup.biceps],
            equipment: const [Equipment.cable, Equipment.cable],
            aliases: const [' Seated row ', 'seated ROW', ' ', 'Row'],
          ),
        ),
      );
      expect(r.name, 'Cable Row');
      expect(r.secondaryMuscles, [MuscleGroup.biceps]);
      expect(r.equipment, [Equipment.cable]);
      expect(r.aliases, ['Seated row', 'Row']);
    });

    test('rejects a blank or long name, a primary repeated as secondary', () {
      expect(_field(validateExercise(_ex('a', '   '))), 'name');
      expect(_field(validateExercise(_ex('a', 'x' * 101))), 'name');
      expect(
        _field(
          validateExercise(
            _ex(
              'a',
              'Press',
              secondary: const [MuscleGroup.triceps, MuscleGroup.chest],
            ),
          ),
        ),
        'secondaryMuscles',
      );
      expect(
        _field(
          validateExercise(
            _ex('a', 'Press', aliases: [for (var i = 0; i < 21; i++) 'a$i']),
          ),
        ),
        'aliases',
      );
    });

    test('supplied is the single provenance concept; isCustom derives', () {
      expect(_ex('a', 'A').isCustom, isTrue);
      expect(_ex('a', 'A').copyWith(supplied: true).isCustom, isFalse);
    });
  });

  group('validateSetForExercise', () {
    final weighted = _ex('w', 'Squat');
    final bodyweight = _ex('b', 'Pull-up', type: ExerciseType.bodyweight);
    final assisted = _ex('a', 'Assisted dip', type: ExerciseType.assisted);
    final timed = _ex('t', 'Plank', type: ExerciseType.timed);
    final distance = _ex('d', 'Row', type: ExerciseType.distance);
    final cardio = _ex('c', 'Run', type: ExerciseType.cardio);

    test('accepts a valid set of each type unchanged', () {
      final cases = <(Exercise, SetData)>[
        (weighted, SetData.weighted(load: _kg(80), reps: 5)),
        (weighted, SetData.weighted(load: _kg(0), reps: 100)),
        (bodyweight, const SetData.bodyweight(reps: 12)),
        (bodyweight, SetData.bodyweight(reps: 8, addedLoad: _kg(10))),
        (assisted, SetData.assisted(reps: 6, assistance: _kg(20))),
        (timed, const SetData.timed(duration: Duration(seconds: 90))),
        (
          timed,
          SetData.timed(
            duration: const Duration(seconds: 30),
            addedLoad: _kg(5),
          ),
        ),
        (distance, const SetData.distance(metres: 400)),
        (
          distance,
          const SetData.distance(metres: 400, duration: Duration(seconds: 80)),
        ),
        (cardio, const SetData.cardio(duration: Duration(minutes: 30))),
        (
          cardio,
          const SetData.cardio(
            duration: Duration(minutes: 30),
            metres: 5000,
            averageHeartRate: 145,
            energyKcal: 320,
            energyProvenance: DataProvenance.estimated,
          ),
        ),
      ];
      for (final (e, d) in cases) {
        expect(_ok(validateSetForExercise(e, d)), d, reason: '$d');
      }
    });

    test('rejects a set whose type does not match the exercise', () {
      final r = validateSetForExercise(
        timed,
        SetData.weighted(load: _kg(60), reps: 5),
      );
      expect(_field(r), 'type');
      expect(
        _field(
          validateSetForExercise(
            weighted,
            const SetData.timed(duration: Duration(seconds: 60)),
          ),
        ),
        'type',
      );
      for (final e in [bodyweight, assisted, distance, cardio]) {
        expect(
          _field(
            validateSetForExercise(e, SetData.weighted(load: _kg(1), reps: 1)),
          ),
          'type',
        );
      }
    });

    test('repetitions are 1 to 100 for every rep-based type', () {
      for (final reps in [0, -1, 101]) {
        expect(
          _field(
            validateSetForExercise(
              weighted,
              SetData.weighted(load: _kg(50), reps: reps),
            ),
          ),
          'reps',
        );
        expect(
          _field(
            validateSetForExercise(bodyweight, SetData.bodyweight(reps: reps)),
          ),
          'reps',
        );
        expect(
          _field(
            validateSetForExercise(
              assisted,
              SetData.assisted(reps: reps, assistance: _kg(10)),
            ),
          ),
          'reps',
        );
      }
      expect(
        validateSetForExercise(
          weighted,
          SetData.weighted(load: _kg(1), reps: 1),
        ).isOk,
        isTrue,
      );
    });

    test('durations and distances must be greater than zero', () {
      for (final d in [
        Duration.zero,
        const Duration(milliseconds: 999),
        const Duration(seconds: -5),
      ]) {
        expect(
          _field(validateSetForExercise(timed, SetData.timed(duration: d))),
          'duration',
        );
        expect(
          _field(validateSetForExercise(cardio, SetData.cardio(duration: d))),
          'duration',
        );
        expect(
          _field(
            validateSetForExercise(
              distance,
              SetData.distance(metres: 100, duration: d),
            ),
          ),
          'duration',
        );
      }
      for (final m in [0.0, -1.0, 0.04, double.nan]) {
        expect(
          _field(validateSetForExercise(distance, SetData.distance(metres: m))),
          'metres',
          reason: '$m',
        );
        expect(
          _field(
            validateSetForExercise(
              cardio,
              SetData.cardio(duration: const Duration(minutes: 1), metres: m),
            ),
          ),
          'metres',
        );
      }
    });

    test('durations are stored in whole seconds, metres to 0.1 m', () {
      final t = _ok(
        validateSetForExercise(
          timed,
          const SetData.timed(duration: Duration(milliseconds: 90900)),
        ),
      );
      expect((t as TimedSet).duration, const Duration(seconds: 90));
      final d = _ok(
        validateSetForExercise(
          distance,
          const SetData.distance(metres: 400.06),
        ),
      );
      expect((d as DistanceSet).metres, 400.1);
      final small = _ok(
        validateSetForExercise(distance, const SetData.distance(metres: 0.05)),
      );
      expect((small as DistanceSet).metres, 0.1);
    });

    test('heart rate is 30 to 250 bpm', () {
      SetData hr(int v) => SetData.cardio(
        duration: const Duration(minutes: 10),
        averageHeartRate: v,
      );
      for (final bad in [300, 251, 29, 0, -1]) {
        expect(
          _field(validateSetForExercise(cardio, hr(bad))),
          'averageHeartRate',
          reason: '$bad',
        );
      }
      expect(validateSetForExercise(cardio, hr(30)).isOk, isTrue);
      expect(validateSetForExercise(cardio, hr(250)).isOk, isTrue);
    });

    test('energy is at least 0 and carries a user-entered or estimated '
        'label (TRN-007(2))', () {
      SetData energy(double? kcal, DataProvenance? p) => SetData.cardio(
        duration: const Duration(minutes: 30),
        energyKcal: kcal,
        energyProvenance: p,
      );
      expect(
        validateSetForExercise(
          cardio,
          energy(0, DataProvenance.userEntered),
        ).isOk,
        isTrue,
      );
      expect(
        validateSetForExercise(
          cardio,
          energy(250, DataProvenance.estimated),
        ).isOk,
        isTrue,
      );
      expect(
        _field(
          validateSetForExercise(
            cardio,
            energy(-1, DataProvenance.userEntered),
          ),
        ),
        'energyKcal',
      );
      expect(
        _field(validateSetForExercise(cardio, energy(250, null))),
        'energyProvenance',
        reason: 'unlabelled energy',
      );
      for (final p in [DataProvenance.verified, DataProvenance.crowdsourced]) {
        expect(
          _field(validateSetForExercise(cardio, energy(250, p))),
          'energyProvenance',
          reason: '$p is not a valid energy label',
        );
      }
      expect(
        _field(
          validateSetForExercise(
            cardio,
            energy(null, DataProvenance.estimated),
          ),
        ),
        'energyProvenance',
        reason: 'label without a value',
      );
    });

    test('exertion must be valid for its scale', () {
      final set = SetData.weighted(load: _kg(60), reps: 5);
      Result<SetData> with_(Exertion e) =>
          validateSetForExercise(weighted, set, exertion: e);
      expect(
        with_(const Exertion(scale: ExertionScale.rpe, value: 8.5)).isOk,
        isTrue,
      );
      expect(
        with_(const Exertion(scale: ExertionScale.rir, value: 0)).isOk,
        isTrue,
      );
      for (final bad in [
        const Exertion(scale: ExertionScale.rpe, value: 0.5),
        const Exertion(scale: ExertionScale.rpe, value: 10.5),
        const Exertion(scale: ExertionScale.rpe, value: 8.3),
        const Exertion(scale: ExertionScale.rir, value: -1),
        const Exertion(scale: ExertionScale.rir, value: 11),
      ]) {
        expect(_field(with_(bad)), 'exertion', reason: '$bad');
      }
    });
  });

  group('LoadKg.strict (TRN-002(2))', () {
    test('accepts 0.25 kg steps and refuses other steps and negatives', () {
      expect(_ok(LoadKg.strict(80)).value, 80);
      expect(_ok(LoadKg.strict(62.5)).value, 62.5);
      expect(_ok(LoadKg.strict(0.25)).value, 0.25);
      expect(_ok(LoadKg.strict(0)).value, 0);
      expect(LoadKg.strict(0.1).isErr, isTrue);
      expect(LoadKg.strict(62.3).isErr, isTrue);
      expect(LoadKg.strict(-0.25).isErr, isTrue);
      expect(LoadKg.strict(1000.25).isErr, isTrue);
      expect(LoadKg.strict(double.nan).isErr, isTrue);
      // The lenient constructor still rounds (display / legacy input).
      expect(_ok(LoadKg.of(0.1)).value, 0);
    });
  });

  group('validatePlanExercise (TRN-013(1))', () {
    PlanExercise pe({
      int sets = 3,
      int? min = 8,
      int? max = 10,
      int? rest = 120,
      Duration? duration,
      double? metres,
      LoadKg? load,
      int order = 0,
    }) => PlanExercise(
      id: 'p',
      exerciseId: 'e',
      sortOrder: order,
      targetSets: sets,
      repsMin: min,
      repsMax: max,
      restSeconds: rest,
      targetDuration: duration,
      targetMetres: metres,
      targetLoad: load,
    );

    test('3 sets of 8 to 10 reps with 120 s rest is valid', () {
      final r = _ok(validatePlanExercise(pe()));
      expect(
        [r.targetSets, r.repsMin, r.repsMax, r.restSeconds],
        [3, 8, 10, 120],
      );
      expect(validatePlanExercise(pe(max: 8)).isOk, isTrue);
      expect(validatePlanExercise(pe(min: null, max: null)).isOk, isTrue);
      expect(validatePlanExercise(pe(sets: 20, rest: 0)).isOk, isTrue);
      expect(validatePlanExercise(pe(rest: 3600)).isOk, isTrue);
    });

    test('rejects out-of-range sets, reps and rest', () {
      expect(_field(validatePlanExercise(pe(sets: 0))), 'targetSets');
      expect(_field(validatePlanExercise(pe(sets: 21))), 'targetSets');
      expect(_field(validatePlanExercise(pe(min: 10, max: 8))), 'reps');
      expect(_field(validatePlanExercise(pe(min: 0, max: 8))), 'reps');
      expect(_field(validatePlanExercise(pe(max: 101))), 'reps');
      expect(_field(validatePlanExercise(pe(max: null))), 'reps');
      expect(_field(validatePlanExercise(pe(min: null, max: 8))), 'reps');
      expect(_field(validatePlanExercise(pe(rest: -1))), 'restSeconds');
      expect(_field(validatePlanExercise(pe(rest: 3601))), 'restSeconds');
      expect(_field(validatePlanExercise(pe(order: -1))), 'sortOrder');
    });

    test('duration and distance targets are positive and normalised', () {
      expect(
        _field(
          validatePlanExercise(
            pe(min: null, max: null, duration: Duration.zero),
          ),
        ),
        'targetDuration',
      );
      expect(
        _field(validatePlanExercise(pe(min: null, max: null, metres: 0))),
        'targetMetres',
      );
      final r = _ok(
        validatePlanExercise(pe(min: null, max: null, metres: 1500.04)),
      );
      expect(r.targetMetres, 1500);
    });

    test('targets must fit the exercise type', () {
      expect(
        _field(validatePlanExercise(pe(), type: ExerciseType.timed)),
        'reps',
      );
      expect(
        _field(
          validatePlanExercise(
            pe(min: null, max: null, duration: const Duration(seconds: 60)),
            type: ExerciseType.weighted,
          ),
        ),
        'duration',
      );
      expect(
        _field(
          validatePlanExercise(
            pe(min: null, max: null, metres: 500),
            type: ExerciseType.timed,
          ),
        ),
        'metres',
      );
      expect(
        _field(
          validatePlanExercise(
            pe(min: null, max: null, load: _kg(10)),
            type: ExerciseType.cardio,
          ),
        ),
        'load',
      );
      expect(
        validatePlanExercise(
          pe(min: null, max: null, metres: 5000, rest: null),
          type: ExerciseType.cardio,
        ).isOk,
        isTrue,
      );
      expect(
        validatePlanExercise(pe(), type: ExerciseType.weighted).isOk,
        isTrue,
      );
    });
  });

  group('validateSplit (TRN-014)', () {
    TrainingSplit split(List<String?> days, {String name = 'Upper/Lower'}) =>
        TrainingSplit(
          id: 's',
          name: name,
          days: [for (final d in days) SplitDay(planId: d)],
          createdAt: _t,
          updatedAt: _t,
        );

    test('a 7-day cycle with rest days is valid', () {
      final s = split(['ua', 'la', null, 'ub', 'lb', null, null]);
      final r = _ok(validateSplit(s));
      expect(r.cycleDays, 7);
      expect(r.days.where((d) => d.isRest), hasLength(3));
    });

    test('cycle must be 1 to 14 days with at least one workout', () {
      expect(validateSplit(split(['a'])).isOk, isTrue);
      expect(validateSplit(split(List.filled(14, 'a'))).isOk, isTrue);
      expect(_field(validateSplit(split([]))), 'days');
      expect(_field(validateSplit(split(List.filled(15, 'a')))), 'days');
      expect(_field(validateSplit(split([null, null]))), 'days');
      expect(_field(validateSplit(split(['a', '  ']))), 'days');
      expect(_field(validateSplit(split(['a'], name: ' '))), 'name');
    });
  });

  group('reorder (TRN-013(2))', () {
    test('moves an element to the target index', () {
      expect(_ok(reorder([1, 2, 3, 4], 0, 2)), [2, 3, 1, 4]);
      expect(_ok(reorder([1, 2, 3, 4], 3, 0)), [4, 1, 2, 3]);
      expect(_ok(reorder([1, 2, 3, 4], 1, 2)), [1, 3, 2, 4]);
      expect(_ok(reorder([1, 2, 3], 1, 1)), [1, 2, 3]);
    });

    test('rejects indices outside the list and does not mutate', () {
      final list = [1, 2, 3];
      expect(reorder(list, -1, 0).isErr, isTrue);
      expect(reorder(list, 0, 3).isErr, isTrue);
      expect(reorder(<int>[], 0, 0).isErr, isTrue);
      expect(list, [1, 2, 3]);
    });

    test('reorderPlanExercises renumbers sortOrder', () {
      final list = [
        for (var i = 0; i < 3; i++)
          PlanExercise(
            id: 'p$i',
            exerciseId: 'e$i',
            sortOrder: i,
            targetSets: 3,
          ),
      ];
      final moved = _ok(reorderPlanExercises(list, 2, 0));
      expect(moved.map((e) => e.id), ['p2', 'p0', 'p1']);
      expect(moved.map((e) => e.sortOrder), [0, 1, 2]);
    });
  });

  group('library filters', () {
    final bench = _ex(
      'bench',
      'Bench Press',
      secondary: const [MuscleGroup.triceps, MuscleGroup.frontDelts],
      equipment: const [Equipment.barbell, Equipment.bench],
    );
    final dip = _ex(
      'dip',
      'Dip',
      type: ExerciseType.bodyweight,
      primary: MuscleGroup.triceps,
      secondary: const [MuscleGroup.chest],
      equipment: const [Equipment.dipBars],
    );
    final pushUp = _ex(
      'pushup',
      'Push-up',
      type: ExerciseType.bodyweight,
      secondary: const [MuscleGroup.triceps],
    );
    final pushdown = _ex(
      'pushdown',
      'Triceps pushdown',
      primary: MuscleGroup.triceps,
      equipment: const [Equipment.cable],
    );
    final run = _ex(
      'run',
      'Run',
      type: ExerciseType.cardio,
      category: ExerciseCategory.cardio,
      primary: MuscleGroup.fullBody,
      equipment: const [Equipment.treadmill],
    );
    final old = _ex(
      'old',
      'Archived curl',
      primary: MuscleGroup.biceps,
      archived: true,
    );
    final all = [bench, dip, pushUp, pushdown, run, old];

    List<String> ids(ExerciseQuery q) => [
      for (final e in filterExercises(all, q)) e.id,
    ];

    test('muscle filter returns primary or secondary, primary first '
        '(TRN-010(2))', () {
      expect(ids(const ExerciseQuery(muscle: MuscleGroup.chest)), [
        'bench', // primary, by name
        'pushup', // primary
        'dip', // secondary
      ]);
      expect(ids(const ExerciseQuery(muscle: MuscleGroup.triceps)), [
        'dip', // primary
        'pushdown', // primary
        'bench', // secondary
        'pushup', // secondary
      ]);
      expect(ids(const ExerciseQuery(muscle: MuscleGroup.quadriceps)), isEmpty);
    });

    test('equipment filter shows exercises whose equipment is a subset of '
        'what is available; bodyweight always shows (TRN-011(2))', () {
      expect(
        ids(
          const ExerciseQuery(
            availableEquipment: {Equipment.barbell, Equipment.bench},
          ),
        ),
        ['bench', 'pushup'],
      );
      expect(
        ids(const ExerciseQuery(availableEquipment: {Equipment.barbell})),
        ['pushup'],
        reason: 'the bench press also needs a bench',
      );
      expect(ids(const ExerciseQuery(availableEquipment: {})), ['pushup']);
      expect(
        ids(
          const ExerciseQuery(
            availableEquipment: {Equipment.cable, Equipment.dipBars},
          ),
        ),
        ['dip', 'pushup', 'pushdown'],
      );
      expect(ids(const ExerciseQuery()), hasLength(5), reason: 'no filter');
    });

    test(
      'category filter (TRN-009(2)) and archived exercises (TRN-012(2))',
      () {
        expect(ids(const ExerciseQuery(category: ExerciseCategory.cardio)), [
          'run',
        ]);
        expect(ids(const ExerciseQuery()), isNot(contains('old')));
        expect(
          ids(const ExerciseQuery(includeArchived: true)),
          contains('old'),
        );
      },
    );

    test('filters combine', () {
      expect(
        ids(
          const ExerciseQuery(
            text: 'press',
            muscle: MuscleGroup.chest,
            category: ExerciseCategory.push,
            availableEquipment: {Equipment.barbell, Equipment.bench},
          ),
        ),
        ['bench'],
      );
    });

    test('ExerciseQuery has value equality', () {
      expect(
        const ExerciseQuery(
          availableEquipment: {Equipment.cable, Equipment.bench},
        ),
        const ExerciseQuery(
          availableEquipment: {Equipment.bench, Equipment.cable},
        ),
      );
      expect(const ExerciseQuery(text: 'a'), isNot(const ExerciseQuery()));
      expect(
        const ExerciseQuery(availableEquipment: {Equipment.cable}).hashCode,
        const ExerciseQuery(availableEquipment: {Equipment.cable}).hashCode,
      );
    });
  });

  group('SplitDay', () {
    test('a day without a plan is a rest day', () {
      expect(const SplitDay().isRest, isTrue);
      expect(const SplitDay(planId: 'x').isRest, isFalse);
    });
  });
}
