import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart'
    show DatabaseConnectionUser, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:repforge/data/db/migration/repforge_migration.dart';
import 'package:repforge/data/db/migration/v7_to_v8.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/library/integrity_preflight.dart';
import 'package:repforge/domain/library/legacy_v8_mapping.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:sqlite3/sqlite3.dart';

import 'harness_v7_db.dart';
import 'migration_digest.dart' as digest;

/// Test support for WP 8 sub-stage 3b-4 (the v7 → v8 step).
///
/// Expectations are computed here **independently of the migration code**:
/// from the v7 state of each database and the WS4 contract
/// (`mapLegacyExercise`, `classifyLegacyExertion`, `MigrationReportBuilder`,
/// `migrationEventId`), with the foreign-key and reference findings taken
/// by SQL of their own. Nothing here calls `V7ToV8Migration` to predict its
/// output.

/// Prefix of the temporary directories made by the 3b-4 tests.
const v8TempPrefix = 'repforge_v8_3b4_';

/// Fixed clock of the v8 tests: the same instant as the 3b-3 harness, so
/// the chain stamps quarantine rows exactly as `HarnessV7Database` does.
final v8Clock = FixedClock(DateTime.utc(2026, 11, 6, 12));

/// The instant of [v8Clock] as stored.
const v8Stamp = '2026-11-06T12:00:00.000Z';

const appVersion = '0.8.0-test';
const installLabel = 'install-3b4-test';

/// The bundled seed, as the app ships it.
const seedPath = 'assets/seed/exercise_library.json';

/// The v7-era seed hash, pinned independently of the migration code (the
/// SHA-256 of `app/assets/seed/exercise_library.json` at commit df326db,
/// the only seed any v7 install applied; R-30 option b).
const v7SeedSha256Pin =
    '839d9ca28f043e61ed502b4bf765ca1ff8110fc21b54e84d98014c3b8d5e0b22';

List<int> seedBytes() => File(seedPath).readAsBytesSync();

/// A run id generator that counts: `run-1`, `run-2`, ...
String Function() countingRunIds([String prefix = 'run']) {
  var n = 0;
  return () => '$prefix-${++n}';
}

V8MigrationConfig testConfig({
  MigrationRunLedger? ledger,
  String Function()? newRunId,
  Future<QuickCheckResult> Function(DatabaseConnectionUser db)? quickCheck,
  LegacyExerciseMapper? mapExercise,
  String Function(File file)? fingerprint,
  Future<List<int>> Function()? loadSeedBytes,
  Clock? clock,
  String version = appVersion,
}) => V8MigrationConfig.forTesting(
  clock: clock ?? v8Clock,
  appVersion: version,
  installLabel: installLabel,
  loadSeedBytes: loadSeedBytes ?? () async => seedBytes(),
  runLedger: ledger ?? InMemoryMigrationRunLedger(),
  newRunId: newRunId ?? () => 'run-1',
  quickCheck: quickCheck,
  mapExercise: mapExercise ?? mapLegacyExercise,
  fingerprint: fingerprint ?? V7ToV8Migration.fileFingerprint,
);

/// The ledger key of the database [file] (its canonical path).
String ledgerKeyOf(File file) => file.resolveSymbolicLinksSync();

/// A temporary directory deleted after [body].
Future<T> inTempDir<T>(Future<T> Function(Directory dir) body) async {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final dir = Directory.systemTemp.createTempSync(v8TempPrefix);
  try {
    return await body(dir);
  } finally {
    dir.deleteSync(recursive: true);
  }
}

/// Copies [fixture] into [dir] as [name].
File copyFixture(String fixture, Directory dir, [String name = 'db.sqlite']) =>
    File(fixture).copySync('${dir.path}/$name');

