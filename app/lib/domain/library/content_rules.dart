import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/catalogue_records.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/text_normalisation.dart';

/// Longest sentence before IC-703 warns, in words.
const int maxSentenceWords = 20;

/// Item length limits in characters (IC-701).
const int minItemLength = 10;
const int maxItemLength = 200;

/// Similarity above which two items of different exercises are reported as
/// near-identical (IC-708).
const double nearIdenticalSimilarity = 0.9;

final RegExp _blockedPhrases = RegExp(
  r'\b(cure[sd]?|cur(ing)|treat(s|ed|ing|ment)?|heal(s|ed|ing)?|'
  r'rehabilitat\w*|prevent(s|ed|ing)?\s+(an\s+)?injur\w*|'
  r'reduc\w*\s+(the\s+)?pain|burn(s|ed|ing)?\s+(body\s+)?fat|guarantee\w*)\b',
  caseSensitive: false,
);

final RegExp _prescription = RegExp(
  r'\d+\s*(reps?|sets?|kg|lbs?|%)|\d+\s*x\s*\d+|\b\d+x\b',
  caseSensitive: false,
);

final RegExp _nonMetricOrUs = RegExp(
  r'\b(pounds?|lbs?|ounces?|inch(es)?|miles?|yards?|colou?r|color|center|'
  r'meter|gray|program|stabiliz\w*)\b',
  caseSensitive: false,
);

final RegExp _passive = RegExp(
  r'\b(is|are|was|were|be|been|being)\s+\w+(ed|en)\b',
  caseSensitive: false,
);

List<String> _sentences(String text) => text
    .trim()
    .split(RegExp(r'(?<=[.!?])\s+'))
    .where((s) => s.trim().isNotEmpty)
    .toList();

/// IC-210 and IC-701 to IC-710 over the instruction [content] of [exercises].
///
/// IC-210 (the four sections present and non-empty for every active system
/// exercise) is an error once the exercise's tranche is complete
/// ([missingContentIsError]) and a warning before. Content for an exercise
/// that is not in [exercises] is reported as IC-709-independent orphan under
/// IC-402's family: it cannot be checked and is listed as an error here.
List<Finding> validateContent(
  Iterable<CatalogueExercise> exercises,
  Iterable<ContentSection> content, {
  bool missingContentIsError = false,
}) {
  final out = <Finding>[];
  final byExercise = <ExerciseId, List<ContentSection>>{};
  for (final c in content) {
    byExercise.putIfAbsent(c.exerciseId, () => []).add(c);
  }
  final known = {for (final e in exercises) e.id};
  for (final id in byExercise.keys.where((id) => !known.contains(id))) {
    out.add(
      Finding(
        code: 'ED-701',
        severity: Severity.error,
        message: 'Content is stored for the unknown exercise $id.',
        subjectId: id.value,
      ),
    );
  }

  for (final e in exercises) {
    final rows = byExercise[e.id] ?? const <ContentSection>[];
    if (e.isSystem && e.isActive) {
      final missing = <String>[];
      for (final kind in ContentSectionKinds.core) {
        final present = rows.any(
          (r) =>
              r.locale == canonicalLocale &&
              r.kind == kind &&
              r.body.trim().isNotEmpty,
        );
        if (!present) missing.add(kind);
      }
      if (missing.isNotEmpty) {
        out.add(
          Finding(
            code: 'IC-210',
            severity: missingContentIsError ? Severity.error : Severity.warning,
            message: 'The instructions lack: ${missing.join(', ')}.',
            subjectId: e.id.value,
            field: 'content',
          ),
        );
      }
    }
    // Counts per (locale, kind) and the en-GB counterpart rule.
    final counts = <String, int>{};
    final localesByKind = <String, Set<String>>{};
    for (final r in rows) {
      counts.update('${r.locale}|${r.kind}', (n) => n + 1, ifAbsent: () => 1);
      localesByKind.putIfAbsent(r.kind, () => {}).add(r.locale);
      if (!ContentSectionKinds.isControlled(r.kind)) {
        out.add(
          Finding(
            code: 'IC-308',
            severity: Severity.error,
            message:
                'The section kind "${r.kind}" is not in the controlled list.',
            subjectId: e.id.value,
            field: 'content',
          ),
        );
      }
    }
    for (final MapEntry(:key, value: count) in counts.entries) {
      final parts = key.split('|');
      final range = ContentSectionKinds.itemCounts[parts[1]];
      if (range != null && (count < range.$1 || count > range.$2)) {
        out.add(
          Finding(
            code: 'IC-702',
            severity: Severity.error,
            message:
                'The ${parts[1]} section (${parts[0]}) has $count items; it '
                'needs ${range.$1} to ${range.$2}.',
            subjectId: e.id.value,
            field: 'content',
          ),
        );
      }
    }
    for (final MapEntry(key: kind, value: locales) in localesByKind.entries) {
      if (!locales.contains(canonicalLocale)) {
        out.add(
          Finding(
            code: 'IC-709',
            severity: Severity.error,
            message:
                'The $kind section exists in '
                '${(locales.toList()..sort()).join(', ')} '
                'but not in $canonicalLocale.',
            subjectId: e.id.value,
            field: 'content',
          ),
        );
      }
    }
    for (final r in rows) {
      out.addAll(_itemFindings(e.id, r));
    }
  }
  out.addAll(_nearIdentical(content));
  return out;
}

