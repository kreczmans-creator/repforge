import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/library/reference_validation.dart';

import 'support/catalogue_fixtures.dart';

AnatomyNode n(
  String id,
  int level,
  int sort, {
  String? parent,
  bool nonAnatomical = false,
  ReferenceStatus status = ReferenceStatus.active,
  String? label,
}) => AnatomyNode(
  id: AnatomyNodeId(id),
  parentId: parent == null ? null : AnatomyNodeId(parent),
  level: level,
  sort: sort,
  labels: {'en-GB': label ?? id},
  nonAnatomical: nonAnatomical,
  status: status,
);

MovementPattern p(
  String id,
  int level, {
  String? parent,
  ReferenceStatus status = ReferenceStatus.active,
}) => MovementPattern(
  id: MovementPatternId(id),
  parentId: parent == null ? null : MovementPatternId(parent),
  level: level,
  sort: 10,
  labels: {'en-GB': id},
  status: status,
);

EquipmentItem item(
  String id, {
  bool existing = false,
  ReferenceStatus status = ReferenceStatus.active,
}) => EquipmentItem(
  id: EquipmentItemId(id),
  sort: 10,
  labels: {'en-GB': id},
  equipmentClass: EquipmentClass.freeWeight,
  defaultRole: EquipmentDefaultRole.load,
  existing: existing,
  status: status,
);

