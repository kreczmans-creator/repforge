import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_rules.dart';
import 'package:repforge/domain/training/volume.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/session_view.dart';
import 'package:repforge/features/training/presentation/set_defaults.dart';
import 'package:repforge/features/training/presentation/set_form.dart';
import 'package:repforge/features/training/presentation/volume_format.dart';

LoadKg kg(double v) => LoadKg.fromStored(v);

SessionSet set(
  String id,
  SetData data, {
  int order = 0,
  SetKind kind = SetKind.working,
}) => SessionSet(
  id: id,
  sessionId: 's',
  exerciseId: 'e',
  exerciseOrder: 0,
  setOrder: order,
  data: data,
  completed: true,
  kind: kind,
);

ValidationError? _error(Result<Object?> r) =>
    r is Err ? r.error as ValidationError : null;

void main() {
  group('next-set defaults (TRN-016(1), TRN-018)', () {
    final previous = EntryPrefill(
      sessionExerciseId: 'x',
      exerciseId: 'e',
      previous: [
        set('p0', SetData.weighted(load: kg(80), reps: 5)),
        set('p1', SetData.weighted(load: kg(82.5), reps: 4), order: 1),
      ],
      target: const PlanExercise(
        id: 'pe',
        exerciseId: 'e',
        sortOrder: 0,
        targetSets: 3,
        repsMin: 8,
        repsMax: 10,
        restSeconds: 90,
      ),
    );

    test('own last set wins, then the previous session, then the plan', () {
      final own = [set('a', SetData.weighted(load: kg(100), reps: 3))];
      var d = nextSetDraft(
        type: ExerciseType.weighted,
        entrySets: own,
        prefill: previous,
      );
      expect((d.load, d.reps), ('100', '3'));

      d = nextSetDraft(
        type: ExerciseType.weighted,
        entrySets: const [],
        prefill: previous,
      );
      expect((d.load, d.reps), ('80', '5'));
      // The second set looks at the second set of last time.
      d = nextSetDraft(
        type: ExerciseType.weighted,
        entrySets: [
          set(
            'a',
            SetData.weighted(load: kg(1), reps: 1),
            kind: SetKind.warmUp,
          ),
          ...const [],
        ],
        prefill: previous,
      );
      expect((d.load, d.reps), ('80', '5'));

      d = nextSetDraft(
        type: ExerciseType.weighted,
        entrySets: const [],
        prefill: const EntryPrefill(
          sessionExerciseId: 'x',
          exerciseId: 'e',
          target: PlanExercise(
            id: 'pe',
            exerciseId: 'e',
            sortOrder: 0,
            targetSets: 3,
            repsMin: 8,
            repsMax: 10,
          ),
        ),
      );
      expect((d.load, d.reps), ('', '8'));
      expect(
        nextSetDraft(
          type: ExerciseType.weighted,
          entrySets: const [],
          prefill: null,
        ).reps,
        '',
      );
    });

    test('hints', () {
      SessionSet own(int i) =>
          set('o$i', SetData.weighted(load: kg(1), reps: 1), order: i);
      String? hint(List<SessionSet> sets, [ExerciseType? t]) => previousHint(
        t ?? ExerciseType.weighted,
        sets,
        previous,
        UnitSystem.metric,
      );
      expect(hint(const []), 'Last: 80 kg × 5');
      expect(hint([own(0)]), 'Last: 82.5 kg × 4');
      // Past the end: the last set of last time.
      expect(hint([for (var i = 0; i < 9; i++) own(i)]), 'Last: 82.5 kg × 4');
      expect(hint(const [], ExerciseType.timed), isNull);
      expect(planHint(previous), 'Plan: 3 sets · 8–10 reps · rest 90 s');
      expect(planHint(null), isNull);
    });
  });

  group('pre-fill matches warm-ups with warm-ups (final review M3)', () {
    SessionSet w(String id, double load, int reps, SetKind kind, int order) =>
        set(
          id,
          SetData.weighted(load: kg(load), reps: reps),
          order: order,
          kind: kind,
        );
    final previous = EntryPrefill(
      sessionExerciseId: 'x',
      exerciseId: 'e',
      previous: [
        w('p0', 40, 10, SetKind.warmUp, 0),
        w('p1', 100, 5, SetKind.working, 1),
        w('p2', 100, 5, SetKind.working, 2),
      ],
    );

    SetDraft next(List<SessionSet> own, [EntryPrefill? prefill]) =>
        nextSetDraft(
          type: ExerciseType.weighted,
          entrySets: own,
          prefill: prefill ?? previous,
        );

    test('the first row is the previous warm-up, with its kind', () {
      final d = next(const []);
      expect((d.load, d.reps, d.kind), ('40', '10', SetKind.warmUp));
    });

    test('after the warm-up is logged the next row is working 100 x 5', () {
      final d = next([w('a', 40, 10, SetKind.warmUp, 0)]);
      expect((d.load, d.reps, d.kind), ('100', '5', SetKind.working));
      // And the hint names the working set, not the warm-up.
      expect(
        previousHint(
          ExerciseType.weighted,
          [w('a', 40, 10, SetKind.warmUp, 0)],
          previous,
          UnitSystem.metric,
        ),
        'Last: 100 kg × 5',
      );
    });

    test('with no warm-up today the working rows still match', () {
      // The user skipped the warm-up and logged a working set directly.
      final first = w('a', 100, 5, SetKind.working, 0);
      var d = next([first]);
      expect((d.load, d.reps, d.kind), ('100', '5', SetKind.working));
      d = next([first, w('b', 102.5, 5, SetKind.working, 1)]);
      expect((d.load, d.reps, d.kind), ('102.5', '5', SetKind.working));
    });

    test('a previous session without warm-ups never proposes one', () {
      final noWarm = EntryPrefill(
        sessionExerciseId: 'x',
        exerciseId: 'e',
        previous: [
          w('p0', 100, 5, SetKind.working, 0),
          w('p1', 100, 3, SetKind.failure, 1),
        ],
      );
      var d = next(const [], noWarm);
      expect((d.load, d.kind), ('100', SetKind.working));
      // A matched failure set pre-fills a working row (final review N3).
      d = next([w('a', 100, 5, SetKind.working, 0)], noWarm);
      expect(d.kind, SetKind.working);
    });

    test('only warm-up vs working carries over; a failure set becomes '
        'working (N3)', () {
      final prev = EntryPrefill(
        sessionExerciseId: 'x',
        exerciseId: 'e',
        previous: [
          w('p0', 100, 5, SetKind.working, 0),
          w('p1', 100, 5, SetKind.working, 1),
          w('p2', 100, 3, SetKind.failure, 2),
        ],
      );
      final own = [
        w('a', 100, 5, SetKind.working, 0),
        w('b', 100, 5, SetKind.working, 1),
      ];
      final d = next(own, prev);
      expect(d.kind, SetKind.working);
      expect(
        matchPrevious(
          type: ExerciseType.weighted,
          entrySets: own,
          prefill: prev,
        ).kind,
        SetKind.working,
      );
    });

    test('the hint says when the matched set was a warm-up (N1)', () {
      expect(
        previousHint(
          ExerciseType.weighted,
          const [],
          previous,
          UnitSystem.metric,
        ),
        'Last: 40 kg × 10 (warm-up)',
      );
    });

    test('a previous session of warm-ups only leaves working rows to the '
        'plan', () {
      final onlyWarm = EntryPrefill(
        sessionExerciseId: 'x',
        exerciseId: 'e',
        previous: [w('p0', 40, 10, SetKind.warmUp, 0)],
        target: const PlanExercise(
          id: 'pe',
          exerciseId: 'e',
          sortOrder: 0,
          targetSets: 3,
          repsMin: 8,
          repsMax: 8,
        ),
      );
      final d = next([w('a', 40, 10, SetKind.warmUp, 0)], onlyWarm);
      expect((d.reps, d.kind), ('8', SetKind.working));
    });
  });

  test('exertion labels come from the rule constants (final review L11)', () {
    expect(
      exertionFieldLabel(ExertionScale.rpe),
      'RPE (${TrainingRules.rpeMin}–${TrainingRules.rpeMax})',
    );
    expect(
      exertionFieldLabel(ExertionScale.rir),
      'RIR (${TrainingRules.rirMin}–${TrainingRules.rirMax})',
    );
  });

  group('SetFormController typed values', () {
    test('weighted: strict load, required fields', () {
      final c = SetFormController(type: ExerciseType.weighted);
      expect(_error(c.parseData())!.field, 'loadKg');
      c.load.text = '80,5';
      c.reps.text = '';
      expect(_error(c.parseData())!.field, 'reps');
      c.reps.text = '5';
      expect(
        (c.parseData() as Ok<SetData>).value,
        SetData.weighted(load: kg(80.5), reps: 5),
      );
      c.load.text = '80.1';
      expect(_error(c.parseData())!.field, 'loadKg');
      c.load.text = 'abc';
      expect(_error(c.parseData())!.field, 'loadKg');
      c.dispose();
    });

    test('other types', () {
      var c = SetFormController(type: ExerciseType.bodyweight)
        ..reps.text = '12';
      expect(
        (c.parseData() as Ok<SetData>).value,
        const SetData.bodyweight(reps: 12),
      );
      c.load.text = '10';
      expect(
        (c.parseData() as Ok<SetData>).value,
        SetData.bodyweight(reps: 12, addedLoad: kg(10)),
      );
      c.dispose();

      c = SetFormController(type: ExerciseType.assisted)..reps.text = '8';
      expect(_error(c.parseData())!.field, 'loadKg');
      c
        ..load.text = '20'
        ..dispose();

      c = SetFormController(type: ExerciseType.timed);
      expect(_error(c.parseData())!.field, 'duration');
      c.duration.text = '1:30';
      expect(
        (c.parseData() as Ok<SetData>).value,
        const SetData.timed(duration: Duration(seconds: 90)),
      );
      c.dispose();

      c = SetFormController(type: ExerciseType.distance)..metres.text = '400';
      expect(
        (c.parseData() as Ok<SetData>).value,
        const SetData.distance(metres: 400),
      );
      c.duration.text = '2:00';
      expect(
        (c.parseData() as Ok<SetData>).value,
        const SetData.distance(metres: 400, duration: Duration(minutes: 2)),
      );
      c.dispose();

      c = SetFormController(type: ExerciseType.cardio)
        ..duration.text = '20:00'
        ..heartRate.text = '140';
      expect(
        (c.parseData() as Ok<SetData>).value,
        const SetData.cardio(
          duration: Duration(minutes: 20),
          averageHeartRate: 140,
        ),
      );
      c.heartRate.text = 'x';
      expect(_error(c.parseData())!.field, 'averageHeartRate');
      c.dispose();
    });

    test('exertion and rest are parsed, never judged here', () {
      final c = SetFormController(type: ExerciseType.weighted);
      expect(
        (c.parseExertion(ExertionScale.rpe) as Ok<Exertion?>).value,
        isNull,
      );
      c.exertion.text = '11';
      // Out-of-range values reach the use case, which rejects them.
      expect(
        (c.parseExertion(ExertionScale.rpe) as Ok<Exertion?>).value,
        const Exertion(scale: ExertionScale.rpe, value: 11),
      );
      c.exertion.text = 'x';
      expect(_error(c.parseExertion(ExertionScale.rir))!.field, 'exertion');
      c.rest.text = '90';
      expect((c.parseRest() as Ok<int?>).value, 90);
      c.rest.text = '9x';
      expect(_error(c.parseRest())!.field, 'restSeconds');
      c.dispose();
    });
  });

  test('volume text by measure', () {
    expect(formatVolume(VolumeTotals.zero), 'none yet');
    expect(formatVolume(const VolumeTotals(loadKg: 720, sets: 2)), '720 kg');
    expect(
      formatVolume(
        const VolumeTotals(reps: 20, seconds: 90, metres: 1500, sets: 3),
      ),
      '20 reps · 1:30 · 1.5 km',
    );
  });
}
