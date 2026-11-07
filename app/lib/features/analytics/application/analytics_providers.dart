import 'dart:async';

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
import 'package:repforge/domain/settings/settings.dart';
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

/// Counts the (debounced) writes to any table the analytics read. Every
/// analytics provider watches it, so an edit
/// of any row, an old one or a single set included, recomputes the figures.
class AnalyticsRevision extends Notifier<int> {
  Timer? _debounce;

  @override
  int build() {
    // Debounced by 300 ms: a burst of writes (a saved session, an import)
    // recomputes the figures once.
    final sub = ref.watch(analyticsTableUpdatesProvider).listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 300), () {
        state = state + 1;
      });
    });
    ref.onDispose(() {
      _debounce?.cancel();
      unawaited(sub.cancel());
    });
    return 0;
  }
}

final analyticsRevisionProvider = NotifierProvider<AnalyticsRevision, int>(
  AnalyticsRevision.new,
);

/// Re-runs the analytics on any write to the data they read.
void _refreshOn(Ref ref) {
  ref.watch(analyticsRevisionProvider);
}

/// The periods the screens open on.
enum PeriodChoice { thisWeek, lastWeek, thisMonth, lastMonth }

/// The period for [choice] at [now], with the week start and day-start hour
/// of [settings]: the one place those two settings become a period.
AnalyticsPeriod periodFor(
  PeriodChoice choice,
  DateTime now,
  AppSettings settings,
) => switch (choice) {
  PeriodChoice.thisWeek => AnalyticsPeriod.thisWeek(
    now,
    settings.weekStartDay,
    dayStartHour: settings.dayStartHour,
  ),
  PeriodChoice.lastWeek => AnalyticsPeriod.lastWeek(
    now,
    settings.weekStartDay,
    dayStartHour: settings.dayStartHour,
  ),
  PeriodChoice.thisMonth => AnalyticsPeriod.thisMonth(
    now,
    dayStartHour: settings.dayStartHour,
  ),
  PeriodChoice.lastMonth => AnalyticsPeriod.lastMonth(
    now,
    dayStartHour: settings.dayStartHour,
  ),
};

/// The current week or month from the saved settings and the clock. It
/// rolls over with the diary day (`todayKeyProvider`) and follows a change of
/// week start or day start.
// ignore: specify_nonobvious_property_types, the family type is not exported
final currentPeriodProvider = Provider.family<AnalyticsPeriod, PeriodChoice>((
  ref,
  choice,
) {
  ref.watch(todayKeyProvider);
  final settings =
      ref.watch(settingsProvider.select((s) => s.value)) ?? const AppSettings();
  return periodFor(choice, ref.watch(clockProvider).now(), settings);
});

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
    clock: ref.watch(clockProvider),
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
    clock: ref.watch(clockProvider),
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
  _refreshOn(ref);
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
