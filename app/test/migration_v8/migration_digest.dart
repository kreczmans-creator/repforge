import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_backup_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:sqlite3/sqlite3.dart';

import '../data/generated_migrations/schema.dart';

/// Shared helpers for the frozen v8 migration evidence (WP 8 stage 3b-1):
/// SHA-256, schema description, row digests, the format 1 era exporter and
/// the production-migration runner. Used by the generator
/// (`fixtures/build_fixtures.dart`) and by `frozen_artefacts_test.dart`.
/// Changing how a digest is computed invalidates the frozen expectation
/// files, so this file is part of the evidence contract: add a new function
/// instead of changing an existing one.

/// Directory of the frozen artefacts, relative to `app/`.
const fixturesDir = 'test/migration_v8/fixtures';

/// Prefix of every temporary directory made by these helpers (unique to this
/// evidence, so the "no temp files left" check cannot see other tests).
const tempPrefix = 'repforge_v8_frozen_7c1e_';

/// Schema versions that have a clean fixture.
const fixtureVersions = [1, 2, 3, 4, 5, 6, 7];

/// Versions that also have an `_orphans` fixture (v1 has no foreign keys).
const orphanFixtureVersions = [2, 3, 4, 5, 6, 7];

String fixturePath(int v, {bool orphans = false}) =>
    '$fixturesDir/fixture_v$v${orphans ? '_orphans' : ''}.sqlite';

/// Every fixture as `(key, path)`; the key names it in the expectation file.
List<(String, String)> allFixtures() => [
  for (final v in fixtureVersions) ('v$v', fixturePath(v)),
  for (final v in orphanFixtureVersions)
    ('v${v}_orphans', fixturePath(v, orphans: true)),
];

/// Format 1 golden backups exist for these fixture versions. 2, 4, 5, 6 are
/// the eras of the original request; 3 and 7 are the v3 era and the ebff8d0
/// era (format 1 written with schemaVersion 7, before format 2 existed).
const goldenFormat1Versions = [2, 3, 4, 5, 6, 7];

String goldenFormat1Path(int v, {bool orphans = false}) =>
    '$fixturesDir/golden_format1_v$v${orphans ? '_orphans' : ''}.json';
String goldenFormat2Path({bool orphans = false}) =>
    '$fixturesDir/golden_format2_v7${orphans ? '_orphans' : ''}.json';
const goldenFormat1SettingsOnlyPath =
    '$fixturesDir/golden_format1_settings_only.json';
const goldenFormat2SettingsOnlyPath =
    '$fixturesDir/golden_format2_settings_only.json';

/// Every golden backup as `(key, path)`.
List<(String, String)> allGoldens() => [
  for (final o in [false, true])
    for (final v in goldenFormat1Versions)
      ('format1_v$v${o ? '_orphans' : ''}', goldenFormat1Path(v, orphans: o)),
  for (final o in [false, true])
    ('format2_v7${o ? '_orphans' : ''}', goldenFormat2Path(orphans: o)),
  ('format1_settings_only', goldenFormat1SettingsOnlyPath),
  ('format2_settings_only', goldenFormat2SettingsOnlyPath),
];

const expectedDigestsPath = '$fixturesDir/expected_v7_digests.json';
const manifestPath = '$fixturesDir/MANIFEST.sha256';

/// `exportedAt` written into every golden backup. The original exporter used
/// the wall clock; a fixed value keeps the goldens deterministic.
const goldenExportedAt = '2026-11-06T12:00:00.000Z';

/// Quarantine timestamps carried by the fixtures themselves start with this
/// prefix and are compared as they are; see [tableDigests].
const fixtureQuarantineStampPrefix = '2026-02-01T10:';
const migrationTimePlaceholder = '<migration-time>';

final _isoUtc = RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z$');

