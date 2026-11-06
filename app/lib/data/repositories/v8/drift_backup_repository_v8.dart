import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:repforge/data/db/migration/bootstrap_reference_v8.dart';
import 'package:repforge/data/db/migration/historical_steps.dart';
import 'package:repforge/data/db/migration/v7_to_v8.dart' show V7ToV8Migration;
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:repforge/data/repositories/v8/backup_restore_plan_v8.dart';
import 'package:repforge/data/repositories/v8/backup_schema_v8.dart';
import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/migration_report.dart';

export 'package:repforge/data/repositories/v8/backup_restore_plan_v8.dart'
    show RestoreRejected, backupFormatV8, backupSchemaV8;

/// Inputs of the v8 backup repository. Nothing here has a production
/// default: the app does not use v8 yet.
@immutable
final class BackupV8Config {
  const BackupV8Config({
    required this.clock,
    required this.appVersion,
    required this.installLabel,
    required this.newRunId,
  });

  /// Export time, restore time (`generated_at`, `merged_at`, quarantine and
  /// block stamps of the restore).
  final Clock clock;

  /// `appVersion` of a format 3 file and `app_version` of a restore run.
  final String appVersion;

  /// `provenance_source` of a run produced on this device (the integrity
  /// run of a restore; R-08).
  final String installLabel;

  /// A new, unique run id for every restore (production: a UUID). A
  /// restore never reads or writes the migration run ledger (R-32; Review B
  /// re-check N2).
  final String Function() newRunId;
}

/// Checkpoints of phase 2, for failure injection in tests.
enum RestorePhase {
  keysOff,
  transactionStarted,
  baselineTaken,
  userDataDeleted,
  referenceInserted,
  exercisesInserted,
  userDataInserted,
  quarantineInserted,
  sessionExercisesBackfilled,
  reportMerged,
  restoreReportWritten,
  foreignKeysChecked,
  selfChecked,
}

typedef RestorePhaseProbe = Future<void> Function(RestorePhase phase);

/// Report rule code of a device-wins difference (D04 §7, 2026-11-06
/// "Restore conflicts"; ADR-0008 E Q15). Awaits owner confirmation as a
/// report rule code (`docs/backup-format-3.md` register B-06).
const String deviceWinsRule = 'D04-RESTORE-DEVICE-WINS';

/// Backup format 3 and restore of formats 1, 2 and 3 into schema v8 (WP 8
/// sub-stage 3b-7). Contract: `docs/backup-format-3.md`.
///
/// **Not connected to the app.** Production keeps `DriftBackupRepository`
/// (schema 7, format 2); nothing in `lib/app`, `lib/features` or `lib/ui`
/// imports this file (architecture test).
///
/// Restore = phase 1a ([planRestore], pure: parse, map, validate every row
/// and key), phase 1b (reads the device, writes nothing: reference and
/// catalogue conflicts, IC-315, every foreign key of the composed state,
/// report-history conflicts), then phase 2: foreign keys switched off
/// outside the transaction and verified, one transaction (delete only the
/// user tables, insert, quarantine, merge the report, write the restore run,
/// targeted foreign-key check against a baseline, self-checks), keys
/// restored. Any failure rolls back; nothing is changed.
final class DriftBackupRepositoryV8 implements BackupRepository {
  DriftBackupRepositoryV8(
    this._db, {
    required this.config,
    @visibleForTesting this.phaseProbe,
  });

  final AppDatabaseV8 _db;
  final BackupV8Config config;

  /// Test seam: called at every [RestorePhase]; a throw aborts the restore.
  final RestorePhaseProbe? phaseProbe;

  static const int formatVersion = backupFormatV8;

  Future<void> _phase(RestorePhase p) async {
    await phaseProbe?.call(p);
  }

  // ---- Export -------------------------------------------------------------

  @override
  Future<String> exportJson() async {
    final tables = <String, List<Map<String, Object?>>>{};
    await _db.transaction(() async {
      for (final spec in schemaV8Tables) {
        tables[spec.name] = [
          for (final r
              in await _db
                  .customSelect('SELECT * FROM "${spec.name}" ORDER BY rowid')
                  .get())
            Map.of(r.data),
        ];
      }
    });
    return const JsonEncoder.withIndent('  ').convert({
      'app': 'repforge',
      'formatVersion': backupFormatV8,
      'schemaVersion': _db.schemaVersion,
      'appVersion': config.appVersion,
      'exportedAt': config.clock.now().toUtc().toIso8601String(),
      'releaseLog': [
        for (final r in tables['catalogue_releases']!) releaseLogEntry(r),
      ],
      'tables': tables,
    });
  }

  // ---- Preview ------------------------------------------------------------

  /// Phase 1a only (pure, synchronous): every check that needs no device
  /// data. Conflicts with the device's reference data, IC-315 against the
  /// device's items and the report-history merge are checked by
  /// [importJson] before it writes (`docs/backup-format-3.md` section 4).
  @override
  Result<BackupPreview> previewJson(String json) {
    try {
      final plan = planRestore(json);
      if (plan.restorableRows == 0) return const Err(_empty);
      return Ok(
        BackupPreview(
          formatVersion: plan.format,
          exportedAt: plan.exportedAt,
          rowCounts: plan.previewCounts,
        ),
      );
    } on RestoreRejected catch (e) {
      return Err(e.toError());
    }
  }

