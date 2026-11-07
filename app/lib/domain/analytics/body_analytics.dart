import 'package:meta/meta.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/weight_trend.dart';

/// Change of the weight trend between the first and the last trend point of
/// a window, per week (WP 11 plan decision 8a).
///
/// The trend points are those of the owner-approved WP 10 method
/// ([weightTrend]); the rate is `(last - first) / weeks between them`, with
/// no interpolation and no regression.
@immutable
final class RateOfChange {
  const RateOfChange({
    required this.perWeek,
    required this.fromDate,
    required this.toDate,
    required this.fromValue,
    required this.toValue,
    required this.pointsUsed,
  });

  /// kg per week; negative when the trend fell.
  final double perWeek;

  /// Date of the first trend point of the window.
  final CalendarDate fromDate;

  /// Date of the last trend point of the window.
  final CalendarDate toDate;
  final double fromValue;
  final double toValue;

  /// Trend points with a value inside the window (the first and last of
  /// them give the rate).
  final int pointsUsed;

  /// Weeks between the two points (days / 7).
  double get weeks => fromDate.daysUntil(toDate) / 7;

  /// Last trend value minus first, in kg.
  double get change => toValue - fromValue;
}

/// Body weight over a period (GOL-003, GOL-007): the latest raw reading, the
/// latest trend value, and the change of the trend.
///
/// Body readings belong to the local calendar date of the reading and ignore
/// the day-start setting (plan decision 7b; [calendarDayRule]). The readings
/// passed in should reach back [trendWindowDays] - 1 days before the period
/// start so the first trend points are not artificially empty.
@immutable
final class WeightSummary {
  const WeightSummary._({
    required this.period,
    required this.latestRaw,
    required this.latestTrend,
    required this.readingsInWindow,
    required this.recentReadingCount,
    required this.trendPoints,
    required this.rateOfChange,
    required this.trendChange,
    required this._weights,
  });

  /// Builds the summary from weight [readings] (other sites are ignored;
  /// readings after the period end are ignored).
  factory WeightSummary.build({
    required AnalyticsPeriod period,
    required Iterable<Measurement> readings,
  }) {
    final upToEnd = [
      for (final m in readings)
        if (m.site == MeasurementSite.weight &&
            !CalendarDate.fromInstant(m.recordedAt).isAfter(period.to))
          m,
    ]..sort(compareOldestFirst);
    final all = weightTrend(upToEnd);
    final withValue = [
      for (final p in all)
        if (p.average != null) p,
    ];
    final inWindow = [
      for (final p in withValue)
        if (period.containsDay(p.date)) p,
    ];
    final trendFrom = period.to.addDays(-(trendWindowDays - 1));
    final recent = upToEnd
        .where(
          (m) => !CalendarDate.fromInstant(m.recordedAt).isBefore(trendFrom),
        )
        .length;

    MetricBasis basis(int n) => MetricBasis(
      period: period,
      sampleCount: n,
      sources: const ['weight readings (7-day trend)'],
      dayRule: calendarDayRule,
    );

    final Metric<RateOfChange> rate;
    final Metric<double> change;
    if (inWindow.length >= 2) {
      final first = inWindow.first;
      final last = inWindow.last;
      final r = RateOfChange(
        perWeek:
            (last.average! - first.average!) /
            (first.date.daysUntil(last.date) / 7),
        fromDate: first.date,
        toDate: last.date,
        fromValue: first.average!,
        toValue: last.average!,
        pointsUsed: inWindow.length,
      );
      rate = MetricValue(r, basis(inWindow.length));
      change = MetricValue(r.change, basis(inWindow.length));
    } else {
      final reason = inWindow.isEmpty
          ? 'No weight trend value in ${period.label} (a trend value needs '
                '$trendMinReadings readings in $trendWindowDays days).'
          : 'Only one weight trend value in ${period.label}; two are '
                'needed to compare.';
      rate = NotEnoughData(have: inWindow.length, need: 2, reason: reason);
      change = NotEnoughData(have: inWindow.length, need: 2, reason: reason);
    }

    return WeightSummary._(
      period: period,
      latestRaw: upToEnd.isEmpty ? null : upToEnd.last,
      latestTrend: withValue.isEmpty ? null : withValue.last,
      readingsInWindow: upToEnd
          .where(
            (m) => period.containsDay(CalendarDate.fromInstant(m.recordedAt)),
          )
          .length,
      recentReadingCount: recent,
      trendPoints: List.unmodifiable(inWindow),
      rateOfChange: rate,
      trendChange: change,
      weights: upToEnd,
    );
  }

  final AnalyticsPeriod period;

  /// Weight readings up to the period end, oldest first.
  final List<Measurement> _weights;

  /// The trend value of the window ending on [day], from the readings this
  /// summary holds (so the lookback before the period counts); null when the
  /// window holds fewer than [trendMinReadings] readings. Unlike a trend
  /// point it is defined for a day without a reading.
  double? trendValueOn(CalendarDate day) {
    final byDay = <CalendarDate, List<double>>{};
    for (final m in _weights) {
      final d = CalendarDate.fromInstant(m.recordedAt);
      if (d.isAfter(day) || d.isBefore(day.addDays(-(trendWindowDays - 1)))) {
        continue;
      }
      (byDay[d] ??= []).add(m.value.raw);
    }
    final n = byDay.values.fold<int>(0, (a, l) => a + l.length);
    if (n < trendMinReadings) return null;
    final means = [
      for (final l in byDay.values)
        l.fold<double>(0, (a, b) => a + b) / l.length,
    ];
    return means.fold<double>(0, (a, b) => a + b) / means.length;
  }

  /// The baseline value of a goal that started on [day]: the trend value on
  /// that day, else the latest raw reading on or before it, else the first
  /// raw reading after it; null when there is no reading at all.
  double? baselineOn(CalendarDate day) {
    final trend = trendValueOn(day);
    if (trend != null) return trend;
    Measurement? before;
    Measurement? after;
    for (final m in _weights) {
      final d = CalendarDate.fromInstant(m.recordedAt);
      if (!d.isAfter(day)) {
        before = m;
      } else {
        after ??= m;
      }
    }
    return (before ?? after)?.value.raw;
  }

  /// The newest weight reading on or before the period end; null when there
  /// is none.
  final Measurement? latestRaw;

  /// The newest trend point that has a value (on or before the period end);
  /// null when no window ever held enough readings. Its date is shown with
  /// it: no maximum age is applied (open point of the plan, section 5.3).
  final WeightTrendPoint? latestTrend;

  /// Weight readings dated inside the period.
  final int readingsInWindow;

  /// Weight readings in the [trendWindowDays] days ending on the period end.
  final int recentReadingCount;

  /// The trend points with a value that lie inside the period, oldest
  /// first.
  final List<WeightTrendPoint> trendPoints;

  /// Change of the trend per week inside the period (decision 8a).
  final Metric<RateOfChange> rateOfChange;

  /// Last trend value minus first inside the period, in kg (GOL-007
  /// "weight change over the week").
  final Metric<double> trendChange;
}
