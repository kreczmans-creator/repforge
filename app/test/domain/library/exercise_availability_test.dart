import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/exercise_availability.dart';
import 'package:repforge/domain/library/migration_report.dart';

/// WP 8 sub-stage 3b-8: the availability predicate (D04 §7, 2026-11-06,
/// no-primary disposition and "3b check scope"; R-01; R-24; ADR-0008 E
/// Q12).
void main() {
  final t0 = DateTime.utc(2026, 11, 6, 12);
  final t1 = DateTime.utc(2026, 11, 7, 9);

  ExerciseBlock active(BlockReason r) =>
      ExerciseBlock(reason: r, blockedAt: t0);
  ExerciseBlock resolved(BlockReason r) =>
      ExerciseBlock(reason: r, blockedAt: t0, resolvedAt: t1);

  group('states', () {
    test('a clean exercise is selectable and may enter new work', () {
      final a = ExerciseAvailability(exerciseId: 'e');
      expect(a.state, ExerciseAvailabilityState.selectable);
      expect(a.states, [ExerciseAvailabilityState.selectable]);
      expect(a.canEnterNewWork, isTrue);
      expect(a.isDiscoverable, isTrue);
      expect(a.blockReasons, isEmpty);
    });

    test('blocked, retired, archived and deleted are never discoverable; '
        'blocked, archived and deleted refuse new work, retired does not '
        '(ADR-0009: hidden from discovery only; R-C8 decided)', () {
      final cases = {
        ExerciseAvailabilityState.blocked: ExerciseAvailability(
          exerciseId: 'e',
          blocks: [active(BlockReason.noPrimaryTarget)],
        ),
        ExerciseAvailabilityState.retired: ExerciseAvailability(
          exerciseId: 'e',
          retiredAt: t0,
        ),
        ExerciseAvailabilityState.archived: ExerciseAvailability(
          exerciseId: 'e',
          archived: true,
        ),
        ExerciseAvailabilityState.deleted: ExerciseAvailability(
          exerciseId: 'e',
          deletedAt: t0,
        ),
      };
      for (final MapEntry(key: state, value: a) in cases.entries) {
        expect(a.state, state, reason: '$a');
        expect(a.states, [state]);
        expect(a.isDiscoverable, isFalse, reason: '$a');
        expect(
          a.canEnterNewWork,
          state == ExerciseAvailabilityState.retired,
          reason: '$a',
        );
      }
    });

    test('several facts at once: every one is listed; display precedence '
        'deleted, blocked, retired, archived', () {
      final all = ExerciseAvailability(
        exerciseId: 'e',
        blocks: [active(BlockReason.unknownEquipment)],
        archived: true,
        retiredAt: t0,
        deletedAt: t1,
      );
      expect(all.states, [
        ExerciseAvailabilityState.deleted,
        ExerciseAvailabilityState.blocked,
        ExerciseAvailabilityState.retired,
        ExerciseAvailabilityState.archived,
      ]);
      expect(all.state, ExerciseAvailabilityState.deleted);
      final blockedArchived = ExerciseAvailability(
        exerciseId: 'e',
        blocks: [active(BlockReason.noPrimaryTarget)],
        archived: true,
      );
      expect(blockedArchived.state, ExerciseAvailabilityState.blocked);
      expect(blockedArchived.canEnterNewWork, isFalse);
      // Unarchiving does not make a blocked exercise selectable.
      final unarchived = ExerciseAvailability(
        exerciseId: 'e',
        blocks: blockedArchived.blocks,
      );
      expect(unarchived.canEnterNewWork, isFalse);
      expect(unarchived.toString(), contains('noPrimaryTarget'));
    });
  });

  group('R-C4: a field correction resolves every reason of that field', () {
    test('every reason maps to exactly one field', () {
      expect(
        {for (final r in BlockReason.values) r: BlockedField.of(r)},
        {
          BlockReason.noPrimaryTarget: BlockedField.targets,
          BlockReason.invalidSecondaryTarget: BlockedField.targets,
          BlockReason.unknownEquipment: BlockedField.equipment,
          BlockReason.invalidEquipment: BlockedField.equipment,
          BlockReason.invalidClassification: BlockedField.classification,
          BlockReason.invalidAliases: BlockedField.aliases,
        },
      );
      final all = [for (final f in BlockedField.values) ...f.reasons];
      expect(all.toSet(), BlockReason.values.toSet());
      expect(all, hasLength(BlockReason.values.length), reason: 'disjoint');
    });

    test('targets resolve noPrimaryTarget and invalidSecondaryTarget; '
        'classification and aliases resolve only their own reason', () {
      final blocks = [for (final r in BlockReason.values) active(r)];
      final t = resolveField(blocks, BlockedField.targets, t1);
      expect(t.resolved, {
        BlockReason.noPrimaryTarget,
        BlockReason.invalidSecondaryTarget,
      });
      final c = resolveField(t.blocks!, BlockedField.classification, t1);
      expect(c.resolved, {BlockReason.invalidClassification});
      final a = resolveField(c.blocks!, BlockedField.aliases, t1);
      expect(a.resolved, {BlockReason.invalidAliases});
      expect(activeBlockReasons(a.blocks!), {
        BlockReason.unknownEquipment,
        BlockReason.invalidEquipment,
      });
      final e = resolveField(a.blocks!, BlockedField.equipment, t1);
      expect(isBlocked(e.blocks!), isFalse);
    });

    test('equipment resolves both equipment reasons and leaves the target '
        'reason active', () {
      final blocks = [
        active(BlockReason.noPrimaryTarget),
        active(BlockReason.unknownEquipment),
        active(BlockReason.invalidEquipment),
      ];
      final r = resolveField(blocks, BlockedField.equipment, t1);
      expect(r.problem, isNull);
      expect(r.resolved, {
        BlockReason.unknownEquipment,
        BlockReason.invalidEquipment,
      });
      expect(activeBlockReasons(r.blocks!), {BlockReason.noPrimaryTarget});
      expect(r.blocks![0], blocks[0]);
      final t = resolveField(r.blocks!, BlockedField.targets, t1);
      expect(isBlocked(t.blocks!), isFalse);
      expect(t.resolved, {BlockReason.noPrimaryTarget});
    });

    test('a field without an active reason is refused', () {
      final r = resolveField(
        [resolved(BlockReason.unknownEquipment)],
        BlockedField.equipment,
        t1,
      );
      expect(r.problem, BlockResolutionProblem.notBlockedForReason);
      expect(r.blocks, isNull);
      expect(
        resolveField(const [], BlockedField.targets, t1).problem,
        BlockResolutionProblem.notBlockedForReason,
      );
    });
  });

  group('R-01: several reasons, resolved independently', () {
    test('only unresolved rows block; resolved rows stay as the record', () {
      final a = ExerciseAvailability(
        exerciseId: 'e',
        blocks: [resolved(BlockReason.noPrimaryTarget)],
      );
      expect(a.isBlocked, isFalse);
      expect(a.canEnterNewWork, isTrue);
      expect(a.blocks, hasLength(1));
      expect(isBlocked(a.blocks), isFalse);
    });

    test('resolving one of two reasons keeps the exercise blocked; '
        'resolving the second unblocks it', () {
      final blocks = [
        active(BlockReason.noPrimaryTarget),
        active(BlockReason.unknownEquipment),
      ];
      expect(activeBlockReasons(blocks), {
        BlockReason.noPrimaryTarget,
        BlockReason.unknownEquipment,
      });
      final first = resolveBlock(blocks, BlockReason.unknownEquipment, t1);
      expect(first.problem, isNull);
      expect(isBlocked(first.blocks!), isTrue);
      expect(activeBlockReasons(first.blocks!), {BlockReason.noPrimaryTarget});
      // Only that reason's row changed.
      expect(first.blocks![0], blocks[0]);
      expect(first.blocks![1], resolved(BlockReason.unknownEquipment));
      final second = resolveBlock(
        first.blocks!,
        BlockReason.noPrimaryTarget,
        t1,
      );
      expect(isBlocked(second.blocks!), isFalse);
      expect(second.blocks, hasLength(2));
    });

    test('resolving an absent or already resolved reason is refused', () {
      final blocks = [resolved(BlockReason.noPrimaryTarget)];
      expect(
        resolveBlock(blocks, BlockReason.noPrimaryTarget, t1).problem,
        BlockResolutionProblem.alreadyResolved,
      );
      expect(
        resolveBlock(blocks, BlockReason.invalidEquipment, t1).problem,
        BlockResolutionProblem.notBlockedForReason,
      );
      expect(
        resolveBlock(blocks, BlockReason.invalidEquipment, t1).blocks,
        isNull,
      );
    });

    test('reasons are reported in a stable order', () {
      final reasons = activeBlockReasons([
        active(BlockReason.invalidEquipment),
        active(BlockReason.noPrimaryTarget),
      ]).toList();
      expect(reasons, [
        BlockReason.noPrimaryTarget,
        BlockReason.invalidEquipment,
      ]);
    });

    test('value equality of block rows', () {
      expect(
        active(BlockReason.noPrimaryTarget),
        active(BlockReason.noPrimaryTarget),
      );
      expect(
        active(BlockReason.noPrimaryTarget).hashCode,
        active(BlockReason.noPrimaryTarget).hashCode,
      );
      expect(
        active(BlockReason.noPrimaryTarget),
        isNot(resolved(BlockReason.noPrimaryTarget)),
      );
      expect(
        active(BlockReason.noPrimaryTarget).toString(),
        contains('active'),
      );
      expect(
        resolved(BlockReason.noPrimaryTarget).toString(),
        contains('resolved'),
      );
    });
  });
}