  static const _empty = ValidationError(
    'This backup contains no records. Nothing was changed.',
    field: 'file',
  );

  // ---- Restore ------------------------------------------------------------

  @override
  Future<Result<BackupSummary>> importJson(String json) async {
    final RestorePlan plan;
    final _Decision decision;
    final runId = config.newRunId();
    try {
      plan = planRestore(json);
      if (plan.restorableRows == 0) return const Err(_empty);
      decision = await _decide(plan);
      // A new run id per restore (R-07): never one already recorded.
      final taken = await _select(
        'SELECT id FROM migration_runs WHERE id IN (?, ?)',
        [runId, '$runId:integrity'],
      );
      if (runId.isEmpty || taken.isNotEmpty) {
        throw StateError('The restore run id "$runId" is already in use.');
      }
    } on RestoreRejected catch (e) {
      return Err(e.toError());
    } on Object catch (e) {
      return Err(
        StorageError('Restore failed; nothing was changed.', cause: e),
      );
    }

    final now = config.clock.now().toUtc().toIso8601String();
    int? keysBefore;
    Map<String, int> written;
    try {
      keysBefore = await _foreignKeys();
      // Safeguard A: never inside a transaction, and verified.
      await _db.customStatement('PRAGMA foreign_keys = OFF');
      if (await _foreignKeys() != 0) {
        throw StateError('Foreign keys could not be switched off.');
      }
      await _phase(RestorePhase.keysOff);
      written = await _db.transaction(
        () => _write(plan, decision, runId: runId, now: now),
      );
    } on Object catch (e) {
      return Err(
        StorageError('Restore failed; nothing was changed.', cause: e),
      );
    } finally {
      if (keysBefore != null) {
        await _db.customStatement(
          'PRAGMA foreign_keys = ${keysBefore == 1 ? 'ON' : 'OFF'}',
        );
      }
    }
    if (await _foreignKeys() != keysBefore) {
      return const Err(
        StorageError(
          'The backup was restored, but foreign keys could not be switched '
          'back on. Restart the app.',
        ),
      );
    }
    return Ok(BackupSummary(formatVersion: plan.format, rowCounts: written));
  }

  Future<int> _foreignKeys() async =>
      (await _db.customSelect('PRAGMA foreign_keys').getSingle())
              .data
              .values
              .first!
          as int;

  Future<List<Map<String, Object?>>> _select(
    String sql, [
    List<Object?> args = const [],
  ]) async => [
    for (final r
        in await _db
            .customSelect(sql, variables: [for (final a in args) _variable(a)])
            .get())
      r.data,
  ];

  static Variable<Object> _variable(Object? a) => switch (a) {
    null => const Variable(null),
    final String s => Variable.withString(s),
    final int i => Variable.withInt(i),
    final double d => Variable.withReal(d),
    _ => throw ArgumentError.value(a, 'a', 'unsupported value'),
  };

  // ---- Phase 1b: device-aware validation, no writes ------------------------

