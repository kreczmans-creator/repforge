/// Name normalisation of the integrity checks (`quality-and-duplicates.md`
/// IC-500): `norm` and `squash`, the name tokens of the near-duplicate
/// signature, and edit distance.
///
/// The comparison key is full Unicode NFKD (owner decision, 2026-11-06), then
/// the removal of combining diacritics, then case folding, then the
/// punctuation and whitespace rules below. Only the combining-diacritic
/// blocks lose their marks (general category Mn inside U+0300 to U+036F,
/// U+1AB0 to U+1AFF, U+1DC0 to U+1DFF, U+20D0 to U+20FF and U+FE20 to
/// U+FE2F). Marks of other scripts, such as the Devanagari virama, Thai,
/// Hebrew and Arabic points, change the word and stay. Dart's core
/// library has no NFKD and no package is added for it (engineering standards
/// section 4), so the decomposition comes from the generated constant table in
/// `text_normalisation_table.g.dart`. The table holds every code point of
/// every plane whose NFKD form differs from itself; Hangul syllables
/// (U+AC00 to U+D7A3) use the standard algorithm in this file. The
/// diacritic mark ranges and the lower-case map are generated too. A character
/// outside the table has no decomposition and stays as it is.
///
/// Case folding lower-cases each code point by the generated map (not by the
/// platform's `toLowerCase`). It then adds `ß` to `ss` and the final sigma
/// `ς` to `σ`. Five letters have no NFKD decomposition; by owner decision
/// (2026-11-06) the key folds them: `ø` to `o`, `đ` to `d`, `ł` to `l`,
/// `æ` to `ae` and `œ` to `oe`. Upper-case forms fold the same way. Other
/// such letters (for example `ħ`, `ŧ`, `ı`) stay distinct: this is not a
/// transliteration. Display names are never changed; only the key is.
library;

import 'package:repforge/domain/library/text_normalisation_table.g.dart';

const int _sBase = 0xAC00;
const int _lBase = 0x1100;
const int _vBase = 0x1161;
const int _tBase = 0x11A7;
const int _tCount = 28;
const int _nCount = 588;
const int _sCount = 11172;

/// Appends the NFKD form of [rune] to [out] (not yet mark-stripped).
void _decompose(int rune, StringBuffer out) {
  final sIndex = rune - _sBase;
  if (sIndex >= 0 && sIndex < _sCount) {
    // Hangul syllable: the standard algorithmic decomposition.
    out
      ..writeCharCode(_lBase + sIndex ~/ _nCount)
      ..writeCharCode(_vBase + (sIndex % _nCount) ~/ _tCount);
    final t = _tBase + sIndex % _tCount;
    if (t != _tBase) out.writeCharCode(t);
    return;
  }
  final d = nfkdDecomposition[rune];
  if (d == null) {
    out.writeCharCode(rune);
  } else {
    out.write(d);
  }
}

/// True when [rune] is a combining diacritic: a mark (Mn) inside one of the
/// combining-diacritic blocks.
bool _isMark(int rune) {
  var lo = 0;
  var hi = diacriticMarkRanges.length ~/ 2 - 1;
  while (lo <= hi) {
    final mid = (lo + hi) >> 1;
    if (rune < diacriticMarkRanges[2 * mid]) {
      hi = mid - 1;
    } else if (rune > diacriticMarkRanges[2 * mid + 1]) {
      lo = mid + 1;
    } else {
      return true;
    }
  }
  return false;
}

/// Case-folds one code point with the generated lower-case map, then `ß` to
/// `ss`, final sigma to sigma, and the five owner-approved letters.
String _caseFold(int rune) {
  final lower = lowerCaseMap[rune] ?? rune;
  return switch (lower) {
    0xDF => 'ss',
    0x3C2 => 'σ',
    0xF8 => 'o', // ø
    0x111 => 'd', // đ
    0x142 => 'l', // ł
    0xE6 => 'ae', // æ
    0x153 => 'oe', // œ
    _ => String.fromCharCode(lower),
  };
}

