import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'generated_migrations/schema_v7.dart' as v7;

/// Regression guards for drift's `onUpgrade` behaviour (WP 8 plan section 21,
/// safeguard A), measured in the stage 3b trial: no transaction around
/// `onUpgrade`, foreign keys off by default, the pragma ignored inside a
/// transaction, a rebuild with keys on cascading to child rows, and
/// `user_version` written after `onUpgrade` and `beforeOpen`. A drift upgrade
/// that changes any of this fails here. Uses `NativeDatabase(File)`, the same
/// engine as the background connection of `drift_flutter`.
/// Minimal rebuilt `exercises` table (drops the muscle columns, adds
/// `source`) so `TableMigration` has a target. Hand-written like the
/// generated schema classes.
class _GuardExercises extends Table with TableInfo<_GuardExercises, Object> {
  _GuardExercises(this.attachedDatabase, [this._alias]);

  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;

  GeneratedColumn<String> _text(String name, {String? defaultSql}) =>
      GeneratedColumn<String>(
        name,
        aliasedName,
        false,
        type: DriftSqlType.string,
        $customConstraints: defaultSql == null
            ? 'NOT NULL'
            : 'NOT NULL DEFAULT $defaultSql',
        defaultValue: defaultSql == null ? null : CustomExpression(defaultSql),
      );

  late final GeneratedColumn<String> id = _text('id');
  late final GeneratedColumn<String> createdAt = _text('created_at');
  late final GeneratedColumn<String> updatedAt = _text('updated_at');
  late final GeneratedColumn<String> name = _text('name');
  late final GeneratedColumn<String> type = _text('type');
  late final GeneratedColumn<String> category = _text('category');
  late final GeneratedColumn<String> equipmentJson = _text('equipment_json');
  late final GeneratedColumn<String> source = _text(
    'source',
    defaultSql: "'user'",
  );

  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    name,
    type,
    category,
    equipmentJson,
    source,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Object map(Map<String, dynamic> data, {String? tablePrefix}) =>
      throw UnsupportedError('DDL only');
  @override
  _GuardExercises createAlias(String alias) =>
      _GuardExercises(attachedDatabase, alias);
  @override
  List<String> get customConstraints => const ['PRIMARY KEY(id)'];
  @override
  bool get dontWriteConstraints => true;
}

class _ProbeDb extends GeneratedDatabase {
  _ProbeDb(super.executor, this.onUp, {this.onBefore});

  final Future<void> Function(_ProbeDb db, Migrator m) onUp;
  final Future<void> Function(_ProbeDb db)? onBefore;

  late final _GuardExercises exercises = _GuardExercises(this);

  @override
  Iterable<TableInfo<Table, dynamic>> get allTables => [exercises];

  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [exercises];

  @override
  int get schemaVersion => 8;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onUpgrade: (m, from, to) => onUp(this, m),
    beforeOpen: (details) async {
      await onBefore?.call(this);
    },
  );
}

Future<bool> _keys(GeneratedDatabase db) async =>
    (await db.customSelect('PRAGMA foreign_keys').getSingle()).read<bool>(
      'foreign_keys',
    );