  Future<_Decision> _decide(RestorePlan plan) async {
    final problems = <String>[];
    final d = _Decision();

    // Reference and catalogue rows (D04 "Restore conflicts"; Q8, Q15, R-20).
    final deviceRef = <String, Map<String, Map<String, Object?>>>{};
    for (final spec in schemaV8Tables) {
      if (spec.kind != TableKind.reference) continue;
      final rows = await _select('SELECT * FROM "${spec.name}"');
      deviceRef[spec.name] = {for (final r in rows) spec.keyOf(r): r};
    }
    if (plan.isLegacy) {
      // The migration's bootstrap, device rows winning (R-23): a v7 backup
      // holds no reference rows, its targets and items need these.
      for (final n in BootstrapReferenceV8.anatomyNodes) {
        d.bootstrapMissing += deviceRef['anatomy_nodes']!.containsKey(n.id)
            ? 0
            : 1;
      }
      for (final e in BootstrapReferenceV8.equipmentItems) {
        d.bootstrapMissing += deviceRef['equipment_items']!.containsKey(e.id)
            ? 0
            : 1;
      }
      d.bootstrapMissing +=
          deviceRef['content_providers']!.containsKey(
            BootstrapReferenceV8.providerId,
          )
          ? 0
          : 1;
    }
    for (final MapEntry(key: table, value: rows)
        in plan.referenceRows.entries) {
      final spec = schemaV8ByName[table]!;
      final device = deviceRef[table]!;
      for (final r in rows) {
        final key = spec.keyOf(r);
        final have = device[key];
        if (have == null) {
          d.referenceInsert.putIfAbsent(table, () => []).add(r);
          continue;
        }
        for (final c in spec.columns) {
          if (have[c.name] == r[c.name]) continue;
          if (spec.immutableColumns.contains(c.name)) {
            final why = table == 'equipment_items' && c.name == 'default_role'
                ? ' (a default role never changes: ADR-0008 E Q8, R-20)'
                : '';
            problems.add(
              '$table $key: ${c.name} is ${jsonEncode(r[c.name])} in the '
              'backup and ${jsonEncode(have[c.name])} on this device$why',
            );
          } else {
            d.referenceWarnings
                .putIfAbsent(table, () => {})
                .putIfAbsent(key, () => [])
                .add(
                  _deviceWins(
                    table: table,
                    recordId: key,
                    field: c.name,
                    backup: r[c.name],
                    device: have[c.name],
                  ),
                );
          }
        }
      }
    }

    // Exercises: user and imported ones are replaced; a system exercise on
    // the device is catalogue content and wins (Q15); same id with another
    // source or provider is a conflict.
    final deviceExercises = {
      for (final r in await _select(
        'SELECT id, source, provider_id FROM exercises',
      ))
        r['id']! as String: r,
    };
    final keptSystem = {
      for (final MapEntry(:key, :value) in deviceExercises.entries)
        if (value['source'] == 'system') key,
    };
    for (final x in plan.exercises) {
      if (!keptSystem.contains(x.id)) {
        d.exercisesInsert.add(x);
        continue;
      }
      final have = deviceExercises[x.id]!;
      final spec = schemaV8ByName['exercises']!;
      var conflict = false;
      for (final c in spec.immutableColumns) {
        if (have[c] != x.row[c]) {
          conflict = true;
          problems.add(
            'exercises ${x.id}: $c is ${jsonEncode(x.row[c])} in the backup '
            'and ${jsonEncode(have[c])} on this device',
          );
        }
      }
      if (conflict) continue;
      d.deviceWins[x.id] = await _deviceWinsEvents(x);
    }

    // IC-315 on every equipment link the restore writes (R-19): a CHECK
    // cannot read the item's default role.
    String? defaultRole(String item) {
      final device = deviceRef['equipment_items']![item];
      if (device != null) return device['default_role'] as String?;
      for (final r
          in d.referenceInsert['equipment_items'] ??
              const <Map<String, Object?>>[]) {
        if (r['id'] == item) return r['default_role'] as String?;
      }
      for (final e in BootstrapReferenceV8.equipmentItems) {
        if (plan.isLegacy && e.id == item) return e.defaultRole;
      }
      return null;
    }

    for (final x in d.exercisesInsert) {
      for (final e in x.equipment) {
        final problem = ic315Problem(
          roleOverride: e['role_override'] as String?,
          overrideNote: e['override_note'] as String?,
          defaultRole: defaultRole(e['equipment_id']! as String),
        );
        if (problem != null) {
          problems.add(
            'exercise_equipment ${x.id}/${e['equipment_id']}: $problem',
          );
        }
      }
    }

    // Report history: merged by stable id (R-07), never replaced.
    await _decideReport(plan, d, problems);

    if (problems.isNotEmpty) {
      throw RestoreRejected(
        'This backup conflicts with the data on this device:',
        problems,
      );
    }

    // Every foreign key of the composed state.
    _checkComposedForeignKeys(plan, d, deviceRef, keptSystem);
    return d;
  }

  ReportEvent _deviceWins({
    required String table,
    required String recordId,
    required String field,
    required Object? backup,
    required Object? device,
  }) => ReportEvent(
    table: table,
    recordId: recordId,
    field: field,
    originalValue: encodeStoredValue(backup),
    resultingValue: encodeStoredValue(device),
    action: ReportAction.retained,
    rule: deviceWinsRule,
    category: ReportCategory.warningForReview,
    reason:
        'The backup holds another value; the device keeps its own '
        '(reference and catalogue data: the device wins on restore).',
  );

  /// Differences between the backup's version of a system exercise and the
  /// device's, one warning per column or child table.
  Future<List<ReportEvent>> _deviceWinsEvents(ExerciseAggregate x) async {
    final device = (await _select('SELECT * FROM exercises WHERE id = ?', [
      x.id,
    ])).single;
    final events = <ReportEvent>[];
    final spec = schemaV8ByName['exercises']!;
    for (final c in spec.columns) {
      if (spec.immutableColumns.contains(c.name)) continue;
      if (device[c.name] != x.row[c.name]) {
        events.add(
          _deviceWins(
            table: 'exercises',
            recordId: x.id,
            field: c.name,
            backup: x.row[c.name],
            device: device[c.name],
          ),
        );
      }
    }
    for (final MapEntry(key: table, value: rows) in x.children.entries) {
      final deviceRows = await _select(
        'SELECT * FROM "$table" WHERE exercise_id = ?',
        [x.id],
      );
      final a = _canonicalChildren(table, rows);
      final b = _canonicalChildren(table, deviceRows);
      if (a != b) {
        events.add(
          _deviceWins(
            table: 'exercises',
            recordId: x.id,
            field: table,
            backup: a,
            device: b,
          ),
        );
      }
    }
    return events;
  }

