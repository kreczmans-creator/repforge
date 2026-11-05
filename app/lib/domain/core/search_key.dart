const _diacritics = {
  'àáâäãå': 'a',
  'èéêë': 'e',
  'ìíîï': 'i',
  'òóôöõ': 'o',
  'ùúûü': 'u',
  'ç': 'c',
  'ñ': 'n',
};

final Map<String, String> _foldMap = {
  for (final e in _diacritics.entries)
    for (final ch in e.key.split('')) ch: e.value,
};

/// Lower-cases [input] and strips common Latin diacritics. Shared by food
/// search (NUT-004) and exercise search (TRN-008(3)).
String normaliseSearchKey(String input) {
  final buf = StringBuffer();
  for (final ch in input.toLowerCase().split('')) {
    buf.write(_foldMap[ch] ?? ch);
  }
  return buf.toString();
}
