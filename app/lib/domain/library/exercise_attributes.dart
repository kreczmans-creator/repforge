import 'package:meta/meta.dart';

/// The seven optional controlled exercise attributes (approved 2026-11-05,
/// `coverage-matrix.md` section 3). They are single-valued, never required,
/// and used by coverage slots and the duplicate checks only.
enum ExerciseAttribute {
  angle,
  armPosition,
  bodyPosition,
  grip,
  gripWidth,
  kneePosition,
  stance,
}

/// A value of an attribute with its boundary rule.
@immutable
final class AttributeValue {
  const AttributeValue(this.value, this.boundary);

  final String value;

  /// Boundary rule that lets two editors tag the same movement the same way.
  final String boundary;
}

/// Direction of the working upper arm, for [AttributeBoundaries.armPosition].
enum ArmDirection { forward, lateral, behind }

/// Vocabulary and boundary rules of the seven attributes.
///
/// The value names equal the approved `coverage.json` vocabulary (a test
/// compares them), and so do the boundary texts. **X1 (closed 2026-11-06,
/// owner sign-off):** the earlier texts left gaps (angle 10 to 15 degrees,
/// arm 20 to 90 degrees, knee 10 to 90 degrees). The texts below match the
/// classifiers in [AttributeBoundaries] exactly: every measurement maps to
/// exactly one value, and where two arm texts could both fit, a precedence
/// sentence says which value wins (`supportedInFront` over all other arm values, `behindBody`
/// over `overhead`). The cut points (bench 10 degrees, arm 20 and 135 degrees,
/// knee 10 degrees) are approved by the owner (2026-11-06). A
/// measurement outside an attribute's range has no value; that is derived,
/// not a text.
abstract final class AttributeVocabulary {
  static const Map<ExerciseAttribute, List<AttributeValue>> values = {
    ExerciseAttribute.angle: [
      AttributeValue(
        'flat',
        'Bench or body from 10 degrees head-down to 10 degrees head-up '
            'inclusive.',
      ),
      AttributeValue(
        'incline',
        'Bench raised more than 10 and up to 45 degrees (steeper is a '
            'vertical push, rule R2).',
      ),
      AttributeValue(
        'decline',
        'Bench lowered with the head more than 10 and up to 90 degrees below '
            'the hips.',
      ),
    ],
    ExerciseAttribute.armPosition: [
      AttributeValue(
        'besideBody',
        'Upper arm hangs by the side, from 0 to 20 degrees inclusive from the '
            'trunk line, in any direction.',
      ),
      AttributeValue(
        'behindBody',
        'Elbow behind the trunk line by more than 20 and up to 180 degrees '
            '(for example an incline curl). Takes precedence over overhead.',
      ),
      AttributeValue(
        'supportedInFront',
        'Upper arm rests on a pad, bench or thigh in front of the trunk, at '
            'any angle from 0 to 180 degrees from the trunk line. Takes '
            'precedence over every other arm value.',
      ),
      AttributeValue(
        'overhead',
        'Upper arm raised forward or to the side more than 135 and up to 180 '
            'degrees from the trunk line (typically with the elbow at or above '
            'ear height). Not used for an arm behind the trunk.',
      ),
      AttributeValue(
        'flexed90',
        'Upper arm raised forward more than 20 and up to 135 degrees from the '
            'trunk line (typically about 90 degrees).',
      ),
      AttributeValue(
        'abducted90',
        'Upper arm raised to the side more than 20 and up to 135 degrees from '
            'the trunk line (typically 90/90 with the elbow bent).',
      ),
    ],
    ExerciseAttribute.bodyPosition: [
      AttributeValue('standing', 'Upright on the feet.'),
      AttributeValue('seated', 'Sitting, back supported or not.'),
      AttributeValue(
        'lying',
        'On the back or side, supported along the length of the trunk.',
      ),
      AttributeValue(
        'prone',
        'Face down, trunk supported on a bench or the floor.',
      ),
      AttributeValue(
        'bentOver',
        'Standing with the hips hinged forward and the trunk unsupported.',
      ),
      AttributeValue('kneeling', 'On both knees or on all fours.'),
      AttributeValue('halfKneeling', 'One knee down, one foot forward.'),
      AttributeValue(
        'inclined',
        'Back or chest supported on an inclined surface, or the upper back on '
            'a bench with the hips free (hip thrust).',
      ),
    ],
    ExerciseAttribute.grip: [
      AttributeValue('pronated', 'Palms facing down or away.'),
      AttributeValue('supinated', 'Palms facing up or towards the face.'),
      AttributeValue('neutral', 'Palms facing each other.'),
      AttributeValue('mixed', 'One hand pronated, one supinated.'),
    ],
    ExerciseAttribute.gripWidth: [
      AttributeValue('close', 'Hands inside shoulder width.'),
      AttributeValue('standard', 'Hands about shoulder width.'),
      AttributeValue(
        'wide',
        'Hands outside shoulder width by more than a hand width.',
      ),
    ],
    ExerciseAttribute.kneePosition: [
      AttributeValue(
        'straight',
        'Knee from fully straight (0 degrees) to 10 degrees of flexion '
            'inclusive.',
      ),
      AttributeValue(
        'bent',
        'Knee bent more than 10 and up to 180 degrees of flexion (typically '
            'about 90).',
      ),
    ],
    ExerciseAttribute.stance: [
      AttributeValue('narrow', 'Feet inside hip width.'),
      AttributeValue('standard', 'Feet hip to shoulder width.'),
      AttributeValue('wide', 'Feet outside shoulder width.'),
      AttributeValue('split', 'One foot ahead of the other.'),
    ],
  };

