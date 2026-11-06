import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/text_normalisation.dart';

/// Words that do not belong in an exercise name or alias (IC-506): brand
/// names, hype words and medical terms. The list is held with the tool and
/// reviewed by the owner (quality-and-duplicates.md section 7, decision 5).
const Set<String> blockedNameWords = {
  // Hype
  'best',
  'ultimate',
  'killer',
  'perfect',
  'guaranteed',
  'insane',
  'extreme',
  'miracle',
  // Medical
  'cure',
  'treatment',
  'therapy',
  'therapeutic',
  'rehab',
  'rehabilitation',
  'injury',
  'pain',
  // Brands and trademarks
  'nike',
  'adidas',
  'reebok',
  'bowflex',
  'nautilus',
  'technogym',
  'cybex',
  'peloton',
  'concept2',
  'rogue',
  'eleiko',
  'gymshark',
  'crossfit',
  'trx',
  'p90x',
  'zumba',
};

/// US spellings that the UK catalogue avoids (IC-507).
const Set<String> usSpellings = {
  'color',
  'center',
  'centered',
  'program',
  'gray',
  'meter',
  'liter',
  'favorite',
  'fiber',
  'defense',
  'tire',
  'stabilizer',
  'stabilize',
  'behavior',
  'neighbor',
  'labor',
};

/// Capitalised words that are proper nouns in exercise names (IC-507).
const Set<String> properNounWords = {
  'arnold',
  'bradford',
  'bulgarian',
  'copenhagen',
  'cossack',
  'dutch',
  'finnish',
  'hindu',
  'jefferson',
  'nordic',
  'olympic',
  'pallof',
  'romanian',
  'russian',
  'scott',
  'smith',
  'spanish',
  'swiss',
  'turkish',
  'zottman',
  'zercher',
};

/// Known UK and US or common synonym pairs of names (IC-509), as `norm`
/// phrases.
const List<(String, String)> synonymPairs = [
  ('press up', 'push up'),
  ('jump rope', 'skipping'),
  ('elliptical', 'cross trainer'),
  ('stationary bike', 'exercise bike'),
  ('hyperextension', 'back extension'),
  ('skull crusher', 'lying triceps extension'),
  ('heel raise', 'calf raise'),
];

Severity _collisionSeverity(Iterable<CatalogueExercise> group) =>
    group.every((e) => e.isSystem) ? Severity.error : Severity.warning;

/// IC-501 to IC-509 over the active exercises of [exercises], per locale.
///
/// Collisions between system exercises are errors; a collision that involves
/// a user or imported exercise is a warning and never blocks the user
/// (quality-and-duplicates.md section 2, IC-500).
List<Finding> validateNames(Iterable<CatalogueExercise> exercises) {
  final active = exercises.where((e) => e.isActive).toList()
    ..sort((a, b) => a.id.compareTo(b.id));
  final locales = <String>{for (final e in active) ...e.names.byLocale.keys};
  final out = <Finding>[];
  for (final locale in (locales.toList()..sort())) {
    out.addAll(_namesInLocale(active, locale));
  }
  return out;
}

typedef _Entry = ({CatalogueExercise exercise, String text, bool isAlias});

