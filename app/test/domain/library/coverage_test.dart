import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/coverage_evaluation.dart';
import 'package:repforge/domain/library/coverage_spec.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/training/training.dart' show ExerciseCategory;

import 'support/catalogue_fixtures.dart';

/// A one-group spec for the rule tests.
Map<String, Object?> miniSpec({
  List<Map<String, Object?>>? slots,
  bool bodyweightExempt = false,
  int? slotTotal,
  List<Object?>? sets,
}) {
  final s =
      slots ??
      [
        {
          'id': 'chest.flat',
          'label': 'Flat press',
          'patterns': ['horizontalPush'],
          'discriminator': <Object?>[],
          'min': 2,
          'entries': [
            {
              'name': 'One',
              'equipmentClass': 'freeWeight',
              'laterality': 'bilateral',
              'counted': true,
              'mechanics': 'compound',
            },
            {
              'name': 'Two',
              'equipmentClass': 'machine',
              'laterality': 'bilateral',
              'counted': true,
              'mechanics': 'compound',
            },
          ],
        },
      ];
  return {
    'formatVersion': 1,
    'exerciseAttributesProposed': {
      'attributes': {
        'angle': {
          'values': {'flat': '', 'incline': '', 'decline': ''},
        },
      },
    },
    'metrics': _metrics,
    'groups': [
      {
        'id': 'chest',
        'label': 'Chest',
        'tranche': '5.1',
        'nodes': ['chest'],
        'bodyweightExempt': bodyweightExempt,
        'slotTotal':
            slotTotal ?? s.fold<int>(0, (n, x) => n + (x['min']! as int)),
        'slots': s,
        'derived': {
          'mechanics': {'compound': 2, 'isolation': 0},
          'laterality': {'bilateral': 2, 'unilateralOrAlternating': 0},
          'equipmentClasses': {'freeWeight': 1, 'machine': 1},
          'variationFamilies': 0,
          'classCap': 4.0,
        },
      },
    ],
    'sets': sets ?? <Object?>[],
  };
}

final Map<String, Object?> _metrics = {
  'primariesPerExercise': {
    'meanMaximum': 1.25,
    'shareWithTwoOrMorePrimariesMaximum': 0.2,
  },
  'difficulty': {
    'regionalTranche': {
      'beginner': [0.3, 0.45],
      'intermediate': [0.4, 0.55],
      'advanced': [0.1, 0.2],
    },
    'groupWithTotalAtLeast20': {
      'beginner': 0.2,
      'intermediate': 0.3,
      'advancedShare': 0.05,
      'advancedMinimumExercises': 2,
    },
    'groupWithTotalBelow20': {'beginner': 1, 'intermediate': 1},
    'conditioning': {
      'beginner': [0.3, 0.45],
      'intermediate': [0.4, 0.55],
      'advanced': [0.1, 0.2],
    },
    'mobility': {
      'beginner': [0.5, 0.7],
      'intermediate': [0.25, 0.4],
      'advanced': [0.0, 0.1],
    },
  },
};

