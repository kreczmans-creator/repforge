import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/nutrition_analytics.dart';
import 'package:repforge/domain/analytics/target_history.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/features/analytics/application/analytics_guard.dart';

/// Use case: the food diary of a period with the target in effect on each day
/// (NUT-016, NUT-019, GOL-006). Reads only the period's entries.
final class LoadNutritionWeek {
  const LoadNutritionWeek({
    required this.foodLog,
    required this.goals,
    this.clock = const SystemClock(),
  });

  final FoodLogRepository foodLog;
  final GoalRepository goals;

  /// Gives the current diary day, so a week in progress does not count its
  /// future days as not logged.
  final Clock clock;

  Future<Result<NutritionWeek>> call(AnalyticsPeriod period) =>
      guardAnalytics('Could not read the nutrition summary.', () async {
        final entries = await foodLog.forDays(period.fromKey, period.toKey);
        final history = TargetHistory.fromGoals(await goals.history());
        return NutritionWeek.build(
          period: period,
          entries: entries,
          history: history,
          dayStartHour: period.dayStartHour,
          asOf: diaryDay(clock.now(), period.dayStartHour),
        );
      });
}
