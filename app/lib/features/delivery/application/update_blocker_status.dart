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
    final blocker = register.where((b) => b.id == blockerId).firstOrNull;
    if (blocker == null) {
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
    final cleanNote = trimmed == null || trimmed.isEmpty ? null : trimmed;
    if (status == BlockerStatus.resolved &&
        cleanNote == null &&
        needsResolutionNote(blocker)) {
      return const Err(
        ValidationError(
          'Record the decision in the note before resolving this item, so '
          'the audit trail shows what was decided.',
          field: 'note',
        ),
      );
    }
    final change = BlockerChange(
      status: status,
      at: clock.now().toUtc(),
      note: cleanNote,
    );
    final BlockerState saved;
    try {
      final earlier = (await repository.readBlockerStates())[blockerId];
      saved = BlockerState.after(earlier, change);
      await repository.saveBlockerState(blockerId, saved);
    } on Object catch (e) {
      // Any failure, including a TypeError from foreign stored data, is a
      // storage error to the caller; nothing may escape the use case.
      return Err(StorageError('Could not save the blocker status.', cause: e));
    }
    return Ok(saved);
  }

  /// Resolving an owner decision, a scope approval or an owner acceptance
  /// without a note would leave no record of what was decided.
  static bool needsResolutionNote(OwnerBlocker blocker) => const {
    BlockerCategory.ownerDecision,
    BlockerCategory.scopeApproval,
    BlockerCategory.ownerAcceptance,
  }.contains(blocker.category);
}