Iterable<Finding> _itemFindings(ExerciseId id, ContentSection r) sync* {
  Finding f(String code, Severity s, String message) => Finding(
    code: code,
    severity: s,
    message: '${r.kind} item ${r.ordinal + 1} (${r.locale}): $message',
    subjectId: id.value,
    field: 'content',
  );

  final body = r.body.trim();
  if (body.length < minItemLength || body.length > maxItemLength) {
    yield f(
      'IC-701',
      Severity.error,
      'has ${body.length} characters; items are $minItemLength to '
          '$maxItemLength.',
    );
  }
  final sentences = _sentences(body);
  if (sentences.any((s) => s.split(RegExp(r'\s+')).length > maxSentenceWords)) {
    yield f(
      'IC-703',
      Severity.warning,
      'has a sentence of more than $maxSentenceWords words.',
    );
  }
  if (_blockedPhrases.hasMatch(body)) {
    yield f(
      'IC-704',
      Severity.error,
      'makes a medical or outcome claim '
          '("${_blockedPhrases.firstMatch(body)![0]}").',
    );
  }
  if (_prescription.hasMatch(body)) {
    yield f(
      'IC-705',
      Severity.warning,
      'contains a prescription ("${_prescription.firstMatch(body)![0]}").',
    );
  }
  if (_nonMetricOrUs.hasMatch(body)) {
    yield f(
      'IC-706',
      Severity.warning,
      'uses a US spelling or non-metric unit '
          '("${_nonMetricOrUs.firstMatch(body)![0]}").',
    );
  }
  if (_passive.hasMatch(body)) {
    yield f(
      'IC-707',
      Severity.warning,
      'may use the passive voice ("${_passive.firstMatch(body)![0]}").',
    );
  }
  if (r.kind == ContentSectionKinds.commonMistakes && sentences.length < 2) {
    yield f(
      'IC-710',
      Severity.warning,
      'names a fault without a fix sentence.',
    );
  }
}

/// IC-708: identical or near-identical item text across two exercises.
Iterable<Finding> _nearIdentical(Iterable<ContentSection> content) sync* {
  final byKey = <String, List<(ContentSection, String)>>{};
  for (final c in content) {
    final text = norm(c.body);
    if (text.isEmpty) continue;
    byKey.putIfAbsent('${c.locale}|${c.kind}', () => []).add((c, text));
  }
  final reported = <String>{};
  for (final items in byKey.values) {
    items.sort((a, b) => a.$2.length.compareTo(b.$2.length));
    for (var i = 0; i < items.length; i++) {
      for (var j = i + 1; j < items.length; j++) {
        final a = items[i];
        final b = items[j];
        if (b.$2.length > a.$2.length * 1.2 + 2) break;
        if (a.$1.exerciseId == b.$1.exerciseId) continue;
        final similarity = a.$2 == b.$2 ? 1.0 : _bigramDice(a.$2, b.$2);
        if (similarity > nearIdenticalSimilarity) {
          final pair = [a.$1.exerciseId.value, b.$1.exerciseId.value]..sort();
          if (reported.add('${a.$1.kind}|${pair.join('|')}|${a.$2}')) {
            yield Finding(
              code: 'IC-708',
              severity: Severity.warning,
              message:
                  'A ${a.$1.kind} item is near-identical in ${pair[0]} and '
                  '${pair[1]} (similarity ${similarity.toStringAsFixed(2)}).',
              subjectId: pair[0],
              field: 'content',
              related: [pair[1]],
            );
          }
        }
      }
    }
  }
}

double _bigramDice(String a, String b) {
  Map<String, int> bigrams(String s) {
    final m = <String, int>{};
    for (var i = 0; i < s.length - 1; i++) {
      m.update(s.substring(i, i + 2), (n) => n + 1, ifAbsent: () => 1);
    }
    return m;
  }

  final x = bigrams(a);
  final y = bigrams(b);
  var overlap = 0;
  for (final e in x.entries) {
    final other = y[e.key];
    if (other != null) overlap += e.value < other ? e.value : other;
  }
  final total = (a.length - 1) + (b.length - 1);
  return total <= 0 ? 0 : 2 * overlap / total;
}
