import 'package:repforge/domain/training/training.dart';

abstract interface class ExerciseRepository {
  Stream<List<Exercise>> watchAll({bool includeArchived = false});
  Future<Exercise?> byId(String id);
  Future<void> upsert(Exercise exercise);
  Future<void> archive(String id, {required bool archived});
}

abstract interface class WorkoutPlanRepository {
  Stream<List<WorkoutPlan>> watchAll({bool includeArchived = false});
  Future<WorkoutPlan?> byId(String id);
  Future<void> upsert(WorkoutPlan plan);
  Future<void> delete(String id);
}

abstract interface class WorkoutSessionRepository {
  /// Newest first.
  Stream<List<WorkoutSession>> watchAll({int limit = 100});
  Future<WorkoutSession?> byId(String id);
  Future<void> upsert(WorkoutSession session);
  Future<void> delete(String id);

  /// All sets ever recorded for an exercise, oldest first (for PR checks).
  Future<List<SessionSet>> setsForExercise(String exerciseId);
}
