import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/accepted_gaps.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/catalogue_records.dart';
import 'package:repforge/domain/library/coverage_evaluation.dart';
import 'package:repforge/domain/library/exercise_relationship.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/integrity_report.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';

import 'support/catalogue_fixtures.dart';

IntegrityInput withExercises(
  ApprovedReference ref,
  List<CatalogueExercise> exercises, {
  List<ExerciseRelationship> relationships = const [],
  PreviousCatalogue? previous,
  List<Retirement> retirements = const [],
  Set<ExerciseId> retiredLedger = const {},
  ExerciseReferences? history,
  List<MediaReference> media = const [],
  List<UserExerciseState> userStates = const [],
  AcceptedGaps acceptedGaps = AcceptedGaps.none,
  IntegrityOptions options = const IntegrityOptions(),
  ({Set<ExerciseId> systemIds, int rowCount})? before,
}) => IntegrityInput(
  anatomy: ref.anatomy.nodes,
  patterns: ref.patterns.nodes,
  equipment: ref.equipment.items,
  exercises: exercises,
  relationships: relationships,
  providers: const [repforgeProvider],
  release: const ReleaseId(ProviderId.repforge, 3),
  previous: previous,
  retirements: retirements,
  retiredExerciseLedger: retiredLedger,
  history: history,
  media: media,
  userStates: userStates,
  acceptedGaps: acceptedGaps,
  options: options,
  systemRowsBefore: before,
);

