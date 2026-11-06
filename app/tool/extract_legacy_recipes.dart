// One-off extractor, kept for audit.
//
// Parses the `Recipe(...)` constructor calls in the legacy Kotlin function
// `defaultStarterRecipes()` and writes the seed JSON asset.
//
// Usage: dart run tool/extract_legacy_recipes.dart <kotlin path> <out json>
import 'dart:convert';
import 'dart:io';

const _defaultNote =
    'Estimated values; verify against actual ingredients and brands.';

void main(List<String> args) {
  if (args.length != 2) {
    stderr.writeln(
      'Usage: dart run tool/extract_legacy_recipes.dart <kotlin path> <out json>',
    );
    exit(64);
  }
  final src = File(args[0]).readAsStringSync();
  final sha = _gitShortSha(File(args[0]).parent.path);
  final recipes = parseRecipes(src);
  final out = <String, Object?>{
    'source':
        'legacy/android/app/src/main/java/com/tempest/repforge/MainActivity.kt '
        'defaultStarterRecipes() at $sha',
    'formatVersion': 1,
    'recipes': recipes,
  };
  File(
    args[1],
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(out)}\n');
  stdout.writeln('Wrote ${recipes.length} recipes to ${args[1]}');
}

String _gitShortSha(String dir) {
  final r = Process.runSync('git', [
    'rev-parse',
    '--short',
    'HEAD',
  ], workingDirectory: dir);
  if (r.exitCode != 0) throw StateError('git rev-parse failed: ${r.stderr}');
  return (r.stdout as String).trim();
}

List<Map<String, Object?>> parseRecipes(String src) {
  final start = src.indexOf('defaultStarterRecipes()');
  if (start < 0) throw StateError('defaultStarterRecipes() not found');
  final result = <Map<String, Object?>>[];
  final p = _Cursor(src, start);
  while (true) {
    final i = src.indexOf('Recipe(', p.pos);
    if (i < 0) break;
    // Stop at the end of the listOf( call: next top-level text after the
    // last recipe is "\n)" followed by a blank line; a "Recipe(" found past
    // the function would be a different declaration, so guard on indentation.
    final lineStart = src.lastIndexOf('\n', i) + 1;
    if (src.substring(lineStart, i).trim().isNotEmpty || i - lineStart != 4) {
      break;
    }
    p.pos = i + 'Recipe('.length;
    final fields = <String, Object>{};
    while (true) {
      p.skipSpaceAndCommas();
      if (p.peek() == ')') {
        p.pos++;
        break;
      }
      final key = p.readIdent();
      p
        ..skipSpace()
        ..expect('=')
        ..skipSpace();
      fields[key] = p.readValue();
    }
    result.add(_toJson(fields));
  }
  return result;
}

Map<String, Object?> _toJson(Map<String, Object> f) {
  T need<T>(String k) {
    final v = f[k];
    if (v is! T) throw StateError('Recipe ${f['id']}: bad/missing "$k": $v');
    return v;
  }

  double num_(String k) => need<num>(k).toDouble();

  final ingredients = need<String>('ingredients')
      .split('\n')
      .map((l) => l.trim())
      .where((l) => l.isNotEmpty)
      .toList();
  final steps = _splitSteps(need<String>('method'), need<String>('id'));
  return {
    'id': need<String>('id'),
    'name': need<String>('name'),
    'category': need<String>('category'),
    'description': need<String>('description'),
    'portions': need<num>('servings').toInt(),
    'perPortion': {
      'kcal': num_('caloriesPerServing'),
      'proteinG': num_('proteinPerServing'),
      'carbsG': num_('carbsPerServing'),
      'fatG': num_('fatPerServing'),
    },
    'ingredientLines': ingredients,
    'methodSteps': steps,
    'legacyFreezerFriendly':
        !f.containsKey('freezerFriendly') || need<bool>('freezerFriendly'),
    'nutritionNote': f.containsKey('nutritionNote')
        ? need<String>('nutritionNote')
        : _defaultNote,
  };
}

