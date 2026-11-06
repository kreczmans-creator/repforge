import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart' as v7;
import 'package:repforge/data/db/migration/schema_v8_shapes.g.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:repforge/data/db/v8/exertion_rule_sql.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../migration_trial/trial_db.dart' as trial;
import '../generated_migrations/schema.dart';
import 'v8_support.dart';

/// WP 8 stage 3b-2: the schema v8 definition equals the dumped schema
/// (`drift_schemas/drift_schema_v8.json`), keeps every unchanged v7 table
/// byte for byte, and is not connected to production.
void main() {
  group('a fresh AppDatabaseV8 creates exactly the dumped schema', () {
    late List<String> fresh;
    setUpAll(() async => fresh = await freshStrictSchema(AppDatabaseV8.new));

    test('equal to the snapshot generated from drift_schema_v8.json', () async {
      final snapshot = await freshStrictSchema(
        (e) => GeneratedHelper().databaseForVersion(e, 8),
      );
      expect(fresh, snapshot);
      expect(GeneratedHelper.versions, contains(8));
    });

    test('equal to Schema8 of schema_v8_shapes.g.dart (the 3b-4 step '
        'shapes)', () async {
      final shapes = await freshStrictSchema(
        BareDatabase.new,
        create: (db) => Migrator(db, Schema8(database: db)).createAll(),
      );
      expect(fresh, shapes);
    });

    test('the dump names schema version 8 and every table of the '
        'database', () async {
      final dump = jsonDecode(
        File('drift_schemas/drift_schema_v8.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final entities = (dump['entities']! as List<Object?>)
          .cast<Map<String, Object?>>();
      final dumpedTables = {
        for (final e in entities)
          if (e['type'] == 'table') (e['data']! as Map)['name'],
      };
      final v8 = await FreshV8.open();
      addTearDown(v8.close);
      expect(dumpedTables, {
        for (final t in v8.db.allTables) t.actualTableName,
      });
      expect(v8.db.schemaVersion, 8);
      expect(v8.raw.select('PRAGMA user_version').first.values.first, 8);
    });

    test('foreign keys are on, integrity_check is ok, foreign_key_check is '
        'empty after the bootstrap', () async {
      final v8 = await FreshV8.open();
      addTearDown(v8.close);
      expect(v8.raw.select('PRAGMA foreign_keys').first.values.first, 1);
      expect(v8.raw.select('PRAGMA integrity_check').first.values.first, 'ok');
      expect(v8.raw.select('PRAGMA foreign_key_check'), isEmpty);
    });

    test('no trigger or view exists (nothing derives values)', () {
      expect(
        fresh.where((e) => e.startsWith('trigger|') || e.startsWith('view|')),
        isEmpty,
      );
    });

    test('tables deferred to 3c by the owner are absent (R-13, R-16 '
        'to R-18)', () {
      final tables = {
        for (final e in fresh)
          if (e.startsWith('table|')) e.split('|')[1],
      };
      expect(
        tables.intersection({
          'exercise_relationships',
          'exercise_content',
          'exercise_media',
        }),
        isEmpty,
      );
      expect(
        tables,
        containsAll([
          'content_providers',
          'catalogue_releases',
          'anatomy_nodes',
          'movement_patterns',
          'equipment_items',
          'reference_labels',
          'exercise_targets',
          'exercise_patterns',
          'exercise_equipment',
          'exercise_names',
          'exercise_user_state',
          'exercise_blocks',
          'migration_runs',
          'migration_report_counts',
          'migration_report_entries',
        ]),
      );
      for (final t in [
        'anatomy_nodes',
        'movement_patterns',
        'equipment_items',
      ]) {
        final create = fresh.firstWhere((e) => e.startsWith('table|$t|'));
        expect(create, isNot(contains('release')), reason: t);
      }
    });
  });

  group('v7 compared with v8', () {
    late Map<String, String> v7Sql;
    late Map<String, String> v8Sql;

    Future<Map<String, String>> sqlOf(
      GeneratedDatabase Function(QueryExecutor) open,
    ) async {
      final raw = sqlite3.openInMemory();
      final db = open(NativeDatabase.opened(raw));
      await db.customSelect('SELECT 1').get();
      final out = {
        for (final r in raw.select(
          'SELECT name, sql FROM sqlite_master WHERE sql IS NOT NULL',
        ))
          r['name']! as String: r['sql']! as String,
      };
      await db.close();
      return out;
    }

    setUpAll(() async {
      v7Sql = await sqlOf(v7.AppDatabase.new);
      v8Sql = await sqlOf(AppDatabaseV8.new);
    });

    test('every v7 table and index except exercises and session_sets is '
        'unchanged, byte for byte', () {
      final unchanged = {
        for (final e in v7Sql.entries)
          if (e.key != 'exercises' && e.key != 'session_sets') e.key: e.value,
      };
      expect(unchanged.length, greaterThan(35));
      for (final e in unchanged.entries) {
        expect(v8Sql[e.key], e.value, reason: e.key);
      }
    });

    test('session_sets differs only by the TRN-020 clause', () {
      const v7Clause =
          'CHECK (exertion_value IS NULL OR exertion_value BETWEEN 0 AND 10)';
      final v7Table = v7Sql['session_sets']!;
      expect(v7Table, contains(v7Clause));
      expect(
        v8Sql['session_sets'],
        v7Table.replaceFirst(v7Clause, sessionSetsExertionCheck),
      );
    });

    test('the TRN-020 expression is the trial expression, ported', () {
      String flat(String s) => s.replaceAll(RegExp(r'\s+'), ' ').trim();
      expect(flat(exertionRuleSql()), flat(trial.exertionRuleSql()));
      expect(
        flat(exertionRuleSql(scale: 'NEW.s', value: 'NEW.v')),
        flat(trial.exertionRuleSql(scale: 'NEW.s', value: 'NEW.v')),
      );
    });

    test('exercises: three muscle and supply columns and equipment_json '
        'removed; provenance, classifications and attributes added', () async {
      final v8 = await FreshV8.open();
      addTearDown(v8.close);
      final cols = [
        for (final r in v8.raw.select('PRAGMA table_info(exercises)'))
          r['name'],
      ];
      expect(
        cols,
        isNot(
          anyOf(
            contains('primary_muscle'),
            contains('secondary_muscles_json'),
            contains('supplied'),
            contains('equipment_json'),
          ),
        ),
      );
      expect(cols, [
        'id',
        'created_at',
        'updated_at',
        'deleted_at',
        'name',
        'type',
        'category',
        'aliases_json',
        'search_key',
        'copied_from_id',
        'archived',
        'source',
        'provider_id',
        'revision',
        'mechanics',
        'laterality',
        'difficulty',
        'retired_at',
        'angle',
        'arm_position',
        'body_position',
        'grip',
        'grip_width',
        'knee_position',
        'stance',
      ]);
    });

    test('the index on exercise_equipment(equipment_id) exists', () {
      expect(
        collapseSql(v8Sql['idx_exercise_equipment_equipment']!),
        'CREATE INDEX idx_exercise_equipment_equipment ON exercise_equipment '
        '(equipment_id)',
      );
    });
  });

  group('not connected', () {
    test('opening a v7 database with AppDatabaseV8 refuses to migrate and '
        'leaves the file at v7', () async {
      final dir = Directory.systemTemp.createTempSync('repforge_v8_3b2_');
      addTearDown(() => dir.deleteSync(recursive: true));
      final file = File('${dir.path}/v7.sqlite');
      final prod = v7.AppDatabase(NativeDatabase(file));
      await prod.customSelect('SELECT 1').get();
      await prod.close();
      final before = file.readAsBytesSync();

      final v8 = AppDatabaseV8(NativeDatabase(file));
      await expectLater(
        v8.customSelect('SELECT 1').get(),
        throwsA(isA<UnsupportedError>()),
      );
      await v8.close();

      expect(file.readAsBytesSync(), before);
      final raw = sqlite3.open(file.path, mode: OpenMode.readOnly);
      addTearDown(raw.close);
      expect(raw.select('PRAGMA user_version').first.values.first, 7);
    });
  });
}