void main() {
  late ApprovedReference ref;
  setUpAll(() => ref = ApprovedReference.load());

  group('anatomy hierarchy (IC-801)', () {
    test('a valid small tree passes', () {
      expect(
        validateAnatomy([
          n('r', 1, 10),
          n('g', 2, 10, parent: 'r'),
          n('m', 3, 10, parent: 'g'),
          n('h', 4, 10, parent: 'm'),
          n('fullBody', 1, 20, nonAnatomical: true),
        ]),
        isEmpty,
      );
    });

    test('duplicate ids', () {
      final f = validateAnatomy([n('r', 1, 10), n('r', 1, 20)]);
      expect(f.codes, ['IC-801']);
      expect(f.single.message, contains('Duplicate'));
    });

    test('missing parent', () {
      final f = validateAnatomy([n('g', 2, 10, parent: 'ghost')]);
      expect(
        f.withCode('IC-801').map((x) => x.message),
        contains(contains('does not exist')),
      );
    });

    test('level must be parent level plus one', () {
      final f = validateAnatomy([n('r', 1, 10), n('m', 3, 10, parent: 'r')]);
      expect(f.single.message, contains('one level deeper'));
    });

    test('level 1 must have no parent and others must have one', () {
      expect(
        validateAnatomy([n('x', 1, 10), n('r', 1, 20, parent: 'x')])
            .map((f) => f.message),
        contains(contains('Level 1 node r has a parent')),
      );
      expect(
        validateAnatomy([n('g', 2, 10)]).single.message,
        contains('has no parent'),
      );
    });

    test('levels outside 1 to 4', () {
      expect(validateAnatomy([n('r', 0, 10)]).codes, contains('IC-801'));
      expect(
        validateAnatomy([
          n('a', 1, 1),
          n('b', 2, 1, parent: 'a'),
          n('c', 3, 1, parent: 'b'),
          n('d', 4, 1, parent: 'c'),
          n('e', 5, 1, parent: 'd'),
        ]).single.message,
        contains('levels are 1 to 4'),
      );
    });

    test('a cycle is reported once, named by its smallest id', () {
      final f = validateAnatomy([
        n('a', 2, 10, parent: 'b'),
        n('b', 2, 10, parent: 'a'),
      ]);
      final cycles = f.where((x) => x.message.contains('cycle'));
      expect(cycles, hasLength(1));
      expect(cycles.single.subjectId, 'a');
    });

    test('a self-parent is a cycle', () {
      final f = validateAnatomy([n('a', 2, 10, parent: 'a')]);
      expect(f.any((x) => x.message.contains('cycle')), isTrue);
    });
  });

  group('sibling sort (IC-802)', () {
    test('unique sort values within a parent pass; same value fails', () {
      expect(validateAnatomy([n('r', 1, 10), n('s', 1, 20)]), isEmpty);
      final f = validateAnatomy([n('r', 1, 10), n('s', 1, 10)]);
      expect(f.codes, ['IC-802']);
      expect(f.single.related, ['s']);
    });

    test('the same sort value under different parents is fine', () {
      expect(
        validateAnatomy([
          n('r', 1, 10),
          n('s', 1, 20),
          n('a', 2, 10, parent: 'r'),
          n('b', 2, 10, parent: 's'),
        ]),
        isEmpty,
      );
    });
  });

  group('fullBody (IC-803)', () {
    test('another non-anatomical node fails', () {
      final f = validateAnatomy([n('x', 1, 10, nonAnatomical: true)]);
      expect(f.single.code, 'IC-803');
    });

    test('fullBody must be flagged, level 1 and childless', () {
      expect(validateAnatomy([n('fullBody', 1, 10)]).codes, ['IC-803']);
      expect(
        validateAnatomy([
          n('r', 1, 5),
          n('fullBody', 2, 10, parent: 'r', nonAnatomical: true),
        ]).withCode('IC-803'),
        isNotEmpty,
      );
      final f = validateAnatomy([
        n('fullBody', 1, 10, nonAnatomical: true),
        n('kid', 2, 10, parent: 'fullBody'),
      ]);
      expect(f.single.message, contains('no children'));
    });
  });

  group('preserved ids (IC-804)', () {
    test('a removed, moved or retired preserved id fails', () {
      final nodes = [...ref.anatomy.nodes]
        ..removeWhere((x) => x.id.value == 'chest');
      expect(
        validatePreservedAnatomy(AnatomyTree(nodes)).single.message,
        contains('chest is missing'),
      );
      final moved = [
        for (final x in ref.anatomy.nodes)
          if (x.id.value == 'lats')
            n('lats', 2, 20, parent: 'regionChest')
          else if (x.id.value == 'abs')
            n('abs', 3, 10, parent: 'regionTrunk')
          else if (x.id.value == 'calves')
            n(
              'calves',
              2,
              10,
              parent: 'regionLowerLeg',
              status: ReferenceStatus.retired,
            )
          else
            x,
      ];
      final f = validatePreservedAnatomy(AnatomyTree(moved));
      expect(f.map((x) => x.field), containsAll(['parent', 'level', 'status']));
    });
  });

  group('patterns (IC-805)', () {
    test('valid family and pattern pass', () {
      expect(
        validatePatterns([p('fam', 1), p('pat', 2, parent: 'fam')]),
        isEmpty,
      );
    });

    test(
      'pattern without a family, with a pattern parent, with a missing parent',
      () {
        expect(
          validatePatterns([p('pat', 2)]).single.message,
          contains('only families are roots'),
        );
        expect(
          validatePatterns([
            p('fam', 1),
            p('a', 2, parent: 'fam'),
            p('b', 2, parent: 'a'),
          ]).single.message,
          contains('not a family'),
        );
        expect(
          validatePatterns([p('a', 2, parent: 'ghost')]).single.message,
          contains('does not exist'),
        );
        expect(
          validatePatterns([p('fam', 1, parent: 'x')]).withCode('IC-805'),
          isNotEmpty,
        );
      },
    );

    test('duplicate ids and cycles', () {
      expect(
        validatePatterns([p('a', 1), p('a', 1)]).single.message,
        contains('Duplicate'),
      );
      final f = validatePatterns([
        p('a', 2, parent: 'b'),
        p('b', 2, parent: 'a'),
      ]);
      expect(f.any((x) => x.message.contains('cycle')), isTrue);
    });
  });

  group('equipment (IC-806)', () {
    final all = [for (final id in ref0Existing) item(id, existing: true)];

    test('all 21 existing ids present passes', () {
      expect(validateEquipmentItems(all), isEmpty);
    });

    test('a missing, unmarked, retired or duplicated item fails', () {
      expect(
        validateEquipmentItems(all.skip(1)).single.message,
        contains('is missing'),
      );
      final unmarked = [item(ref0Existing.first), ...all.skip(1)];
      expect(
        validateEquipmentItems(unmarked).single.message,
        contains('not marked existing'),
      );
      final retired = [
        item(
          ref0Existing.first,
          existing: true,
          status: ReferenceStatus.retired,
        ),
        ...all.skip(1),
      ];
      expect(
        validateEquipmentItems(retired).single.message,
        contains('retired'),
      );
      expect(
        validateEquipmentItems([...all, item('barbell', existing: true)])
            .single
            .message,
        contains('Duplicate'),
      );
    });
  });

  group('texts, labels, previous release, ledger', () {
    test('IC-807: missing definition, includes or excludes', () {
      final f = validateReferenceTexts(
        anatomy: [n('a', 1, 10)],
        patterns: [p('b', 1)],
      );
      expect(f, hasLength(6));
      expect(f.map((x) => x.field).toSet(), {
        'definition',
        'includes',
        'excludes',
      });
    });

    test('IC-809: duplicate labels warn per list and locale', () {
      final f = validateReferenceLabels(
        anatomy: [
          n('a', 1, 10, label: 'Chest'),
          n('b', 1, 20, label: 'chest'),
        ],
      );
      expect(f.single.severity, Severity.warning);
      expect(
        validateReferenceLabels(
          anatomy: [
            n('a', 1, 10, label: 'A'),
            n('b', 1, 20, label: 'B'),
          ],
        ),
        isEmpty,
      );
    });

    test('IC-808: removed id, changed parent or level', () {
      final before = [n('r', 1, 10), n('g', 2, 10, parent: 'r')];
      expect(
        validateReferenceAgainstPrevious(
          previousAnatomy: before,
          anatomy: before,
        ),
        isEmpty,
      );
      expect(
        validateReferenceAgainstPrevious(
          previousAnatomy: before,
          anatomy: [n('r', 1, 10)],
        ).single.message,
        contains('removed'),
      );
      expect(
        validateReferenceAgainstPrevious(
          previousAnatomy: before,
          anatomy: [
            n('r', 1, 10),
            n('s', 1, 20),
            n('g', 2, 10, parent: 's'),
          ],
        ).single.message,
        contains('changed parent'),
      );
      expect(
        validateReferenceAgainstPrevious(
          previousPatterns: [p('a', 1)],
          patterns: [],
        ).single.message,
        contains('removed'),
      );
      expect(
        validateReferenceAgainstPrevious(
          previousEquipment: [item('x')],
          equipment: [],
        ).single.message,
        contains('removed'),
      );
    });

    test(
      'IC-810: ledger completeness, lifecycle, retirement data, no return',
      () {
        final nodes = [
          n('a', 1, 10),
          n('b', 1, 20, status: ReferenceStatus.retired),
        ];
        LedgerEntry e(
          String id,
          ReferenceStatus s, {
          String? retiredIn,
          String? reason,
        }) => LedgerEntry(
          list: ReferenceList.anatomy,
          id: id,
          status: s,
          retiredIn: retiredIn,
          reason: reason,
        );
        expect(
          validateLedger(
            ledger: [
              e('a', ReferenceStatus.active),
              e(
                'b',
                ReferenceStatus.retired,
                retiredIn: 'r3',
                reason: 'merged',
              ),
            ],
            anatomy: nodes,
          ),
          isEmpty,
        );
        expect(
          validateLedger(
            ledger: [e('a', ReferenceStatus.active)],
            anatomy: nodes,
          ).single.message,
          contains('not in the ledger'),
        );
        expect(
          validateLedger(
            ledger: [
              e('a', ReferenceStatus.active),
              e('a', ReferenceStatus.active),
            ],
            anatomy: [nodes[0]],
          ).single.message,
          contains('more than once'),
        );
        expect(
          validateLedger(
            ledger: [
              e('a', ReferenceStatus.retired, retiredIn: 'r3', reason: 'x'),
            ],
            anatomy: [nodes[0]],
          ).single.message,
          contains('in the list but'),
        );
        expect(
          validateLedger(
            ledger: [
              e('a', ReferenceStatus.active),
              e('ghost', ReferenceStatus.active),
            ],
            anatomy: [nodes[0]],
          ).single.message,
          contains('no node in the list'),
        );
        final noData = validateLedger(
          ledger: [
            e('a', ReferenceStatus.active),
            e('b', ReferenceStatus.retired),
          ],
          anatomy: nodes,
        );
        expect(noData, hasLength(2));
        final returned = validateLedger(
          ledger: [e('a', ReferenceStatus.active)],
          anatomy: [nodes[0]],
          previousLedger: [
            e('a', ReferenceStatus.retired, retiredIn: 'r1', reason: 'x'),
          ],
        );
        expect(returned.single.message, contains('never return'));
      },
    );
  });
}

final List<String> ref0Existing = [
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
];
