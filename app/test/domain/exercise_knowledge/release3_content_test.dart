import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge.dart';
import 'package:repforge/domain/exercise_knowledge/knowledge_checks.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/release/release_parser.dart';
import 'package:repforge/domain/library/release/release_validator.dart';
import 'package:repforge/domain/library/sha256_hex.dart';
import 'package:repforge/features/training/presentation/exercise_illustration.dart';

import '../library/release/support/release_support.dart';
import 'support/knowledge_support.dart';

/// The shipped knowledge release (release 3): schema, identity, references,
/// provenance, content rules and media, checked from the asset itself.
void main() {
  final release2 = release2Map();
  final release3 = release3Map();
  final ids2 = [for (final e in exercisesOf(release2)) e['id']! as String];
  final ex3 = exercisesIn(release3);

  group('schema and validation', () {
    test('parses as release format 2 and passes the full release validation '
        'against release 2 with zero errors', () {
      final parsed = parseReleaseBytes(release3Bytes());
      expect(parsed.ok, isTrue, reason: '${parsed.findings.take(5)}');
      final reference = approvedSet();
      final previous = validateReleaseBytes(
        bytes: release2Bytes(),
        reference: reference,
      );
      expect(previous.isValid, isTrue);
      final v = validateReleaseBytes(
        bytes: release3Bytes(),
        reference: reference,
        previous: previousCatalogueOf(previous.release!),
      );
      expect(v.errors, isEmpty, reason: '${v.errors.take(5)}');
      // Instructions now exist for every exercise; the family worklist is
      // linked.
      expect(v.report!.findingsFor('IC-210'), isEmpty);
      expect(v.report!.findingsFor('IC-412'), isEmpty);
      expect(v.report!.findingsFor('IC-704'), isEmpty, reason: 'no claims');
    });

    test('the knowledge checks report no error and no warning', () {
      final doc = parseReleaseBytes(release3Bytes()).document!;
      expect(checkKnowledge(doc), isEmpty);
    });

    test('release 3 has the 89 ids of release 2, in the same order, at '
        'revision 3, with classifications unchanged', () {
      expect(release3['release'], 3);
      expect(release3['formatVersion'], 2);
      expect([for (final e in ex3) e['id']], ids2);
      final byId2 = {for (final e in exercisesOf(release2)) e['id']: e};
      const knowledgeKeys = {
        'revision',
        'relationships',
        'content',
        'contentProvenance',
        'media',
      };
      for (final e in ex3) {
        expect(e['revision'], 3, reason: '${e['id']}');
        final before = byId2[e['id']]!;
        for (final k in {...before.keys, ...e.keys}) {
          if (knowledgeKeys.contains(k)) continue;
          expect(
            jsonEncode(e[k]),
            jsonEncode(before[k]),
            reason: '${e['id']}.$k must not change',
          );
        }
      }
      expect(release3['reference'], release2['reference']);
      expect(release3['provider'], release2['provider']);
    });

    test('the seed file is untouched by the knowledge work (pinned bytes, '
        'WP8 R-30; docs/schema-v8.md)', () {
      final seed = File('assets/seed/exercise_library.json').readAsBytesSync();
      expect(
        sha256Hex(seed),
        '839d9ca28f043e61ed502b4bf765ca1ff8110fc21b54e84d98014c3b8d5e0b22',
      );
    });
  });

  group('every seed exercise has a knowledge record', () {
    test(
      'all ids of the seed catalogue resolve in the knowledge catalogue',
      () {
        final seed = jsonDecode(
          File('assets/seed/exercise_library.json').readAsStringSync(),
        ) as Map<String, Object?>;
        final seedIds = [
          for (final e in (seed['exercises']! as List<Object?>))
            (e! as Map<String, Object?>)['id']! as String,
        ];
        expect(seedIds, hasLength(89));
        final catalogue = shippedCatalogue();
        for (final id in seedIds) {
          expect(catalogue[id], isNotNull, reason: id);
          expect(catalogue[id]!.hasInstructions, isTrue, reason: id);
        }
      },
    );
  });

  group('references resolve', () {
    test('every relationship ends on a real exercise of the release', () {
      final ids = {for (final e in ex3) e['id']};
      var count = 0;
      for (final e in ex3) {
        for (final r in (e['relationships'] as List<Object?>? ?? const [])) {
          final to = (r! as Map<String, Object?>)['to'];
          expect(ids, contains(to), reason: '${e['id']} -> $to');
          count++;
        }
      }
      expect(count, greaterThan(40));
    });

    test('every link shown on screen names a real exercise', () {
      final catalogue = shippedCatalogue();
      for (final k in catalogue.all) {
        for (final l in k.links) {
          expect(catalogue[l.exerciseId.value], isNotNull);
          expect(l.name, catalogue[l.exerciseId.value]!.name);
        }
      }
    });
  });

  group('provenance and editorial status', () {
    test('every exercise with content records AI-drafted provenance, no '
        'editor and draftAwaitingEditor', () {
      for (final e in ex3) {
        final p = e['contentProvenance']! as Map<String, Object?>;
        expect(p['authoredBy'], 'RepForge (AI-drafted)', reason: '${e['id']}');
        expect(p['editor'], isNull);
        expect(p['status'], 'draftAwaitingEditor');
        expect(p['draftingAssistance'], contains('AI'));
        expect(p['draftedOn'], '2026-11-07');
      }
      final catalogue = shippedCatalogue();
      expect(
        catalogue.all.where(
          (k) => k.contentProvenance?.status == ContentStatus.editorApproved,
        ),
        isEmpty,
        reason: 'nothing is editor-approved until a named editor reviews it',
      );
    });
  });

  group('content rules (editorial guide, IC-700, owner brief)', () {
    final catalogue = shippedCatalogue();

    test('section item counts are within the editorial limits', () {
      for (final k in catalogue.all) {
        for (final MapEntry(:key, :value) in k.content.entries) {
          final range = ContentSectionKinds.itemCounts[key]!;
          expect(
            value.length,
            inInclusiveRange(range.$1, range.$2),
            reason: '${k.id} $key',
          );
        }
      }
    });

    test('every mistake has a fault, a reason and a fix', () {
      for (final k in catalogue.all) {
        expect(k.mistakes, isNotEmpty);
        for (final m in k.mistakes) {
          expect(m.isComplete, isTrue, reason: '${k.id}: ${m.fault}');
        }
      }
    });

    test('no prescriptions, URLs or brand claims in the text', () {
      final bad = RegExp(
        r'https?://|www\.|bodybuilding\.com|\d+\s*(reps?|sets?|kg|lbs?|%)|'
        r'\b(best|perfect|guaranteed|cure|heal)\b',
        caseSensitive: false,
      );
      for (final k in catalogue.all) {
        for (final items in k.content.values) {
          for (final t in items) {
            expect(bad.hasMatch(t), isFalse, reason: '${k.id}: $t');
          }
        }
      }
    });

    test('tempo is given only where it is written, never invented', () {
      final withTempo = catalogue.all.where((k) => k.tempo.isNotEmpty).length;
      expect(withTempo, lessThan(catalogue.all.length));
      for (final k in catalogue.all.where((k) => k.tempo.isNotEmpty)) {
        expect(k.tempo, hasLength(1));
      }
    });
  });

  group('media', () {
    final catalogue = shippedCatalogue();
    final withMedia = [
      for (final k in catalogue.all)
        if (k.media.isNotEmpty) k,
    ];

    test('ten exercises carry original illustrations; several carry more '
        'than one stage, in sequence order', () {
      expect(withMedia, hasLength(10));
      final multi = withMedia.where((k) => k.media.length > 1).toList();
      expect(multi.length, greaterThanOrEqualTo(8));
      for (final k in multi) {
        expect(
          [for (final m in k.media) m.ordinal],
          [for (var i = 0; i < k.media.length; i++) i],
        );
        expect(k.media.first.purpose, KnowledgeMediaPurposes.start);
        expect(k.media.last.purpose, KnowledgeMediaPurposes.finish);
      }
    });

    test('every media item is original, available, bundled and resolves to '
        'a built-in illustration', () {
      for (final k in withMedia) {
        for (final m in k.media) {
          expect(m.kind, KnowledgeMediaKinds.illustration);
          expect(m.source, KnowledgeMediaSources.original);
          expect(m.isAvailable, isTrue);
          expect(m.licence, 'proprietary (RepForge)');
          expect(m.attribution, isNotEmpty);
          expect(m.caption.length, greaterThan(10));
          expect(m.locator, startsWith(builtInIllustrationScheme));
          expect(
            exerciseIllustrations,
            contains(m.builtInIllustrationKey),
            reason: m.locator,
          );
        }
      }
    });

    test('no media of any exercise needs external hosting', () {
      for (final k in catalogue.all) {
        for (final m in k.media) {
          expect(m.locator, isNot(contains('://')));
        }
      }
    });
  });
}
