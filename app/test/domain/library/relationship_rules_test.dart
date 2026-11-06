import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/exercise_relationship.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/relationship_rules.dart';

import 'support/catalogue_fixtures.dart';

ExerciseRelationship rel(
  String from,
  String to,
  RelationshipKind kind, {
  ExerciseSource source = ExerciseSource.system,
}) => ExerciseRelationship(
  from: xid(from),
  to: xid(to),
  kind: kind,
  source: source,
);

void main() {
  final a = exercise('lib-a');
  final b = exercise('lib-b');
  final c = exercise('lib-c');
  final d = exercise('lib-d');

  RelationshipAnalysis run(
    List<ExerciseRelationship> rels, [
    List<dynamic>? extra,
  ]) => analyseRelationships([a, b, c, d, ...?extra?.cast()], rels);

  group('normalisation (ExerciseRelationship.normalised)', () {
    ExerciseRelationship ok(Result<ExerciseRelationship> r) =>
        (r as Ok<ExerciseRelationship>).value;

    test('regressionOf is stored as the inverse progressionOf', () {
      final r = ok(
        ExerciseRelationship.normalised(
          from: xid('lib-easy'),
          to: xid('lib-hard'),
          kind: RelationshipKind.regressionOf,
          source: ExerciseSource.user,
        ),
      );
      expect(r.kind, RelationshipKind.progressionOf);
      expect(r.from.value, 'lib-hard');
      expect(r.to.value, 'lib-easy');
      expect(r.isNormalised, isTrue);
    });

    test('symmetric kinds are stored once with ids in order', () {
      for (final kind in [
        RelationshipKind.alternativeTo,
        RelationshipKind.unilateralCounterpartOf,
      ]) {
        final r = ok(
          ExerciseRelationship.normalised(
            from: xid('lib-z'),
            to: xid('lib-a'),
            kind: kind,
            source: ExerciseSource.user,
          ),
        );
        expect(r.from.value, 'lib-a');
        expect(r.to.value, 'lib-z');
        expect(r.kind, kind);
      }
      final keep = ok(
        ExerciseRelationship.normalised(
          from: xid('lib-a'),
          to: xid('lib-z'),
          kind: RelationshipKind.alternativeTo,
          source: ExerciseSource.user,
        ),
      );
      expect(keep.from.value, 'lib-a');
    });

    test('directional kinds keep their direction', () {
      final r = ok(
        ExerciseRelationship.normalised(
          from: xid('lib-z'),
          to: xid('lib-a'),
          kind: RelationshipKind.variationOf,
          source: ExerciseSource.user,
        ),
      );
      expect(r.from.value, 'lib-z');
    });

    test('a self-reference is refused', () {
      final r = ExerciseRelationship.normalised(
        from: xid('lib-a'),
        to: xid('lib-a'),
        kind: RelationshipKind.alternativeTo,
        source: ExerciseSource.user,
      );
      expect(r.isErr, isTrue);
      expect(
        ((r as Err<ExerciseRelationship>).error as ValidationError).field,
        'to',
      );
    });

    test('equality, order and text of a stored relationship', () {
      final r = rel('lib-a', 'lib-b', RelationshipKind.variationOf);
      expect(r, rel('lib-a', 'lib-b', RelationshipKind.variationOf));
      expect(r.toString(), 'lib-a variationOf lib-b');
      expect(
        [
          rel('lib-b', 'lib-c', RelationshipKind.progressionOf),
          rel('lib-b', 'lib-a', RelationshipKind.progressionOf),
          r,
        ]..sort(),
        [
          r,
          rel('lib-b', 'lib-a', RelationshipKind.progressionOf),
          rel('lib-b', 'lib-c', RelationshipKind.progressionOf),
        ],
      );
    });

    test('the derived regression view of a progression', () {
      final p = rel('lib-hard', 'lib-easy', RelationshipKind.progressionOf);
      expect(p.derivedRegression, (
        easier: xid('lib-easy'),
        harder: xid('lib-hard'),
      ));
      expect(
        derivedRegressions([
          p,
          rel('lib-a', 'lib-b', RelationshipKind.variationOf),
        ]),
        hasLength(1),
      );
      expect(
        rel('lib-a', 'lib-b', RelationshipKind.alternativeTo).derivedRegression,
        isNull,
      );
    });

    test('isNormalised flags regressionOf, self and misordered pairs', () {
      expect(
        rel('lib-a', 'lib-b', RelationshipKind.regressionOf).isNormalised,
        isFalse,
      );
      expect(
        rel('lib-a', 'lib-a', RelationshipKind.variationOf).isNormalised,
        isFalse,
      );
      expect(
        rel('lib-b', 'lib-a', RelationshipKind.alternativeTo).isNormalised,
        isFalse,
      );
      expect(
        rel('lib-a', 'lib-b', RelationshipKind.alternativeTo).isNormalised,
        isTrue,
      );
    });
  });

  group('IC-401 to IC-404', () {
    test('a clean set of relationships has no finding', () {
      final r = run([
        rel('lib-b', 'lib-a', RelationshipKind.variationOf),
        rel('lib-c', 'lib-a', RelationshipKind.variationOf),
        rel('lib-c', 'lib-b', RelationshipKind.progressionOf),
        rel('lib-a', 'lib-d', RelationshipKind.alternativeTo),
      ]);
      expect(r.findings, isEmpty);
      expect(r.families, 1);
      expect(r.maxDepth, 1);
      expect(r.longestProgression, 1);
      expect(r.sameFamily(xid('lib-b'), xid('lib-c')), isTrue);
      expect(r.sameFamily(xid('lib-a'), xid('lib-d')), isFalse);
    });

    test('IC-401 self-reference', () {
      expect(
        run([rel('lib-a', 'lib-a', RelationshipKind.alternativeTo)])
            .findings
            .codes,
        contains('IC-401'),
      );
    });

    test('IC-402 missing end', () {
      final r = run([rel('lib-a', 'lib-ghost', RelationshipKind.variationOf)]);
      expect(r.findings.codes, contains('IC-402'));
    });

    test('IC-403 duplicate', () {
      final r = run([
        rel('lib-a', 'lib-b', RelationshipKind.progressionOf),
        rel('lib-a', 'lib-b', RelationshipKind.progressionOf),
      ]);
      expect(r.findings.withCode('IC-403'), hasLength(1));
      // The same pair with another kind is not a duplicate.
      expect(
        run([
          rel('lib-a', 'lib-b', RelationshipKind.progressionOf),
          rel('lib-a', 'lib-b', RelationshipKind.variationOf),
        ]).findings.codes,
        isNot(contains('IC-403')),
      );
    });

    test('IC-404 inverse duplicate of a progression', () {
      final r = run([
        rel('lib-a', 'lib-b', RelationshipKind.progressionOf),
        rel('lib-b', 'lib-a', RelationshipKind.progressionOf),
      ]);
      expect(r.findings.withCode('IC-404'), hasLength(1));
    });

    test('IC-404 a stored regressionOf and unordered symmetric pairs', () {
      expect(
        run([rel('lib-a', 'lib-b', RelationshipKind.regressionOf)]).findings
            .withCode('IC-404'),
        hasLength(1),
      );
      expect(
        run([rel('lib-b', 'lib-a', RelationshipKind.alternativeTo)]).findings
            .withCode('IC-404'),
        hasLength(1),
      );
      expect(
        run([rel('lib-b', 'lib-a', RelationshipKind.unilateralCounterpartOf)])
            .findings
            .codes,
        contains('IC-404'),
      );
    });
  });

  group('IC-405 variationOf forest', () {
    test('at most one variationOf per exercise', () {
      final r = run([
        rel('lib-c', 'lib-a', RelationshipKind.variationOf),
        rel('lib-c', 'lib-b', RelationshipKind.variationOf),
      ]);
      expect(
        r.findings.withCode('IC-405').first.message,
        contains('more than one'),
      );
    });

    test('the target must be a family root', () {
      final r = run([
        rel('lib-c', 'lib-b', RelationshipKind.variationOf),
        rel('lib-b', 'lib-a', RelationshipKind.variationOf),
      ]);
      expect(
        r.findings.withCode('IC-405').single.message,
        contains('family root'),
      );
    });

    test('a cycle is reported', () {
      final r = run([
        rel('lib-a', 'lib-b', RelationshipKind.variationOf),
        rel('lib-b', 'lib-a', RelationshipKind.variationOf),
      ]);
      expect(
        r.findings.withCode('IC-405').any((f) => f.message.contains('cycle')),
        isTrue,
      );
      expect(r.cycles, 1);
      expect(r.families, 0);
    });

    test('two families are counted', () {
      final r = run([
        rel('lib-b', 'lib-a', RelationshipKind.variationOf),
        rel('lib-d', 'lib-c', RelationshipKind.variationOf),
      ]);
      expect(r.families, 2);
    });
  });

  group('IC-407 and IC-414 progressions', () {
    test('a progression cycle is refused', () {
      final r = run([
        rel('lib-a', 'lib-b', RelationshipKind.progressionOf),
        rel('lib-b', 'lib-c', RelationshipKind.progressionOf),
        rel('lib-c', 'lib-a', RelationshipKind.progressionOf),
      ]);
      expect(r.findings.withCode('IC-407'), hasLength(1));
      expect(r.cycles, 1);
    });

    test('a chain of 7 steps warns, 6 steps do not', () {
      final ids = [for (var i = 0; i < 8; i++) exercise('lib-s$i')];
      List<ExerciseRelationship> chain(int steps) => [
        for (var i = 0; i < steps; i++)
          rel('lib-s${i + 1}', 'lib-s$i', RelationshipKind.progressionOf),
      ];
      final six = analyseRelationships(ids, chain(6));
      expect(six.longestProgression, 6);
      expect(six.findings.codes, isNot(contains('IC-414')));
      final seven = analyseRelationships(ids, chain(7));
      expect(seven.longestProgression, 7);
      expect(
        seven.findings.withCode('IC-414').single.severity,
        Severity.warning,
      );
    });
  });

  group('review fixes M1 and L4', () {
    test('M1: IC-402 when an end of a system relationship is retired', () {
      final r1 = exercise('lib-r1', retiredAt: fixtureTime);
      final r2 = exercise('lib-r2', retiredAt: fixtureTime);
      final f = analyseRelationships(
        [r1, r2],
        [rel('lib-r1', 'lib-r2', RelationshipKind.variationOf)],
      ).findings;
      expect(f.withCode('IC-402'), hasLength(1));
      expect(f.withCode('IC-402').single.message, contains('retired'));
      // A user relationship is left to IC-905 (and IC-413 does not apply).
      final user = analyseRelationships(
        [r1, r2],
        [
          rel(
            'lib-r1',
            'lib-r2',
            RelationshipKind.variationOf,
            source: ExerciseSource.user,
          ),
        ],
      ).findings;
      expect(user.codes, isNot(contains('IC-402')));
    });

    test('L4: IC-414 is evaluated although another chain has a cycle', () {
      final ids = [for (var i = 0; i < 8; i++) exercise('lib-s$i')];
      final chain = [
        for (var i = 0; i < 7; i++)
          rel('lib-s${i + 1}', 'lib-s$i', RelationshipKind.progressionOf),
      ];
      final cyc = [exercise('lib-x'), exercise('lib-y')];
      final r = analyseRelationships(
        [...ids, ...cyc],
        [
          ...chain,
          rel('lib-x', 'lib-y', RelationshipKind.progressionOf),
          rel('lib-y', 'lib-x', RelationshipKind.progressionOf),
        ],
      );
      expect(r.findings.codes, contains('IC-407'));
      expect(r.findings.withCode('IC-414'), hasLength(1));
      expect(r.longestProgression, 7);
    });
  });

  group('IC-408 to IC-410, IC-413', () {
    test('IC-408 unilateralCounterpartOf joins bilateral with unilateral', () {
      final bi = exercise('lib-bi');
      final uni = exercise('lib-uni', laterality: Laterality.unilateral);
      final alt = exercise('lib-alt', laterality: Laterality.alternating);
      final good = analyseRelationships(
        [bi, uni],
        [rel('lib-bi', 'lib-uni', RelationshipKind.unilateralCounterpartOf)],
      );
      expect(good.findings, isEmpty);
      final good2 = analyseRelationships(
        [bi, alt],
        [rel('lib-alt', 'lib-bi', RelationshipKind.unilateralCounterpartOf)],
      );
      expect(good2.findings.codes, isNot(contains('IC-408')));
      final bad = analyseRelationships(
        [uni, alt],
        [rel('lib-alt', 'lib-uni', RelationshipKind.unilateralCounterpartOf)],
      );
      expect(bad.findings.codes, contains('IC-408'));
      final bothBilateral = analyseRelationships(
        [bi, exercise('lib-bi2')],
        [rel('lib-bi', 'lib-bi2', RelationshipKind.unilateralCounterpartOf)],
      );
      expect(bothBilateral.findings.codes, contains('IC-408'));
    });

    test('IC-409 alternativeTo inside one family warns', () {
      final r = run([
        rel('lib-b', 'lib-a', RelationshipKind.variationOf),
        rel('lib-c', 'lib-a', RelationshipKind.variationOf),
        rel('lib-b', 'lib-c', RelationshipKind.alternativeTo),
      ]);
      expect(r.findings.withCode('IC-409').single.severity, Severity.warning);
    });

    test('IC-410 variationOf between unrelated movements warns', () {
      final other = exercise(
        'lib-lat',
        patterns: const ['verticalPull'],
        targets: [primary('lats', 0)],
      );
      final r = analyseRelationships(
        [a, other],
        [rel('lib-lat', 'lib-a', RelationshipKind.variationOf)],
      );
      expect(r.findings.withCode('IC-410').single.severity, Severity.warning);
      final sameTarget = exercise('lib-same', patterns: const ['verticalPush']);
      expect(
        analyseRelationships(
          [a, sameTarget],
          [rel('lib-same', 'lib-a', RelationshipKind.variationOf)],
        ).findings.codes,
        isNot(contains('IC-410')),
      );
    });

    test('IC-413 an active system exercise linked to a retired one', () {
      final retired = exercise('lib-old', retiredAt: fixtureTime);
      final r = analyseRelationships(
        [a, retired],
        [rel('lib-a', 'lib-old', RelationshipKind.alternativeTo)],
      );
      expect(r.findings.withCode('IC-413'), hasLength(1));
      final bothRetired = analyseRelationships(
        [retired, exercise('lib-old2', retiredAt: fixtureTime)],
        [rel('lib-old', 'lib-old2', RelationshipKind.alternativeTo)],
      );
      expect(bothRetired.findings.codes, isNot(contains('IC-413')));
    });
  });
}
