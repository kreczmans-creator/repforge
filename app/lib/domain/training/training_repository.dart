import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/personal_records.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
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

  /// True when any plan that is not deleted (archived plans count) lists
  /// [exerciseId].
  Future<bool> usesExercise(String exerciseId);
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
  /// Newest first. Deleted sessions are not listed.
  Stream<List<WorkoutSession>> watchAll({int limit = 100});

  /// The session with its exercise entries and sets. A soft-deleted session
  /// is returned only with [includeDeleted] (restoring it, TRN-024).
  Future<WorkoutSession?> byId(String id, {bool includeDeleted = false});

  /// Non-deleted sessions that started in [from, to), oldest first, with
  /// their sets (volume reports).
  Future<List<WorkoutSession>> sessionsBetween(DateTime from, DateTime to);

  /// Writes the session's own fields only. `session.sets` and
  /// `session.exercises` are ignored: sets and entries are stored through
  /// their own methods after a use case has validated them.
  Future<void> upsert(WorkoutSession session);

  /// Soft-deletes the session (deleted_at); nothing is removed.
  Future<void> delete(String id);

  /// Undoes [delete]. Returns false when the session is not deleted.
  Future<bool> restore(String id);

  /// Adds one set to an existing, non-deleted session without touching its
  /// other sets. The set joins the entry named by `sessionExerciseId`, or,
  /// when it names none, the session's entry for its exercise at its
  /// `exerciseOrder`; when there is none, [newEntry] (or else one derived
  /// from the set) is created in the same transaction, at the set's
  /// `exerciseOrder` when free, otherwise last. The stored set's
  /// `exerciseOrder` mirrors its entry's position. Throws if the session does
  /// not exist.
  Future<void> addSet(SessionSet set, {SessionExercise? newEntry});

  /// Replaces the stored set with the same id (edit, TRN-024). Entry and
  /// session of the set do not change. Returns false when it does not exist.
  Future<bool> updateSet(SessionSet set);

  /// Removes one set. Returns false when it does not exist.
  Future<bool> deleteSet(String setId);

  /// Appends or inserts an entry exactly as given. Throws if the session does
  /// not exist.
  Future<void> addExercise(SessionExercise entry);

  /// Changes an entry's exercise and note (not its position). The sets
  /// of the entry follow the exercise. Returns false when it does not exist.
  Future<bool> updateExercise(SessionExercise entry);

  /// Removes an entry and all its sets. Returns false when it does not exist.
  Future<bool> removeExercise(String entryId);

  /// Stores the order of the session's entries: [entryIds] must be exactly
  /// the session's entries. Positions become 0..n-1 in that order and the
  /// entries' sets' `exerciseOrder` follow, in one transaction.
  Future<void> setExerciseOrder(String sessionId, List<String> entryIds);

  /// All sets ever recorded for an exercise, oldest first (for PR checks).
  Future<List<SessionSet>> setsForExercise(String exerciseId);

  /// Completed sets of [exerciseId] in non-deleted sessions with their
  /// session's start, oldest first (personal records).
  Future<List<PerformedSet>> performedSets(String exerciseId);

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

abstract interface class ScheduledWorkoutRepository {
  /// Scheduled workouts whose current date is in [from, to] (inclusive,
  /// dates only), by date then creation.
  Future<List<ScheduledWorkout>> inRange(DateTime from, DateTime to);

  Stream<List<ScheduledWorkout>> watchRange(DateTime from, DateTime to);

  Future<ScheduledWorkout?> byId(String id);

  /// Every scheduled workout of [planId], any date or status.
  Future<List<ScheduledWorkout>> forPlan(String planId);

  /// Inserts or replaces the row with the same id.
  Future<void> upsert(ScheduledWorkout workout);
}
