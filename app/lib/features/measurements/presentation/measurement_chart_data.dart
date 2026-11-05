import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurement_site_help.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/weight_trend.dart';
import 'package:repforge/features/measurements/presentation/measurement_format.dart';
import 'package:repforge/ui/components/rf_trend_chart.dart';

/// What a chart screen needs for one measurement type and period: the series
/// for `RfTrendChart`, its unit and a text summary. Mapping only: values come
/// from the domain (readings, the D1 trend, the gap rule); nothing is
/// computed or invented here.
final class SiteChartData {
  const SiteChartData({
    required this.series,
    required this.unit,
    required this.summary,
    required this.readingCount,
  });

  final List<RfTrendSeries> series;
  final String unit;

  /// Plain-text summary shown above the chart and read by screen readers.
  final String summary;

  /// Readings of the shown site(s) in the period.
  final int readingCount;
}

/// Series for [site] over [period] ending on the local date of [now].
///
/// - Weight: the raw readings as points only, plus the D1 trend as a separate
///   line "7-day trend" drawn only where the rule yields a value.
/// - Left/right sites: both sides on one chart, left as circles with a solid
///   line and right as diamonds with a dashed line.
/// - Others: one series.
///
/// Lines join only readings the gap rule ([chartJoins]) allows.
SiteChartData siteChartData(
  MeasurementSite site,
  Iterable<Measurement> all,
  MeasurementPeriod period,
  DateTime now,
) {
  final list = all.toList();
  final range = period.rangeEndingOn(CalendarDate.fromInstant(now));
  List<Measurement> inPeriod(MeasurementSite s) =>
      readingsOf(list, s, range: range);

  List<RfTrendPoint> pointsOf(List<Measurement> readings) {
    final points = <RfTrendPoint>[];
    for (var i = 0; i < readings.length; i++) {
      final joins =
          i > 0 &&
          chartJoins(readings[i - 1].recordedAt, readings[i].recordedAt);
      points.add(
        RfTrendPoint(
          readings[i].recordedAt.toLocal(),
          readings[i].value.raw,
          joinPrevious: joins,
        ),
      );
    }
    return points;
  }

  if (site.isWeight) {
    final raw = inPeriod(site);
    // The trend's x position is the day's latest reading, so the data table
    // lines the trend value up with a reading.
    final lastOfDay = <CalendarDate, DateTime>{
      for (final m in raw) CalendarDate.fromInstant(m.recordedAt): m.recordedAt,
    };
    final trendPoints = <RfTrendPoint>[];
    CalendarDate? prevDate;
    var prevHadValue = false;
    for (final p in weightTrendInRange(list, range)) {
      final at = lastOfDay[p.date];
      final value = p.average;
      if (at != null && value != null) {
        final joins =
            prevHadValue &&
            prevDate != null &&
            prevDate.daysUntil(p.date) <= chartJoinMaxDayGap;
        trendPoints.add(RfTrendPoint(at.toLocal(), value, joinPrevious: joins));
      }
      prevDate = p.date;
      prevHadValue = value != null;
    }
    final series = [
      RfTrendSeries(
        label: 'Weight readings',
        points: pointsOf(raw),
        showLine: false,
      ),
      RfTrendSeries(
        label: '7-day trend',
        points: trendPoints,
        showMarkers: false,
        markIsolated: true,
        marker: RfTrendMarker.square,
      ),
    ];
    final trendText = trendPoints.isEmpty
        ? ' No 7-day trend: it needs at least three readings within seven '
              'days.'
        : ' 7-day trend, latest '
              '${trendPoints.last.value.toStringAsFixed(1)} kg.';
    return SiteChartData(
      series: series,
      unit: 'kg',
      summary: _describe('Weight', raw, 'kg', period) + trendText,
      readingCount: raw.length,
    );
  }

  final other = site.counterpart;
  if (other != null) {
    final left = site.name.endsWith('Left') ? site : other;
    final right = left.counterpart ?? site;
    final l = inPeriod(left);
    final r = inPeriod(right);
    return SiteChartData(
      series: [
        RfTrendSeries(label: left.label, points: pointsOf(l)),
        RfTrendSeries(
          label: right.label,
          points: pointsOf(r),
          marker: RfTrendMarker.diamond,
          dashed: true,
        ),
      ],
      unit: 'cm',
      summary:
          '${_describe(left.label, l, 'cm', period)} '
          '${_describe(right.label, r, 'cm', period)}',
      readingCount: l.length + r.length,
    );
  }

  final readings = inPeriod(site);
  return SiteChartData(
    series: [RfTrendSeries(label: site.label, points: pointsOf(readings))],
    unit: site.unit,
    summary: _describe(site.label, readings, site.unit, period),
    readingCount: readings.length,
  );
}

String _describe(
  String name,
  List<Measurement> readings,
  String unit,
  MeasurementPeriod period,
) {
  final span = period == MeasurementPeriod.all
      ? 'all time'
      : 'last ${period.label}';
  if (readings.isEmpty) return '$name, $span: no readings.';
  final values = readings.map((m) => m.value.raw);
  final lo = values.reduce((a, b) => a < b ? a : b);
  final hi = values.reduce((a, b) => a > b ? a : b);
  final latest = readings.last;
  final count = readings.length;
  return '$name, $span: $count ${count == 1 ? 'reading' : 'readings'}, '
      'latest ${formatReading(latest)} on ${formatDay(latest.recordedAt)}, '
      'lowest ${lo.toStringAsFixed(1)} $unit, '
      'highest ${hi.toStringAsFixed(1)} $unit.';
}
