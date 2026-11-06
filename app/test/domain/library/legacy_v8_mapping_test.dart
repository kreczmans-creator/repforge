import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/exercise_rules.dart';
import 'package:repforge/domain/library/legacy_v8_mapping.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:repforge/domain/library/preserved_ids.dart';
import 'package:repforge/domain/library/set_attribution.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_rules.dart';

import 'support/catalogue_fixtures.dart';

/// WS4 (3B-ACC-01): the v7 → v8 legacy mapping and the TRN-020 classifier.
void main() {
  LegacyExerciseMapping map({
    String id = 'ex-1',
    Object? type = 'weighted',
    Object? category = 'push',
    Object? aliases = '[]',
    Object? primary = 'chest',
    Object? secondary = '[]',
    Object? equipment = '[]',
    Object? supplied = 0,
  }) => mapLegacyExercise(
    LegacyExerciseRow(
      id: id,
      type: type,
      category: category,
      aliasesJson: aliases,
      primaryMuscle: primary,
      secondaryMusclesJson: secondary,
      equipmentJson: equipment,
      supplied: supplied,
    ),
  );

  List<String> targetsOf(LegacyExerciseMapping m) => [
    for (final t in m.targets) '$t',
  ];

  List<(String, int?, String, String)> eventsOf(LegacyExerciseMapping m) => [
    for (final e in m.events) (e.field, e.position, e.action.name, e.rule),
  ];

  group('clean rows', () {
    test('a clean row maps one to one with no event, block or quarantine', () {
      final m = map(
        secondary: '["triceps","frontDelts"]',
        equipment: '["barbell","bench"]',
      );
      expect(targetsOf(m), [
        'primary:chest@0',
        'secondary:triceps@1',
        'secondary:frontDelts@2',
      ]);
      expect(m.equipment, const [
        LegacyEquipmentLink(EquipmentItemId('barbell'), 0),
        LegacyEquipmentLink(EquipmentItemId('bench'), 1),
      ]);
      expect(m.events, isEmpty);
      expect(m.blocks, isEmpty);
      expect(m.quarantine, isEmpty);
      expect(m.isBlocked, isFalse);
      expect(m.outcome, ReportCategory.migrated);
    });

    test('supplied maps to source, provider and revision', () {
      final sys = map(supplied: 1);
      expect(sys.source, ExerciseSource.system);
      expect(sys.providerId, ProviderId.repforge);
      expect(sys.revision, 1);
      final sysBool = map(supplied: true);
      expect(sysBool.source, ExerciseSource.system);
      final user = map();
      expect(user.source, ExerciseSource.user);
      expect(user.providerId, isNull);
      expect(user.revision, isNull);
      expect(map(supplied: false).source, ExerciseSource.user);
    });

    test('a supplied value outside the v7 CHECK is a precondition error', () {
      for (final bad in [2, -1, null, '1', 1.0]) {
        expect(() => map(supplied: bad), throwsArgumentError, reason: '$bad');
      }
      expect(() => map(id: ''), throwsArgumentError);
    });

    test('every one of the 19 preserved ids maps as a primary', () {
      for (final p in preservedMuscleNodes) {
        final m = map(primary: p.id.value);
        expect(targetsOf(m), ['primary:${p.id}@0'], reason: '${p.id}');
        expect(m.events, isEmpty);
      }
    });

    test('every one of the 21 equipment ids maps, in stored order', () {
      final ids = [for (final e in existingEquipmentIds) e.value];
      final m = map(equipment: jsonEncode(ids.reversed.toList()));
      expect([for (final l in m.equipment) l.item.value], ids.reversed);
      expect(
        [for (final l in m.equipment) l.ordinal],
        [for (var i = 0; i < ids.length; i++) i],
      );
      expect(m.events, isEmpty);
    });

    test('the same input always gives the same output', () {
      Object snapshot() {
        final m = map(
          primary: 'Neck',
          secondary: '["chest","chest",7,"traps","fullBody"]',
          equipment: '["barbell","barbell","hoverboard",null]',
        );
        return [
          targetsOf(m),
          m.equipment,
          m.blocks,
          [for (final e in m.events) e],
          [for (final q in m.quarantine) q.originalJson],
        ].toString();
      }

      expect(snapshot(), snapshot());
    });
  });

  group('primary target', () {
    for (final bad in <Object?>[
      'rotator cuff',
      'Neck',
      '',
      'Chest',
      'chest ',
      null,
      42,
    ]) {
      test('unmapped primary ${jsonEncode(bad)} is quarantined and blocked, '
          'never invented', () {
        final m = map(primary: bad, secondary: '["triceps"]');
        // The secondary still migrates, at ordinal 0 (contiguous, IC-309).
        expect(targetsOf(m), ['secondary:triceps@0']);
        expect(m.targets.any((t) => t.isPrimary), isFalse);
        expect(eventsOf(m), [
          ('primary_muscle', null, 'blocked', 'IC-204'),
          ('primary_muscle', null, 'quarantined', 'IC-301'),
        ]);
        expect(m.blocks.single.reason, BlockReason.noPrimaryTarget);
        expect(m.events.first.blockReason, BlockReason.noPrimaryTarget);
        expect(m.events.first.category, ReportCategory.rejectedOrBlocked);
        expect(m.events.last.category, ReportCategory.quarantinedOrUnresolved);
        expect(
          m.events.every((e) => e.originalValue == encodeStoredValue(bad)),
          isTrue,
        );
        expect(m.quarantine.single.original, {'primary_muscle': bad});
        expect(
          m.quarantine.single.originalJson,
          '{"primary_muscle":${encodeStoredValue(bad)}}',
        );
        expect(m.outcome, ReportCategory.rejectedOrBlocked);
      });
    }

    test('a blocked exercise still migrates its equipment (ADR-0008 B18)', () {
      final m = map(primary: 'Neck', equipment: '["dumbbell"]');
      expect(m.equipment, const [
        LegacyEquipmentLink(EquipmentItemId('dumbbell'), 0),
      ]);
    });

    test('fullBody as the primary is valid', () {
      final m = map(primary: 'fullBody', secondary: '["quadriceps"]');
      expect(targetsOf(m), ['primary:fullBody@0', 'secondary:quadriceps@1']);
      expect(m.events, isEmpty);
    });
  });

  group('secondary targets', () {
    test('a secondary equal to the primary is skipped (IC-305), never '
        'duplicated', () {
      final m = map(secondary: '["triceps","chest","frontDelts"]');
      expect(targetsOf(m), [
        'primary:chest@0',
        'secondary:triceps@1',
        'secondary:frontDelts@2',
      ]);
      expect(eventsOf(m), [('secondary_muscles_json', 1, 'skipped', 'IC-305')]);
      final e = m.events.single;
      expect(e.category, ReportCategory.migrated);
      expect(e.element, '"chest"');
      expect(e.originalValue, jsonEncode('["triceps","chest","frontDelts"]'));
      expect(m.quarantine, isEmpty);
      expect(m.outcome, ReportCategory.migrated);
    });

    test('a secondary repeated in one list is skipped (IC-302); the first '
        'occurrence is kept', () {
      final m = map(secondary: '["biceps","triceps","biceps","biceps"]');
      expect(targetsOf(m), [
        'primary:chest@0',
        'secondary:biceps@1',
        'secondary:triceps@2',
      ]);
      expect(eventsOf(m), [
        ('secondary_muscles_json', 2, 'skipped', 'IC-302'),
        ('secondary_muscles_json', 3, 'skipped', 'IC-302'),
      ]);
    });

    test('a repeated primary in the secondary list is IC-305 each time', () {
      final m = map(secondary: '["chest","chest"]');
      expect(targetsOf(m), ['primary:chest@0']);
      expect(eventsOf(m), [
        ('secondary_muscles_json', 0, 'skipped', 'IC-305'),
        ('secondary_muscles_json', 1, 'skipped', 'IC-305'),
      ]);
    });

    test('a fullBody secondary is kept and reported as a warning for review '
        '(ADR-0010 rule 5)', () {
      final m = map(primary: 'quadriceps', secondary: '["fullBody","glutes"]');
      expect(targetsOf(m), [
        'primary:quadriceps@0',
        'secondary:fullBody@1',
        'secondary:glutes@2',
      ]);
      final e = m.events.single;
      expect(
        (e.field, e.position, e.action, e.rule, e.category),
        (
          'secondary_muscles_json',
          0,
          ReportAction.retained,
          'ADR-0010',
          ReportCategory.warningForReview,
        ),
      );
      // A warning never changes the outcome.
      expect(m.outcome, ReportCategory.migrated);
      expect(m.quarantine, isEmpty);
    });

    test('a repeated fullBody secondary: one warning, one IC-302 skip', () {
      final m = map(secondary: '["fullBody","fullBody"]');
      expect(eventsOf(m), [
        ('secondary_muscles_json', 0, 'retained', 'ADR-0010'),
        ('secondary_muscles_json', 1, 'skipped', 'IC-302'),
      ]);
    });

    test('an unmapped secondary is quarantined (IC-301) and blocks as '
        'invalidSecondaryTarget; the rest migrate with contiguous ordinals '
        '(R-11)', () {
      final m = map(secondary: '["traps","triceps","Neck","lats"]');
      expect(targetsOf(m), [
        'primary:chest@0',
        'secondary:triceps@1',
        'secondary:lats@2',
      ]);
      expect(eventsOf(m), [
        ('secondary_muscles_json', null, 'blocked', 'D04-UNREADABLE-SECONDARY'),
        ('secondary_muscles_json', 0, 'quarantined', 'IC-301'),
        ('secondary_muscles_json', 2, 'quarantined', 'IC-301'),
      ]);
      expect(m.quarantine.single.original, {
        'secondary_muscles_json': '["traps","triceps","Neck","lats"]',
      });
      expect(
        [for (final b in m.blocks) b.reason],
        [BlockReason.invalidSecondaryTarget],
      );
      expect(m.outcome, ReportCategory.rejectedOrBlocked);
    });

    test('a non-string secondary element is quarantined (WP8-D3)', () {
      final m = map(secondary: '["triceps",null,3,{"a":1}]');
      expect(targetsOf(m), ['primary:chest@0', 'secondary:triceps@1']);
      expect(eventsOf(m), [
        ('secondary_muscles_json', null, 'blocked', 'D04-UNREADABLE-SECONDARY'),
        ('secondary_muscles_json', 1, 'quarantined', 'WP8-D3'),
        ('secondary_muscles_json', 2, 'quarantined', 'WP8-D3'),
        ('secondary_muscles_json', 3, 'quarantined', 'WP8-D3'),
      ]);
      expect(
        [for (final e in m.events) e.element],
        [null, 'null', '3', '{"a":1}'],
      );
    });

    for (final (text, label) in <(Object?, String)>[
      ('not json', 'invalid JSON'),
      ('{"a":1}', 'an object'),
      ('"chest"', 'a JSON string'),
      ('', 'empty text'),
      (null, 'NULL'),
      (5, 'an integer'),
    ]) {
      test('secondary text that is $label is quarantined whole (WP8-D3) and '
          'blocks as invalidSecondaryTarget', () {
        final m = map(secondary: text);
        expect(targetsOf(m), ['primary:chest@0']);
        expect(eventsOf(m), [
          (
            'secondary_muscles_json',
            null,
            'blocked',
            'D04-UNREADABLE-SECONDARY',
          ),
          ('secondary_muscles_json', null, 'quarantined', 'WP8-D3'),
        ]);
        for (final e in m.events) {
          expect(e.originalValue, encodeStoredValue(text));
        }
        expect(
          [for (final b in m.blocks) b.reason],
          [BlockReason.invalidSecondaryTarget],
        );
        expect(m.quarantine.single.original, {'secondary_muscles_json': text});
      });
    }

    test('an unmapped primary repeated as a secondary is quarantined, not '
        'skipped', () {
      final m = map(primary: 'Neck', secondary: '["Neck"]');
      expect(eventsOf(m), [
        ('primary_muscle', null, 'blocked', 'IC-204'),
        ('primary_muscle', null, 'quarantined', 'IC-301'),
        ('secondary_muscles_json', null, 'blocked', 'D04-UNREADABLE-SECONDARY'),
        ('secondary_muscles_json', 0, 'quarantined', 'IC-301'),
      ]);
      expect(m.targets, isEmpty);
    });

    test('OQ-19 roll-up: a secondary sharing the primary parent is an '
        'ordinary target, not a migration event', () {
      // frontDelts and sideDelts both roll up to deltoid (L3).
      final m = map(primary: 'frontDelts', secondary: '["sideDelts"]');
      expect(m.events, isEmpty);
      expect(targetsOf(m), ['primary:frontDelts@0', 'secondary:sideDelts@1']);
      final ref = ApprovedReference.load();
      final counts = attributeSetCounts(
        [AttributedExercise(targets: m.targets, sets: 4)],
        ref.data.anatomy,
        rollUpToLevel: 3,
      );
      // The calculation suppresses the secondary credit at deltoid ...
      expect(counts.primary[const AnatomyNodeId('deltoid')]?.sets, 4);
      expect(counts.secondary[const AnatomyNodeId('deltoid')], isNull);
      // ... while the stored targets are unchanged and nothing is reported.
      expect(m.targets.length, 2);
    });
  });

  group('equipment (ADR-0008 sections B and E)', () {
    test('a repeated id keeps its first occurrence; each repeat is skipped '
        'with position and id (Q10); not quarantined', () {
      final m = map(equipment: '["barbell","bench","barbell","bench"]');
      expect(m.equipment, const [
        LegacyEquipmentLink(EquipmentItemId('barbell'), 0),
        LegacyEquipmentLink(EquipmentItemId('bench'), 1),
      ]);
      expect(eventsOf(m), [
        ('equipment_json', 2, 'skipped', 'IC-307'),
        ('equipment_json', 3, 'skipped', 'IC-307'),
      ]);
      expect([for (final e in m.events) e.element], ['"barbell"', '"bench"']);
      expect(m.quarantine, isEmpty);
      expect(m.blocks, isEmpty);
      expect(m.outcome, ReportCategory.migrated);
    });

    test('an unknown id is quarantined (IC-307) and blocks the exercise as '
        'unknownEquipment, naming the id; known items stay linked with '
        'ordinals over kept elements', () {
      const text = '["hoverboard","dumbbell","Barbell","none","dumbbell"]';
      final m = map(equipment: text);
      expect(m.equipment, const [
        LegacyEquipmentLink(EquipmentItemId('dumbbell'), 0),
      ]);
      expect(eventsOf(m), [
        ('equipment_json', null, 'blocked', 'ADR-0008-Q12'),
        ('equipment_json', 0, 'quarantined', 'IC-307'),
        ('equipment_json', 2, 'quarantined', 'IC-307'),
        ('equipment_json', 3, 'quarantined', 'IC-307'),
        ('equipment_json', 4, 'skipped', 'IC-307'),
      ]);
      expect(m.blocks, const [
        BlockDecision(
          BlockReason.unknownEquipment,
          '"hoverboard", "Barbell", "none"',
        ),
      ]);
      expect(m.events.first.reason, contains('"hoverboard"'));
      expect(m.quarantine.single.original, {'equipment_json': text});
      expect(m.outcome, ReportCategory.rejectedOrBlocked);
    });

    test('a non-string element is quarantined (WP8-D3) and blocks as '
        'invalidEquipment (R-02)', () {
      final m = map(equipment: '["barbell",null,7,["x"]]');
      expect(m.equipment, const [
        LegacyEquipmentLink(EquipmentItemId('barbell'), 0),
      ]);
      expect(eventsOf(m), [
        ('equipment_json', null, 'blocked', 'R-02'),
        ('equipment_json', 1, 'quarantined', 'WP8-D3'),
        ('equipment_json', 2, 'quarantined', 'WP8-D3'),
        ('equipment_json', 3, 'quarantined', 'WP8-D3'),
      ]);
      expect(m.blocks.single.reason, BlockReason.invalidEquipment);
      expect(m.events.first.blockReason, BlockReason.invalidEquipment);
    });

    for (final text in <Object?>['oops', '{"barbell":true}', '', null, 3]) {
      test('equipment text ${jsonEncode(text)} that is not an array blocks '
          'as invalidEquipment; nothing is linked', () {
        final m = map(equipment: text);
        expect(m.equipment, isEmpty);
        // A quarantined entry and a blocked entry, told apart by rule
        // (review WS4 L5), so their event ids differ.
        expect(eventsOf(m), [
          ('equipment_json', null, 'blocked', 'R-02'),
          ('equipment_json', null, 'quarantined', 'WP8-D3'),
        ]);
        final ids = {for (final e in m.events) ReportEntry('run-1', e).eventId};
        expect(ids, hasLength(2));
        expect(m.blocks.single.reason, BlockReason.invalidEquipment);
        expect(m.quarantine.single.original, {'equipment_json': text});
        for (final e in m.events) {
          expect(e.originalValue, encodeStoredValue(text));
          expect(e.position, isNull);
        }
        expect(m.outcome, ReportCategory.rejectedOrBlocked);
      });
    }

    test('unknown and invalid elements give two independent blocks (R-01)', () {
      final m = map(equipment: '["hoverboard",false]');
      expect(
        [for (final b in m.blocks) b.reason],
        [BlockReason.unknownEquipment, BlockReason.invalidEquipment],
      );
      expect(m.quarantine, hasLength(1), reason: 'one request per column');
    });

    test('no primary and unknown equipment: both reasons are active', () {
      final m = map(primary: '', equipment: '["hoverboard"]');
      expect(
        [for (final b in m.blocks) b.reason],
        [BlockReason.noPrimaryTarget, BlockReason.unknownEquipment],
      );
      expect(
        [for (final q in m.quarantine) q.original.keys.single],
        ['primary_muscle', 'equipment_json'],
      );
    });

    test('an empty list is valid: no item, no event', () {
      final m = map();
      expect(m.equipment, isEmpty);
      expect(m.events, isEmpty);
    });
  });

  group('unreadable data blocks individually (owner decision 2026-11-06; '
      'the H1 switch is removed)', () {
    for (final (text, label) in <(Object?, String)>[
      ('["triceps","traps"]', 'an unknown muscle'),
      ('["triceps",null]', 'a non-string element'),
      ('oops', 'non-array text'),
      (null, 'NULL'),
    ]) {
      test('secondaries with $label block as invalidSecondaryTarget, still '
          'quarantined, valid secondaries kept', () {
        final m = map(secondary: text);
        expect(m.blocks, [
          const BlockDecision(
            BlockReason.invalidSecondaryTarget,
            'secondary_muscles_json is not fully mappable',
          ),
        ]);
        final block = m.events.singleWhere(
          (e) => e.action == ReportAction.blocked,
        );
        expect(block.field, 'secondary_muscles_json');
        expect(block.position, isNull);
        expect(block.rule, 'D04-UNREADABLE-SECONDARY');
        expect(block.rule, MigrationRuleCodes.invalidSecondaryTargetBlock);
        expect(block.blockReason, BlockReason.invalidSecondaryTarget);
        expect(block.originalValue, encodeStoredValue(text));
        expect(
          m.events.where((e) => e.action == ReportAction.quarantined),
          isNotEmpty,
        );
        expect(m.quarantine.single.original, {'secondary_muscles_json': text});
        expect(m.outcome, ReportCategory.rejectedOrBlocked);
        expect({
          for (final e in m.events) ReportEntry('r', e).eventId,
        }, hasLength(m.events.length));
      });
    }

    test('what v7 accepts never blocks: repeats, the primary repeated, '
        'fullBody, an empty list', () {
      for (final text in [
        '["triceps","triceps"]',
        '["chest"]',
        '["fullBody"]',
        '[]',
      ]) {
        expect(map(secondary: text).blocks, isEmpty, reason: text);
      }
    });

    for (final (type, category, label) in <(Object?, Object?, String)>[
      ('Aerobic', 'push', 'an unknown type'),
      ('weighted', 'Plyometrics', 'an unknown category'),
      ('Weighted', 'push', 'a type in another case'),
      ('weighted', '', 'an empty category'),
      (7, 'push', 'a type that is not text'),
      ('Aerobic', 'Plyometrics', 'both unknown'),
    ]) {
      test('$label blocks as invalidClassification once; each unreadable '
          'field is quarantined and reported with its original', () {
        final m = map(type: type, category: category);
        expect(
          [for (final b in m.blocks) b.reason],
          [BlockReason.invalidClassification],
        );
        final bad = {
          if (type is! String ||
              !ExerciseType.values.any((t) => t.name == type))
            'type': type,
          if (category is! String ||
              !ExerciseCategory.values.any((c) => c.name == category))
            'category': category,
        };
        expect(m.quarantine.map((q) => q.original).toList(), [
          for (final MapEntry(:key, :value) in bad.entries) {key: value},
        ]);
        for (final MapEntry(key: field, value: original) in bad.entries) {
          final quarantined = m.events.singleWhere(
            (e) => e.field == field && e.action == ReportAction.quarantined,
          );
          expect(
            quarantined.rule,
            original is String
                ? (field == 'type' ? 'IC-202' : 'IC-203')
                : 'WP8-D3',
          );
          expect(quarantined.category, ReportCategory.quarantinedOrUnresolved);
          expect(quarantined.originalValue, encodeStoredValue(original));
          // The column keeps its original: nothing is rewritten.
          expect(quarantined.resultingValue, encodeStoredValue(original));
        }
        // One blocked entry for the one block, on the first unreadable
        // column (type before category).
        final blocked = m.events.singleWhere(
          (e) => e.action == ReportAction.blocked,
        );
        final first = bad.entries.first;
        expect(blocked.field, first.key);
        expect(blocked.originalValue, encodeStoredValue(first.value));
        expect(blocked.rule, 'D04-UNREADABLE-CLASSIFICATION');
        expect(blocked.blockReason, BlockReason.invalidClassification);
        for (final f in bad.keys) {
          expect(blocked.reason, contains(f));
        }
        expect(m.events.length, bad.length + 1);
        expect(m.outcome, ReportCategory.rejectedOrBlocked);
        expect(targetsOf(m), ['primary:chest@0'], reason: 'targets migrate');
      });
    }

    test('every domain type and category is readable', () {
      for (final t in ExerciseType.values) {
        for (final c in ExerciseCategory.values) {
          expect(map(type: t.name, category: c.name).blocks, isEmpty);
        }
      }
    });

    for (final (text, label, positions) in <(Object?, String, List<int?>)>[
      ('oops', 'invalid JSON', [null]),
      ('{"a":1}', 'an object', [null]),
      ('"alias"', 'a JSON string', [null]),
      ('', 'empty text', [null]),
      (null, 'NULL', [null]),
      ('["ok",null,3]', 'non-string elements', [1, 2]),
    ]) {
      test('aliases that are $label block as invalidAliases, quarantined '
          '(WP8-D3) and kept unchanged', () {
        final m = map(aliases: text);
        expect(
          [for (final b in m.blocks) b.reason],
          [BlockReason.invalidAliases],
        );
        expect(eventsOf(m), [
          ('aliases_json', null, 'blocked', 'D04-UNREADABLE-ALIASES'),
          for (final p in positions)
            ('aliases_json', p, 'quarantined', 'WP8-D3'),
        ]);
        for (final e in m.events) {
          expect(e.originalValue, encodeStoredValue(text));
          expect(e.resultingValue, encodeStoredValue(text));
        }
        expect(m.quarantine.single.original, {'aliases_json': text});
        expect(m.outcome, ReportCategory.rejectedOrBlocked);
      });
    }

    test('readable aliases never block: empty, strings, non-ASCII', () {
      for (final text in ['[]', '["a"]', '["Rudern ✓","Äpfel",""]']) {
        expect(map(aliases: text).blocks, isEmpty, reason: text);
      }
    });

    test('blocks follow the BlockReason order with every reason active '
        '(R-01)', () {
      final m = map(
        type: 'Aerobic',
        aliases: 'oops',
        primary: 'Neck',
        secondary: '["traps"]',
        equipment: '["hoverboard",1]',
      );
      expect([for (final b in m.blocks) b.reason], BlockReason.values);
      expect(m.quarantine.map((q) => q.original.keys.single).toList(), [
        'primary_muscle',
        'secondary_muscles_json',
        'equipment_json',
        'type',
        'aliases_json',
      ]);
      expect(
        m.events
            .where((e) => e.action == ReportAction.blocked)
            .map((e) => e.blockReason),
        unorderedEquals(BlockReason.values),
      );
      expect({
        for (final e in m.events) ReportEntry('r', e).eventId,
      }, hasLength(m.events.length));
    });

    test('reasons stay independent (R-01)', () {
      final m = map(secondary: '["traps"]', primary: 'Neck');
      expect(
        [for (final b in m.blocks) b.reason],
        [BlockReason.noPrimaryTarget, BlockReason.invalidSecondaryTarget],
      );
    });
  });

  group('consistency with the 3a domain rules', () {
    test('mapped targets of every non-blocked row pass the target rules '
        '(IC-301, 302, 303 aside, 305, 309)', () {
      final ref = ApprovedReference.load();
      final rows = <LegacyExerciseMapping>[
        map(secondary: '["triceps","chest","triceps","traps",1]'),
        map(primary: 'quadriceps', secondary: '["glutes","glutes"]'),
        map(primary: 'lats', secondary: '["biceps","rearDelts","lats"]'),
      ];
      for (final m in rows) {
        final e = exercise(
          'lib-x',
          source: ExerciseSource.user,
          targets: m.targets,
        );
        final codes = validateExercise(
          e,
          ExerciseRuleContext(reference: ref.data),
        ).codes;
        for (final c in ['IC-204', 'IC-301', 'IC-302', 'IC-305', 'IC-309']) {
          expect(codes, isNot(contains(c)), reason: '$c in ${m.targets}');
        }
      }
    });

    test('a no-primary mapping fails IC-204 exactly as the domain rule '
        'says, which is why it is blocked', () {
      final ref = ApprovedReference.load();
      final m = map(primary: 'Neck', secondary: '["triceps"]');
      final codes = validateExercise(
        exercise('lib-x', source: ExerciseSource.user, targets: m.targets),
        ExerciseRuleContext(reference: ref.data),
      ).codes;
      expect(codes, contains('IC-204'));
      expect(codes, isNot(contains('IC-309')));
    });

    test('a fullBody secondary is what the domain reports as IC-304', () {
      final ref = ApprovedReference.load();
      final m = map(primary: 'quadriceps', secondary: '["fullBody"]');
      final findings = validateExercise(
        exercise('lib-x', source: ExerciseSource.user, targets: m.targets),
        ExerciseRuleContext(reference: ref.data),
      );
      expect(findings.codes, contains('IC-304'));
    });
  });

  group(
    'trial fixture categories (seed 20261106 shape, independent count)',
    () {
      // A generator of the same categories as the 3b trial fixture
      // (`test/migration_trial/trial_fixture.dart`), with its own seed. The
      // expectations are counted independently of the mapping.
      const muscles = [
        'chest', 'frontDelts', 'sideDelts', 'rearDelts', 'triceps', 'biceps', //
        'forearms', 'upperBack', 'lats', 'lowerBack', 'abs', 'obliques',
        'glutes', 'abductors', 'adductors', 'quadriceps', 'hamstrings',
        'calves', 'fullBody',
      ];
      const equipmentIds = ['barbell', 'dumbbell', 'cable', 'bench', 'rings'];

      test(
        'every category is reported, reconciled and blocked individually',
        () {
          final r = Random(20261106);
          final rows = <LegacyExerciseRow>[];
          var unmappedPrimary = 0;
          var equalToPrimary = 0;
          var fullBodySecondary = 0;
          var repeatedInList = 0;
          var unmappedSecondary = 0;
          var repeatedEquipment = 0;
          var unknownEquipment = 0;
          var nonArrayEquipment = 0;
          var unknownType = 0;
          var unknownCategory = 0;
          var unreadableAliases = 0;
          for (var i = 0; i < 2000; i++) {
            final roll = r.nextInt(100);
            final primary = roll < 94
                ? muscles[r.nextInt(muscles.length)]
                : const ['rotator cuff', 'Neck', ''][roll % 3];
            final mapped = roll < 94;
            if (!mapped) unmappedPrimary++;
            final secondary = <String>[];
            final n = r.nextInt(4);
            while (secondary.length < n) {
              final s = muscles[r.nextInt(muscles.length - 1)]; // no fullBody
              if (!secondary.contains(s) && s != primary) secondary.add(s);
            }
            final e = r.nextInt(100);
            if (e < 8 && mapped) {
              secondary.add(primary);
              equalToPrimary++;
            } else if (e < 11 && primary != 'fullBody') {
              secondary.add('fullBody');
              fullBodySecondary++;
            } else if (e == 11) {
              secondary.add('traps');
              unmappedSecondary++;
            } else if (e == 12 && secondary.isNotEmpty) {
              secondary.add(secondary.first);
              repeatedInList++;
            }
            final eq = <String>{
              for (var k = 0; k < r.nextInt(3); k++)
                equipmentIds[r.nextInt(equipmentIds.length)],
            }.toList();
            Object? equipmentText = jsonEncode(eq);
            final q = r.nextInt(100);
            if (q < 2 && eq.isNotEmpty) {
              equipmentText = jsonEncode([...eq, eq.first]);
              repeatedEquipment++;
            } else if (q == 2) {
              equipmentText = jsonEncode([...eq, 'hoverboard']);
              unknownEquipment++;
            } else if (q == 3) {
              equipmentText = 'barbell, bench';
              nonArrayEquipment++;
            }
            final k = r.nextInt(100);
            var type = 'weighted';
            var category = 'push';
            var aliases = '["a"]';
            if (k == 0) {
              type = 'Aerobic';
              unknownType++;
            } else if (k == 1) {
              category = 'Stretching';
              unknownCategory++;
            } else if (k == 2) {
              aliases = 'a, b';
              unreadableAliases++;
            } else if (k == 3) {
              aliases = '["a",1]';
              unreadableAliases++;
            }
            rows.add(
              LegacyExerciseRow(
                id: 'ex-${i.toString().padLeft(4, '0')}',
                type: type,
                category: category,
                aliasesJson: aliases,
                primaryMuscle: primary,
                secondaryMusclesJson: jsonEncode(secondary),
                equipmentJson: equipmentText,
                supplied: i < 89 ? 1 : 0,
              ),
            );
          }

          final builder = MigrationReportBuilder(
            ReportRun(
              runId: 'run-fixture',
              trigger: ReportTrigger.migration,
              generatedAt: DateTime.utc(2026, 11, 6),
              appVersion: 'test',
              fromSchemaVersion: 7,
              toSchemaVersion: 8,
            ),
          );
          final mappings = [for (final row in rows) mapLegacyExercise(row)];
          for (final m in mappings) {
            builder.examine(
              table: 'exercises',
              recordId: m.id.value,
              cleanOutcome: ReportCategory.migrated,
              events: m.events,
            );
          }
          final report = builder.build();
          expect(
            reconcileReport(
              report,
              examinedByTable: {'exercises': rows.length},
            ).problems,
            isEmpty,
          );

          int entries(String rule, ReportAction action) => report.entries
              .where((e) => e.event.rule == rule && e.event.action == action)
              .length;
          expect(
            entries('IC-301', ReportAction.quarantined),
            unmappedPrimary + unmappedSecondary,
          );
          expect(entries('IC-204', ReportAction.blocked), unmappedPrimary);
          expect(entries('IC-305', ReportAction.skipped), equalToPrimary);
          expect(entries('ADR-0010', ReportAction.retained), fullBodySecondary);
          expect(entries('IC-302', ReportAction.skipped), repeatedInList);
          expect(entries('IC-307', ReportAction.skipped), repeatedEquipment);
          expect(
            entries('ADR-0008-Q12', ReportAction.blocked),
            unknownEquipment,
          );
          expect(entries('R-02', ReportAction.blocked), nonArrayEquipment);
          expect(
            entries('D04-UNREADABLE-SECONDARY', ReportAction.blocked),
            unmappedSecondary,
          );
          expect(entries('IC-202', ReportAction.quarantined), unknownType);
          expect(entries('IC-203', ReportAction.quarantined), unknownCategory);
          expect(
            entries('D04-UNREADABLE-CLASSIFICATION', ReportAction.blocked),
            {
              for (final m in mappings)
                if (m.blocks.any(
                  (b) => b.reason == BlockReason.invalidClassification,
                ))
                  m.id.value,
            }.length,
          );
          expect(
            entries('D04-UNREADABLE-CLASSIFICATION', ReportAction.blocked),
            unknownType + unknownCategory,
            reason: 'one roll per row: never both',
          );
          expect(
            entries('D04-UNREADABLE-ALIASES', ReportAction.blocked),
            unreadableAliases,
          );
          expect(
            report.entries
                .where(
                  (e) =>
                      e.event.field == 'equipment_json' &&
                      e.event.rule == 'WP8-D3' &&
                      e.event.position == null,
                )
                .length,
            nonArrayEquipment,
          );
          for (final c in [
            unmappedPrimary,
            equalToPrimary,
            fullBodySecondary,
            repeatedInList,
            unmappedSecondary,
            repeatedEquipment,
            unknownEquipment,
            nonArrayEquipment,
            unknownType,
            unknownCategory,
            unreadableAliases,
          ]) {
            expect(
              c,
              greaterThan(0),
              reason: 'the fixture covers each category',
            );
          }

          final counts = report.counts['exercises']!;
          final blockedIds = {
            for (final m in mappings)
              if (m.isBlocked) m.id.value,
          };
          expect(counts.rejectedOrBlocked, blockedIds.length);
          expect(counts.blocked, blockedIds.length);
          expect(counts.rejected, 0);
          expect(counts.recordsWithWarnings, fullBodySecondary);
          expect(counts.warningEntries, fullBodySecondary);
          // Every blocked exercise is listed with its id and reason.
          for (final id in blockedIds) {
            expect(
              report.entries.any(
                (e) =>
                    e.event.recordId == id &&
                    e.event.action == ReportAction.blocked &&
                    e.event.blockReason != null,
              ),
              isTrue,
            );
          }
          // Each examined record in exactly one outcome.
          expect(counts.outcomeTotal, rows.length);
        },
      );
    },
  );

  group('TRN-020 classifier', () {
    ExertionClassification classify(Object? scale, Object? value) =>
        classifyLegacyExertion(setId: 'set-1', scale: scale, value: value);

    test('valid pairs are preserved unchanged with no event', () {
      for (final (s, v) in <(Object?, Object?)>[
        (null, null),
        ('rpe', 1.0),
        ('rpe', 6.5),
        ('rpe', 10.0),
        ('rpe', 8), // an INTEGER read from storage
        ('rir', 0.0),
        ('rir', 5.0),
        ('rir', 3),
      ]) {
        final c = classify(s, v);
        expect(c.isValid, isTrue, reason: '($s, $v)');
        expect(c.scale, s);
        expect(c.value, v);
        expect(c.events, isEmpty);
        expect(c.quarantine, isNull);
        expect(c.outcome, ReportCategory.preserved);
      }
    });

    test('the trial legacy grid is quarantined, cleared and reported, never '
        'rounded', () {
      final grid = <(Object?, Object?, ExertionDefect, List<String>)>[
        ('rpe', 0.0, ExertionDefect.rpeOutsideRule, ['scale', 'value']),
        ('rpe', 0.5, ExertionDefect.rpeOutsideRule, ['scale', 'value']),
        ('rpe', 7.3, ExertionDefect.rpeOutsideRule, ['scale', 'value']),
        ('rpe', 9.75, ExertionDefect.rpeOutsideRule, ['scale', 'value']),
        ('rpe', 10.5, ExertionDefect.rpeOutsideRule, ['scale', 'value']),
        ('rir', 6.0, ExertionDefect.rirOutsideRule, ['scale', 'value']),
        ('rir', 7.5, ExertionDefect.rirOutsideRule, ['scale', 'value']),
        ('rir', 2.5, ExertionDefect.rirOutsideRule, ['scale', 'value']),
        ('rir', 0.5, ExertionDefect.rirOutsideRule, ['scale', 'value']),
        ('rir', -1, ExertionDefect.rirOutsideRule, ['scale', 'value']),
        ('borg', 5.0, ExertionDefect.unknownScale, ['scale', 'value']),
        ('RPE', 8.0, ExertionDefect.unknownScale, ['scale', 'value']),
        ('', 8.0, ExertionDefect.unknownScale, ['scale', 'value']),
        (null, 6.0, ExertionDefect.valueWithoutScale, ['value']),
        ('rir', null, ExertionDefect.scaleWithoutValue, ['scale']),
        ('rpe', null, ExertionDefect.scaleWithoutValue, ['scale']),
        ('rpe', 'eight', ExertionDefect.valueNotNumber, ['scale', 'value']),
        ('rpe', double.nan, ExertionDefect.rpeOutsideRule, ['scale', 'value']),
        (
          'rir',
          double.infinity,
          ExertionDefect.rirOutsideRule,
          ['scale', 'value'],
        ),
      ];
      for (final (s, v, defect, fields) in grid) {
        final c = classify(s, v);
        final why = '($s, $v)';
        expect(c.isValid, isFalse, reason: why);
        expect(c.defect, defect, reason: why);
        expect(c.scale, isNull, reason: why);
        expect(c.value, isNull, reason: why);
        expect(
          [for (final e in c.events) e.field],
          [for (final f in fields) 'exertion_$f'],
          reason: why,
        );
        for (final e in c.events) {
          expect(e.table, 'session_sets');
          expect(e.recordId, 'set-1');
          expect(e.action, ReportAction.cleared);
          expect(e.rule, 'TRN-020');
          expect(e.category, ReportCategory.quarantinedOrUnresolved);
          expect(e.resultingValue, 'null');
          expect(
            e.originalValue,
            encodeStoredValue(e.field == 'exertion_scale' ? s : v),
          );
        }
        final q = c.quarantine!;
        expect(q.table, 'session_sets');
        expect(q.original, {'exertion_scale': s, 'exertion_value': v});
        expect(c.outcome, ReportCategory.quarantinedOrUnresolved);
      }
    });

    test('the original value is kept exactly: 9.75 is never 10 or 9.5', () {
      final c = classify('rpe', 9.75);
      expect(
        c.quarantine!.originalJson,
        '{"exertion_scale":"rpe","exertion_value":9.75}',
      );
      expect(decodeStoredValue(c.events.last.originalValue), 9.75);
    });

    test('property: equals TrainingRules.validExertion for every scale and '
        'value', () {
      final values = <double>[
        for (var i = -300; i <= 1300; i++) i / 100, // -3.00 .. 13.00 by 0.01
        for (var i = -10; i <= 60; i++) i / 4, // quarter steps
        double.nan,
        double.infinity,
        double.negativeInfinity,
        // ignore: prefer_int_literals, -0.0 is not the same value as 0
        -0.0,
        double.minPositive,
        1e-300,
        0.9999999999999999,
        1.0000000000000002,
        4.999999999999999,
        5.000000000000001,
        9.999999999999998,
        10.000000000000002,
        1e300,
      ];
      final r = Random(20261106);
      for (var i = 0; i < 20000; i++) {
        values
          ..add(r.nextDouble() * 14 - 2)
          ..add((r.nextInt(30) - 5) / 2)
          ..add(r.nextInt(12) - 3.0);
      }
      var agreeValid = 0;
      for (final scale in ExertionScale.values) {
        for (final v in values) {
          final e = Exertion(scale: scale, value: v);
          final expected = TrainingRules.validExertion(e);
          expect(exertionMeetsTrn020(e), expected, reason: '$scale $v');
          final c = classify(scale.name, v);
          expect(c.isValid, expected, reason: '$scale $v');
          if (expected) agreeValid++;
        }
      }
      // The grid exercises both outcomes on both scales.
      expect(agreeValid, greaterThan(1000));
    });

    test('property: an INTEGER value classifies like the same REAL value', () {
      for (final scale in ExertionScale.values) {
        for (var i = -5; i <= 15; i++) {
          expect(
            classify(scale.name, i).isValid,
            classify(scale.name, i.toDouble()).isValid,
            reason: '$scale $i',
          );
        }
      }
    });

    test('the classifier is deterministic and needs a set id', () {
      expect(classify('rpe', 7.3).events, classify('rpe', 7.3).events);
      expect(
        () => classifyLegacyExertion(setId: '', scale: null, value: null),
        throwsArgumentError,
      );
    });
  });
}
