/// Name normalisation of the integrity checks (`quality-and-duplicates.md`
/// IC-500): `norm` and `squash`, the name tokens of the near-duplicate
/// signature, and edit distance.
///
/// The specification says Unicode NFKD, then remove combining marks. Dart's
/// core library has no NFKD, and no package is added for it (engineering
/// standards section 4), so [norm] folds the Latin letters with diacritics
/// (Latin-1 Supplement and Latin Extended-A) through a table and removes any
/// remaining combining mark (U+0300 to U+036F). For the characters that occur
/// in exercise names the result equals NFKD followed by mark removal.
library;

const Map<String, String> _fold = {
  'àáâãäåāăą': 'a',
  'çćĉċč': 'c',
  'ďđ': 'd',
  'èéêëēĕėęě': 'e',
  'ĝğġģ': 'g',
  'ĥħ': 'h',
  'ìíîïĩīĭįı': 'i',
  'ĵ': 'j',
  'ķ': 'k',
  'ĺļľŀł': 'l',
  'ñńņňŉ': 'n',
  'òóôõöøōŏő': 'o',
  'ŕŗř': 'r',
  'śŝşš': 's',
  'ţťŧ': 't',
  'ùúûüũūŭůűų': 'u',
  'ŵ': 'w',
  'ýÿŷ': 'y',
  'źżž': 'z',
};

final Map<int, String> _foldByCodeUnit = {
  for (final e in _fold.entries)
    for (final r in e.key.runes) r: e.value,
};

const Map<String, String> _compat = {
  'ß': 'ss',
  'æ': 'ae',
  'œ': 'oe',
  'ﬁ': 'fi',
  'ﬂ': 'fl',
  ' ': ' ',
};

/// `norm`: fold diacritics, lower-case, hyphens, dashes, slashes and
/// underscores to a space, delete apostrophes and other punctuation, collapse
/// spaces, trim.
String norm(String text) {
  final buf = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    if (rune >= 0x0300 && rune <= 0x036F) continue; // combining mark
    final ch = String.fromCharCode(rune);
    final compat = _compat[ch];
    if (compat != null) {
      buf.write(compat);
      continue;
    }
    final folded = _foldByCodeUnit[rune];
    if (folded != null) {
      buf.write(folded);
      continue;
    }
    if (_isSeparator(rune)) {
      buf.write(' ');
    } else if (_isDeleted(rune)) {
      continue;
    } else if (_isLetterOrDigitOrSpace(rune)) {
      buf.write(ch);
    }
    // Any other punctuation or symbol is deleted.
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
    r == 0x5F; // underscore

bool _isDeleted(int r) =>
    r == 0x27 || r == 0x2018 || r == 0x2019 || r == 0x60 || r == 0xB4;

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
