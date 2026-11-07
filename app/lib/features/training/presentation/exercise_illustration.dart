import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:repforge/ui/tokens.dart';

/// Original RepForge instructional illustrations (WP 8 exercise knowledge
/// system). Each is a side-view line figure drawn by the app from vector data
/// in this file: no image file, no dependency, no network, so it works
/// offline and follows the light and dark themes.
///
/// Provenance: authored for RepForge on 2026-11-07 from body proportions and
/// joint angles (segment lengths below are fixed, so every pose keeps the same
/// body); not traced or derived from any photograph, video or third-party
/// drawing. The release file references them as
/// `repforge-illustration:<key>` media with source `original`.

/// Segment lengths in figure units (about 2 cm each for a 1.8 m person).
abstract final class FigureProportions {
  static const double thigh = 22;
  static const double shin = 21;
  static const double foot = 8;
  static const double torso = 26;
  static const double neck = 6;
  static const double headRadius = 5.5;
  static const double upperArm = 15;
  static const double forearm = 14;
}

/// Angles of one limb in degrees (0 = forward, 90 = up), each measured at the
/// joint nearer the trunk: hip to knee, knee to ankle, ankle to toe; or
/// shoulder to elbow, elbow to wrist.
@immutable
class LimbAngles {
  const LimbAngles(this.upper, this.lower, [this.end = 0]);
  final double upper;
  final double lower;
  final double end;
}

/// Equipment drawn with a figure.
@immutable
class IllustrationProp {
  const IllustrationProp.plate(this.a, this.radius)
    : kind = IllustrationPropKind.plate,
      b = Offset.zero;
  const IllustrationProp.bar(this.a, this.b)
    : kind = IllustrationPropKind.bar,
      radius = 0;
  const IllustrationProp.fixedBar(this.a, this.b)
    : kind = IllustrationPropKind.fixedBar,
      radius = 0;

  final IllustrationPropKind kind;
  final Offset a;
  final Offset b;
  final double radius;
}

enum IllustrationPropKind { plate, bar, fixedBar }

/// A pose: hip position (figure units, y up from the floor) and joint angles.
@immutable
class FigurePose {
  const FigurePose({
    required this.hip,
    required this.torso,
    required this.head,
    required this.nearLeg,
    required this.farLeg,
    required this.nearArm,
    required this.farArm,
    required this.floor,
    this.props = const [],
  });

  final Offset hip;
  final double torso;
  final double head;
  final LimbAngles nearLeg;
  final LimbAngles farLeg;
  final LimbAngles nearArm;
  final LimbAngles farArm;

  /// Whether the pose stands on the floor (the floor line is drawn at y 0).
  final bool floor;
  final List<IllustrationProp> props;

  /// Joint positions in figure units (y up).
  FigureJoints get joints => FigureJoints.of(this);
}

/// Joint positions computed from a pose by forward kinematics.
@immutable
class FigureJoints {
  const FigureJoints._(this.points);

  factory FigureJoints.of(FigurePose p) {
    Offset step(Offset from, double length, double degrees) {
      final r = degrees * math.pi / 180;
      return from + Offset(length * math.cos(r), length * math.sin(r));
    }

    final pts = <String, Offset>{'hip': p.hip};
    for (final (side, leg) in [('near', p.nearLeg), ('far', p.farLeg)]) {
      final knee = step(p.hip, FigureProportions.thigh, leg.upper);
      final ankle = step(knee, FigureProportions.shin, leg.lower);
      pts['${side}Knee'] = knee;
      pts['${side}Ankle'] = ankle;
      pts['${side}Toe'] = step(ankle, FigureProportions.foot, leg.end);
    }
    final shoulder = step(p.hip, FigureProportions.torso, p.torso);
    pts['shoulder'] = shoulder;
    pts['head'] = step(
      shoulder,
      FigureProportions.neck + FigureProportions.headRadius,
      p.head,
    );
    for (final (side, arm) in [('near', p.nearArm), ('far', p.farArm)]) {
      final elbow = step(shoulder, FigureProportions.upperArm, arm.upper);
      pts['${side}Elbow'] = elbow;
      pts['${side}Wrist'] = step(elbow, FigureProportions.forearm, arm.lower);
    }
    return FigureJoints._(Map.unmodifiable(pts));
  }

  final Map<String, Offset> points;

  Offset operator [](String name) => points[name]!;
}

