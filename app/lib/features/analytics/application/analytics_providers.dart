import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/body_analytics.dart';
import 'package:repforge/domain/analytics/goal_progress.dart';
import 'package:repforge/domain/analytics/nutrition_analytics.dart';
import 'package:repforge/domain/analytics/period_comparison.dart';
import 'package:repforge/domain/analytics/recomposition.dart';
import 'package:repforge/domain/analytics/target_history.dart';
import 'package:repforge/domain/analytics/training_analytics.dart';
import 'package:repforge/domain/analytics/weekly_report.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/analytics/application/body_use_cases.dart';
import 'package:repforge/features/analytics/application/nutrition_use_cases.dart';
import 'package:repforge/features/analytics/application/report_use_cases.dart';
import 'package:repforge/features/analytics/application/target_history_use_cases.dart';
import 'package:repforge/features/analytics/application/training_use_cases.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';

/// A failed analytics load, carried by the `AsyncError` of the providers
/// below. The screen maps [error] to user text in one place.
final class AnalyticsLoadException implements Exception {
  const AnalyticsLoadException(this.error);

  final AppError error;

  @override
  String toString() => 'AnalyticsLoadException(${error.message})';
}

Future<T> _load<T>(Future<Result<T>> result) async => switch (await result) {
  Ok(:final value) => value,
  Err(:final error) => throw AnalyticsLoadException(error),
};

/// A failed analytics load is a stored-data error that a retry would repeat;
/// Riverpod's automatic retry is switched off so the error reaches the screen.
Duration? _noRetry(int retryCount, Object error) => null;

/// The earlier and later period of a comparison, as a family key.
typedef PeriodPair = ({AnalyticsPeriod later, AnalyticsPeriod earlier});

/// The chosen period and exercise of the recomposition view, as a family key.
typedef RecompositionKey = ({AnalyticsPeriod period, String? exerciseId});

/// The newest weight or measurement. Analytics providers watch it so a new
/// reading recomputes them; edits of older rows need an explicit
/// `ref.invalidate`.
final latestMeasurementProvider = StreamProvider<List<Measurement>>(
  (ref) => ref.watch(measurementRepositoryProvider).watchAll(limit: 1),
);

/// Re-runs the analytics when settings, goals, today's entries, the newest
/// session or the newest measurement change.
void _refreshOn(Ref ref) {
  ref
    ..watch(settingsProvider)
    ..watch(activeGoalsProvider)
    ..watch(todayEntriesProvider)
    ..watch(recentSessionsProvider)
    ..watch(latestMeasurementProvider);
}

/// Resolves exercise names for the analytics, including archived exercises.
/// Swap this one provider when the exercise port changes (WP 8 stage 3d).
final exerciseNameLookupProvider = Provider<ExerciseNameLookup>((ref) {
  final exercises = ref.watch(exerciseRepositoryProvider);
  return (id) async => (await exercises.byId(id))?.name;
});

final loadTargetHistoryProvider = Provider<LoadTargetHistory>(
  (ref) => LoadTargetHistory(goals: ref.watch(goalRepositoryProvider)),
);

final loadNutritionWeekProvider = Provider<LoadNutritionWeek>(
  (ref) => LoadNutritionWeek(
    foodLog: ref.watch(foodLogRepositoryProvider),
    goals: ref.watch(goalRepositoryProvider),
  ),
);

final loadWeekTrainingProvider = Provider<LoadWeekTraining>(
  (ref) => LoadWeekTraining(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    exerciseName: ref.watch(exerciseNameLookupProvider),
  ),
);

final loadWeightSummaryProvider = Provider<LoadWeightSummary>(
  (ref) =>
      LoadWeightSummary(measurements: ref.watch(measurementRepositoryProvider)),
);

