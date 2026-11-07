import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/sha256_hex.dart';

/// WP 8 3b-10, Review C M-1: the incremental SHA-256 and the sliced UTF-8
/// hash give exactly the one-shot digest.
void main() {
  test('FIPS 180-4 examples, one shot and in parts', () {
    const abc =
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad';
    expect(sha256Hex(utf8.encode('abc')), abc);
    expect(
      (Sha256()
            ..add([0x61])
            ..add(const [])
            ..add([0x62, 0x63]))
          .closeHex(),
      abc,
    );
    expect(
      sha256Hex(
        utf8.encode('abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq'),
      ),
      '248d6a61d20638b8e5c026930c3e6039a33ce45964ff2167f6ecedd419db06c1',
    );
  });

  test('every length around the block and padding boundaries, split at '
      'every point', () {
    for (var n = 0; n <= 130; n++) {
      final data = [for (var i = 0; i < n; i++) (i * 37 + 11) & 0xff];
      final whole = sha256Hex(data);
      for (final split in {0, n ~/ 3, n ~/ 2, n}) {
        final parts =
            (Sha256()
                  ..add(data.sublist(0, split))
                  ..add(data.sublist(split)))
                .closeHex();
        expect(parts, whole, reason: 'n=$n split=$split');
      }
    }
  });

  test('sha256HexOfUtf8 equals the hash of utf8.encode, with surrogate '
      'pairs and lone surrogates on the slice boundary', () {
    const slice = 1 << 16;
    final cases = <String>[
      '',
      'a',
      'é€\u{1F600}',
      '${'x' * (slice - 1)}\u{1F600}tail',
      '${'x' * (slice - 1)}\ud83d',
      '${'x' * slice}\ude00${'y' * slice}',
      '${'ü' * (3 * slice + 5)}\u{10FFFF}',
    ];
    for (final s in cases) {
      expect(
        sha256HexOfUtf8(s),
        sha256Hex(utf8.encode(s)),
        reason: s.length.toString(),
      );
    }
  });

  test('a value that is not a byte is refused; a closed hash is final', () {
    expect(() => sha256Hex([256]), throwsArgumentError);
    expect(() => sha256Hex([-1]), throwsArgumentError);
    final h = Sha256()
      ..add([1])
      ..closeHex();
    expect(h.closeHex, throwsStateError);
    expect(() => h.add([1]), throwsStateError);
  });
}