void main() {
  late ApprovedReference ref;
  late IntegrityReport release2;
  setUpAll(() {
    ref = ApprovedReference.load();
    release2 = runIntegrityChecks(release2Input(ref));
  });

  group(
    'release 2 (the 89 seed exercises with the approved reference data)',
    () {
      test('zero errors: the release may be applied', () {
        expect(release2.errors, 0);
        expect(release2.passed, isTrue);
      });

      test('findings by code against quality-and-duplicates.md section 6', () {
        expect(release2.countsByCode, {
          'IC-207':
              16, // info, empty cardio and mobility mechanics (documented 16)
          'IC-210': 89, // warning, instructions not written yet (documented 89)
          'IC-311': 2, // warning, kettlebell swing and thruster (documented 2)
          'IC-412': 30, // warning; 16 before X2 (documented), +14 with X2
          'IC-508': 2, // warning, hip abduction/adduction and push-up/pull-up
          'IC-602': 4, // warning (documented 4)
          'IC-603': 7, // info (documented 7)
          'IC-809':
              1, // warning, two nodes are labelled "Chest" (not in section 6)
        });
      });

      test('the documented totals: 93 warnings and 16 infos', () {
        const documented = {'IC-210', 'IC-311', 'IC-508'};
        final warnings = release2.findings.where(
          (f) => f.severity == Severity.warning && documented.contains(f.code),
        );
        expect(warnings, hasLength(93));
        expect(
          release2
              .findingsFor('IC-207')
              .every((f) => f.severity == Severity.info),
          isTrue,
        );
        expect(release2.findingsFor('IC-207'), hasLength(16));
        // Everything else: IC-602 (4), IC-412 (30; 16 before X2), IC-809 (1).
        expect(release2.warnings, 93 + 4 + 30 + 1);
        expect(release2.infos, 16 + 7);
      });

      test('IC-304 has no finding: lib-skipping carries no fullBody tag', () {
        expect(release2.findingsFor('IC-304'), isEmpty);
        expect(release2.findingsFor('ED-501'), isEmpty);
      });

      test('IC-601 and IC-411 have no finding', () {
        expect(release2.findingsFor('IC-601'), isEmpty);
        expect(release2.findingsFor('IC-411'), isEmpty);
        expect(release2.duplicatePairs, hasLength(11));
        expect(release2.duplicatePairs.every((p) => !p.cleared), isTrue);
      });

      test('reference data counts and catalogue summary', () {
        expect(release2.anatomyNodes, 126);
        expect(release2.patterns, 79);
        expect(release2.equipment, 33);
        expect(release2.exerciseCount, 89);
        expect(release2.retiredCount, 0);
        expect(release2.provider, 'repforge');
        expect(release2.release, 2);
        expect(release2.coverage!.slotFilled, 67);
        expect(release2.coverage!.setFilled, 20);
      });

      test('evaluated checks pass; checks that need other input say so', () {
        final byCode = {for (final c in release2.checks) c.code: c};
        expect(byCode['IC-204']!.status, 'passed');
        expect(byCode['IC-801']!.status, 'passed');
        expect(byCode['IC-810']!.status, 'passed');
        expect(byCode['IC-811']!.status, 'passed');
        expect(byCode['IC-210']!.status, 'warned');
        expect(byCode['IC-603']!.status, 'reported');
        expect(byCode['IC-202']!.status, 'enforcedByType');
        expect(byCode['IC-104']!.status, 'notEvaluated');
        expect(byCode['IC-901']!.status, 'notEvaluated');
        expect(release2.checks.where((c) => c.status == 'failed'), isEmpty);
      });

      test('every IC code of the specification is registered', () {
        final text = File('$catalogueDir/quality-and-duplicates.md')
            .readAsStringSync();
        final section = text.substring(
          text.indexOf('## 2. Checks'),
          text.indexOf('## 3. Integrity report format'),
        );
        final codes = {
          for (final m in RegExp(r'\| (IC-\d{3}) \|').allMatches(section))
            m.group(1)!,
        }..remove('IC-406'); // Withdrawn at revision 2.
        final registered = {for (final c in integrityChecks) c.code};
        expect(codes.difference(registered), isEmpty);
        expect(codes.length, greaterThan(80));
        // IC-950 is a heading in the specification; IC-406 is not reused.
        expect(registered, contains('IC-950'));
        expect(registered, isNot(contains('IC-406')));
      });

      test('the JSON form is deterministic and has the specified shape', () {
        final again = runIntegrityChecks(release2Input(ref));
        expect(again.toJsonString(), release2.toJsonString());
        final json =
            jsonDecode(release2.toJsonString()) as Map<String, Object?>;
        expect(json['schema'], 'repforge.integrityReport/1');
        expect((json['catalogue']! as Map)['exercises'], 89);
        expect(json['referenceData'], {
          'anatomyNodes': 126,
          'patterns': 79,
          'equipment': 33,
        });
        expect((json['summary']! as Map)['errors'], 0);
        expect((json['checks']! as List).first, containsPair('code', 'IC-101'));
        expect((json['duplicates']! as Map)['pairs'], hasLength(11));
        expect(json['relationships'], {
          'families': 0,
          'maxDepth': 0,
          'longestProgression': 0,
          'cycles': 0,
        });
      });

      test('findings are in deterministic order', () {
        final sorted = [...release2.findings]..sort();
        expect(
          [for (final f in release2.findings) f.toString()],
          [for (final f in sorted) f.toString()],
        );
      });

      test(
        'the Markdown form lists summary, warnings by code and duplicates',
        () {
          final md = release2.toMarkdown();
          expect(md, contains('# Integrity report'));
          expect(md, contains('| 0 | 128 | 23 |'));
          expect(md, contains('### IC-210 (89)'));
          expect(md, contains('## Duplicate pairs'));
          expect(md, contains('lib-back-squat'));
          expect(md, contains('Slots filled 67 of 325'));
          expect(md, contains('## Errors\nNone.'));
        },
      );

      test('without ledger and coverage inputs those checks are not run', () {
        final r = runIntegrityChecks(
          release2Input(ref, withLedger: false, withCoverage: false),
        );
        final byCode = {for (final c in r.checks) c.code: c.status};
        expect(byCode['IC-810'], 'notEvaluated');
        expect(byCode['IC-811'], 'notEvaluated');
        expect(r.coverage, isNull);
        expect(r.errors, 0);
      });
    },
  );

  group(
    'identity and revision (IC-102, IC-104 to IC-106, IC-110 to IC-112)',
    () {
      late List<CatalogueExercise> seed;
      setUpAll(() => seed = release2Exercises());

      IntegrityReport run(
        List<CatalogueExercise> now, {
        List<Retirement> retirements = const [],
        Set<ExerciseId> ledger = const {},
      }) => runIntegrityChecks(
        withExercises(
          ref,
          now,
          previous: PreviousCatalogue(exercises: seed),
          retirements: retirements,
          retiredLedger: ledger,
        ),
      );

      List<CatalogueExercise> modified(
        String id,
        CatalogueExercise Function(CatalogueExercise) f,
      ) => [
        for (final e in seed)
          if (e.id.value == id) f(e) else e,
      ];

      test('unchanged exercises produce none of these findings', () {
        final r = run(seed);
        for (final code in [
          'IC-104',
          'IC-105',
          'IC-106',
          'IC-110',
          'IC-111',
          'IC-112',
        ]) {
          expect(r.findingsFor(code), isEmpty, reason: code);
        }
        expect(
          {for (final c in r.checks) c.code: c.status}['IC-104'],
          'passed',
        );
      });

      test('IC-102 duplicate ids', () {
        final r = runIntegrityChecks(
          withExercises(ref, [seed.first, seed.first]),
        );
        expect(r.findingsFor('IC-102'), hasLength(1));
      });

      test('IC-104 a lowered revision', () {
        final up = modified('lib-plank', (e) => e.copyWith(revision: 3));
        final r = runIntegrityChecks(
          withExercises(
            ref,
            modified('lib-plank', (e) => e.copyWith(revision: 2)),
            previous: PreviousCatalogue(exercises: up),
          ),
        );
        expect(r.findingsFor('IC-104').single.subjectId, 'lib-plank');
      });

      test('IC-105 a changed system field without a higher revision', () {
        final r = run(
          modified(
            'lib-plank',
            (e) => e.copyWith(difficulty: Difficulty.intermediate),
          ),
        );
        expect(r.findingsFor('IC-105').single.severity, Severity.error);
        final withRev = run(
          modified(
            'lib-plank',
            (e) => e.copyWith(difficulty: Difficulty.intermediate, revision: 2),
          ),
        );
        expect(withRev.findingsFor('IC-105'), isEmpty);
        expect(withRev.findingsFor('IC-106'), isEmpty);
      });

      test('IC-105 also sees changed content', () {
        final content = [
          ContentSection(
            exerciseId: xid('lib-plank'),
            locale: 'en-GB',
            kind: 'setup',
            ordinal: 0,
            body: 'Lie face down and prop up on your forearms.',
          ),
        ];
        final changed = IntegrityInput(
          anatomy: ref.anatomy.nodes,
          patterns: ref.patterns.nodes,
          equipment: ref.equipment.items,
          exercises: seed,
          content: content,
          providers: const [repforgeProvider],
          previous: PreviousCatalogue(exercises: seed),
        );
        expect(
          runIntegrityChecks(changed).findingsFor('IC-105').single.subjectId,
          'lib-plank',
        );
      });

      test('IC-106 revision raised, content unchanged', () {
        final r = run(modified('lib-plank', (e) => e.copyWith(revision: 2)));
        expect(r.findingsFor('IC-106').single.severity, Severity.warning);
      });

      test('IC-110 an id absent and not retired; retiring it is accepted', () {
        final without = [
          for (final e in seed)
            if (e.id.value != 'lib-plank') e,
        ];
        expect(
          run(without).findingsFor('IC-110').single.subjectId,
          'lib-plank',
        );
        expect(
          run(
            without,
            retirements: [
              Retirement(xid('lib-plank'), 'Merged into another entry.'),
            ],
          ).findingsFor('IC-110'),
          isEmpty,
        );
        // A retired exercise that is still present (retired_at set) is present.
        final retired = modified(
          'lib-plank',
          (e) => e.copyWith(retiredAt: fixtureTime, revision: 2),
        );
        expect(run(retired).findingsFor('IC-110'), isEmpty);
      });

      test('IC-111 a retired id never reappears as active', () {
        final r = run(seed, ledger: {xid('lib-plank')});
        expect(r.findingsFor('IC-111').single.subjectId, 'lib-plank');
        final retired = modified(
          'lib-plank',
          (e) => e.copyWith(retiredAt: fixtureTime),
        );
        expect(
          run(retired, ledger: {xid('lib-plank')}).findingsFor('IC-111'),
          isEmpty,
        );
      });

      test('IC-112 a retirement needs a reason and an active replacement', () {
        final r = run(
          seed,
          retirements: [
            Retirement(xid('lib-a'), ' '),
            Retirement(xid('lib-b'), 'Merged.', replacedBy: xid('lib-ghost')),
            Retirement(xid('lib-c'), 'Merged.', replacedBy: xid('lib-plank')),
          ],
        );
        expect(r.findingsFor('IC-112'), hasLength(2));
        final retiredTarget = run(
          modified('lib-plank', (e) => e.copyWith(retiredAt: fixtureTime)),
          retirements: [
            Retirement(xid('lib-c'), 'Merged.', replacedBy: xid('lib-plank')),
          ],
        );
        expect(retiredTarget.findingsFor('IC-112'), hasLength(1));
      });

      test('IC-808 reference data removed since the previous release', () {
        final input = IntegrityInput(
          anatomy: [
            for (final n in ref.anatomy.nodes)
              if (n.id.value != 'regionNeck') n,
          ],
          patterns: ref.patterns.nodes,
          equipment: ref.equipment.items,
          exercises: const [],
          previous: PreviousCatalogue(
            exercises: const [],
            anatomy: ref.anatomy.nodes,
            patterns: ref.patterns.nodes,
            equipment: ref.equipment.items,
          ),
        );
        final r = runIntegrityChecks(input);
        expect(r.findingsFor('IC-808').single.subjectId, 'regionNeck');
      });
    },
  );

  group('references from user data and history (IC-900)', () {
    late List<CatalogueExercise> seed;
    setUpAll(() => seed = release2Exercises());

    test('all references resolve, retired exercises included', () {
      final retired = [
        for (final e in seed)
          if (e.id.value == 'lib-plank')
            e.copyWith(retiredAt: fixtureTime)
          else
            e,
      ];
      final r = runIntegrityChecks(
        withExercises(
          ref,
          retired,
          history: ExerciseReferences(
            sessionSetExerciseIds: {xid('lib-plank'), xid('lib-back-squat')},
            sessionExerciseIds: {xid('lib-plank')},
            planExerciseIds: {xid('lib-plank')},
            userStateExerciseIds: {xid('lib-plank')},
          ),
          userStates: [
            UserExerciseState(exerciseId: xid('lib-plank'), favourite: true),
          ],
        ),
      );
      for (final code in ['IC-901', 'IC-902', 'IC-903', 'IC-905', 'IC-907']) {
        expect(r.findingsFor(code), isEmpty, reason: code);
      }
      expect({for (final c in r.checks) c.code: c.status}['IC-901'], 'passed');
    });

    test(
      'unresolved sets, plans, state, copies, relationships and quarantine',
      () {
        final copy = exercise(
          'user-copy',
          source: ExerciseSource.user,
          copiedFromId: xid('lib-gone'),
        );
        final r = runIntegrityChecks(
          withExercises(
            ref,
            [...seed.take(3), copy],
            relationships: [
              ExerciseRelationship(
                from: xid('user-copy'),
                to: xid('lib-gone2'),
                kind: RelationshipKind.alternativeTo,
                source: ExerciseSource.user,
              ),
              ExerciseRelationship(
                from: xid('lib-gone3'),
                to: seed.first.id,
                kind: RelationshipKind.variationOf,
                source: ExerciseSource.user,
              ),
            ],
            history: ExerciseReferences(
              sessionSetExerciseIds: {xid('lib-missing-1')},
              sessionExerciseIds: {xid('lib-missing-2')},
              planExerciseIds: {xid('lib-missing-3')},
              userStateExerciseIds: {xid('lib-missing-4')},
              quarantinedExerciseIds: {xid('lib-missing-5')},
            ),
            userStates: [UserExerciseState(exerciseId: xid('lib-missing-6'))],
          ),
        );
        expect(r.findingsFor('IC-901'), hasLength(2));
        expect(
          r.findingsFor('IC-902').map((f) => f.subjectId),
          containsAll(['lib-missing-3', 'lib-missing-4', 'lib-missing-6']),
        );
        expect(r.findingsFor('IC-903').single.subjectId, 'lib-gone');
        expect(r.findingsFor('IC-905'), hasLength(2));
        final quarantined = r.findingsFor('IC-907').single;
        expect(quarantined.severity, Severity.info);
        expect(quarantined.subjectId, 'lib-missing-5');
        expect(r.passed, isFalse);
      },
    );

    test('IC-904 and IC-906 never delete, never shrink', () {
      final ids = {for (final e in seed) e.id};
      final okRun = runIntegrityChecks(
        withExercises(
          ref,
          seed,
          before: (systemIds: ids, rowCount: seed.length),
        ),
      );
      expect(okRun.findingsFor('IC-904'), isEmpty);
      expect(okRun.findingsFor('IC-906'), isEmpty);
      final shrunk = seed.skip(1).toList();
      final bad = runIntegrityChecks(
        withExercises(
          ref,
          shrunk,
          before: (systemIds: ids, rowCount: seed.length),
        ),
      );
      expect(bad.findingsFor('IC-904').single.subjectId, seed.first.id.value);
      expect(bad.findingsFor('IC-906'), hasLength(1));
    });
  });

  group('relationships, media and names in the report', () {
    late List<CatalogueExercise> seed;
    setUpAll(() => seed = release2Exercises());

    test('the relationship section reports the graph', () {
      final r = runIntegrityChecks(
        withExercises(
          ref,
          seed,
          relationships: [
            ExerciseRelationship(
              from: xid('lib-front-squat'),
              to: xid('lib-back-squat'),
              kind: RelationshipKind.variationOf,
              source: ExerciseSource.user,
            ),
            ExerciseRelationship(
              from: xid('lib-pull-up'),
              to: xid('lib-assisted-pull-up'),
              kind: RelationshipKind.progressionOf,
              source: ExerciseSource.user,
            ),
          ],
        ),
      );
      expect(r.families, 1);
      expect(r.maxDepth, 1);
      expect(r.longestProgression, 1);
      // The variationOf link clears the close pair of the back and front squat.
      final pair = r.duplicatePairs.firstWhere(
        (p) => p.a.value == 'lib-back-squat' && p.b.value == 'lib-front-squat',
      );
      expect(pair.cleared, isTrue);
      expect(
        r
            .findingsFor('IC-602')
            .firstWhere((f) => f.subjectId == 'lib-back-squat')
            .disposition,
        'relationship',
      );
    });

    test('ED-702 incomplete or orphan media', () {
      final r = runIntegrityChecks(
        withExercises(
          ref,
          seed.take(2).toList(),
          media: [
            MediaReference(
              id: 'm1',
              exerciseId: seed.first.id,
              kind: 'image',
              locator: 'a.png',
              licence: '',
              attribution: 'Me',
            ),
            MediaReference(
              id: 'm1',
              exerciseId: xid('lib-ghost'),
              kind: 'image',
              locator: 'b.png',
              licence: 'CC0-1.0',
              attribution: 'Me',
            ),
            MediaReference(
              id: 'm2',
              exerciseId: seed.first.id,
              kind: 'video',
              locator: 'c.mp4',
              licence: 'CC0-1.0',
              attribution: 'Me',
            ),
          ],
        ),
      );
      expect(r.findingsFor('ED-702'), hasLength(3));
    });
  });

  group('accepted gaps and tranche status', () {
    test('a warning with an accepted-gaps entry gets its disposition', () {
      final gaps = unwrap(
        parseAcceptedGaps({
          'schema': 'repforge.acceptedGaps/1',
          'accepted': [
            {
              'id': 'AG-0001',
              'kind': 'warning',
              'code': 'IC-311',
              'exerciseId': 'lib-thruster',
              'reason': 'Accepted.',
              'acceptedBy': 'owner',
            },
            {
              'id': 'AG-0002',
              'kind': 'duplicate',
              'pair': ['lib-hack-squat', 'lib-leg-press'],
              'decision': 'distinct',
              'reason': 'Different machines.',
              'acceptedBy': 'KR',
            },
            {
              'id': 'AG-0003',
              'kind': 'warning',
              'code': 'IC-999',
              'exerciseId': 'lib-nope',
              'reason': 'Stale.',
              'acceptedBy': 'owner',
            },
            {
              'id': 'AG-0004',
              'kind': 'coverageGap',
              'group': 'neck',
              'dimension': 'slot',
              'item': 'neck.rotation',
              'reason': 'Example.',
              'acceptedBy': 'owner',
            },
            {
              'id': 'AG-0005',
              'kind': 'warning',
              'code': 'IC-210',
              'exerciseId': 'lib-plank',
              'reason': 'Old.',
              'acceptedBy': 'owner',
              'untilRelease': 1,
            },
          ],
        }),
      );
      final r = runIntegrityChecks(release2Input(ref).withAcceptedGaps(gaps));
      final thruster = r
          .findingsFor('IC-311')
          .firstWhere((f) => f.subjectId == 'lib-thruster');
      expect(thruster.disposition, 'accepted (AG-0001)');
      expect(
        r
            .findingsFor('IC-311')
            .firstWhere((f) => f.subjectId == 'lib-kettlebell-swing')
            .disposition,
        isNull,
      );
      final hack = r.duplicatePairs.firstWhere(
        (p) => p.a.value == 'lib-hack-squat',
      );
      expect(hack.cleared, isTrue);
      expect(hack.disposition, 'distinct (AG-0002)');
      // Stale (matches nothing) and expired entries are reported as info.
      final stale = r.findingsFor('ED-901');
      expect(
        stale.map((f) => f.subjectId),
        unorderedEquals(['AG-0003', 'AG-0005']),
      );
      expect(stale.every((f) => f.severity == Severity.info), isTrue);
      // The owner's coverage gap entry matched a row and is not stale.
      expect(
        r.coverage!.rows.firstWhere((x) => x.item == 'neck.rotation').status,
        GapStatus.accepted,
      );
      // The expired entry did not apply.
      expect(
        r
            .findingsFor('IC-210')
            .firstWhere((f) => f.subjectId == 'lib-plank')
            .disposition,
        isNull,
      );
    });

    test('M2a: a duplicate entry clears the IC-412 findings of its pair', () {
      const gaps = AcceptedGaps([
        AcceptedGap(
          id: 'AG-7',
          kind: AcceptedGapKind.duplicate,
          pair: [
            ExerciseId('lib-triceps-pushdown'),
            ExerciseId('lib-overhead-triceps-extension'),
          ],
          decision: 'distinct',
          reason: 'Different arm position.',
          acceptedBy: 'KR',
        ),
      ]);
      final r = runIntegrityChecks(release2Input(ref).withAcceptedGaps(gaps));
      final f = r
          .findingsFor('IC-412')
          .singleWhere(
            (x) =>
                x.subjectId == 'lib-overhead-triceps-extension' &&
                x.related.contains('lib-triceps-pushdown'),
          );
      expect(f.disposition, 'distinct (AG-7)');
      expect(r.findingsFor('ED-901'), isEmpty);
      // Other IC-412 findings stay open.
      expect(
        r.findingsFor('IC-412').where((x) => x.disposition == null),
        hasLength(29),
      );
    });

    test('M2b: a warning entry with a pair clears only that pair', () {
      const gaps = AcceptedGaps([
        AcceptedGap(
          id: 'AG-8',
          kind: AcceptedGapKind.warning,
          code: 'IC-412',
          pair: [ExerciseId('lib-barbell-curl'), ExerciseId('lib-db-curl')],
          reason: 'Reviewed.',
          acceptedBy: 'KR',
        ),
      ]);
      final r = runIntegrityChecks(release2Input(ref).withAcceptedGaps(gaps));
      final curls = r
          .findingsFor('IC-412')
          .where((x) => x.subjectId == 'lib-barbell-curl')
          .toList();
      expect(curls.length, greaterThan(1));
      final cleared = curls.where((x) => x.disposition != null).toList();
      expect(cleared, hasLength(1));
      expect(cleared.single.related, ['lib-db-curl']);
      expect(r.findingsFor('ED-901'), isEmpty);
    });

    test('M2c: a pair entry that matches no finding is stale', () {
      const gaps = AcceptedGaps([
        AcceptedGap(
          id: 'AG-9',
          kind: AcceptedGapKind.duplicate,
          pair: [ExerciseId('lib-plank'), ExerciseId('lib-crunch')],
          decision: 'distinct',
          reason: 'No finding.',
          acceptedBy: 'KR',
        ),
        AcceptedGap(
          id: 'AG-10',
          kind: AcceptedGapKind.warning,
          code: 'IC-412',
          pair: [ExerciseId('lib-plank'), ExerciseId('lib-crunch')],
          reason: 'No finding.',
          acceptedBy: 'KR',
        ),
      ]);
      final r = runIntegrityChecks(release2Input(ref).withAcceptedGaps(gaps));
      expect(
        r.findingsFor('ED-901').map((f) => f.subjectId),
        unorderedEquals(['AG-9', 'AG-10']),
      );
    });

    test('an accepted-gaps entry never silences an error', () {
      final gaps = AcceptedGaps([
        AcceptedGap(
          id: 'AG-1',
          kind: AcceptedGapKind.warning,
          code: 'IC-204',
          exerciseId: xid('lib-x'),
          reason: 'No.',
          acceptedBy: 'owner',
        ),
      ]);
      final bad = exercise('lib-x', targets: const []);
      final r = runIntegrityChecks(
        withExercises(ref, [bad], acceptedGaps: gaps),
      );
      expect(r.findingsFor('IC-204').single.disposition, isNull);
      expect(r.passed, isFalse);
    });

    test('a coverage gap accepted by the owner becomes accepted', () {
      const gaps = AcceptedGaps([
        AcceptedGap(
          id: 'AG-9',
          kind: AcceptedGapKind.coverageGap,
          group: 'neck',
          dimension: 'slot',
          item: 'neck.flexion',
          reason: 'Owner accepts.',
          acceptedBy: 'owner',
        ),
      ]);
      final input = release2Input(ref).withAcceptedGaps(gaps);
      final r = runIntegrityChecks(input);
      final row = r.coverage!.rows.firstWhere(
        (x) => x.group == 'neck' && x.item == 'neck.flexion',
      );
      expect(row.status, GapStatus.accepted);
      expect(row.note, contains('AG-9'));
    });

    test('parser: a coverage gap must be accepted by the owner', () {
      expect(
        parseAcceptedGaps({
          'schema': 'repforge.acceptedGaps/1',
          'accepted': [
            {
              'id': 'AG-1',
              'kind': 'coverageGap',
              'reason': 'x',
              'acceptedBy': 'reviewer',
            },
          ],
        }).isErr,
        isTrue,
      );
      expect(
        parseAcceptedGaps({'schema': 'other', 'accepted': <Object?>[]}).isErr,
        isTrue,
      );
      expect(parseAcceptedGaps(null).isErr, isTrue);
      expect(
        parseAcceptedGaps({
          'schema': 'repforge.acceptedGaps/1',
          'accepted': [
            {
              'id': 'AG-1',
              'kind': 'warning',
              'pair': ['only-one'],
              'reason': 'x',
              'acceptedBy': 'a',
              'untilRelease': 'soon',
            },
          ],
        }).isErr,
        isTrue,
      );
    });

    test('open gaps of a complete tranche are errors (IC-950)', () {
      final plain = runIntegrityChecks(release2Input(ref));
      expect(plain.findingsFor('IC-950'), isEmpty);
      final info = runIntegrityChecks(
        release2Input(
          ref,
          options: const IntegrityOptions(includeCoverageFindings: true),
        ),
      );
      expect(info.findingsFor('IC-950'), isNotEmpty);
      expect(
        info.findingsFor('IC-950').every((f) => f.severity == Severity.info),
        isTrue,
      );
      final complete = runIntegrityChecks(
        release2Input(
          ref,
          options: const IntegrityOptions(
            completeTranches: {'5.1'},
            inProgressTranches: {'5.2'},
          ),
        ),
      );
      expect(
        complete
            .findingsFor('IC-950')
            .every((f) => f.severity == Severity.error),
        isTrue,
      );
      expect(complete.errors, greaterThan(0));
      expect(complete.passed, isFalse);
      expect(
        complete.toJson()['summary'],
        containsPair('tranches', {'5.2': 'inProgress', '5.1': 'complete'}),
      );
    });

    test('IC-210 and IC-205 severities follow the options', () {
      final strict = runIntegrityChecks(
        release2Input(
          ref,
          options: const IntegrityOptions(missingContentIsError: true),
        ),
      );
      expect(
        strict.findingsFor('IC-210').every((f) => f.severity == Severity.error),
        isTrue,
      );
      expect(strict.errors, 89);
    });
  });
}

extension on IntegrityInput {
  IntegrityInput withAcceptedGaps(AcceptedGaps gaps) => IntegrityInput(
    anatomy: anatomy,
    patterns: patterns,
    equipment: equipment,
    exercises: exercises,
    relationships: relationships,
    content: content,
    media: media,
    providers: providers,
    userStates: userStates,
    release: release,
    contentHash: contentHash,
    previous: previous,
    retirements: retirements,
    retiredExerciseLedger: retiredExerciseLedger,
    ledger: ledger,
    coverage: coverage,
    history: history,
    systemRowsBefore: systemRowsBefore,
    acceptedGaps: gaps,
    options: options,
  );
}