List<Finding> _namesInLocale(List<CatalogueExercise> exercises, String locale) {
  final out = <Finding>[];
  final entries = <_Entry>[];
  final names = <CatalogueExercise, String>{};
  for (final e in exercises) {
    final n = e.names.byLocale[locale];
    if (n == null) continue;
    names[e] = n.name;
    entries.add((exercise: e, text: n.name, isAlias: false));
    for (final a in n.aliases) {
      entries.add((exercise: e, text: a, isAlias: true));
    }
  }

  // IC-501 and IC-502: names.
  final byNorm = <String, List<CatalogueExercise>>{};
  final bySquash = <String, List<CatalogueExercise>>{};
  for (final MapEntry(key: e, value: name) in names.entries) {
    byNorm.putIfAbsent(norm(name), () => []).add(e);
    bySquash.putIfAbsent(squash(name), () => []).add(e);
  }
  for (final MapEntry(:key, value: group) in byNorm.entries) {
    if (group.length > 1) {
      out.add(
        Finding(
          code: 'IC-501',
          severity: _collisionSeverity(group),
          message:
              'The name "${names[group.first]}" ($locale) is used by '
              '${group.length} exercises after normalisation ("$key").',
          subjectId: group.first.id.value,
          related: [for (final g in group.skip(1)) g.id.value],
        ),
      );
    }
  }
  for (final group in bySquash.values) {
    final norms = {for (final g in group) norm(names[g]!)};
    if (group.length > 1 && norms.length > 1) {
      out.add(
        Finding(
          code: 'IC-502',
          severity: _collisionSeverity(group),
          message:
              'The names "${names[group.first]}" and "${names[group[1]]}" '
              'are the same once spaces are removed.',
          subjectId: group.first.id.value,
          related: [for (final g in group.skip(1)) g.id.value],
        ),
      );
    }
  }

  // IC-502, IC-503, IC-504: aliases.
  final indexSquash = <String, List<_Entry>>{};
  for (final en in entries) {
    indexSquash.putIfAbsent(squash(en.text), () => []).add(en);
  }
  final reported = <String>{};
  void report(String code, _Entry a, _Entry b, String message) {
    final key = '$code|${a.exercise.id}|${a.text}|${b.exercise.id}|${b.text}';
    final inverse =
        '$code|${b.exercise.id}|${b.text}|${a.exercise.id}|${a.text}';
    if (reported.contains(inverse) || !reported.add(key)) return;
    out.add(
      Finding(
        code: code,
        severity: _collisionSeverity([a.exercise, b.exercise]),
        message: message,
        subjectId: a.exercise.id.value,
        related: [b.exercise.id.value],
      ),
    );
  }

  for (final a in entries.where((e) => e.isAlias)) {
    final nk = norm(a.text);
    final sk = squash(a.text);
    for (final b in indexSquash[sk] ?? const <_Entry>[]) {
      if (identical(a, b)) continue;
      if (b.exercise == a.exercise) {
        if (!b.isAlias) {
          final same = norm(b.text) == nk;
          report(
            same ? 'IC-504' : 'IC-502',
            a,
            b,
            same
                ? 'The alias "${a.text}" equals the name of its own exercise.'
                : 'The alias "${a.text}" equals the name "${b.text}" of its '
                      'own exercise once spaces are removed.',
          );
        } else {
          report(
            'IC-503',
            a,
            b,
            'The aliases "${a.text}" and "${b.text}" of one exercise are '
                'the same after normalisation.',
          );
        }
      } else {
        report(
          'IC-503',
          a,
          b,
          'The alias "${a.text}" equals the ${b.isAlias ? 'alias' : 'name'} '
              '"${b.text}" of ${b.exercise.id} after normalisation.',
        );
      }
    }
  }

  // IC-505, IC-506, IC-507: aliases and names.
  for (final e in names.keys) {
    final aliases = e.names.byLocale[locale]!.aliases;
    if (aliases.length > 6 || aliases.any((a) => a.length > 60)) {
      out.add(
        Finding(
          code: 'IC-505',
          severity: Severity.warning,
          message:
              'The exercise has ${aliases.length} aliases or an alias longer '
              'than 60 characters; the limits are 6 and 60.',
          subjectId: e.id.value,
        ),
      );
    }
  }
  for (final en in entries) {
    final words = norm(en.text).split(' ');
    final blocked = words.where(blockedNameWords.contains).toList();
    if (blocked.isNotEmpty) {
      out.add(
        Finding(
          code: 'IC-506',
          severity: Severity.warning,
          message:
              '"${en.text}" contains the blocked word '
              '"${blocked.first}".',
          subjectId: en.exercise.id.value,
        ),
      );
    }
    final us = words.where(usSpellings.contains).toList();
    if (us.isNotEmpty) {
      out.add(
        Finding(
          code: 'IC-507',
          severity: Severity.warning,
          message: '"${en.text}" uses the US spelling "${us.first}".',
          subjectId: en.exercise.id.value,
        ),
      );
    }
    if (!en.isAlias && !_isSentenceCase(en.text)) {
      out.add(
        Finding(
          code: 'IC-507',
          severity: Severity.warning,
          message: 'The name "${en.text}" is not in sentence case.',
          subjectId: en.exercise.id.value,
        ),
      );
    }
  }

  // IC-508: names within edit distance 2.
  final distinct = byNorm.keys.toList()..sort();
  for (var i = 0; i < distinct.length; i++) {
    for (var j = i + 1; j < distinct.length; j++) {
      if (boundedLevenshtein(distinct[i], distinct[j], 2) <= 2) {
        final a = byNorm[distinct[i]]!.first;
        final b = byNorm[distinct[j]]!.first;
        out.add(
          Finding(
            code: 'IC-508',
            severity: Severity.warning,
            message:
                'The names "${names[a]}" and "${names[b]}" are within an '
                'edit distance of 2.',
            subjectId: a.id.value,
            related: [b.id.value],
          ),
        );
      }
    }
  }

  // IC-509: synonym pairs.
  for (final (x, y) in synonymPairs) {
    for (final MapEntry(key: nameKey, value: group) in byNorm.entries) {
      if (!_containsPhrase(nameKey, x)) continue;
      final other = byNorm[_replacePhrase(nameKey, x, y)];
      if (other == null) continue;
      out.add(
        Finding(
          code: 'IC-509',
          severity: Severity.warning,
          message:
              'The name "${names[group.first]}" is a known synonym of '
              '"${names[other.first]}".',
          subjectId: group.first.id.value,
          related: [other.first.id.value],
        ),
      );
    }
  }
  return out;
}

bool _containsPhrase(String text, String phrase) =>
    ' $text '.contains(' $phrase ');

String _replacePhrase(String text, String from, String to) =>
    ' $text '.replaceAll(' $from ', ' $to ').trim();

/// Sentence case: the first word is capitalised and later words are lower
/// case, except proper nouns, acronyms (two or more capitals) and words with a
/// digit. Names that start with a digit are not checked.
bool _isSentenceCase(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  if (words.isEmpty || words.first.isEmpty) return false;
  final first = words.first;
  final startsWithLetter = RegExp(r'^\p{L}', unicode: true).hasMatch(first);
  if (startsWithLetter && first[0] != first[0].toUpperCase()) return false;
  for (var i = 0; i < words.length; i++) {
    final segments = words[i].split(RegExp('[-/]'));
    for (var s = 0; s < segments.length; s++) {
      final seg = segments[s];
      if (seg.isEmpty || (i == 0 && s == 0)) continue;
      if (!RegExp(r'^\p{Lu}', unicode: true).hasMatch(seg)) continue;
      final core = seg.replaceAll(RegExp(r"['’]s$"), '');
      final isAcronym = RegExp(r'^\p{Lu}{2,}$', unicode: true).hasMatch(core);
      final hasDigit = RegExp(r'\d').hasMatch(core);
      if (isAcronym || hasDigit) continue;
      if (properNounWords.contains(core.toLowerCase())) continue;
      return false;
    }
  }
  return true;
}