/// True when a transaction is already open: BEGIN then fails.
Future<bool> _inTransaction(GeneratedDatabase db) async {
  try {
    await db.customStatement('BEGIN');
    await db.customStatement('ROLLBACK');
    return false;
  } on Object {
    return true;
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late Directory tmp;
  final out = <String, Object?>{};

  void record(String k, Object? v) => out[k] = v;

  /// A small v7 file: exercises (with a child table that cascades) so the
  /// rebuild hazard is visible.
  Future<String> v7File(String name) async {
    final path = '${tmp.path}/$name.sqlite';
    if (File(path).existsSync()) File(path).deleteSync();
    final db = v7.DatabaseAtV7(NativeDatabase(File(path)));
    await db.customSelect('SELECT 1').get();
    await db.close();
    sqlite3.open(path)
      ..execute('''
INSERT INTO exercises (id, created_at, updated_at, name, type, category,
  primary_muscle, secondary_muscles_json, equipment_json)
VALUES ('e1','t','t','One','weighted','push','chest','[]','[]'),
       ('e2','t','t','Two','weighted','push','lats','[]','[]')''')
      ..execute('''
CREATE TABLE exercise_targets (
  exercise_id TEXT NOT NULL REFERENCES exercises (id) ON DELETE CASCADE,
  node_id TEXT NOT NULL, PRIMARY KEY (exercise_id, node_id))''')
      ..execute(
        "INSERT INTO exercise_targets VALUES ('e1','chest'),('e2','lats')",
      )
      ..close();
    return path;
  }

  tearDownAll(() => tmp.deleteSync(recursive: true));
  setUpAll(
    () => tmp = Directory.systemTemp.createTempSync('repforge_safeguard_'),
  );

  test(
    '1. onUpgrade runs outside a transaction; foreign keys at start',
    () async {
      final path = await v7File('s1');
      final seen = <String, Object?>{};
      // Default connection, exactly as the app opens it (no setup callback).
      final db = _ProbeDb(NativeDatabase(File(path)), (db, m) async {
        seen['in_transaction_at_start_of_onUpgrade'] = await _inTransaction(db);
        seen['foreign_keys_at_start_default_connection'] = await _keys(db);
        await db.transaction(() async {
          seen['in_transaction_inside_db_transaction'] = await _inTransaction(
            db,
          );
        });
      });
      await db.customSelect('SELECT 1').get();
      await db.close();
      record('onUpgrade_default_connection', seen);
      expect(seen['in_transaction_at_start_of_onUpgrade'], isFalse);
      expect(seen['foreign_keys_at_start_default_connection'], isFalse);
      expect(seen['in_transaction_inside_db_transaction'], isTrue);
    },
  );

  test(
    '2. foreign_keys pragma: ignored inside a transaction, works outside',
    () async {
      final path = await v7File('s2');
      final seen = <String, Object?>{};
      final db = _ProbeDb(
        NativeDatabase(
          File(path),
          setup: (r) => r.execute('PRAGMA foreign_keys = ON'),
        ),
        (db, m) async {
          seen['start_with_setup_on'] = await _keys(db);
          await db.transaction(() async {
            await db.customStatement('PRAGMA foreign_keys = OFF');
            seen['off_inside_transaction_takes_effect'] = !await _keys(db);
          });
          seen['after_that_transaction'] = await _keys(db);
          await db.customStatement('PRAGMA foreign_keys = OFF');
          seen['off_outside_transaction_takes_effect'] = !await _keys(db);
          await db.customStatement('PRAGMA foreign_keys = ON');
        },
      );
      await db.customSelect('SELECT 1').get();
      await db.close();
      record('pragma_in_and_out_of_transaction', seen);
      expect(seen['off_inside_transaction_takes_effect'], isFalse);
      expect(seen['off_outside_transaction_takes_effect'], isTrue);
    },
  );

  test('3. where the pragma can be set before onUpgrade', () async {
    final seen = <String, Object?>{};
    for (final (label, on) in [('setup ON', true), ('setup OFF', false)]) {
      final path = await v7File('s3');
      final db = _ProbeDb(
        NativeDatabase(
          File(path),
          setup: (r) => r.execute('PRAGMA foreign_keys = ${on ? 'ON' : 'OFF'}'),
        ),
        (db, m) async => seen['$label: seen in onUpgrade'] = await _keys(db),
        onBefore: (db) async {
          seen['$label: in beforeOpen before the callback sets it'] =
              await _keys(db);
          await db.customStatement('PRAGMA foreign_keys = ON');
        },
      );
      await db.customSelect('SELECT 1').get();
      seen['$label: after beforeOpen'] = await _keys(db);
      await db.close();
      File(path).deleteSync();
    }
    record('where_to_set_the_pragma', seen);
    expect(seen['setup ON: seen in onUpgrade'], isTrue);
    expect(seen['setup OFF: seen in onUpgrade'], isFalse);
    expect(seen['setup OFF: after beforeOpen'], isTrue);
  });

  test('4. rebuild with keys ON in a transaction cascades', () async {
    final seen = <String, Object?>{};
    for (final (label, offFirst) in [
      ('transaction only, keys ON', false),
      ('keys OFF outside, then transaction', true),
    ]) {
      final path = await v7File('s4');
      final db = _ProbeDb(
        NativeDatabase(
          File(path),
          setup: (r) => r.execute('PRAGMA foreign_keys = ON'),
        ),
        (db, m) async {
          if (offFirst) await db.customStatement('PRAGMA foreign_keys = OFF');
          try {
            await db.transaction(() async {
              await m.alterTable(
                TableMigration(db.exercises, newColumns: [db.exercises.source]),
              );
            });
          } finally {
            if (offFirst) await db.customStatement('PRAGMA foreign_keys = ON');
          }
        },
      );
      await db.customSelect('SELECT 1').get();
      await db.close();
      final raw = sqlite3.open(path);
      seen['$label: exercises kept'] = raw
          .select('SELECT count(*) AS c FROM exercises')
          .first['c'];
      seen['$label: exercise_targets kept (of 2)'] = raw
          .select('SELECT count(*) AS c FROM exercise_targets')
          .first['c'];
      raw.close();
    }
    record('rebuild_cascade_hazard', seen);
    expect(seen['transaction only, keys ON: exercise_targets kept (of 2)'], 0);
    expect(
      seen['keys OFF outside, then transaction: exercise_targets kept (of 2)'],
      2,
    );
  });

  test(
    '5. failure rolls back only if the work is inside transaction()',
    () async {
      final seen = <String, Object?>{};
      for (final (label, wrap) in [
        ('statements without transaction', false),
        ('statements inside transaction', true),
      ]) {
        final path = await v7File('s5');
        Future<void> work(_ProbeDb db) async {
          await db.customStatement('CREATE TABLE step_one (x INTEGER)');
          await db.customStatement(
            'ALTER TABLE exercises ADD COLUMN extra TEXT',
          );
          throw StateError('boom');
        }

        final db = _ProbeDb(NativeDatabase(File(path)), (db, m) async {
          if (wrap) {
            await db.transaction(() => work(db));
          } else {
            await work(db);
          }
        });
        try {
          await db.customSelect('SELECT 1').get();
        } on Object {
          // expected
        }
        try {
          await db.close();
        } on Object {
          // ignore
        }
        final raw = sqlite3.open(path);
        seen['$label: user_version'] = raw
            .select('PRAGMA user_version')
            .first
            .values
            .first;
        seen['$label: step_one table persists'] = raw
            .select("SELECT 1 FROM sqlite_master WHERE name = 'step_one'")
            .isNotEmpty;
        seen['$label: extra column persists'] = raw
            .select('PRAGMA table_info(exercises)')
            .any((r) => r['name'] == 'extra');
        raw.close();
      }
      record('failure_rollback', seen);
      expect(
        seen['statements inside transaction: step_one table persists'],
        isFalse,
      );
    },
  );

  test('6. user_version is written after onUpgrade and beforeOpen', () async {
    final path = await v7File('s6');
    final seen = <String, Object?>{};
    final db = _ProbeDb(
      NativeDatabase(File(path)),
      (db, m) async {
        seen['user_version_in_onUpgrade'] =
            (await db.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version');
      },
      onBefore: (db) async {
        seen['user_version_in_beforeOpen'] =
            (await db.customSelect('PRAGMA user_version').getSingle())
                .read<int>('user_version');
      },
    );
    await db.customSelect('SELECT 1').get();
    seen['user_version_after_open'] =
        (await db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        );
    seen['journal_mode'] =
        (await db.customSelect('PRAGMA journal_mode').getSingle())
            .data
            .values
            .first;
    await db.close();
    record('user_version_timing', seen);
    expect(seen['user_version_in_onUpgrade'], 7);
    expect(seen['user_version_in_beforeOpen'], 7);
    expect(seen['user_version_after_open'], 8);
  });
}
