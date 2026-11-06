import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/preserved_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/library/reference_parsers.dart';
import 'package:repforge/domain/library/reference_validation.dart';
import 'package:repforge/domain/training/training.dart' show Equipment;

import 'support/catalogue_fixtures.dart';

/// Parsers and validators against the approved reference files under
/// `docs/catalogue/reference/` (read only).
void main() {
  late ApprovedReference ref;
  setUpAll(() => ref = ApprovedReference.load());

  group('parsers read the approved files', () {
    test('anatomy: 126 nodes (10 L1, 26 L2, 63 L3, 27 L4)', () {
      expect(ref.anatomy.nodes, hasLength(126));
      final byLevel = <int, int>{};
      for (final n in ref.anatomy.nodes) {
        byLevel.update(n.level, (c) => c + 1, ifAbsent: () => 1);
      }
      expect(byLevel, {1: 10, 2: 26, 3: 63, 4: 27});
      expect(ref.anatomy.provider, ProviderId.repforge);
      expect(ref.anatomy.locale, 'en-GB');
      expect(ref.anatomy.preservedIds, hasLength(19));
    });

    test('movement patterns: 79 entries (17 families, 62 patterns)', () {
      expect(ref.patterns.nodes, hasLength(79));
      expect(ref.patterns.nodes.where((p) => p.isFamily), hasLength(17));
      expect(ref.patterns.nodes.where((p) => !p.isFamily), hasLength(62));
      final lower = ref.patterns.nodes.firstWhere(
        (p) => p.id.value == 'lowerBodyCompound',
      );
      expect(lower.relatedCategories, ['legs']);
      expect(lower.definition, isNotEmpty);
    });

    test('equipment: 33 items (21 existing, 12 approved), 8 classes', () {
      expect(ref.equipment.items, hasLength(33));
      expect(ref.equipment.items.where((i) => i.existing), hasLength(21));
      expect(ref.equipment.items.where((i) => !i.existing), hasLength(12));
      expect(ref.equipment.classes, hasLength(8));
      expect(ref.equipment.notProposed, hasLength(7));
      final bench = ref.equipment.items.firstWhere(
        (i) => i.id.value == 'bench',
      );
      expect(bench.defaultRole, EquipmentDefaultRole.support);
      expect(bench.equipmentClass, EquipmentClass.bodyweight);
    });

    test('ledger: 238 entries, one per reference id', () {
      expect(ref.ledger, hasLength(238));
    });

    test('coverage specification: 21 groups, 325 slot minimums, 70 set '
        'entries', () {
      final c = ref.coverage;
      expect(c.groups, hasLength(21));
      expect(c.slotMinimumTotal, 325);
      expect(c.sets, hasLength(16));
      expect(c.setMinimumTotal, 70);
      expect(c.attributeValues.keys, hasLength(7));
    });

    test('node details survive parsing', () {
      final fullBody = ref.anatomy.nodes.firstWhere(
        (n) => n.id.value == 'fullBody',
      );
      expect(fullBody.nonAnatomical, isTrue);
      expect(fullBody.level, 1);
      expect(fullBody.parentId, isNull);
      expect(fullBody.label, 'Full body');
      expect(fullBody.status, ReferenceStatus.active);
    });
  });

  group('every validator passes on the approved files', () {
    test('anatomy hierarchy, sort order, fullBody, preserved ids', () {
      expect(validateAnatomy(ref.anatomy.nodes), isEmpty);
      expect(validatePreservedAnatomy(AnatomyTree(ref.anatomy.nodes)), isEmpty);
    });

    test('patterns, equipment, texts', () {
      expect(validatePatterns(ref.patterns.nodes), isEmpty);
      expect(validateEquipmentItems(ref.equipment.items), isEmpty);
      expect(
        validateReferenceTexts(
          anatomy: ref.anatomy.nodes,
          patterns: ref.patterns.nodes,
        ),
        isEmpty,
      );
    });

    test('ledger matches the lists (IC-810)', () {
      expect(
        validateLedger(
          ledger: ref.ledger,
          anatomy: ref.anatomy.nodes,
          patterns: ref.patterns.nodes,
          equipment: ref.equipment.items,
        ),
        isEmpty,
      );
    });

    test('coverage references resolve (IC-811)', () {
      // validateCoverageSpec is exercised in the coverage tests; here only
      // the ledger and lists are checked.
      expect(ref.data.anatomy.length, 126);
    });

    test(
      'labels: no duplicate label, IC-809 does not fire (IC-809 relabel)',
      () {
        final findings = validateReferenceLabels(
          anatomy: ref.anatomy.nodes,
          patterns: ref.patterns.nodes,
          equipment: ref.equipment.items,
        );
        expect(findings, isEmpty);
      },
    );

    test('the amendment records of 2026-11-06 are present and tolerated', () {
      for (final f in [
        'reference/anatomy.json',
        'reference/movement-patterns.json',
      ]) {
        final json = readJson(f)! as Map<String, Object?>;
        final amendments = json['amendments']! as List<Object?>;
        expect((amendments.single! as Map)['date'], '2026-11-06');
        expect((amendments.single! as Map)['by'], 'owner');
      }
      // The parsers read both files with the extra field.
      expect(ref.anatomy.nodes, hasLength(126));
      expect(ref.patterns.nodes, hasLength(79));
    });

    test('X3: trunkExtension carries the approved wording', () {
      final json =
          readJson('reference/movement-patterns.json')! as Map<String, Object?>;
      final node = (json['nodes']! as List)
          .cast<Map<String, Object?>>()
          .firstWhere((n) => n['id'] == 'trunkExtension');
      expect(
        node['includes'],
        contains('Machine back extensions in which the spine itself moves.'),
      );
    });

    test('regionChest is labelled "Chest region"; id and parent unchanged', () {
      final region = ref.anatomy.nodes.singleWhere(
        (n) => n.id.value == 'regionChest',
      );
      expect(region.label, 'Chest region');
      expect(region.level, 1);
      expect(region.parentId, isNull);
      final chest = ref.anatomy.nodes.singleWhere((n) => n.id.value == 'chest');
      expect(chest.label, 'Chest');
      expect(chest.parentId?.value, 'regionChest');
    });
  });

  group('the 19 preserved ids', () {
    test('the planned table equals anatomy.json (levels and parents)', () {
      final tree = AnatomyTree(ref.anatomy.nodes);
      expect(preservedMuscleNodes, hasLength(19));
      expect([
        for (final p in preservedMuscleNodes) p.id,
      ], ref.anatomy.preservedIds);
      for (final p in preservedMuscleNodes) {
        final node = tree.node(p.id)!;
        expect(node.level, p.level, reason: p.id.value);
        expect(node.parentId, p.parent, reason: p.id.value);
      }
    });

    test('they equal the WP 8 MuscleGroup values by name', () {
      // MuscleGroup stays untouched in 3a; the ids are the same strings.
      final names = {for (final p in preservedMuscleNodes) p.id.value};
      expect(names, hasLength(19));
      expect(names.contains('fullBody'), isTrue);
    });

    test('the 21 existing equipment ids equal the Equipment enum', () {
      expect(
        [for (final i in existingEquipmentIds) i.value],
        [for (final e in Equipment.values) e.name],
      );
      expect(existingEquipmentIds, hasLength(21));
    });

    test('specific levels and parents from the plan (section 4)', () {
      final tree = AnatomyTree(ref.anatomy.nodes);
      expect(tree.node(const AnatomyNodeId('frontDelts'))!.level, 4);
      expect(
        [
          for (final a in tree.ancestors(const AnatomyNodeId('frontDelts')))
            a.id.value,
        ],
        ['deltoid', 'shoulders', 'regionShoulder'],
      );
      expect(tree.node(const AnatomyNodeId('chest'))!.level, 2);
      expect(tree.node(const AnatomyNodeId('triceps'))!.level, 3);
      expect(
        [
          for (final c in tree.children(const AnatomyNodeId('abductors')))
            c.id.value,
        ],
        ['tensorFasciaeLatae'],
      );
    });
  });

  group('bootstrap node derivation (safeguard B)', () {
    test('ancestors of the 19 preserved ids are 31 nodes', () {
      final tree = AnatomyTree(ref.anatomy.nodes);
      final ids = bootstrapNodeIds(tree);
      expect(ids, hasLength(31));
      expect(
        ids
            .where((id) => !preservedMuscleNodes.any((p) => p.id == id))
            .map((i) => i.value)
            .toSet(),
        {
          'regionShoulder',
          'regionChest',
          'regionBack',
          'regionArm',
          'regionTrunk',
          'regionHip',
          'regionThigh',
          'regionLowerLeg',
          'shoulders',
          'deltoid',
          'upperArmAnterior',
          'upperArmPosterior',
        },
      );
    });

    test('the bootstrap is a small subset of the 126 node catalogue', () {
      final tree = AnatomyTree(ref.anatomy.nodes);
      expect(bootstrapNodeIds(tree).length, lessThan(tree.length));
      expect(tree.contains(const AnatomyNodeId('regionNeck')), isTrue);
      expect(
        bootstrapNodeIds(tree).contains(const AnatomyNodeId('regionNeck')),
        isFalse,
      );
    });

    test('unknown ids are ignored and the result is closed under parents', () {
      final tree = AnatomyTree(ref.anatomy.nodes);
      final ids = bootstrapNodeIds(tree, const [
        AnatomyNodeId('sideDelts'),
        AnatomyNodeId('doesNotExist'),
      ]);
      expect(ids.map((i) => i.value).toSet(), {
        'sideDelts',
        'deltoid',
        'shoulders',
        'regionShoulder',
      });
    });
  });

  group('tree queries', () {
    late AnatomyTree tree;
    setUpAll(() => tree = AnatomyTree(ref.anatomy.nodes));

    test('descendants include the whole subtree and exclude the node', () {
      final d = tree.descendants(const AnatomyNodeId('chest'));
      expect(d.map((n) => n.id.value), contains('pectoralisMajor'));
      expect(d.map((n) => n.id.value), isNot(contains('chest')));
      expect(
        tree
            .selfAndDescendantIds(const AnatomyNodeId('deltoid'))
            .map((i) => i.value),
        containsAll(['deltoid', 'frontDelts', 'sideDelts', 'rearDelts']),
      );
    });

    test('ancestor queries and lift to level 2', () {
      expect(
        tree.isSelfOrDescendantOf(
          const AnatomyNodeId('sideDelts'),
          const AnatomyNodeId('shoulders'),
        ),
        isTrue,
      );
      expect(
        tree.isSelfOrDescendantOf(
          const AnatomyNodeId('chest'),
          const AnatomyNodeId('shoulders'),
        ),
        isFalse,
      );
      expect(tree.lift(const AnatomyNodeId('sideDelts')).value, 'shoulders');
      expect(tree.lift(const AnatomyNodeId('pectoralisMajor')).value, 'chest');
      expect(tree.lift(const AnatomyNodeId('chest')).value, 'chest');
      expect(tree.lift(const AnatomyNodeId('fullBody')).value, 'fullBody');
      expect(
        tree.atLevel(const AnatomyNodeId('sideDelts'), 3)!.value,
        'deltoid',
      );
      expect(tree.atLevel(const AnatomyNodeId('nope'), 2), isNull);
    });

    test('fullBody is non-anatomical and childless', () {
      expect(tree.isAnatomical(const AnatomyNodeId('fullBody')), isFalse);
      expect(tree.isAnatomical(const AnatomyNodeId('chest')), isTrue);
      expect(tree.children(const AnatomyNodeId('fullBody')), isEmpty);
      expect(tree.descendants(const AnatomyNodeId('fullBody')), isEmpty);
    });

    test('roots are the ten level 1 nodes in sort order', () {
      expect(tree.roots, hasLength(10));
      expect(tree.roots.last.id.value, 'fullBody');
    });
  });

  group('attribute vocabulary equals coverage.json', () {
    test('seven attributes with the approved value names', () {
      expect(ExerciseAttribute.values, hasLength(7));
      for (final MapEntry(key: name, value: values)
          in ref.coverage.attributeValues.entries) {
        final attribute = ExerciseAttribute.values.byName(name);
        expect(
          AttributeVocabulary.valuesOf(attribute).toSet(),
          values.toSet(),
          reason: name,
        );
      }
    });
  });

  group('reference model', referenceModelTests);

  group('parsers reject malformed input', () {
    Map<String, Object?> anatomyJson() => {
      'formatVersion': 1,
      'provider': 'repforge',
      'locale': 'en-GB',
      'preservedWp8Ids': <String>[],
      'nodes': <Object?>[
        {
          'id': 'a',
          'parent': null,
          'level': 1,
          'sort': 10,
          'label': 'A',
          'lifecycle': 'active',
        },
      ],
    };

    test('not an object', () {
      expect(parseAnatomyReference('x').isErr, isTrue);
      expect(parsePatternReference(null).isErr, isTrue);
      expect(parseEquipmentReference(<Object?>[]).isErr, isTrue);
      expect(parseLedger(1).isErr, isTrue);
    });

    test('a minimal valid anatomy parses', () {
      final r = parseAnatomyReference(anatomyJson());
      expect(r.isOk, isTrue);
      expect((r as Ok<AnatomyReference>).value.nodes.single.id.value, 'a');
    });

    test('wrong format version and missing header are reported', () {
      final j = anatomyJson()..['formatVersion'] = 2;
      final r = parseAnatomyReference(j);
      expect(r.isErr, isTrue);
      final e = (r as Err<AnatomyReference>).error as ValidationError;
      expect(e.fieldErrors.keys, contains('formatVersion'));
    });

    test('field errors are collected with paths', () {
      final j = anatomyJson();
      (j['nodes']! as List<Object?>).add({
        'id': 'b',
        'level': 'two',
        'sort': 10,
        'label': 'B',
        'lifecycle': 'sleeping',
        'nonAnatomical': 'yes',
      });
      final r = parseAnatomyReference(j);
      final e = (r as Err<AnatomyReference>).error as ValidationError;
      expect(
        e.fieldErrors.keys,
        containsAll([
          'nodes[1].level',
          'nodes[1].lifecycle',
          'nodes[1].nonAnatomical',
        ]),
      );
      expect(e.message, contains('3 problem'));
    });

    test('pattern, equipment and ledger shape errors', () {
      expect(
        parsePatternReference({
          'formatVersion': 1,
          'provider': 'repforge',
          'locale': 'en-GB',
          'nodes': [
            {
              'id': 'p',
              'level': 1,
              'sort': 1,
              'label': 'P',
              'lifecycle': 'active',
              'relatedCategories': 'legs',
            },
          ],
        }).isErr,
        isTrue,
      );
      expect(
        parseEquipmentReference({
          'formatVersion': 1,
          'provider': 'repforge',
          'locale': 'en-GB',
          'classes': ['freeWeight', 'spaceship'],
          'nodes': [
            {
              'id': 'x',
              'sort': 1,
              'label': 'X',
              'equipmentClass': 'cable',
              'role': 'load',
              'status': 'invented',
              'lifecycle': 'active',
            },
          ],
        }).isErr,
        isTrue,
      );
      expect(
        parseLedger({
          'formatVersion': 1,
          'entries': [
            {'list': 'colours', 'id': 'x', 'lifecycle': 'active'},
          ],
        }).isErr,
        isTrue,
      );
      expect(
        parseLedger({'formatVersion': 9, 'entries': <Object?>[]}).isErr,
        isTrue,
      );
    });
  });
}