  /// The child rows as one JSON text, sorted by key; the block stamp
  /// `blocked_at` is not content.
  static String _canonicalChildren(
    String table,
    List<Map<String, Object?>> rows,
  ) {
    final spec = schemaV8ByName[table]!;
    final cols = [
      for (final c in spec.columns)
        if (c.name != 'blocked_at') c.name,
    ];
    final list = [
      for (final r in rows) [for (final c in cols) r[c]],
    ]..sort((p, q) => jsonEncode(p).compareTo(jsonEncode(q)));
    return jsonEncode({'columns': cols, 'rows': list});
  }

  Future<void> _decideReport(
    RestorePlan plan,
    _Decision d,
    List<String> problems,
  ) async {
    final runs = plan.reportRows['migration_runs'] ?? const [];
    if (runs.isEmpty &&
        (plan.reportRows['migration_report_entries'] ?? const []).isEmpty) {
      return;
    }
    final deviceRuns = {
      for (final r in await _select('SELECT * FROM migration_runs'))
        r['id']! as String: r,
    };
    const produced = [
      'id',
      'trigger_kind',
      'from_version',
      'to_version',
      'generated_at',
      'app_version',
    ];
    for (final r in runs) {
      final have = deviceRuns[r['id']];
      if (have == null) {
        d.runsInsert.add(r);
        continue;
      }
      for (final c in produced) {
        if (have[c] != r[c]) {
          problems.add(
            'migration_runs ${r['id']}: $c is ${jsonEncode(r[c])} in the '
            'backup and ${jsonEncode(have[c])} on this device',
          );
        }
      }
    }
    final deviceEntries = {
      for (final r in await _select('SELECT * FROM migration_report_entries'))
        r['event_id']! as String: r,
    };
    for (final r in plan.reportRows['migration_report_entries']!) {
      final have = deviceEntries[r['event_id']];
      if (have == null) {
        d.entriesInsert.add(r);
        continue;
      }
      for (final c in schemaV8ByName['migration_report_entries']!.columns) {
        // The user's acknowledgement is device state (register B-05).
        if (c.name == 'acknowledged_at') continue;
        if (have[c.name] != r[c.name]) {
          problems.add(
            'migration_report_entries ${r['event_id']}: ${c.name} differs '
            'between the backup and this device (same event id, other '
            'content)',
          );
        }
      }
    }
    final countsSpec = schemaV8ByName['migration_report_counts']!;
    final deviceCounts = {
      for (final r in await _select('SELECT * FROM migration_report_counts'))
        countsSpec.keyOf(r): r,
    };
    for (final r in plan.reportRows['migration_report_counts']!) {
      final key = countsSpec.keyOf(r);
      final have = deviceCounts[key];
      if (have == null) {
        d.countsInsert.add(r);
      } else if (have['record_count'] != r['record_count']) {
        problems.add(
          'migration_report_counts $key: ${r['record_count']} in the backup '
          'and ${have['record_count']} on this device',
        );
      }
    }
  }

  void _checkComposedForeignKeys(
    RestorePlan plan,
    _Decision d,
    Map<String, Map<String, Map<String, Object?>>> deviceRef,
    Set<String> keptSystem,
  ) {
    final parents = <String, Set<Object?>>{
      for (final MapEntry(key: t, value: rows) in deviceRef.entries)
        t: {...rows.values.map((r) => r['id'])},
    };
    for (final MapEntry(key: t, value: rows) in d.referenceInsert.entries) {
      parents[t]!.addAll(rows.map((r) => r['id']));
    }
    if (plan.isLegacy) {
      parents['content_providers']!.add(BootstrapReferenceV8.providerId);
      parents['anatomy_nodes']!.addAll(
        BootstrapReferenceV8.anatomyNodes.map((n) => n.id),
      );
      parents['equipment_items']!.addAll(
        BootstrapReferenceV8.equipmentItems.map((e) => e.id),
      );
    }
    parents['exercises'] = {
      ...keptSystem,
      ...d.exercisesInsert.map((x) => x.id),
    };
    final writes = <String, List<Map<String, Object?>>>{
      ...d.referenceInsert,
      'exercises': [for (final x in d.exercisesInsert) x.row],
      for (final t in exerciseChildTables)
        t: [for (final x in d.exercisesInsert) ...x.children[t]!],
    };
    final problems = <String>[];
    for (final MapEntry(key: table, value: rows) in writes.entries) {
      final spec = schemaV8ByName[table]!;
      for (final fk in spec.foreignKeys) {
        final keys = parents[fk.parentTable];
        if (keys == null) continue; // user parents: checked in phase 1a
        for (final r in rows) {
          final v = r[fk.column];
          if (v != null && !keys.contains(v)) {
            problems.add(
              '$table ${spec.keyOf(r)}: ${fk.column} ${jsonEncode(v)} has '
              'no ${fk.parentTable} row in the backup or on this device',
            );
          }
        }
      }
    }
    if (problems.isNotEmpty) {
      throw RestoreRejected(
        'This backup refers to reference or catalogue records that exist '
        'neither in the backup nor on this device (foreign key):',
        problems,
      );
    }
  }

  // ---- Phase 2: one transaction --------------------------------------------

  Future<void> _insert(String table, Map<String, Object?> row) async {
    final cols = row.keys.toList();
    await _db.customStatement(
      'INSERT INTO "$table" (${cols.map((c) => '"$c"').join(', ')}) '
      'VALUES (${List.filled(cols.length, '?').join(', ')})',
      [for (final c in cols) row[c]],
    );
  }