/// Compares two SQL fragments (CREATE text, CHECK clauses, index SQL) while
/// ignoring what differs only by who wrote it: double quotes around
/// identifiers, and whitespace around punctuation and operators. The drift
/// snapshot classes (`generated_migrations/schema_vN.dart`) reformat DDL
/// (unquoted column names in CHECKs, `a)=(b` without spaces); apps of the
/// era wrote the quoted, spaced form that production `createAll` writes.
String normaliseSql(String sql) {
  final t = sql.replaceAll('"', '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.replaceAll(RegExp(r'\s*([(),=<>!])\s*'), r'$1');
}

// ---- SHA-256 (no dependency: `crypto` is only transitive) -----------------

const _k = <int>[
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, //
  0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
  0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
  0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
  0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
  0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

/// Hex SHA-256 of [data].
String sha256Hex(List<int> data) {
  const mask = 0xffffffff;
  int rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & mask;
  final h = <int>[
    0x6a09e667,
    0xbb67ae85,
    0x3c6ef372,
    0xa54ff53a,
    0x510e527f,
    0x9b05688c,
    0x1f83d9ab,
    0x5be0cd19,
  ];
  final bitLength = data.length * 8;
  final padded = <int>[...data, 0x80];
  while (padded.length % 64 != 56) {
    padded.add(0);
  }
  for (var i = 7; i >= 0; i--) {
    padded.add((bitLength >> (i * 8)) & 0xff);
  }
  final w = List<int>.filled(64, 0);
  for (var chunk = 0; chunk < padded.length; chunk += 64) {
    for (var i = 0; i < 16; i++) {
      final j = chunk + i * 4;
      w[i] =
          (padded[j] << 24) |
          (padded[j + 1] << 16) |
          (padded[j + 2] << 8) |
          padded[j + 3];
    }
    for (var i = 16; i < 64; i++) {
      final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >> 3);
      final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >> 10);
      w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & mask;
    }
    var a = h[0];
    var b = h[1];
    var c = h[2];
    var d = h[3];
    var e = h[4];
    var f = h[5];
    var g = h[6];
    var hh = h[7];
    for (var i = 0; i < 64; i++) {
      final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
      final ch = (e & f) ^ ((~e & mask) & g);
      final t1 = (hh + s1 + ch + _k[i] + w[i]) & mask;
      final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & mask;
      hh = g;
      g = f;
      f = e;
      e = (d + t1) & mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & mask;
    }
    h[0] = (h[0] + a) & mask;
    h[1] = (h[1] + b) & mask;
    h[2] = (h[2] + c) & mask;
    h[3] = (h[3] + d) & mask;
    h[4] = (h[4] + e) & mask;
    h[5] = (h[5] + f) & mask;
    h[6] = (h[6] + g) & mask;
    h[7] = (h[7] + hh) & mask;
  }
  return h.map((x) => x.toRadixString(16).padLeft(8, '0')).join();
}

String sha256OfFile(String path) => sha256Hex(File(path).readAsBytesSync());

String sha256OfString(String s) => sha256Hex(utf8.encode(s));

// ---- Schema description ---------------------------------------------------

int userVersion(Database db) =>
    db.select('PRAGMA user_version').first.values.first! as int;

List<String> _checkClauses(String sql) {
  final out = <String>[];
  final upper = sql.toUpperCase();
  var from = 0;
  while (true) {
    final at = upper.indexOf('CHECK', from);
    if (at < 0) break;
    var i = at + 5;
    while (i < sql.length && sql[i] == ' ') {
      i++;
    }
    if (i >= sql.length || sql[i] != '(') {
      from = at + 5;
      continue;
    }
    var depth = 0;
    var j = i;
    for (; j < sql.length; j++) {
      if (sql[j] == '(') depth++;
      if (sql[j] == ')') {
        depth--;
        if (depth == 0) break;
      }
    }
    out.add(normaliseSql(sql.substring(i + 1, j)));
    from = j;
  }
  return out;
}

List<Map<String, Object?>> _rows(ResultSet rs) => [
  for (final r in rs) Map<String, Object?>.of(r),
];

