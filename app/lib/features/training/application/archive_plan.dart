import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';

/// Use case: archive or restore a workout plan (TRN-013). An archived plan is
/// hidden from the plan list, cannot be scheduled or started, and stays in
/// history and in any split that lists it. Only the flag changes.
final class ArchivePlan {
  const ArchivePlan({required this.plans, required this.clock});

  final WorkoutPlanRepository plans;
  final Clock clock;

  Future<Result<WorkoutPlan>> call(
    String planId, {
    required bool archived,
  }) async {
    try {
      final plan = await plans.byId(planId);
      if (plan == null) {
        return const Err(NotFoundError('That workout no longer exists.'));
      }
      final updated = plan.copyWith(
        archived: archived,
        updatedAt: clock.now().toUtc(),
      );
      await plans.upsert(updated);
      return Ok(updated);
    } on Object catch (e) {
      return Err(StorageError('Could not update the workout.', cause: e));
    }
  }
}
