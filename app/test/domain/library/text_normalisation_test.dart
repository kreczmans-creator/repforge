import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/name_rules.dart';
import 'package:repforge/domain/library/text_normalisation.dart';
import 'package:repforge/domain/library/text_normalisation_table.g.dart';

import 'support/catalogue_fixtures.dart';

/// Name normalisation: Unicode NFKD by a generated table, combining marks
/// removed, case folded (owner decision 2026-11-06). Display names are never
/// changed; these tests cover the comparison key only.
void main() {
  group('the generated NFKD table', () {
    test('records its Unicode version and exact size', () {
      expect(nfkdUnicodeVersion, '15.1.0');
      expect(nfkdEntryCount, 5857);
      expect(nfkdDecomposition.length, nfkdEntryCount);
      expect(diacriticMarkRanges.length.isEven, isTrue);
      expect(diacriticMarkRanges.length ~/ 2, 8);
      expect(lowerCaseMap.length, 1432);
    });

    test('mark ranges are sorted, disjoint and start at U+0300', () {
      const r = diacriticMarkRanges;
      expect(r.first, 0x0300);
      for (var i = 0; i < r.length; i += 2) {
        expect(r[i], lessThanOrEqualTo(r[i + 1]));
        if (i > 0) expect(r[i], greaterThan(r[i - 1] + 1));
      }
    });

    test('covers each required block', () {
      bool has(int lo, int hi) =>
          nfkdDecomposition.keys.any((k) => k >= lo && k <= hi);
      expect(has(0x00A0, 0x00BF), isTrue); // Latin-1 punctuation and symbols
      expect(has(0x00C0, 0x00FF), isTrue); // Latin-1 Supplement
      expect(has(0x0100, 0x017F), isTrue); // Latin Extended-A
      expect(has(0x0180, 0x024F), isTrue); // Latin Extended-B
      expect(has(0x1E00, 0x1EFF), isTrue); // Latin Extended Additional
      expect(has(0x0370, 0x03FF), isTrue); // Greek and Coptic
      expect(has(0x1F00, 0x1FFF), isTrue); // Greek Extended
      expect(has(0x2000, 0x200A), isTrue); // compatibility spaces
      expect(has(0xFB00, 0xFB06), isTrue); // Latin ligatures
      expect(has(0xFF01, 0xFF5E), isTrue); // full-width ASCII variants
      expect(has(0xFFE0, 0xFFEE), isTrue); // full-width signs
      expect(has(0x1D400, 0x1D7FF), isTrue); // mathematical alphanumerics
      expect(has(0x2460, 0x24FF), isTrue); // enclosed alphanumerics
    });

    test('spot entries', () {
      expect(nfkdDecomposition[0x00A0], ' ');
      expect(nfkdDecomposition[0x00B2], '2');
      expect(
        nfkdDecomposition[0x00BD],
        '1\u2044'
        '2',
      );
      expect(nfkdDecomposition[0x00C5], 'A\u030A');
      expect(nfkdDecomposition[0x00B5], '\u03BC');
      expect(nfkdDecomposition[0x2000], ' ');
      expect(nfkdDecomposition[0x200A], ' ');
      expect(nfkdDecomposition[0x212B], 'A\u030A');
      expect(nfkdDecomposition[0x2122], 'TM');
      expect(nfkdDecomposition[0xFB03], 'ffi');
      expect(nfkdDecomposition[0xFF21], 'A');
      expect(nfkdDecomposition[0x1D400], 'A');
      expect(nfkdDecomposition[0x1F00], '\u03B1\u0313');
    });

    test('every full-width ASCII variant maps to its ASCII character', () {
      for (var cp = 0xFF01; cp <= 0xFF5E; cp++) {
        expect(
          nfkdDecomposition[cp],
          String.fromCharCode(cp - 0xFF01 + 0x21),
          reason: cp.toRadixString(16),
        );
      }
    });

    test('code points without a decomposition have no entry', () {
      for (final cp in [0xF8, 0xD8, 0x111, 0x142, 0xE6, 0x153, 0x3B1]) {
        expect(nfkdDecomposition.containsKey(cp), isFalse, reason: '$cp');
      }
    });

    test('Hangul syllables are not in the table (algorithmic)', () {
      expect(
        nfkdDecomposition.keys.any((k) => k >= 0xAC00 && k <= 0xD7A3),
        isFalse,
      );
    });
  });

  group('full Unicode NFKD probes', () {
    test('superscripts, symbols, numerals, enclosed and maths letters', () {
      expect(norm('x⁴'), 'x4');
      expect(norm('™'), 'tm');
      expect(norm('Ⅳ'), 'iv');
      expect(norm('①'), '1');
      expect(norm('𝐀'), 'a');
      expect(norm('𝐀𝐁'), 'ab');
      expect(norm('\u212B'), 'a'); // Angstrom sign
      expect(norm('ʰ'), 'h');
      expect(norm('Ⓐ'), 'a');
    });

    test('other spaces act as spaces and do not merge words', () {
      expect(norm('a\u202Fb'), 'a b'); // narrow no-break space
      expect(norm('a\u205Fb'), 'a b'); // medium mathematical space
      expect(norm('a\u3000b'), 'a b'); // ideographic space
      expect(norm('a\u00A0b'), 'a b');
      expect(norm('a\u2000b'), 'a b');
      expect(norm('a\u200Ab'), 'a b');
      expect(squash('a\u202Fb'), 'ab');
    });

    test('full-width signs decompose and follow the punctuation rules', () {
      // U+FFE0 cent, U+FFE1 pound, U+FFE5 yen, U+FFE6 won: currency, deleted.
      expect(norm('a\uFFE0b'), 'ab');
      expect(norm('a\uFFE1b\uFFE5\uFFE6'), 'ab');
      expect(norm('a\uFFE2b'), 'ab'); // full-width not sign
      expect(nfkdDecomposition[0xFFE0], '\u00A2');
      expect(nfkdDecomposition[0xFFE5], '\u00A5');
      for (var cp = 0xFFE0; cp <= 0xFFEE; cp++) {
        if (cp == 0xFFE7) continue; // unassigned
        expect(nfkdDecomposition.containsKey(cp), isTrue, reason: '$cp');
      }
    });

    test('Hangul syllables decompose algorithmically', () {
      // U+D55C = jamo U+1112 U+1161 U+11AB; U+AC00 = U+1100 U+1161 (no tail).
      expect(norm('\uD55C'), '\u1112\u1161\u11AB');
      expect(norm('\uAC00'), '\u1100\u1161');
      expect(norm('\uD7A3'), '\u1112\u1175\u11C2');
      expect(norm('\uD55C'), norm('\u1112\u1161\u11AB'));
      expect(norm('\uD55C'), isNot(norm('\uAC00')));
    });

    test('combining diacritics outside U+0300 to U+036F are removed', () {
      expect(norm('v\u20D7'), 'v'); // combining right arrow above
      expect(norm('a\u1DC0b'), 'ab'); // combining dotted grave accent
      expect(norm('e\u0301\u20D7'), 'e');
      expect(norm('a\u1AB0b'), 'ab'); // extended block
      expect(norm('a\uFE20b'), 'ab'); // half marks
      expect(norm('a\u0345b'), 'ab'); // Greek ypogegrammeni
    });

    test('marks of other scripts are kept and do not merge words', () {
      // Devanagari virama (Mn): a conjunct differs from the plain letters.
      expect(norm('\u0915\u094D\u0924'), '\u0915\u094D\u0924');
      expect(norm('\u0915\u094D\u0924'), isNot(norm('\u0915\u0924')));
      // Thai sara i (Mn) is kept.
      expect(norm('\u0E01\u0E34'), '\u0E01\u0E34');
      expect(norm('\u0E01\u0E34'), isNot(norm('\u0E01')));
      // Hebrew shin dot and sin dot (Mn) keep two letters apart.
      expect(norm('\u05E9\u05C1'), isNot(norm('\u05E9\u05C2')));
      expect(norm('\u05E9\u05C1'), isNot(norm('\u05E9')));
      // Arabic fatha (Mn): vocalised and bare words differ.
      expect(
        norm('\u0641\u064E\u062A\u062D'),
        isNot(norm('\u0641\u062A\u062D')),
      );
    });

    test('case folding uses the generated map for every cased code point', () {
      expect(lowerCaseMap[0x41], 0x61);
      expect(lowerCaseMap[0x3A3], 0x3C3);
      for (final e in lowerCaseMap.entries) {
        final upper = String.fromCharCode(e.key);
        final lower = String.fromCharCode(e.value);
        expect(
          norm(upper),
          norm(lower),
          reason: 'U+${e.key.toRadixString(16)}',
        );
      }
      // Titlecase digraphs and Georgian capitals fold too.
      expect(norm('ǅ'), norm('ǆ'));
      expect(norm('\u1C90'), norm('\u10D0')); // Georgian Mtavruli A
      expect(norm('\u13A0'), norm('\uAB70')); // Cherokee A
    });

    test('fraction and division slashes are separators', () {
      expect(norm('½ squat'), '1 2 squat');
      expect(norm('1/2 squat'), '1 2 squat');
      expect(norm('½ squat'), norm('1/2 squat'));
      expect(
        norm(
          '1\u2044'
          '2 squat',
        ),
        norm('1/2 squat'),
      );
      expect(norm('a\u2215b'), 'a b');
    });

    test('modifier apostrophe and Greek oxia are deleted like apostrophes', () {
      expect(norm('Farmer\u02BCs walk'), norm("Farmer's walk"));
      expect(norm('Farmer\u1FFDs walk'), norm("Farmer's walk"));
      expect(norm('Farmer\u00B4s walk'), 'farmers walk');
      expect(norm('Farmer\uFF07s walk'), 'farmers walk'); // full-width '
    });
  });

  group('Latin', () {
    test('Latin-1 Supplement and Extended-A accents fold to the base', () {
      expect(norm('Café'), 'cafe');
      expect(norm('Crème brûlée'), 'creme brulee');
      expect(norm('Ångström'), 'angstrom');
      expect(norm('Señor ÑANDÚ'), 'senor nandu');
      expect(norm('Łódź'), 'łodz'); // ł has no decomposition
      expect(norm('Žižek Čapek Šuma'), 'zizek capek suma');
    });

    test('precomposed and decomposed forms give one key', () {
      expect(norm('é'), norm('é'));
      expect(norm('Café'), norm('Café'));
      expect(norm('Ångström'), norm('Ångström'));
    });

    test('Latin Extended-B and Additional (Vietnamese, digraphs)', () {
      expect(norm('Ơ'), 'o');
      expect(norm('Việt'), 'viet');
      expect(norm('ạ'), 'a');
      expect(norm('ǆ'), 'dz');
      expect(norm('Ǆ'), 'dz');
      expect(norm('ǅ'), 'dz');
      expect(norm('Ẩ'), 'a');
    });

    test(
      'ø, đ, æ, œ, ł, ħ, ı have no NFKD decomposition and stay distinct',
      () {
        // Documented behaviour: the key keeps these letters, so "Søren" does
        // not equal "Soren". Only ß is folded, to ss, by case folding.
        expect(norm('Søren'), 'søren');
        expect(norm('Søren'), isNot(norm('Soren')));
        expect(norm('Đ'), 'đ');
        expect(norm('Æther'), 'æther');
        expect(norm('Œuvre'), 'œuvre');
        expect(norm('Straße'), 'strasse');
        expect(norm('ẞ'), 'ss');
        expect(norm('ı'), 'ı');
        expect(norm('İ'), 'i'); // I with dot above decomposes to I + U+0307
      },
    );

    test('compatibility ligatures and characters expand', () {
      expect(norm('ﬁnish'), 'finish');
      expect(norm('ﬂy'), 'fly');
      expect(norm('ﬃx'), 'ffix');
      expect(norm('ﬆ'), 'st');
      expect(norm('ĳ'), 'ij');
      expect(norm('m²'), 'm2');
      expect(norm('x y'), 'x y'); // no-break space
      expect(norm('x y'), 'x y'); // thin space
      expect(norm('ﬁnish'), norm('finish'));
    });
  });

  group('Greek', () {
    test('tonos, dialytika and Greek Extended marks are removed', () {
      expect(norm('Άλφα'), 'αλφα');
      expect(norm('ΆΛΦΑ'), 'αλφα');
      expect(norm('ΐ'), 'ι');
      expect(norm('ἀρχή'), 'αρχη');
      expect(norm('ᾳ'), 'α');
      expect(norm('Ὥρα'), 'ωρα');
    });

    test('precomposed and decomposed tonos give one key', () {
      expect(norm('ά'), norm('ά'));
      expect(norm('Άλφα'), norm('Αλφα'));
    });

    test('case and final sigma fold together', () {
      expect(norm('ΣΟΦΟΣ'), norm('σοφος'));
      expect(norm('σοφός'), norm('ΣΟΦΌΣ'));
      expect(norm('ς'), 'σ');
    });

    test('compatibility Greek symbols map to the plain letters', () {
      expect(norm('ϐ'), 'β');
      expect(norm('ϑ'), 'θ');
      expect(norm('µ'), 'μ'); // micro sign to Greek mu
    });
  });

  group('full-width forms', () {
    test('full-width letters and digits equal their ASCII keys', () {
      expect(norm('ＡＢＣ１２３'), 'abc123');
      expect(norm('ＢＥＮＣＨ　ＰＲＥＳＳ'), norm('Bench Press'));
      expect(norm('Ｐｕｓｈ－ｕｐ'), 'push up');
    });

    test('full-width punctuation follows the ASCII rules', () {
      expect(norm('Ｆａｒｍｅｒ＇ｓ'), 'farmers');
      expect(norm('ｕｐ／ｄｏｗｎ'), 'up down');
      expect(norm('Ｄｉｐ！'), 'dip');
    });
  });

  group('existing semantics are kept', () {
    test('punctuation, separators, apostrophes and spaces', () {
      expect(norm('Push-up'), 'push up');
      expect(norm("Farmer's carry"), 'farmers carry');
      expect(norm('Farmer’s carry'), 'farmers carry');
      expect(norm('Farmer´s carry'), 'farmers carry'); // acute is deleted
      expect(norm('Cat–cow / Thread_the_needle'), 'cat cow thread the needle');
      expect(norm('  Wide   grip \t'), 'wide grip');
      expect(norm(''), '');
    });

    test('squash and nameTokens use the same key', () {
      expect(squash('Ｐｕｌｌ－ｕｐ'), 'pullup');
      expect(nameTokens('Café Curls'), {'cafe', 'curl'});
      expect(nameTokens('ＢＥＮＣＨ ｐｒｅｓｓ'), {
        'bench',
        'pres',
      }); // trailing s is dropped
    });

    test('the key is idempotent', () {
      for (final s in ['Άλφα Ｂeta ﬁ ß', 'Søren Café', 'Farmer’s Ｗalk']) {
        expect(norm(norm(s)), norm(s), reason: s);
      }
    });
  });

  group('distinct names stay distinct (no false merges)', () {
    test('different Greek letters', () {
      expect(norm('α'), isNot(norm('β')));
      expect(norm('Άλφα'), isNot(norm('Βήτα')));
      expect(norm('ο'), isNot(norm('ω'))); // omicron against omega
      expect(norm('Ηλιος'), isNot(norm('Ηλιας')));
    });

    test('Greek letters are not merged with look-alike Latin letters', () {
      expect(norm('Αθλητής'), isNot(norm('Athlitis')));
      expect(norm('ο'), isNot(norm('o'))); // Greek omicron against Latin o
      expect(norm('Ηρα'), isNot(norm('Hpa')));
    });

    test('Press against Presse and other near names', () {
      expect(norm('Press'), isNot(norm('Presse')));
      expect(squash('Press'), isNot(squash('Presse')));
      expect(norm('Row'), isNot(norm('Rowe')));
      expect(norm('Curl'), isNot(norm('Curls')));
      expect(norm('Cable crossover'), isNot(norm('Cable cross over x')));
    });

    test('accent-only differences merge, base-letter differences do not', () {
      expect(norm('résumé'), norm('resume'));
      expect(norm('resume'), isNot(norm('resumé s')));
      expect(norm('Søren'), isNot(norm('Soren'))); // ø stays
      expect(norm('Mo'), isNot(norm('Mø')));
      expect(norm('ﬁre'), isNot(norm('ﬂire')));
      expect(norm('ＡＢ'), isNot(norm('ＡＣ')));
      expect(norm('１２'), isNot(norm('１３')));
    });
  });

  group('duplicate detection keys use the normalisation', () {
    List<Finding> names(List<CatalogueExercise> list) => validateNames(list);

    test('IC-501: accented, full-width and ligature names collide', () {
      expect(
        names([
          exercise('lib-a', name: 'Café curl'),
          exercise('lib-b', name: 'Cafe curl'),
        ]).codes,
        contains('IC-501'),
      );
      expect(
        names([
          exercise('lib-a', name: 'Bench press'),
          exercise('lib-b', name: 'ＢＥＮＣＨ ＰＲＥＳＳ'),
        ]).codes,
        contains('IC-501'),
      );
      expect(
        names([
          exercise('lib-a', name: 'Fire walk'),
          exercise('lib-b', name: 'ﬁre walk'),
        ]).codes,
        contains('IC-501'),
      );
      expect(
        names([
          exercise('lib-a', name: 'Άλφα raise'),
          exercise('lib-b', name: 'Αλφα raise'),
        ]).codes,
        contains('IC-501'),
      );
    });

    test('no IC-501 or IC-502 for distinct names', () {
      final f = names([
        exercise('lib-a', name: 'Press'),
        exercise('lib-b', name: 'Presse'),
        exercise('lib-c', name: 'Søren raise'),
        exercise('lib-d', name: 'Soren raise'),
        exercise('lib-e', name: 'Αλφα'),
        exercise('lib-f', name: 'Βητα'),
      ]);
      expect(f.codes, isNot(contains('IC-501')));
      expect(f.codes, isNot(contains('IC-502')));
    });
  });
}
