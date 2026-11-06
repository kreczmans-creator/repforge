import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/db/migration/historical_steps.dart';
import 'package:repforge/data/db/migration/repforge_migration.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:sqlite3/sqlite3.dart';

import '../data/generated_migrations/schema_v7.dart' as v7;
import 'migration_digest.dart';

/// Test-only database for WP 8 stage 3b-3: the frozen schema v7 snapshot
/// classes (`DatabaseAtV7`) migrated by the new step chain
/// ([RepforgeMigration] with [HistoricalSteps]) instead of `AppDatabase`.
///
/// [targetVersion] below 7 stops the chain early (reference states for the
/// failure tests). It is never used to create a database.
class HarnessV7Database extends v7.DatabaseAtV7 {
  HarnessV7Database(
    super.e, {
    this.targetVersion = 7,
    this.probe,
    this.steps,
    Clock? clock,
  }) : clock = clock ?? harnessClock;

  final int targetVersion;
  final MigrationProbe? probe;
  final MigrationStep? steps;
  final Clock clock;

  @override
  int get schemaVersion => targetVersion;

  @override
  MigrationStrategy get migration => RepforgeMigration(
    database: this,
    clock: clock,
    probe: probe,
    steps: steps,
  ).strategy;
}

/// Fixed clock of the harness; its stamps normalise to `<migration-time>`.
final harnessClock = FixedClock(DateTime.utc(2026, 11, 6, 12));

/// Prefix of the temporary directories made here (distinct from the 3b-1
/// prefix, whose "no temp file left" check must not see these).
const chainTempPrefix = 'repforge_v8_chain_3b3_';

