// Generator for the frozen 3b-3 evidence (WP 8 stage 3b-3, review M1).
//
// Run once, from `app/`, while production is at schema v7:
//
//   flutter test --concurrency=1 test/migration_v8/fixtures/build_3b3_evidence.dart
//
// (Not a `_test.dart` file, so a plain `flutter test` never runs it.) It
// writes, next to itself:
//   v7_strict_schema_3b3.json  today's production v7 schema with raw and
//                              strict SQL: a fresh database and every
//                              fixture migrated by production
//   MANIFEST_3b3.sha256        SHA-256 of the 3b-3 frozen files
//
// Each step REFUSES to overwrite an existing file. The 3b-1 files and their
// generator (`build_fixtures.dart`) are not touched. See README_3b3.md.
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';

import '../harness_v7_db.dart';
import '../migration_digest.dart';

void _refuseOverwrite(String path) {
  if (File(path).existsSync()) {
    fail('$path exists. Frozen evidence is never regenerated (README_3b3.md).');
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('write v7_strict_schema_3b3.json from production v7', () async {
    expect(Directory('lib').existsSync(), isTrue, reason: 'run from app/');
    _refuseOverwrite(strictSchemaPath);
    final probe = AppDatabase(NativeDatabase.memory());
    final version = probe.schemaVersion;
    await probe.close();
    expect(version, 7, reason: 'production must still be at schema v7');
    final out = <String, Object?>{
      'description':
          'Schema of the production AppDatabase at schema v7: a fresh '
          'database (createAll) and every frozen fixture migrated by it, as '
          'of WP 8 stage 3b-3. It refines expected_v7_digests.json, whose '
          'normaliseSql loses every operator and bracket. Frozen evidence: '
          'never regenerate.',
      'normalisation':
          'Entities from sqlite_master (not sqlite_sequence) sorted by type '
          'and name. "sql" is the stored text; "strict" removes double '
          'quotes, collapses whitespace and removes whitespace around ( ) , '
          '= < > ! while keeping those characters; "checks" are the CHECK '
          'clauses of a table in the same form.',
      'fresh': await productionFreshStrictRecord(),
      'fixtures': {
        for (final (key, path) in allFixtures())
          key: await productionStrictRecord(path),
      },
    };
    File(strictSchemaPath).writeAsStringSync(encodeJson(out));
  });

  test('write MANIFEST_3b3.sha256', () {
    expect(Directory('lib').existsSync(), isTrue, reason: 'run from app/');
    _refuseOverwrite(manifest3b3Path);
    final lines = [
      for (final path in pinned3b3Files) '${sha256OfFile(path)}  $path',
    ];
    File(manifest3b3Path).writeAsStringSync('${lines.join('\n')}\n');
  });
}
