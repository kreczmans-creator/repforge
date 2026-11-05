import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';

abstract interface class ExerciseRepository {
  /// All non-deleted exercises ordered by name.
  Stream<List<Exercise>> watchAll({bool includeArchived = false});

  /// The library filtered and ordered by [query] (TRN-008..012).
  Stream<List<Exercise>> watchLibrary(ExerciseQuery query);

  /// One-shot form of [watchLibrary].
  Future<List<Exercise>> search(ExerciseQuery query);

  /// A non-deleted exercise (archived ones included), or null.
  Future<Exercise?> byId(String id);

  /// True when a row with [id] exists, deleted or archived included. The
  /// library importer uses it to never re-create what the user removed.
  Future<bool> exists(String id);

  Future<void> upsert(Exercise exercise);

  /// Archives or restores a non-deleted exercise (TD-23: a soft-deleted row
  /// is never touched). Returns false when no such exercise exists.
  Future<bool> archive(String id, {required bool archived});

  /// Soft-deletes a non-deleted exercise. Returns false when none matched.
  /// History that references it stays readable.
  Future<bool> delete(String id);
}

abstract interface class WorkoutPlanRepository {
  Stream<List<WorkoutPlan>> watchAll({bool includeArchived = false});
  Future<WorkoutPlan?> byId(String id);
  Future<void> upsert(WorkoutPlan plan);
  Future<void> delete(String id);
}

/// One performed workout's completed sets for one exercise (TRN-025).
final class ExerciseSessionHistory {
  const ExerciseSessionHistory({
    required this.sessionId,
    required this.sessionName,
    required this.startedAt,
    required this.sets,
  });

  final String sessionId;
  final String sessionName;
  final DateTime startedAt;

  /// Completed sets of the exercise in this session, in performed order.
  final List<SessionSet> sets;
}

abstract interface class WorkoutSessionRepository {
  /// Newest first.
  Stream<List<WorkoutSession>> watchAll({int limit = 100});
  Future<WorkoutSession?> byId(String id);
  Future<void> upsert(WorkoutSession session);
  Future<void> delete(String id);

  /// Adds one set to an existing, non-deleted session without touching its
  /// other sets. Throws if the session does not exist.
  Future<void> addSet(SessionSet set);

  /// All sets ever recorded for an exercise, oldest first (for PR checks).
  Future<List<SessionSet>> setsForExercise(String exerciseId);

  /// True when any set (completed or not) references [exerciseId] in a
  /// non-deleted session.
  Future<bool> hasHistory(String exerciseId);

  /// Sessions in which [exerciseId] has completed sets, newest first, each
  /// with those sets (TRN-025). [limit] and [offset] page the sessions. An
  /// archived or deleted exercise's history stays readable.
  Future<List<ExerciseSessionHistory>> sessionsForExercise(
    String exerciseId, {
    int? limit,
    int offset = 0,
  });

  /// The completed sets of the most recent session that has any for
  /// [exerciseId]; empty when never performed.
  Future<List<SessionSet>> lastPerformance(String exerciseId);
}

abstract interface class TrainingSplitRepository {
  /// Splits ordered by sort order, then name.
  Stream<List<TrainingSplit>> watchAll();
  Future<TrainingSplit?> byId(String id);
  Future<void> upsert(TrainingSplit split);

  /// Soft-deletes a non-deleted split.
  Future<void> delete(String id);
}
