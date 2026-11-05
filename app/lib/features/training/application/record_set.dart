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

/// Use case: record one set in an existing session (TRN-001..007, D06 WP 8
/// acceptance).
///
/// The set is validated against the stored exercise by
/// [validateSetForExercise], so an invalid combination (a weighted set on a
/// timed exercise, 0 or 101 reps, a zero duration, an unlabelled energy value,
/// an exertion out of range...) is rejected here and nothing is stored. This
/// is where `validReps` and `validExertion` are enforced on write. An
/// archived or deleted exercise cannot receive new sets. Set and exercise
/// order within the session are assigned: a set joins the session's entry for
/// its exercise (TRN-017), or creates one after the last entry; a new set
/// goes after the entry's last set. [SetKind] defaults to working (TRN-019).
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
    SetKind kind = SetKind.working,
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
      final extras = validateSetExtras(restSeconds: restSeconds, note: note);
      if (extras case Err(:final error)) return Err(error);
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      final entry = session.exercises
          .where((e) => e.exerciseId == exerciseId)
          .firstOrNull;
      final entrySets = entry == null
          ? const <SessionSet>[]
          : [
              for (final s in session.sets)
                if (s.sessionExerciseId == entry.id) s,
            ];
      final positions = [
        ...session.exercises.map((e) => e.position),
        ...session.sets.map((s) => s.exerciseOrder),
      ];
      final exerciseOrder =
          entry?.position ??
          (positions.isEmpty
              ? 0
              : positions.reduce((a, b) => a > b ? a : b) + 1);
      final setOrder = entrySets.isEmpty
          ? 0
          : entrySets.map((s) => s.setOrder).reduce((a, b) => a > b ? a : b) +
                1;
      final created = entry != null
          ? null
          : SessionExercise(
              id: newId(),
              sessionId: sessionId,
              exerciseId: exerciseId,
              position: exerciseOrder,
            );
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
        note: (extras as Ok<String?>).value,
        kind: kind,
        sessionExerciseId: entry?.id ?? created!.id,
      );
      await sessions.addSet(stored, newEntry: created);
      return Ok(stored);
    } on Object catch (e) {
      return Err(StorageError('Could not save the set.', cause: e));
    }
  }
}
