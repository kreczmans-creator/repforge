import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/analytics/nutrition_analytics.dart';
import 'package:repforge/domain/analytics/period_comparison.dart';
import 'package:repforge/domain/analytics/target_history.dart';
import 'package:repforge/domain/analytics/training_analytics.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/training.dart';

import '../../helpers/analytics_fixtures.dart';

final _now = DateTime(2026, 11, 11, 12);
final _this = AnalyticsPeriod.thisWeek(_now, 1); // 9 - 15 Nov
final _last = AnalyticsPeriod.lastWeek(_now, 1); // 2 - 8 Nov

PeriodComparison _compare({
  List<FoodLogEntry> food = const [],
  List<WorkoutSession> sessions = const [],
  List<Measurement> weights = const [],
  AnalyticsPeriod? earlier,
  AnalyticsPeriod? later,
}) {
  final a = earlier ?? _last;
  final b = later ?? _this;
  NutritionWeek n(AnalyticsPeriod p) => NutritionWeek.build(
    period: p,
    entries: food,
    history: TargetHistory.fromGoals(const []),
    dayStartHour: 0,
  );
  WeekTraining t(AnalyticsPeriod p) => WeekTraining.build(
    period: p,
    sessions: sessions,
    settings: const AppSettings(),
  );
  return PeriodComparison.build(
    earlierNutrition: n(a),
    laterNutrition: n(b),
    earlierTraining: t(a),
    laterTraining: t(b),
    weightReadings: weights,
  );
}

void main() {
  group('PeriodComparison (GOL-009)', () {
    final food = [
      foodEntry('2026-11-03', 2000, protein: 100),
      foodEntry('2026-11-04', 2200, protein: 120),
      foodEntry('2026-11-10', 2400, protein: 140),
    ];
    final sessions = [
      workout(DateTime(2026, 11, 3, 18), [weighted(80, 5)]),
      workout(DateTime(2026, 11, 10, 18), [weighted(80, 5), weighted(80, 5)]),
    ];
    final weights = [
      weightReading(90, 11, 3),
      weightReading(89, 11, 10),
      weightReading(88, 11, 11),
    ];

    test('this week against last week for all four measures', () {
      final c = _compare(food: food, sessions: sessions, weights: weights);
      expect(c.earlier, _last);
      expect(c.later, _this);

      final energy = c.of(ComparisonMeasure.energy);
      expect((energy.earlier as MetricValue<double>).value, 2100);
      expect((energy.later as MetricValue<double>).value, 2400);
      expect(energy.difference, 300);
      expect(energy.percent, 14.3);

      final protein = c.of(ComparisonMeasure.protein);
      expect(protein.difference, 140 - 110);

      final volume = c.of(ComparisonMeasure.volume);
      expect(volume.difference, 800 - 400);
      expect(volume.percent, 100);

      final weight = c.of(ComparisonMeasure.weight);
      expect((weight.earlier as MetricValue<double>).value, 90);
      expect((weight.later as MetricValue<double>).value, 88.5);
      expect(weight.difference, -1.5);
      expect(weight.isAvailable, isTrue);
      expect(c.measures.map((m) => m.measure), ComparisonMeasure.values);
    });

    test('a period with no data is "not available", never a zero', () {
      final c = _compare(
        food: food.take(2).toList(),
        sessions: sessions.take(1).toList(),
        weights: weights.take(1).toList(),
      );
      for (final m in c.measures) {
        expect(m.isAvailable, isFalse, reason: m.measure.name);
        expect(m.difference, isNull);
        expect(m.percent, isNull);
        expect(m.unavailableReason, contains('later period'));
        expect(m.later, isA<NotEnoughData<double>>());
      }
      expect(notAvailableText, 'not available');
    });

    test('an empty earlier period names the earlier period in the reason', () {
      final c = _compare(food: [food.last]);
      final e = c.of(ComparisonMeasure.energy);
      expect(e.isAvailable, isFalse);
      expect(e.unavailableReason, contains('earlier period'));
      expect(e.unavailableReason, isNot(contains('later period')));
      expect((e.later as MetricValue<double>).value, 2400);
    });

    test('both periods empty: every measure is unavailable', () {
      final c = _compare();
      expect(c.measures.every((m) => !m.isAvailable), isTrue);
      expect(
        c.of(ComparisonMeasure.volume).unavailableReason,
        allOf(contains('earlier period'), contains('later period')),
      );
    });

    test('this month against last month', () {
      final c = _compare(
        food: [foodEntry('2026-10-05', 2000), foodEntry('2026-11-05', 2500)],
        earlier: AnalyticsPeriod.lastMonth(_now),
        later: AnalyticsPeriod.thisMonth(_now),
      );
      expect(c.later.label, 'November 2026');
      expect(c.of(ComparisonMeasure.energy).difference, 500);
    });

    test('a difference of zero is a real figure, not unavailable', () {
      final c = _compare(
        food: [foodEntry('2026-11-03', 2000), foodEntry('2026-11-10', 2000)],
      );
      final e = c.of(ComparisonMeasure.energy);
      expect(e.isAvailable, isTrue);
      expect(e.difference, 0);
    });

    test('a period in progress is marked partial', () {
      final done = _compare();
      expect(done.laterIsPartial, isFalse);
      expect(done.partialNote, isNull);
      final c = PeriodComparison.build(
        earlierNutrition: NutritionWeek.build(
          period: _last,
          entries: const [],
          history: TargetHistory.fromGoals(const []),
          dayStartHour: 0,
        ),
        laterNutrition: NutritionWeek.build(
          period: _this,
          entries: const [],
          history: TargetHistory.fromGoals(const []),
          dayStartHour: 0,
        ),
        earlierTraining: WeekTraining.build(
          period: _last,
          sessions: const [],
          settings: const AppSettings(),
        ),
        laterTraining: WeekTraining.build(
          period: _this,
          sessions: const [],
          settings: const AppSettings(),
        ),
        weightReadings: const [],
        asOf: CalendarDate(2026, 11, 11),
      );
      expect(c.laterElapsedDays, 3);
      expect(c.laterIsPartial, isTrue);
      expect(c.partialNote, 'Week of 2026-11-09 so far: 3 of 7 days');
      expect(PeriodComparison.weightBasisNote, contains('raw readings'));
    });
  });
}
