import 'package:meta/meta.dart';

/// A calendar date (year, month, day) without a time or a zone.
///
/// Measurements are instants (stored as UTC); every calendar rule — "today",
/// ranges, comparison dates, daily means — uses the **local** calendar date of
/// the instant, obtained with [CalendarDate.fromInstant]. Date arithmetic is
/// done on UTC dates so daylight-saving changes cannot shift or repeat a day.
@immutable
final class CalendarDate implements Comparable<CalendarDate> {
  /// A date; out-of-range months or days roll over (2026-02-30 → 2026-03-02).
  factory CalendarDate(int year, int month, int day) {
    final d = DateTime.utc(year, month, day);
    return CalendarDate._(d.year, d.month, d.day);
  }

  const CalendarDate._(this.year, this.month, this.day);

  /// The local calendar date of [instant] in the device time zone.
  factory CalendarDate.fromInstant(DateTime instant) {
    final l = instant.toLocal();
    return CalendarDate._(l.year, l.month, l.day);
  }

  final int year;
  final int month;
  final int day;

  DateTime get _utc => DateTime.utc(year, month, day);

  /// Days since 1970-01-01 (UTC calendar), a total order key.
  int get epochDay =>
      _utc.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;

  CalendarDate addDays(int days) => CalendarDate(year, month, day + days);

  /// Same month and day [years] later; 29 February rolls to 1 March.
  CalendarDate addYears(int years) => CalendarDate(year + years, month, day);

  /// Whole days from this date to [other] (negative when [other] is earlier).
  int daysUntil(CalendarDate other) => other.epochDay - epochDay;

  /// ISO 8601 date, e.g. `2026-11-05`.
  String get iso =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  bool isBefore(CalendarDate other) => compareTo(other) < 0;
  bool isAfter(CalendarDate other) => compareTo(other) > 0;

  @override
  int compareTo(CalendarDate other) => epochDay.compareTo(other.epochDay);

  @override
  bool operator ==(Object other) =>
      other is CalendarDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => iso;
}
