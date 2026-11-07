import 'package:repforge/domain/exercise_knowledge/exercise_knowledge.dart';
import 'package:repforge/domain/library/catalogue_records.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/release/release_format.dart';

/// Knowledge-system checks (KS codes) over a parsed release, in addition to
/// the integrity checks the release validator runs (`IC-xxx`, including the
/// IC-700 content rules for every section kind). They cover what the IC
/// checks do not: content provenance, the pairing of mistakes with their
/// reasons, and the media fields of specification revision 2.
///
/// Codes (all errors except KS-103, a warning):
/// - KS-101: instruction content records content provenance.
/// - KS-102: editor-approved content names the editor and the date.
/// - KS-103: content provenance without any content.
/// - KS-104: content provenance names an author.
/// - KS-201: `mistakeEffects` has one item per `commonMistakes` item.
/// - KS-202: a `commonMistakes` item has a fault and a fix sentence.
/// - KS-301: media kind is image, illustration, animation or video.
/// - KS-302: media purpose is start, execution, finish or overview.
/// - KS-303: media has a caption.
/// - KS-304: media source is original or licensed (with a licence).
/// - KS-305: media availability is available or unavailable.
/// - KS-306: no media locator needs external hosting (no URL scheme).
/// - KS-307: an available media locator uses a bundled scheme.
/// - KS-308: no prohibited source (scraped or proprietary site) is named.
List<Finding> checkKnowledge(ReleaseDocument document) {
  final out = <Finding>[];
  Finding f(
    String code,
    String message,
    ExerciseId id, {
    Severity severity = Severity.error,
    String? field,
  }) => Finding(
    code: code,
    severity: severity,
    message: message,
    subjectId: id.value,
    field: field,
  );

  final items = <ExerciseId, Map<String, List<ContentSection>>>{};
  for (final c in document.content) {
    if (c.locale != canonicalLocale) continue;
    items
        .putIfAbsent(c.exerciseId, () => {})
        .putIfAbsent(c.kind, () => [])
        .add(c);
  }

  for (final e in document.exercises) {
    final sections = items[e.id] ?? const {};
    final hasContent = sections.values.any((v) => v.isNotEmpty);
    final cp = document.contentProvenance[e.id];
    if (hasContent && cp == null) {
      out.add(f('KS-101', 'Instruction content has no provenance.', e.id));
    }
    if (cp != null) {
      if (cp.authoredBy.trim().isEmpty) {
        out.add(f('KS-104', 'Content provenance names no author.', e.id));
      }
      if (cp.status == ContentStatus.editorApproved &&
          ((cp.editor?.trim().isEmpty ?? true) || cp.approvedOn == null)) {
        out.add(
          f(
            'KS-102',
            'Content marked editor-approved must name the editor and the '
                'approval date.',
            e.id,
          ),
        );
      }
      if (!hasContent) {
        out.add(
          f(
            'KS-103',
            'Content provenance is recorded but there is no content.',
            e.id,
            severity: Severity.warning,
          ),
        );
      }
    }
    final mistakes = sections[ContentSectionKinds.commonMistakes] ?? const [];
    final effects = sections[ContentSectionKinds.mistakeEffects] ?? const [];
    if (effects.isNotEmpty && effects.length != mistakes.length) {
      out.add(
        f(
          'KS-201',
          'There are ${effects.length} mistake reasons for '
              '${mistakes.length} mistakes.',
          e.id,
          field: 'content',
        ),
      );
    }
    for (final m in mistakes) {
      final parsed = CommonMistake.fromItem(m.body);
      if (parsed.fix.isEmpty) {
        out.add(
          f(
            'KS-202',
            'Mistake ${m.ordinal + 1} has no fix sentence ("Fault. Fix.").',
            e.id,
            field: 'content',
          ),
        );
      }
    }
  }

  final prohibited = RegExp(
    r'bodybuilding\.com|scraped|screenshot',
    caseSensitive: false,
  );
  final urlScheme = RegExp('^[a-z][a-z0-9+.-]*://', caseSensitive: false);
  for (final m in document.media) {
    void bad(String code, String message) => out.add(
      f(code, 'Media ${m.id}: $message', m.exerciseId, field: 'media'),
    );
    if (!KnowledgeMediaKinds.all.contains(m.kind)) {
      bad('KS-301', 'unknown kind "${m.kind}".');
    }
    if (!KnowledgeMediaPurposes.all.contains(m.purpose)) {
      bad('KS-302', 'unknown or missing purpose "${m.purpose}".');
    }
    if ((m.caption?.trim().length ?? 0) < 3) {
      bad('KS-303', 'a caption is required.');
    }
    if (!KnowledgeMediaSources.all.contains(m.source)) {
      bad('KS-304', 'source must be original or licensed, not "${m.source}".');
    } else if (m.source == KnowledgeMediaSources.licensed &&
        (m.licence.trim().isEmpty || m.licence.contains('proprietary'))) {
      bad('KS-304', 'licensed media must name its licence.');
    }
    if (!KnowledgeMediaAvailability.all.contains(m.availability)) {
      bad('KS-305', 'availability must be available or unavailable.');
    }
    if (urlScheme.hasMatch(m.locator) || m.locator.startsWith('//')) {
      bad('KS-306', 'the locator needs external hosting (${m.locator}).');
    } else if (m.availability == KnowledgeMediaAvailability.available &&
        !m.locator.startsWith(builtInIllustrationScheme) &&
        !m.locator.startsWith(bundledAssetScheme)) {
      bad('KS-307', 'an available item must be bundled (${m.locator}).');
    }
    for (final text in [m.locator, m.attribution, m.licence, m.caption ?? '']) {
      if (prohibited.hasMatch(text)) {
        bad('KS-308', 'names a prohibited source.');
        break;
      }
    }
  }
  return sortedFindings(out);
}