  Future<int> _count(String table) async =>
      (await _select('SELECT count(*) AS c FROM "$table"')).single['c']! as int;

  Future<Map<String, int>> _write(
    RestorePlan plan,
    _Decision d, {
    required String runId,
    required String now,
  }) async {
    await _phase(RestorePhase.transactionStarted);
    final written = <String, int>{};
    void tally(String table, [int n = 1]) =>
        written.update(table, (v) => v + n, ifAbsent: () => n);

    final baseline = await _foreignKeyFindings();
    final before = {
      for (final t in schemaV8Tables) t.name: await _count(t.name),
    };
    final keptSystemChildren = {
      for (final t in exerciseChildTables)
        t:
            (await _select(
                  'SELECT count(*) AS c FROM "$t" WHERE exercise_id IN '
                  "(SELECT id FROM exercises WHERE source = 'system')",
                )).single['c']!
                as int,
    };
    final keptSystem =
        (await _select(
              "SELECT count(*) AS c FROM exercises WHERE source = 'system'",
            )).single['c']!
            as int;
    await _phase(RestorePhase.baselineTaken);

    // Delete only the allow-listed user data (keys are off: no cascade).
    for (final spec in schemaV8Tables) {
      if (spec.kind == TableKind.user) {
        await _db.customStatement('DELETE FROM "${spec.name}"');
      }
    }
    for (final t in exerciseChildTables) {
      await _db.customStatement(
        'DELETE FROM "$t" WHERE exercise_id NOT IN '
        "(SELECT id FROM exercises WHERE source = 'system')",
      );
    }
    await _db.customStatement("DELETE FROM exercises WHERE source <> 'system'");
    await _phase(RestorePhase.userDataDeleted);

    // Reference: missing rows only; the device wins.
    if (plan.isLegacy) {
      await BootstrapReferenceV8.insert(_db);
    }
    for (final spec in schemaV8Tables) {
      for (final r
          in d.referenceInsert[spec.name] ?? const <Map<String, Object?>>[]) {
        await _insert(spec.name, r);
        tally(spec.name);
      }
    }
    await _phase(RestorePhase.referenceInserted);

    for (final x in d.exercisesInsert) {
      await _insert('exercises', x.row);
      tally('exercises');
      for (final MapEntry(key: t, value: rows) in x.children.entries) {
        for (final r in rows) {
          await _insert(t, {
            ...r,
            if (t == 'exercise_blocks' && !r.containsKey('blocked_at'))
              'blocked_at': now,
          });
          tally(t);
        }
      }
    }
    await _phase(RestorePhase.exercisesInserted);

    for (final spec in schemaV8Tables) {
      for (final r
          in plan.userRows[spec.name] ?? const <Map<String, Object?>>[]) {
        await _insert(spec.name, r);
        tally(spec.name);
      }
    }
    await _phase(RestorePhase.userDataInserted);

    // Quarantine: the backup's rows with their ids, then the new ones.
    final preV8Quarantine = <Map<String, Object?>>[];
    for (final r in plan.legacyQuarantineRows) {
      await _insert('legacy_quarantine', r);
      tally('legacy_quarantine');
      preV8Quarantine.add(r);
    }
    final quarantineIds = <String, int>{};
    for (final q in _quarantineToWrite(plan, d)) {
      final id = await _db.customInsert(
        'INSERT INTO legacy_quarantine (source_table, row_id, reason, '
        'original_json, quarantined_at) VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(q.sourceTable),
          Variable.withString(q.rowId),
          Variable.withString(q.reason),
          Variable.withString(q.originalJson),
          Variable.withString(now),
        ],
      );
      tally('legacy_quarantine');
      if (q.fields.isEmpty) {
        // A pre-v6 quarantine row: reported like the migration's pre-v8
        // rows (R-33).
        preV8Quarantine.add({
          'id': id,
          'source_table': q.sourceTable,
          'row_id': q.rowId,
          'reason': q.reason,
          'original_json': q.originalJson,
          'quarantined_at': now,
        });
      }
      for (final f in q.fields) {
        quarantineIds['${q.sourceTable}|${q.rowId}|$f'] = id;
      }
    }
    await _phase(RestorePhase.quarantineInserted);

    if (plan.backfillSessionExercises) {
      // The frozen v6 → v7 backfill, as production restore and the
      // migration give a pre-v7 backup's sets their entries.
      await HistoricalSteps.backfillSessionExercisesV7(_db);
      tally('session_exercises', await _count('session_exercises'));
    }
    await _phase(RestorePhase.sessionExercisesBackfilled);

    // Report history: merged (R-07, R-08).
    for (final r in d.runsInsert) {
      final merged = r['provenance_kind'] == 'device'
          ? {
              ...r,
              'provenance_kind': 'backup',
              'provenance_source': plan.backupIdentity,
              'merged_at': now,
            }
          : r;
      await _insert('migration_runs', merged);
      tally('migration_runs');
    }
    for (final r in d.countsInsert) {
      await _insert('migration_report_counts', r);
      tally('migration_report_counts');
    }
    for (final r in d.entriesInsert) {
      await _insert('migration_report_entries', r);
      tally('migration_report_entries');
    }
    await _phase(RestorePhase.reportMerged);