/// The built-in illustration library, keyed by the locator key
/// (`repforge-illustration:<key>`).
const Map<String, FigurePose> exerciseIllustrations = {
  'back-squat/finish': FigurePose(
    hip: Offset(37.56, 22.86),
    torso: 52,
    head: 52,
    nearLeg: LimbAngles(357, 243),
    farLeg: LimbAngles(357, 243),
    nearArm: LimbAngles(237.62, 77.49),
    farArm: LimbAngles(237.62, 77.49),
    floor: true,
    props: [
      IllustrationProp.plate(Offset(51.07, 44.35), 10.7),
      IllustrationProp.bar(Offset(48.07, 44.35), Offset(54.07, 44.35)),
    ],
  ),
  'back-squat/start': FigurePose(
    hip: Offset(49.97, 45.97),
    torso: 90,
    head: 90,
    nearLeg: LimbAngles(272, 268),
    farLeg: LimbAngles(272, 268),
    nearArm: LimbAngles(237.62, 77.49),
    farArm: LimbAngles(237.62, 77.49),
    floor: true,
    props: [
      IllustrationProp.plate(Offset(47.47, 72.97), 10.7),
      IllustrationProp.bar(Offset(44.47, 72.97), Offset(50.47, 72.97)),
    ],
  ),
  'bodyweight-lunge/finish': FigurePose(
    hip: Offset(48.76, 25.14),
    torso: 88,
    head: 88,
    nearLeg: LimbAngles(357, 268),
    farLeg: LimbAngles(245.4, 183, 334),
    nearArm: LimbAngles(265, 270),
    farArm: LimbAngles(265, 270),
    floor: true,
  ),
  'bodyweight-lunge/start': FigurePose(
    hip: Offset(51.97, 45.97),
    torso: 90,
    head: 90,
    nearLeg: LimbAngles(272, 268),
    farLeg: LimbAngles(272, 268),
    nearArm: LimbAngles(265, 270),
    farArm: LimbAngles(265, 270),
    floor: true,
  ),
  'bodyweight-squat/finish': FigurePose(
    hip: Offset(37.62, 23.63),
    torso: 57,
    head: 57,
    nearLeg: LimbAngles(355, 243),
    farLeg: LimbAngles(355, 243),
    nearArm: LimbAngles(5, 5),
    farArm: LimbAngles(5, 5),
    floor: true,
  ),
  'bodyweight-squat/start': FigurePose(
    hip: Offset(49.97, 45.97),
    torso: 90,
    head: 90,
    nearLeg: LimbAngles(272, 268),
    farLeg: LimbAngles(272, 268),
    nearArm: LimbAngles(0, 0),
    farArm: LimbAngles(0, 0),
    floor: true,
  ),
  'dead-hang/start': FigurePose(
    hip: Offset(55, 31.08),
    torso: 90,
    head: 90,
    nearLeg: LimbAngles(273, 268, 330),
    farLeg: LimbAngles(273, 268, 330),
    nearArm: LimbAngles(84, 89),
    farArm: LimbAngles(84, 89),
    floor: false,
    props: [IllustrationProp.fixedBar(Offset(38.81, 86), Offset(74.81, 86))],
  ),
  'deadlift/finish': FigurePose(
    hip: Offset(47.97, 45.97),
    torso: 90,
    head: 90,
    nearLeg: LimbAngles(272, 268),
    farLeg: LimbAngles(272, 268),
    nearArm: LimbAngles(275, 272),
    farArm: LimbAngles(275, 272),
    floor: true,
    props: [IllustrationProp.plate(Offset(49.77, 43.04), 10.7)],
  ),
  'deadlift/start': FigurePose(
    hip: Offset(32.5, 30.05),
    torso: 23.2,
    head: 23.2,
    nearLeg: LimbAngles(342.1, 255),
    farLeg: LimbAngles(342.1, 255),
    nearArm: LimbAngles(263.3, 263.3),
    farArm: LimbAngles(263.3, 263.3),
    floor: true,
    props: [IllustrationProp.plate(Offset(53.01, 11.49), 10.7)],
  ),
  'glute-bridge/finish': FigurePose(
    hip: Offset(48, 15.39),
    torso: 201.64,
    head: 180,
    nearLeg: LimbAngles(22.91, 273.8),
    farLeg: LimbAngles(22.91, 273.8),
    nearArm: LimbAngles(340, 0),
    farArm: LimbAngles(340, 0),
    floor: true,
  ),
  'glute-bridge/start': FigurePose(
    hip: Offset(48, 5.13),
    torso: 178,
    head: 180,
    nearLeg: LimbAngles(52, 292),
    farLeg: LimbAngles(52, 292),
    nearArm: LimbAngles(352, 0),
    farArm: LimbAngles(352, 0),
    floor: true,
  ),
  'plank/start': FigurePose(
    hip: Offset(52.19, 13.88),
    torso: 6.9,
    head: 6.9,
    nearLeg: LimbAngles(186.9, 186.9, 285),
    farLeg: LimbAngles(186.9, 186.9, 285),
    nearArm: LimbAngles(270, 0),
    farArm: LimbAngles(270, 0),
    floor: true,
  ),
  'pull-up/finish': FigurePose(
    hip: Offset(58.17, 54.69),
    torso: 97,
    head: 92,
    nearLeg: LimbAngles(273, 268, 330),
    farLeg: LimbAngles(273, 268, 330),
    nearArm: LimbAngles(332.09, 116.54),
    farArm: LimbAngles(332.09, 116.54),
    floor: false,
    props: [IllustrationProp.fixedBar(Offset(44, 86), Offset(80, 86))],
  ),
  'pull-up/start': FigurePose(
    hip: Offset(55, 31.08),
    torso: 90,
    head: 90,
    nearLeg: LimbAngles(273, 268, 330),
    farLeg: LimbAngles(273, 268, 330),
    nearArm: LimbAngles(84, 89),
    farArm: LimbAngles(84, 89),
    floor: false,
    props: [IllustrationProp.fixedBar(Offset(38.81, 86), Offset(74.81, 86))],
  ),
  'push-up/finish': FigurePose(
    hip: Offset(55.11, 11.63),
    torso: 5.24,
    head: 5.24,
    nearLeg: LimbAngles(185.24, 185.24, 285),
    farLeg: LimbAngles(185.24, 185.24, 285),
    nearArm: LimbAngles(194.83, 321.79),
    farArm: LimbAngles(194.83, 321.79),
    floor: true,
  ),
  'push-up/start': FigurePose(
    hip: Offset(53.2, 22.68),
    torso: 17.5,
    head: 17.5,
    nearLeg: LimbAngles(197.5, 197.5, 285),
    farLeg: LimbAngles(197.5, 197.5, 285),
    nearArm: LimbAngles(270, 270),
    farArm: LimbAngles(270, 270),
    floor: true,
  ),
  'romanian-deadlift/finish': FigurePose(
    hip: Offset(33.42, 42.45),
    torso: 12,
    head: 12,
    nearLeg: LimbAngles(302, 278),
    farLeg: LimbAngles(302, 278),
    nearArm: LimbAngles(256, 256),
    farArm: LimbAngles(256, 256),
    floor: true,
    props: [IllustrationProp.plate(Offset(51.84, 19.72), 10.7)],
  ),
  'romanian-deadlift/start': FigurePose(
    hip: Offset(47.55, 45.87),
    torso: 90,
    head: 90,
    nearLeg: LimbAngles(275, 266),
    farLeg: LimbAngles(275, 266),
    nearArm: LimbAngles(276, 272),
    farArm: LimbAngles(276, 272),
    floor: true,
    props: [IllustrationProp.plate(Offset(49.61, 42.96), 10.7)],
  ),
};

