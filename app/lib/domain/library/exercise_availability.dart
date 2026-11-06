/// Availability of an exercise for new work (WP 8 sub-stage 3b-8; D04 §7,
/// 2026-11-06: "WP 8 stage 3b implementation authorised; disposition of
/// exercises with no primary target", "3b check scope" and register R-01;
/// ADR-0008 section E, Q12; R-24).
///
/// Pure and storage-free. The data layer reads the facts (deleted, retired,
/// archived, the block rows) and this file decides one thing only: whether
/// the exercise may **enter new work** (a plan entry, a session entry, a
/// started session). Every other read (by id, history, the report) includes
/// every exercise, whatever its availability.
///
/// Rules, each from an approved source:
/// - **blocked**: an exercise with at least one block row whose
///   `resolved_at` is NULL is unavailable for normal selection and new
///   workout planning; its id, original data and history stay (D04 no-primary
///   disposition; ADR-0008 E Q12). Each reason is recorded and resolved
///   independently, and resolving one never unblocks the exercise while
///   another stays active (R-01).
/// - **retired**: a catalogue release retired it; it stays available to
///   historical records but is hidden from discovery (ADR-0009 decision 4;
///   R-24).
/// - **archived**: the user archived it; pickers hide it (TRN-012(2), WP 9
///   behaviour); user archiving and catalogue retirement are distinct
///   states (R-24).
/// - **deleted**: soft-deleted; history that references it stays readable.
///
/// The conditions are independent facts; an exercise can be blocked and
/// archived at once. [ExerciseAvailability.state] names one state for
/// display with a fixed precedence (deleted, blocked, retired, archived).
/// The precedence is a presentation convenience only: every state other
/// than selectable refuses new work, so it never changes
/// [ExerciseAvailability.canEnterNewWork].
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

  /// True only when nothing refuses new work: not deleted, no active block,
  /// not retired, not archived.
  bool get canEnterNewWork => state == ExerciseAvailabilityState.selectable;

  @override
  String toString() =>
      'ExerciseAvailability($exerciseId: ${states.map((s) => s.name).join('+')}'
      '${isBlocked ? ' ${blockReasons.map((r) => r.name).toList()}' : ''})';
}
