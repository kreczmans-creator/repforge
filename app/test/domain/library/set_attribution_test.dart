import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/set_attribution.dart';

import 'support/catalogue_fixtures.dart';

/// OQ-19: attributed set counts, not physiological measurements.
void main() {
  late ApprovedReference ref;
  setUpAll(() => ref = ApprovedReference.load());

  int sets(Map<AnatomyNodeId, AttributedTotals> m, String node) =>
      m[node_(node)]?.sets ?? 0;

  test('each primary target receives the full recorded set count', () {
    final r = attributeSetCounts([
      AttributedExercise(
        targets: [primary('chest', 0), secondary('triceps', 1)],
        sets: 3,
      ),
    ], ref.data.anatomy);
    expect(sets(r.primary, 'chest'), 3);
    expect(sets(r.primary, 'triceps'), 0);
  });

  test(
    'several primary targets each get the full count, once per distinct node',
    () {
      final r = attributeSetCounts([
        AttributedExercise(
          targets: [primary('lats', 0), primary('upperBack', 1)],
          sets: 4,
        ),
        AttributedExercise(targets: [primary('lats', 0)], sets: 2),
      ], ref.data.anatomy);
      expect(sets(r.primary, 'lats'), 6);
      expect(sets(r.primary, 'upperBack'), 4);
    },
  );

  test('secondary targets are separate and excluded from primary totals', () {
    final r = attributeSetCounts([
      AttributedExercise(
        targets: [
          primary('chest', 0),
          secondary('triceps', 1),
          secondary('frontDelts', 2),
        ],
        sets: 3,
      ),
      AttributedExercise(targets: [primary('triceps', 0)], sets: 2),
    ], ref.data.anatomy);
    expect(
      sets(r.primary, 'triceps'),
      2,
    ); // only the exercise where it is primary
    expect(sets(r.secondary, 'triceps'), 3);
    expect(sets(r.secondary, 'frontDelts'), 3);
    expect(r.primary.containsKey(node_('frontDelts')), isFalse);
  });

  test('kg volume of the attributed sets follows the same attribution', () {
    final r = attributeSetCounts([
      AttributedExercise(
        targets: [primary('chest', 0), secondary('triceps', 1)],
        sets: 3,
        volumeKg: 1200,
      ),
      AttributedExercise(
        targets: [primary('chest', 0)],
        sets: 1,
        volumeKg: 400.5,
      ),
    ], ref.data.anatomy);
    expect(r.primary[node_('chest')], const AttributedTotals(4, 1600.5));
    expect(r.secondary[node_('triceps')], const AttributedTotals(3, 1200));
  });

  test('fullBody is non-anatomical: separate, never in anatomical totals', () {
    final r = attributeSetCounts([
      AttributedExercise(targets: [primary('fullBody', 0)], sets: 5),
      AttributedExercise(
        targets: [primary('calves', 0), secondary('fullBody', 1)],
        sets: 2,
      ),
    ], ref.data.anatomy);
    expect(r.primary.keys.map((k) => k.value), ['calves']);
    expect(sets(r.nonAnatomicalPrimary, 'fullBody'), 5);
    expect(
      sets(r.nonAnatomicalSecondary, 'fullBody'),
      2,
    ); // stored historically
    expect(r.secondary.isEmpty, isTrue);
  });

  test(
    'roll-up to a level attributes once per distinct ancestor per exercise',
    () {
      final r = attributeSetCounts(
        [
          // Two heads of the deltoid as primaries: the deltoid gets them once.
          AttributedExercise(
            targets: [
              primary('frontDelts', 0),
              primary('sideDelts', 1),
              secondary('triceps', 2),
            ],
            sets: 3,
          ),
          AttributedExercise(targets: [primary('rearDelts', 0)], sets: 2),
        ],
        ref.data.anatomy,
        rollUpToLevel: 3,
      );
      expect(sets(r.primary, 'deltoid'), 5);
      expect(sets(r.secondary, 'triceps'), 3);
      final atGroup = attributeSetCounts(
        [
          AttributedExercise(
            targets: [primary('frontDelts', 0), primary('rearDelts', 1)],
            sets: 3,
          ),
        ],
        ref.data.anatomy,
        rollUpToLevel: 2,
      );
      expect(sets(atGroup.primary, 'shoulders'), 3);
      // A node above the level stays where it is.
      final high = attributeSetCounts(
        [
          AttributedExercise(targets: [primary('chest', 0)], sets: 1),
        ],
        ref.data.anatomy,
        rollUpToLevel: 3,
      );
      expect(sets(high.primary, 'chest'), 1);
      // Non-anatomical nodes are never rolled up.
      final fb = attributeSetCounts(
        [
          AttributedExercise(targets: [primary('fullBody', 0)], sets: 1),
        ],
        ref.data.anatomy,
        rollUpToLevel: 2,
      );
      expect(sets(fb.nonAnatomicalPrimary, 'fullBody'), 1);
    },
  );

  test(
    'without roll-up each node keeps its own figures; unknown ids pass through',
    () {
      final r = attributeSetCounts([
        AttributedExercise(
          targets: [primary('sideDelts', 0), primary('mystery', 1)],
          sets: 2,
        ),
      ], ref.data.anatomy);
      expect(sets(r.primary, 'sideDelts'), 2);
      expect(sets(r.primary, 'mystery'), 2);
      expect(sets(r.primary, 'deltoid'), 0);
    },
  );

  test('empty input and the notice wording', () {
    final r = attributeSetCounts(const [], ref.data.anatomy);
    expect(r.primary, isEmpty);
    expect(r.notice, attributedSetCountsNotice);
    expect(
      attributedSetCountsNotice,
      contains('not physiological measurements'),
    );
    expect(attributedSetCountsNotice, contains('full attribution'));
    expect(const AttributedTotals(1, 2).toString(), '1 sets, 2.0 kg');
    expect(
      const AttributedTotals(1, 2).hashCode,
      const AttributedTotals(1, 2).hashCode,
    );
  });
}

AnatomyNodeId node_(String v) => AnatomyNodeId(v);
