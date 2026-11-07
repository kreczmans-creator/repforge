import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/release/release_hash.dart';
import 'package:repforge/domain/library/release/release_parser.dart';
import 'package:repforge/domain/library/sha256_hex.dart';

import 'support/release_support.dart';

void main() {
  test('the algorithm and encoding names are the R-10 words', () {
    expect(releaseHashAlgorithm, 'sha256');
    expect(releaseHashEncoding, 'hex-lower');
  });

  test('known SHA-256 vectors, lowercase hex', () {
    expect(
      releaseContentHash(const []),
      'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
    );
    expect(
      releaseContentHash(utf8.encode('abc')),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
    expect(
      releaseContentHash(utf8.encode('abc')),
      sha256Hex(utf8.encode('abc')),
    );
  });

  test('the approved reference files hash to their documented values', () {
    final bytes = approvedReferenceBytes();
    expect(
      {for (final e in bytes.entries) e.key.wire: releaseContentHash(e.value)},
      {
        'anatomy':
            '207b151fd9d5be164494a4e852ffe52781d1e9b3ea8c29c8277a160330e334d6',
        'movementPatterns':
            '1a2c28239fb8ee9c3f288d83a90309a4a8cfa2cb3bf44ea0cfba07523df67655',
        'equipment':
            '7595bab7c19bdad044b60257959eae7c6adc3dd630b4ab7714d88bfb9c7058bf',
        'ledger':
            'f1b3aae2cd298916657bbe548dedaf71e8de62140c925968f1bfa98b019bef4e',
        'coverage':
            '06f9d72aecc32a16d69fb94a374340b68fbeb68d9fd4e5749e3f9fd2734494c4',
      },
    );
  });

  test('format check accepts 64 lowercase hex only', () {
    expect(isReleaseContentHash(releaseContentHash(const [1])), isTrue);
    expect(isReleaseContentHash('ABC'), isFalse);
    expect(isReleaseContentHash('${'a' * 63}G'), isFalse);
    expect(isReleaseContentHash('${'A' * 64}'), isFalse);
    expect(isReleaseContentHash('sha256:${'a' * 64}'), isFalse);
  });

  test('the parser reports the hash of the exact bytes', () {
    final bytes = release2Bytes();
    final parsed = parseReleaseBytes(bytes);
    expect(parsed.contentHash, releaseContentHash(bytes));
    expect(parsed.contentHash, hasLength(64));
  });

  test('a re-serialised or reordered file is a different file (R-10)', () {
    final bytes = release2Bytes();
    final map = release2Map();
    // Same data, compact encoding.
    final compact = utf8.encode(jsonEncode(map));
    // Same data, top-level keys reversed.
    final reversed = utf8.encode(
      const JsonEncoder.withIndent('  ')
          .convert({for (final k in map.keys.toList().reversed) k: map[k]}),
    );
    final hashes = {
      releaseContentHash(bytes),
      releaseContentHash(compact),
      releaseContentHash(reversed),
    };
    expect(hashes, hasLength(3));
    // All three describe the same release.
    final docs = [
      bytes,
      compact,
      reversed,
    ].map((b) => parseReleaseBytes(b).document!).toList();
    expect(docs[1], docs[0]);
    expect(docs[2], docs[0]);
  });

  test('a single changed byte changes the hash', () {
    final bytes = release2Bytes();
    final changed = [...bytes];
    changed[changed.length ~/ 2] ^= 1;
    expect(releaseContentHash(changed), isNot(releaseContentHash(bytes)));
  });
}
