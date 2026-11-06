import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/training/training_validation.dart';

/// Validates the optional rest (0-3600 s) and note (trimmed, at most
/// [maxSessionNoteLength] characters; blank becomes null) of a set. Shared
/// by [RecordSet] and `EditSet`.
Result<String?> validateSetExtras({int? restSeconds, String? note}) {
  if (restSeconds != null && (restSeconds < 0 || restSeconds > 3600)) {
    return const Err(
      ValidationError('Rest must be 0 to 3600 seconds.', field: 'restSeconds'),
    );
  }
  final trimmed = note?.trim();
  if (trimmed != null && trimmed.length > maxSessionNoteLength) {
    return const Err(
      ValidationError(
        'The note can be at most $maxSessionNoteLength characters.',
        field: 'note',
      ),
    );
  }
  return Ok(trimmed == null || trimmed.isEmpty ? null : trimmed);
}

/// Use case: record one set against an exercise entry of an existing session
/// (TRN-001..007, TRN-017, D06 WP 8 acceptance).
///
/// The set is recorded against `sessionExerciseId`, an entry of the session,
/// and is validated against that entry's exercise by
/// [validateSetForExercise], so an invalid combination (a weighted set on a
/// timed exercise, 0 or 101 reps, a zero duration, an unlabelled energy value,
/// an exertion out of range...) is rejected here and nothing is stored. This
/// is where `validReps` and `validExertion` are enforced on write. A session
/// may hold the same exercise in several entries; naming the entry is what
/// tells them apart. An archived or deleted exercise cannot receive new sets.
/// The set joins the entry and goes after its last set; [SetKind] defaults to
/// working (TRN-019).
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
    required String sessionExerciseId,
    required SetData data,
    bool completed = true,
    Exertion? exertion,
    int? restSeconds,
    String? note,
    SetKind kind = SetKind.working,
  }) async {
    try {
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      final entry = session.exercises
          .where((e) => e.id == sessionExerciseId)
          .firstOrNull;
      if (entry == null) {
        return const Err(NotFoundError('That exercise is not in the session.'));
      }
      final exercise = await exercises.byId(entry.exerciseId);
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
      final extras = validateSetExtras(restSeconds: restSeconds, note: note);
      if (extras case Err(:final error)) return Err(error);
      final entrySets = [
        for (final s in session.sets)
          if (s.sessionExerciseId == entry.id) s,
      ];
      final setOrder = entrySets.isEmpty
          ? 0
          : entrySets.map((s) => s.setOrder).reduce((a, b) => a > b ? a : b) +
                1;
      final stored = SessionSet(
        id: newId(),
        sessionId: sessionId,
        exerciseId: entry.exerciseId,
        exerciseOrder: entry.position,
        setOrder: setOrder,
        data: (checked as Ok<SetData>).value,
        completed: completed,
        exertion: exertion,
        restSeconds: restSeconds,
        note: (extras as Ok<String?>).value,
        kind: kind,
        sessionExerciseId: entry.id,
      );
      await sessions.addSet(stored);
      return Ok(stored);
    } on Object catch (e) {
      return Err(StorageError('Could not save the set.', cause: e));
    }
  }
}
