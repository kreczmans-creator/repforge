import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/core/transactor.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/training/training_validation.dart';
import 'package:repforge/features/training/application/record_set.dart';

const _storageMessage = 'Could not save the session.';

/// An exercise left out of a session that was started from a plan or a past
/// session, with the reason. Decision (WP 9): an archived or deleted exercise
/// is skipped with this warning and the session still starts; the plan or
/// past session is not changed.
class StartWarning {
  const StartWarning({
    required this.exerciseId,
    required this.reason,
    this.exerciseName,
  });

  final String exerciseId;
  final String? exerciseName;
  final StartSkipReason reason;
}

enum StartSkipReason { archived, missing }

/// What the session screen pre-fills for one exercise (TRN-016(1)): the
/// plan's targets and the previous performance. Nothing here is stored as a
/// set; a set exists only once it is confirmed through `RecordSet`.
class ExercisePrefill {
  const ExercisePrefill({
    required this.sessionExerciseId,
    required this.exerciseId,
    required this.previous,
    this.targetSets,
    this.repsMin,
    this.repsMax,
    this.targetLoadKg,
    this.targetDuration,
    this.targetMetres,
    this.restSeconds,
  });

  final String sessionExerciseId;
  final String exerciseId;
  final int? targetSets;
  final int? repsMin;
  final int? repsMax;
  final double? targetLoadKg;
  final Duration? targetDuration;
  final double? targetMetres;
  final int? restSeconds;

  /// Completed sets of the most recent earlier session with this exercise, in
  /// performed order (warm-ups included, flagged by their kind); empty when
  /// never performed.
  final List<SessionSet> previous;
}

/// A started session with its pre-fill and the exercises that were skipped.
class StartedSession {
  const StartedSession({
    required this.session,
    required this.prefill,
    required this.warnings,
  });

  final WorkoutSession session;
  final List<ExercisePrefill> prefill;
  final List<StartWarning> warnings;
}

String _sessionName(String? name, String fallback) {
  final trimmed = name?.trim();
  return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
}

Err<T>? _badName<T>(String name) => name.length > maxTrainingNameLength
    ? Err<T>(
        const ValidationError(
          'The name can be at most $maxTrainingNameLength characters.',
          field: 'name',
        ),
      )
    : null;

/// Use case: start an empty session (TRN-016(2)); exercises are added during
/// the workout.
final class StartEmptySession {
  const StartEmptySession({
    required this.sessions,
    required this.clock,
    required this.newId,
  });

