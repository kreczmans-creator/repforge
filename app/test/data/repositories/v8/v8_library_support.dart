import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:repforge/data/repositories/v8/drift_library_repository_v8.dart';
import 'package:repforge/data/repositories/v8/drift_migration_report_repository_v8.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/library/sha256_hex.dart';
import 'package:sqlite3/sqlite3.dart';

import '../../../migration_v8/migration_digest.dart' as digest;
import '../../../migration_v8/v8_migration_support.dart'
    show appVersion, copyFixture, installLabel, openV8, testConfig;

/// Shared fixture of the WP 8 sub-stage 3b-8 tests: the frozen v7 fixture
/// with a little legacy work added **before** migration, migrated to v8 by
/// the real 3b-4 step (`AppDatabaseV8` with a `V8MigrationConfig`).
///
/// The v7 fixture already holds the blocked exercises of the 3b-4 scenarios:
/// `ex-rotator` (noPrimaryTarget and unknownEquipment: two reasons, R-01),
/// `ex-empty` and `ex-neck` (noPrimaryTarget), `ex-garbage`
/// (invalidEquipment), `ex-dup` (unknownEquipment). Added here, in v7:
/// - legacy history of blocked exercises: session `sess-legacy` with entries
///   and sets of `ex-rotator` and `ex-empty`, and plan entries listing them;
/// - plan `plan-wp9` mixing usable and blocked exercises, and a planned
///   scheduled workout `sw-wp9` for it, for the WP 9 contract test.
abstract final class V8LibraryFixture {
  /// The time of the 3b-8 tests (after the migration time of the 3b-4
  /// support, 2026-11-06T12:00Z).
  static final DateTime now = DateTime.utc(2026, 11, 7, 9);
  static final Clock clock = FixedClock(now);

  /// The plan with usable and blocked exercises, in plan order.
  static const String planId = 'plan-wp9';
  static const List<String> planOrder = [
    'lib-back-squat',
    'ex-rotator',
    'ex-row',
    'ex-empty',
    'ex-squat',
    'ex-garbage',
    'ex-row',
  ];
  static const String scheduledId = 'sw-wp9';
  static const String legacySession = 'sess-legacy';

  /// Exercises blocked by the migration of the fixture, with their reasons.
  static const Map<String, Set<String>> blocked = {
    'ex-rotator': {'noPrimaryTarget', 'unknownEquipment'},
    'ex-empty': {'noPrimaryTarget'},
    'ex-neck': {'noPrimaryTarget'},
    'ex-garbage': {'invalidEquipment'},
    'ex-dup': {'unknownEquipment'},
  };

  /// Adds the legacy work to a v7 database file.
  static void addLegacyWork(File v7File) {
    final db = sqlite3.open(v7File.path);
    try {
      const t = '2026-01-10T07:00:00.000Z';
      db
        ..execute(
          'INSERT INTO workout_plans (id, created_at, updated_at, deleted_at, '
          'name, split, scheduled_weekdays_json, archived) VALUES '
          "(?, ?, ?, NULL, 'Blocked mix', NULL, '[]', 0)",
          [planId, t, t],
        )
        ..execute(
          'INSERT INTO scheduled_workouts (id, created_at, updated_at, '
          'deleted_at, day, source_day, plan_id, origin, status, session_id) '
          "VALUES (?, ?, ?, NULL, '2026-11-07', '2026-11-07', ?, 'date', "
          "'planned', NULL)",
          [scheduledId, t, t, planId],
        );
      for (var i = 0; i < planOrder.length; i++) {
        db.execute(
          'INSERT INTO plan_exercises (id, plan_id, exercise_id, sort_order, '
          'target_sets, reps_min, reps_max, target_load_kg, '
          'target_duration_sec, target_metres, rest_seconds) VALUES '
          '(?, ?, ?, ?, ?, ?, ?, ?, NULL, NULL, ?)',
          [
            'pe-wp9-$i',
            planId,
            planOrder[i],
            i,
            3 + i % 2,
            5 + i,
            8 + i,
            if (i.isEven) 40.0 + i else null,
            90,
          ],
        );
      }
      db
        ..execute(
          'INSERT INTO workout_sessions (id, created_at, updated_at, '
          'deleted_at, name, plan_id, started_at, ended_at, notes) VALUES '
          "(?, ?, ?, NULL, 'Legacy blocked work', NULL, ?, ?, 'old notes')",
          [legacySession, t, t, t, '2026-01-10T08:00:00.000Z'],
        )
        ..execute(
          'INSERT INTO session_exercises (id, session_id, position, '
          "exercise_id, note) VALUES ('se-leg-1', ?, 0, 'ex-rotator', "
          "'band at hip height'), ('se-leg-2', ?, 1, 'ex-empty', NULL)",
          [legacySession, legacySession],
        );
      final sets = [
        ('set-leg-1', 'ex-rotator', 0, 0, 7.5, 12, 'se-leg-1', 'rir', 2.0),
        ('set-leg-2', 'ex-rotator', 0, 1, 7.5, 10, 'se-leg-1', null, null),
        ('set-leg-3', 'ex-empty', 1, 0, null, 15, 'se-leg-2', 'rpe', 7.5),
      ];
      for (final (id, ex, eo, so, load, reps, entry, scale, value) in sets) {
        db.execute(
          'INSERT INTO session_sets (id, session_id, exercise_id, '
          'exercise_order, set_order, type, load_kg, reps, completed, '
          'exertion_scale, exertion_value, set_kind, session_exercise_id) '
          'VALUES (?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?, ?, ?)',
          [
            id,
            legacySession,
            ex,
            eo,
            so,
            if (load == null) 'bodyweight' else 'weighted',
            load,
            reps,
            scale,
            value,
            'working',
            entry,
          ],
        );
      }
    } finally {
      db.close();
    }
  }

