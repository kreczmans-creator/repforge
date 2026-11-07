import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge.dart';
import 'package:repforge/domain/exercise_knowledge/knowledge_completeness.dart';
import 'package:repforge/domain/library/release/release_parser.dart';

import '../../../tool/knowledge_report.dart';
import 'support/knowledge_support.dart';

const String _reportPath =
    '../docs/catalogue/content-completeness-2026-11-07.md';

void main() {
  final matrix = KnowledgeMatrix(shippedCatalogue().all);

  group('completeness matrix over the shipped release', () {
    test('exact counts: 89 exercises, 89 drafts, 0 editor-approved, 10 with '
        'an illustration, 79 placeholders', () {
      expect(matrix.exercises, 89);
      expect(matrix.drafted, 89);
      expect(matrix.editorApproved, 0);
      expect(matrix.withoutContent, 0);
      expect(matrix.withVisual, 10);
      expect(matrix.placeholders, 79);
      expect(matrix.withVisual + matrix.placeholders, matrix.exercises);
    });

    test('instruction completeness: every required instruction element is '
        'present for every exercise', () {
      for (final r in matrix.rows) {
        expect(r.instructionsComplete, isTrue, reason: r.exerciseId);
        for (final e in KnowledgeElement.values) {
          if (e.rule == ElementRule.required && e != KnowledgeElement.visual) {
            expect(r[e], ElementStatus.complete, reason: '${r.exerciseId} $e');
          }
        }
      }
    });

    test('where-applicable elements are never reported as partial', () {
      for (final r in matrix.rows) {
        expect(r.cells.values, isNot(contains(ElementStatus.partial)));
      }
    });
  });

  group('matrix rules', () {
    KnowledgeRow rowFor(Map<String, Object?> exercise) {
      final map = release3Map()..['exercises'] = [exercise];
      exercise.remove('relationships');
      final doc = parseReleaseJson(jsonDecode(jsonEncode(map))).document!;
      return completenessRow(KnowledgeCatalogue.fromRelease(doc).all.single);
    }

    Map<String, Object?> exercise(String id) =>
        exercisesIn(release3Map()).firstWhere((e) => e['id'] == id);

    test('a mistake without its reason is partial; missing sections are '
        'missing; no media is a placeholder and media provenance is n/a', () {
      final e = exercise('lib-bench-press');
      ((e['content']! as Map<String, Object?>)['en-GB']!
            as Map<String, Object?>)
        ..remove('mistakeEffects')
        ..remove('description')
        ..remove('cues');
      final row = rowFor(e);
      expect(row[KnowledgeElement.mistakes], ElementStatus.partial);
      expect(row[KnowledgeElement.description], ElementStatus.missing);
      expect(row[KnowledgeElement.cues], ElementStatus.missing);
      expect(row[KnowledgeElement.visual], ElementStatus.placeholder);
      expect(
        row[KnowledgeElement.mediaProvenance],
        ElementStatus.notApplicable,
      );
      expect(row[KnowledgeElement.variations], ElementStatus.missing);
      expect(row.instructionsComplete, isFalse);
      expect(row.fullyComplete, isFalse);
    });

    test('bodyweight: no equipment is not applicable; media with provenance '
        'is complete', () {
      final row = rowFor(exercise('lib-push-up'));
      expect(row[KnowledgeElement.equipment], ElementStatus.notApplicable);
      expect(row[KnowledgeElement.visual], ElementStatus.complete);
      expect(row[KnowledgeElement.mediaProvenance], ElementStatus.complete);
      expect(row.editorialStatus, 'draftAwaitingEditor');
    });

    test('an exercise without content has editorial status none', () {
      final e = exercise('lib-plank')
        ..remove('content')
        ..remove('contentProvenance');
      final row = rowFor(e);
      expect(row.editorialStatus, 'none');
      expect(row[KnowledgeElement.execution], ElementStatus.missing);
    });
  });

  group('report', () {
    test(
      'the committed report equals the report recomputed from the asset',
      () {
        final built = buildKnowledgeReport(
          releaseBytes: release3Bytes(),
          reference: shippedReferenceBytes(),
          date: '2026-11-07',
          releaseFile: 'app/$defaultRelease',
        );
        final text = (built as Ok<String>).value;
        expect(File(_reportPath).readAsStringSync(), text);
        expect(text, contains('| Exercises in the release | 89 |'));
        expect(text, contains('| Editor-approved | 0 |'));
        expect(
          text,
          contains('| Visual gap: designed placeholder shown | 79 |'),
        );
      },
    );

    test('the report is deterministic', () {
      String render() => renderCompletenessReport(
        matrix,
        snapshotDate: '2026-11-07',
        releaseFile: 'x',
        contentHash: 'y',
      );
      expect(render(), render());
    });
  });
}
