import 'package:repforge/domain/analytics/training_analytics.dart';
import 'package:repforge/domain/training/personal_records.dart';
import 'package:repforge/domain/units/format.dart';

/// A record event as a descriptive line: "Heaviest at 5 reps: 100 kg".
String recordText(RecordEvent r) {
  final v = formatNumber(r.value);
  return switch (r.key.measure) {
    PrMeasure.heaviestAtReps =>
      'Heaviest at ${r.key.reps} ${r.key.reps == 1 ? 'rep' : 'reps'}: $v kg',
    PrMeasure.longestDuration => 'Longest duration: $v s',
    PrMeasure.longestDistance => 'Longest distance: $v m',
    PrMeasure.mostReps => 'Most repetitions: $v',
  };
}