  final WorkoutSessionRepository sessions;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<WorkoutSession>> call({String? name}) async {
    final title = _sessionName(name, 'Workout');
    if (_badName<WorkoutSession>(title) case final e?) return e;
    try {
      final now = clock.now().toUtc();
      final session = WorkoutSession(
        id: newId(),
        name: title,
        startedAt: now,
        createdAt: now,
        updatedAt: now,
      );
      await sessions.upsert(session);
      return Ok(session);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

/// Shared by the two "start from" use cases: creates the session with an
/// entry for each usable exercise and builds the pre-fill.
Future<StartedSession> _startWith({
  required WorkoutSessionRepository sessions,
  required ExerciseRepository exercises,
  required IdGenerator newId,
  required DateTime now,
  required String name,
  required String? planId,
  required List<({String exerciseId, PlanExercise? target})> wanted,
}) async {
  final session = WorkoutSession(
    id: newId(),
    name: name,
    planId: planId,
    startedAt: now,
    createdAt: now,
    updatedAt: now,
  );
  await sessions.upsert(session);
  final entries = <SessionExercise>[];
  final prefill = <ExercisePrefill>[];
  final warnings = <StartWarning>[];
  for (final w in wanted) {
    final exercise = await exercises.byId(w.exerciseId);
    if (exercise == null || exercise.archived) {
      warnings.add(
        StartWarning(
          exerciseId: w.exerciseId,
          exerciseName: exercise?.name,
          reason: exercise == null
              ? StartSkipReason.missing
              : StartSkipReason.archived,
        ),
      );
      continue;
    }
    if (entries.any((e) => e.exerciseId == w.exerciseId)) continue;
    final entry = SessionExercise(
      id: newId(),
      sessionId: session.id,
      exerciseId: w.exerciseId,
      position: entries.length,
    );
    await sessions.addExercise(entry);
    entries.add(entry);
    final t = w.target;
    prefill.add(
      ExercisePrefill(
        sessionExerciseId: entry.id,
        exerciseId: w.exerciseId,
        previous: await sessions.lastPerformance(w.exerciseId),
        targetSets: t?.targetSets,
        repsMin: t?.repsMin,
        repsMax: t?.repsMax,
        targetLoadKg: t?.targetLoad?.value,
        targetDuration: t?.targetDuration,
        targetMetres: t?.targetMetres,
        restSeconds: t?.restSeconds,
      ),
    );
  }
  return StartedSession(
    session: session.copyWith(exercises: entries),
    prefill: prefill,
    warnings: warnings,
  );
}

/// Use case: start a session from a workout plan (TRN-016(1)).
///
/// The session gets one entry per plan exercise in plan order and the plan's
/// name and id. The pre-fill pairs each plan target with the previous
/// performance (`lastPerformance`) of that exercise; it is returned as data
/// and nothing is stored as a set. An archived or deleted exercise is skipped
/// with a [StartWarning]. An archived or deleted plan is refused. With
/// `scheduledWorkoutId` the scheduled workout (planned, for this plan) is
/// marked done and linked to the new session in the same transaction.
final class StartSessionFromPlan {
  const StartSessionFromPlan({
    required this.plans,
    required this.sessions,
    required this.exercises,
    required this.scheduled,
    required this.transactor,
    required this.clock,
    required this.newId,
  });

  final WorkoutPlanRepository plans;
  final WorkoutSessionRepository sessions;
  final ExerciseRepository exercises;
  final ScheduledWorkoutRepository scheduled;
  final Transactor transactor;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<StartedSession>> call({
    required String planId,
    String? scheduledWorkoutId,
  }) async {
    try {
      final plan = await plans.byId(planId);
      if (plan == null) {
        return const Err(NotFoundError('That workout no longer exists.'));
      }
      if (plan.archived) {
        return const Err(
          ValidationError(
            'That workout is archived. Restore it first.',
            field: 'planId',
          ),
        );
      }
      ScheduledWorkout? occurrence;
      if (scheduledWorkoutId != null) {
        occurrence = await scheduled.byId(scheduledWorkoutId);
        if (occurrence == null) {
          return const Err(
            NotFoundError('That scheduled workout no longer exists.'),
          );
        }
        if (occurrence.planId != planId ||
            occurrence.status != ScheduleStatus.planned) {
          return const Err(
            ValidationError(
              'That scheduled workout is not a planned one for this workout.',
              field: 'scheduledWorkoutId',
            ),
          );
        }
      }
      final now = clock.now().toUtc();
      final ordered = [...plan.exercises]
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final started = await transactor.run(() async {
        final s = await _startWith(
          sessions: sessions,
          exercises: exercises,
          newId: newId,
          now: now,
          name: plan.name,
          planId: plan.id,
          wanted: [
            for (final e in ordered) (exerciseId: e.exerciseId, target: e),
          ],
        );
        if (occurrence != null) {
          await scheduled.upsert(
            occurrence.copyWith(
              status: ScheduleStatus.done,
              sessionId: s.session.id,
              updatedAt: now,
            ),
          );
        }
        return s;
      });
      return Ok(started);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

/// Use case: start a session from a past one (TRN-016): the same exercises in
/// the same order, no sets and no notes. The pre-fill carries each exercise's
/// previous performance; plan targets are not known (the plan, if any, is
/// kept as the session's plan id). Archived or deleted exercises are skipped
/// with a [StartWarning].
final class StartSessionFromPast {
  const StartSessionFromPast({
    required this.sessions,
    required this.exercises,
    required this.transactor,
    required this.clock,
    required this.newId,
  });

  final WorkoutSessionRepository sessions;
  final ExerciseRepository exercises;
  final Transactor transactor;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<StartedSession>> call({required String pastSessionId}) async {
    try {
      final past = await sessions.byId(pastSessionId);
      if (past == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      final ordered = [...past.exercises]
        ..sort((a, b) => a.position.compareTo(b.position));
      final now = clock.now().toUtc();
      final started = await transactor.run(
        () => _startWith(
          sessions: sessions,
          exercises: exercises,
          newId: newId,
          now: now,
          name: past.name,
          planId: past.planId,
          wanted: [
            for (final e in ordered) (exerciseId: e.exerciseId, target: null),
          ],
        ),
      );
      return Ok(started);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

/// Use case: finish a session (sets `endedAt` to now, never before the
/// start). A session that already ended is refused; edit its times with
/// [EditSessionDetails].
final class FinishSession {
  const FinishSession({required this.sessions, required this.clock});

  final WorkoutSessionRepository sessions;
  final Clock clock;

  Future<Result<WorkoutSession>> call(String sessionId) async {
    try {
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      if (session.endedAt != null) {
        return const Err(
          ValidationError(
            'That session is already finished.',
            field: 'endedAt',
          ),
        );
      }
      final now = clock.now().toUtc();
      final ended = now.isBefore(session.startedAt) ? session.startedAt : now;
      final updated = session.copyWith(endedAt: ended, updatedAt: now);
      await sessions.upsert(updated);
      return Ok(updated);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

/// Use case: edit a session's name and times (TRN-024). The end, when given,
/// is not before the start; a null end means in progress.
final class EditSessionDetails {
  const EditSessionDetails({required this.sessions, required this.clock});

  final WorkoutSessionRepository sessions;
  final Clock clock;

  Future<Result<WorkoutSession>> call({
    required String sessionId,
    required String name,
    required DateTime startedAt,
    DateTime? endedAt,
  }) async {
    final title = name.trim();
    if (title.isEmpty) {
      return const Err(ValidationError('Enter a name.', field: 'name'));
    }
    if (_badName<WorkoutSession>(title) case final e?) return e;
    if (endedAt != null && endedAt.isBefore(startedAt)) {
      return const Err(
        ValidationError(
          'A session cannot end before it starts.',
          field: 'endedAt',
        ),
      );
    }
    try {
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      final updated = session.copyWith(
        name: title,
        startedAt: startedAt.toUtc(),
        endedAt: endedAt?.toUtc(),
        updatedAt: clock.now().toUtc(),
      );
      await sessions.upsert(updated);
      return Ok(updated);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

String? _cleanNote(String? note) {
  final t = note?.trim();
  return t == null || t.isEmpty ? null : t;
}

Err<T>? _noteTooLong<T>(String? note) =>
    note != null && note.length > maxSessionNoteLength
    ? Err<T>(
        const ValidationError(
          'The note can be at most $maxSessionNoteLength characters.',
          field: 'note',
        ),
      )
    : null;

/// Use case: set or clear the session note (TRN-023). Trimmed; at most
/// [maxSessionNoteLength] characters; blank clears it.
final class SetSessionNote {
  const SetSessionNote({required this.sessions, required this.clock});

  final WorkoutSessionRepository sessions;
  final Clock clock;

  Future<Result<WorkoutSession>> call({
    required String sessionId,
    required String note,
  }) async {
    final cleaned = _cleanNote(note);
    if (_noteTooLong<WorkoutSession>(cleaned) case final e?) return e;
    try {
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      final updated = session.copyWith(
        notes: cleaned ?? '',
        updatedAt: clock.now().toUtc(),
      );
      await sessions.upsert(updated);
      return Ok(updated);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

SessionExercise? _entry(WorkoutSession s, String entryId) =>
    s.exercises.where((e) => e.id == entryId).firstOrNull;

int _nextPosition(WorkoutSession s) => s.exercises.isEmpty
    ? 0
    : s.exercises.map((e) => e.position).reduce((a, b) => a > b ? a : b) + 1;

const _noEntry = NotFoundError('That exercise is not in the session.');

/// Use case: set or clear the note of one exercise in a session (TRN-023).
final class SetSessionExerciseNote {
  const SetSessionExerciseNote({required this.sessions});

  final WorkoutSessionRepository sessions;

  Future<Result<SessionExercise>> call({
    required String sessionId,
    required String sessionExerciseId,
    required String note,
  }) async {
    final cleaned = _cleanNote(note);
    if (_noteTooLong<SessionExercise>(cleaned) case final e?) return e;
    try {
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      final entry = _entry(session, sessionExerciseId);
      if (entry == null) return const Err(_noEntry);
      final updated = SessionExercise(
        id: entry.id,
        sessionId: entry.sessionId,
        exerciseId: entry.exerciseId,
        position: entry.position,
        note: cleaned,
      );
      await sessions.updateExercise(updated);
      return Ok(updated);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

/// Use case: add an exercise to a session, last in order, before any set
/// exists (TRN-017). The exercise must exist, not be archived and not already
/// be in the session (a session holds an exercise once; to do more of it,
/// add sets to its entry).
final class AddSessionExercise {
  const AddSessionExercise({
    required this.sessions,
    required this.exercises,
    required this.newId,
  });

  final WorkoutSessionRepository sessions;
  final ExerciseRepository exercises;
  final IdGenerator newId;

  Future<Result<SessionExercise>> call({
    required String sessionId,
    required String exerciseId,
  }) async {
    try {
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      final problem = await _usable(exercises, session, exerciseId);
      if (problem != null) return Err(problem);
      final entry = SessionExercise(
        id: newId(),
        sessionId: sessionId,
        exerciseId: exerciseId,
        position: _nextPosition(session),
      );
      await sessions.addExercise(entry);
      return Ok(entry);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

Future<AppError?> _usable(
  ExerciseRepository exercises,
  WorkoutSession session,
  String exerciseId,
) async {
  final exercise = await exercises.byId(exerciseId);
  if (exercise == null) {
    return const NotFoundError('That exercise no longer exists.');
  }
  if (exercise.archived) {
    return const ValidationError(
      'An archived exercise cannot be used. Restore it first.',
      field: 'exerciseId',
    );
  }
  if (session.exercises.any((e) => e.exerciseId == exerciseId)) {
    return const ValidationError(
      'That exercise is already in the session.',
      field: 'exerciseId',
    );
  }
  return null;
}

/// Use case: remove an exercise from a session together with all its sets
/// (TRN-017). Destructive: the caller confirms first when the entry has sets
/// (`session.sets` with that `sessionExerciseId`). Remaining entries are
/// renumbered 0..n-1 keeping their order. Returns the number of sets removed.
final class RemoveSessionExercise {
  const RemoveSessionExercise({
    required this.sessions,
    required this.transactor,
  });

  final WorkoutSessionRepository sessions;
  final Transactor transactor;

  Future<Result<int>> call({
    required String sessionId,
    required String sessionExerciseId,
  }) async {
    try {
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      if (_entry(session, sessionExerciseId) == null) {
        return const Err(_noEntry);
      }
      final removed = session.sets
          .where((s) => s.sessionExerciseId == sessionExerciseId)
          .length;
      await transactor.run(() async {
        await sessions.removeExercise(sessionExerciseId);
        await sessions.setExerciseOrder(sessionId, [
          for (final e in session.exercises)
            if (e.id != sessionExerciseId) e.id,
        ]);
      });
      return Ok(removed);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

/// Use case: replace an exercise in a session (TRN-017(1)).
///
/// Sets already recorded stay with the original exercise. When the entry has
/// sets, the original entry is kept and the new exercise gets a new, empty
/// entry directly after it for the sets still to come; when it has none, the
/// entry itself changes to the new exercise (its note is kept). The new
/// exercise must exist, not be archived, differ from the original and not
/// already be in the session. Returns the entry that now holds the new
/// exercise.
final class ReplaceSessionExercise {
  const ReplaceSessionExercise({
    required this.sessions,
    required this.exercises,
    required this.transactor,
    required this.newId,
  });

  final WorkoutSessionRepository sessions;
  final ExerciseRepository exercises;
  final Transactor transactor;
  final IdGenerator newId;

  Future<Result<SessionExercise>> call({
    required String sessionId,
    required String sessionExerciseId,
    required String newExerciseId,
  }) async {
    try {
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      final entry = _entry(session, sessionExerciseId);
      if (entry == null) return const Err(_noEntry);
      final problem = await _usable(exercises, session, newExerciseId);
      if (problem != null) return Err(problem);
      final hasSets = session.sets.any(
        (s) => s.sessionExerciseId == sessionExerciseId,
      );
      final result = await transactor.run(() async {
        if (!hasSets) {
          final changed = SessionExercise(
            id: entry.id,
            sessionId: entry.sessionId,
            exerciseId: newExerciseId,
            position: entry.position,
            note: entry.note,
          );
          await sessions.updateExercise(changed);
          return changed;
        }
        final added = SessionExercise(
          id: newId(),
          sessionId: sessionId,
          exerciseId: newExerciseId,
          position: _nextPosition(session),
        );
        await sessions.addExercise(added);
        final index = session.exercises.indexWhere((e) => e.id == entry.id);
        final ids = [for (final e in session.exercises) e.id]
          ..insert(index + 1, added.id);
        await sessions.setExerciseOrder(sessionId, ids);
        return SessionExercise(
          id: added.id,
          sessionId: sessionId,
          exerciseId: newExerciseId,
          position: index + 1,
        );
      });
      return Ok(result);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

/// Use case: move one exercise of a session from index `from` to `to`
/// (TRN-017(2)); the stored order changes, in one transaction.
final class ReorderSessionExercises {
  const ReorderSessionExercises({required this.sessions});

  final WorkoutSessionRepository sessions;

  Future<Result<List<SessionExercise>>> call({
    required String sessionId,
    required int from,
    required int to,
  }) async {
    try {
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      final moved = reorder(session.exercises, from, to);
      if (moved case Err(:final error)) return Err(error);
      final list = (moved as Ok<List<SessionExercise>>).value;
      await sessions.setExerciseOrder(sessionId, [for (final e in list) e.id]);
      return Ok([
        for (var i = 0; i < list.length; i++)
          SessionExercise(
            id: list[i].id,
            sessionId: list[i].sessionId,
            exerciseId: list[i].exerciseId,
            position: i,
            note: list[i].note,
          ),
      ]);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

/// Use case: edit a recorded set (TRN-024). Validated exactly like
/// `RecordSet` (type, reps, exertion, rest, note), except that the exercise
/// may since have been archived or deleted (history stays editable); the
/// exercise, entry and order of the set do not change. Because records and
/// volume are derived, they follow the edit.
final class EditSet {
  const EditSet({required this.exercises, required this.sessions});

  final ExerciseRepository exercises;
  final WorkoutSessionRepository sessions;

  Future<Result<SessionSet>> call({
    required String sessionId,
    required String setId,
    required SetData data,
    required bool completed,
    SetKind kind = SetKind.working,
    Exertion? exertion,
    int? restSeconds,
    String? note,
  }) async {
    try {
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      final existing = session.sets.where((s) => s.id == setId).firstOrNull;
      if (existing == null) {
        return const Err(NotFoundError('That set no longer exists.'));
      }
      final exercise =
          await exercises.byId(existing.exerciseId) ??
          // A deleted exercise cannot be looked up; its type is the type of
          // the set it already holds.
          Exercise(
            id: existing.exerciseId,
            name: '',
            type: existing.data.type,
            category: ExerciseCategory.fullBody,
            primaryMuscle: MuscleGroup.fullBody,
            createdAt: session.createdAt,
            updatedAt: session.createdAt,
          );
      final checked = validateSetForExercise(
        exercise,
        data,
        exertion: exertion,
      );
      if (checked case Err(:final error)) return Err(error);
      final extras = validateSetExtras(restSeconds: restSeconds, note: note);
      if (extras case Err(:final error)) return Err(error);
      final updated = existing.copyWith(
        data: (checked as Ok<SetData>).value,
        completed: completed,
        kind: kind,
        exertion: exertion,
        restSeconds: restSeconds,
        note: (extras as Ok<String?>).value,
      );
      await sessions.updateSet(updated);
      return Ok(updated);
    } on Object catch (e) {
      return Err(StorageError('Could not save the set.', cause: e));
    }
  }
}

/// Use case: delete one recorded set (TRN-024). The set is removed; records
/// and volume are derived, so they follow. The caller confirms first.
final class DeleteSet {
  const DeleteSet({required this.sessions});

  final WorkoutSessionRepository sessions;

  Future<Result<void>> call({
    required String sessionId,
    required String setId,
  }) async {
    try {
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      if (!session.sets.any((s) => s.id == setId)) {
        return const Err(NotFoundError('That set no longer exists.'));
      }
      await sessions.deleteSet(setId);
      return const Ok(null);
    } on Object catch (e) {
      return Err(StorageError('Could not delete the set.', cause: e));
    }
  }
}

/// Use case: delete a session (TRN-024(2)). A soft delete (`deleted_at`):
/// nothing is removed, and [RestoreSession] brings it back at any time. The
/// confirmation and the undo window (at least 10 s) belong to the screen.
final class DeleteSession {
  const DeleteSession({required this.sessions});

  final WorkoutSessionRepository sessions;

  Future<Result<void>> call(String sessionId) async {
    try {
      if (await sessions.byId(sessionId) == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      await sessions.delete(sessionId);
      return const Ok(null);
    } on Object catch (e) {
      return Err(StorageError('Could not delete the session.', cause: e));
    }
  }
}

/// Use case: undo [DeleteSession]. Works at any time, as nothing is purged.
final class RestoreSession {
  const RestoreSession({required this.sessions});

  final WorkoutSessionRepository sessions;

  Future<Result<WorkoutSession>> call(String sessionId) async {
    try {
      if (!await sessions.restore(sessionId)) {
        return const Err(NotFoundError('That session is not deleted.'));
      }
      final session = await sessions.byId(sessionId);
      if (session == null) {
        return const Err(NotFoundError('That session no longer exists.'));
      }
      return Ok(session);
    } on Object catch (e) {
      return Err(StorageError('Could not restore the session.', cause: e));
    }
  }
}