    final restoreRuns = await _writeRestoreReport(
      plan,
      d,
      runId: runId,
      now: now,
      preV8Quarantine: preV8Quarantine,
      quarantineIds: quarantineIds,
    );
    await _phase(RestorePhase.restoreReportWritten);

    // Targeted foreign-key check against the baseline (safeguard A).
    final after = await _foreignKeyFindings();
    final fresh = [
      for (final k in after)
        if (!baseline.contains(k)) k,
    ];
    if (fresh.isNotEmpty) {
      throw StateError('The restore would break foreign keys: $fresh');
    }
    await _phase(RestorePhase.foreignKeysChecked);

    // Self-checks: every table holds exactly the composed rows.
    final expected = <String, int>{
      for (final spec in schemaV8Tables)
        if (spec.kind == TableKind.user)
          spec.name: (plan.userRows[spec.name] ?? const []).length,
      'legacy_quarantine':
          plan.legacyQuarantineRows.length + _quarantineToWrite(plan, d).length,
      'exercises': keptSystem + d.exercisesInsert.length,
      for (final t in exerciseChildTables)
        t:
            keptSystemChildren[t]! +
            d.exercisesInsert.fold(0, (s, x) => s + x.children[t]!.length),
      for (final spec in schemaV8Tables)
        if (spec.kind == TableKind.reference)
          spec.name:
              before[spec.name]! +
              (d.referenceInsert[spec.name] ?? const []).length,
      'migration_runs':
          before['migration_runs']! + d.runsInsert.length + restoreRuns.runs,
      'migration_report_entries':
          before['migration_report_entries']! +
          d.entriesInsert.length +
          restoreRuns.entries,
      'migration_report_counts':
          before['migration_report_counts']! +
          d.countsInsert.length +
          restoreRuns.counts,
    };
    if (plan.isLegacy) {
      // The bootstrap's missing rows (device rows win).
      final boot =
          await _count('content_providers') +
          await _count('anatomy_nodes') +
          await _count('equipment_items') -
          before['content_providers']! -
          before['anatomy_nodes']! -
          before['equipment_items']!;
      if (boot != d.bootstrapMissing) {
        throw StateError(
          'bootstrap: $boot rows inserted, expected '
          '${d.bootstrapMissing}',
        );
      }
      expected.removeWhere(
        (t, _) => const {
          'content_providers',
          'anatomy_nodes',
          'equipment_items',
        }.contains(t),
      );
    }
    if (plan.backfillSessionExercises) expected.remove('session_exercises');
    final problems = <String>[];
    for (final MapEntry(key: t, value: n) in expected.entries) {
      final actual = await _count(t);
      if (actual != n) problems.add('$t: $actual rows, expected $n');
    }
    if (problems.isNotEmpty) {
      throw StateError('Restore self-check failed: ${problems.join('; ')}');
    }
    await _phase(RestorePhase.selfChecked);
    return written;
  }

  /// The quarantine rows phase 2 writes: a system exercise kept from the
  /// device (device wins) uses nothing of the backup's version, so its
  /// conversion leaves nothing to quarantine.
  static List<NewQuarantineRow> _quarantineToWrite(
    RestorePlan plan,
    _Decision d,
  ) => [
    for (final q in plan.newQuarantineRows)
      if (!(q.sourceTable == 'exercises' && d.deviceWins.containsKey(q.rowId)))
        q,
  ];

  /// Every foreign-key violation, keyed by table, primary key and parent.
  Future<Set<String>> _foreignKeyFindings() async {
    final out = <String>{};
    for (final v in await _select('PRAGMA foreign_key_check')) {
      final table = v['table']! as String;
      final spec = schemaV8ByName[table];
      final key = spec == null
          ? '${v['rowid']}'
          : spec.keyOf(
              (await _select('SELECT * FROM "$table" WHERE rowid = ?', [
                v['rowid'],
              ])).single,
            );
      out.add(jsonEncode([table, key, v['parent'], v['fkid']]));
    }
    return out;
  }

  Future<({int runs, int entries, int counts})> _writeRestoreReport(
    RestorePlan plan,
    _Decision d, {
    required String runId,
    required String now,
    required List<Map<String, Object?>> preV8Quarantine,
    required Map<String, int> quarantineIds,
  }) async {
    final run = ReportRun(
      runId: runId,
      trigger: ReportTrigger.restore,
      generatedAt: DateTime.parse(now),
      appVersion: config.appVersion,
      fromSchemaVersion: plan.schemaVersion,
      toSchemaVersion: backupSchemaV8,
    );
    final builder = MigrationReportBuilder(run);
    final exerciseOf = <String, String>{};
    final examined = <String, int>{};
    final clean = plan.isLegacy
        ? ReportCategory.migrated
        : ReportCategory.preserved;
    for (final x in plan.exercises) {
      exerciseOf['exercises|${x.id}'] = x.id;
      final wins = d.deviceWins[x.id];
      builder.examine(
        table: 'exercises',
        recordId: x.id,
        cleanOutcome: clean,
        events: wins ?? x.events,
      );
    }
    if (plan.exercises.isNotEmpty) {
      examined['exercises'] = plan.exercises.length;
    }
    for (final s in plan.sets) {
      if (s.exerciseId case final String e) {
        exerciseOf['session_sets|${s.setId}'] = e;
      }
      builder.examine(
        table: 'session_sets',
        recordId: s.setId,
        cleanOutcome: ReportCategory.preserved,
        events: s.events,
      );
    }
    if (plan.sets.isNotEmpty) examined['session_sets'] = plan.sets.length;
    if (plan.isLegacy) {
      for (final r in preV8Quarantine) {
        final id = '${r['id']}';
        quarantineIds['${V7ToV8Migration.legacyQuarantineTable}|$id|'
                '${V7ToV8Migration.legacyQuarantineField}'] =
            r['id']! as int;
        if (r['source_table'] == 'exercises' && r['row_id'] is String) {
          exerciseOf['${V7ToV8Migration.legacyQuarantineTable}|$id'] =
              r['row_id']! as String;
        }
        builder.examine(
          table: V7ToV8Migration.legacyQuarantineTable,
          recordId: id,
          cleanOutcome: ReportCategory.preserved,
          events: [V7ToV8Migration.legacyQuarantineEvent(r)],
        );
      }
      if (preV8Quarantine.isNotEmpty) {
        examined[V7ToV8Migration.legacyQuarantineTable] =
            preV8Quarantine.length;
      }
    }
    for (final MapEntry(key: table, value: rows)
        in plan.referenceRows.entries) {
      if (rows.isEmpty) continue;
      final spec = schemaV8ByName[table]!;
      final warnings = d.referenceWarnings[table] ?? const {};
      for (final r in rows) {
        final key = spec.keyOf(r);
        builder.examine(
          table: table,
          recordId: key,
          cleanOutcome: ReportCategory.preserved,
          events: warnings[key] ?? const [],
        );
      }
      examined[table] = rows.length;
    }
    final report = builder.build();
    final rec = reconcileReport(report, examinedByTable: examined);
    if (!rec.reconciles) {
      throw StateError('The restore report does not reconcile: $rec');
    }
    await _insert('migration_runs', {
      'id': runId,
      'trigger_kind': 'restore',
      'from_version': plan.schemaVersion,
      'to_version': backupSchemaV8,
      'generated_at': now,
      'app_version': config.appVersion,
      'provenance_kind': 'backup',
      'provenance_source': plan.backupIdentity,
      'merged_at': now,
    });
    var written = await _writeReport(report, quarantineIds, exerciseOf);
    var runs = 1;

    // Exercise references that do not resolve (IC-901 to IC-903): reported
    // in an integrity run, never repaired, never blocking (as the
    // migration's R-31 run).
    final integrity = await _integrityReport(
      runId: '$runId:integrity',
      now: now,
    );
    if (integrity != null) {
      await _insert('migration_runs', {
        'id': integrity.run.runId,
        'trigger_kind': 'integrityCheck',
        'from_version': null,
        'to_version': null,
        'generated_at': now,
        'app_version': config.appVersion,
        'provenance_kind': 'device',
        'provenance_source': config.installLabel,
        'merged_at': null,
      });
      runs++;
      final w = await _writeReport(integrity, const {}, {
        for (final e in integrity.entries)
          '${e.event.table}|${e.event.recordId}': ?_exerciseOfFinding(e.event),
      });
      written = (
        entries: written.entries + w.entries,
        counts: written.counts + w.counts,
      );
    }
    return (runs: runs, entries: written.entries, counts: written.counts);
  }

  static String? _exerciseOfFinding(ReportEvent e) => e.table == 'exercises'
      ? e.recordId
      : switch (decodeStoredValue(e.originalValue)) {
          final String s => s,
          _ => null,
        };

  /// Exercise ids without a foreign key (IC-900 series), as the migration
  /// checks them.
  static const List<({String table, String column, String rule})>
  _looseReferences = [
    (table: 'session_sets', column: 'exercise_id', rule: 'IC-901'),
    (table: 'session_exercises', column: 'exercise_id', rule: 'IC-901'),
    (table: 'plan_exercises', column: 'exercise_id', rule: 'IC-902'),
    (table: 'exercise_user_state', column: 'exercise_id', rule: 'IC-902'),
    (table: 'exercises', column: 'copied_from_id', rule: 'IC-903'),
  ];

  Future<MigrationReport?> _integrityReport({
    required String runId,
    required String now,
  }) async {
    final findings = <String, Map<String, List<ReportEvent>>>{};
    for (final r in _looseReferences) {
      final spec = schemaV8ByName[r.table]!;
      final pk = spec.primaryKey;
      final rows = await _select(
        'SELECT ${pk.map((c) => '"$c"').join(', ')}, "${r.column}" AS ref '
        'FROM "${r.table}" t WHERE t."${r.column}" IS NOT NULL AND NOT '
        'EXISTS (SELECT 1 FROM exercises e WHERE e.id = t."${r.column}")',
      );
      for (final row in rows) {
        final value = row['ref'];
        findings
            .putIfAbsent(r.table, () => {})
            .putIfAbsent(spec.keyOf(row), () => [])
            .add(
              ReportEvent(
                table: r.table,
                recordId: spec.keyOf(row),
                field: r.column,
                originalValue: encodeStoredValue(value),
                resultingValue: encodeStoredValue(value),
                action: ReportAction.none,
                rule: r.rule,
                category: ReportCategory.quarantinedOrUnresolved,
                reason:
                    '${r.table}.${r.column} ${encodeStoredValue(value)} '
                    'does not resolve in exercises. It came from the '
                    'restored backup; it is reported, not repaired, and did '
                    'not block the restore.',
              ),
            );
      }
    }
    if (findings.isEmpty) return null;
    final builder = MigrationReportBuilder(
      ReportRun(
        runId: runId,
        trigger: ReportTrigger.integrityCheck,
        generatedAt: DateTime.parse(now),
        appVersion: config.appVersion,
      ),
    );
    final examined = <String, int>{};
    for (final table in {for (final r in _looseReferences) r.table}) {
      final spec = schemaV8ByName[table]!;
      final keys = [
        for (final r in await _select(
          'SELECT ${spec.primaryKey.map((c) => '"$c"').join(', ')} FROM '
          '"$table"',
        ))
          spec.keyOf(r),
      ];
      if (keys.isEmpty) continue;
      examined[table] = keys.length;
      for (final k in keys) {
        builder.examine(
          table: table,
          recordId: k,
          cleanOutcome: ReportCategory.preserved,
          events: findings[table]?[k] ?? const [],
        );
      }
    }
    final report = builder.build();
    final rec = reconcileReport(report, examinedByTable: examined);
    if (!rec.reconciles) {
      throw StateError('The integrity report does not reconcile: $rec');
    }
    return report;
  }

  /// Writes the entries and counts of [report] as the migration does: both
  /// count dimensions for every examined table, zeros included.
  Future<({int entries, int counts})> _writeReport(
    MigrationReport report,
    Map<String, int> quarantineIds,
    Map<String, String> exerciseOf,
  ) async {
    var entries = 0;
    var counts = 0;
    for (final entry in report.entries) {
      final e = entry.event;
      await _insert('migration_report_entries', {
        'event_id': entry.eventId,
        'run_id': entry.runId,
        'source_table': e.table,
        'record_id': e.recordId,
        'exercise_id': exerciseOf['${e.table}|${e.recordId}'],
        'field': e.field,
        'position': e.position,
        'original_value': e.originalValue,
        'resulting_value': e.resultingValue ?? encodeStoredValue(null),
        'element': e.element,
        'disposition': e.action.name,
        'block_reason': e.blockReason?.name,
        'rule': e.rule,
        'reason': e.reason,
        'category': e.category.code,
        'quarantine_id': quarantineIds['${e.table}|${e.recordId}|${e.field}'],
        'acknowledged_at': null,
      });
      entries++;
    }
    for (final c in report.counts.values) {
      final rows = <(String, String, int)>[
        ('category', 'examined', c.examined),
        for (final o in ReportCategory.outcomes)
          ('category', o.code, c.count(o)),
        (
          'category',
          ReportCategory.warningForReview.code,
          c.recordsWithWarnings,
        ),
        for (final a in ReportAction.values)
          ('disposition', a.name, c.entries(a)),
      ];
      for (final (dimension, code, n) in rows) {
        await _insert('migration_report_counts', {
          'run_id': report.run.runId,
          'source_table': c.table,
          'dimension': dimension,
          'code': code,
          'record_count': n,
        });
        counts++;
      }
    }
    return (entries: entries, counts: counts);
  }
}