/// Splits a numbered method block ("1. ...\n2. ...") into step texts.
/// Continuation lines (not starting with "N. ") are appended to the previous
/// step; an unnumbered block yields one step per non-empty line (and warns).
List<String> _splitSteps(String method, String id) {
  final numbered = RegExp(r'^\d+\.\s+');
  final steps = <String>[];
  var expected = 1;
  for (final raw in method.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty) continue;
    final m = numbered.firstMatch(line);
    if (m != null) {
      final n = int.parse(line.substring(0, line.indexOf('.')));
      if (n != expected) {
        stderr.writeln('WARN $id: step numbering $n, expected $expected');
      }
      expected = n + 1;
      steps.add(line.substring(m.end).trim());
    } else if (steps.isNotEmpty) {
      stderr.writeln('WARN $id: unnumbered continuation line joined: $line');
      steps[steps.length - 1] = '${steps.last} $line';
    } else {
      stderr.writeln('WARN $id: unnumbered method line: $line');
      steps.add(line);
    }
  }
  return steps;
}

class _Cursor {
  _Cursor(this.s, this.pos);
  final String s;
  int pos;

  String peek() => pos < s.length ? s[pos] : '';

  void skipSpace() {
    while (pos < s.length && ' \t\r\n'.contains(s[pos])) {
      pos++;
    }
  }

  void skipSpaceAndCommas() {
    while (pos < s.length && ' \t\r\n,'.contains(s[pos])) {
      pos++;
    }
  }

  void expect(String c) {
    if (peek() != c) {
      throw StateError('Expected "$c" at offset $pos, got "${peek()}"');
    }
    pos++;
  }

  String readIdent() {
    final m = RegExp('[A-Za-z_][A-Za-z0-9_]*').matchAsPrefix(s, pos);
    if (m == null) throw StateError('Expected identifier at offset $pos');
    pos = m.end;
    return m.group(0)!;
  }

  Object readValue() {
    if (s.startsWith('"""', pos)) {
      final end = s.indexOf('"""', pos + 3);
      if (end < 0) throw StateError('Unterminated """ at $pos');
      var close = end;
      // Kotlin allows extra quotes at the end of a raw string ("""a"""").
      while (close + 3 < s.length && s[close + 3] == '"') {
        close++;
      }
      final v = s.substring(pos + 3, close);
      pos = close + 3;
      return v;
    }
    if (peek() == '"') return _readQuoted();
    if (s.startsWith('true', pos)) {
      pos += 4;
      return true;
    }
    if (s.startsWith('false', pos)) {
      pos += 5;
      return false;
    }
    final m = RegExp(r'-?\d+(\.\d+)?[fFL]?').matchAsPrefix(s, pos);
    if (m == null) throw StateError('Unparseable value at offset $pos');
    pos = m.end;
    final txt = m.group(0)!.replaceAll(RegExp(r'[fFL]$'), '');
    return txt.contains('.') ? double.parse(txt) : int.parse(txt);
  }

  String _readQuoted() {
    pos++; // opening quote
    final b = StringBuffer();
    while (true) {
      if (pos >= s.length) throw StateError('Unterminated string');
      final c = s[pos++];
      if (c == '"') break;
      if (c != r'\') {
        b.write(c);
        continue;
      }
      final e = s[pos++];
      switch (e) {
        case 'n':
          b.write('\n');
        case 't':
          b.write('\t');
        case 'r':
          b.write('\r');
        case 'b':
          b.write('\b');
        case '"' || "'" || r'\' || r'$':
          b.write(e);
        case 'u':
          b.writeCharCode(int.parse(s.substring(pos, pos + 4), radix: 16));
          pos += 4;
        default:
          throw StateError('Unknown escape \\$e at offset $pos');
      }
    }
    return b.toString();
  }
}
