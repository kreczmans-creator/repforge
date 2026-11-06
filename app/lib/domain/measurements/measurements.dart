import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';

part 'measurements.freezed.dart';

/// Body sites (BCM-001..003). Left and right are separate sites by design.
enum MeasurementSite {
  weight('Weight', 'kg'),
  neck('Neck', 'cm'),
  chest('Chest', 'cm'),
  waist('Waist', 'cm'),
  hips('Hips', 'cm'),
  thighLeft('Left thigh', 'cm'),
  thighRight('Right thigh', 'cm'),
  calfLeft('Left calf', 'cm'),
  calfRight('Right calf', 'cm'),
  bicepsLeft('Left biceps', 'cm'),
  bicepsRight('Right biceps', 'cm'),
  forearmLeft('Left forearm', 'cm'),
  forearmRight('Right forearm', 'cm');

  MeasurementSite(this.label, this.unit);
  final String label;
  final String unit;

  bool get isWeight => this == MeasurementSite.weight;
}

/// Validated measurement value: [Kilograms] for weight, [Centimetres]
/// otherwise.
@freezed
sealed class MeasurementValue with _$MeasurementValue {
  const factory MeasurementValue.kg(Kilograms kg) = WeightValue;
  const factory MeasurementValue.cm(Centimetres cm) = LengthValue;

  const MeasurementValue._();

  double get raw => switch (this) {
    WeightValue(:final kg) => kg.value,
    LengthValue(:final cm) => cm.value,
  };

  String get label => switch (this) {
    WeightValue(:final kg) => kg.label,
    LengthValue(:final cm) => cm.label,
  };
}

/// One dated measurement of one site (BCM-004).
@freezed
abstract class Measurement with _$Measurement {
  const factory Measurement({
    required String id,
    required MeasurementSite site,
    required MeasurementValue value,
    required DateTime recordedAt,
    required DateTime createdAt,
    required DateTime updatedAt,
    String? note,
  }) = _Measurement;
}
