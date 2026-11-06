import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:sqlite3/sqlite3.dart';

/// Test support for schema v8 (WP 8 stage 3b-2).

/// A fresh in-memory [AppDatabaseV8], opened (so `onCreate` and the
/// bootstrap ran and foreign keys are on), with the raw connection for
/// synchronous constraint probes.
final class FreshV8 {
  FreshV8._(this.raw, this.db);

  static Future<FreshV8> open() async {
    final raw = sqlite3.openInMemory();
    final db = AppDatabaseV8(NativeDatabase.opened(raw));
    await db.customSelect('SELECT 1').get();
    return FreshV8._(raw, db);
  }

  final Database raw;
  final AppDatabaseV8 db;

  Future<void> close() => db.close();

  /// True when [sql] with [args] succeeds; false when SQLite refuses it with
  /// a constraint error. Any other error fails the test.
  bool accepts(String sql, [List<Object?> args = const []]) {
    raw.execute('SAVEPOINT probe');
    try {
      raw.execute(sql, args);
      return true;
    } on SqliteException catch (e) {
      if (!e.message.contains('constraint failed') &&
          !e.message.contains('FOREIGN KEY')) {
        fail('unexpected error: $e');
      }
      return false;
    } finally {
      raw
        ..execute('ROLLBACK TO probe')
        ..execute('RELEASE probe');
    }
  }

  /// Executes [sql] and keeps the result.
  void run(String sql, [List<Object?> args = const []]) =>
      raw.execute(sql, args);

  /// Rows of [table] as JSON lines, sorted (order independent).
  List<String> dump(String table) => [
    for (final r in raw.select('SELECT * FROM "$table"'))
      jsonEncode(Map<String, Object?>.of(r)),
  ]..sort();
}

const stamp = '2026-11-06T12:00:00.000Z';

/// Inserts a minimal exercise row; [extra] overrides or adds columns.
void insertExercise(
  FreshV8 v8,
  String id, {
  Map<String, Object?> extra = const {},
}) {
  final row = <String, Object?>{
    'id': id,
    'created_at': stamp,
    'updated_at': stamp,
    'name': 'Exercise $id',
    'type': 'weighted',
    'category': 'push',
    'source': 'user',
    ...extra,
  };
  v8.run(
    'INSERT INTO exercises (${row.keys.join(', ')}) '
    'VALUES (${List.filled(row.length, '?').join(', ')})',
    row.values.toList(),
  );
}

/// Same, as SQL text for [FreshV8.accepts].
(String, List<Object?>) exerciseInsert(
  String id, [
  Map<String, Object?> extra = const {},
]) {
  final row = <String, Object?>{
    'id': id,
    'created_at': stamp,
    'updated_at': stamp,
    'name': 'Exercise $id',
    'type': 'weighted',
    'category': 'push',
    'source': 'user',
    ...extra,
  };
  return (
    'INSERT INTO exercises (${row.keys.join(', ')}) '
        'VALUES (${List.filled(row.length, '?').join(', ')})',
    row.values.toList(),
  );
}

/// SQL text of a stored entity, whitespace collapsed and double quotes
/// removed (the form drift writes depends on who wrote the DDL).
String collapseSql(String sql) =>
    sql.replaceAll('"', '').replaceAll(RegExp(r'\s+'), ' ').trim();

/// Strict schema of [db]: every entity as `type|name|table|sql`, SQL through
/// a whitespace and quote normaliser that keeps operators (the 3b-3
/// `strictNormaliseSql` form), sorted. Auto-indexes are listed by name.
List<String> strictSchema(Database db) => [
  for (final r in db.select(
    'SELECT type, name, tbl_name, sql FROM sqlite_master '
    "WHERE name <> 'sqlite_sequence' ORDER BY type, name",
  ))
    [
      r['type'],
      r['name'],
      r['tbl_name'],
      if (r['sql'] case final String sql)
        collapseSql(sql)
            .replaceAllMapped(RegExp(r'\s*([(),=<>!])\s*'), (m) => m.group(1)!)
      else
        '-',
    ].join('|'),
];

/// A database with no tables, so a [Migrator] over a versioned schema can
/// create that schema on an empty connection.
class BareDatabase extends GeneratedDatabase {
  BareDatabase(super.executor, {this.version = 1});

  final int version;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables => const [];

  @override
  int get schemaVersion => version;
}

/// [strictSchema] of a new in-memory database opened by [open], after
/// [create] if given.
Future<List<String>> freshStrictSchema(
  GeneratedDatabase Function(QueryExecutor e) open, {
  Future<void> Function(GeneratedDatabase db)? create,
}) async {
  final raw = sqlite3.openInMemory();
  final db = open(NativeDatabase.opened(raw));
  try {
    await db.customSelect('SELECT 1').get();
    if (create != null) await create(db);
    return strictSchema(raw);
  } finally {
    await db.close();
  }
}

/// Approved reference file under `docs/catalogue/reference/`.
Map<String, Object?> referenceJson(String name) =>
    jsonDecode(File('../docs/catalogue/reference/$name').readAsStringSync())
        as Map<String, Object?>;
