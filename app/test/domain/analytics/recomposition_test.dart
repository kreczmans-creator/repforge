import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/recomposition.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurements.dart';

import '../../helpers/analytics_fixtures.dart';

final _period = AnalyticsPeriod.custom(
  CalendarDate(2026, 11, 2),
  CalendarDate(2026, 11, 30),
);

void main() {
  group('RecompositionSeries (GOL-010)', () {
    final weights = [
      for (final d in [1, 2, 3, 4, 10, 11, 12, 25])
        weightReading(90 - d * 0.1, 11, d),
    ];
    final waists = [
      reading(MeasurementSite.waist, 92, 11, 3),
      reading(MeasurementSite.waist, 91, 11, 10), // 7 days: joins
      reading(MeasurementSite.waist, 90, 11, 18), // 8 days: breaks
      reading(MeasurementSite.hips, 100, 11, 5),
    ];
    final strength = [
      exerciseHistory(DateTime(2026, 11, 3, 18), [weighted(80, 5)]),
      exerciseHistory(DateTime(2026, 11, 10, 18), [weighted(82.5, 5)]),
      exerciseHistory(DateTime(2026, 10, 27, 18), [weighted(75, 5)]),
    ];

    RecompositionSeries build() => RecompositionSeries.build(
      period: _period,
      weightReadings: weights,
      waistReadings: waists,
      strengthSessions: strength,
      exerciseId: 'bench',
    );

    test('states the number of points behind each series', () {
      final s = build();
      // Trend points exist from the 3rd reading in a window: 3, 4, 10, 11,
      // 12 (window 6-12 has 10, 11, 12), 25 has only itself.
      expect(s.weight.pointCount, greaterThan(0));
      expect(s.waist.pointCount, 3);
      expect(s.strength.pointCount, 2);
      expect(s.countTexts, [
        '${s.weight.name}: ${s.weight.pointCount} points',
        'Waist: 3 points',
        'Top set weight: 2 points',
      ]);
    });

    test('weight points are trend values inside the period', () {
      final s = build();
      expect(s.weight.points.every((p) => _period.containsDay(p.date)), isTrue);
      expect(s.weight.points.first.date, CalendarDate(2026, 11, 3));
      expect(s.weight.points.first.joinPrevious, isFalse);
      // 3 Nov: window holds readings of the 1st, 2nd and 3rd.
      expect(s.weight.points.first.value, closeTo(89.8, 1e-9));
    });

    test('waist uses the 7-day join rule of the measurements domain', () {
      final s = build();
      expect(s.waist.points.map((p) => p.joinPrevious), [false, true, false]);
      expect(s.waist.points.map((p) => p.value), [92, 91, 90]);
    });

    test('strength is the top-set weight per session in the period', () {
      final s = build();
      expect(s.strength.points.map((p) => p.value), [80, 82.5]);
      expect(s.strength.points.map((p) => p.date), [
        CalendarDate(2026, 11, 3),
        CalendarDate(2026, 11, 10),
      ]);
      expect(s.strength.points.last.joinPrevious, isTrue);
      expect(s.exerciseId, 'bench');
    });

    test('all three series share one date range', () {
      final s = build();
      expect(s.range.start, CalendarDate(2026, 11, 2));
      expect(s.range.end, CalendarDate(2026, 11, 30));
      expect(s.series, hasLength(3));
      for (final series in s.series) {
        for (final p in series.points) {
          expect(s.range.contains(p.date), isTrue);
        }
      }
    });

    test('a series with no data says 0 points; none is invented', () {
      final s = RecompositionSeries.build(
        period: _period,
        weightReadings: const [],
        waistReadings: const [],
        strengthSessions: const [],
      );
      expect(s.weight.pointCount, 0);
      expect(s.waist.pointCount, 0);
      expect(s.strength.pointCount, 0);
      expect(s.exerciseId, isNull);
      expect(s.waist.countText, 'Waist: 0 points');
    });

    test('a single point reads "1 point"', () {
      final s = RecompositionSeries.build(
        period: _period,
        weightReadings: const [],
        waistReadings: [reading(MeasurementSite.waist, 92, 11, 3)],
        strengthSessions: const [],
      );
      expect(s.waist.countText, 'Waist: 1 point');
    });

    test('readings outside the period do not count', () {
      final s = RecompositionSeries.build(
        period: _period,
        weightReadings: const [],
        waistReadings: [
          reading(MeasurementSite.waist, 92, 10, 30),
          reading(MeasurementSite.waist, 92, 12, 1),
        ],
        strengthSessions: const [],
      );
      expect(s.waist.pointCount, 0);
    });
  });
}
