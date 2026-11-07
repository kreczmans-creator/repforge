import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/exercise_knowledge/exercise_knowledge.dart';
import 'package:repforge/domain/exercise_knowledge/knowledge_checks.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/reference_parsers.dart';
import 'package:repforge/domain/library/release/release_format.dart';
import 'package:repforge/domain/library/release/release_hash.dart';
import 'package:repforge/domain/library/release/release_parser.dart';

export 'package:repforge/domain/library/release/release_format.dart'
    show ReleaseReferenceName;

/// The result of asking for the knowledge of one exercise.
sealed class KnowledgeLookup {
  const KnowledgeLookup();
}

/// The catalogue holds a record for the exercise. Its sections may still be
/// empty; the screen shows each missing section as "not written yet".
final class KnowledgeFound extends KnowledgeLookup {
  const KnowledgeFound(this.knowledge);
  final ExerciseKnowledge knowledge;
}

/// The catalogue loaded but has no record for the id: a custom or imported
/// exercise, or a system exercise the release does not describe.
final class KnowledgeNotAuthored extends KnowledgeLookup {
  const KnowledgeNotAuthored();
}

/// The catalogue holds guidance for the exercise, but no named editor has
/// approved it and drafts are not shown (owner decision KS-D9 pending; see
/// [applyPublicationPolicy]).
final class KnowledgeAwaitingReview extends KnowledgeLookup {
  const KnowledgeAwaitingReview(this.knowledge);

  /// The draft, kept for the screen's classification only; its text and
  /// media are not shown.
  final ExerciseKnowledge knowledge;
}

/// The catalogue could not be read (not bundled in this build, or invalid).
/// Nothing is invented; the screen degrades to its basic details.
final class KnowledgeUnavailable extends KnowledgeLookup {
  const KnowledgeUnavailable(this.reason);
  final String reason;
}

/// Publication rule (owner editorial rule, D04 section 7; KS-D9): only
/// editor-approved guidance is shown. Drafts are shown only when
/// [showDrafts] is true, which is off by default.
KnowledgeLookup applyPublicationPolicy(
  KnowledgeLookup lookup, {
  required bool showDrafts,
}) {
  if (lookup case KnowledgeFound(:final knowledge)
      when !showDrafts &&
          knowledge.contentProvenance?.status != ContentStatus.editorApproved) {
    return KnowledgeAwaitingReview(knowledge);
  }
  return lookup;
}

/// Domain port: read-only, offline access to exercise knowledge by stable
/// exercise id. Implementations never use the network.
abstract interface class ExerciseKnowledgeSource {
  Future<KnowledgeLookup> lookup(String exerciseId);
}

/// The bytes a knowledge catalogue is built from: the release file and,
/// optionally, the approved reference files it points at (for labels).
@immutable
final class KnowledgeBundle {
  const KnowledgeBundle({required this.release, this.reference = const {}});

  final List<int> release;

  /// Reference file bytes by section; a file whose hash differs from the one
  /// the release declares is ignored (labels then fall back to ids).
  final Map<ReleaseReferenceName, List<int>> reference;
}

/// Builds the knowledge catalogue from a bundle. Fails (never throws) when
/// the release does not parse or breaks a knowledge rule of severity error.
Result<KnowledgeCatalogue> loadKnowledgeCatalogue(KnowledgeBundle bundle) {
  final parsed = parseReleaseBytes(bundle.release);
  final document = parsed.document;
  if (document == null) {
    final first = parsed.findings.isEmpty ? null : parsed.findings.first;
    return Err(
      ValidationError(
        'The exercise catalogue could not be read'
        '${first == null ? '' : ': ${first.code} ${first.message}'}',
      ),
    );
  }
  final errors = [
    for (final f in checkKnowledge(document))
      if (f.severity == Severity.error) f,
  ];
  if (errors.isNotEmpty) {
    return Err(
      ValidationError(
        'The exercise catalogue breaks ${errors.length} knowledge rule(s); '
        'first: ${errors.first.code} ${errors.first.message}',
      ),
    );
  }
  return Ok(
    KnowledgeCatalogue.fromRelease(
      document,
      labels: referenceLabelsFor(document, bundle.reference),
      contentHash: parsed.contentHash,
    ),
  );
}

/// Labels from the approved reference files whose bytes match the hashes the
/// release declares. A missing or mismatched file contributes nothing.
ReferenceLabels referenceLabelsFor(
  ReleaseDocument document,
  Map<ReleaseReferenceName, List<int>> files,
) {
  Object? decoded(ReleaseReferenceName name) {
    final bytes = files[name];
    final declared = document.reference[name];
    if (bytes == null || declared == null) return null;
    if (releaseContentHash(bytes) != declared.sha256) return null;
    try {
      return jsonDecode(utf8.decode(bytes));
    } on FormatException {
      return null;
    }
  }

  final anatomy = parseAnatomyReference(decoded(ReleaseReferenceName.anatomy));
  final patterns = parsePatternReference(
    decoded(ReleaseReferenceName.movementPatterns),
  );
  final equipment = parseEquipmentReference(
    decoded(ReleaseReferenceName.equipment),
  );
  return ReferenceLabels(
    anatomy: switch (anatomy) {
      Ok(:final value) => {for (final n in value.nodes) n.id.value: n.label},
      Err() => const {},
    },
    patterns: switch (patterns) {
      Ok(:final value) => {for (final n in value.nodes) n.id.value: n.label},
      Err() => const {},
    },
    equipment: switch (equipment) {
      Ok(:final value) => {for (final n in value.items) n.id.value: n.label},
      Err() => const {},
    },
    supportEquipment: switch (equipment) {
      Ok(:final value) => {
        for (final n in value.items)
          if (n.defaultRole == EquipmentDefaultRole.support) n.id.value,
      },
      Err() => const {},
    },
  );
}