void main() {
  late ApprovedReference ref;
  late List<CatalogueExercise> seed;
  late CoverageReport baseline;
  setUpAll(() {
    ref = ApprovedReference.load();
    seed = release2Exercises();
    baseline = evaluateCoverage(
      spec: ref.coverage,
      reference: ref.data,
      exercises: seed,
    );
  });

  group('the approved seed baseline (coverage-matrix.md section 11)', () {
    test(
      '67 of 325 slot fills and 20 of 70 conditioning, power and mobility',
      () {
        expect(baseline.slotRequired, 325);
        expect(baseline.slotFilled, 67);
        expect(baseline.setRequired, 70);
        expect(baseline.setFilled, 20);
      },
    );

    test('baseline per group equals the documented table', () {
      const expected = {
        'chest': (36, 8),
        'upperBack': (25, 5),
        'lats': (20, 6),
        'shoulders': (35, 5),
        'rotatorCuff': (10, 0),
        'neck': (10, 0),
        'biceps': (17, 5),
        'triceps': (24, 5),
        'forearms': (19, 2),
        'glutes': (25, 4),
        'abductors': (3, 1),
        'adductors': (4, 1),
        'hipFlexors': (4, 0),
        'hipExternalRotators': (3, 0),
        'quadriceps': (28, 12),
        'hamstrings': (13, 4),
        'calves': (9, 1),
        'lowerLeg': (4, 0),
        'abs': (18, 6),
        'obliques': (13, 2),
        'lowerBack': (5, 0),
      };
      for (final MapEntry(key: id, value: (required, filled))
          in expected.entries) {
        final g = baseline.group(id)!;
        expect((g.required, g.filled), (required, filled), reason: id);
      }
      expect(expected, hasLength(21));
      final withNone = [
        for (final g in baseline.groups)
          if (g.filled == 0) g.group.id,
      ];
      expect(withNone.toSet(), {
        'rotatorCuff',
        'neck',
        'hipFlexors',
        'hipExternalRotators',
        'lowerLeg',
        'lowerBack',
      });
    });

    test('class baseline per group (FW/M/C/S/B/KB/BW/O) equals the table', () {
      const expected = {
        'chest': '5/1/1/0/0/0/1/0',
        'upperBack': '2/1/1/0/0/0/1/0',
        'lats': '1/1/1/0/1/0/2/0',
        'shoulders': '3/1/1/0/0/0/0/0',
        'biceps': '4/0/1/0/0/0/0/0',
        'triceps': '2/1/1/0/0/0/1/0',
        'forearms': '1/0/0/0/0/0/1/0',
        'glutes': '3/0/0/0/0/0/1/0',
        'abductors': '0/1/0/0/0/0/0/0',
        'adductors': '0/1/0/0/0/0/0/0',
        'quadriceps': '6/3/0/0/0/0/3/0',
        'hamstrings': '2/2/0/0/0/0/0/0',
        'calves': '0/1/0/0/0/0/0/0',
        'abs': '1/0/1/0/0/0/4/0',
        'obliques': '0/0/1/0/0/0/1/0',
      };
      const order = [
        EquipmentClass.freeWeight,
        EquipmentClass.machine,
        EquipmentClass.cable,
        EquipmentClass.smithMachine,
        EquipmentClass.band,
        EquipmentClass.kettlebell,
        EquipmentClass.bodyweight,
        EquipmentClass.other,
      ];
      final byId = {for (final e in seed) e.id: e};
      for (final MapEntry(key: id, value: text) in expected.entries) {
        final counts = {for (final c in order) c: 0};
        for (final eid in baseline.group(id)!.matched) {
          counts.update(
            equipmentClassOf(byId[eid]!, ref.data.equipment),
            (n) => n + 1,
          );
        }
        expect(order.map((c) => counts[c]).join('/'), text, reason: id);
      }
    });

    test(
      'conditioning, power and mobility sets equal the documented table',
      () {
        const expected = {
          'cardio.walkRun': (
            4,
            [
              'lib-incline-walk',
              'lib-outdoor-run',
              'lib-run-400m',
              'lib-treadmill-run',
            ],
          ),
          'cardio.ergometer': (
            5,
            ['lib-cross-trainer', 'lib-rowing-machine', 'lib-stationary-bike'],
          ),
          'cardio.skipping': (3, ['lib-skipping']),
          'conditioning.sled': (2, ['lib-sled-push']),
          'conditioning.ballisticHinge': (1, ['lib-kettlebell-swing']),
          'conditioning.crawl': (3, <String>[]),
          'conditioning.wholeBody': (4, ['lib-burpee']),
          'power.verticalJump': (4, <String>[]),
          'power.horizontalJump': (2, <String>[]),
          'power.lateralJump': (1, <String>[]),
          'power.upperPlyometric': (3, <String>[]),
          'power.explosiveLift': (6, ['lib-clean-and-press']),
          'mobility.dynamic': (6, ['lib-worlds-greatest-stretch']),
          'mobility.spinal': (5, ['lib-cat-cow', 'lib-thoracic-extension']),
          'mobility.softTissue': (0, <String>[]),
        };
        for (final MapEntry(key: id, value: (required, ids))
            in expected.entries) {
          final s = baseline.set(id)!;
          expect(s.required, required, reason: id);
          expect(
            [for (final e in s.exercises) e.value]..sort(),
            ids,
            reason: id,
          );
        }
        final stretch = baseline.set('mobility.static')!;
        expect(stretch.required, 21);
        expect(stretch.filled, 5);
        expect(stretch.exercises, hasLength(5));
      },
    );

    test('the open gaps are listed and statuses are consistent', () {
      expect(baseline.openGaps, isNotEmpty);
      final slotRows = baseline.rowsFor(GapDimension.slot);
      expect(
        slotRows
            .where((r) => r.group == 'chest' && r.item == 'chest.declinePress')
            .single
            .status,
        GapStatus.gap,
      );
      expect(baseline.rows.every((r) => r.gap >= 0), isTrue);
      final totals = baseline.rowsFor(GapDimension.total);
      expect(totals, hasLength(21));
      expect(totals.fold<num>(0, (n, r) => n + (r.actual ?? 0)), 67);
    });

    test('the seed has no variation relationship, so no family is met', () {
      final rows = baseline.rowsFor(GapDimension.variationFamilies);
      expect(rows, isNotEmpty);
      expect(
        rows.every((r) => r.actual == 0 && r.status == GapStatus.gap),
        isTrue,
      );
    });
  });

  group('IC-811 on the specification', () {
    test('the approved specification resolves against the approved lists', () {
      expect(validateCoverageSpec(ref.coverage, ref.data), isEmpty);
    });

    test('unresolved references and arithmetic are reported', () {
      final bad = parseCoverageSpec(
        miniSpec(
          slotTotal: 9,
          slots: [
            {
              'id': 'chest.x',
              'label': 'X',
              'patterns': ['nopePattern', 'upperPush', 'wristFlexion'],
              'discriminator': [
                {
                  'kind': 'attribute',
                  'attribute': 'angle',
                  'values': ['steep'],
                },
                {'kind': 'subTarget', 'node': 'frontDelts', 'role': 'any'},
                {'kind': 'subTarget', 'node': 'nowhere', 'role': 'any'},
              ],
              'min': 3,
              'entries': [
                {
                  'name': 'One',
                  'equipmentClass': 'freeWeight',
                  'laterality': 'bilateral',
                  'counted': true,
                  'mechanics': 'compound',
                },
              ],
            },
          ],
        ),
      );
      final f = validateCoverageSpec(unwrap(bad), ref.data);
      final messages = f.map((x) => x.message).join('\n');
      expect(messages, contains('nopePattern'));
      expect(messages, contains('family'));
      expect(messages, contains('steep'));
      expect(messages, contains('level 4'));
      expect(messages, contains('nowhere'));
      expect(messages, contains('differs from 1 counted'));
      expect(messages, contains('slot total 9'));
      expect(f.every((x) => x.code == 'IC-811'), isTrue);
    });

    test('a retired group node or pattern fails', () {
      final nodes = [
        for (final n in ref.anatomy.nodes)
          if (n.id.value == 'chest') AnatomyNodeAs.retired(n) else n,
      ];
      final patterns = [
        for (final p in ref.patterns.nodes)
          if (p.id.value == 'horizontalPush') PatternAs.retired(p) else p,
      ];
      final f = validateCoverageSpec(
        unwrap(parseCoverageSpec(miniSpec())),
        referenceOf(nodes, patterns, ref.equipment.items),
      );
      expect(
        f.map((x) => x.message),
        containsAll([
          contains('retired node chest'),
          contains('retired pattern horizontalPush'),
        ]),
      );
    });

    test('the attribute vocabulary of the file must equal the domain '
        'vocabulary', () {
      final json = miniSpec();
      final attributes =
          (json['exerciseAttributesProposed']!
                  as Map<String, Object?>)['attributes']!
              as Map<String, Object?>;
      attributes['angle'] = {
        'values': {'flat': '', 'steep': ''},
      };
      attributes['sparkle'] = {
        'values': {'a': ''},
      };
      final f = validateCoverageSpec(unwrap(parseCoverageSpec(json)), ref.data);
      expect(
        f.map((x) => x.message),
        containsAll([contains('values of angle differ'), contains('sparkle')]),
      );
      expect(
        validateCoverageSpec(unwrap(parseCoverageSpec(miniSpec())), ref.data),
        isEmpty,
      );
    });
  });

  group('counting rules', () {
    late CoverageSpec mini;
    setUpAll(() => mini = unwrap(parseCoverageSpec(miniSpec())));

    CoverageReport run(List<CatalogueExercise> list, {CoverageSpec? spec}) =>
        evaluateCoverage(
          spec: spec ?? mini,
          reference: ref.data,
          exercises: list,
        );

    CatalogueExercise press(
      String id, {
      List<ExerciseTarget>? targets,
      ExerciseCategory category = ExerciseCategory.push,
      ExerciseSource source = ExerciseSource.system,
      String pattern = 'horizontalPush',
      DateTime? retiredAt,
    }) => exercise(
      id,
      targets: targets ?? [primary('chest', 0)],
      category: category,
      source: source,
      patterns: [pattern],
      retiredAt: retiredAt,
    );

    test('category rule: only push, pull, legs and core count', () {
      for (final c in [
        ExerciseCategory.fullBody,
        ExerciseCategory.cardio,
        ExerciseCategory.mobility,
      ]) {
        expect(
          run([press('lib-a', category: c)]).slotFilled,
          0,
          reason: c.name,
        );
      }
      for (final c in [
        ExerciseCategory.push,
        ExerciseCategory.pull,
        ExerciseCategory.legs,
        ExerciseCategory.core,
      ]) {
        expect(
          run([press('lib-a', category: c)]).slotFilled,
          1,
          reason: c.name,
        );
      }
    });

    test('primary rule: a secondary target never counts; descendants do', () {
      expect(
        run([
          press(
            'lib-a',
            targets: [primary('triceps', 0), secondary('chest', 1)],
          ),
        ]).slotFilled,
        0,
      );
      expect(
        run([
          press('lib-a', targets: [primary('pectoralisMajor', 0)]),
        ]).slotFilled,
        1,
      );
    });

    test('fullBody never counts toward a group', () {
      expect(
        run([
          press('lib-a', targets: [primary('fullBody', 0)]),
        ]).slotFilled,
        0,
      );
    });

    test('primary-pattern rule: only the first pattern counts', () {
      final secondPattern = exercise(
        'lib-a',
        targets: [primary('chest', 0)],
        patterns: const ['antiExtension', 'horizontalPush'],
      );
      expect(run([secondPattern]).slotFilled, 0);
      expect(run([press('lib-b', pattern: 'verticalPush')]).slotFilled, 0);
    });

    test('retired, user and imported exercises never count', () {
      expect(run([press('lib-a', retiredAt: fixtureTime)]).slotFilled, 0);
      expect(run([press('u1', source: ExerciseSource.user)]).slotFilled, 0);
      expect(run([press('u2', source: ExerciseSource.imported)]).slotFilled, 0);
    });

    test('a slot takes at most its minimum', () {
      final r = run([for (var i = 0; i < 5; i++) press('lib-p$i')]);
      expect(r.slotFilled, 2);
      expect(r.group('chest')!.candidates, hasLength(5));
    });

    test('an exercise fills at most one slot per group (maximum matching)', () {
      final spec = unwrap(
        parseCoverageSpec(
          miniSpec(
            slots: [
              _slot('chest.flat', 1, [
                {
                  'kind': 'attribute',
                  'attribute': 'angle',
                  'values': ['flat'],
                },
              ]),
              _slot('chest.single', 1, [
                {
                  'kind': 'laterality',
                  'values': ['unilateral'],
                },
              ]),
            ],
          ),
        ),
      );
      final flatSingle = press('lib-a').copyWith(
        attributes: {ExerciseAttribute.angle: 'flat'},
        laterality: Laterality.unilateral,
      );
      final flatOnly = press('lib-b')
          .copyWith(attributes: {ExerciseAttribute.angle: 'flat'});
      // Greedy order would give lib-a to flat and leave single empty;
      // maximum matching puts lib-a in single and lib-b in flat.
      final r = run([flatSingle, flatOnly], spec: spec);
      expect(r.slotFilled, 2);
      expect(r.group('chest')!.slotFills['chest.flat'], [xid('lib-b')]);
      expect(r.group('chest')!.slotFills['chest.single'], [xid('lib-a')]);
      // One exercise alone fills one slot only.
      expect(run([flatSingle], spec: spec).slotFilled, 1);
    });

    test('the matching is deterministic whatever the input order', () {
      final a = press('lib-a').copyWith(
        attributes: {ExerciseAttribute.angle: 'flat'},
        laterality: Laterality.unilateral,
      );
      final b = press('lib-b')
          .copyWith(attributes: {ExerciseAttribute.angle: 'flat'});
      final spec = unwrap(
        parseCoverageSpec(
          miniSpec(
            slots: [
              _slot('chest.flat', 1, [
                {
                  'kind': 'attribute',
                  'attribute': 'angle',
                  'values': ['flat'],
                },
              ]),
              _slot('chest.single', 1, [
                {
                  'kind': 'laterality',
                  'values': ['unilateral'],
                },
              ]),
            ],
          ),
        ),
      );
      final one = run([a, b], spec: spec).group('chest')!.slotFills;
      final two = run([b, a], spec: spec).group('chest')!.slotFills;
      expect(one, two);
    });

    group('discriminators', () {
      CoverageSpec withDisc(Map<String, Object?> d) => unwrap(
        parseCoverageSpec(
          miniSpec(
            slots: [
              _slot('chest.s', 1, [d]),
            ],
          ),
        ),
      );

      test('attribute: an unrecorded attribute never matches', () {
        final spec = withDisc({
          'kind': 'attribute',
          'attribute': 'angle',
          'values': ['incline'],
        });
        expect(run([press('lib-a')], spec: spec).slotFilled, 0);
        expect(
          run([
            press('lib-a')
                .copyWith(attributes: {ExerciseAttribute.angle: 'flat'}),
          ], spec: spec).slotFilled,
          0,
        );
        expect(
          run([
            press('lib-a')
                .copyWith(attributes: {ExerciseAttribute.angle: 'incline'}),
          ], spec: spec).slotFilled,
          1,
        );
      });

      test('equipment class: support items are ignored', () {
        final spec = withDisc({
          'kind': 'equipmentClass',
          'values': ['bodyweight'],
        });
        final onlyBench = press('lib-a').copyWith(
          equipment: const [ExerciseEquipment(EquipmentItemId('bench'))],
        );
        final barbell = press('lib-b');
        expect(run([onlyBench], spec: spec).slotFilled, 1);
        expect(run([barbell], spec: spec).slotFilled, 0);
        // The role override: a barbell used as support is bodyweight.
        final inverted = press('lib-c').copyWith(
          equipment: const [
            ExerciseEquipment(
              EquipmentItemId('barbell'),
              roleOverride: EquipmentRole.support,
              overrideNote: 'Fixed bar.',
            ),
          ],
        );
        expect(run([inverted], spec: spec).slotFilled, 1);
      });

      test('laterality and mechanics: unset never matches for mechanics', () {
        final lat = withDisc({
          'kind': 'laterality',
          'values': ['unilateral', 'alternating'],
        });
        expect(
          run([
            press('lib-a').copyWith(laterality: Laterality.alternating),
          ], spec: lat).slotFilled,
          1,
        );
        expect(run([press('lib-a')], spec: lat).slotFilled, 0);
        final mech = withDisc({
          'kind': 'mechanics',
          'values': ['isolation'],
        });
        expect(
          run([
            press('lib-a').copyWith(mechanics: Mechanics.isolation),
          ], spec: mech).slotFilled,
          1,
        );
        expect(
          run([
            press('lib-a').copyWith(mechanics: null),
          ], spec: mech).slotFilled,
          0,
        );
      });

      test('subTarget: role primary or any, node or descendant', () {
        final primaryOnly = withDisc({
          'kind': 'subTarget',
          'node': 'pectoralisMajor',
          'role': 'primary',
        });
        final any = withDisc({
          'kind': 'subTarget',
          'node': 'pectoralisMajor',
          'role': 'any',
        });
        final viaSecondary = press(
          'lib-a',
          targets: [primary('chest', 0), secondary('pectoralisMajor', 1)],
        );
        // chest with its descendant is refused by IC-303; the counting rule
        // only reads roles.
        expect(run([viaSecondary], spec: primaryOnly).slotFilled, 0);
        expect(run([viaSecondary], spec: any).slotFilled, 1);
        expect(
          run([
            press('lib-b', targets: [primary('pectoralisMajor', 0)]),
          ], spec: primaryOnly).slotFilled,
          1,
        );
      });
    });

    test('the set rules: pattern, category, each-group matching', () {
      final spec = unwrap(
        parseCoverageSpec(
          miniSpec(
            sets: [
              {
                'id': 'cardio.x',
                'label': 'X',
                'patterns': ['walkRun'],
                'min': 2,
                'entries': [
                  {'name': 'a', 'counted': true},
                  {'name': 'b', 'counted': true},
                ],
              },
              {
                'id': 'conditioning.hinge',
                'label': 'H',
                'patterns': ['hinge'],
                'min': 1,
                'categories': ['fullBody'],
                'entries': [
                  {'name': 'a', 'counted': true},
                ],
              },
              {
                'id': 'mobility.static',
                'label': 'S',
                'patterns': ['staticStretch'],
                'rule': 'eachGroup',
                'min': 1,
                'entries': [
                  {'name': 'a', 'group': 'chest', 'counted': true},
                ],
              },
            ],
          ),
        ),
      );
      CatalogueExercise run1(
        String id,
        String pattern,
        ExerciseCategory c, [
        String node = 'fullBody',
      ]) => exercise(
        id,
        patterns: [pattern],
        category: c,
        targets: [primary(node, 0)],
        mechanics: null,
      );
      final list = [
        run1('lib-r1', 'walkRun', ExerciseCategory.cardio),
        run1('lib-r2', 'walkRun', ExerciseCategory.cardio),
        run1('lib-r3', 'walkRun', ExerciseCategory.cardio),
        run1(
          'lib-dl',
          'hinge',
          ExerciseCategory.legs,
          'hamstrings',
        ), // category excluded
        run1('lib-ks', 'hinge', ExerciseCategory.fullBody),
        run1('lib-s1', 'staticStretch', ExerciseCategory.mobility, 'chest'),
        run1('lib-s2', 'staticStretch', ExerciseCategory.mobility, 'chest'),
      ];
      final r = evaluateCoverage(
        spec: spec,
        reference: ref.data,
        exercises: list,
      );
      expect(r.set('cardio.x')!.exercises, hasLength(3)); // counted
      expect(r.set('cardio.x')!.filled, 2); // capped at the minimum
      expect(r.set('conditioning.hinge')!.exercises.map((e) => e.value), [
        'lib-ks',
      ]);
      expect(
        r.set('mobility.static')!.exercises,
        hasLength(1),
      ); // one per group
      expect(r.setFilled, 2 + 1 + 1);
      expect(r.setRequired, 4);
    });
  });

  group('class cap, dimensions and metrics', () {
    test(
      'the class cap is max(55 %, 4) and bodyweight is exempt where marked',
      () {
        List<CatalogueExercise> many(int n, List<ExerciseEquipment> eq) => [
          for (var i = 0; i < n; i++)
            exercise(
              'lib-${eq.isEmpty ? 'bw' : 'fw'}$i',
              targets: [primary('chest', 0)],
              equipment: eq,
            ),
        ];
        Map<String, Object?> spec({required bool exempt}) => miniSpec(
          bodyweightExempt: exempt,
          slots: [
            {
              'id': 'chest.s',
              'label': 'S',
              'patterns': ['horizontalPush'],
              'discriminator': <Object?>[],
              'min': 10,
              'entries': [
                for (var i = 0; i < 10; i++)
                  {
                    'name': 'e$i',
                    'equipmentClass': 'freeWeight',
                    'laterality': 'bilateral',
                    'counted': true,
                    'mechanics': 'compound',
                  },
              ],
            },
          ],
        );
        // 10 total => cap max(5.5, 4) = 5.5. Six barbell exercises exceed it.
        var r = evaluateCoverage(
          spec: unwrap(parseCoverageSpec(spec(exempt: false))),
          reference: ref.data,
          exercises: many(6, const [
            ExerciseEquipment(EquipmentItemId('barbell')),
          ]),
        );
        final row = r.rowsFor(GapDimension.diversity).single;
        expect(row.required, closeTo(5.5, 1e-9));
        expect(row.actual, 6);
        expect(row.status, GapStatus.gap);
        expect(row.gap, closeTo(0.5, 1e-9));
        // Five barbell exercises are within the cap.
        r = evaluateCoverage(
          spec: unwrap(parseCoverageSpec(spec(exempt: false))),
          reference: ref.data,
          exercises: many(5, const [
            ExerciseEquipment(EquipmentItemId('barbell')),
          ]),
        );
        expect(r.rowsFor(GapDimension.diversity).single.status, GapStatus.met);
        // Bodyweight over the cap is a gap unless the group is exempt.
        r = evaluateCoverage(
          spec: unwrap(parseCoverageSpec(spec(exempt: false))),
          reference: ref.data,
          exercises: many(8, const []),
        );
        expect(r.rowsFor(GapDimension.diversity).single.status, GapStatus.gap);
        r = evaluateCoverage(
          spec: unwrap(parseCoverageSpec(spec(exempt: true))),
          reference: ref.data,
          exercises: many(8, const []),
        );
        expect(r.rowsFor(GapDimension.diversity).single.status, GapStatus.met);
        // Small groups: the floor of 4 applies.
        final small = evaluateCoverage(
          spec: unwrap(parseCoverageSpec(miniSpec())),
          reference: ref.data,
          exercises: many(2, const [
            ExerciseEquipment(EquipmentItemId('barbell')),
          ]),
        );
        expect(small.rowsFor(GapDimension.diversity).single.required, 4);
      },
    );

    test(
      'mechanics and laterality are counted over the exercises that fill slots',
      () {
        final spec = unwrap(parseCoverageSpec(miniSpec()));
        final r = evaluateCoverage(
          spec: spec,
          reference: ref.data,
          exercises: [
            exercise('lib-a', targets: [primary('chest', 0)]),
            exercise('lib-b', targets: [primary('chest', 0)], mechanics: null),
          ],
        );
        final mech = r
            .rowsFor(GapDimension.mechanics)
            .firstWhere((x) => x.item == 'compound');
        expect(mech.actual, 1);
        expect(
          mech.status,
          GapStatus.notRecorded,
        ); // one filler has no mechanics
        final lat = r
            .rowsFor(GapDimension.laterality)
            .firstWhere((x) => x.item == 'bilateral');
        expect(lat.status, GapStatus.met);
      },
    );

    test('variation families: a root with at least three variations', () {
      final spec = unwrap(
        parseCoverageSpec(
          miniSpec(
            slots: [
              {
                'id': 'chest.s',
                'label': 'S',
                'patterns': ['horizontalPush'],
                'discriminator': <Object?>[],
                'min': 4,
                'entries': [
                  for (var i = 0; i < 4; i++)
                    {
                      'name': 'e$i',
                      'equipmentClass': 'freeWeight',
                      'laterality': 'bilateral',
                      'counted': true,
                      'mechanics': 'compound',
                    },
                ],
              },
            ],
          )..update('groups', (g) {
            final group = (g! as List<Object?>).single! as Map<String, Object?>;
            (group['derived']! as Map<String, Object?>)['variationFamilies'] =
                1;
            return g;
          }),
        ),
      );
      final list = [
        for (final i in ['r', 'a', 'b', 'c'])
          exercise('lib-$i', targets: [primary('chest', 0)]),
      ];
      final roots = {
        xid('lib-a'): xid('lib-r'),
        xid('lib-b'): xid('lib-r'),
        xid('lib-c'): xid('lib-r'),
        xid('lib-r'): xid('lib-r'),
      };
      final met = evaluateCoverage(
        spec: spec,
        reference: ref.data,
        exercises: list,
        familyRoots: roots,
      );
      expect(
        met.rowsFor(GapDimension.variationFamilies).single.status,
        GapStatus.met,
      );
      final fewer = evaluateCoverage(
        spec: spec,
        reference: ref.data,
        exercises: list,
        familyRoots: {
          xid('lib-a'): xid('lib-r'),
          xid('lib-b'): xid('lib-r'),
          xid('lib-r'): xid('lib-r'),
        },
      );
      expect(
        fewer.rowsFor(GapDimension.variationFamilies).single.status,
        GapStatus.gap,
      );
    });

    test('difficulty rules for large and small groups', () {
      final r = baseline;
      // Chest has 36 slots: shares of the 8 counted seed exercises.
      final chest = r
          .rowsFor(GapDimension.difficulty)
          .where((x) => x.group == 'chest')
          .toList();
      expect(chest.map((x) => x.item), [
        'beginner',
        'intermediate',
        'advanced',
      ]);
      expect(chest.last.status, GapStatus.gap); // no advanced in the seed
      // Neck has 10 slots and no exercise: beginner and intermediate gaps.
      final neck = r
          .rowsFor(GapDimension.difficulty)
          .where((x) => x.group == 'neck')
          .toList();
      expect(neck.where((x) => x.status == GapStatus.gap).map((x) => x.item), [
        'beginner',
        'intermediate',
      ]);
      expect(neck.last.status, GapStatus.notApplicable);
    });

    test('primaries per exercise and completeness per tranche', () {
      final rows = baseline.rowsFor(GapDimension.primariesPerExercise);
      final chest = rows.where((x) => x.group == 'tranche 5.1').toList();
      expect(chest.map((x) => x.item), ['mean', 'shareWithTwoOrMore']);
      expect(chest.every((x) => x.status == GapStatus.met), isTrue);
      final two = evaluateCoverage(
        spec: unwrap(parseCoverageSpec(miniSpec())),
        reference: ref.data,
        exercises: [
          for (var i = 0; i < 4; i++)
            exercise(
              'lib-$i',
              targets: [primary('chest', 0), primary('lats', 1)],
            ),
        ],
      );
      final mean = two
          .rowsFor(GapDimension.primariesPerExercise)
          .firstWhere((x) => x.item == 'mean');
      expect(mean.actual, 2);
      expect(mean.status, GapStatus.gap);
      // newExerciseIds restricts the pool.
      final restricted = evaluateCoverage(
        spec: unwrap(parseCoverageSpec(miniSpec())),
        reference: ref.data,
        exercises: [
          exercise('lib-1', targets: [primary('chest', 0), primary('lats', 1)]),
          exercise('lib-2', targets: [primary('chest', 0)]),
        ],
        newExerciseIds: {xid('lib-2')},
      );
      expect(
        restricted
            .rowsFor(GapDimension.primariesPerExercise)
            .firstWhere((x) => x.item == 'mean')
            .actual,
        1,
      );
      final completeness = baseline.rowsFor(GapDimension.completeness);
      expect(completeness.every((x) => x.status == GapStatus.met), isTrue);
    });

    test('parser errors name the path', () {
      final r = parseCoverageSpec({
        'formatVersion': 1,
        'metrics': <String, Object?>{},
        'groups': [<String, Object?>{}],
      });
      expect(r.isErr, isTrue);
      expect(parseCoverageSpec(<Object?>[]).isErr, isTrue);
    });
  });
}

Map<String, Object?> _slot(String id, int min, List<Object?> discriminators) =>
    {
      'id': id,
      'label': id,
      'patterns': ['horizontalPush'],
      'discriminator': discriminators,
      'min': min,
      'entries': [
        for (var i = 0; i < min; i++)
          {
            'name': 'e$i',
            'equipmentClass': 'freeWeight',
            'laterality': 'bilateral',
            'counted': true,
            'mechanics': 'compound',
          },
      ],
    };
