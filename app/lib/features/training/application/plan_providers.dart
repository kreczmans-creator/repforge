import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/archive_plan.dart';
import 'package:repforge/features/training/application/schedule_use_cases.dart';
import 'package:repforge/features/training/application/training_providers.dart';

/// Every workout plan, archived ones included (the list filters; names of
/// archived plans must still resolve in splits and the schedule).
final allWorkoutPlansProvider = StreamProvider<List<WorkoutPlan>>(
  (ref) =>
      ref.watch(workoutPlanRepositoryProvider).watchAll(includeArchived: true),
);

/// Plans that are not archived: what can be scheduled and put in a split.
final activeWorkoutPlansProvider = Provider<AsyncValue<List<WorkoutPlan>>>(
  (ref) => ref
      .watch(allWorkoutPlansProvider)
      .whenData(
        (all) => [
          for (final p in all)
            if (!p.archived) p,
        ],
      ),
);

/// One plan by id, archived included; null when it does not exist.
// ignore: specify_nonobvious_property_types, the family type is not exported
final workoutPlanByIdProvider = FutureProvider.autoDispose
    .family<WorkoutPlan?, String>(
      (ref, id) => ref.watch(workoutPlanRepositoryProvider).byId(id),
    );

/// All training splits, by sort order.
final trainingSplitsProvider = StreamProvider<List<TrainingSplit>>(
  (ref) => ref.watch(trainingSplitRepositoryProvider).watchAll(),
);

/// One split by id; null when it does not exist.
// ignore: specify_nonobvious_property_types, the family type is not exported
final trainingSplitByIdProvider = FutureProvider.autoDispose
    .family<TrainingSplit?, String>(
      (ref, id) => ref.watch(trainingSplitRepositoryProvider).byId(id),
    );

/// A date range for the schedule list (dates only, both ends inclusive).
typedef ScheduleRange = ({DateTime from, DateTime to});

/// The scheduled workouts in a range, through [ScheduledWorkoutsInRange].
/// Screens invalidate it after a change.
// ignore: specify_nonobvious_property_types, the family type is not exported
final scheduledRangeProvider = FutureProvider.autoDispose
    .family<List<ScheduledWorkout>, ScheduleRange>((ref, range) async {
      final result = await ref.watch(scheduledWorkoutsInRangeProvider)(
        range.from,
        range.to,
      );
      return switch (result) {
        Ok(:final value) => value,
        Err(:final error) => throw StateError(error.message),
      };
    });

final archivePlanProvider = Provider<ArchivePlan>(
  (ref) => ArchivePlan(
    plans: ref.watch(workoutPlanRepositoryProvider),
    clock: ref.watch(clockProvider),
  ),
);