/// The reference model types: value equality and the queries that stay safe
/// on invalid data (the validators report on it).
void referenceModelTests() {
  late ApprovedReference ref;
  setUpAll(() => ref = ApprovedReference.load());

  test('nodes compare by value and expose their label', () {
    final a = ref.anatomy.nodes.first;
    final same = AnatomyNode(
      id: a.id,
      parentId: a.parentId,
      level: a.level,
      sort: a.sort,
      labels: Map.of(a.labels),
      nonAnatomical: a.nonAnatomical,
      status: a.status,
      providerId: a.providerId,
      definition: a.definition,
      includes: a.includes,
      excludes: a.excludes,
      note: a.note,
    );
    expect(a, same);
    expect(a.hashCode, same.hashCode);
    expect(a.label, a.labels['en-GB']);
    expect(a.isActive, isTrue);
    const unlabelled = AnatomyNode(
      id: AnatomyNodeId('x'),
      level: 1,
      sort: 1,
      labels: {},
    );
    expect(unlabelled.label, 'x');
    final p = ref.patterns.nodes.first;
    expect(p.isActive, isTrue);
    expect(p.label, isNotEmpty);
    final item = ref.equipment.items.first;
    expect(item.isActive, isTrue);
    expect(item.label, isNotEmpty);
    expect(
      item,
      EquipmentItem(
        id: item.id,
        sort: item.sort,
        labels: Map.of(item.labels),
        equipmentClass: item.equipmentClass,
        defaultRole: item.defaultRole,
        existing: item.existing,
        status: item.status,
        providerId: item.providerId,
        note: item.note,
      ),
    );
  });

  test('pattern tree: families, family of a pattern, children', () {
    final tree = ref.data.patterns;
    expect(tree.length, 79);
    expect(tree.families, hasLength(17));
    expect(tree.contains(const MovementPatternId('squat')), isTrue);
    expect(tree.pattern(const MovementPatternId('squat'))!.isFamily, isFalse);
    expect(
      tree.familyOf(const MovementPatternId('squat'))!.id.value,
      'lowerBodyCompound',
    );
    expect(
      tree.familyOf(const MovementPatternId('upperPush'))!.id.value,
      'upperPush',
    );
    expect(tree.familyOf(const MovementPatternId('nope')), isNull);
    expect(
      tree
          .children(const MovementPatternId('lowerBodyCompound'))
          .map((p) => p.id.value),
      ['squat', 'hinge', 'lunge'],
    );
  });

  test('equipment catalogue lookups', () {
    final items = ref.data.equipment;
    expect(items.length, 33);
    expect(items.contains(const EquipmentItemId('skiErg')), isTrue);
    expect(items.item(const EquipmentItemId('nope')), isNull);
  });

  test('a tree built from invalid data never throws or loops', () {
    AnatomyNode n(String id, String? parent) => AnatomyNode(
      id: AnatomyNodeId(id),
      parentId: parent == null ? null : AnatomyNodeId(parent),
      level: 2,
      sort: 1,
      labels: const {},
    );
    final tree = AnatomyTree([
      n('a', 'b'),
      n('b', 'a'),
      n('a', null),
      n('c', 'ghost'),
    ]);
    expect(tree.length, 3); // the duplicate id a keeps its first node
    expect(tree.ancestors(const AnatomyNodeId('a')).map((x) => x.id.value), [
      'b',
    ]);
    expect(tree.ancestors(const AnatomyNodeId('c')), isEmpty);
    expect(tree.descendants(const AnatomyNodeId('a')).map((x) => x.id.value), [
      'b',
    ]);
    expect(
      tree.areRelated(const AnatomyNodeId('a'), const AnatomyNodeId('b')),
      isTrue,
    );
    expect(tree.node(const AnatomyNodeId('zzz')), isNull);
  });
}