final loadGoalProgressProvider = Provider<LoadGoalProgress>(
  (ref) => LoadGoalProgress(
    goals: ref.watch(goalRepositoryProvider),
    measurements: ref.watch(measurementRepositoryProvider),
    sessions: ref.watch(workoutSessionRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);

final loadExerciseProgressProvider = Provider<LoadExerciseProgress>(
  (ref) => LoadExerciseProgress(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    exerciseName: ref.watch(exerciseNameLookupProvider),
  ),
);

final loadWeeklyReportProvider = Provider<LoadWeeklyReport>(
  (ref) => LoadWeeklyReport(
    nutrition: ref.watch(loadNutritionWeekProvider),
    training: ref.watch(loadWeekTrainingProvider),
    weight: ref.watch(loadWeightSummaryProvider),
    goals: ref.watch(goalRepositoryProvider),
  ),
);

final loadPeriodComparisonProvider = Provider<LoadPeriodComparison>(
  (ref) => LoadPeriodComparison(
    nutrition: ref.watch(loadNutritionWeekProvider),
    training: ref.watch(loadWeekTrainingProvider),
    measurements: ref.watch(measurementRepositoryProvider),
  ),
);

final loadRecompositionSeriesProvider = Provider<LoadRecompositionSeries>(
  (ref) => LoadRecompositionSeries(
    measurements: ref.watch(measurementRepositoryProvider),
    sessions: ref.watch(workoutSessionRepositoryProvider),
  ),
);

/// The target history, including inactive goals (GOL-006(2)).
final targetHistoryProvider = FutureProvider<TargetHistory>((ref) {
  ref.watch(activeGoalsProvider);
  return _load(ref.watch(loadTargetHistoryProvider)());
}, retry: _noRetry);

/// Progress of every active goal (GOL-008).
final goalProgressProvider = FutureProvider<List<GoalProgress>>((ref) {
  _refreshOn(ref);
  return _load(ref.watch(loadGoalProgressProvider)());
}, retry: _noRetry);

/// The food diary of a period.
// ignore: specify_nonobvious_property_types, the family type is not exported
final nutritionWeekProvider = FutureProvider.autoDispose
    .family<NutritionWeek, AnalyticsPeriod>((ref, period) {
      _refreshOn(ref);
      return _load(ref.watch(loadNutritionWeekProvider)(period));
    }, retry: _noRetry);

/// Training of a period with names and record events.
// ignore: specify_nonobvious_property_types, the family type is not exported
final weekTrainingProvider = FutureProvider.autoDispose
    .family<WeekTrainingView, AnalyticsPeriod>((ref, period) {
      _refreshOn(ref);
      return _load(ref.watch(loadWeekTrainingProvider)(period));
    }, retry: _noRetry);

/// Weight summary of a period.
// ignore: specify_nonobvious_property_types, the family type is not exported
final weightSummaryProvider = FutureProvider.autoDispose
    .family<WeightSummary, AnalyticsPeriod>((ref, period) {
      _refreshOn(ref);
      return _load(ref.watch(loadWeightSummaryProvider)(period));
    }, retry: _noRetry);

/// The weekly (or monthly) summary of a period.
// ignore: specify_nonobvious_property_types, the family type is not exported
final weeklyReportProvider = FutureProvider.autoDispose
    .family<WeeklyReport, AnalyticsPeriod>((ref, period) {
      _refreshOn(ref);
      return _load(ref.watch(loadWeeklyReportProvider)(period));
    }, retry: _noRetry);

/// A period against an earlier one.
// ignore: specify_nonobvious_property_types, the family type is not exported
final periodComparisonProvider = FutureProvider.autoDispose
    .family<PeriodComparison, PeriodPair>((ref, pair) {
      _refreshOn(ref);
      return _load(
        ref.watch(loadPeriodComparisonProvider)(
          later: pair.later,
          earlier: pair.earlier,
        ),
      );
    }, retry: _noRetry);

/// Progress of one exercise by exercise id.
// ignore: specify_nonobvious_property_types, the family type is not exported
final exerciseProgressProvider = FutureProvider.autoDispose
    .family<ExerciseProgressView, String>((ref, id) {
      _refreshOn(ref);
      return _load(ref.watch(loadExerciseProgressProvider)(id));
    }, retry: _noRetry);

/// Weight trend, waist and strength on one date range.
// ignore: specify_nonobvious_property_types, the family type is not exported
final recompositionSeriesProvider = FutureProvider.autoDispose
    .family<RecompositionSeries, RecompositionKey>((ref, key) {
      _refreshOn(ref);
      return _load(
        ref.watch(loadRecompositionSeriesProvider)(
          period: key.period,
          exerciseId: key.exerciseId,
        ),
      );
    }, retry: _noRetry);