/// Runs [body] with a temporary copy of [fixture]; deletes the copy after.
Future<T> withFixtureCopy<T>(
  String fixture,
  Future<T> Function(File copy) body,
) async {
  final dir = Directory.systemTemp.createTempSync(chainTempPrefix);
  try {
    final copy = File('${dir.path}/copy.sqlite');
    File(fixture).copySync(copy.path);
    return await body(copy);
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// Opens [file] with a [HarnessV7Database] (which runs the chain), closes it
/// and returns the error, if any. [foreignKeysOnAtSetup] switches keys on
/// when the connection opens, before drift runs the migration.
Future<Object?> openWithChain(
  File file, {
  int targetVersion = 7,
  MigrationProbe? probe,
  MigrationStep? steps,
  bool foreignKeysOnAtSetup = false,
}) async {
  final db = HarnessV7Database(
    NativeDatabase(
      file,
      setup: foreignKeysOnAtSetup
          ? (d) => d.execute('PRAGMA foreign_keys = ON')
          : null,
    ),
    targetVersion: targetVersion,
    probe: probe,
    steps: steps,
  );
  try {
    await db.customSelect('SELECT 1').get();
    return null;
  } on Object catch (e) {
    return e;
  } finally {
    await db.close();
  }
}

/// The 3b-1 result map (as `migrateWithProduction` returns it) of the state
/// in [file].
Map<String, Object?> describeFile(File file, {Object? error}) {
  final db = sqlite3.open(file.path);
  try {
    return {
      'migrated': error == null,
      if (error != null) 'error': error.toString().split('\n').first,
      'userVersion': userVersion(db),
      'integrityCheck': integrityCheck(db),
      'foreignKeyViolations': foreignKeyViolations(db),
      'schema': describeSchema(db),
      'tables': tableDigests(db),
      'strictSchema': strictSchema(db),
      'strictRecord': strictSchemaRecord(db),
    };
  } finally {
    db.close();
  }
}

/// Migrates a copy of [fixture] with the new chain; same keys as the 3b-1
/// `migrateWithProduction`, plus `strictSchema`.
Future<Map<String, Object?>> migrateWithChain(String fixture) =>
    withFixtureCopy(fixture, (copy) async {
      final before = sqlite3.open(copy.path, mode: OpenMode.readOnly);
      final List<String> violationsBefore;
      try {
        violationsBefore = foreignKeyViolations(before);
      } finally {
        before.close();
      }
      final error = await openWithChain(copy);
      return {
        ...describeFile(copy, error: error),
        'foreignKeyViolationsBefore': violationsBefore,
      };
    });

/// [strictSchema] of a copy of [fixture] migrated by today's production
/// `AppDatabase` (live, not the stored expectation).
Future<List<String>> productionStrictSchema(String fixture) =>
    withFixtureCopy(fixture, (copy) async {
      final app = AppDatabase(NativeDatabase(copy));
      try {
        await app.customSelect('SELECT 1').get();
      } finally {
        await app.close();
      }
      final db = sqlite3.open(copy.path, mode: OpenMode.readOnly);
      try {
        return strictSchema(db);
      } finally {
        db.close();
      }
    });

/// Like the 3b-1 `normaliseSql`, but keeps the punctuation and operators it
/// removes the whitespace around. (`normaliseSql` writes a literal `$1` for
/// every one of them, so `<`, `>`, `=`, `!`, `(`, `)` and `,` compare equal
/// there; it is frozen evidence and stays as it is.)
///
/// Known limit (review L5, accepted): it is not SQL-aware, so it also
/// collapses whitespace and removes `"` inside string literals. The frozen
/// record (`strictSchemaRecord`) keeps the raw `sql` too, which covers them.
String strictNormaliseSql(String sql) {
  final t = sql.replaceAll('"', '').replaceAll(RegExp(r'\s+'), ' ').trim();
  return t.replaceAllMapped(RegExp(r'\s*([(),=<>!])\s*'), (m) => m.group(1)!);
}

/// Every schema entity as `type|name|table|sql`, the SQL through
/// [strictNormaliseSql], sorted. Auto-indexes (no SQL) are listed by name.
List<String> strictSchema(Database db) => [
  for (final r in db.select(
    'SELECT type, name, tbl_name, sql FROM sqlite_master '
    "WHERE name <> 'sqlite_sequence' ORDER BY type, name",
  ))
    [
      r['type'],
      r['name'],
      r['tbl_name'],
      if (r['sql'] case final String sql) strictNormaliseSql(sql) else '-',
    ].join('|'),
];

// ---- Strict schema record (3b-3 frozen evidence, review M1) ----------------

/// Frozen strict v7 schema of today's production (written once by
/// `fixtures/build_3b3_evidence.dart`). Not named `expected_*`: the 3b-1
/// manifest test claims every `expected_*` file in `fixtures/`.
const strictSchemaPath = '$fixturesDir/v7_strict_schema_3b3.json';

/// Manifest of the 3b-3 frozen files; the old `MANIFEST.sha256` is unchanged.
const manifest3b3Path = '$fixturesDir/MANIFEST_3b3.sha256';

/// Files pinned by [manifest3b3Path], relative to `app/`.
const pinned3b3Files = <String>[
  strictSchemaPath,
  'lib/data/db/migration/schema_versions.g.dart',
  'lib/data/db/migration/legacy_training_rows_v6.dart',
];

/// The CHECK clauses of a CREATE TABLE text, each through
/// [strictNormaliseSql] (same scan as the 3b-1 `describeSchema`).
List<String> strictChecks(String sql) {
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
    out.add(strictNormaliseSql(sql.substring(i + 1, j)));
    from = j;
  }
  return out;
}

/// Every schema entity (tables, indexes, triggers, views; not
/// `sqlite_sequence`) sorted by type and name, with its raw SQL, its strict
/// SQL and, for a table, its strict CHECK clauses.
List<Map<String, Object?>> strictSchemaRecord(Database db) => [
  for (final r in db.select(
    'SELECT type, name, tbl_name, sql FROM sqlite_master '
    "WHERE name <> 'sqlite_sequence' ORDER BY type, name",
  ))
    {
      'type': r['type'],
      'name': r['name'],
      'tbl_name': r['tbl_name'],
      'sql': r['sql'],
      'strict': switch (r['sql']) {
        final String sql => strictNormaliseSql(sql),
        _ => null,
      },
      if (r['type'] == 'table' && r['sql'] is String)
        'checks': strictChecks(r['sql']! as String),
    },
];

/// The strict parts of a [strictSchemaRecord] (raw SQL left out), for
/// comparing databases created by different code.
List<Map<String, Object?>> strictOnly(List<Object?> record) => [
  for (final e in record.cast<Map<String, Object?>>())
    {
      for (final k in e.keys)
        if (k != 'sql') k: e[k],
    },
];

/// [strictSchemaRecord] of a copy of [fixture] migrated by today's
/// production `AppDatabase`.
Future<List<Map<String, Object?>>> productionStrictRecord(String fixture) =>
    withFixtureCopy(fixture, (copy) async {
      final app = AppDatabase(NativeDatabase(copy));
      try {
        await app.customSelect('SELECT 1').get();
      } finally {
        await app.close();
      }
      final db = sqlite3.open(copy.path, mode: OpenMode.readOnly);
      try {
        return strictSchemaRecord(db);
      } finally {
        db.close();
      }
    });

/// [strictSchemaRecord] of a fresh production database (`createAll`).
Future<List<Map<String, Object?>>> productionFreshStrictRecord() async {
  final dir = Directory.systemTemp.createTempSync(chainTempPrefix);
  try {
    final file = File('${dir.path}/fresh.sqlite');
    final app = AppDatabase(NativeDatabase(file));
    try {
      await app.customSelect('SELECT 1').get();
    } finally {
      await app.close();
    }
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      return strictSchemaRecord(db);
    } finally {
      db.close();
    }
  } finally {
    dir.deleteSync(recursive: true);
  }
}
