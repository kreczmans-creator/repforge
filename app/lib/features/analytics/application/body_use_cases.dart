import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/body_analytics.dart';
import 'package:repforge/domain/analytics/goal_progress.dart';
import 'package:repforge/domain/analytics/training_analytics.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurement_repository.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/weight_trend.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/features/analytics/application/analytics_guard.dart';

/// Weight readings for [period] plus the lookback its first trend points
/// need (`trendWindowDays` - 1 days before the start). Calendar arithmetic.
Future<List<Measurement>> weightReadingsFor(
  MeasurementRepository measurements,
  AnalyticsPeriod period,
) {
  final from = period.from.addDays(-(trendWindowDays - 1));
  return measurements.readingsBetween(
    DateTime(from.year, from.month, from.day),
    period.calendarEndInstantExclusive,
    site: MeasurementSite.weight,
  );
}

/// Use case: weight summary of a period (GOL-003, GOL-007). Reads the
/// period's weight readings plus the trend lookback.
final class LoadWeightSummary {
  const LoadWeightSummary({required this.measurements});

  final MeasurementRepository measurements;

  Future<Result<WeightSummary>> call(AnalyticsPeriod period) => guardAnalytics(
    'Could not read the weight summary.',
    () async => WeightSummary.build(
      period: period,
      readings: await weightReadingsFor(measurements, period),
    ),
  );
}

/// Use case: progress of every active body weight, measurement and
/// sessions-per-week goal (GOL-003..005, GOL-008). Calorie and macro targets
/// are daily targets, not progress goals, and are skipped. Weight and
/// measurement goals are read from their start date to today (calendar
/// dates); the sessions goal is read for the current week.
final class LoadGoalProgress {
  const LoadGoalProgress({
    required this.goals,
    required this.measurements,
    required this.sessions,
    required this.settings,
    required this.clock,
  });

  final GoalRepository goals;
  final MeasurementRepository measurements;
  final WorkoutSessionRepository sessions;
  final SettingsRepository settings;
  final Clock clock;

  Future<Result<List<GoalProgress>>> call() =>
      guardAnalytics('Could not read the goal progress.', () async {
        final now = clock.now();
        final s = await settings.read();
        final today = CalendarDate.fromInstant(now);
        final out = <GoalProgress>[];
        for (final goal in await goals.active()) {
          switch (goal.kind) {
            case GoalKind.bodyWeight:
              final period = _sinceStart(goal, today);
              out.add(
                GoalProgress.bodyWeight(
                  goal: goal,
                  summary: WeightSummary.build(
                    period: period,
                    readings: await weightReadingsFor(measurements, period),
                  ),
                ),
              );
            case GoalKind.measurement:
              final site = goal.site;
              final period = _sinceStart(goal, today);
              final readings = <Measurement>[];
              if (site != null) {
                final latest = await measurements.latest(site);
                final inRange = await measurements.readingsBetween(
                  period.calendarStartInstant,
                  period.calendarEndInstantExclusive,
                  site: site,
                );
                readings
                  ..addAll(inRange)
                  ..addAll(
                    [?latest].where((m) => !inRange.any((r) => r.id == m.id)),
                  );
              }
              out.add(
                GoalProgress.measurement(
                  goal: goal,
                  readings: readings,
                  period: period,
                ),
              );
            case GoalKind.sessionsPerWeek:
              final week = AnalyticsPeriod.thisWeek(
                now,
                s.weekStartDay,
                dayStartHour: s.dayStartHour,
              );
              final list = await sessions.sessionsBetween(
                DateTime(week.from.year, week.from.month, week.from.day - 1),
                DateTime(week.to.year, week.to.month, week.to.day + 2),
              );
              out.add(
                GoalProgress.sessionsPerWeek(
                  goal: goal,
                  week: WeekTraining.build(
                    period: week,
                    sessions: list,
                    settings: s,
                  ),
                ),
              );
            case GoalKind.calories ||
                GoalKind.protein ||
                GoalKind.carbs ||
                GoalKind.fat ||
                GoalKind.fibre:
              break;
          }
        }
        return out;
      });

  /// From the goal's start date to today; a goal that starts in the future
  /// reads as starting today.
  AnalyticsPeriod _sinceStart(Goal goal, CalendarDate today) {
    final start = CalendarDate.fromInstant(goal.startDate);
    return AnalyticsPeriod.custom(start.isAfter(today) ? today : start, today);
  }
}
