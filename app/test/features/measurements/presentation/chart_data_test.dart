import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/measurements/presentation/measurement_chart_data.dart';
import 'package:repforge/ui/components/rf_trend_chart.dart';

import 'measurement_harness.dart';

void main() {
  group('chart gap rule: lines join only real consecutive-day readings', () {
    test('a missing day breaks the line; no point is invented', () {
      final data = siteChartData(
        MeasurementSite.waist,
        [
          reading(MeasurementSite.waist, 90, DateTime(2026, 11, 1, 8)),
          reading(MeasurementSite.waist, 89.5, DateTime(2026, 11, 2, 20)),
          // 3 Nov and 4 Nov have no reading
          reading(MeasurementSite.waist, 89, DateTime(2026, 11, 5, 8)),
        ],
        MeasurementPeriod.weeks4,
        testNow,
      );
      final points = data.series.single.points;
      expect(points.map((p) => p.value), [90.0, 89.5, 89.0]);
      expect(points.map((p) => p.joinPrevious), [false, true, false]);
    });

    test('several readings on one day or on adjacent days stay joined', () {
      final data = siteChartData(
        MeasurementSite.waist,
        [
          reading(MeasurementSite.waist, 90, DateTime(2026, 11, 1, 8)),
          reading(MeasurementSite.waist, 90.2, DateTime(2026, 11, 1, 20)),
          reading(MeasurementSite.waist, 89.8, DateTime(2026, 11, 2, 7)),
        ],
        MeasurementPeriod.weeks4,
        testNow,
      );
      expect(data.series.single.points.map((p) => p.joinPrevious), [
        false,
        true,
        true,
      ]);
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
