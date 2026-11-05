import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
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
      expect(
        previousHint(ExerciseType.weighted, 0, previous, UnitSystem.metric),
        'Last: 80 kg × 5',
      );
      expect(
        previousHint(ExerciseType.weighted, 1, previous, UnitSystem.metric),
        'Last: 82.5 kg × 4',
      );
      // Past the end: the last set of last time.
      expect(
        previousHint(ExerciseType.weighted, 9, previous, UnitSystem.metric),
        'Last: 82.5 kg × 4',
      );
      expect(
        previousHint(ExerciseType.timed, 0, previous, UnitSystem.metric),
        isNull,
      );
      expect(planHint(previous), 'Plan: 3 sets · 8–10 reps · rest 90 s');
      expect(planHint(null), isNull);
    });
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
