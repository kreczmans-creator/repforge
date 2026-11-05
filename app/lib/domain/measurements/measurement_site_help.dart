import 'package:repforge/domain/measurements/measurements.dart';

/// Help text for a measurement site (BCM-002 note): where on the body to
/// measure. Original, neutral wording; not medical advice.
extension MeasurementSiteHelp on MeasurementSite {
  /// Where and how to take this measurement.
  String get helpText => switch (this) {
    MeasurementSite.weight =>
      'Body weight in kilograms. Weighing at a similar time of day, for '
          'example in the morning, makes readings easier to compare.',
    MeasurementSite.neck =>
      'Around the middle of the neck, just below the larynx, with the tape '
          'level and the head looking straight ahead.',
    MeasurementSite.chest =>
      'Around the fullest part of the chest at nipple height, with the '
          'tape level across the back and arms relaxed at your sides.',
    MeasurementSite.waist =>
      'Around the natural waist at the level of the navel, after a normal '
          'breath out, without pulling the tape tight.',
    MeasurementSite.hips =>
      'Around the widest part of the hips and buttocks, with feet together '
          'and the tape level all the way round.',
    MeasurementSite.thighLeft || MeasurementSite.thighRight =>
      'Around the thickest part of the upper thigh, standing with weight '
          'evenly on both feet.$_sideNote',
    MeasurementSite.calfLeft || MeasurementSite.calfRight =>
      'Around the widest part of the lower leg, standing with weight evenly '
          'on both feet.$_sideNote',
    MeasurementSite.bicepsLeft || MeasurementSite.bicepsRight =>
      'Around the middle of the upper arm, halfway between shoulder and '
          'elbow, with the arm relaxed at your side.$_sideNote',
    MeasurementSite.forearmLeft || MeasurementSite.forearmRight =>
      'Around the widest part of the forearm, just below the elbow, with '
          'the arm relaxed.$_sideNote',
  };

  /// True for the eight limb sites that exist as a left and a right value.
  bool get isBilateral => counterpart != null;

  /// The opposite side of a left/right site; null for the other sites.
  MeasurementSite? get counterpart => switch (this) {
    MeasurementSite.thighLeft => MeasurementSite.thighRight,
    MeasurementSite.thighRight => MeasurementSite.thighLeft,
    MeasurementSite.calfLeft => MeasurementSite.calfRight,
    MeasurementSite.calfRight => MeasurementSite.calfLeft,
    MeasurementSite.bicepsLeft => MeasurementSite.bicepsRight,
    MeasurementSite.bicepsRight => MeasurementSite.bicepsLeft,
    MeasurementSite.forearmLeft => MeasurementSite.forearmRight,
    MeasurementSite.forearmRight => MeasurementSite.forearmLeft,
    _ => null,
  };
}

/// Left/right note: each side is stored on its own.
const _sideNote = ' Measure the same side consistently.';
