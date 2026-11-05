import 'package:meta/meta.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurements.dart';

/// Trailing window length of the weight trend, in calendar days.
const int trendWindowDays = 7;

/// Minimum number of **individual readings** in the window for a trend value
/// (owner decision D1: at least three readings, not three distinct days).
/// Three readings on two days, or four on one day, are enough; two are not.
const int trendMinReadings = 3;

/// One day with weight entries on the trend line.
@immutable
final class WeightTrendPoint {
  const WeightTrendPoint({
    required this.date,
    required this.dailyMean,
    required this.readingsInWindow,
    this.average,
  });

  /// Local calendar date.
  final CalendarDate date;

  /// Mean of that day's raw entries (kg).
  final double dailyMean;

  /// Individual readings in the window `date-6 .. date` (including [date]).
  final int readingsInWindow;

  /// Trend value (kg): the mean of the daily means of the days with entries
  /// in the window. Null when [readingsInWindow] is below
  /// [trendMinReadings] (BCM-006(2)): no value is drawn.
  final double? average;
}

/// Weight trend line, owner-approved method (D1, 2026-11-05).
///
/// 1. group the weight readings by local calendar date and take each day's
///    mean (so a day with three weigh-ins counts once in the average);
/// 2. for each date that has entries, take the trailing window of the
///    [trendWindowDays] calendar days ending on that date;
/// 3. the trend value is the mean of the daily means of the days with entries
///    in that window, shown only when the window holds at least
///    [trendMinReadings] individual readings (not distinct days), else null.
///
/// Returns one point per date with entries, oldest first; a point's `average`
/// may be null. Raw readings are not modified or dropped (the chart draws
/// them itself). Gaps are not interpolated: dates without entries get no
/// point. Readings of other sites in [readings] are ignored.
List<WeightTrendPoint> weightTrend(Iterable<Measurement> readings) {
  final sums = <CalendarDate, ({double sum, int n})>{};
  for (final m in readings) {
    if (m.site != MeasurementSite.weight) continue;
    final d = CalendarDate.fromInstant(m.recordedAt);
    final cur = sums[d];
    sums[d] = (sum: (cur?.sum ?? 0) + m.value.raw, n: (cur?.n ?? 0) + 1);
  }
  final dates = sums.keys.toList()..sort();
  return [
    for (final d in dates)
      () {
        var readingCount = 0;
        var days = 0;
        var total = 0.0;
        for (var i = 0; i < trendWindowDays; i++) {
          final day = sums[d.addDays(-i)];
          if (day != null) {
            readingCount += day.n;
            days++;
            total += day.sum / day.n;
          }
        }
        final own = sums[d]!;
        return WeightTrendPoint(
          date: d,
          dailyMean: own.sum / own.n,
          readingsInWindow: readingCount,
          average: readingCount >= trendMinReadings ? total / days : null,
        );
      }(),
  ];
}

/// [weightTrend] limited to points whose date lies in [range] (null = all).
/// The window still looks back before the range start, so the first points of
/// a period are not artificially empty.
List<WeightTrendPoint> weightTrendInRange(
  Iterable<Measurement> readings,
  DateRange? range,
) => [
  for (final p in weightTrend(readings))
    if (range == null || range.contains(p.date)) p,
];
