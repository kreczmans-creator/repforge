import 'package:repforge/domain/nutrition/nutrition.dart' show DataProvenance;
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_validation.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/domain/units/units.dart';

/// A load in the user's unit system (storage stays kg): `80 kg`, `176.4 lb`.
String formatLoad(LoadKg load, UnitSystem units) => switch (units) {
  UnitSystem.metric => '${formatNumber(load.value, maxDecimals: 2)} kg',
  UnitSystem.imperial =>
    '${formatNumber(UnitConversion.kgToLb(load.value))} lb',
};

/// `1:30`, `30:00`, `1:05:00`.
String formatClock(Duration d) {
  final total = d.inSeconds;
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = total % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}';
}

String _reps(int reps) => reps == 1 ? '1 rep' : '$reps reps';

/// One recorded set as text, per exercise type (TRN-001..007). An assisted
/// set shows its assistance as assistance, never as a lifted load
/// (TRN-004(2)); distance switches to km from 1000 m (TRN-006(2)); cardio
/// energy is labelled user-entered or estimated (TRN-007(2)).
String formatSetData(SetData data, UnitSystem units) => switch (data) {
  WeightedSet(:final load, :final reps) => '${formatLoad(load, units)} × $reps',
  BodyweightSet(:final reps, :final addedLoad) =>
    addedLoad == null || addedLoad.value == 0
        ? _reps(reps)
        : '${_reps(reps)} + ${formatLoad(addedLoad, units)}',
  AssistedSet(:final reps, :final assistance) =>
    '${_reps(reps)}, ${formatLoad(assistance, units)} assistance',
  TimedSet(:final duration, :final addedLoad) =>
    addedLoad == null || addedLoad.value == 0
        ? formatClock(duration)
        : '${formatClock(duration)} + ${formatLoad(addedLoad, units)}',
  DistanceSet(:final metres, :final duration) =>
    duration == null
        ? formatDistance(metres)
        : '${formatDistance(metres)} in ${formatClock(duration)}',
  CardioSet(
    :final duration,
    :final metres,
    :final averageHeartRate,
    :final energyKcal,
    :final energyProvenance,
  ) =>
    [
      formatClock(duration),
      if (metres != null) formatDistance(metres),
      if (averageHeartRate != null) 'avg HR $averageHeartRate bpm',
      if (energyKcal != null) _energy(energyKcal, energyProvenance),
    ].join(', '),
};

/// TRN-007(2): energy is always labelled with where the number came from.
String _energy(double kcal, DataProvenance? p) {
  final label = p == DataProvenance.estimated ? 'estimated' : 'user-entered';
  return '${formatNumber(kcal, maxDecimals: 0)} kcal ($label)';
}

/// `RPE 8` or `RIR 2`.
String formatExertion(Exertion e) =>
    '${e.scale == ExertionScale.rpe ? 'RPE' : 'RIR'} ${formatNumber(e.value)}';
