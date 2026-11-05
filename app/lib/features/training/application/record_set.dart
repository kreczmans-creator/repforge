import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/training/training_validation.dart';

/// Use case: record one set in an existing session (TRN-001..007, D06 WP 8
/// acceptance).
///
/// The set is validated against the stored exercise by
/// [validateSetForExercise], so an invalid combination (a weighted set on a
/// timed exercise, 0 or 101 reps, a zero duration, an unlabelled energy value,
/// an exertion out of range...) is rejected here and nothing is stored. This
/// is where `validReps` and `validExertion` are enforced on write. An
/// archived or deleted exercise cannot receive new sets. Set and exercise
/// order within the session are assigned: a new exercise goes after the
/// session's last one, a new set after the exercise's last set.
final class RecordSet {
  const RecordSet({
    required this.exercises,
    required this.sessions,
    required this.newId,
  });

  final ExerciseRepository exercises;
  final WorkoutSessionRepository sessions;
  final IdGenerator newId;

  /// Returns the stored set (normalised: whole-second durations, metres to
  /// 0.1 m).
  Future<Result<SessionSet>> call({
    required String sessionId,
    required String exerciseId,
    required SetData data,
    bool completed = true,
    Exertion? exertion,
    int? restSeconds,
    String? note,
  }) async {
    try {
      final exercise = await exercises.byId(exerciseId);
      if (exercise == null) {
        return const Err(NotFoundError('That exercise no longer exists.'));
      }
      if (exercise.archived) {
        return const Err(
          ValidationError(
            'An archived exercise cannot be used. Restore it first.',
            field: 'exerciseId',
          ),
        );
      }
      final checked = validateSetForExercise(
        exercise,
        data,
        exertion: exertion,
      );
      if (checked case Err(:final error)) return Err(error);
      if (restSeconds != null && (restSeconds < 0 || restSeconds > 3600)) {
        return const Err(
          ValidationError(
            'Rest must be 0 to 3600 seconds.',
            field: 'restSeconds',
          ),
        );
      }
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      final sameExercise = [
        for (final s in session.sets)
          if (s.exerciseId == exerciseId) s,
      ];
      final exerciseOrder = sameExercise.isNotEmpty
          ? sameExercise.first.exerciseOrder
          : (session.sets.isEmpty
                ? 0
                : session.sets
                          .map((s) => s.exerciseOrder)
                          .reduce((a, b) => a > b ? a : b) +
                      1);
      final setOrder = sameExercise.isEmpty
          ? 0
          : sameExercise
                    .map((s) => s.setOrder)
                    .reduce((a, b) => a > b ? a : b) +
                1;
      final trimmedNote = note?.trim();
      final stored = SessionSet(
        id: newId(),
        sessionId: sessionId,
        exerciseId: exerciseId,
        exerciseOrder: exerciseOrder,
        setOrder: setOrder,
        data: (checked as Ok<SetData>).value,
        completed: completed,
        exertion: exertion,
        restSeconds: restSeconds,
        note: trimmedNote == null || trimmedNote.isEmpty ? null : trimmedNote,
      );
      await sessions.addSet(stored);
      return Ok(stored);
    } on Object catch (e) {
      return Err(StorageError('Could not save the set.', cause: e));
    }
  }
}
