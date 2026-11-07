import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/body_analytics.dart';
import 'package:repforge/domain/analytics/goal_progress.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';

int _seq = 0;

Measurement _m(MeasurementSite site, double v, int mo, int d, [int h = 12]) {
  final at = DateTime(2026, mo, d, h);
  return Measurement(
    id: 'm${_seq++}',
    site: site,
    value: site.isWeight
        ? MeasurementValue.kg(Kilograms.fromStored(v))
        : MeasurementValue.cm(Centimetres.fromStored(v)),
    recordedAt: at.toUtc(),
    createdAt: at.toUtc(),
    updatedAt: at.toUtc(),
  );
}

Measurement _w(double v, int d, [int h = 12, int mo = 11]) =>
    _m(MeasurementSite.weight, v, mo, d, h);

Goal _goal(
  GoalKind kind,
  double target,
  DateTime start, {
  MeasurementSite? site,
}) => Goal(
  id: 'g${_seq++}',
  kind: kind,
  target: target,
  startDate: start.toUtc(),
  createdAt: start.toUtc(),
  updatedAt: start.toUtc(),
  site: site,
);

AnalyticsPeriod _p(int d1, int d2) => AnalyticsPeriod.custom(
  CalendarDate(2026, 11, d1),
  CalendarDate(2026, 11, d2),
);

