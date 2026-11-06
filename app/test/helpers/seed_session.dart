import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/features/training/application/record_set.dart';

/// Stores [session] and then each of its sets through `addSet`, the only
/// path that writes sets (`upsert` writes the session row only). For test
/// fixtures; the app records sets through `RecordSet`.
Future<void> seedSession(
  WorkoutSessionRepository repo,
  WorkoutSession session,
) async {
  await repo.upsert(session);
  for (final set in session.sets) {
    await repo.addSet(set);
  }
}

/// Test helper: records a set for [exerciseId] in the session's first entry
/// for that exercise, adding the entry (last in order) when there is none.
/// `RecordSet` itself always needs an entry id; the app adds entries through
/// `AddSessionExercise`. A missing session reaches `RecordSet` as an unknown
/// entry, so it reports not found.
Future<Result<SessionSet>> recordFor(
  RecordSet record,
  WorkoutSessionRepository sessions, {
  required String sessionId,
  required String exerciseId,
  required SetData data,
  bool completed = true,
  Exertion? exertion,
  int? restSeconds,
  String? note,
  SetKind kind = SetKind.working,
}) async {
  var entryId = 'missing-session';
  try {
    final session = await sessions.byId(sessionId);
    if (session != null) {
      final existing = session.exercises
          .where((e) => e.exerciseId == exerciseId)
          .firstOrNull;
      if (existing != null) {
        entryId = existing.id;
      } else {
        entryId = 'entry-$sessionId-$exerciseId';
        await sessions.addExercise(
          SessionExercise(
            id: entryId,
            sessionId: sessionId,
            exerciseId: exerciseId,
            position: session.exercises.length,
          ),
        );
      }
    }
  } on Object catch (e) {
    return Err(StorageError('Could not save the set.', cause: e));
  }
  return await record(
    sessionId: sessionId,
    sessionExerciseId: entryId,
    data: data,
    completed: completed,
    exertion: exertion,
    restSeconds: restSeconds,
    note: note,
    kind: kind,
  );
}
