/// Availability of an exercise (WP 8 sub-stage 3b-8; D04 §7, 2026-11-06:
/// "WP 8 stage 3b implementation authorised; disposition of exercises with
/// no primary target", "3b check scope" and register R-01; ADR-0008 section
/// E, Q12; ADR-0009 decision 4; R-24).
///
/// Pure and storage-free. The data layer reads the facts (deleted, retired,
/// archived, the block rows) and this file decides two things:
/// - [ExerciseAvailability.isDiscoverable]: whether selection and discovery
///   (pickers, the library list) offer the exercise;
/// - [ExerciseAvailability.canEnterNewWork]: whether a use case may add it
///   to new work (a plan entry, a session entry, a started session, a set).
/// Every other read (by id, history, the report) includes every exercise,
/// whatever its availability.
///
/// Rules, each from an approved source:
/// - **blocked**: an exercise with at least one block row whose
///   `resolved_at` is NULL is unavailable for normal selection and new
///   workout planning; its id, original data and history stay (D04 no-primary
///   disposition; ADR-0008 E Q12). Each reason is recorded and resolved
///   independently, and resolving one never unblocks the exercise while
///   another stays active (R-01). Not discoverable; refused for new work.
/// - **retired**: a catalogue release retired it; it is "kept, hidden from
///   discovery, readable in history" and retirement "protects history"
///   and plans (ADR-0009 decision 4 and rationale; R-24). Not discoverable;
///   **not** refused for new work: the sources state no such refusal, so
///   whether new work may use a retired exercise is an owner question
///   (register R-C8, `docs/v8-library-use-cases.md`).
/// - **archived**: the user archived it; pickers hide it and a use case
///   refuses it for new work, exactly as WP 9 does (TRN-012(2); TD-42 lets a
///   saved plan keep it). Not discoverable; refused for new work.
/// - **deleted**: soft-deleted; history that references it stays readable.
///   Not discoverable; refused for new work.
///
/// The conditions are independent facts; an exercise can be blocked and
/// archived at once. [ExerciseAvailability.state] names one state for
/// display with a fixed precedence (deleted, blocked, retired, archived).
/// The precedence is a presentation convenience only and never changes the
/// two predicates.
library;

import 'package:meta/meta.dart';
import 'package:repforge/domain/library/migration_report.dart' show BlockReason;

/// One stored block of an exercise (`exercise_blocks`, one row per exercise
/// and reason; R-01).
@immutable
final class ExerciseBlock {
  const ExerciseBlock({
    required this.reason,
    required this.blockedAt,
    this.resolvedAt,
  });

  final BlockReason reason;
  final DateTime blockedAt;

  /// Set by the correction route for this reason only; null while active.
  final DateTime? resolvedAt;

  bool get isActive => resolvedAt == null;

  @override
  bool operator ==(Object other) =>
      other is ExerciseBlock &&
      other.reason == reason &&
      other.blockedAt == blockedAt &&
      other.resolvedAt == resolvedAt;

  @override
  int get hashCode => Object.hash(reason, blockedAt, resolvedAt);

  @override
  String toString() =>
      'ExerciseBlock(${reason.name}, '
      '${isActive ? 'active' : 'resolved $resolvedAt'})';
}

/// The active block reasons of [blocks] (R-01), in [BlockReason] order.
Set<BlockReason> activeBlockReasons(Iterable<ExerciseBlock> blocks) {
  final active = {
    for (final b in blocks)
      if (b.isActive) b.reason,
  };
  return {
    for (final r in BlockReason.values)
      if (active.contains(r)) r,
  };
}

/// True while any block of [blocks] is active (R-01: "blocked while any of
/// its rows has `resolved_at` NULL").
bool isBlocked(Iterable<ExerciseBlock> blocks) => blocks.any((b) => b.isActive);

/// Why resolving a block was refused.
enum BlockResolutionProblem {
  /// The exercise has no block with this reason.
  notBlockedForReason,

  /// The block with this reason is already resolved.
  alreadyResolved,
}

/// The blocks after resolving [reason] at [at]: only that reason's row
/// changes (R-01: each reason is resolved independently). Returns the
/// problem instead when the reason has no active block. The result is still
/// blocked when another reason stays active ([isBlocked]).
({List<ExerciseBlock>? blocks, BlockResolutionProblem? problem}) resolveBlock(
  List<ExerciseBlock> blocks,
  BlockReason reason,
  DateTime at,
) {
  final index = blocks.indexWhere((b) => b.reason == reason);
  if (index < 0) {
    return (blocks: null, problem: BlockResolutionProblem.notBlockedForReason);
  }
  if (!blocks[index].isActive) {
    return (blocks: null, problem: BlockResolutionProblem.alreadyResolved);
  }
  final out = [...blocks];
  out[index] = ExerciseBlock(
    reason: reason,
    blockedAt: blocks[index].blockedAt,
    resolvedAt: at,
  );
  return (blocks: List.unmodifiable(out), problem: null);
}