/// Offset of the far-side limbs, drawn muted behind the near side.
const Offset _farOffset = Offset(-1.6, 0.6);

/// Paints one pose, scaled to fit with a margin, in theme colours.
class FigurePainter extends CustomPainter {
  FigurePainter({
    required this.pose,
    required this.ink,
    required this.muted,
    required this.accent,
    required this.line,
  });

  final FigurePose pose;
  final Color ink;
  final Color muted;
  final Color accent;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    final j = pose.joints;
    final farPoints = [
      for (final k in ['farKnee', 'farAnkle', 'farToe', 'farElbow', 'farWrist'])
        j[k] + _farOffset,
    ];
    final all = <Offset>[...j.points.values, ...farPoints];
    var minX = all.map((p) => p.dx).reduce(math.min);
    var maxX = all.map((p) => p.dx).reduce(math.max);
    var minY = all.map((p) => p.dy).reduce(math.min);
    var maxY = all.map((p) => p.dy).reduce(math.max);
    // Head extent and props.
    final head = j['head'];
    const r = FigureProportions.headRadius;
    minX = math.min(minX, head.dx - r);
    maxX = math.max(maxX, head.dx + r);
    maxY = math.max(maxY, head.dy + r);
    minY = math.min(minY, head.dy - r);
    for (final p in pose.props) {
      final ends = p.kind == IllustrationPropKind.plate
          ? [p.a - Offset(p.radius, p.radius), p.a + Offset(p.radius, p.radius)]
          : [p.a, p.b];
      for (final e in ends) {
        minX = math.min(minX, e.dx);
        maxX = math.max(maxX, e.dx);
        minY = math.min(minY, e.dy);
        maxY = math.max(maxY, e.dy);
      }
    }
    if (pose.floor) minY = math.min(minY, 0);
    const margin = 6.0;
    minX -= margin;
    maxX += margin;
    minY -= margin / 2;
    maxY += margin / 2;
    final scale = math.min(
      size.width / (maxX - minX),
      size.height / (maxY - minY),
    );
    final dx = (size.width - (maxX - minX) * scale) / 2;
    final dy = (size.height - (maxY - minY) * scale) / 2;
    Offset map(Offset p) => Offset(
      dx + (p.dx - minX) * scale,
      size.height - dy - (p.dy - minY) * scale,
    );