  /// The allowed values of [attribute].
  static List<String> valuesOf(ExerciseAttribute attribute) => [
    for (final v in values[attribute]!) v.value,
  ];

  static bool isValid(ExerciseAttribute attribute, String value) =>
      valuesOf(attribute).contains(value);
}

/// Numeric classifiers that implement the contiguous boundary rules (X1).
///
/// Each function returns the single value whose rule contains the measurement,
/// or null when the measurement is outside the attribute's range. Boundaries
/// are inclusive on the lower side of the next value as stated in the texts of
/// [AttributeVocabulary].
abstract final class AttributeBoundaries {
  /// Angle of the bench or the body to the horizontal in degrees; positive
  /// when the head is above the hips. Steeper than 45 degrees is a vertical
  /// push (rule R2) and has no `angle` value.
  static String? angle(double degrees) {
    if (degrees.isNaN) return null;
    if (degrees < -10) return degrees >= -90 ? 'decline' : null;
    if (degrees <= 10) return 'flat';
    if (degrees <= 45) return 'incline';
    return null;
  }

  /// Knee flexion in degrees, 0 for fully straight, up to 180.
  static String? kneePosition(double flexionDegrees) {
    if (flexionDegrees.isNaN || flexionDegrees < 0 || flexionDegrees > 180) {
      return null;
    }
    return flexionDegrees <= 10 ? 'straight' : 'bent';
  }

  /// Position of the working upper arm. [degreesFromTrunk] is the angle
  /// between the upper arm and the trunk line, 0 hanging by the side and 180
  /// vertical overhead; [direction] is where the arm travels from the side;
  /// [supportedInFront] is true when the arm rests on a pad, bench or thigh.
  static String? armPosition({
    required double degreesFromTrunk,
    required ArmDirection direction,
    bool supportedInFront = false,
  }) {
    if (degreesFromTrunk.isNaN ||
        degreesFromTrunk < 0 ||
        degreesFromTrunk > 180) {
      return null;
    }
    if (supportedInFront) return 'supportedInFront';
    if (degreesFromTrunk <= 20) return 'besideBody';
    if (direction == ArmDirection.behind) return 'behindBody';
    if (degreesFromTrunk > 135) return 'overhead';
    return direction == ArmDirection.forward ? 'flexed90' : 'abducted90';
  }
}
