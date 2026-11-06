import 'package:intl/intl.dart' show DateFormat;
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_validation.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/training/presentation/set_format.dart';

/// `Thu 5 Nov 2026`.
String formatScheduleDate(DateTime d) => DateFormat('EEE d MMM y').format(d);

/// Names of the weekdays 1 (Monday) to 7 (Sunday).
const weekdayNames = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// Short weekday label for 1 (Monday) to 7 (Sunday).
String weekdayShort(int weekday) => weekdayNames[weekday - 1].substring(0, 3);

/// The weekdays 1..7 starting at [weekStartDay] (1 Monday to 7 Sunday).
List<int> weekdaysFrom(int weekStartDay) => [
  for (var i = 0; i < 7; i++) (weekStartDay - 1 + i) % 7 + 1,
];

/// One plan exercise's targets as text: `3 × 8–10 reps`, `3 × 1:00`,
/// `2 × 400 m`, plus load and rest when set.
String formatPlanTargets(PlanExercise e) {
  final parts = <String>['${e.targetSets} sets'];
  final min = e.repsMin;
  final max = e.repsMax;
  if (min != null && max != null) {
    parts.add(min == max ? '$min reps' : '$min–$max reps');
  }
  if (e.targetDuration != null) parts.add(formatClock(e.targetDuration!));
  if (e.targetMetres != null) parts.add(formatDistance(e.targetMetres!));
  if (e.targetLoad != null) {
    parts.add('${formatNumber(e.targetLoad!.value, maxDecimals: 2)} kg');
  }
  if (e.restSeconds != null) parts.add('rest ${e.restSeconds} s');
  return parts.join(' · ');
}
