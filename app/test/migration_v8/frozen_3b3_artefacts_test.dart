import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'harness_v7_db.dart';
import 'migration_digest.dart';

/// SHA-256 of `fixtures/MANIFEST_3b3.sha256` (it cannot list itself).
/// Recorded in `docs/delivery-record/WP8.md` and `fixtures/README_3b3.md`.
const manifest3b3Sha256 =
    '61ab326cdcbb782ae2e5ffc85ed66bdc962f1e21264482f6bca16864a58e5e9d';

/// Guards the frozen 3b-3 evidence (review M1): the strict v7 schema of
/// production, the generated step shapes and the frozen v6 data logic. The
/// 3b-1 manifest and its test stay unchanged.
void main() {
  Map<String, String> manifest() => {
    for (final line in File(manifest3b3Path).readAsLinesSync())
      if (line.trim().isNotEmpty)
        line.substring(line.indexOf('  ') + 2): line.substring(
          0,
          line.indexOf('  '),
        ),
  };

  test('MANIFEST_3b3.sha256 itself is pinned', () {
    expect(sha256OfFile(manifest3b3Path), manifest3b3Sha256);
  });

  test('it lists exactly the 3b-3 frozen files', () {
    expect(manifest().keys.toList(), pinned3b3Files);
  });

  test('every 3b-3 frozen file has the recorded SHA-256', () {
    final changed = [
      for (final MapEntry(key: path, value: hash) in manifest().entries)
        if (!File(path).existsSync() || sha256OfFile(path) != hash) path,
    ];
    expect(changed, isEmpty, reason: 'frozen file(s) changed or missing');
  });

  test('the strict schema file covers a fresh database and every '
      'fixture', () {
    final json = jsonDecode(
      File(strictSchemaPath).readAsStringSync(),
    ) as Map<String, Object?>;
    expect(json['fresh'], isA<List<Object?>>());
    expect((json['fixtures']! as Map<String, Object?>).keys.toList(), [
      for (final (key, _) in allFixtures()) key,
    ]);
  });

  test('the erratum note exists next to the frozen files', () {
    expect(File('$fixturesDir/README_3b3.md').existsSync(), isTrue);
  });
}
