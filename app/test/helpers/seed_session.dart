import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';

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
