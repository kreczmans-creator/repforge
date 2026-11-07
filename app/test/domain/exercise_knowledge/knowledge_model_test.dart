import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge_source.dart';
import 'package:repforge/domain/exercise_knowledge/knowledge_checks.dart';
import 'package:repforge/domain/library/release/release_format.dart';
import 'package:repforge/domain/library/release/release_parser.dart';

import 'support/knowledge_support.dart';

/// A small knowledge release built from the shipped release 3 for the rules
/// that need a controlled input.
Map<String, Object?> _subset(Iterable<String> ids) {
  final map = release3Map();
  final wanted = ids.toSet();
  map['exercises'] = [
    for (final e in exercisesIn(map))
      if (wanted.contains(e['id'])) e,
  ];
  // Relationships to exercises outside the subset are dropped.
  for (final e in exercisesIn(map)) {
    final rels = (e['relationships'] as List<Object?>?)
        ?.cast<Map<String, Object?>>()
        .where((r) => wanted.contains(r['to']))
        .toList();
    if (rels == null || rels.isEmpty) {
      e.remove('relationships');
    } else {
      e['relationships'] = rels;
    }
  }
  return map;
}

ReleaseDocument _doc(Map<String, Object?> map) {
  final r = parseReleaseJson(jsonDecode(jsonEncode(map)));
  expect(r.ok, isTrue, reason: '${r.findings.take(3)}');
  return r.document!;
}

Map<String, Object?> _ex(Map<String, Object?> map, String id) =>
    exercisesIn(map).firstWhere((e) => e['id'] == id);

Map<String, Object?> _content(Map<String, Object?> e) =>
    (e['content']! as Map<String, Object?>)['en-GB']! as Map<String, Object?>;

List<String> _codes(ReleaseDocument d) => [
  for (final f in checkKnowledge(d)) f.code,
];