  static File? _template;
  static File? _v7Template;
  static Directory? _dir;

  /// The v7 fixture with the legacy work (never migrated).
  static File v7Template() {
    _prepare();
    return _v7Template!;
  }

  /// The migrated v8 template (built once per test process).
  static Future<File> template() async {
    _prepare();
    if (_template != null) return _template!;
    final file = File('${_dir!.path}/v8_template.sqlite');
    _v7Template!.copySync(file.path);
    final error = await openV8(file, config: testConfig());
    if (error != null) throw StateError('v8 migration failed: $error');
    return _template = file;
  }

  static void _prepare() {
    if (_dir != null) return;
    driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
    _dir = Directory.systemTemp.createTempSync('repforge_v8_3b8_');
    final v7 = copyFixture(digest.fixturePath(7), _dir!, 'v7_template.sqlite');
    addLegacyWork(v7);
    _v7Template = v7;
  }

  /// Deletes the templates (call from `tearDownAll`).
  static void dispose() {
    _dir?.deleteSync(recursive: true);
    _dir = null;
    _template = null;
    _v7Template = null;
  }
}

/// An open, migrated v8 copy with its repositories.
final class V8LibraryHarness {
  V8LibraryHarness._(this.dir, this.file, this.db) {
    var n = 0;
    library = DriftLibraryRepositoryV8(
      db,
      clock: V8LibraryFixture.clock,
      newId: () => 'new-${++n}',
      appVersion: appVersion,
      installLabel: installLabel,
    );
    report = DriftMigrationReportRepositoryV8(
      db,
      clock: V8LibraryFixture.clock,
    );
  }

  static Future<V8LibraryHarness> open() async {
    final template = await V8LibraryFixture.template();
    final dir = Directory.systemTemp.createTempSync('repforge_v8_3b8_case_');
    final file = template.copySync('${dir.path}/db.sqlite');
    return V8LibraryHarness._(dir, file, AppDatabaseV8(NativeDatabase(file)));
  }

  final Directory dir;
  final File file;
  final AppDatabaseV8 db;
  late final DriftLibraryRepositoryV8 library;
  late final DriftMigrationReportRepositoryV8 report;

  Future<void> close() async {
    await db.close();
    dir.deleteSync(recursive: true);
  }

  /// Every row of [table] as typed JSON (storage types distinguished),
  /// in key order.
  Future<List<String>> rowsOf(String table, {String orderBy = 'rowid'}) async {
    final rows = await db
        .customSelect('SELECT * FROM "$table" ORDER BY $orderBy')
        .get();
    return [
      for (final r in rows)
        jsonEncode({
          for (final MapEntry(:key, :value) in r.data.entries)
            key: switch (value) {
              null => null,
              final int i => 'int:$i',
              final double d => 'real:$d',
              final String s => 'text:$s',
              _ => 'other:$value',
            },
        }),
    ];
  }

  /// One SHA-256 digest per row of every plan, session, entry, set,
  /// schedule and split table, keyed by table and row: the "history digest"
  /// a correction must leave unchanged.
  Future<Map<String, String>> historyDigests() async {
    final out = <String, String>{};
    for (final table in historyTables) {
      final rows = await rowsOf(table);
      for (var i = 0; i < rows.length; i++) {
        out['$table#$i'] = sha256Hex(utf8.encode(rows[i]));
      }
      out['$table#count'] = '${rows.length}';
    }
    return out;
  }

  /// Rows of [table] whose `exercise_id` is [exerciseId].
  Future<int> countFor(String table, String exerciseId) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM "$table" WHERE exercise_id = ?',
                variables: [Variable<String>(exerciseId)],
              )
              .getSingle())
          .read<int>('n');

  /// Row count of every table, for "nothing written" checks.
  Future<Map<String, int>> tableCounts() async {
    final names = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name NOT LIKE 'sqlite_%' ORDER BY name",
        )
        .get();
    return {
      for (final n in names)
        n.read<String>('name'):
            (await db
                    .customSelect(
                      'SELECT COUNT(*) AS c FROM "${n.read<String>('name')}"',
                    )
                    .getSingle())
                .read<int>('c'),
    };
  }

  /// A full, typed dump of every table: equal dumps mean nothing was
  /// written.
  Future<Map<String, List<String>>> dump() async {
    final names = (await tableCounts()).keys;
    return {for (final n in names) n: await rowsOf(n)};
  }
}

/// The tables whose rows make up workout and session history.
const historyTables = [
  'workout_plans',
  'plan_exercises',
  'workout_sessions',
  'session_exercises',
  'session_sets',
  'scheduled_workouts',
  'training_splits',
  'split_days',
];