/// A normalised, deterministic description of the schema: for every table
/// the `table_info`, `index_list` (with the columns of each index), the
/// `foreign_key_list` and the CHECK clauses taken from the stored `CREATE
/// TABLE` text (whitespace collapsed); plus every index's stored SQL.
/// Entities are sorted by name.
Map<String, Object?> describeSchema(Database db) {
  final tables = db.select(
    "SELECT name, sql FROM sqlite_master WHERE type = 'table' "
    "AND name NOT LIKE 'sqlite_%' ORDER BY name",
  );
  final out = <String, Object?>{};
  for (final t in tables) {
    final name = t['name']! as String;
    final indexes = <Map<String, Object?>>[];
    for (final ix in db.select('PRAGMA index_list("$name")')) {
      final ixName = ix['name']! as String;
      indexes.add({
        'name': ixName,
        'unique': ix['unique'],
        'origin': ix['origin'],
        'partial': ix['partial'],
        'columns': [
          for (final c in db.select('PRAGMA index_info("$ixName")')) c['name'],
        ],
      });
    }
    indexes.sort(
      (a, b) => (a['name']! as String).compareTo(b['name']! as String),
    );
    out[name] = {
      'table_info': _rows(db.select('PRAGMA table_info("$name")')),
      'index_list': indexes,
      'foreign_key_list': _rows(db.select('PRAGMA foreign_key_list("$name")')),
      'checks': _checkClauses(t['sql']! as String),
      'create_sql': normaliseSql(t['sql']! as String),
      // legacy_quarantine is AUTOINCREMENT: its counter lives in
      // sqlite_sequence, which tableDigests records.
    };
  }
  final indexSql = <String, String>{};
  for (final i in db.select(
    "SELECT name, sql FROM sqlite_master WHERE type = 'index' "
    'AND sql IS NOT NULL ORDER BY name',
  )) {
    indexSql[i['name']! as String] = normaliseSql(i['sql']! as String);
  }
  final other = <String, String>{};
  for (final o in db.select(
    "SELECT type, name, sql FROM sqlite_master WHERE type IN ('trigger', "
    "'view') ORDER BY type, name",
  )) {
    other['${o['type']}:${o['name']}'] = normaliseSql(o['sql']! as String);
  }
  return {'tables': out, 'index_sql': indexSql, 'triggers_and_views': other};
}

// ---- Row digests ----------------------------------------------------------

String _typeName(Object? v) => switch (v) {
  null => 'null',
  int() => 'int',
  double() => 'real',
  String() => 'text',
  _ => 'blob',
};

/// Per-table digests over all columns. A row is serialised as a JSON list of
/// `[column, storage type, value]`; the serialised rows are sorted as text
/// and hashed, so the digest does not depend on rowid or physical order.
/// `rowHashes` holds the first 16 hex digits of each row's SHA-256, sorted,
/// so a failing comparison shows which rows differ.
///
/// `sqlite_sequence` (the AUTOINCREMENT counter of `legacy_quarantine`) is
/// included. Only one value is normalised: `legacy_quarantine.quarantined_at`
/// when it is an ISO-8601 UTC text (regex `^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z\$`) that does not start with
/// [fixtureQuarantineStampPrefix], because the migration writes it from the
/// wall clock. Everything else, ids included, is compared as it is.
Map<String, Object?> tableDigests(Database db) {
  final tables = db.select(
    "SELECT name FROM sqlite_master WHERE type = 'table' "
    "AND (name NOT LIKE 'sqlite_%' OR name = 'sqlite_sequence') ORDER BY name",
  );
  final out = <String, Object?>{};
  for (final t in tables) {
    final name = t['name']! as String;
    final serialised = <String>[];
    for (final r in db.select('SELECT * FROM "$name"')) {
      final cells = <Object?>[];
      for (final c in r.keys) {
        var v = r[c];
        // Only an ISO-8601 UTC text that is not one of the fixtures' own
        // stamps is a wall-clock value written by the migration. Anything
        // else (an integer epoch, another text form) is kept and so detected.
        if (name == 'legacy_quarantine' &&
            c == 'quarantined_at' &&
            v is String &&
            _isoUtc.hasMatch(v) &&
            !v.startsWith(fixtureQuarantineStampPrefix)) {
          v = migrationTimePlaceholder;
        }
        cells.add([c, _typeName(v), v]);
      }
      serialised.add(jsonEncode(cells));
    }
    serialised.sort();
    final hashes = [
      for (final s in serialised) sha256OfString(s).substring(0, 16),
    ];
    out[name] = {
      'rows': serialised.length,
      'sha256': sha256OfString(serialised.join('\n')),
      'rowHashes': hashes,
    };
  }
  return out;
}