/// `norm`: NFKD, remove combining diacritics, case-fold, hyphens, dashes,
/// slashes and underscores to a space, delete apostrophes and other
/// punctuation, collapse spaces, trim.
String norm(String text) {
  final buf = StringBuffer();
  final parts = StringBuffer();
  for (final rune in text.runes) {
    // Apostrophe-like characters are deleted before decomposition, which
    // would turn U+00B4 or U+1FFD into a space plus a mark.
    if (_isDeleted(rune)) continue;
    parts.clear();
    _decompose(rune, parts);
    for (final part in parts.toString().runes) {
      if (_isMark(part)) continue;
      for (final r in _caseFold(part).runes) {
        if (_isSeparator(r)) {
          buf.write(' ');
        } else if (_isDeleted(r)) {
          continue;
        } else if (_isLetterOrDigitOrSpace(r)) {
          buf.writeCharCode(r);
        }
        // Any other punctuation or symbol is deleted.
      }
    }
  }
  return buf
      .toString()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .join(' ');
}

bool _isSeparator(int r) =>
    r == 0x2D || // hyphen-minus
    r == 0x2010 ||
    r == 0x2011 ||
    r == 0x2012 ||
    r == 0x2013 || // en dash
    r == 0x2014 || // em dash
    r == 0x2015 ||
    r == 0x2212 || // minus
    r == 0x2F || // slash
    r == 0x5C || // backslash
    r == 0x2044 || // fraction slash
    r == 0x2215 || // division slash
    r == 0x5F; // underscore

/// Apostrophes and apostrophe-like characters: ASCII apostrophe, left and
/// right single quotation marks, grave accent, acute accent, modifier letter
/// apostrophe (U+02BC), Greek oxia (U+1FFD) and Greek varia (U+1FEF).
bool _isDeleted(int r) =>
    r == 0x27 ||
    r == 0x2018 ||
    r == 0x2019 ||
    r == 0x60 ||
    r == 0xB4 ||
    r == 0x2BC ||
    r == 0x1FFD ||
    r == 0x1FEF;

bool _isLetterOrDigitOrSpace(int r) =>
    (r >= 0x30 && r <= 0x39) ||
    (r >= 0x61 && r <= 0x7A) ||
    r == 0x20 ||
    r == 0x09 ||
    r == 0x0A ||
    (r > 0x7F && !_isPunctuationOrSymbol(r));

// Non-ASCII characters outside the folded Latin set are kept when they are
// letters of other scripts; common non-ASCII punctuation is removed.
bool _isPunctuationOrSymbol(int r) =>
    (r >= 0x2000 && r <= 0x206F) || // general punctuation
    (r >= 0x00A1 && r <= 0x00BF) || // Latin-1 punctuation and symbols
    r == 0xD7 ||
    r == 0xF7 ||
    (r >= 0x20A0 && r <= 0x20CF) || // currency
    (r >= 0x2190 && r <= 0x2BFF); // arrows, maths, shapes

/// `squash`: [norm] with all spaces removed.
String squash(String text) => norm(text).replaceAll(' ', '');

const Set<String> _stopWords = {'the', 'of', 'a', 'and', 'with'};

/// The name tokens of the near-duplicate signature: [norm] split on spaces,
/// the stop words *the of a and with* removed, a trailing *s* removed from
/// words longer than three letters.
Set<String> nameTokens(String name) {
  final out = <String>{};
  for (var word in norm(name).split(' ')) {
    if (word.isEmpty || _stopWords.contains(word)) continue;
    if (word.length > 3 && word.endsWith('s')) {
      word = word.substring(0, word.length - 1);
    }
    out.add(word);
  }
  return out;
}

/// Jaccard similarity of two sets; two empty sets count as 1.
double jaccard<T>(Set<T> a, Set<T> b) {
  if (a.isEmpty && b.isEmpty) return 1;
  final inter = a.where(b.contains).length;
  final union = a.length + b.length - inter;
  return inter / union;
}

/// Levenshtein distance of [a] and [b], or [limit] + 1 as soon as the distance
/// is known to exceed [limit].
int boundedLevenshtein(String a, String b, int limit) {
  if ((a.length - b.length).abs() > limit) return limit + 1;
  if (a == b) return 0;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    var rowMin = cur[0];
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var v = prev[j - 1] + cost;
      if (prev[j] + 1 < v) v = prev[j] + 1;
      if (cur[j - 1] + 1 < v) v = cur[j - 1] + 1;
      cur[j] = v;
      if (v < rowMin) rowMin = v;
    }
    if (rowMin > limit) return limit + 1;
    prev = cur;
  }
  return prev[b.length];
}
