import 'package:repforge/domain/nutrition/nutrition.dart' show dayKey;
import 'package:repforge/domain/training/training.dart';

/// How a scheduled workout came to exist (TRN-015).
enum ScheduleOrigin { date, weekday, split }

/// State of a scheduled workout. Only a planned one can be moved or skipped.
enum ScheduleStatus { planned, skipped, done }

/// Weeks a weekday pattern or a split cycle is scheduled ahead (TRN-015(1)).
const scheduleHorizonWeeks = 8;

/// A workout plan placed on a local date (TRN-015). A dated row of its own, so
/// moving or skipping it never touches the plan.
///
/// [day] is the date it is on now; [sourceDay] the date it was generated for
/// (equal to [day] until it is moved). [sessionId] is the session started
/// from it once [status] is done.
class ScheduledWorkout {
  const ScheduledWorkout({
    required this.id,
    required this.day,
    required this.sourceDay,
    required this.planId,
    required this.origin,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.sessionId,
  });

  final String id;
  final DateTime day;
  final DateTime sourceDay;
  final String planId;
  final ScheduleOrigin origin;
  final ScheduleStatus status;
  final String? sessionId;
  final DateTime createdAt;
  final DateTime updatedAt;

  ScheduledWorkout copyWith({
    DateTime? day,
    ScheduleStatus? status,
    String? sessionId,
    DateTime? updatedAt,
  }) => ScheduledWorkout(
    id: id,
    day: day ?? this.day,
    sourceDay: sourceDay,
    planId: planId,
    origin: origin,
    status: status ?? this.status,
    sessionId: sessionId ?? this.sessionId,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}

/// The calendar date of [d] as a local date-only value (midnight).
DateTime scheduleDate(DateTime d) => DateTime(d.year, d.month, d.day);

/// Storage and comparison key of a scheduled date (`YYYY-MM-DD`).
String scheduleDayKey(DateTime d) => dayKey(scheduleDate(d));

/// Parses a key written by [scheduleDayKey]; null when malformed.
DateTime? parseScheduleDayKey(String key) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (m == null) return null;
  final d = DateTime(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
  return scheduleDayKey(d) == key ? d : null;
}

/// Dates of the next [weeks] weeks from [start] (inclusive) that fall on one
/// of [weekdays] (1 Monday to 7 Sunday), in date order.
List<DateTime> weekdayDates(
  DateTime start,
  Iterable<int> weekdays, {
  int weeks = scheduleHorizonWeeks,
}) {
  final first = scheduleDate(start);
  final wanted = weekdays.toSet();
  return [
    for (var i = 0; i < weeks * 7; i++)
      if (wanted.contains(
        DateTime(first.year, first.month, first.day + i).weekday,
      ))
        DateTime(first.year, first.month, first.day + i),
  ];
}

/// One date of a split cycle with its workout.
class SplitOccurrence {
  const SplitOccurrence(this.date, this.planId);
  final DateTime date;
  final String planId;
}

/// Lays [split]'s cycle over the next [weeks] weeks from [start]: day 0 of
/// the cycle is [start], the cycle then repeats. Rest days produce nothing.
List<SplitOccurrence> splitOccurrences(
  TrainingSplit split,
  DateTime start, {
  int weeks = scheduleHorizonWeeks,
}) {
  final first = scheduleDate(start);
  final out = <SplitOccurrence>[];
  for (var i = 0; i < weeks * 7; i++) {
    final planId = split.days[i % split.cycleDays].planId;
    if (planId != null) {
      out.add(
        SplitOccurrence(
          DateTime(first.year, first.month, first.day + i),
          planId,
        ),
      );
    }
  }
  return out;
}
