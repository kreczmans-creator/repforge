import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_rules.dart';
import 'package:repforge/domain/units/units.dart';

LoadKg _kg(double v) => LoadKg.fromStored(v);
SetData _w(double kg, int reps) => SetData.weighted(load: _kg(kg), reps: reps);

void main() {
  group('volumeKg', () {
    test('weighted is load x reps', () {
      expect(TrainingRules.volumeKg([_w(80, 5)]), 400);
    });

    test('bodyweight counts added load only', () {
      expect(
        TrainingRules.volumeKg([
          SetData.bodyweight(reps: 8, addedLoad: _kg(10)),
        ]),
        80,
      );
      expect(TrainingRules.volumeKg([const SetData.bodyweight(reps: 8)]), 0);
    });

    test('assisted, timed, distance and cardio contribute zero', () {
      expect(
        TrainingRules.volumeKg([
          SetData.assisted(reps: 8, assistance: _kg(30)),
          const SetData.timed(duration: Duration(seconds: 60)),
          const SetData.distance(metres: 400),
          const SetData.cardio(duration: Duration(minutes: 10), metres: 2000),
        ]),
        0,
      );
    });

    test('sums a mixed collection and handles empty', () {
      expect(
        TrainingRules.volumeKg([
          _w(80, 5),
          SetData.bodyweight(reps: 8, addedLoad: _kg(10)),
          const SetData.timed(duration: Duration(seconds: 30)),
        ]),
        480,
      );
      expect(TrainingRules.volumeKg(const []), 0);
    });
  });

  group('estimatedOneRepMax', () {
    test('Epley: 100 kg x 5 = 116.67', () {
      expect(
        TrainingRules.estimatedOneRepMax(_w(100, 5)),
        closeTo(116.67, 0.01),
      );
    });

    test('a single rep returns the load', () {
      expect(TrainingRules.estimatedOneRepMax(_w(140, 1)), 140);
    });

    test('12 reps is defined, 13 reps and 0 reps are null', () {
      expect(TrainingRules.estimatedOneRepMax(_w(100, 12)), closeTo(140, 0.01));
      expect(TrainingRules.estimatedOneRepMax(_w(100, 13)), isNull);
      expect(TrainingRules.estimatedOneRepMax(_w(100, 0)), isNull);
    });

    test('non-weighted sets are null', () {
      expect(
        TrainingRules.estimatedOneRepMax(
          SetData.bodyweight(reps: 5, addedLoad: _kg(10)),
        ),
        isNull,
      );
      expect(
        TrainingRules.estimatedOneRepMax(
          const SetData.timed(duration: Duration(seconds: 5)),
        ),
        isNull,
      );
    });
  });

  group('maxLoadFor', () {
    final sets = [
      _w(100, 3),
      _w(90, 8),
      _w(95, 5),
      const SetData.distance(metres: 5),
    ];

    test('defaults to any reps', () {
      expect(TrainingRules.maxLoadFor(sets), _kg(100));
    });

    test('respects minReps', () {
      expect(TrainingRules.maxLoadFor(sets, minReps: 5), _kg(95));
      expect(TrainingRules.maxLoadFor(sets, minReps: 8), _kg(90));
      expect(TrainingRules.maxLoadFor(sets, minReps: 9), isNull);
    });

    test('is null with no weighted sets', () {
      expect(TrainingRules.maxLoadFor(const []), isNull);
    });
  });

  group('isPersonalRecord', () {
    test('weighted compares estimated 1RM; tie is not a record', () {
      final history = [_w(100, 5)];
      expect(TrainingRules.isPersonalRecord(_w(102.5, 5), history), isTrue);
      expect(TrainingRules.isPersonalRecord(_w(100, 5), history), isFalse);
      expect(TrainingRules.isPersonalRecord(_w(95, 5), history), isFalse);
      expect(TrainingRules.isPersonalRecord(_w(100, 6), history), isTrue);
    });

    test('weighted uses the Epley score at any rep count; first set is a '
        'record', () {
      expect(TrainingRules.isPersonalRecord(_w(100, 5), const []), isTrue);
      // 100 × 13 → 143.3 beats 100 × 5 → 116.7 even though the display
      // estimate is undefined beyond 12 reps.
      expect(TrainingRules.isPersonalRecord(_w(100, 13), [_w(100, 5)]), isTrue);
      expect(
        TrainingRules.isPersonalRecord(_w(100, 5), [_w(100, 13)]),
        isFalse,
      );
    });

    test('weighted ignores other variants in history', () {
      expect(
        TrainingRules.isPersonalRecord(_w(50, 5), [
          const SetData.bodyweight(reps: 50),
        ]),
        isTrue,
      );
    });

    test('bodyweight compares reps; tie is not a record', () {
      final history = [const SetData.bodyweight(reps: 10)];
      expect(
        TrainingRules.isPersonalRecord(
          const SetData.bodyweight(reps: 11),
          history,
        ),
        isTrue,
      );
      expect(
        TrainingRules.isPersonalRecord(
          const SetData.bodyweight(reps: 10),
          history,
        ),
        isFalse,
      );
    });

    test('assisted: less assistance or more reps at equal assistance', () {
      final history = [SetData.assisted(reps: 8, assistance: _kg(20))];
      expect(
        TrainingRules.isPersonalRecord(
          SetData.assisted(reps: 5, assistance: _kg(15)),
          history,
        ),
        isTrue,
      );
      expect(
        TrainingRules.isPersonalRecord(
          SetData.assisted(reps: 9, assistance: _kg(20)),
          history,
        ),
        isTrue,
      );
      expect(
        TrainingRules.isPersonalRecord(
          SetData.assisted(reps: 8, assistance: _kg(20)),
          history,
        ),
        isFalse,
      );
      expect(
        TrainingRules.isPersonalRecord(
          SetData.assisted(reps: 12, assistance: _kg(25)),
          history,
        ),
        isFalse,
      );
    });

    test('timed compares duration; tie is not a record', () {
      final history = [const SetData.timed(duration: Duration(seconds: 60))];
      expect(
        TrainingRules.isPersonalRecord(
          const SetData.timed(duration: Duration(seconds: 61)),
          history,
        ),
        isTrue,
      );
      expect(
        TrainingRules.isPersonalRecord(
          const SetData.timed(duration: Duration(seconds: 60)),
          history,
        ),
        isFalse,
      );
    });

    test('distance compares metres; tie is not a record', () {
      final history = [const SetData.distance(metres: 400)];
      expect(
        TrainingRules.isPersonalRecord(
          const SetData.distance(metres: 400.5),
          history,
        ),
        isTrue,
      );
      expect(
        TrainingRules.isPersonalRecord(
          const SetData.distance(metres: 400),
          history,
        ),
        isFalse,
      );
    });

    test('cardio compares metres; null metres is never a record', () {
      final history = [
        const SetData.cardio(duration: Duration(minutes: 10), metres: 2000),
        const SetData.cardio(duration: Duration(minutes: 10)),
      ];
      expect(
        TrainingRules.isPersonalRecord(
          const SetData.cardio(duration: Duration(minutes: 9), metres: 2100),
          history,
        ),
        isTrue,
      );
      expect(
        TrainingRules.isPersonalRecord(
          const SetData.cardio(duration: Duration(minutes: 9), metres: 2000),
          history,
        ),
        isFalse,
      );
      expect(
        TrainingRules.isPersonalRecord(
          const SetData.cardio(duration: Duration(minutes: 30)),
          history,
        ),
        isFalse,
      );
    });
  });

  group('validReps', () {
    test('accepts 1..100 only', () {
      expect(TrainingRules.validReps(0), isFalse);
      expect(TrainingRules.validReps(1), isTrue);
      expect(TrainingRules.validReps(100), isTrue);
      expect(TrainingRules.validReps(101), isFalse);
      expect(TrainingRules.validReps(-3), isFalse);
    });
  });

  group('validExertion', () {
    bool ok(ExertionScale s, double v) =>
        TrainingRules.validExertion(Exertion(scale: s, value: v));

    test('RPE is 1-10 in half steps', () {
      expect(ok(ExertionScale.rpe, 1), isTrue);
      expect(ok(ExertionScale.rpe, 8.5), isTrue);
      expect(ok(ExertionScale.rpe, 10), isTrue);
      expect(ok(ExertionScale.rpe, 0), isFalse);
      expect(ok(ExertionScale.rpe, 0.5), isFalse);
      expect(ok(ExertionScale.rpe, 10.5), isFalse);
      expect(ok(ExertionScale.rpe, 7.3), isFalse);
    });

    test('RIR is 0-10 in half steps', () {
      expect(ok(ExertionScale.rir, 0), isTrue);
      expect(ok(ExertionScale.rir, 2.5), isTrue);
      expect(ok(ExertionScale.rir, 10), isTrue);
      expect(ok(ExertionScale.rir, -1), isFalse);
      expect(ok(ExertionScale.rir, 10.5), isFalse);
      expect(ok(ExertionScale.rir, 7.3), isFalse);
    });
  });
}