/// Opens [file] with a configured [AppDatabaseV8] (which runs the chain),
/// closes it and returns the error, if any.
Future<Object?> openV8(
  File file, {
  V8MigrationConfig? config,
  MigrationProbe? probe,
  V8PhaseProbe? phaseProbe,
}) async {
  final db = AppDatabaseV8(
    NativeDatabase(file),
    migrationConfig: config ?? testConfig(),
    probe: probe,
    phaseProbe: phaseProbe,
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

/// A copy of [fixture] in [dir] migrated to v7 by the frozen 3b-3 chain:
/// exactly the state the v7 → v8 step starts from.
Future<File> v7Copy(String fixture, Directory dir) async {
  final file = copyFixture(fixture, dir, 'v7.sqlite');
  final error = await openWithChain(file);
  if (error != null) throw StateError('v7 chain failed: $error');
  return file;
}

// ---- Reading a database ----------------------------------------------------

/// Every row of every user table of a database, by table, in primary-key
/// order (rowid order for tables without one).
final class DbState {
  DbState._(this.userVersion, this.tables, this.columns);

  factory DbState.read(File file) {
    final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
    try {
      return DbState.of(db);
    } finally {
      db.close();
    }
  }

  factory DbState.of(Database db) {
    final tables = <String, List<Map<String, Object?>>>{};
    final columns = <String, List<String>>{};
    for (final t in db.select(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    )) {
      final name = t['name']! as String;
      final info = db.select('PRAGMA table_info("$name")');
      columns[name] = [for (final c in info) c['name']! as String];
      final pk = [
        for (final c in info)
          if ((c['pk']! as int) > 0) c,
      ]..sort((a, b) => (a['pk']! as int).compareTo(b['pk']! as int));
      final order = pk.isEmpty
          ? 'rowid'
          : pk.map((c) => '"${c['name']}"').join(', ');
      tables[name] = [
        for (final r in db.select('SELECT * FROM "$name" ORDER BY $order'))
          Map<String, Object?>.of(r),
      ];
    }
    return DbState._(digest.userVersion(db), tables, columns);
  }

  final int userVersion;
  final Map<String, List<Map<String, Object?>>> tables;
  final Map<String, List<String>> columns;

  List<Map<String, Object?>> rows(String table) => tables[table] ?? const [];

  Map<String, Map<String, Object?>> byId(String table) => {
    for (final r in rows(table)) '${r['id']}': r,
  };
}

/// A stored cell with its storage type, so INTEGER 7 and REAL 7.0 differ.
String typed(Object? v) => switch (v) {
  null => 'null',
  final int i => 'int:$i',
  final double d => 'real:$d',
  final String s => 'text:${jsonEncode(s)}',
  final Uint8List b => 'blob:${base64Encode(b)}',
  _ => 'other:$v',
};

/// [row] restricted to [cols], each cell [typed].
Map<String, String> typedRow(Map<String, Object?> row, Iterable<String> cols) =>
    {for (final c in cols) c: typed(row[c])};

// ---- Independent expectations ---------------------------------------------

/// The columns of v7 `exercises` that v8 keeps unchanged.
const retainedExerciseColumns = [
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
];

/// The v7 columns that v8 drops from `exercises`.
const droppedExerciseColumns = [
  'primary_muscle',
  'secondary_muscles_json',
  'equipment_json',
  'supplied',
];

/// New v8 columns of `exercises` that the migration leaves NULL.
const nullNewExerciseColumns = [
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
];

/// One foreign-key violation or unresolved exercise reference, found by the
/// test's own SQL.
typedef Finding = ({
  String table,
  String recordId,
  String column,
  Object? value,
  String parent,
  String rule,
  String? exerciseId,
});

String findingKey(Finding f) =>
    '${f.table}|${f.recordId}|${f.column}|${f.parent}|${f.rule}';

/// The record id of [row]: its primary key as text (JSON array if composite).
String recordIdOf(Database db, String table, Map<String, Object?> row) {
  final pk = pkColumns(db, table);
  return pk.length == 1
      ? '${row[pk.single]}'
      : jsonEncode([for (final c in pk) row[c]]);
}

List<String> pkColumns(Database db, String table) {
  final pk = [
    for (final c in db.select('PRAGMA table_info("$table")'))
      if ((c['pk']! as int) > 0) c,
  ]..sort((a, b) => (a['pk']! as int).compareTo(b['pk']! as int));
  return pk.isEmpty ? ['rowid'] : [for (final c in pk) c['name']! as String];
}

bool hasColumn(Database db, String table, String column) =>
    db.select('PRAGMA table_info("$table")').any((r) => r['name'] == column);

/// Every foreign-key violation (`PRAGMA foreign_key_check`, the whole
/// database) and every unresolved exercise reference (IC-901 to IC-903) of
/// [db], keyed by primary key.
Map<String, Finding> findingsOf(Database db) {
  final out = <String, Finding>{};
  for (final v in db.select('PRAGMA foreign_key_check')) {
    final table = v['table']! as String;
    final fk = [
      for (final f in db.select('PRAGMA foreign_key_list("$table")'))
        if (f['id'] == v['fkid']) f['from']! as String,
    ];
    final row = Map<String, Object?>.of(
      db.select('SELECT rowid, * FROM "$table" WHERE rowid = ?', [
        v['rowid'],
      ]).single,
    );
    final id = recordIdOf(db, table, row);
    final f = (
      table: table,
      recordId: id,
      column: fk.join(','),
      value: row[fk.single],
      parent: v['parent']! as String,
      rule: 'foreign_key_check',
      exerciseId: table == 'exercises'
          ? id
          : (hasColumn(db, table, 'exercise_id')
                ? row['exercise_id'] as String?
                : null),
    );
    out[findingKey(f)] = f;
  }
  const loose = [
    ('session_sets', 'exercise_id', 'IC-901'),
    ('session_exercises', 'exercise_id', 'IC-901'),
    ('plan_exercises', 'exercise_id', 'IC-902'),
    ('exercise_user_state', 'exercise_id', 'IC-902'),
    ('exercises', 'copied_from_id', 'IC-903'),
  ];
  final exerciseIds = {
    for (final r in db.select('SELECT id FROM exercises')) r['id'],
  };
  for (final (table, column, rule) in loose) {
    if (!hasColumn(db, table, column)) continue;
    for (final r in db.select('SELECT * FROM "$table"')) {
      final ref = r[column];
      if (ref == null || exerciseIds.contains(ref)) continue;
      final row = Map<String, Object?>.of(r);
      final id = recordIdOf(db, table, row);
      final f = (
        table: table,
        recordId: id,
        column: column,
        value: ref,
        parent: 'exercises',
        rule: rule,
        exerciseId: table == 'exercises' ? id : ref as String?,
      );
      out[findingKey(f)] = f;
    }
  }
  return out;
}

/// Findings of the database [file].
Map<String, Finding> findingsOfFile(File file) {
  final db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  try {
    return findingsOf(db);
  } finally {
    db.close();
  }
}

/// A stored report entry, as compared by the tests.
typedef EntryRow = Map<String, Object?>;

EntryRow entryRow({
  required String runId,
  required ReportEvent e,
  required String? exerciseId,
  required int? quarantineId,
}) => {
  'event_id': migrationEventId(
    runId: runId,
    table: e.table,
    recordId: e.recordId,
    field: e.field,
    position: e.position,
    rule: e.rule,
  ),
  'run_id': runId,
  'source_table': e.table,
  'record_id': e.recordId,
  'exercise_id': exerciseId,
  'field': e.field,
  'position': e.position,
  'original_value': e.originalValue,
  'resulting_value': e.resultingValue ?? 'null',
  'element': e.element,
  'disposition': e.action.name,
  'block_reason': e.blockReason?.name,
  'rule': e.rule,
  'reason': e.reason,
  'category': e.category.code,
  'quarantine_id': quarantineId,
  'acknowledged_at': null,
};

/// The counts rows of [report] as `table|dimension|code` → count.
Map<String, int> countRows(MigrationReport report) => {
  for (final c in report.counts.values) ...{
    '${c.table}|category|examined': c.examined,
    for (final o in ReportCategory.outcomes)
      '${c.table}|category|${o.code}': c.count(o),
    '${c.table}|category|warningForReview': c.recordsWithWarnings,
    for (final a in ReportAction.values)
      '${c.table}|disposition|${a.name}': c.entries(a),
  },
};

/// Everything the v7 → v8 step must produce from [v7], computed with the
/// WS4 contract and the test's own SQL.
final class V8Expectation {
  V8Expectation._();

  /// Builds the expectation of migrating the v7 database [v7File] with run
  /// id [runId] (its integrity run is `<runId>:integrity`).
  factory V8Expectation.of(
    File v7File, {
    required String runId,
    List<int>? seed,
  }) {
    final x = V8Expectation._()..runId = runId;
    final db = sqlite3.open(v7File.path, mode: OpenMode.readOnly);
    try {
      x._build(db, seed ?? seedBytes());
    } finally {
      db.close();
    }
    return x;
  }

  late final String runId;
  String get integrityRunId => '$runId:integrity';

  late final DbState v7;
  final mappings = <String, LegacyExerciseMapping>{};
  final classifications = <String, ExertionClassification>{};

  /// New `legacy_quarantine` rows, in insertion order, without `id`.
  final newQuarantine = <Map<String, Object?>>[];

  /// `(table|record|field)` → id of the new quarantine row.
  final quarantineIds = <String, int>{};

  final targets = <String>[];
  final equipment = <String>[];
  final blocks = <String>[];
  final entries = <String, EntryRow>{};
  late final Map<String, int> counts;
  late final Map<String, int> integrityCounts;
  late final MigrationReport report;
  late final MigrationReport integrityReport;
  late final Map<String, Finding> findings;
  Map<String, Object?>? release;

  void _build(Database db, List<int> seed) {
    v7 = DbState.of(db);
    findings = findingsOf(db);
    var nextQuarantineId =
        (db
                .select(
                  'SELECT seq FROM sqlite_sequence '
                  "WHERE name = 'legacy_quarantine'",
                )
                .firstOrNull?['seq']
            as int?) ??
        0;
    void quarantine(QuarantineRequest q) {
      newQuarantine.add({
        'source_table': q.table,
        'row_id': q.recordId,
        'reason': q.reason,
        'original_json': q.originalJson,
        'quarantined_at': v8Stamp,
      });
      nextQuarantineId++;
      for (final f in q.original.keys) {
        quarantineIds['${q.table}|${q.recordId}|$f'] = nextQuarantineId;
      }
    }

    final builder = MigrationReportBuilder(
      ReportRun(
        runId: runId,
        trigger: ReportTrigger.migration,
        generatedAt: DateTime.parse(v8Stamp),
        appVersion: appVersion,
        fromSchemaVersion: 7,
        toSchemaVersion: 8,
      ),
    );
    final exerciseOf = <String, String>{};

    for (final r in v7.rows('exercises')) {
      final id = r['id']! as String;
      final m = mapLegacyExercise(
        LegacyExerciseRow(
          id: id,
          type: r['type'],
          category: r['category'],
          aliasesJson: r['aliases_json'],
          primaryMuscle: r['primary_muscle'],
          secondaryMusclesJson: r['secondary_muscles_json'],
          equipmentJson: r['equipment_json'],
          supplied: r['supplied'],
        ),
      );
      mappings[id] = m;
      m.quarantine.forEach(quarantine);
      for (final t in m.targets) {
        targets.add('$id|${t.node.value}|${t.role.name}|${t.ordinal}');
      }
      for (final e in m.equipment) {
        equipment.add('$id|${e.item.value}|${e.ordinal}|null|null');
      }
      for (final b in m.blocks) {
        final original = switch (b.reason) {
          BlockReason.noPrimaryTarget || BlockReason.invalidSecondaryTarget => {
            'primary_muscle': r['primary_muscle'],
            'secondary_muscles_json': r['secondary_muscles_json'],
          },
          BlockReason.unknownEquipment || BlockReason.invalidEquipment => {
            'equipment_json': r['equipment_json'],
          },
          BlockReason.invalidClassification => {
            'type': r['type'],
            'category': r['category'],
          },
          BlockReason.invalidAliases => {'aliases_json': r['aliases_json']},
        };
        blocks.add(
          '$id|${b.reason.name}|${encodeStoredRow(original)}|$v8Stamp|null',
        );
      }
      exerciseOf['exercises|$id'] = id;
      builder.examine(
        table: 'exercises',
        recordId: id,
        cleanOutcome: ReportCategory.migrated,
        events: m.events,
      );
    }
    for (final r in v7.rows('session_sets')) {
      final id = r['id']! as String;
      final c = classifyLegacyExertion(
        setId: id,
        scale: r['exertion_scale'],
        value: r['exertion_value'],
      );
      classifications[id] = c;
      if (c.quarantine case final q?) quarantine(q);
      exerciseOf['session_sets|$id'] = r['exercise_id']! as String;
      builder.examine(
        table: 'session_sets',
        recordId: id,
        cleanOutcome: ReportCategory.preserved,
        events: c.events,
      );
    }
    for (final r in v7.rows('legacy_quarantine')) {
      final id = '${r['id']}';
      quarantineIds['legacy_quarantine|$id|original_json'] = r['id']! as int;
      if (r['source_table'] == 'exercises') {
        exerciseOf['legacy_quarantine|$id'] = r['row_id']! as String;
      }
      builder.examine(
        table: 'legacy_quarantine',
        recordId: id,
        cleanOutcome: ReportCategory.preserved,
        events: [
          // R-33: retained, preserved, never this run's quarantine.
          ReportEvent(
            table: 'legacy_quarantine',
            recordId: id,
            field: 'original_json',
            originalValue: encodeStoredValue(r['original_json']),
            resultingValue: 'null',
            action: ReportAction.retained,
            rule: 'WP8-D3',
            category: ReportCategory.preserved,
            reason:
                'Quarantined before schema v8 from ${r['source_table']} '
                'record ${r['row_id']} (${r['reason']}); retained unchanged '
                'in legacy_quarantine and not counted as quarantined by this '
                'run (R-33).',
          ),
        ],
      );
    }
    // Release 1 (plan section 6 step 9; R-10; R-30 option b): the seed
    // setting is examined whenever it exists; release 1 only when the seed
    // applied and the bytes hash to the pinned v7-era value.
    final seedSetting = v7
        .rows('settings')
        .where((r) => r['key'] == 'seedExercisesVersion');
    if (seedSetting.isNotEmpty) {
      final setting = seedSetting.single;
      final applied = (int.tryParse('${setting['value']}') ?? 0) >= 1;
      final hash = digest.sha256Hex(seed);
      ReportEvent? warning;
      if (applied && hash == v7SeedSha256Pin) {
        release = {
          'provider_id': 'repforge',
          'release': 1,
          'applied_at': setting['updated_at'],
          'applied_at_source': 'seedExercisesVersion.updated_at',
          'content_hash_algorithm': 'sha256',
          'content_hash_encoding': 'hex-lower',
          'content_hash': hash,
          'inserted': null,
          'updated': null,
          'retired': null,
          'app_version': null,
        };
      } else if (applied) {
        warning = ReportEvent(
          table: 'settings',
          recordId: 'seedExercisesVersion',
          field: 'value',
          originalValue: encodeStoredValue(setting['value']),
          resultingValue: encodeStoredValue(setting['value']),
          action: ReportAction.none,
          rule: 'R-30',
          category: ReportCategory.warningForReview,
          reason:
              'The v7 seed was applied, but the bundled seed hashes to '
              '$hash, not the v7-era release 1 hash $v7SeedSha256Pin. No '
              'release 1 record is created (R-30); the setting is kept '
              'unchanged.',
        );
      }
      builder.examine(
        table: 'settings',
        recordId: 'seedExercisesVersion',
        cleanOutcome: ReportCategory.preserved,
        events: [?warning],
      );
    }
    report = builder.build();
    for (final e in report.entries) {
      final row = entryRow(
        runId: runId,
        e: e.event,
        exerciseId: exerciseOf['${e.event.table}|${e.event.recordId}'],
        quarantineId:
            quarantineIds['${e.event.table}|${e.event.recordId}|'
                '${e.event.field}'],
      );
      entries[row['event_id']! as String] = row;
    }
    counts = countRows(report);

    // Integrity run: pre-existing findings in the v7 tables that hold a
    // foreign key or an exercise reference.
    final integrity = MigrationReportBuilder(
      ReportRun(
        runId: integrityRunId,
        trigger: ReportTrigger.integrityCheck,
        generatedAt: DateTime.parse(v8Stamp),
        appVersion: appVersion,
      ),
    );
    final byRecord = <String, Map<String, List<ReportEvent>>>{};
    final integrityExercise = <String, String>{};
    for (final f in findings.values) {
      final v = encodeStoredValue(f.value);
      byRecord
          .putIfAbsent(f.table, () => {})
          .putIfAbsent(f.recordId, () => [])
          .add(
            ReportEvent(
              table: f.table,
              recordId: f.recordId,
              field: f.column,
              originalValue: v,
              resultingValue: v,
              action: ReportAction.none,
              rule: f.rule,
              category: ReportCategory.quarantinedOrUnresolved,
              reason:
                  '${f.table}.${f.column} $v does not resolve in ${f.parent}. '
                  'The damage existed before the v8 migration; it is reported, '
                  'not repaired, and did not block the migration.',
            ),
          );
      if (f.exerciseId case final x?) {
        integrityExercise['${f.table}|${f.recordId}'] = x;
      }
    }
    for (final table in v7.tables.keys) {
      final references =
          db.select('PRAGMA foreign_key_list("$table")').isNotEmpty ||
          const {
            'session_sets',
            'session_exercises',
            'plan_exercises',
            'exercise_user_state',
            'exercises',
          }.contains(table);
      if (!references) continue;
      final pk = pkColumns(db, table);
      final cols = pk.map((c) => '"$c"').join(', ');
      for (final r in db.select('SELECT $cols FROM "$table" ORDER BY $cols')) {
        final id = pk.length == 1
            ? '${r[pk.single]}'
            : jsonEncode([for (final c in pk) r[c]]);
        integrity.examine(
          table: table,
          recordId: id,
          cleanOutcome: ReportCategory.preserved,
          events: byRecord[table]?[id] ?? const [],
        );
      }
    }
    integrityReport = integrity.build();
    for (final e in integrityReport.entries) {
      final row = entryRow(
        runId: integrityRunId,
        e: e.event,
        exerciseId: integrityExercise['${e.event.table}|${e.event.recordId}'],
        quarantineId: null,
      );
      entries[row['event_id']! as String] = row;
    }
    integrityCounts = countRows(integrityReport);
  }
}

/// Stored report counts of [runId] as `table|dimension|code` → count.
Map<String, int> storedCounts(DbState s, String runId) => {
  for (final r in s.rows('migration_report_counts'))
    if (r['run_id'] == runId)
      '${r['source_table']}|${r['dimension']}|${r['code']}':
          r['record_count']! as int,
};

/// Stored report entries by event id.
Map<String, EntryRow> storedEntries(DbState s) => {
  for (final r in s.rows('migration_report_entries'))
    r['event_id']! as String: r,
};

/// The foreign-key and reference findings of [file] after migration, keyed
/// like [findingsOf] (by primary key, so independent of rowids).
Set<String> findingKeys(File file) => findingsOfFile(file).keys.toSet();