/// Foreign-key violations as `table|rowid|parent|fkid` strings, sorted.
List<String> foreignKeyViolations(Database db) => [
  for (final r in db.select('PRAGMA foreign_key_check'))
    '${r['table']}|${r['rowid']}|${r['parent']}|${r['fkid']}',
]..sort();

String integrityCheck(Database db) =>
    db.select('PRAGMA integrity_check').first.values.first! as String;

// ---- Format 1 era exporter ------------------------------------------------

/// The `@DriftDatabase(tables: [...])` list of each schema era, in the order
/// the era's `allTables` (and so its export) used. Taken from
/// `app/lib/data/db/app_database.dart` at commits eeab56e (v2), 9ed0e7d (v3),
/// 864065f (v4), 77540ae (v5), b1ab45a (v6) and ebff8d0 (v7: format 1 written
/// with schemaVersion 7, before 66a2a00 introduced format 2) and snake_cased.
const eraTableOrder = <int, List<String>>{
  2: [
    'measurements',
    'foods',
    'food_servings',
    'food_log_entries',
    'recipes',
    'recipe_ingredients',
    'exercises',
    'workout_plans',
    'plan_exercises',
    'workout_sessions',
    'session_sets',
    'goals',
    'settings',
  ],
  3: [
    'measurements',
    'foods',
    'food_servings',
    'food_log_entries',
    'saved_meals',
    'saved_meal_items',
    'recipes',
    'recipe_ingredients',
    'exercises',
    'workout_plans',
    'plan_exercises',
    'workout_sessions',
    'session_sets',
    'goals',
    'settings',
  ],
  4: [
    'measurements',
    'foods',
    'food_servings',
    'food_log_entries',
    'saved_meals',
    'saved_meal_items',
    'recipes',
    'recipe_ingredients',
    'exercises',
    'workout_plans',
    'plan_exercises',
    'workout_sessions',
    'session_sets',
    'goals',
    'settings',
  ],
  5: [
    'measurements',
    'foods',
    'food_servings',
    'food_log_entries',
    'saved_meals',
    'saved_meal_items',
    'recipes',
    'recipe_ingredients',
    'recipe_substitutes',
    'meal_plan_items',
    'prep_batches',
    'exercises',
    'workout_plans',
    'plan_exercises',
    'workout_sessions',
    'session_sets',
    'goals',
    'settings',
  ],
  6: [
    'measurements',
    'foods',
    'food_servings',
    'food_log_entries',
    'saved_meals',
    'saved_meal_items',
    'recipes',
    'recipe_ingredients',
    'recipe_substitutes',
    'meal_plan_items',
    'prep_batches',
    'exercises',
    'workout_plans',
    'plan_exercises',
    'workout_sessions',
    'session_sets',
    'training_splits',
    'split_days',
    'legacy_quarantine',
    'goals',
    'settings',
  ],
  7: [
    'measurements',
    'foods',
    'food_servings',
    'food_log_entries',
    'saved_meals',
    'saved_meal_items',
    'recipes',
    'recipe_ingredients',
    'recipe_substitutes',
    'meal_plan_items',
    'prep_batches',
    'exercises',
    'workout_plans',
    'plan_exercises',
    'workout_sessions',
    'session_exercises',
    'session_sets',
    'scheduled_workouts',
    'training_splits',
    'split_days',
    'legacy_quarantine',
    'goals',
    'settings',
  ],
};

