import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/exercise_relationship.dart';
import 'package:repforge/domain/library/exercise_rules.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/training/training.dart'
    show ExerciseCategory, ExerciseType;

import 'support/catalogue_fixtures.dart';

void main() {
  late ApprovedReference ref;
  late ExerciseRuleContext ctx;
  setUpAll(() {
    ref = ApprovedReference.load();
    ctx = ExerciseRuleContext(
      reference: ref.data,
      providers: {ProviderId.repforge},
    );
  });

  List<Finding> check(CatalogueExercise e, [ExerciseRuleContext? c]) =>
      validateExercise(e, c ?? ctx);

  test('a complete system exercise has no finding', () {
    expect(check(exercise('lib-ok')), isEmpty);
  });

  group('identity and revision (IC-101, IC-103)', () {
    test('id pattern and length', () {
      expect(check(exercise('lib-good-id-2')).codes, isNot(contains('IC-101')));
      for (final bad in [
        'bench',
        'lib-Bench',
        'lib--x',
        'lib-x_y',
        'lib-${'a' * 50}',
      ]) {
        expect(check(exercise(bad)).codes, contains('IC-101'), reason: bad);
      }
      expect(
        check(exercise('lib-${'a' * 44}')).codes,
        isNot(contains('IC-101')),
      );
    });

    test('revision must be 1 or more for a system exercise only', () {
      expect(check(exercise('lib-x', revision: 0)).codes, contains('IC-103'));
      expect(
        check(exercise('lib-x', revision: 2)).codes,
        isNot(contains('IC-103')),
      );
      // User ids need no pattern and no revision.
      final user = exercise('3f2c0b3e-uuid', source: ExerciseSource.user);
      expect(check(user).codes, isNot(contains('IC-101')));
      expect(check(user).codes, isNot(contains('IC-103')));
    });
  });

  group('completeness (IC-2xx)', () {
    test('IC-201 name length', () {
      expect(check(exercise('lib-x', name: '')).codes, contains('IC-201'));
      expect(
        check(exercise('lib-x', name: 'a' * 61)).codes,
        contains('IC-201'),
      );
      expect(
        check(exercise('lib-x', name: 'a' * 60)).codes,
        isNot(contains('IC-201')),
      );
    });

    test('IC-204 at least one primary target', () {
      final none = exercise('lib-x', targets: [secondary('chest', 0)]);
      expect(check(none).codes, contains('IC-204'));
      expect(
        check(exercise('lib-x', targets: const [])).codes,
        contains('IC-204'),
      );
      final user = exercise(
        'u1',
        source: ExerciseSource.user,
        targets: const [],
      );
      expect(check(user).codes, contains('IC-204'));
    });

    test(
      'IC-205 pattern required; warning before a tranche is in progress',
      () {
        final e = exercise('lib-x', patterns: const []);
        expect(check(e).withCode('IC-205').single.severity, Severity.error);
        final soft = ExerciseRuleContext(
          reference: ref.data,
          patternsMissingIsError: false,
        );
        expect(
          check(e, soft).withCode('IC-205').single.severity,
          Severity.warning,
        );
      },
    );

    test('IC-207 mechanics', () {
      expect(
        check(exercise('lib-x', mechanics: null))
            .withCode('IC-207')
            .single
            .severity,
        Severity.error,
      );
      final cardio = exercise(
        'lib-x',
        category: ExerciseCategory.cardio,
        type: ExerciseType.cardio,
        targets: [primary('fullBody', 0)],
        patterns: const ['walkRun'],
        equipment: const [],
        mechanics: null,
      );
      expect(check(cardio).withCode('IC-207').single.severity, Severity.info);
      final mobility = exercise(
        'lib-x',
        category: ExerciseCategory.mobility,
        patterns: const ['staticStretch'],
        mechanics: null,
      );
      expect(check(mobility).withCode('IC-207').single.severity, Severity.info);
      // A recorded value is never an issue.
      expect(
        check(cardio.copyWith(mechanics: Mechanics.compound)).codes,
        isNot(contains('IC-207')),
      );
    });

    test('IC-208 and IC-209', () {
      expect(
        check(exercise('lib-x', laterality: null)).codes,
        contains('IC-208'),
      );
      expect(
        check(exercise('lib-x', difficulty: null)).codes,
        contains('IC-209'),
      );
    });

    test('IC-211 empty aliases warn', () {
      final f = check(exercise('lib-x', aliases: const [])).withCode('IC-211');
      expect(f.single.severity, Severity.warning);
    });

    test('IC-212 provider registered and author recorded', () {
      expect(check(exercise('lib-x', author: null)).codes, contains('IC-212'));
      expect(check(exercise('lib-x', author: '  ')).codes, contains('IC-212'));
      final other = ExerciseRuleContext(
        reference: ref.data,
        providers: {const ProviderId('other')},
      );
      expect(check(exercise('lib-x'), other).codes, contains('IC-212'));
      expect(
        check(exercise('lib-x').copyWith(providerId: null)).codes,
        contains('IC-212'),
      );
    });

    test('user exercises may be partly classified', () {
      final user = exercise(
        'u1',
        source: ExerciseSource.user,
        patterns: const [],
        mechanics: null,
        laterality: null,
        difficulty: null,
        aliases: const [],
        author: null,
      );
      expect(check(user), isEmpty);
    });
  });

  group('targets (IC-301 to IC-310)', () {
    test('IC-301 unknown node', () {
      expect(
        check(exercise('lib-x', targets: [primary('nowhere', 0)])).codes,
        contains('IC-301'),
      );
    });

    test('IC-302 a node twice, IC-305 a primary repeated as secondary', () {
      final twice = exercise(
        'lib-x',
        targets: [
          primary('chest', 0),
          secondary('triceps', 1),
          secondary('triceps', 2),
        ],
      );
      expect(check(twice).codes, contains('IC-302'));
      final both = exercise(
        'lib-x',
        targets: [primary('chest', 0), secondary('chest', 1)],
      );
      expect(check(both).codes, contains('IC-305'));
      expect(check(both).codes, isNot(contains('IC-302')));
      final twoPrimary = exercise(
        'lib-x',
        targets: [primary('chest', 0), primary('chest', 1)],
      );
      expect(check(twoPrimary).codes, contains('IC-302'));
    });

    test('IC-303 a node with its ancestor or descendant', () {
      final withDescendant = exercise(
        'lib-x',
        targets: [primary('chest', 0), secondary('pectoralisMajor', 1)],
      );
      expect(check(withDescendant).codes, contains('IC-303'));
      final withAncestor = exercise(
        'lib-x',
        targets: [primary('sideDelts', 0), secondary('shoulders', 1)],
      );
      expect(check(withAncestor).codes, contains('IC-303'));
      final siblings = exercise(
        'lib-x',
        targets: [primary('frontDelts', 0), secondary('sideDelts', 1)],
      );
      expect(check(siblings).codes, isNot(contains('IC-303')));
    });

    test('IC-309 ordinals contiguous from 0', () {
      final gap = exercise(
        'lib-x',
        targets: [primary('chest', 0), secondary('triceps', 2)],
      );
      expect(check(gap).codes, contains('IC-309'));
      final fromOne = exercise('lib-x', targets: [primary('chest', 1)]);
      expect(check(fromOne).codes, contains('IC-309'));
      final shuffled = exercise(
        'lib-x',
        targets: [secondary('triceps', 0), primary('chest', 1)],
      );
      expect(check(shuffled).codes, isNot(contains('IC-309')));
    });

    test('IC-310 more than 3 primaries or 6 secondaries warns', () {
      final many = exercise(
        'lib-x',
        targets: [
          primary('chest', 0),
          primary('lats', 1),
          primary('abs', 2),
          primary('glutes', 3),
        ],
      );
      expect(check(many).withCode('IC-310').single.severity, Severity.warning);
      final sec = exercise(
        'lib-x',
        targets: [
          primary('chest', 0),
          for (var i = 0; i < 7; i++)
            secondary(
              [
                'triceps',
                'lats',
                'abs',
                'glutes',
                'calves',
                'biceps',
                'obliques',
              ][i],
              i + 1,
            ),
        ],
      );
      expect(check(sec).codes, contains('IC-310'));
      final ok = exercise(
        'lib-x',
        targets: [primary('chest', 0), primary('lats', 1), primary('abs', 2)],
      );
      expect(check(ok).codes, isNot(contains('IC-310')));
    });
  });

  group('fullBody (IC-304, ADR-0010)', () {
    CatalogueExercise cardio(
      List<ExerciseTarget> targets, {
      ExerciseSource source = ExerciseSource.system,
    }) => exercise(
      source == ExerciseSource.system ? 'lib-run' : 'u-run',
      source: source,
      category: ExerciseCategory.cardio,
      type: ExerciseType.cardio,
      patterns: const ['walkRun'],
      equipment: const [],
      mechanics: null,
      targets: targets,
    );

    test('the single primary of a conditioning exercise is allowed', () {
      expect(
        check(cardio([primary('fullBody', 0)])),
        anyOf(
          isEmpty,
          everyElement(predicate<Finding>((f) => f.code == 'IC-207')),
        ),
      );
      expect(
        check(cardio([primary('fullBody', 0)])).codes,
        isNot(contains('IC-304')),
      );
    });

    test(
      'as a secondary: error for system content, warning for user content',
      () {
        final targets = [primary('calves', 0), secondary('fullBody', 1)];
        expect(
          check(cardio(targets)).withCode('IC-304').single.severity,
          Severity.error,
        );
        expect(
          check(cardio(targets, source: ExerciseSource.user))
              .withCode('IC-304')
              .single
              .severity,
          Severity.warning,
        );
        expect(
          check(cardio(targets, source: ExerciseSource.imported))
              .withCode('IC-304')
              .single
              .severity,
          Severity.warning,
        );
      },
    );

    test('beside an anatomical primary: error (system) / warning (user)', () {
      final targets = [primary('fullBody', 0), primary('quadriceps', 1)];
      expect(
        check(cardio(targets)).withCode('IC-304').single.severity,
        Severity.error,
      );
      expect(
        check(cardio(targets, source: ExerciseSource.user))
            .withCode('IC-304')
            .single
            .severity,
        Severity.warning,
      );
    });

    test('IC-314: fullBody with a push category warns', () {
      final e = exercise('lib-x', targets: [primary('fullBody', 0)]);
      expect(check(e).withCode('IC-314').single.severity, Severity.warning);
      expect(check(e).codes, isNot(contains('IC-304')));
    });

    test('a stored fullBody secondary on a user exercise keeps working', () {
      final user = exercise(
        'u1',
        source: ExerciseSource.user,
        category: ExerciseCategory.cardio,
        type: ExerciseType.cardio,
        targets: [primary('calves', 0), secondary('fullBody', 1)],
        patterns: const [],
      );
      expect(check(user).where((f) => f.severity == Severity.error), isEmpty);
    });
  });

  group('functional double tags (ED-501)', () {
    test(
      'two primaries of a functional pair are refused (system), warned (user)',
      () {
        final pair = [primary('gluteusMedius', 0), primary('abductors', 1)];
        expect(
          check(exercise('lib-x', targets: pair))
              .withCode('ED-501')
              .single
              .severity,
          Severity.error,
        );
        expect(
          check(exercise('u1', source: ExerciseSource.user, targets: pair))
              .withCode('ED-501')
              .single
              .severity,
          Severity.warning,
        );
      },
    );

    test('one primary and one secondary is the rule', () {
      expect(
        check(
          exercise(
            'lib-x',
            targets: [primary('abductors', 0), secondary('gluteusMedius', 1)],
          ),
        ).codes,
        isNot(contains('ED-501')),
      );
      expect(
        check(
          exercise(
            'lib-x',
            targets: [primary('gluteusMedius', 0), secondary('abductors', 1)],
          ),
        ).codes,
        isNot(contains('ED-501')),
      );
    });

    test('the other pairs and descendants', () {
      expect(
        check(
          exercise(
            'lib-x',
            targets: [primary('rectusFemoris', 0), primary('hipFlexors', 1)],
          ),
        ).codes,
        contains('ED-501'),
      );
      expect(
        check(
          exercise(
            'lib-x',
            targets: [
              primary('trapeziusUpper', 0),
              primary('neckExtensors', 1),
            ],
          ),
        ).codes,
        contains('ED-501'),
      );
      // A descendant of the muscle counts as the muscle.
      expect(
        check(
          exercise(
            'lib-x',
            targets: [primary('rectusFemoris', 0), primary('iliopsoas', 1)],
          ),
        ).codes,
        contains('ED-501'),
      );
    });
  });

  group('patterns and categories (IC-306, IC-311, IC-312)', () {
    test('IC-306 unknown pattern and a family used as a pattern', () {
      expect(
        check(exercise('lib-x', patterns: const ['nope'])).codes,
        contains('IC-306'),
      );
      expect(
        check(exercise('lib-x', patterns: const ['upperPush'])).codes,
        contains('IC-306'),
      );
    });

    test('IC-311 category and pattern family', () {
      final off = exercise('lib-x', category: ExerciseCategory.legs);
      expect(check(off).withCode('IC-311').single.severity, Severity.warning);
      expect(check(exercise('lib-x')).codes, isNot(contains('IC-311')));
      // Accepted pairs from the pattern guide.
      final swing = exercise(
        'lib-x',
        category: ExerciseCategory.fullBody,
        patterns: const ['hinge'],
      );
      expect(check(swing).codes, contains('IC-311'));
    });

    test('IC-312 cardio logging with a strength pattern', () {
      expect(
        check(exercise('lib-x', type: ExerciseType.cardio)).codes,
        contains('IC-312'),
      );
      expect(
        check(
          exercise(
            'lib-x',
            type: ExerciseType.cardio,
            patterns: const ['ergometer'],
            category: ExerciseCategory.cardio,
          ),
        ).codes,
        isNot(contains('IC-312')),
      );
    });
  });

  group('equipment (IC-307, IC-315)', () {
    test('IC-307 unknown or repeated item', () {
      expect(
        check(
          exercise(
            'lib-x',
            equipment: const [ExerciseEquipment(EquipmentItemId('hoverboard'))],
          ),
        ).codes,
        contains('IC-307'),
      );
      expect(
        check(
          exercise(
            'lib-x',
            equipment: const [
              ExerciseEquipment(EquipmentItemId('barbell')),
              ExerciseEquipment(EquipmentItemId('barbell')),
            ],
          ),
        ).codes,
        contains('IC-307'),
      );
      expect(
        check(exercise('lib-x', equipment: const [])).codes,
        isNot(contains('IC-307')),
      );
    });

    test('IC-315 a role override needs a note', () {
      const noNote = ExerciseEquipment(
        EquipmentItemId('barbell'),
        roleOverride: EquipmentRole.support,
      );
      expect(
        check(exercise('lib-x', equipment: const [noNote])).codes,
        contains('IC-315'),
      );
      const note = ExerciseEquipment(
        EquipmentItemId('barbell'),
        roleOverride: EquipmentRole.support,
        overrideNote: 'Fixed in a rack.',
      );
      expect(
        check(exercise('lib-x', equipment: const [note])).codes,
        isNot(contains('IC-315')),
      );
    });
  });

  group('attributes (IC-316)', () {
    test('values must be in the controlled list', () {
      final ok = exercise(
        'lib-x',
        attributes: {ExerciseAttribute.angle: 'incline'},
      );
      expect(check(ok).codes, isNot(contains('IC-316')));
      final bad = exercise(
        'lib-x',
        attributes: {ExerciseAttribute.angle: 'steep'},
      );
      expect(check(bad).codes, contains('IC-316'));
      final wrongAttribute = exercise(
        'lib-x',
        attributes: {ExerciseAttribute.grip: 'incline'},
      );
      expect(check(wrongAttribute).codes, contains('IC-316'));
    });
  });

  group('retired references (IC-313)', () {
    test('an active exercise using a retired node, pattern or item', () {
      final nodes = [
        for (final x in ref.anatomy.nodes)
          if (x.id.value == 'triceps') AnatomyNodeAs.retired(x) else x,
      ];
      final patterns = [
        for (final x in ref.patterns.nodes)
          if (x.id.value == 'horizontalPush') PatternAs.retired(x) else x,
      ];
      final items = [
        for (final x in ref.equipment.items)
          if (x.id.value == 'bench') ItemAs.retired(x) else x,
      ];
      final c = ExerciseRuleContext(
        reference: referenceOf(nodes, patterns, items),
        providers: {ProviderId.repforge},
      );
      final f = check(exercise('lib-x'), c).withCode('IC-313');
      expect(f, hasLength(3));
      expect(f.every((x) => x.severity == Severity.error), isTrue);
      // A retired exercise is not reported, and user content only warns.
      expect(
        check(exercise('lib-x', retiredAt: fixtureTime), c).codes,
        isNot(contains('IC-313')),
      );
      expect(
        check(
          exercise('u1', source: ExerciseSource.user),
          c,
        ).withCode('IC-313').every((x) => x.severity == Severity.warning),
        isTrue,
      );
    });
  });

  group('review fixes L2, L6, L8', () {
    test('L2: a secondary before a primary on one node is IC-305', () {
      final e = exercise(
        'lib-x',
        targets: [secondary('chest', 0), primary('chest', 1)],
      );
      expect(check(e).codes, contains('IC-305'));
      expect(check(e).codes, isNot(contains('IC-302')));
    });

    test('L6: the name length counts characters, not UTF-16 units', () {
      final sixty = exercise('lib-x', name: '\u{1F600}' * 60);
      expect(check(sixty).codes, isNot(contains('IC-201')));
      expect(
        check(exercise('lib-x', name: '\u{1F600}' * 61)).codes,
        contains('IC-201'),
      );
    });

    test('L6: requireValidExercise aggregates repeated code/field keys', () {
      final r = requireValidExercise(
        exercise(
          'lib-x',
          targets: [primary('nowhere', 0), primary('elsewhere', 1)],
        ),
        ctx,
      );
      final e = (r as Err<CatalogueExercise>).error as ValidationError;
      expect(e.fieldErrors['IC-301:targets'], contains('nowhere'));
      expect(e.fieldErrors['IC-301:targets'], contains('elsewhere'));
    });

    test('L8: IC-314 reads the nonAnatomical flag, not a hard-coded id', () {
      const extra = AnatomyNode(
        id: AnatomyNodeId('cardioZone'),
        level: 1,
        sort: 990,
        labels: {'en-GB': 'Cardio zone'},
        nonAnatomical: true,
      );
      final c = ExerciseRuleContext(
        reference: referenceOf(
          [...ref.anatomy.nodes, extra],
          ref.patterns.nodes,
          ref.equipment.items,
        ),
        providers: {ProviderId.repforge},
      );
      final e = exercise('lib-x', targets: [primary('cardioZone', 0)]);
      expect(check(e, c).codes, contains('IC-314'));
    });

    test('N1: relationship source is required and kept as given', () {
      for (final source in ExerciseSource.values) {
        final r = ExerciseRelationship(
          from: const ExerciseId('a'),
          to: const ExerciseId('b'),
          kind: RelationshipKind.variationOf,
          source: source,
        );
        expect(r.source, source);
        final n = ExerciseRelationship.normalised(
          from: const ExerciseId('a'),
          to: const ExerciseId('b'),
          kind: RelationshipKind.variationOf,
          source: source,
        );
        expect((n as Ok<ExerciseRelationship>).value.source, source);
      }
    });
  });

  group('requireValidExercise returns a Result', () {
    test('ok when there is no error, warnings are dropped', () {
      final r = requireValidExercise(exercise('lib-x', aliases: const []), ctx);
      expect(r.isOk, isTrue);
    });

    test('err carries every error as a field error', () {
      final r = requireValidExercise(
        exercise('lib-x', targets: const [], laterality: null),
        ctx,
      );
      final e = (r as Err<CatalogueExercise>).error as ValidationError;
      expect(
        e.fieldErrors.keys,
        containsAll(['IC-204:targets', 'IC-208:laterality']),
      );
    });
  });
}
