import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/training/training.dart';

/// Active goals.
final activeGoalsProvider = StreamProvider<List<Goal>>(
  (ref) => ref.watch(goalRepositoryProvider).watchActive(),
);

/// Daily nutrition targets derived from goals.
final dailyTargetsProvider = Provider<AsyncValue<DailyTargets>>(
  (ref) => ref.watch(activeGoalsProvider).whenData(DailyTargets.fromGoals),
);

/// Ticks once a minute so date-dependent providers roll over at midnight
/// (or the day-start hour) while the app stays open.
final minuteTickProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  return Stream.periodic(const Duration(minutes: 1), (_) => clock.now());
});

/// Today's diary day key, from the injected clock and the day-start setting.
/// Re-evaluated every minute; downstream providers only rebuild when the
/// key actually changes.
final todayKeyProvider = Provider<String>((ref) {
  final clock = ref.watch(clockProvider);
  final now = (ref.watch(minuteTickProvider).value ?? clock.now()).toLocal();
  final dayStart =
      ref.watch(settingsProvider.select((s) => s.value?.dayStartHour)) ?? 0;
  return dayKey(now.subtract(Duration(hours: dayStart)));
});

/// Today's food log entries.
final todayEntriesProvider = StreamProvider<List<FoodLogEntry>>(
  (ref) => ref
      .watch(foodLogRepositoryProvider)
      .watchDay(ref.watch(todayKeyProvider)),
);

/// Intake vs targets for today.
final todaySummaryProvider = Provider<AsyncValue<DailySummary>>((ref) {
  final entries = ref.watch(todayEntriesProvider);
  final targets = ref.watch(dailyTargetsProvider);
  if (entries.hasError) {
    return AsyncError(entries.error!, entries.stackTrace ?? StackTrace.empty);
  }
  if (targets.hasError) {
    return AsyncError(targets.error!, targets.stackTrace ?? StackTrace.empty);
  }
  if (entries.isLoading || targets.isLoading) return const AsyncLoading();
  return AsyncData(
    DailySummary.fromEntries(
      day: ref.watch(todayKeyProvider),
      entries: entries.value!,
      targets: targets.value!,
    ),
  );
});

/// Recent workout sessions, newest first.
final recentSessionsProvider = StreamProvider<List<WorkoutSession>>(
  (ref) => ref.watch(workoutSessionRepositoryProvider).watchAll(limit: 5),
);

/// Active workout plans.
final plansProvider = StreamProvider<List<WorkoutPlan>>(
  (ref) => ref.watch(workoutPlanRepositoryProvider).watchAll(),
);