/// IC-315 for one stored `exercise_equipment` row (R-19; ADR-0008 E Q6):
/// the same two decisions as `validateExercise` in `exercise_rules.dart`
/// (a test proves equality): an override needs a note (Dart `trim`, the
/// domain authority), and an item whose default role is `cardio` or
/// `implement` takes no override. Null when the row is valid.
String? ic315Problem({
  required String? roleOverride,
  required String? overrideNote,
  required String? defaultRole,
}) {
  if (roleOverride == null) return null;
  if ((overrideNote ?? '').trim().isEmpty) {
    return 'a role override needs a note (IC-315)';
  }
  if (defaultRole == 'cardio' || defaultRole == 'implement') {
    return 'an item with the default role $defaultRole takes no role '
        'override (IC-315, ADR-0008 E Q6)';
  }
  return null;
}

/// What phase 1b decided.
final class _Decision {
  final Map<String, List<Map<String, Object?>>> referenceInsert = {};
  final Map<String, Map<String, List<ReportEvent>>> referenceWarnings = {};
  final List<ExerciseAggregate> exercisesInsert = [];
  final Map<String, List<ReportEvent>> deviceWins = {};
  final List<Map<String, Object?>> runsInsert = [];
  final List<Map<String, Object?>> entriesInsert = [];
  final List<Map<String, Object?>> countsInsert = [];
  int bootstrapMissing = 0;
}