void main() {
  group('WeightSummary', () {
    test('fewer than 3 readings in 7 days gives no trend value', () {
      final s = WeightSummary.build(
        period: _p(2, 8),
        readings: [_w(85, 2), _w(84.8, 3)],
      );
      expect(s.latestRaw!.value.raw, 84.8);
      expect(s.latestTrend, isNull);
      expect(s.readingsInWindow, 2);
      expect(s.recentReadingCount, 2);
      expect(s.trendPoints, isEmpty);
      expect(s.rateOfChange, isA<NotEnoughData<RateOfChange>>());
      expect(s.trendChange, isA<NotEnoughData<double>>());
    });

    test('three readings on two days are enough for a trend value', () {
      final s = WeightSummary.build(
        period: _p(2, 8),
        readings: [_w(85, 2), _w(85, 3, 8), _w(85, 3, 20)],
      );
      expect(s.latestTrend!.average, 85);
      expect(s.latestTrend!.date, CalendarDate(2026, 11, 3));
    });

    test('no readings at all', () {
      final s = WeightSummary.build(period: _p(2, 8), readings: const []);
      expect(s.latestRaw, isNull);
      expect(s.latestTrend, isNull);
      expect(s.readingsInWindow, 0);
      final r = s.rateOfChange as NotEnoughData<RateOfChange>;
      expect(r.have, 0);
      expect(r.need, 2);
    });

    test('rate of change: last minus first trend point per week (8a)', () {
      final s = WeightSummary.build(
        period: _p(2, 8),
        readings: [_w(90, 2), _w(90, 3), _w(90, 4), _w(87, 8)],
      );
      // Trend points with a value: Nov 4 = 90.0, Nov 8 = (3x90 + 87) / 4.
      expect(s.trendPoints.map((p) => p.date.day), [4, 8]);
      final m = s.rateOfChange as MetricValue<RateOfChange>;
      expect(m.value.fromValue, 90);
      expect(m.value.toValue, 89.25);
      expect(m.value.weeks, closeTo(4 / 7, 1e-12));
      expect(m.value.perWeek, closeTo(-0.75 / (4 / 7), 1e-12));
      expect(m.value.pointsUsed, 2);
      expect(m.value.fromDate, CalendarDate(2026, 11, 4));
      expect(m.value.toDate, CalendarDate(2026, 11, 8));
      expect(m.basis.dayRule, calendarDayRule);
      expect(m.basis.sampleCount, 2);
      expect((s.trendChange as MetricValue<double>).value, -0.75);
    });

    test('a single trend point is not enough to compare', () {
      final s = WeightSummary.build(
        period: _p(2, 8),
        readings: [_w(90, 2), _w(90, 3), _w(90, 4)],
      );
      final r = s.rateOfChange as NotEnoughData<RateOfChange>;
      expect(r.have, 1);
      expect(r.need, 2);
      expect(r.reason, contains('two'));
    });

    test('lookback readings before the period feed its first trend point', () {
      final s = WeightSummary.build(
        period: _p(9, 15),
        readings: [_w(80, 8), _w(80, 9), _w(80, 10), _w(79, 15)],
      );
      expect(s.trendPoints.first.date.day, 10);
      expect(s.readingsInWindow, 3);
      expect(s.latestRaw!.value.raw, 79);
    });

    test('readings after the period and other sites are ignored', () {
      final s = WeightSummary.build(
        period: _p(2, 8),
        readings: [_w(85, 2), _w(99, 20), _m(MeasurementSite.waist, 90, 11, 3)],
      );
      expect(s.latestRaw!.value.raw, 85);
      expect(s.readingsInWindow, 1);
    });

    test('the latest trend value may be older than the period end', () {
      final s = WeightSummary.build(
        period: _p(2, 30),
        readings: [_w(85, 2), _w(85, 3), _w(85, 4), _w(84, 29)],
      );
      expect(s.latestTrend!.date.day, 4);
      expect(s.latestRaw!.value.raw, 84);
    });
  });

  group('weight GoalProgress (GOL-003)', () {
    final goalStart = DateTime(2026, 11, 2, 9);

    test(
      '85.0 to 80.0 shows 5.0 to go, using the trend value, not the raw',
      () {
        final goal = _goal(GoalKind.bodyWeight, 80, goalStart);
        final summary = WeightSummary.build(
          period: _p(2, 8),
          readings: [_w(85.4, 2), _w(85, 3), _w(84.6, 4)],
        );
        // Raw latest is 84.6; the trend value is 85.0.
        expect(summary.latestRaw!.value.raw, 84.6);
        final p = GoalProgress.bodyWeight(goal: goal, summary: summary);
        expect((p.current as MetricValue<double>).value, 85);
        expect(p.state, GoalState.inProgress);
        expect(p.direction, GoalDirection.decrease);
        expect(p.remaining, 5.0);
        expect(p.statement, '5.0 kg to go');
        expect(p.target, 80);
        expect(p.percent, 0);
        expect(p.drillDown.kind, DrillDownKind.weightEntries);
        final basis = (p.current as MetricValue<double>).basis;
        expect(basis.period, _p(2, 8));
        expect(basis.sources.single, contains('trend value of 2026-11-04'));
      },
    );

    test('shows the percentage of the way from the first trend value', () {
      final goal = _goal(GoalKind.bodyWeight, 80, goalStart);
      final summary = WeightSummary.build(
        period: _p(2, 12),
        readings: [
          _w(85, 2),
          _w(85, 3),
          _w(85, 4),
          _w(82.5, 10),
          _w(82.5, 11),
          _w(82.5, 12),
        ],
      );
      final p = GoalProgress.bodyWeight(goal: goal, summary: summary);
      expect(p.startValue, 85);
      expect(p.remaining, 2.5);
      expect(p.percent, 50);
    });

    test('gaining goal: a trend below the target has to increase', () {
      final goal = _goal(GoalKind.bodyWeight, 75, goalStart);
      final summary = WeightSummary.build(
        period: _p(2, 8),
        readings: [_w(70, 2), _w(70, 3), _w(70, 4)],
      );
      final p = GoalProgress.bodyWeight(goal: goal, summary: summary);
      expect(p.direction, GoalDirection.increase);
      expect(p.remaining, 5.0);
    });

    test('at target when the trend equals the target', () {
      final goal = _goal(GoalKind.bodyWeight, 80, goalStart);
      final summary = WeightSummary.build(
        period: _p(2, 8),
        readings: [_w(80, 2), _w(80, 3), _w(80, 4)],
      );
      final p = GoalProgress.bodyWeight(goal: goal, summary: summary);
      expect(p.state, GoalState.atTarget);
      expect(p.statement, 'At target');
      expect(p.remaining, 0);
      expect(p.percent, 100);
    });

    test('passed target when the first value was on the other side', () {
      final goal = _goal(GoalKind.bodyWeight, 80, goalStart);
      final summary = WeightSummary.build(
        period: _p(2, 12),
        readings: [
          _w(85, 2),
          _w(85, 3),
          _w(85, 4),
          _w(78.8, 10),
          _w(78.8, 11),
          _w(78.8, 12),
        ],
      );
      final p = GoalProgress.bodyWeight(goal: goal, summary: summary);
      expect(p.state, GoalState.passedTarget);
      expect(p.direction, GoalDirection.decrease);
      expect(p.remaining, 1.2);
      expect(p.statement, 'Passed target by 1.2 kg');
    });

    test('fewer than 3 readings: not enough data, no remaining value', () {
      final goal = _goal(GoalKind.bodyWeight, 80, goalStart);
      final summary = WeightSummary.build(
        period: _p(2, 8),
        readings: [_w(85, 2), _w(85, 3)],
      );
      final p = GoalProgress.bodyWeight(goal: goal, summary: summary);
      expect(p.state, GoalState.notEnoughData);
      final c = p.current as NotEnoughData<double>;
      expect(c.have, 2);
      expect(c.need, 3);
      expect(p.remaining, isNull);
      expect(p.percent, isNull);
      expect(p.statement, 'Not enough data');
    });
  });

  group('measurement GoalProgress (GOL-004)', () {
    final goalStart = DateTime(2026, 11, 2, 9);
    final waistGoal = _goal(
      GoalKind.measurement,
      85,
      goalStart,
      site: MeasurementSite.waist,
    );

    test(
      'a waist goal of 85.0 is tracked against the latest waist reading',
      () {
        final p = GoalProgress.measurement(
          goal: waistGoal,
          period: _p(2, 12),
          readings: [
            _m(MeasurementSite.waist, 90, 11, 2),
            _m(MeasurementSite.waist, 88, 11, 5),
            _w(70, 6),
          ],
        );
        expect((p.current as MetricValue<double>).value, 88);
        expect(p.remaining, 3.0);
        expect(p.statement, '3.0 cm to go');
        expect(p.percent, 40);
        expect(p.state, GoalState.inProgress);
        expect(p.drillDown.kind, DrillDownKind.measurementEntries);
        expect(p.drillDown.site, MeasurementSite.waist);
        expect(
          (p.current as MetricValue<double>).basis.sources.single,
          contains('2026-11-05'),
        );
      },
    );

    test('the latest reading, not the best one, is the current value', () {
      // 84 was lower than the target on 4 Nov, but 86 is the latest.
      final p = GoalProgress.measurement(
        goal: waistGoal,
        period: _p(2, 12),
        readings: [
          _m(MeasurementSite.waist, 90, 11, 2),
          _m(MeasurementSite.waist, 84, 11, 4),
          _m(MeasurementSite.waist, 86, 11, 9),
        ],
      );
      expect((p.current as MetricValue<double>).value, 86);
      expect(p.remaining, 1.0);
      expect(p.state, GoalState.inProgress);
    });

    test('left and right sites have separate progress', () {
      final left = _goal(
        GoalKind.measurement,
        60,
        goalStart,
        site: MeasurementSite.thighLeft,
      );
      final right = _goal(
        GoalKind.measurement,
        62,
        goalStart,
        site: MeasurementSite.thighRight,
      );
      final readings = [
        _m(MeasurementSite.thighLeft, 58, 11, 3),
        _m(MeasurementSite.thighRight, 59, 11, 3),
      ];
      final l = GoalProgress.measurement(
        goal: left,
        period: _p(2, 12),
        readings: readings,
      );
      final r = GoalProgress.measurement(
        goal: right,
        period: _p(2, 12),
        readings: readings,
      );
      expect((l.current as MetricValue<double>).value, 58);
      expect(l.direction, GoalDirection.increase);
      expect(l.remaining, 2.0);
      expect((r.current as MetricValue<double>).value, 59);
      expect(r.remaining, 3.0);
    });

    test('no reading of the site: not enough data', () {
      final p = GoalProgress.measurement(
        goal: waistGoal,
        period: _p(2, 12),
        readings: [_m(MeasurementSite.hips, 100, 11, 3)],
      );
      expect(p.state, GoalState.notEnoughData);
      expect(p.current, isA<NotEnoughData<double>>());
      expect(p.remaining, isNull);
    });

    test('a goal without a site and readings after the period', () {
      final noSite = _goal(GoalKind.measurement, 85, goalStart);
      expect(
        GoalProgress.measurement(
          goal: noSite,
          period: _p(2, 12),
          readings: const [],
        ).state,
        GoalState.notEnoughData,
      );
      final late = GoalProgress.measurement(
        goal: waistGoal,
        period: _p(2, 12),
        readings: [_m(MeasurementSite.waist, 80, 11, 20)],
      );
      expect(late.state, GoalState.notEnoughData);
    });

    test('a reading before the goal start is the current value, no start', () {
      final p = GoalProgress.measurement(
        goal: waistGoal,
        period: _p(2, 12),
        readings: [_m(MeasurementSite.waist, 90, 10, 20)],
      );
      expect((p.current as MetricValue<double>).value, 90);
      expect(p.startValue, isNull);
      expect(p.percent, isNull);
      expect(p.statement, '5.0 cm to go');
    });
  });
}
