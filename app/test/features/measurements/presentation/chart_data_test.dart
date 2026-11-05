import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/measurements/presentation/measurement_chart_data.dart';
import 'package:repforge/ui/components/rf_trend_chart.dart';

import 'measurement_harness.dart';

void main() {
  group('chart gap rule (owner decision B): at most 7 calendar days joins', () {
    List<bool> joins(List<DateTime> at) => siteChartData(
      MeasurementSite.waist,
      [for (final t in at) reading(MeasurementSite.waist, 90, t)],
      MeasurementPeriod.all,
      testNow,
    ).series.single.points.map((p) => p.joinPrevious).toList();

    test('exactly 7 days joins, 8 days breaks; no point is invented', () {
      final data = siteChartData(
        MeasurementSite.waist,
        [
          reading(MeasurementSite.waist, 90, DateTime(2026, 10, 1, 8)),
          reading(MeasurementSite.waist, 89.5, DateTime(2026, 10, 8, 20)),
          reading(MeasurementSite.waist, 89, DateTime(2026, 10, 16, 8)),
        ],
        MeasurementPeriod.all,
        testNow,
      );
      final points = data.series.single.points;
      expect(points.map((p) => p.value), [90.0, 89.5, 89.0]);
      expect(points.map((p) => p.joinPrevious), [false, true, false]);
    });

    test('the rule counts calendar dates, not elapsed time', () {
      // 7 dates apart but only 6 days and 4 hours elapsed: joined.
      expect(joins([DateTime(2026, 10, 1, 20), DateTime(2026, 10, 8, 0, 30)]), [
        false,
        true,
      ]);
      // 8 dates apart although only 7 days and 1 hour elapsed: broken.
      expect(
        joins([DateTime(2026, 10, 1, 23, 30), DateTime(2026, 10, 9, 0, 30)]),
        [false, false],
      );
    });

    test('pairs spanning a daylight-saving change follow the same rule', () {
      // Local wall-clock times: under TZ=Pacific/Auckland the change is on
      // 27 Sep 2026 and under America/Los_Angeles on 1 Nov 2026 (the rule
      // uses calendar dates, so the 23 or 25 hour day changes nothing).
      for (final (a, b) in [
        (DateTime(2026, 9, 24, 12), DateTime(2026, 10, 1, 12)),
        (DateTime(2026, 10, 28, 12), DateTime(2026, 11, 4, 12)),
      ]) {
        expect(joins([a, b]), [false, true], reason: '$a to $b is 7 dates');
      }
      for (final (a, b) in [
        (DateTime(2026, 9, 24, 12), DateTime(2026, 10, 2, 12)),
        (DateTime(2026, 10, 28, 12), DateTime(2026, 11, 5, 12)),
      ]) {
        expect(joins([a, b]), [false, false], reason: '$a to $b is 8 dates');
      }
    });

    test('several readings on one day or on adjacent days stay joined', () {
      expect(
        joins([
          DateTime(2026, 11, 1, 8),
          DateTime(2026, 11, 1, 20),
          DateTime(2026, 11, 2, 7),
        ]),
        [false, true, true],
      );
    });

    test('the 7-day trend line follows the same rule', () {
      // Three readings a day, one day every [gapDays]: every day has a trend
      // value; days 7 apart join, days 8 apart break.
      List<bool> trendJoins(int gapDays) {
        final readings = [
          for (var day = 0; day < 3; day++)
            for (var h = 0; h < 3; h++)
              reading(
                MeasurementSite.weight,
                80 + day * 0.1,
                DateTime(2026, 9, 1 + day * gapDays, 8 + h),
              ),
        ];
        final trend = siteChartData(
          MeasurementSite.weight,
          readings,
          MeasurementPeriod.all,
          testNow,
        ).series[1].points;
        expect(trend, hasLength(3));
        return [for (final p in trend) p.joinPrevious];
      }

      expect(trendJoins(7), [false, true, true]);
      expect(trendJoins(8), [false, false, false]);
    });

    test('the summary carries the line note only when a line is drawn', () {
      String summary(MeasurementSite site, List<DateTime> at) => siteChartData(
        site,
        [for (final t in at) reading(site, 90, t)],
        MeasurementPeriod.all,
        testNow,
      ).summary;
      const lines =
          'Lines connect readings up to 7 days apart; they are not '
          'measurements.';
      const trend =
          'The trend line connects values up to 7 days apart; it is not a '
          'measurement.';
      final adjacent = [DateTime(2026, 11, 1, 8), DateTime(2026, 11, 2, 8)];
      final far = [DateTime(2026, 10, 1, 8), DateTime(2026, 10, 20, 8)];

      expect(summary(MeasurementSite.waist, adjacent), endsWith(lines));
      expect(summary(MeasurementSite.thighLeft, adjacent), endsWith(lines));
      // No line: one reading, none, or every pair further apart than 7 days.
      for (final at in [
        <DateTime>[],
        [adjacent.first],
        far,
      ]) {
        expect(
          summary(MeasurementSite.waist, at),
          isNot(contains('connect')),
          reason: '$at',
        );
      }
      // Weight: the trend line is the only line (needs 3 readings a day
      // somewhere); raw readings are points only, so no note without it.
      expect(summary(MeasurementSite.weight, adjacent), isNot(contains(trend)));
      expect(
        summary(MeasurementSite.weight, adjacent),
        isNot(contains('Lines connect')),
      );
      final trendDays = [
        for (var d = 0; d < 3; d++)
          for (var h = 0; h < 3; h++) DateTime(2026, 11, 1 + d, 8 + h),
      ];
      expect(summary(MeasurementSite.weight, trendDays), endsWith(trend));
    });
  });

  group('left/right series differ by more than colour', () {
    test('marker shape and dash pattern differ; both sides on one chart', () {
      final data = siteChartData(
        MeasurementSite.bicepsRight,
        [
          reading(MeasurementSite.bicepsLeft, 35, DateTime(2026, 11, 1, 8)),
          reading(MeasurementSite.bicepsRight, 34, DateTime(2026, 11, 1, 8)),
        ],
        MeasurementPeriod.all,
        testNow,
      );
      expect(data.series.map((s) => s.label), ['Left biceps', 'Right biceps']);
      final left = data.series[0];
      final right = data.series[1];
      expect(left.marker, isNot(right.marker));
      expect(left.dashed, isFalse);
      expect(right.dashed, isTrue);
      expect(data.unit, 'cm');
    });
  });

  group('weight trend series (D1)', () {
    test('raw readings are points only; trend is a separate labelled line', () {
      final data = siteChartData(
        MeasurementSite.weight,
        [
          reading(MeasurementSite.weight, 80, DateTime(2026, 11, 1, 8)),
          reading(MeasurementSite.weight, 81, DateTime(2026, 11, 2, 8)),
          reading(MeasurementSite.weight, 82, DateTime(2026, 11, 3, 8)),
        ],
        MeasurementPeriod.weeks4,
        testNow,
      );
      final raw = data.series[0];
      final trend = data.series[1];
      expect(raw.label, 'Weight readings');
      expect(raw.showLine, isFalse);
      expect(raw.points, hasLength(3));
      expect(trend.label, '7-day trend');
      expect(trend.showMarkers, isFalse);
      // 1 and 2 Nov have fewer than three readings in the window: no value.
      expect(trend.points.map((p) => p.value), [81.0]);
      expect(raw.marker, isNot(RfTrendMarker.square));
    });

    test('three readings on two days give a trend, two do not', () {
      final two = siteChartData(
        MeasurementSite.weight,
        [
          reading(MeasurementSite.weight, 80, DateTime(2026, 11, 1, 8)),
          reading(MeasurementSite.weight, 81, DateTime(2026, 11, 2, 8)),
        ],
        MeasurementPeriod.weeks4,
        testNow,
      );
      expect(two.series[1].points, isEmpty);
      final three = siteChartData(
        MeasurementSite.weight,
        [
          reading(MeasurementSite.weight, 80, DateTime(2026, 11, 1, 8)),
          reading(MeasurementSite.weight, 80, DateTime(2026, 11, 1, 20)),
          reading(MeasurementSite.weight, 83, DateTime(2026, 11, 2, 8)),
        ],
        MeasurementPeriod.weeks4,
        testNow,
      );
      expect(three.series[1].points.map((p) => p.value), [81.5]);
    });

    test('the trend line breaks where a day has no trend value', () {
      // 3 readings by 3 Nov (trend on 3 Nov); 4 Nov adds one more (trend);
      // a day later than 7 days with a single reading has no trend.
      final data = siteChartData(
        MeasurementSite.weight,
        [
          reading(MeasurementSite.weight, 80, DateTime(2026, 10, 20, 8)),
          reading(MeasurementSite.weight, 80, DateTime(2026, 10, 21, 8)),
          reading(MeasurementSite.weight, 80, DateTime(2026, 10, 22, 8)),
          reading(MeasurementSite.weight, 80, DateTime(2026, 10, 30, 8)),
          reading(MeasurementSite.weight, 80, DateTime(2026, 11, 1, 8)),
        ],
        MeasurementPeriod.weeks12,
        testNow,
      );
      final trend = data.series[1].points;
      // 22 Oct has three readings; 30 Oct and 1 Nov have fewer than three.
      expect(trend, hasLength(1));
      expect(trend.single.joinPrevious, isFalse);
    });
  });

  test('empty period gives a summary that says so', () {
    final data = siteChartData(
      MeasurementSite.neck,
      const [],
      MeasurementPeriod.weeks4,
      testNow,
    );
    expect(data.readingCount, 0);
    expect(data.summary, 'Neck, last 4 weeks: no readings.');
  });
}
