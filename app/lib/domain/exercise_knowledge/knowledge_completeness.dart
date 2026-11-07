import 'package:meta/meta.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge.dart';

/// The elements of the completeness matrix (owner brief of 2026-11-07), in
/// report order.
enum KnowledgeElement {
  identity('Identity', ElementRule.required),
  description('Description', ElementRule.required),
  primaryMuscles('Primary muscles', ElementRule.required),
  secondaryMuscles('Secondary muscles', ElementRule.whereApplicable),
  equipment('Equipment', ElementRule.whereApplicable),
  difficulty('Difficulty', ElementRule.required),
  startingPosition('Starting position', ElementRule.required),
  execution('Execution steps', ElementRule.required),
  breathing('Breathing', ElementRule.required),
  cues('Coaching cues', ElementRule.required),
  mistakes('Common mistakes', ElementRule.required),
  safety('Safety', ElementRule.required),
  visual('Visual', ElementRule.required),
  variations('Variations and alternatives', ElementRule.whereApplicable),
  mediaProvenance('Media provenance', ElementRule.whereApplicable);

  KnowledgeElement(this.label, this.rule);

  final String label;
  final ElementRule rule;
}

/// Whether an element is required for every exercise or only where it
/// applies.
enum ElementRule { required, whereApplicable }

/// The state of one cell of the matrix.
enum ElementStatus {
  /// Present and meeting its rule.
  complete,

  /// Present but incomplete (for example a mistake without its reason).
  partial,

  /// Required, or applicable, and absent.
  missing,

  /// Visual only: no media is available; the designed placeholder is shown
  /// and the gap is recorded.
  placeholder,

  /// The element does not apply to this exercise (recorded as such, with the
  /// reason in the rule table).
  notApplicable,
}

/// One row of the matrix.
@immutable
final class KnowledgeRow {
  const KnowledgeRow({
    required this.exerciseId,
    required this.name,
    required this.cells,
    required this.editorialStatus,
  });

  final String exerciseId;
  final String name;
  final Map<KnowledgeElement, ElementStatus> cells;

  /// `draftAwaitingEditor`, `editorApproved` or `none` (no content).
  final String editorialStatus;

  ElementStatus operator [](KnowledgeElement e) => cells[e]!;

  /// Every required instruction element (description to safety, excluding the
  /// visual) is complete.
  bool get instructionsComplete =>
      _instructionElements.every((e) => cells[e] == ElementStatus.complete);

  /// Every element is complete or not applicable.
  bool get fullyComplete => cells.values.every(
    (s) => s == ElementStatus.complete || s == ElementStatus.notApplicable,
  );
}

const List<KnowledgeElement> _instructionElements = [
  KnowledgeElement.description,
  KnowledgeElement.startingPosition,
  KnowledgeElement.execution,
  KnowledgeElement.breathing,
  KnowledgeElement.cues,
  KnowledgeElement.mistakes,
  KnowledgeElement.safety,
];

