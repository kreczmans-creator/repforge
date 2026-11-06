import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';

/// One band of a boundary table: an interval with inclusive or exclusive ends.
typedef Band = ({String name, double lo, bool loIncl, double hi, bool hiIncl});

/// X1 (closed 2026-11-06): the attribute boundary rules are contiguous, so
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

  test('X1 texts state the limits and the precedence of the classifiers', () {
    String text(ExerciseAttribute a, String v) =>
        AttributeVocabulary.values[a]!.firstWhere((x) => x.value == v).boundary;
    expect(text(ExerciseAttribute.angle, 'decline'), contains('up to 90'));
    expect(text(ExerciseAttribute.angle, 'incline'), contains('up to 45'));
    expect(
      text(ExerciseAttribute.armPosition, 'supportedInFront'),
      allOf(contains('0 to 180'), contains('precedence')),
    );
    expect(
      text(ExerciseAttribute.armPosition, 'behindBody'),
      allOf(contains('up to 180'), contains('precedence over overhead')),
    );
    expect(
      text(ExerciseAttribute.armPosition, 'overhead'),
      contains('more than 135 and up to 180'),
    );
    expect(
      text(ExerciseAttribute.armPosition, 'besideBody'),
      contains('0 to 20 degrees inclusive'),
    );
    for (final v in ['flexed90', 'abducted90']) {
      expect(
        text(ExerciseAttribute.armPosition, v),
        contains('more than 20 and up to 135'),
      );
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

  group('X1 boundary table: exactly one class per value (sweep)', () {
    // The table is written independently of the classifiers. Each band is
    // an interval with inclusive or exclusive ends; a value must lie in
    // exactly one band, and the classifier must return that band.
    bool inBand(Band b, double d) =>
        (b.loIncl ? d >= b.lo : d > b.lo) && (b.hiIncl ? d <= b.hi : d < b.hi);

    List<double> sweep(double from, double to, List<double> cuts) {
      final out = <double>{};
      for (var d = from; d <= to; d += 0.5) {
        out.add(d);
      }
      for (final c in cuts) {
        for (final e in [-1e-6, 0.0, 1e-6]) {
          final v = c + e;
          if (v >= from && v <= to) out.add(v);
        }
      }
      return out.toList()..sort();
    }

    void check(
      List<Band> bands,
      double from,
      double to,
      List<double> cuts,
      String? Function(double) classify,
    ) {
      for (final d in sweep(from, to, cuts)) {
        final hits = [
          for (final b in bands)
            if (inBand(b, d)) b.name,
        ];
        expect(hits, hasLength(1), reason: '$d lies in $hits');
        expect(classify(d), hits.single, reason: '$d degrees');
      }
    }

    test('angle: decline [-90, -10), flat [-10, 10], incline (10, 45]', () {
      const bands = <Band>[
        (name: 'decline', lo: -90, loIncl: true, hi: -10, hiIncl: false),
        (name: 'flat', lo: -10, loIncl: true, hi: 10, hiIncl: true),
        (name: 'incline', lo: 10, loIncl: false, hi: 45, hiIncl: true),
      ];
      check(bands, -90, 45, [-90, -10, 10, 45], AttributeBoundaries.angle);
      // Outside the range there is no class.
      expect(AttributeBoundaries.angle(-90.000001), isNull);
      expect(AttributeBoundaries.angle(45.000001), isNull);
    });

    test('angle: a bench tilted 5 degrees head-down is flat (owner)', () {
      expect(AttributeBoundaries.angle(-5), 'flat');
      expect(AttributeBoundaries.angle(-9.999999), 'flat');
      expect(AttributeBoundaries.angle(-10.000001), 'decline');
    });

    test('knee: straight [0, 10], bent (10, 180]', () {
      const bands = <Band>[
        (name: 'straight', lo: 0, loIncl: true, hi: 10, hiIncl: true),
        (name: 'bent', lo: 10, loIncl: false, hi: 180, hiIncl: true),
      ];
      check(bands, 0, 180, [0, 10, 180], AttributeBoundaries.kneePosition);
      expect(AttributeBoundaries.kneePosition(-0.000001), isNull);
      expect(AttributeBoundaries.kneePosition(180.000001), isNull);
    });

    test('arm, forward: besideBody [0, 20], flexed90 (20, 135], '
        'overhead (135, 180]', () {
      const bands = <Band>[
        (name: 'besideBody', lo: 0, loIncl: true, hi: 20, hiIncl: true),
        (name: 'flexed90', lo: 20, loIncl: false, hi: 135, hiIncl: true),
        (name: 'overhead', lo: 135, loIncl: false, hi: 180, hiIncl: true),
      ];
      check(
        bands,
        0,
        180,
        [0, 20, 135, 180],
        (d) => AttributeBoundaries.armPosition(
          degreesFromTrunk: d,
          direction: ArmDirection.forward,
        ),
      );
    });

    test('arm, lateral: besideBody [0, 20], abducted90 (20, 135], '
        'overhead (135, 180]', () {
      const bands = <Band>[
        (name: 'besideBody', lo: 0, loIncl: true, hi: 20, hiIncl: true),
        (name: 'abducted90', lo: 20, loIncl: false, hi: 135, hiIncl: true),
        (name: 'overhead', lo: 135, loIncl: false, hi: 180, hiIncl: true),
      ];
      check(
        bands,
        0,
        180,
        [0, 20, 135, 180],
        (d) => AttributeBoundaries.armPosition(
          degreesFromTrunk: d,
          direction: ArmDirection.lateral,
        ),
      );
    });

    test('arm, behind: besideBody [0, 20], behindBody (20, 180]', () {
      const bands = <Band>[
        (name: 'besideBody', lo: 0, loIncl: true, hi: 20, hiIncl: true),
        (name: 'behindBody', lo: 20, loIncl: false, hi: 180, hiIncl: true),
      ];
      check(
        bands,
        0,
        180,
        [0, 20, 135, 180],
        (d) => AttributeBoundaries.armPosition(
          degreesFromTrunk: d,
          direction: ArmDirection.behind,
        ),
      );
    });

    test('arm, supported in front wins over every angle and direction', () {
      for (final dir in ArmDirection.values) {
        for (var d = 0.0; d <= 180; d += 0.5) {
          expect(
            AttributeBoundaries.armPosition(
              degreesFromTrunk: d,
              direction: dir,
              supportedInFront: true,
            ),
            'supportedInFront',
            reason: '${dir.name} $d',
          );
        }
      }
    });

    test('every class returned is a value of its vocabulary', () {
      final angle = AttributeVocabulary.valuesOf(ExerciseAttribute.angle);
      final knee = AttributeVocabulary.valuesOf(ExerciseAttribute.kneePosition);
      for (var d = -90.0; d <= 45; d += 0.5) {
        expect(angle, contains(AttributeBoundaries.angle(d)));
      }
      for (var d = 0.0; d <= 180; d += 0.5) {
        expect(knee, contains(AttributeBoundaries.kneePosition(d)));
      }
    });
  });
}
