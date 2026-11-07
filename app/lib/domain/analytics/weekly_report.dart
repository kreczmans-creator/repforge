import 'package:meta/meta.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/body_analytics.dart';
import 'package:repforge/domain/analytics/goal_progress.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/analytics/nutrition_analytics.dart';
import 'package:repforge/domain/analytics/training_analytics.dart';
import 'package:repforge/domain/nutrition/nutrition.dart' show DataProvenance;

/// The nutrition part of the weekly report (GOL-007(1)): days logged and the
/// average energy and protein over the logged days.
@immutable
final class NutritionSummary {
  const NutritionSummary({
    required this.daysLogged,
    required this.daysLoggedText,
    required this.averageEnergyKcal,
    required this.averageProteinG,
    required this.hasMissingData,
    this.weakestProvenance,
  });

  final Metric<int> daysLogged;

  /// "5 of 7 days logged".
  final String daysLoggedText;
  final Metric<double> averageEnergyKcal;
  final Metric<double> averageProteinG;

  /// Whether some entry of the period lacked a nutrient (NUT-021).
  final bool hasMissingData;

  /// Weakest provenance over the period (NUT-019).
  final DataProvenance? weakestProvenance;
}

/// The training part of the weekly report: sessions completed against the
/// sessions-per-week goal, and total volume.
@immutable
final class TrainingSummary {
  const TrainingSummary({
    required this.sessionsCompleted,
    required this.totalVolumeKg,
    this.sessionsGoal,
  });

  final Metric<int> sessionsCompleted;

  /// "2 of 3 sessions" progress when a sessions-per-week goal is set.
  final GoalProgress? sessionsGoal;
  final Metric<double> totalVolumeKg;
}

/// The body part of the weekly report: weight change over the period.
@immutable
final class BodySummary {
  const BodySummary({
    required this.readings,
    required this.weightChangeKg,
    this.latestTrendKg,
  });

  /// Weight readings in the period.
  final int readings;

  /// Last trend value minus first inside the period.
  final Metric<double> weightChangeKg;
  final double? latestTrendKg;
}

/// The weekly summary (GOL-007): nutrition, training and body, each section
/// either present or "not enough data" (never zeros). The sections keep their
/// own day rule (plan decision 7b): nutrition and training use the day-start
/// setting, body uses calendar dates. Descriptive only (GOL-011).
@immutable
final class WeeklyReport {
  const WeeklyReport._({
    required this.period,
    required this.nutrition,
    required this.training,
    required this.body,
    required this.nutritionDayRule,
    required this.trainingDayRule,
    required this.bodyDayRule,
  });

  /// Builds the report from the three analytics of [period]. [sessionsGoal]
  /// is the sessions-per-week progress when that goal is set.
  factory WeeklyReport.build({
    required AnalyticsPeriod period,
    required NutritionWeek nutrition,
    required WeekTraining training,
    required WeightSummary weight,
    GoalProgress? sessionsGoal,
  }) {
    MetricBasis basis(
      int n,
      String source,
      String rule, {
      DataProvenance? provenance,
    }) => MetricBasis(
      period: period,
      sampleCount: n,
      sources: [source],
      dayRule: rule,
      weakestProvenance: provenance,
    );

    final Metric<NutritionSummary> nutritionSection;
    if (nutrition.loggedDays == 0) {
      nutritionSection = NotEnoughData(
        have: 0,
        need: 1,
        reason: 'No day was logged in ${period.label}.',
      );
    } else {
      nutritionSection = MetricValue(
        NutritionSummary(
          daysLogged: MetricValue(
            nutrition.loggedDays,
            basis(
              period.dayCount,
              'food log days',
              nutrition.dayRule,
              provenance: nutrition.weakestProvenanceOfPeriod,
            ),
          ),
          daysLoggedText: nutrition.daysLoggedText,
          averageEnergyKcal: nutrition.averageEnergyKcal,
          averageProteinG: nutrition.averageProteinG,
          hasMissingData: nutrition.hasMissingData,
          weakestProvenance: nutrition.weakestProvenanceOfPeriod,
        ),
        basis(
          nutrition.loggedDays,
          'food log entries',
          nutrition.dayRule,
          provenance: nutrition.weakestProvenanceOfPeriod,
        ),
      );
    }

    final Metric<TrainingSummary> trainingSection;
    final anySession =
        training.sessionsCompleted + training.sessionsInProgress > 0;
    if (!anySession && sessionsGoal == null) {
      trainingSection = NotEnoughData(
        have: 0,
        need: 1,
        reason: 'No workout was recorded in ${period.label}.',
      );
    } else {
      trainingSection = MetricValue(
        TrainingSummary(
          sessionsCompleted: MetricValue(
            training.sessionsCompleted,
            basis(
              training.sessionsCompleted,
              'completed sessions',
              training.dayRule,
            ),
          ),
          sessionsGoal: sessionsGoal,
          totalVolumeKg: training.totalVolumeKg,
        ),
        basis(
          training.sessionsCompleted,
          'completed sessions',
          training.dayRule,
        ),
      );
    }

    final Metric<BodySummary> bodySection;
    if (weight.readingsInWindow == 0) {
      bodySection = NotEnoughData(
        have: 0,
        need: 1,
        reason: 'No weight was recorded in ${period.label}.',
      );
    } else {
      bodySection = MetricValue(
        BodySummary(
          readings: weight.readingsInWindow,
          weightChangeKg: weight.trendChange,
          latestTrendKg: weight.latestTrend?.average,
        ),
        basis(weight.readingsInWindow, 'weight readings', calendarDayRule),
      );
    }

    return WeeklyReport._(
      period: period,
      nutrition: nutritionSection,
      training: trainingSection,
      body: bodySection,
      nutritionDayRule: nutrition.dayRule,
      trainingDayRule: training.dayRule,
      bodyDayRule: calendarDayRule,
    );
  }

  final AnalyticsPeriod period;
  final Metric<NutritionSummary> nutrition;
  final Metric<TrainingSummary> training;
  final Metric<BodySummary> body;

  /// The day boundary of each section, stated beside it.
  final String nutritionDayRule;
  final String trainingDayRule;
  final String bodyDayRule;
}