/// Computes one matrix row from the knowledge of an exercise.
KnowledgeRow completenessRow(ExerciseKnowledge k) {
  ElementStatus has(List<String> items) =>
      items.isNotEmpty ? ElementStatus.complete : ElementStatus.missing;
  final e = k.exercise;
  final mistakes = k.mistakes;
  final media = k.media;
  final cells = <KnowledgeElement, ElementStatus>{
    KnowledgeElement.identity: e.id.value.isNotEmpty && e.name.trim().isNotEmpty
        ? ElementStatus.complete
        : ElementStatus.missing,
    KnowledgeElement.description: has(k.description),
    KnowledgeElement.primaryMuscles: e.primaryTargets.isNotEmpty
        ? ElementStatus.complete
        : ElementStatus.missing,
    KnowledgeElement.secondaryMuscles: e.secondaryTargets.isNotEmpty
        ? ElementStatus.complete
        : ElementStatus.notApplicable,
    KnowledgeElement.equipment: e.equipment.isNotEmpty
        ? ElementStatus.complete
        : ElementStatus.notApplicable,
    KnowledgeElement.difficulty: e.difficulty != null
        ? ElementStatus.complete
        : ElementStatus.missing,
    KnowledgeElement.startingPosition: has(k.startingPosition),
    KnowledgeElement.execution: has(k.execution),
    KnowledgeElement.breathing: has(k.breathing),
    KnowledgeElement.cues: has(k.cues),
    KnowledgeElement.mistakes: mistakes.isEmpty
        ? ElementStatus.missing
        : mistakes.every((m) => m.isComplete)
        ? ElementStatus.complete
        : ElementStatus.partial,
    KnowledgeElement.safety: has(k.safety),
    KnowledgeElement.visual: k.availableMedia.isNotEmpty
        ? ElementStatus.complete
        : ElementStatus.placeholder,
    KnowledgeElement.variations: k.links.isNotEmpty
        ? ElementStatus.complete
        : ElementStatus.missing,
    KnowledgeElement.mediaProvenance: media.isEmpty
        ? ElementStatus.notApplicable
        : media.every(
            (m) =>
                m.licence.trim().isNotEmpty &&
                m.attribution.trim().isNotEmpty &&
                KnowledgeMediaSources.all.contains(m.source),
          )
        ? ElementStatus.complete
        : ElementStatus.missing,
  };
  return KnowledgeRow(
    exerciseId: e.id.value,
    name: e.name,
    cells: Map.unmodifiable(cells),
    editorialStatus: k.contentProvenance?.status.name ?? 'none',
  );
}

/// The whole matrix with its counts.
@immutable
final class KnowledgeMatrix {
  KnowledgeMatrix(Iterable<ExerciseKnowledge> knowledge)
    : rows = List.unmodifiable(
        <KnowledgeRow>[for (final k in knowledge) completenessRow(k)]
          ..sort((a, b) => a.exerciseId.compareTo(b.exerciseId)),
      );

  final List<KnowledgeRow> rows;

  int get exercises => rows.length;

  int count(KnowledgeElement e, ElementStatus s) =>
      rows.where((r) => r[e] == s).length;

  int get drafted => rows
      .where((r) => r.editorialStatus == ContentStatus.draftAwaitingEditor.name)
      .length;
  int get editorApproved => rows
      .where((r) => r.editorialStatus == ContentStatus.editorApproved.name)
      .length;
  int get withoutContent =>
      rows.where((r) => r.editorialStatus == 'none').length;
  int get instructionsComplete =>
      rows.where((r) => r.instructionsComplete).length;
  int get fullyComplete => rows.where((r) => r.fullyComplete).length;
  int get withVisual => count(KnowledgeElement.visual, ElementStatus.complete);
  int get placeholders =>
      count(KnowledgeElement.visual, ElementStatus.placeholder);
}

String _cell(ElementStatus s) => switch (s) {
  ElementStatus.complete => 'Y',
  ElementStatus.partial => 'P',
  ElementStatus.missing => '-',
  ElementStatus.placeholder => 'ph',
  ElementStatus.notApplicable => 'n/a',
};

