import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/repositories/v8/backup_restore_plan_v8.dart';
import 'package:repforge/data/repositories/v8/backup_schema_v8.dart';
import 'package:repforge/data/repositories/v8/drift_backup_repository_v8.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/exercise_rules.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../domain/library/support/catalogue_fixtures.dart';
import 'backup_v8_support.dart';

/// WP 8 sub-stage 3b-7: the Dart mirror of the v8 constraints
/// (`backup_schema_v8.dart`) equals a fresh `AppDatabaseV8`, and every CHECK
/// verdict of the mirror equals SQLite's on mutated rows. The restore
/// validates with the mirror before it writes; SQLite stays the backstop.
void main() {
  late Directory dir;
  late Database raw;
  late Map<String, List<Map<String, Object?>>> baseRows;

  setUpAll(() async {
    dir = Directory.systemTemp.createTempSync(backupTempPrefix);
    // A rich database gives a valid base row for every table.
    final rich = await richV8(await V8File.create(dir, 'rich.sqlite'));
    final env =
        jsonDecode(await rich.repo().exportJson()) as Map<String, Object?>;
    await rich.close();
    baseRows = {
      for (final MapEntry(:key, :value)
          in (env['tables']! as Map<String, Object?>).entries)
        key: [for (final r in value! as List) r as Map<String, Object?>],
    };
    // An empty v8 schema for the differential inserts (keys off).
    final empty = await V8File.create(dir, 'empty.sqlite');
    await empty.close();
    raw = sqlite3.open('${dir.path}/empty.sqlite')
      ..execute('PRAGMA foreign_keys = OFF');
  });

  tearDownAll(() {
    raw.close();
    dir.deleteSync(recursive: true);
  });

  String ddl(String table) =>
      raw.select(
            "SELECT sql FROM sqlite_master WHERE type = 'table' AND name = ?",
            [table],
          ).single['sql']!
          as String;

  test('the mirror lists every v8 table in AppDatabaseV8 order', () async {
    final v8 = await V8File.create(dir, 'order.sqlite');
    try {
      expect(
        schemaV8Tables.map((t) => t.name),
        v8.db.allTables.map((t) => t.actualTableName),
      );
    } finally {
      await v8.close();
    }
  });

  test('columns, types, NOT NULL, defaults and primary keys equal '
      'PRAGMA table_info', () {
    for (final spec in schemaV8Tables) {
      final info = raw.select('PRAGMA table_info("${spec.name}")');
      expect(
        [for (final c in info) c['name']],
        [for (final c in spec.columns) c.name],
        reason: spec.name,
      );
      for (final c in info) {
        final m = spec.column(c['name']! as String)!;
        final where = '${spec.name}.${c['name']}';
        expect(c['type'], switch (m.type) {
          ColumnType.text => 'TEXT',
          ColumnType.integer => 'INTEGER',
          ColumnType.real => 'REAL',
        }, reason: where);
        expect(c['notnull'] == 1, m.notNull, reason: where);
        expect(c['dflt_value'], switch (m.defaultValue) {
          _ when !m.hasDefault => null,
          final String s => "'$s'",
          final Object v => '$v',
          null => null,
        }, reason: where);
      }
      final pk = [
        for (final c in info)
          if ((c['pk']! as int) > 0) c,
      ]..sort((a, b) => (a['pk']! as int).compareTo(b['pk']! as int));
      expect(
        [for (final c in pk) c['name']],
        spec.primaryKey,
        reason: spec.name,
      );
      final auto = ddl(spec.name).contains('AUTOINCREMENT');
      expect(spec.columns.any((c) => c.autoIncrement), auto, reason: spec.name);
    }
  });

  test(
    'UNIQUE sets equal the unique indexes; foreign keys equal '
    'PRAGMA foreign_key_list; the number of CHECK clauses equals the DDL',
    () {
      for (final spec in schemaV8Tables) {
        final uniques = [
          for (final i in raw.select('PRAGMA index_list("${spec.name}")'))
            if (i['origin'] == 'u')
              [
                for (final c in raw.select('PRAGMA index_info("${i['name']}")'))
                  c['name'],
              ],
        ];
        expect(
          uniques.map(jsonEncode).toSet(),
          spec.uniques.map(jsonEncode).toSet(),
          reason: spec.name,
        );
        final fks = {
          for (final f in raw.select('PRAGMA foreign_key_list("${spec.name}")'))
            '${f['from']}->${f['table']}.${f['to']}',
        };
        expect(fks, {
          for (final f in spec.foreignKeys)
            '${f.column}->${f.parentTable}.${f.parentColumn}',
        }, reason: spec.name);
        expect(
          RegExp('CHECK').allMatches(ddl(spec.name)).length,
          spec.checks.length,
          reason: spec.name,
        );
      }
    },
  );

  bool sqliteAccepts(String table, Map<String, Object?> row) {
    raw.execute('DELETE FROM "$table"');
    final cols = row.keys.toList();
    try {
      raw.execute(
        'INSERT INTO "$table" (${cols.map((c) => '"$c"').join(', ')}) '
        'VALUES (${List.filled(cols.length, '?').join(', ')})',
        [for (final c in cols) row[c]],
      );
      return true;
    } on SqliteException {
      return false;
    }
  }

  bool mirrorAccepts(String table, Map<String, Object?> row) {
    try {
      validateRowV8(schemaV8ByName[table]!, row, where: table);
      return true;
    } on RestoreRejected {
      return false;
    }
  }

  List<Object?> pool(TableSpec spec, ColumnSpec c, Map<String, Object?> base) {
    final literals = {
      for (final m in RegExp("'([^']*)'").allMatches(ddl(spec.name)))
        m.group(1)!,
    };
    return switch (c.type) {
      ColumnType.text => [
        null,
        '',
        'x',
        ' ',
        '\t \n',
        ' a ',
        ' ',
        'en-GB',
        'de-DE',
        '{"a":1}',
        '[1,2]',
        'not json',
        '"s"',
        '7',
        'a' * 64,
        'A' * 64,
        'a' * 63,
        'g' * 64,
        'n' * 4000,
        'n' * 4001,
        '\u{1F600}' * 4000,
        if (base['id'] case final String id) id,
        ...literals,
      ],
      ColumnType.integer => [
        null,
        for (final v in [-1, 0, 1, 2, 4, 5, 6, 7, 8, 13, 14, 15, 20, 21]) v,
        for (final v in [29, 30, 100, 101, 250, 251, 1000, 1001, 3600, 3601]) v,
      ],
      ColumnType.real => [
        null,
        -0.5,
        0.0,
        0.5,
        1.0,
        1.5,
        4.5,
        5.0,
        5.5,
        7.3,
        9.75,
        10.0,
        10.5,
        1000.0,
        1000.5,
        0,
        5,
        11,
      ],
    };
  }

  test('every single-column mutation of a valid row: the mirror and SQLite '
      'agree', () {
    var compared = 0;
    var refused = 0;
    for (final spec in schemaV8Tables) {
      final base = baseRows[spec.name]!.first;
      expect(sqliteAccepts(spec.name, base), isTrue, reason: spec.name);
      expect(mirrorAccepts(spec.name, base), isTrue, reason: spec.name);
      for (final c in spec.columns) {
        for (final v in pool(spec, c, base)) {
          final row = {...base, c.name: v};
          final s = sqliteAccepts(spec.name, row);
          expect(
            mirrorAccepts(spec.name, row),
            s,
            reason: '${spec.name}.${c.name} = ${jsonEncode(v)}',
          );
          compared++;
          if (!s) refused++;
        }
      }
    }
    expect(compared, greaterThan(5000));
    expect(refused, greaterThan(500));
  });

  test('two-column mutations of the paired CHECKs: the mirror and SQLite '
      'agree', () {
    final pairs = {
      'session_sets': [
        ('exertion_scale', 'exertion_value'),
        ('energy_kcal', 'energy_provenance'),
      ],
      'plan_exercises': [('reps_min', 'reps_max')],
      'anatomy_nodes': [('level', 'parent_id'), ('level', 'non_anatomical')],
      'migration_runs': [
        ('provenance_kind', 'merged_at'),
        ('trigger_kind', 'from_version'),
        ('trigger_kind', 'to_version'),
        ('from_version', 'to_version'),
      ],
      'migration_report_entries': [('disposition', 'block_reason')],
      'migration_report_counts': [('dimension', 'code')],
      'exercise_equipment': [('role_override', 'override_note')],
      'exercises': [('source', 'provider_id'), ('source', 'revision')],
    };
    final extra = <String, List<Object?>>{
      'exertion_scale': ['rpe', 'rir', 'RPE', 'borg', null],
      'exertion_value': [
        null,
        -1,
        0,
        0.5,
        1,
        1.5,
        2.0,
        4.5,
        5,
        5.5,
        6,
        7.3,
        9.75,
        10,
        10.5,
        11,
        0.25,
        1.0000001,
      ],
      'migration_report_counts.code': [
        'examined',
        'migrated',
        'blocked',
        'none',
        'warningForReview',
        'other',
      ],
    };
    var compared = 0;
    for (final MapEntry(key: table, value: list) in pairs.entries) {
      final spec = schemaV8ByName[table]!;
      final base = baseRows[table]!.first;
      for (final (a, b) in list) {
        List<Object?> values(String c) =>
            extra['$table.$c'] ??
            extra[c] ??
            pool(spec, spec.column(c)!, base).take(40).toList();
        for (final va in values(a)) {
          for (final vb in values(b)) {
            final row = {...base, a: va, b: vb};
            expect(
              mirrorAccepts(table, row),
              sqliteAccepts(table, row),
              reason: '$table $a=${jsonEncode(va)} $b=${jsonEncode(vb)}',
            );
            compared++;
          }
        }
      }
    }
    expect(compared, greaterThan(2000));
  });

  test('the TRN-020 mirror equals the SQL expression on a fine grid', () {
    for (final scale in ['rpe', 'rir', 'RPE', null]) {
      for (var i = -40; i <= 240; i++) {
        final v = i / 20; // 0.05 steps from -2 to 12
        final row = {
          ...baseRows['session_sets']!.first,
          'exertion_scale': scale,
          'exertion_value': v,
        };
        expect(
          mirrorAccepts('session_sets', row),
          sqliteAccepts('session_sets', row),
          reason: '$scale $v',
        );
      }
    }
  });

  test('types are strict: a value of another JSON type is refused before '
      'SQLite would coerce it', () {
    final base = baseRows['plan_exercises']!.first;
    for (final (column, value) in [
      ('target_sets', '3'),
      ('target_sets', 3.0),
      ('target_load_kg', '20'),
      ('exercise_id', 5),
      ('exercise_id', true),
      ('target_sets', <Object?>[]),
    ]) {
      expect(
        mirrorAccepts('plan_exercises', {...base, column: value}),
        isFalse,
        reason: '$column ${jsonEncode(value)}',
      );
    }
    // A boolean is stored as 1 or 0 in an INTEGER column (as production
    // restore binds it).
    final set = baseRows['session_sets']!.first;
    final out = validateRowV8(schemaV8ByName['session_sets']!, {
      ...set,
      'completed': false,
    }, where: 'x');
    expect(out['completed'], 0);
  });

  test('IC-315 of the restore equals the domain check (validateExercise) '
      'for every approved item, role and note', () {
    final ref = ApprovedReference.load();
    final ctx = ExerciseRuleContext(
      reference: ref.data,
      providers: {ProviderId.repforge},
    );
    var n = 0;
    for (final item in ref.equipment.items) {
      for (final role in [null, ...EquipmentRole.values]) {
        for (final note in [null, '', ' ', ' ', '\t\n', 'A note.']) {
          final domain = validateExercise(
            exercise(
              'lib-x',
              equipment: [
                ExerciseEquipment(
                  item.id,
                  roleOverride: role,
                  overrideNote: note,
                ),
              ],
            ),
            ctx,
          ).any((f) => f.code == 'IC-315');
          final restore =
              ic315Problem(
                roleOverride: role?.name,
                overrideNote: note,
                defaultRole: item.defaultRole.name,
              ) !=
              null;
          expect(
            restore,
            domain,
            reason: '${item.id} $role ${jsonEncode(note)}',
          );
          n++;
        }
      }
    }
    expect(n, greaterThan(500));
    expect(
      ref.equipment.items.map((i) => i.id),
      contains(const EquipmentItemId('treadmill')),
    );
  });
}
