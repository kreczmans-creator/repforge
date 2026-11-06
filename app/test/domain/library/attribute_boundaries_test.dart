import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';

/// X1 (deferred review item): the attribute boundary rules are contiguous, so
/// every measurement maps to exactly one value and no gap is left between the
/// values (angle 10 to 15 degrees, arm 20 to 90 degrees, knee 10 to 90).
void main() {
  group('angle', () {
    test('flat, incline and decline cover every angle without a gap', () {
      for (var d = -90.0; d <= 45.0; d += 0.5) {
        expect(AttributeBoundaries.angle(d), isNotNull, reason: '$d degrees');
      }
      expect(AttributeBoundaries.angle(-10.5), 'decline');
      expect(AttributeBoundaries.angle(-10), 'flat');
      expect(AttributeBoundaries.angle(0), 'flat');
      expect(AttributeBoundaries.angle(10), 'flat');
      expect(
        AttributeBoundaries.angle(10.5),
        'incline',
      ); // the old 10 to 15 gap
      expect(AttributeBoundaries.angle(12.5), 'incline');
      expect(AttributeBoundaries.angle(15), 'incline');
      expect(AttributeBoundaries.angle(45), 'incline');
    });

    test('steeper than 45 degrees is a vertical push and has no value', () {
      expect(AttributeBoundaries.angle(45.5), isNull);
      expect(AttributeBoundaries.angle(90), isNull);
      expect(AttributeBoundaries.angle(-91), isNull);
      expect(AttributeBoundaries.angle(double.nan), isNull);
    });
  });

  group('knee position', () {
    test('straight up to 10 degrees, bent from there to full flexion', () {
      for (var d = 0.0; d <= 180; d += 0.5) {
        expect(AttributeBoundaries.kneePosition(d), isNotNull, reason: '$d');
      }
      expect(AttributeBoundaries.kneePosition(0), 'straight');
      expect(AttributeBoundaries.kneePosition(10), 'straight');
      expect(AttributeBoundaries.kneePosition(10.5), 'bent');
      expect(
        AttributeBoundaries.kneePosition(45),
        'bent',
      ); // the old 10 to 90 gap
      expect(AttributeBoundaries.kneePosition(90), 'bent');
      expect(AttributeBoundaries.kneePosition(135), 'bent');
    });

    test('outside the joint range there is no value', () {
      expect(AttributeBoundaries.kneePosition(-1), isNull);
      expect(AttributeBoundaries.kneePosition(181), isNull);
      expect(AttributeBoundaries.kneePosition(double.nan), isNull);
    });
  });

  group('arm position', () {
    String? at(double d, ArmDirection dir, {bool supported = false}) =>
        AttributeBoundaries.armPosition(
          degreesFromTrunk: d,
          direction: dir,
          supportedInFront: supported,
        );

    test('every angle and direction maps to exactly one value', () {
      for (final dir in ArmDirection.values) {
        for (var d = 0.0; d <= 180; d += 0.5) {
          expect(at(d, dir), isNotNull, reason: '${dir.name} $d');
        }
      }
    });

    test('besideBody up to 20 degrees; the old 20 to 90 gap is closed', () {
      expect(at(0, ArmDirection.forward), 'besideBody');
      expect(at(20, ArmDirection.lateral), 'besideBody');
      expect(at(20.5, ArmDirection.forward), 'flexed90');
      expect(at(45, ArmDirection.forward), 'flexed90');
      expect(at(90, ArmDirection.forward), 'flexed90');
      expect(at(20.5, ArmDirection.lateral), 'abducted90');
      expect(at(90, ArmDirection.lateral), 'abducted90');
      expect(at(135, ArmDirection.forward), 'flexed90');
      expect(at(135.5, ArmDirection.forward), 'overhead');
      expect(at(170, ArmDirection.lateral), 'overhead');
    });

    test('behind the body and supported in front', () {
      expect(at(20, ArmDirection.behind), 'besideBody');
      expect(at(21, ArmDirection.behind), 'behindBody');
      expect(at(60, ArmDirection.behind), 'behindBody');
      expect(at(60, ArmDirection.forward, supported: true), 'supportedInFront');
      expect(at(0, ArmDirection.forward, supported: true), 'supportedInFront');
    });

    test('out of range has no value', () {
      expect(at(-1, ArmDirection.forward), isNull);
      expect(at(181, ArmDirection.forward), isNull);
      expect(at(double.nan, ArmDirection.forward), isNull);
    });
  });

  test('every classifier result is a value of its vocabulary', () {
    final angle = AttributeVocabulary.valuesOf(ExerciseAttribute.angle);
    final knee = AttributeVocabulary.valuesOf(ExerciseAttribute.kneePosition);
    final arm = AttributeVocabulary.valuesOf(ExerciseAttribute.armPosition);
    for (var d = -90.0; d <= 45; d += 1) {
      expect(angle, contains(AttributeBoundaries.angle(d)));
    }
    for (var d = 0.0; d <= 180; d += 1) {
      expect(knee, contains(AttributeBoundaries.kneePosition(d)));
      for (final dir in ArmDirection.values) {
        expect(
          arm,
          contains(
            AttributeBoundaries.armPosition(
              degreesFromTrunk: d,
              direction: dir,
            ),
          ),
        );
      }
    }
  });

  test('the boundary texts state the contiguous rules (X1)', () {
    String text(ExerciseAttribute a, String v) =>
        AttributeVocabulary.values[a]!.firstWhere((x) => x.value == v).boundary;
    expect(text(ExerciseAttribute.angle, 'incline'), contains('more than 10'));
    expect(text(ExerciseAttribute.angle, 'flat'), contains('10 degrees'));
    expect(
      text(ExerciseAttribute.kneePosition, 'bent'),
      contains('more than 10'),
    );
    expect(
      text(ExerciseAttribute.armPosition, 'flexed90'),
      contains('more than 20'),
    );
    expect(
      AttributeVocabulary.isValid(ExerciseAttribute.grip, 'mixed'),
      isTrue,
    );
    expect(
      AttributeVocabulary.isValid(ExerciseAttribute.grip, 'flat'),
      isFalse,
    );
  });
}