    final stroke = 3.2 * scale;
    Paint pen(Color c, double w) => Paint()
      ..color = c
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (pose.floor) {
      canvas.drawLine(
        map(Offset(minX + margin / 2, 0)),
        map(Offset(maxX - margin / 2, 0)),
        pen(line, 1.2 * scale),
      );
    }
    for (final p in pose.props) {
      switch (p.kind) {
        case IllustrationPropKind.plate:
          canvas
            ..drawCircle(
              map(p.a),
              p.radius * scale,
              Paint()..color = accent.withValues(alpha: 0.16),
            )
            ..drawCircle(map(p.a), p.radius * scale, pen(accent, 1.4 * scale))
            ..drawCircle(map(p.a), 1.4 * scale, Paint()..color = accent);
        case IllustrationPropKind.bar:
          canvas.drawLine(map(p.a), map(p.b), pen(accent, 1.8 * scale));
        case IllustrationPropKind.fixedBar:
          canvas.drawLine(map(p.a), map(p.b), pen(line, 2 * scale));
      }
    }
    // Far limbs first, muted, then the trunk, head and near limbs.
    final far = pen(muted, stroke);
    canvas
      ..drawPath(
        Path()
          ..moveTo(map(j['hip']).dx, map(j['hip']).dy)
          ..lineTo(map(farPoints[0]).dx, map(farPoints[0]).dy)
          ..lineTo(map(farPoints[1]).dx, map(farPoints[1]).dy)
          ..lineTo(map(farPoints[2]).dx, map(farPoints[2]).dy),
        far,
      )
      ..drawPath(
        Path()
          ..moveTo(map(j['shoulder']).dx, map(j['shoulder']).dy)
          ..lineTo(map(farPoints[3]).dx, map(farPoints[3]).dy)
          ..lineTo(map(farPoints[4]).dx, map(farPoints[4]).dy),
        far,
      );
    final near = pen(ink, stroke);
    canvas
      ..drawLine(map(j['hip']), map(j['shoulder']), pen(ink, stroke * 1.35))
      ..drawCircle(map(head), r * scale, pen(ink, stroke * 0.7))
      ..drawPath(
        Path()
          ..moveTo(map(j['hip']).dx, map(j['hip']).dy)
          ..lineTo(map(j['nearKnee']).dx, map(j['nearKnee']).dy)
          ..lineTo(map(j['nearAnkle']).dx, map(j['nearAnkle']).dy)
          ..lineTo(map(j['nearToe']).dx, map(j['nearToe']).dy),
        near,
      )
      ..drawPath(
        Path()
          ..moveTo(map(j['shoulder']).dx, map(j['shoulder']).dy)
          ..lineTo(map(j['nearElbow']).dx, map(j['nearElbow']).dy)
          ..lineTo(map(j['nearWrist']).dx, map(j['nearWrist']).dy),
        near,
      );
  }

  @override
  bool shouldRepaint(FigurePainter old) =>
      old.pose != pose ||
      old.ink != ink ||
      old.muted != muted ||
      old.accent != accent ||
      old.line != line;
}

/// An original RepForge illustration of [pose], in theme colours.
class ExerciseIllustration extends StatelessWidget {
  const ExerciseIllustration({
    required this.pose,
    required this.semanticLabel,
    super.key,
  });

  final FigurePose pose;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final rf = context.rf;
    return Semantics(
      image: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: CustomPaint(
          painter: FigurePainter(
            pose: pose,
            ink: Theme.of(context).colorScheme.onSurface,
            muted: rf.textMuted,
            accent: rf.accent,
            line: rf.borderStrong,
          ),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}
