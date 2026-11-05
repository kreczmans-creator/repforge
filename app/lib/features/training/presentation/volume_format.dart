import 'package:repforge/domain/training/training_validation.dart';
import 'package:repforge/domain/training/volume.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/training/presentation/set_format.dart';

/// Volume as text by measure (TRN-027): kg for weighted working and failure
/// sets, repetitions, seconds and metres for the other types; never one
/// mixed number. `none yet` when nothing counts.
String formatVolume(VolumeTotals v) {
  final parts = <String>[
    if (v.loadKg > 0) '${formatNumber(v.loadKg)} kg',
    if (v.reps > 0) '${v.reps} reps',
    if (v.seconds > 0) formatClock(Duration(seconds: v.seconds)),
    if (v.metres > 0) formatDistance(v.metres),
  ];
  return parts.isEmpty ? 'none yet' : parts.join(' · ');
}
