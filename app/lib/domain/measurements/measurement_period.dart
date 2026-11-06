import 'package:meta/meta.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurements.dart';

/// Selectable chart/summary periods (BCM-005): 4 weeks, 12 weeks, 1 year, all.
enum MeasurementPeriod {
  weeks4('4 weeks'),
  weeks12('12 weeks'),
  year1('1 year'),
  all('All');

  MeasurementPeriod(this.label);
  final String label;

  /// The inclusive range of **local calendar dates** ending on [today]
  /// (today is included), or null for [all].
  ///
  /// - [weeks4]: the 28 dates `today-27 .. today`.
  /// - [weeks12]: the 84 dates `today-83 .. today`.
  /// - [year1]: the dates after the same day last year up to today, i.e.
  ///   `(today - 1 year) + 1 day .. today` (365 or 366 dates).
  DateRange? rangeEndingOn(CalendarDate today) => switch (this) {
    weeks4 => DateRange(today.addDays(-27), today),
    weeks12 => DateRange(today.addDays(-83), today),
    year1 => DateRange(today.addYears(-1).addDays(1), today),
    all => null,
  };
}

/// An inclusive range of local calendar dates.
@immutable
final class DateRange {
  const DateRange(this.start, this.end);

  final CalendarDate start;
  final CalendarDate end;

  bool contains(CalendarDate date) =>
      date.compareTo(start) >= 0 && date.compareTo(end) <= 0;

  /// Whether the local calendar date of [instant] lies in the range.
  bool containsInstant(DateTime instant) =>
      contains(CalendarDate.fromInstant(instant));

  @override
  bool operator ==(Object other) =>
      other is DateRange && other.start == start && other.end == end;

  @override
  int get hashCode => Object.hash(start, end);

  @override
  String toString() => '$start..$end';
}

/// Orders readings oldest first: by instant, then creation time, then id, so
/// the order is total and stable.
int compareOldestFirst(Measurement a, Measurement b) {
  final byTime = a.recordedAt.compareTo(b.recordedAt);
  if (byTime != 0) return byTime;
  final byCreated = a.createdAt.compareTo(b.createdAt);
  return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
}

/// The readings of [site] whose local calendar date lies in [range] (all
/// readings of the site when [range] is null), oldest first.
List<Measurement> readingsOf(
  Iterable<Measurement> all,
  MeasurementSite site, {
  DateRange? range,
}) => [
  for (final m in all)
    if (m.site == site &&
        (range == null || range.containsInstant(m.recordedAt)))
      m,
]..sort(compareOldestFirst);

/// Filters [readings] to [period] ending on the local date of [now]
/// (BCM-005); oldest first. Does not alter the readings.
List<Measurement> filterByPeriod(
  Iterable<Measurement> readings,
  MeasurementPeriod period,
  DateTime now,
) {
  final range = period.rangeEndingOn(CalendarDate.fromInstant(now));
  return [
    for (final m in readings)
      if (range == null || range.containsInstant(m.recordedAt)) m,
  ]..sort(compareOldestFirst);
}

/// Chart gap rule (BCM-005(2), UXD-009; owner decision B, 2026-11-05): a line
/// may join two consecutive readings of a series when their **local calendar
/// dates** are at most this many days apart (difference in dates, not in
/// elapsed hours: 7 days apart joins, 8 days apart breaks, also across a
/// daylight-saving change). A longer gap breaks the line. The join is only a
/// visual link between two recorded observations: readings are always drawn
/// as points, and no value is ever computed for a date without a reading.
const int chartJoinMaxDayGap = 7;

/// Whether a chart line may join [earlier] to [later] (see
/// [chartJoinMaxDayGap]).
bool chartJoins(DateTime earlier, DateTime later) =>
    CalendarDate.fromInstant(earlier)
        .daysUntil(CalendarDate.fromInstant(later)) <=
    chartJoinMaxDayGap;

/// The newest reading of each site in [all] (any order).
Map<MeasurementSite, Measurement> latestPerSite(Iterable<Measurement> all) {
  final out = <MeasurementSite, Measurement>{};
  for (final m in all) {
    final cur = out[m.site];
    if (cur == null || compareOldestFirst(cur, m) < 0) out[m.site] = m;
  }
  return out;
}
