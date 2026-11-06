import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';

/// A preserved WP 8 muscle id at its planned level and parent (plan section
/// 4; IC-804).
typedef PreservedNode = ({AnatomyNodeId id, int level, AnatomyNodeId? parent});

AnatomyNodeId _n(String v) => AnatomyNodeId(v);

/// The 19 WP 8 muscle identifiers with the level and parent the plan fixes.
/// Stored values map one to one; no identifier changes. A test compares this
/// table with the approved `anatomy.json`.
final List<PreservedNode> preservedMuscleNodes = List.unmodifiable([
  (id: _n('chest'), level: 2, parent: _n('regionChest')),
  (id: _n('frontDelts'), level: 4, parent: _n('deltoid')),
  (id: _n('sideDelts'), level: 4, parent: _n('deltoid')),
  (id: _n('rearDelts'), level: 4, parent: _n('deltoid')),
  (id: _n('triceps'), level: 3, parent: _n('upperArmPosterior')),
  (id: _n('biceps'), level: 3, parent: _n('upperArmAnterior')),
  (id: _n('forearms'), level: 2, parent: _n('regionArm')),
  (id: _n('upperBack'), level: 2, parent: _n('regionBack')),
  (id: _n('lats'), level: 2, parent: _n('regionBack')),
  (id: _n('lowerBack'), level: 2, parent: _n('regionBack')),
  (id: _n('abs'), level: 2, parent: _n('regionTrunk')),
  (id: _n('obliques'), level: 2, parent: _n('regionTrunk')),
  (id: _n('glutes'), level: 2, parent: _n('regionHip')),
  (id: _n('abductors'), level: 2, parent: _n('regionHip')),
  (id: _n('adductors'), level: 2, parent: _n('regionHip')),
  (id: _n('quadriceps'), level: 2, parent: _n('regionThigh')),
  (id: _n('hamstrings'), level: 2, parent: _n('regionThigh')),
  (id: _n('calves'), level: 2, parent: _n('regionLowerLeg')),
  (id: _n('fullBody'), level: 1, parent: null),
]);

/// The 21 equipment ids that predate the catalogue and stay unchanged
/// (IC-806; `docs/training-taxonomy.md`).
final List<EquipmentItemId> existingEquipmentIds = List.unmodifiable([
  for (final v in const [
    'barbell',
    'ezBar',
    'trapBar',
    'dumbbell',
    'kettlebell',
    'cable',
    'machine',
    'smithMachine',
    'bench',
    'squatRack',
    'pullUpBar',
    'dipBars',
    'resistanceBand',
    'plate',
    'medicineBall',
    'rings',
    'treadmill',
    'bike',
    'rower',
    'elliptical',
    'skippingRope',
  ])
    EquipmentItemId(v),
]);

/// The id of the one non-anatomical node (ADR-0010).
const AnatomyNodeId fullBodyNodeId = AnatomyNodeId('fullBody');

/// The ids the v8 migration needs for integrity (plan section 6, safeguard
/// B): the preserved ids of [preserved] and all their ancestors in [tree].
/// For the approved anatomy and the 19 preserved ids this is 31 nodes (19
/// plus 12 region, group and muscle ancestors). The migration constants come
/// in sub-stage 3b; this is the derivation they must equal.
Set<AnatomyNodeId> bootstrapNodeIds(
  AnatomyTree tree, [
  Iterable<AnatomyNodeId>? preserved,
]) {
  final ids = preserved ?? [for (final p in preservedMuscleNodes) p.id];
  final out = <AnatomyNodeId>{};
  for (final id in ids) {
    if (!tree.contains(id)) continue;
    out.add(id);
    for (final a in tree.ancestors(id)) {
      out.add(a.id);
    }
  }
  return out;
}