/// Re-implementation of the format 1 `DriftBackupRepository.exportJson` of
/// schema [schemaVersion]'s era. The method body is identical in every
/// commit from 75b6e18 to ebff8d0 except the clock expression (75b6e18 uses
/// `DateTime.now()`, later commits `_clock.now()`); it is:
/// for each table of `allTables`, `SELECT * FROM "<table>"` into a list of
/// column-ordered maps, then
/// `JsonEncoder.withIndent('  ').convert({app, formatVersion: 1,
/// schemaVersion, exportedAt, tables})`. Only the table list differs per
/// era ([eraTableOrder]). `exportedAt` is [goldenExportedAt] instead of the
/// wall clock.
String exportFormat1(Database db, int schemaVersion) {
  final tables = <String, List<Map<String, Object?>>>{};
  for (final name in eraTableOrder[schemaVersion]!) {
    tables[name] = [
      for (final r in db.select('SELECT * FROM "$name"'))
        Map<String, Object?>.of(r),
    ];
  }
  return const JsonEncoder.withIndent('  ').convert({
    'app': 'repforge',
    'formatVersion': 1,
    'schemaVersion': schemaVersion,
    'exportedAt': goldenExportedAt,
    'tables': tables,
  });
}

/// Names of the tables of the generated `schema_v<version>` classes, in
/// `allTables` order (to check [eraTableOrder] against the snapshots).
Future<List<String>> generatedTableOrder(int version) async {
  final db = GeneratedHelper().databaseForVersion(
    NativeDatabase.memory(),
    version,
  );
  try {
    return [for (final t in db.allTables) t.actualTableName];
  } finally {
    await db.close();
  }
}