/// Renders the completeness report (Markdown). Deterministic: the same
/// matrix and arguments give the same bytes, so a test can recompute it.
String renderCompletenessReport(
  KnowledgeMatrix matrix, {
  required String snapshotDate,
  required String releaseFile,
  required String contentHash,
}) {
  final b = StringBuffer()
    ..writeln('# Exercise content completeness — $snapshotDate')
    ..writeln()
    ..writeln(
      '- Generated by `app/tool/knowledge_report.dart` from '
      '`$releaseFile` (SHA-256 `$contentHash`). Do not edit by hand: '
      '`app/test/domain/exercise_knowledge/completeness_report_test.dart` '
      'recomputes this file from the asset and fails on any difference.',
    )
    ..writeln(
      '- Rules: `docs/catalogue/exercise-knowledge-system.md` section 5. '
      'Editorial rule (owner, D04 section 7): nothing is complete or '
      'published until a named human editor approves it.',
    )
    ..writeln()
    ..writeln('## 1. Summary')
    ..writeln()
    ..writeln('| Measure | Count |')
    ..writeln('|---|---:|')
    ..writeln('| Exercises in the release | ${matrix.exercises} |')
    ..writeln(
      '| Instruction content drafted (status `draftAwaitingEditor`) | '
      '${matrix.drafted} |',
    )
    ..writeln('| Editor-approved | ${matrix.editorApproved} |')
    ..writeln('| Without instruction content | ${matrix.withoutContent} |')
    ..writeln(
      '| All required instruction elements present (drafts) | '
      '${matrix.instructionsComplete} |',
    )
    ..writeln(
      '| With an original RepForge illustration | ${matrix.withVisual} |',
    )
    ..writeln(
      '| Visual gap: designed placeholder shown | ${matrix.placeholders} |',
    )
    ..writeln(
      '| Every element complete or not applicable (drafts) | '
      '${matrix.fullyComplete} |',
    )
    ..writeln()
    ..writeln('## 2. Counts per element')
    ..writeln()
    ..writeln(
      '| Element | Rule | Complete | Partial | Missing | Placeholder | '
      'Not applicable |',
    )
    ..writeln('|---|---|---:|---:|---:|---:|---:|');
  for (final e in KnowledgeElement.values) {
    b.writeln(
      '| ${e.label} | '
      '${e.rule == ElementRule.required ? 'required' : 'where applicable'} | '
      '${matrix.count(e, ElementStatus.complete)} | '
      '${matrix.count(e, ElementStatus.partial)} | '
      '${matrix.count(e, ElementStatus.missing)} | '
      '${matrix.count(e, ElementStatus.placeholder)} | '
      '${matrix.count(e, ElementStatus.notApplicable)} |',
    );
  }
  b
    ..writeln()
    ..writeln('## 3. Matrix')
    ..writeln()
    ..writeln(
      'Y complete, P partial, - missing, ph placeholder shown (visual gap '
      'recorded), n/a not applicable. Columns follow section 2. Status: '
      'editorial status of the instruction content.',
    )
    ..writeln()
    ..write('| Exercise | ')
    ..write(
      [for (var i = 1; i <= KnowledgeElement.values.length; i++) 'E$i']
          .join(' | '),
    )
    ..writeln(' | Status |')
    ..write('|---|')
    ..write([for (final _ in KnowledgeElement.values) ':-:'].join('|'))
    ..writeln('|---|');
  for (final r in matrix.rows) {
    b
      ..write('| `${r.exerciseId}` | ')
      ..write(
        [for (final e in KnowledgeElement.values) _cell(r[e])].join(' | '),
      )
      ..writeln(' | ${r.editorialStatus} |');
  }
  b
    ..writeln()
    ..writeln('Column key:')
    ..writeln();
  for (var i = 0; i < KnowledgeElement.values.length; i++) {
    b.writeln('- E${i + 1}: ${KnowledgeElement.values[i].label}');
  }
  b
    ..writeln()
    ..writeln('## 4. Recorded gaps')
    ..writeln()
    ..writeln(
      '- **Visual:** ${matrix.placeholders} exercises show the designed '
      'placeholder "Illustration not yet available":',
    );
  final gaps = [
    for (final r in matrix.rows)
      if (r[KnowledgeElement.visual] == ElementStatus.placeholder)
        '`${r.exerciseId}`',
  ];
  b.writeln('  ${gaps.isEmpty ? 'none' : gaps.join(', ')}.');
  final noLinks = [
    for (final r in matrix.rows)
      if (r[KnowledgeElement.variations] == ElementStatus.missing)
        '`${r.exerciseId}`',
  ];
  b
    ..writeln(
      '- **Variations and alternatives:** ${noLinks.length} exercises have '
      'no link to another catalogue exercise yet (no suitable exercise in '
      'the current catalogue; candidates for stage 5 tranches):',
    )
    ..writeln('  ${noLinks.isEmpty ? 'none' : noLinks.join(', ')}.')
    ..writeln(
      '- **Editorial review:** ${matrix.drafted} drafts await a named human '
      'editor; ${matrix.editorApproved} are editor-approved.',
    );
  return b.toString();
}
