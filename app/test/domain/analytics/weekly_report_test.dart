import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/body_analytics.dart';
import 'package:repforge/domain/analytics/goal_progress.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/analytics/nutrition_analytics.dart';
import 'package:repforge/domain/analytics/target_history.dart';
import 'package:repforge/domain/analytics/training_analytics.dart';
import 'package:repforge/domain/analytics/weekly_report.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/training.dart';

import '../../helpers/analytics_fixtures.dart';

final _week = AnalyticsPeriod.thisWeek(DateTime(2026, 11, 4, 12), 1);
const _settings = AppSettings();

Goal get _sessionsGoal => Goal(
  id: 'sg',
  kind: GoalKind.sessionsPerWeek,
  target: 3,
  startDate: DateTime(2026, 10).toUtc(),
  createdAt: DateTime(2026, 10).toUtc(),
  updatedAt: DateTime(2026, 10).toUtc(),
);

WeeklyReport _build({
  List<FoodLogEntry> food = const [],
  List<WorkoutSession> sessions = const [],
  List<Measurement> weights = const [],
  bool withGoal = false,
}) {
  final training = WeekTraining.build(
    period: _week,
    sessions: sessions,
    settings: _settings,
  );
  return WeeklyReport.build(
    period: _week,
    nutrition: NutritionWeek.build(
      period: _week,
      entries: food,
      history: TargetHistory.fromGoals(const []),
      dayStartHour: 0,
    ),
    training: training,
    weight: WeightSummary.build(period: _week, readings: weights),
    sessionsGoal: withGoal
        ? GoalProgress.sessionsPerWeek(goal: _sessionsGoal, week: training)
        : null,
  );
}

void main() {
  group('WeeklyReport (GOL-007)', () {
    test('a full week fills every item with its basis', () {
      final r = _build(
        food: [
          for (final d in [2, 3, 4, 5, 6])
            foodEntry('2026-11-0$d', 2000, protein: 120),
        ],
        sessions: [
          workout(DateTime(2026, 11, 2, 18), [
            weighted(80, 5),
            weighted(80, 4),
          ]),
          workout(DateTime(2026, 11, 4, 18), [weighted(100, 5)]),
        ],
        weights: [
          weightReading(90, 11, 2),
          weightReading(90, 11, 3),
          weightReading(90, 11, 4),
          weightReading(87, 11, 8),
        ],
        withGoal: true,
      );

      final n = (r.nutrition as MetricValue<NutritionSummary>).value;
      expect((n.daysLogged as MetricValue<int>).value, 5);
      expect(n.daysLoggedText, '5 of 7 days logged');
      expect((n.averageEnergyKcal as MetricValue<double>).value, 2000);
      expect((n.averageProteinG as MetricValue<double>).value, 120);

      final t = (r.training as MetricValue<TrainingSummary>).value;
      expect((t.sessionsCompleted as MetricValue<int>).value, 2);
      expect(t.sessionsGoal!.statement, '2 of 3 sessions');
      expect((t.totalVolumeKg as MetricValue<double>).value, 720 + 500);

      final b = (r.body as MetricValue<BodySummary>).value;
      expect(b.readings, 4);
      expect((b.weightChangeKg as MetricValue<double>).value, -0.75);
      expect(b.latestTrendKg, 89.25);
    });

    test('bodyweight-only sessions report reps, not missing volume', () {
      final r = _build(
        sessions: [
          workout(DateTime(2026, 11, 3, 18), [
            const SetData.bodyweight(reps: 12),
            const SetData.timed(duration: Duration(seconds: 45)),
          ], exercise: 'mix'),
        ],
      );
      final t = (r.training as MetricValue<TrainingSummary>).value;
      expect((t.totalVolumeKg as MetricValue<double>).value, 0);
      expect(t.reps, 12);
      expect(t.seconds, 45);
      expect(t.metres, 0);
    });

    test('without input: 0 days logged, training and body not enough data', () {
      final r = _build();
      // Days logged is a known count: "0 of 7 days logged", averages missing.
      final n = (r.nutrition as MetricValue<NutritionSummary>).value;
      expect(n.daysLoggedText, '0 of 7 days logged');
      expect((n.daysLogged as MetricValue<int>).value, 0);
      expect(n.averageEnergyKcal, isA<NotEnoughData<double>>());
      expect(n.averageProteinG, isA<NotEnoughData<double>>());
      expect(r.training, isA<NotEnoughData<TrainingSummary>>());
      expect(r.body, isA<NotEnoughData<BodySummary>>());
    });

    test('sections are independent: only nutrition present', () {
      final r = _build(food: [foodEntry('2026-11-03', 1800)]);
      expect(r.nutrition, isA<MetricValue<NutritionSummary>>());
      expect(r.training, isA<NotEnoughData<TrainingSummary>>());
      expect(r.body, isA<NotEnoughData<BodySummary>>());
    });

    test('weight change needs two trend values; one reading is not zero', () {
      final r = _build(weights: [weightReading(90, 11, 3)]);
      final b = (r.body as MetricValue<BodySummary>).value;
      expect(b.readings, 1);
      expect(b.weightChangeKg, isA<NotEnoughData<double>>());
    });

    test(
      'a week with a goal but no session reads 0 sessions, volume missing',
      () {
        final r = _build(withGoal: true);
        final t = (r.training as MetricValue<TrainingSummary>).value;
        expect((t.sessionsCompleted as MetricValue<int>).value, 0);
        expect(t.sessionsGoal!.statement, '0 of 3 sessions');
        expect(t.totalVolumeKg, isA<NotEnoughData<double>>());
      },
    );

    test('each section carries its own day rule (decision 7b)', () {
      final r = _build();
      expect(r.nutritionDayRule, 'Days run from local midnight');
      expect(r.trainingDayRule, 'Days run from local midnight');
      expect(r.bodyDayRule, calendarDayRule);
    });

    test(
      'nutrition keeps the weakest provenance and the missing-data flag',
      () {
        final r = _build(
          food: [
            foodEntry('2026-11-02', 500),
            foodEntry('2026-11-02', 500, provenance: DataProvenance.estimated),
            foodEntry('2026-11-03', 500, protein: null),
          ],
        );
        final n = (r.nutrition as MetricValue<NutritionSummary>).value;
        expect(n.weakestProvenance, DataProvenance.estimated);
        expect(n.hasMissingData, isTrue);
      },
    );
  });

  test('a body-only week uses the site-specific weight readings', () {
    final r = _build(weights: [reading(MeasurementSite.waist, 90, 11, 3)]);
    expect(r.body, isA<NotEnoughData<BodySummary>>());
  });
}