/// Description of a freshly created database of schema [version].
Future<Map<String, Object?>> freshSchemaDescription(int version) async {
  final dir = Directory.systemTemp.createTempSync('${tempPrefix}fresh_');
  try {
    final file = File('${dir.path}/fresh.sqlite');
    final gen = GeneratedHelper().databaseForVersion(
      NativeDatabase(file),
      version,
    );
    await gen.customSelect('SELECT 1').get();
    await gen.close();
    final db = sqlite3.open(file.path);
    try {
      return describeSchema(db);
    } finally {
      db.close();
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}

// ---- Production migration -------------------------------------------------

/// Copies [fixture] to a temporary file, opens it with the CURRENT
/// production [AppDatabase] (which migrates it to v7), closes it and returns
/// the outcome. The fixture itself is never opened for writing. The
/// temporary directory is deleted before returning.
Future<Map<String, Object?>> migrateWithProduction(String fixture) async {
  final dir = Directory.systemTemp.createTempSync('${tempPrefix}migrate_');
  try {
    final copy = File('${dir.path}/copy.sqlite');
    File(fixture).copySync(copy.path);
    final beforeDb = sqlite3.open(copy.path, mode: OpenMode.readOnly);
    final List<String> violationsBefore;
    try {
      violationsBefore = foreignKeyViolations(beforeDb);
    } finally {
      beforeDb.close();
    }
    Object? error;
    final app = AppDatabase(NativeDatabase(copy));
    try {
      await app.customSelect('SELECT 1').get();
    } on Object catch (e) {
      error = e;
    } finally {
      await app.close();
    }
    final db = sqlite3.open(copy.path);
    try {
      return {
        'migrated': error == null,
        if (error != null) 'error': error.toString().split('\n').first,
        'foreignKeyViolationsBefore': violationsBefore,
        'userVersion': userVersion(db),
        'integrityCheck': integrityCheck(db),
        'foreignKeyViolations': foreignKeyViolations(db),
        'schema': describeSchema(db),
        'tables': tableDigests(db),
      };
    } finally {
      db.close();
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// Description of a database created by the production [AppDatabase]
/// (`createAll`) on an empty file.
Future<Map<String, Object?>> productionFreshSchemaDescription() async {
  final dir = Directory.systemTemp.createTempSync('${tempPrefix}prodfresh_');
  try {
    final file = File('${dir.path}/fresh.sqlite');
    final app = AppDatabase(NativeDatabase(file));
    await app.customSelect('SELECT 1').get();
    await app.close();
    final db = sqlite3.open(file.path);
    try {
      return describeSchema(db);
    } finally {
      db.close();
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// `{"v1": ..., ..., "v7": ...}` for every fixture, as stored in
/// [expectedDigestsPath]. The two `schemaEquals...` flags compare the
/// migrated schema, including the stored CHECK text, with a fresh `schema_v7`
/// snapshot database and with a fresh production `createAll` database. They
/// are informational (the stored text of a table depends on which code
/// created it); the frozen test compares the whole `schema` entry.
Future<Map<String, Object?>> expectedDigests({
  required Map<String, Object?> generatedV7Schema,
  required Map<String, Object?> productionFreshSchema,
}) async {
  final out = <String, Object?>{};
  for (final (key, path) in allFixtures()) {
    final r = await migrateWithProduction(path);
    out[key] = {
      ...r,
      'schemaEqualsGeneratedSnapshotV7': _jsonEq(
        r['schema'],
        generatedV7Schema,
      ),
      'schemaEqualsProductionFreshV7': _jsonEq(
        r['schema'],
        productionFreshSchema,
      ),
    };
  }
  return out;
}

bool _jsonEq(Object? a, Object? b) => jsonEncode(a) == jsonEncode(b);

/// The stored expectation file: documentation header, the migration result
/// of every fixture and the restore outcome of every golden backup.
Map<String, Object?> expectedFile(
  Map<String, Object?> digests,
  Map<String, Object?> restores,
) => {
  'description':
      'Result of migrating each frozen fixture with the production '
      'AppDatabase at schema v7, and of restoring each golden backup with '
      'the production DriftBackupRepository.importJson into a fresh v7 '
      'database that holds one sentinel measurement (the migration code as '
      'of the commit that added these artefacts). Frozen evidence: never '
      'regenerate.',
  'normalisation':
      'Row digests cover every column of every table (storage type and '
      'value), plus sqlite_sequence. Rows are sorted by their serialised '
      'text, so rowid order is ignored. The only normalised value is '
      'legacy_quarantine.quarantined_at: an ISO-8601 UTC text that does not '
      'start with "$fixtureQuarantineStampPrefix" (the fixtures own stamps) '
      'was written by the migration from the wall clock and is replaced by '
      '"$migrationTimePlaceholder"; any other value is kept.',
  'schema':
      'table_info, index_list (+ index columns), foreign_key_list, CHECK '
      'clauses and full CREATE text per table, stored index SQL, triggers '
      'and views. All SQL text goes through normaliseSql (identifier quotes '
      'removed, whitespace around punctuation and operators removed).',
  'fixtures': digests,
  'restores': restores,
};

String encodeJson(Object? v) =>
    '${const JsonEncoder.withIndent('  ').convert(v)}\n';

/// Restores [json] with the production `importJson` into a fresh database
/// (production `createAll`, schema v7) that first receives one sentinel
/// measurement. Returns the outcome: success or the failure kind, whether a
/// failed restore left the database byte-for-byte equal in row digests
/// (atomic), and the row digests and integrity results of a successful one.
Future<Map<String, Object?>> restoreOutcome(String json) async {
  final dir = Directory.systemTemp.createTempSync('${tempPrefix}restore_');
  try {
    final file = File('${dir.path}/restore.sqlite');
    final app = AppDatabase(NativeDatabase(file));
    Object? failure;
    int? formatVersion;
    try {
      await app.customStatement(
        'INSERT INTO measurements (id, created_at, updated_at, site, value, '
        "recorded_at) VALUES ('sentinel', '2026-11-06T00:00:00.000Z', "
        "'2026-11-06T00:00:00.000Z', 'weight', 70.0, "
        "'2026-11-06T00:00:00.000Z')",
      );
      final before = await _digestsOf(file.path, app);
      final repo = DriftBackupRepository(
        app,
        clock: FixedClock(DateTime.parse(goldenExportedAt)),
      );
      final result = await repo.importJson(json);
      switch (result) {
        case Ok(:final value):
          formatVersion = value.formatVersion;
        case Err(:final error):
          failure = error is StorageError ? (error.cause ?? error) : error;
      }
      final after = await _digestsOf(file.path, app);
      return {
        'restored': failure == null,
        'formatVersion': ?formatVersion,
        if (failure != null) ...{
          'failedOnForeignKey': failure.toString().contains('787'),
          'databaseUnchanged': jsonEncode(before) == jsonEncode(after),
        },
        'foreignKeyViolations': await _fkOf(file.path, app),
        'tables': after,
      };
    } finally {
      await app.close();
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}

// The app connection holds the file; a second read-only connection reads it
// between statements (no transaction is open here).
Future<Map<String, Object?>> _digestsOf(String path, AppDatabase app) async {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return tableDigests(db);
  } finally {
    db.close();
  }
}

Future<List<String>> _fkOf(String path, AppDatabase app) async {
  final db = sqlite3.open(path, mode: OpenMode.readOnly);
  try {
    return foreignKeyViolations(db);
  } finally {
    db.close();
  }
}

/// Restore outcome of every golden, keyed as in [allGoldens].
Future<Map<String, Object?>> expectedRestores() async => {
  for (final (key, path) in allGoldens())
    key: await restoreOutcome(File(path).readAsStringSync()),
};

/// A settings-only backup in format 1 (v6 era) and format 2 (production
/// exporter): every table present, rows only in `settings`.
Future<String> settingsOnlyFormat1(List<Map<String, Object?>> rows) async {
  final dir = Directory.systemTemp.createTempSync('${tempPrefix}settings1_');
  try {
    final file = File('${dir.path}/s.sqlite');
    final gen = GeneratedHelper().databaseForVersion(NativeDatabase(file), 6);
    await gen.customSelect('SELECT 1').get();
    await gen.close();
    final db = sqlite3.open(file.path);
    try {
      for (final r in rows) {
        db.execute(
          'INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?)',
          [r['key'], r['value'], r['updated_at']],
        );
      }
      return exportFormat1(db, 6);
    } finally {
      db.close();
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}

Future<String> settingsOnlyFormat2(List<Map<String, Object?>> rows) async {
  final dir = Directory.systemTemp.createTempSync('${tempPrefix}settings2_');
  try {
    final file = File('${dir.path}/s.sqlite');
    final app = AppDatabase(NativeDatabase(file));
    try {
      for (final r in rows) {
        await app.customStatement(
          'INSERT INTO settings (key, value, updated_at) VALUES (?, ?, ?)',
          [r['key'], r['value'], r['updated_at']],
        );
      }
      return await DriftBackupRepository(
        app,
        clock: FixedClock(DateTime.parse(goldenExportedAt)),
      ).exportJson();
    } finally {
      await app.close();
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// Format 2 export as the production repository writes it, from a temporary
/// copy of the v7 fixture (the fixture itself is not opened for writing).
Future<String> exportFormat2FromFixture({bool orphans = false}) async {
  final dir = Directory.systemTemp.createTempSync('${tempPrefix}golden_');
  try {
    final copy = File('${dir.path}/copy.sqlite');
    File(fixturePath(7, orphans: orphans)).copySync(copy.path);
    final db = AppDatabase(NativeDatabase(copy));
    try {
      return await DriftBackupRepository(
        db,
        clock: FixedClock(DateTime.parse(goldenExportedAt)),
      ).exportJson();
    } finally {
      await db.close();
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}