void main() {
  group('detail retrieval from the canonical release', () {
    final catalogue = shippedCatalogue();

    test('the deadlift carries every element of the owner brief', () {
      final k = catalogue['lib-deadlift']!;
      expect(k.name, 'Conventional deadlift');
      expect(k.description, isNotEmpty);
      expect(k.startingPosition.length, greaterThanOrEqualTo(2));
      expect(k.execution.length, greaterThanOrEqualTo(3));
      expect(k.breathing, isNotEmpty);
      expect(k.cues, isNotEmpty);
      expect(k.safety, isNotEmpty);
      expect(k.mistakes.first.fault, 'Rounding the back off the floor.');
      expect(
        k.mistakes.first.fix,
        'Set a flat back and brace before you pull.',
      );
      expect(k.mistakes.first.why, contains('spine'));
      expect(k.difficulty, Difficulty.intermediate);
      expect(k.mechanics, Mechanics.compound);
      expect(k.laterality, Laterality.bilateral);
      // Labels come from the approved reference files.
      expect(k.primaryTargetLabels, ['Glutes']);
      expect(k.patternLabels, ['Hinge']);
      expect(k.equipmentLabels, ['Barbell']);
    });

    test('links are typed: other equipment, variations, easier, harder, '
        'comparable', () {
      List<String> ids(String id, ExerciseLinkKind kind) => [
        for (final l in catalogue[id]!.linksOf(kind)) l.exerciseId.value,
      ];
      expect(
        ids('lib-bench-press', ExerciseLinkKind.equipmentAlternative),
        containsAll(['lib-db-bench-press', 'lib-machine-chest-press']),
      );
      expect(ids('lib-bench-press', ExerciseLinkKind.variation), [
        'lib-incline-bench-press',
      ]);
      expect(ids('lib-bench-press', ExerciseLinkKind.comparable), [
        'lib-push-up',
      ]);
      expect(ids('lib-goblet-squat', ExerciseLinkKind.easier), [
        'lib-bodyweight-squat',
      ]);
      expect(ids('lib-goblet-squat', ExerciseLinkKind.harder), [
        'lib-back-squat',
      ]);
      // A variation sees the family root and its siblings.
      expect(
        ids('lib-front-squat', ExerciseLinkKind.variation),
        contains('lib-back-squat'),
      );
      // Each linked exercise appears once, with the most specific kind.
      final squat = catalogue['lib-bodyweight-squat']!;
      final linked = [for (final l in squat.links) l.exerciseId];
      expect(linked.toSet().length, linked.length);
      expect(
        squat.links
            .firstWhere((l) => l.exerciseId.value == 'lib-goblet-squat')
            .kind,
        ExerciseLinkKind.harder,
      );
    });

    test('an unknown id has no record', () {
      expect(catalogue['custom-uuid-1'], isNull);
    });
  });

  group('media associations', () {
    test('several media per exercise in sequence order, display order kept '
        'when the file order differs', () {
      final map = _subset(['lib-deadlift']);
      final media = (_ex(map, 'lib-deadlift')['media']! as List<Object?>)
          .reversed
          .toList();
      _ex(map, 'lib-deadlift')['media'] = media;
      final k = KnowledgeCatalogue.fromRelease(_doc(map))['lib-deadlift']!;
      expect([for (final m in k.media) m.ordinal], [0, 1]);
      expect(k.media.first.purpose, 'finish', reason: 'array order wins');
      expect(k.availableMedia, hasLength(2));
    });

    test('an unavailable item is a recorded gap and is not shown', () {
      final map = _subset(['lib-deadlift']);
      final media = (_ex(map, 'lib-deadlift')['media']! as List<Object?>)
          .cast<Map<String, Object?>>();
      media.first['availability'] = 'unavailable';
      final doc = _doc(map);
      expect(_codes(doc), isEmpty);
      final k = KnowledgeCatalogue.fromRelease(doc)['lib-deadlift']!;
      expect(k.media, hasLength(2));
      expect(k.availableMedia, hasLength(1));
    });
  });

  group('knowledge checks (KS)', () {
    test('content without provenance (KS-101)', () {
      final map = _subset(['lib-plank']);
      _ex(map, 'lib-plank').remove('contentProvenance');
      expect(_codes(_doc(map)), ['KS-101']);
    });

    test('editor-approved content must name the editor and date (KS-102)', () {
      final map = _subset(['lib-plank']);
      final p =
          _ex(map, 'lib-plank')['contentProvenance']! as Map<String, Object?>;
      p['status'] = 'editorApproved';
      expect(_codes(_doc(map)), ['KS-102']);
      p
        ..['editor'] = 'A. Editor'
        ..['approvedOn'] = '2026-11-08';
      expect(_codes(_doc(map)), isEmpty);
    });

    test('provenance without content is a warning (KS-103); an empty author '
        'is an error (KS-104)', () {
      final map = _subset(['lib-plank']);
      _ex(map, 'lib-plank').remove('content');
      expect(_codes(_doc(map)), ['KS-103']);
      (_ex(map, 'lib-plank')['contentProvenance']!
              as Map<String, Object?>)['authoredBy'] =
          ' ';
      expect(_codes(_doc(map)), containsAll(['KS-103', 'KS-104']));
    });

    test('mistake reasons pair one to one (KS-201) and mistakes have a fix '
        '(KS-202)', () {
      final map = _subset(['lib-plank']);
      final c = _content(_ex(map, 'lib-plank'));
      (c['mistakeEffects']! as List<Object?>).removeLast();
      expect(_codes(_doc(map)), ['KS-201']);
      final m = _subset(['lib-plank']);
      (_content(_ex(m, 'lib-plank'))['commonMistakes']! as List<Object?>)[0] =
          'Hips sagging towards the floor';
      expect(_codes(_doc(m)), ['KS-202']);
    });

    test('media fields (KS-301 to KS-308)', () {
      Map<String, Object?> withMedia(Map<String, Object?> item) {
        final map = _subset(['lib-plank']);
        _ex(map, 'lib-plank')['media'] = [
          {
            'id': 'm1',
            'kind': 'illustration',
            'locator': 'repforge-illustration:plank/start',
            'licence': 'proprietary (RepForge)',
            'attribution': 'RepForge original illustration',
            'purpose': 'overview',
            'caption': 'Hold position.',
            'source': 'original',
            'availability': 'available',
            ...item,
          },
        ];
        return map;
      }

      expect(_codes(_doc(withMedia({}))), isEmpty);
      expect(_codes(_doc(withMedia({'kind': 'gif'}))), ['KS-301']);
      expect(_codes(_doc(withMedia({'purpose': 'hero'}))), ['KS-302']);
      expect(_codes(_doc(withMedia({'caption': ''}))), ['KS-303']);
      expect(_codes(_doc(withMedia({'source': 'stock'}))), ['KS-304']);
      expect(
        _codes(
          _doc(withMedia({'source': 'licensed', 'licence': 'proprietary (X)'})),
        ),
        ['KS-304'],
      );
      expect(_codes(_doc(withMedia({'availability': 'maybe'}))), ['KS-305']);
      expect(
        _codes(_doc(withMedia({'locator': 'https://example.com/p.png'}))),
        ['KS-306'],
      );
      expect(_codes(_doc(withMedia({'locator': 'photos/plank.png'}))), [
        'KS-307',
      ]);
      expect(
        _codes(
          _doc(
            withMedia({
              'locator': 'photos/plank.png',
              'availability': 'unavailable',
            }),
          ),
        ),
        isEmpty,
        reason: 'an unavailable gap may name its planned location',
      );
      expect(
        _codes(
          _doc(withMedia({'attribution': 'Copied from bodybuilding.com'})),
        ),
        ['KS-308'],
      );
    });

    test('the parser reports unknown content provenance keys and statuses', () {
      final map = _subset(['lib-plank']);
      final p =
          _ex(map, 'lib-plank')['contentProvenance']! as Map<String, Object?>;
      p['reviewer'] = 'x';
      final r = parseReleaseJson(jsonDecode(jsonEncode(map)));
      expect(r.ok, isFalse);
      expect([for (final f in r.findings) f.code], contains('RF-006'));
      p
        ..remove('reviewer')
        ..['status'] = 'published';
      expect(parseReleaseJson(jsonDecode(jsonEncode(map))).ok, isFalse);
      p
        ..['status'] = 'draftAwaitingEditor'
        ..['draftedOn'] = '2026-13-40';
      expect(parseReleaseJson(jsonDecode(jsonEncode(map))).ok, isFalse);
    });
  });

  group('loading', () {
    test('a release that does not parse fails without throwing', () {
      final r = loadKnowledgeCatalogue(
        KnowledgeBundle(release: utf8.encode('{"formatVersion": 2}')),
      );
      expect(r, isA<Err<KnowledgeCatalogue>>());
    });

    test('a release that breaks a knowledge rule is refused', () {
      final map = _subset(['lib-plank']);
      _ex(map, 'lib-plank').remove('contentProvenance');
      final r = loadKnowledgeCatalogue(
        KnowledgeBundle(release: utf8.encode(jsonEncode(map))),
      );
      expect(r, isA<Err<KnowledgeCatalogue>>());
      expect((r as Err).error.message, contains('KS-101'));
    });

    test('without reference files the ids are shown and the instructions '
        'still load', () {
      final r = loadKnowledgeCatalogue(
        KnowledgeBundle(release: release3Bytes()),
      );
      final k = (r as Ok<KnowledgeCatalogue>).value['lib-deadlift']!;
      expect(k.primaryTargetLabels, ['glutes']);
      expect(k.execution, isNotEmpty);
    });

    test('a reference file whose hash differs from the release is ignored', () {
      final reference = shippedReferenceBytes()
        ..[ReleaseReferenceName.anatomy] = utf8.encode('{"nodes": []}');
      final labels = referenceLabelsFor(
        parseReleaseBytes(release3Bytes()).document!,
        reference,
      );
      expect(labels.anatomy, isEmpty);
      expect(labels.patterns, isNotEmpty);
      expect(labels.supportEquipment, containsAll(['bench', 'squatRack']));
    });
  });

  group('publication policy (owner editorial rule; KS-D9)', () {
    final catalogue = shippedCatalogue();

    test('a draft is withheld unless drafts are switched on', () {
      final found = KnowledgeFound(catalogue['lib-deadlift']!);
      expect(
        applyPublicationPolicy(found, showDrafts: false),
        isA<KnowledgeAwaitingReview>(),
      );
      expect(applyPublicationPolicy(found, showDrafts: true), same(found));
    });

    test('editor-approved content is always shown', () {
      final map = _subset(['lib-plank']);
      (_ex(map, 'lib-plank')['contentProvenance']! as Map<String, Object?>)
        ..['status'] = 'editorApproved'
        ..['editor'] = 'A. Editor'
        ..['approvedOn'] = '2026-11-08';
      final k = KnowledgeCatalogue.fromRelease(_doc(map))['lib-plank']!;
      final found = KnowledgeFound(k);
      expect(applyPublicationPolicy(found, showDrafts: false), same(found));
    });

    test('other results pass through unchanged', () {
      const none = KnowledgeNotAuthored();
      const off = KnowledgeUnavailable('x');
      expect(applyPublicationPolicy(none, showDrafts: false), same(none));
      expect(applyPublicationPolicy(off, showDrafts: false), same(off));
    });
  });
}
