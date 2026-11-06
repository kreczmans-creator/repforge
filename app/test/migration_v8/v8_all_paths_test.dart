import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:repforge/domain/library/preserved_ids.dart';
import 'package:sqlite3/sqlite3.dart';

import 'harness_v7_db.dart' show strictSchema;
import 'migration_digest.dart' as digest;
import 'v8_migration_support.dart';

/// WP 8 sub-stage 3b-4 (and the 3b-5 path evidence on the frozen fixtures):
/// every frozen fixture v1..v7 and every orphan fixture migrates to v8
/// through `AppDatabaseV8` (the historical steps, then the v7 → v8 step).
///
/// For each fixture, against expectations computed independently from its
/// v7 state with the WS4 contract (`v8_migration_support.dart`):
/// - the schema equals a fresh `AppDatabaseV8` (strict normaliser, PRAGMA
///   `table_info`, `foreign_key_list`, `index_list`, CHECK clauses, triggers
///   and views, and drift's own `validateDatabaseSchema`);
/// - every retained column of every row equals its v7 value; unchanged
///   tables are equal row for row;
/// - targets, equipment links, blocks, quarantine rows, report entries,
///   report counts, run rows and the release record equal the expectation;
/// - the reference tables hold the bootstrap and nothing invented;
/// - a full `foreign_key_check` finds exactly the v7 findings (keyed by
///   primary key) and `integrity_check` is ok;
/// - the stored report reconciles;
/// - blocked exercises keep their row, sets, sessions and plans.
void main() {
  late FreshSchema fresh;
  setUpAll(() async => fresh = await FreshSchema.open());

  for (final (key, path) in digest.allFixtures()) {
    group('$key → v8', () {
      late Directory dir;
      late File migrated;
      late V8Expectation x;
      late DbState s;
      late Object? error;

      setUpAll(() async {
        dir = Directory.systemTemp.createTempSync(v8TempPrefix);
        final v7 = await v7Copy(path, dir);
        x = V8Expectation.of(v7, runId: 'run-1');
        migrated = copyFixture(path, dir);
        error = await openV8(migrated);
        s = DbState.read(migrated);
      });
      tearDownAll(() => dir.deleteSync(recursive: true));

      test('migrates to user_version 8', () {
        expect(error, isNull);
        expect(s.userVersion, 8);
      });

      test('schema equals a fresh AppDatabaseV8 (strict, PRAGMAs, CHECKs, '
          'triggers, drift validation)', () async {
        final raw = sqlite3.open(migrated.path, mode: OpenMode.readOnly);
        try {
          expect(strictSchema(raw), fresh.strict);
          expect(
            jsonEncode(digest.describeSchema(raw)),
            jsonEncode(fresh.described),
          );
        } finally {
          raw.close();
        }
        final db = AppDatabaseV8(NativeDatabase(migrated));
        try {
          await db.validateDatabaseSchema();
        } finally {
          await db.close();
        }
      });

      test('unchanged tables are equal row for row', () {
        for (final table in x.v7.tables.keys) {
          if (const {
            'exercises',
            'session_sets',
            'legacy_quarantine',
          }.contains(table)) {
            continue;
          }
          final cols = x.v7.columns[table]!;
          expect(s.columns[table], cols, reason: table);
          expect(
            [for (final r in s.rows(table)) typedRow(r, cols)],
            [for (final r in x.v7.rows(table)) typedRow(r, cols)],
            reason: table,
          );
        }
      });

      test('exercises: retained columns equal, provenance from the mapping, '
          'legacy columns gone, new columns NULL', () {
        final before = x.v7.rows('exercises');
        final after = s.rows('exercises');
        expect(after.length, before.length);
        for (final c in droppedExerciseColumns) {
          expect(s.columns['exercises'], isNot(contains(c)));
        }
        for (var i = 0; i < before.length; i++) {
          final b = before[i];
          final a = after[i];
          expect(
            typedRow(a, retainedExerciseColumns),
            typedRow(b, retainedExerciseColumns),
          );
          final m = x.mappings[b['id']]!;
          expect(a['source'], m.source.name);
          expect(a['provider_id'], m.providerId?.value);
          expect(a['revision'], m.revision);
          expect(a['source'], b['supplied'] == 1 ? 'system' : 'user');
          for (final c in nullNewExerciseColumns) {
            expect(a[c], isNull, reason: '${b['id']}.$c');
          }
        }
      });

      test('session_sets: every column equal; only offending exertion pairs '
          'cleared (TRN-020)', () {
        final before = x.v7.rows('session_sets');
        final after = s.rows('session_sets');
        expect(after.length, before.length);
        final cols = x.v7.columns['session_sets']!;
        expect(s.columns['session_sets'], cols);
        for (var i = 0; i < before.length; i++) {
          final b = Map<String, Object?>.of(before[i]);
          if (!x.classifications[b['id']]!.isValid) {
            b['exertion_scale'] = null;
            b['exertion_value'] = null;
          }
          expect(typedRow(after[i], cols), typedRow(b, cols));
        }
      });

      test('legacy_quarantine: v7 rows unchanged; new rows equal the '
          'expected originals, in order', () {
        final before = x.v7.rows('legacy_quarantine');
        final after = s.rows('legacy_quarantine');
        final cols = x.v7.columns['legacy_quarantine'] ?? const <String>[];
        expect(
          [for (final r in after.take(before.length)) typedRow(r, cols)],
          [for (final r in before) typedRow(r, cols)],
        );
        final added = after.skip(before.length).toList();
        expect(added.length, x.newQuarantine.length);
        for (var i = 0; i < added.length; i++) {
          final want = x.newQuarantine[i];
          expect(typedRow(added[i], want.keys), typedRow(want, want.keys));
        }
        final v7Ids = {for (final r in before) r['id']};
        expect([
          for (final r in added) r['id'],
        ], (x.quarantineIds.values.toSet()..removeAll(v7Ids)).toList()..sort());
      });

      test('targets, equipment links and blocks equal the mapping', () {
        expect(
          [
            for (final r in s.rows('exercise_targets'))
              [
                r['exercise_id'],
                r['node_id'],
                r['role'],
                r['ordinal'],
              ].join('|'),
          ]..sort(),
          x.targets.toList()..sort(),
        );
        expect(
          [
            for (final r in s.rows('exercise_equipment'))
              [
                r['exercise_id'],
                r['equipment_id'],
                r['ordinal'],
                r['role_override'],
                r['override_note'],
              ].join('|'),
          ]..sort(),
          x.equipment.toList()..sort(),
        );
        expect(
          [
            for (final r in s.rows('exercise_blocks'))
              [
                r['exercise_id'],
                r['reason'],
                r['original_json'],
                r['blocked_at'],
                r['resolved_at'],
              ].join('|'),
          ]..sort(),
          x.blocks.toList()..sort(),
        );
        for (final t in ['exercise_patterns', 'exercise_names']) {
          expect(s.rows(t), isEmpty, reason: t);
        }
        expect(s.rows('exercise_user_state'), isEmpty);
      });

      test('report entries of both runs equal the expectation', () {
        final stored = storedEntries(s);
        expect(stored.keys.toSet(), x.entries.keys.toSet());
        for (final MapEntry(:key, :value) in x.entries.entries) {
          final got = stored[key]!;
          expect(
            {for (final c in value.keys) c: typed(got[c])},
            {for (final c in value.keys) c: typed(value[c])},
            reason: key,
          );
        }
      });

      test('report counts of both runs equal the expectation', () {
        expect(storedCounts(s, 'run-1'), x.counts);
        expect(storedCounts(s, 'run-1:integrity'), x.integrityCounts);
      });

      test('the stored report reconciles (R-04, M1, R-07)', () {
        final entries = s.rows('migration_report_entries');
        for (final runId in ['run-1', 'run-1:integrity']) {
          final counts = storedCounts(s, runId);
          final tables = {for (final k in counts.keys) k.split('|').first};
          for (final t in tables) {
            final outcomes = [
              for (final o in ReportCategory.outcomes)
                counts['$t|category|${o.code}']!,
            ].fold(0, (a, b) => a + b);
            expect(outcomes, counts['$t|category|examined'], reason: t);
            for (final a in ReportAction.values) {
              expect(
                entries
                    .where(
                      (e) =>
                          e['run_id'] == runId &&
                          e['source_table'] == t &&
                          e['disposition'] == a.name,
                    )
                    .length,
                counts['$t|disposition|${a.name}'],
                reason: '$runId $t ${a.name}',
              );
            }
          }
        }
        // Examined equals the input, counted independently.
        final c = storedCounts(s, 'run-1');
        for (final t in ['exercises', 'session_sets', 'legacy_quarantine']) {
          final n = x.v7.rows(t).length;
          expect(c['$t|category|examined'], n == 0 ? isNull : n, reason: t);
        }
        for (final e in entries) {
          expect(
            e['event_id'],
            migrationEventId(
              runId: e['run_id']! as String,
              table: e['source_table']! as String,
              recordId: e['record_id']! as String,
              field: e['field']! as String,
              position: e['position'] as int?,
              rule: e['rule']! as String,
            ),
          );
          expect(e['resulting_value'], isNotNull);
        }
      });

      test('run rows and the release record', () {
        expect(s.rows('migration_runs'), [
          {
            'id': 'run-1',
            'trigger_kind': 'migration',
            'from_version': 7,
            'to_version': 8,
            'generated_at': v8Stamp,
            'app_version': appVersion,
            'provenance_kind': 'device',
            'provenance_source': installLabel,
            'merged_at': null,
          },
          {
            'id': 'run-1:integrity',
            'trigger_kind': 'integrityCheck',
            'from_version': null,
            'to_version': null,
            'generated_at': v8Stamp,
            'app_version': appVersion,
            'provenance_kind': 'device',
            'provenance_source': installLabel,
            'merged_at': null,
          },
        ]);
        expect(s.rows('catalogue_releases'), [?x.release]);
      });

      test('reference tables hold the bootstrap and nothing invented', () {
        for (final t in [
          'content_providers',
          'anatomy_nodes',
          'equipment_items',
          'movement_patterns',
          'reference_labels',
          'exercise_names',
        ]) {
          expect(s.rows(t), fresh.state.rows(t), reason: t);
        }
        final nodes = {for (final n in preservedMuscleNodes) n.id.value};
        final items = {for (final e in existingEquipmentIds) e.value};
        for (final r in s.rows('exercise_targets')) {
          expect(nodes, contains(r['node_id']));
        }
        for (final r in s.rows('exercise_equipment')) {
          expect(items, contains(r['equipment_id']));
        }
      });

      test('foreign keys and integrity: exactly the v7 findings remain '
          '(pre-existing damage never blocks); integrity_check ok', () {
        expect(findingKeys(migrated), x.findings.keys.toSet());
        final raw = sqlite3.open(migrated.path, mode: OpenMode.readOnly);
        try {
          expect(digest.integrityCheck(raw), 'ok');
          expect(
            raw.select('PRAGMA foreign_key_check').length,
            x.findings.values
                .where((f) => f.rule == 'foreign_key_check')
                .length,
          );
        } finally {
          raw.close();
        }
        if (key.endsWith('_orphans')) {
          expect(x.findings, isNotEmpty);
          expect(
            s
                .rows('migration_report_entries')
                .where((e) => e['run_id'] == 'run-1:integrity'),
            hasLength(x.findings.length),
          );
        }
      });

      test('blocked exercises keep their row, sets, sessions and plans', () {
        final blocked = {
          for (final r in s.rows('exercise_blocks')) r['exercise_id'],
        };
        if (key == 'v7' || key == 'v6') expect(blocked, isNotEmpty);
        final exercises = s.byId('exercises');
        for (final id in blocked) {
          expect(exercises, contains(id));
          for (final t in [
            'session_sets',
            'session_exercises',
            'plan_exercises',
          ]) {
            final cols = x.v7.columns[t]!.where(
              (c) => !const {'exertion_scale', 'exertion_value'}.contains(c),
            );
            expect(
              [
                for (final r in s.rows(t))
                  if (r['exercise_id'] == id) typedRow(r, cols),
              ],
              [
                for (final r in x.v7.rows(t))
                  if (r['exercise_id'] == id) typedRow(r, cols),
              ],
              reason: '$t of $id',
            );
          }
        }
      });
    });
  }
}

/// The schema and rows of a fresh `AppDatabaseV8`.
final class FreshSchema {
  FreshSchema._(this.strict, this.described, this.state);

  static Future<FreshSchema> open() async {
    final raw = sqlite3.openInMemory();
    final db = AppDatabaseV8(NativeDatabase.opened(raw));
    try {
      await db.customSelect('SELECT 1').get();
      return FreshSchema._(
        strictSchema(raw),
        digest.describeSchema(raw),
        DbState.of(raw),
      );
    } finally {
      await db.close();
    }
  }

  final List<String> strict;
  final Map<String, Object?> described;
  final DbState state;
}
