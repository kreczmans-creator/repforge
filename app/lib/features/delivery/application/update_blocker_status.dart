import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/delivery/owner_blocker.dart';
import 'package:repforge/domain/settings/settings.dart';

/// Use case: record the owner's status change (and optional note) for one
/// register entry.
final class UpdateBlockerStatus {
  const UpdateBlockerStatus({
    required this.repository,
    required this.clock,
    required this.register,
  });

  /// Longest note accepted, in characters.
  static const maxNoteLength = 500;

  final SettingsRepository repository;
  final Clock clock;
  final List<OwnerBlocker> register;

  Future<Result<BlockerState>> call({
    required String blockerId,
    required BlockerStatus status,
    String? note,
  }) async {
    if (!register.any((b) => b.id == blockerId)) {
      return const Err(
        ValidationError(
          'This blocker is not in the register.',
          field: 'blockerId',
        ),
      );
    }
    final trimmed = note?.trim();
    if (trimmed != null && trimmed.length > maxNoteLength) {
      return const Err(
        ValidationError(
          'Keep the note to $maxNoteLength characters or fewer.',
          field: 'note',
        ),
      );
    }
    final state = BlockerState(
      status: status,
      updatedAt: clock.now().toUtc(),
      note: trimmed == null || trimmed.isEmpty ? null : trimmed,
    );
    try {
      await repository.saveBlockerState(blockerId, state);
    } on Exception catch (e) {
      return Err(StorageError('Could not save the blocker status.', cause: e));
    }
    return Ok(state);
  }
}