/// The exercise field a block reason is about. A correction sets a whole
/// field, so it resolves every active reason tied to that field: setting
/// the equipment list resolves `unknownEquipment` and `invalidEquipment`
/// together (register R-C4, owner confirmation requested). The no-primary
/// disposition ties `noPrimaryTarget` to the targets.
/// `invalidSecondaryTarget` (OPEN, WS4 H1) has no field and no correction
/// route (register R-C3).
enum BlockedField {
  targets({BlockReason.noPrimaryTarget}),
  equipment({BlockReason.unknownEquipment, BlockReason.invalidEquipment});

  BlockedField(this.reasons);

  /// The block reasons this field resolves.
  final Set<BlockReason> reasons;

  /// The field of [reason]; null when it has no correction route.
  static BlockedField? of(BlockReason reason) {
    for (final f in values) {
      if (f.reasons.contains(reason)) return f;
    }
    return null;
  }
}

/// The blocks after a correction of [field] at [at]: every **active** row
/// whose reason belongs to the field is resolved; other rows are unchanged
/// (R-01: another field's reason keeps the exercise blocked). Returns
/// [BlockResolutionProblem.notBlockedForReason] when no active reason of the
/// field exists.
({
  List<ExerciseBlock>? blocks,
  Set<BlockReason> resolved,
  BlockResolutionProblem? problem,
})
resolveField(List<ExerciseBlock> blocks, BlockedField field, DateTime at) {
  final resolved = <BlockReason>{};
  final out = [
    for (final b in blocks)
      if (b.isActive && field.reasons.contains(b.reason))
        ExerciseBlock(reason: b.reason, blockedAt: b.blockedAt, resolvedAt: at)
      else
        b,
  ];
  for (final b in blocks) {
    if (b.isActive && field.reasons.contains(b.reason)) resolved.add(b.reason);
  }
  if (resolved.isEmpty) {
    return (
      blocks: null,
      resolved: const {},
      problem: BlockResolutionProblem.notBlockedForReason,
    );
  }
  return (blocks: List.unmodifiable(out), resolved: resolved, problem: null);
}

/// The single state shown for an exercise (precedence: deleted, blocked,
/// retired, archived, selectable).
enum ExerciseAvailabilityState {
  selectable,
  blocked,
  retired,
  archived,
  deleted,
}

/// The availability facts of one exercise and what follows from them.
@immutable
final class ExerciseAvailability {
  ExerciseAvailability({
    required this.exerciseId,
    Iterable<ExerciseBlock> blocks = const [],
    this.archived = false,
    this.retiredAt,
    this.deletedAt,
  }) : blocks = List.unmodifiable(blocks);

  final String exerciseId;

  /// Every block row, active and resolved (resolved rows are the record of
  /// the correction and stay).
  final List<ExerciseBlock> blocks;
  final bool archived;
  final DateTime? retiredAt;
  final DateTime? deletedAt;

  /// Active block reasons (R-01); empty when not blocked.
  Set<BlockReason> get blockReasons => activeBlockReasons(blocks);

  bool get isBlocked => blockReasons.isNotEmpty;
  bool get isRetired => retiredAt != null;
  bool get isDeleted => deletedAt != null;

  /// The one state shown, with the fixed display precedence.
  ExerciseAvailabilityState get state {
    if (isDeleted) return ExerciseAvailabilityState.deleted;
    if (isBlocked) return ExerciseAvailabilityState.blocked;
    if (isRetired) return ExerciseAvailabilityState.retired;
    if (archived) return ExerciseAvailabilityState.archived;
    return ExerciseAvailabilityState.selectable;
  }

  /// Every state that holds, in precedence order (more than one when, for
  /// example, an exercise is blocked and archived).
  List<ExerciseAvailabilityState> get states => [
    if (isDeleted) ExerciseAvailabilityState.deleted,
    if (isBlocked) ExerciseAvailabilityState.blocked,
    if (isRetired) ExerciseAvailabilityState.retired,
    if (archived) ExerciseAvailabilityState.archived,
    if (!isDeleted && !isBlocked && !isRetired && !archived)
      ExerciseAvailabilityState.selectable,
  ];

  /// True when selection and discovery offer the exercise: not deleted, no
  /// active block, not retired, not archived.
  bool get isDiscoverable => discoverable();

  /// [isDiscoverable], or with [includeArchived] also an archived exercise
  /// that is otherwise discoverable (WP 9 history views list archived
  /// exercises, TRN-012(2)). Blocked, retired and deleted exercises are never
  /// discoverable.
  bool discoverable({bool includeArchived = false}) =>
      !isDeleted && !isBlocked && !isRetired && (includeArchived || !archived);

  /// True when a use case may add the exercise to new work: not deleted, no
  /// active block (R-01), not archived (WP 9). A retired exercise is not
  /// refused here (ADR-0009 hides it from discovery only; owner question
  /// R-C8).
  bool get canEnterNewWork => !isDeleted && !isBlocked && !archived;

  @override
  String toString() =>
      'ExerciseAvailability($exerciseId: ${states.map((s) => s.name).join('+')}'
      '${isBlocked ? ' ${blockReasons.map((r) => r.name).toList()}' : ''})';
}
