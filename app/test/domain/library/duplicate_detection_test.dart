import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/duplicate_detection.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/exercise_relationship.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/relationship_rules.dart';
import 'package:repforge/domain/training/training.dart'
    show ExerciseCategory, ExerciseType;

import 'support/catalogue_fixtures.dart';

void main() {
  late ApprovedReference ref;
  late List<CatalogueExercise> seed;
  setUpAll(() {
    ref = ApprovedReference.load();
    seed = release2Exercises();
  });

  group('the approved release-2 seed (quality-and-duplicates.md 6.1)', () {
    test(
      'IC-601 0, IC-602 4, IC-603 7 with the documented pairs and scores',
      () {
        final a = detectDuplicates(exercises: seed, reference: ref.data);
        expect(a.pairsIn(DuplicateBand.probable), isEmpty);
        expect(a.pairsIn(DuplicateBand.close), hasLength(4));
        expect(a.pairsIn(DuplicateBand.similar), hasLength(7));

        String pair(DuplicatePair p) =>
            '${p.a}|${p.b}|${p.score.toStringAsFixed(3)}';
        expect(a.pairsIn(DuplicateBand.close).map(pair).toSet(), {
          'lib-back-squat|lib-front-squat|0.925',
          'lib-outdoor-run|lib-run-400m|0.888',
          'lib-hack-squat|lib-leg-press|0.850',
          'lib-bulgarian-split-squat|lib-step-up|0.850',
        });
        expect(a.pairsIn(DuplicateBand.similar).map(pair).toSet(), {
          'lib-back-squat|lib-thruster|0.838',
          'lib-front-squat|lib-thruster|0.838',
          'lib-step-up|lib-walking-lunge|0.830',
          'lib-bulgarian-split-squat|lib-walking-lunge|0.800',
          'lib-bodyweight-squat|lib-wall-sit|0.800',
          'lib-ab-wheel|lib-plank|0.800',
          'lib-dumbbell-rdl|lib-romanian-deadlift|0.750',
        });
        // Findings carry the codes and severities.
        expect(a.findings.withCode('IC-602'), hasLength(4));
        expect(a.findings.withCode('IC-603'), hasLength(7));
        expect(
          a.findings
              .withCode('IC-602')
              .every((f) => f.severity == Severity.warning),
          isTrue,
        );
        expect(
          a.findings
              .withCode('IC-603')
              .every((f) => f.severity == Severity.info),
          isTrue,
        );
        expect(a.findings.codes, isNot(contains('IC-411')));
      },
    );

    test('IC-412: the pre-X2 worklist is the documented 16 pairs', () {
      final a = detectDuplicates(
        exercises: seed,
        reference: ref.data,
        options: const DuplicateOptions(tokenGate: TokenGateRule.always),
      );
      expect(a.familyLinkCandidates, hasLength(16));
      String pair(({ExerciseId a, ExerciseId b, double score}) p) =>
          '${p.a}|${p.b}|${p.score.toStringAsFixed(3)}';
      expect(a.familyLinkCandidates.map(pair).toSet(), {
        'lib-bench-press|lib-incline-bench-press|0.963',
        'lib-leg-curl|lib-lying-leg-curl|0.925',
        'lib-db-bench-press|lib-incline-db-press|0.925',
        'lib-dumbbell-rdl|lib-romanian-deadlift|0.750',
        'lib-assisted-pull-up|lib-band-assisted-pull-up|0.740',
        'lib-bench-press|lib-db-bench-press|0.725',
        'lib-cable-fly|lib-db-fly|0.725',
        'lib-barbell-curl|lib-db-curl|0.725',
        'lib-barbell-curl|lib-cable-curl|0.725',
        'lib-cable-curl|lib-db-curl|0.725',
        'lib-plank|lib-weighted-plank|0.725',
        'lib-db-bench-press|lib-incline-bench-press|0.710',
        'lib-incline-bench-press|lib-incline-db-press|0.710',
        'lib-assisted-pull-up|lib-pull-up|0.675',
        'lib-band-assisted-pull-up|lib-pull-up|0.675',
        'lib-cable-crunch|lib-crunch|0.675',
      });
    });

    test('IC-412 literal X2 rule (default) adds 14 pairs, 30 in all', () {
      final x2 = detectDuplicates(exercises: seed, reference: ref.data);
      final old = detectDuplicates(
        exercises: seed,
        reference: ref.data,
        options: const DuplicateOptions(tokenGate: TokenGateRule.always),
      );
      expect(x2.familyLinkCandidates, hasLength(30));
      String key(({ExerciseId a, ExerciseId b, double score}) p) =>
          '${p.a}|${p.b}';
      final added = {for (final p in x2.familyLinkCandidates) key(p)}
        ..removeAll({for (final p in old.familyLinkCandidates) key(p)});
      expect(added, hasLength(14));
      // Of the 14, only the three the review named differ by attributes
      // alone; the other 11 also differ in load items.
      expect(
        added,
        containsAll([
          'lib-deadlift|lib-sumo-deadlift',
          'lib-chin-up|lib-pull-up',
          'lib-db-curl|lib-hammer-curl',
        ]),
      );
      // IC-601..603 are unaffected by X2.
      expect(x2.pairs.length, old.pairs.length);
    });

    test('narrow X2 rule (attributes differ, load items equal): 19 pairs', () {
      String key(({ExerciseId a, ExerciseId b, double score}) p) =>
          '${p.a}|${p.b}';
      final base = {
        for (final p in detectDuplicates(
          exercises: seed,
          reference: ref.data,
          options: const DuplicateOptions(tokenGate: TokenGateRule.always),
        ).familyLinkCandidates)
          key(p),
      };
      final narrow = detectDuplicates(
        exercises: seed,
        reference: ref.data,
        options: const DuplicateOptions(
          tokenGate: TokenGateRule.whenAttributesDifferAndLoadsEqual,
        ),
      );
      expect(narrow.familyLinkCandidates, hasLength(19));
      expect(
        {for (final p in narrow.familyLinkCandidates) key(p)}.difference(base),
        {
          'lib-deadlift|lib-sumo-deadlift',
          'lib-chin-up|lib-pull-up',
          'lib-db-curl|lib-hammer-curl',
        },
      );
    });

    test('the assisted dip stays hidden under every reading', () {
      for (final rule in TokenGateRule.values) {
        final a = detectDuplicates(
          exercises: seed,
          reference: ref.data,
          options: DuplicateOptions(tokenGate: rule),
        );
        expect(
          a.familyLinkCandidates.any(
            (p) =>
                p.a.value == 'lib-assisted-dip' ||
                p.b.value == 'lib-assisted-dip',
          ),
          isFalse,
          reason: rule.name,
        );
      }
    });

    test(
      'attribute-distinguished pairs are not IC-601..603 but remain IC-412',
      () {
        final a = detectDuplicates(exercises: seed, reference: ref.data);
        final flagged = {for (final p in a.pairs) '${p.a}|${p.b}'};
        expect(
          flagged.contains('lib-bench-press|lib-incline-bench-press'),
          isFalse,
        );
        expect(flagged.contains('lib-chin-up|lib-pull-up'), isFalse);
        expect(
          a.familyLinkCandidates.any(
            (p) =>
                p.a.value == 'lib-bench-press' &&
                p.b.value == 'lib-incline-bench-press',
          ),
          isTrue,
        );
      },
    );

    test('pairs are only scored within one primary pattern', () {
      final a = detectDuplicates(exercises: seed, reference: ref.data);
      expect(a.pairsCompared, lessThan(89 * 88 ~/ 2));
      expect(a.pairsCompared, greaterThan(100));
    });

    test('the result is deterministic and sorted', () {
      final one = detectDuplicates(exercises: seed, reference: ref.data);
      final two = detectDuplicates(
        exercises: seed.reversed.toList(),
        reference: ref.data,
      );
      expect(
        [for (final f in one.findings) f.toString()],
        [for (final f in two.findings) f.toString()],
      );
    });
  });

  group('signature and score', () {
    test('ancestor lift: a head equals its group', () {
      final head = exercise(
        'lib-a',
        name: 'Side raise',
        targets: [primary('sideDelts', 0)],
        patterns: const ['shoulderAbduction'],
      );
      final group = exercise(
        'lib-b',
        name: 'Side raise',
        targets: [primary('shoulders', 0)],
        patterns: const ['shoulderAbduction'],
      );
      final sa = StructuralSignature.of(head, ref.data);
      final sb = StructuralSignature.of(group, ref.data);
      expect(sa.liftedPrimaries, sb.liftedPrimaries);
      expect(sa.scoreWith(sb), closeTo(1.0, 1e-9));
    });

    test('support items are ignored', () {
      final withBench = exercise(
        'lib-a',
        name: 'Press',
        equipment: const [
          ExerciseEquipment(EquipmentItemId('dumbbell')),
          ExerciseEquipment(EquipmentItemId('bench')),
        ],
      );
      final noBench = exercise(
        'lib-b',
        name: 'Press',
        equipment: const [ExerciseEquipment(EquipmentItemId('dumbbell'))],
      );
      expect(StructuralSignature.of(withBench, ref.data).loadItems, {
        const EquipmentItemId('dumbbell'),
      });
      expect(
        StructuralSignature.of(
          withBench,
          ref.data,
        ).scoreWith(StructuralSignature.of(noBench, ref.data)),
        closeTo(1.0, 1e-9),
      );
    });

    test('weights: each term contributes its share', () {
      final base = exercise('lib-a', name: 'Alpha one');
      final sa = StructuralSignature.of(base, ref.data);
      // Different everything except nothing shared: names, equipment, etc.
      final other = exercise(
        'lib-b',
        name: 'Zulu two',
        category: ExerciseCategory.pull,
        type: ExerciseType.bodyweight,
        targets: [primary('lats', 0)],
        patterns: const ['verticalPull'],
        equipment: const [ExerciseEquipment(EquipmentItemId('cable'))],
        mechanics: Mechanics.isolation,
        laterality: Laterality.unilateral,
      );
      expect(
        sa.scoreWith(StructuralSignature.of(other, ref.data)),
        closeTo(0, 1e-9),
      );
      // Only the pattern in common adds 0.20.
      final samePattern = other.copyWith(
        patterns: [const MovementPatternId('horizontalPush')],
      );
      expect(
        sa.scoreWith(StructuralSignature.of(samePattern, ref.data)),
        closeTo(0.20, 1e-9),
      );
      // Only laterality and mechanics in common add 0.05 each.
      final lat = other.copyWith(
        laterality: Laterality.bilateral,
        mechanics: Mechanics.compound,
      );
      expect(
        sa.scoreWith(StructuralSignature.of(lat, ref.data)),
        closeTo(0.10, 1e-9),
      );
    });

    test('an unrecorded attribute never distinguishes a pair', () {
      final a = exercise(
        'lib-a',
        attributes: {ExerciseAttribute.angle: 'flat'},
      );
      final b = exercise('lib-b');
      final c = exercise(
        'lib-c',
        attributes: {ExerciseAttribute.angle: 'incline'},
      );
      expect(
        StructuralSignature.of(
          a,
          ref.data,
        ).distinguishedFrom(StructuralSignature.of(b, ref.data)),
        isFalse,
      );
      expect(
        StructuralSignature.of(
          a,
          ref.data,
        ).distinguishedFrom(StructuralSignature.of(c, ref.data)),
        isTrue,
      );
      expect(
        StructuralSignature.of(
          b,
          ref.data,
        ).distinguishedFrom(StructuralSignature.of(c, ref.data)),
        isFalse,
      );
    });
  });

  group('thresholds and clearing', () {
    CatalogueExercise e(String id, String name) => exercise(id, name: name);

    test('identical structure is a probable duplicate (IC-601)', () {
      final a = detectDuplicates(
        exercises: [e('lib-a', 'Bench press'), e('lib-b', 'Bench press')],
        reference: ref.data,
      );
      expect(a.pairs.single.band, DuplicateBand.probable);
      expect(a.pairs.single.score, closeTo(1.0, 1e-9));
      expect(a.findings.withCode('IC-601').single.severity, Severity.warning);
    });

    test('thresholds are options', () {
      final pair = [e('lib-a', 'Bench press'), e('lib-b', 'Bench press')];
      final strict = detectDuplicates(
        exercises: pair,
        reference: ref.data,
        options: const DuplicateOptions(
          probableThreshold: 1.01,
          closeThreshold: 1.01,
          similarThreshold: 1.01,
        ),
      );
      expect(strict.pairs, isEmpty);
    });

    test('a relationship clears a pair', () {
      final a = detectDuplicates(
        exercises: [e('lib-a', 'Bench press'), e('lib-b', 'Bench press')],
        reference: ref.data,
        relationships: [
          ExerciseRelationship(
            from: xid('lib-b'),
            to: xid('lib-a'),
            kind: RelationshipKind.variationOf,
            source: ExerciseSource.user,
          ),
        ],
      );
      expect(a.pairs.single.cleared, isTrue);
      expect(a.pairs.single.disposition, 'relationship');
      expect(a.findings.single.disposition, 'relationship');
    });

    test('a recorded disposition clears a pair', () {
      final a = detectDuplicates(
        exercises: [e('lib-a', 'Bench press'), e('lib-b', 'Bench press')],
        reference: ref.data,
        dispositions: {
          duplicatePairKey(xid('lib-b'), xid('lib-a')): 'distinct (AG-0002)',
        },
      );
      expect(a.pairs.single.disposition, 'distinct (AG-0002)');
    });

    test('retired exercises are not compared', () {
      final a = detectDuplicates(
        exercises: [
          e('lib-a', 'Bench press'),
          exercise('lib-b', name: 'Bench press', retiredAt: fixtureTime),
        ],
        reference: ref.data,
      );
      expect(a.pairs, isEmpty);
    });

    test('exercises without a pattern are not paired', () {
      final a = detectDuplicates(
        exercises: [
          exercise(
            'u1',
            name: 'Same',
            source: ExerciseSource.user,
            patterns: const [],
          ),
          exercise(
            'u2',
            name: 'Same',
            source: ExerciseSource.user,
            patterns: const [],
          ),
        ],
        reference: ref.data,
      );
      expect(a.pairsCompared, 0);
    });
  });

  group('IC-411 and IC-412 rules', () {
    test(
      'IC-411 a unilateral entry with a bilateral twin and no counterpart link',
      () {
        final bi = exercise('lib-row', name: 'Dumbbell row');
        final uni = exercise(
          'lib-row-one',
          name: 'One-arm dumbbell row',
          laterality: Laterality.unilateral,
        );
        final a = detectDuplicates(exercises: [bi, uni], reference: ref.data);
        expect(a.findings.withCode('IC-411').single.severity, Severity.warning);
        final linked = detectDuplicates(
          exercises: [bi, uni],
          reference: ref.data,
          relationships: [
            ExerciseRelationship(
              from: xid('lib-row'),
              to: xid('lib-row-one'),
              kind: RelationshipKind.unilateralCounterpartOf,
              source: ExerciseSource.user,
            ),
          ],
        );
        expect(linked.findings.codes, isNot(contains('IC-411')));
        // Different load items: not a twin by structure.
        final other = exercise(
          'lib-row-cable',
          name: 'One-arm cable row',
          laterality: Laterality.unilateral,
          equipment: const [ExerciseEquipment(EquipmentItemId('cable'))],
        );
        expect(
          detectDuplicates(
            exercises: [bi, other],
            reference: ref.data,
          ).findings.codes,
          isNot(contains('IC-411')),
        );
        // Two unilateral entries are not a twin pair.
        final alt = exercise(
          'lib-row-alt',
          name: 'Alternating dumbbell row',
          laterality: Laterality.alternating,
        );
        expect(
          detectDuplicates(
            exercises: [uni, alt],
            reference: ref.data,
          ).findings.codes,
          isNot(contains('IC-411')),
        );
      },
    );

    test(
      'IC-412 needs the name tokens unless a recorded attribute differs (X2)',
      () {
        final a = exercise(
          'lib-a',
          name: 'Alpha lift',
          equipment: const [ExerciseEquipment(EquipmentItemId('barbell'))],
        );
        final b = exercise(
          'lib-b',
          name: 'Zulu thing',
          equipment: const [ExerciseEquipment(EquipmentItemId('dumbbell'))],
        );
        expect(
          detectDuplicates(
            exercises: [a, b],
            reference: ref.data,
          ).findings.codes,
          isNot(contains('IC-412')),
        );
        final withAttr = [
          a.copyWith(attributes: {ExerciseAttribute.grip: 'pronated'}),
          b.copyWith(attributes: {ExerciseAttribute.grip: 'supinated'}),
        ];
        expect(
          detectDuplicates(
            exercises: withAttr,
            reference: ref.data,
          ).findings.codes,
          contains('IC-412'),
        );
        expect(
          detectDuplicates(
            exercises: withAttr,
            reference: ref.data,
            options: const DuplicateOptions(tokenGate: TokenGateRule.always),
          ).findings.codes,
          isNot(contains('IC-412')),
        );
        // Same load items, same attributes: nothing to link.
        final same = [
          a,
          a.copyWith(
            id: xid('lib-c'),
            names: ExerciseNames.english('Alpha lift'),
          ),
        ];
        expect(
          detectDuplicates(exercises: same, reference: ref.data).findings.codes,
          isNot(contains('IC-412')),
        );
      },
    );

    test('IC-412 is not raised inside one family', () {
      final a = exercise(
        'lib-a',
        name: 'Bench press',
        equipment: const [ExerciseEquipment(EquipmentItemId('barbell'))],
      );
      final b = exercise(
        'lib-b',
        name: 'Bench press dumbbell',
        equipment: const [ExerciseEquipment(EquipmentItemId('dumbbell'))],
      );
      expect(
        detectDuplicates(exercises: [a, b], reference: ref.data).findings.codes,
        contains('IC-412'),
      );
      final rels = [
        ExerciseRelationship(
          from: xid('lib-b'),
          to: xid('lib-a'),
          kind: RelationshipKind.variationOf,
          source: ExerciseSource.user,
        ),
      ];
      final analysis = analyseRelationships([a, b], rels);
      final cleared = detectDuplicates(
        exercises: [a, b],
        reference: ref.data,
        relationships: rels,
        familyRoots: analysis.familyRoots,
      );
      expect(cleared.findings.codes, isNot(contains('IC-412')));
    });

    test('a different laterality or mechanics is not IC-412', () {
      final a = exercise(
        'lib-a',
        name: 'Bench press',
        equipment: const [ExerciseEquipment(EquipmentItemId('barbell'))],
      );
      final b = exercise(
        'lib-b',
        name: 'Bench press dumbbell',
        laterality: Laterality.unilateral,
        equipment: const [ExerciseEquipment(EquipmentItemId('dumbbell'))],
      );
      final c = exercise(
        'lib-c',
        name: 'Bench press cable',
        mechanics: Mechanics.isolation,
        equipment: const [ExerciseEquipment(EquipmentItemId('cable'))],
      );
      expect(
        detectDuplicates(exercises: [a, b], reference: ref.data).findings.codes,
        isNot(contains('IC-412')),
      );
      expect(
        detectDuplicates(exercises: [a, c], reference: ref.data).findings.codes,
        isNot(contains('IC-412')),
      );
    });
  });
}
