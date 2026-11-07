import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:meta/meta.dart';
import 'package:repforge/data/db/migration/bootstrap_reference_v8.dart';
import 'package:repforge/data/db/migration/historical_steps.dart';
import 'package:repforge/data/db/migration/v7_to_v8.dart' show V7ToV8Migration;
import 'package:repforge/data/db/migration/v8_sql.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:repforge/data/repositories/v8/backup_restore_plan_v8.dart';
import 'package:repforge/data/repositories/v8/backup_schema_v8.dart';
import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/exercise_rules.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_ids.dart';
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
    required this.loadSeedBytes,
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

  /// The exact bytes of the bundled seed `assets/seed/exercise_library.json`
  /// (as `V8MigrationConfig.loadSeedBytes`). A restored v7 backup records
  /// release 1 only when they hash to the pinned v7-era value (owner
  /// decision R-30 / B-07 option b, the migration's rule).
  final Future<List<int>> Function() loadSeedBytes;
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
                  .customSelect(
                    'SELECT * FROM ${V8Sql.quote(spec.name)} ORDER BY rowid',
                  )
                  .get())
            Map.of(r.data),
        ];
      }
    });
    // Compact (no indentation; Review C M-1): the contract fixes the content,
    // not the layout (`docs/backup-format-3.md` section 2, N-10), and the
    // pretty-printed file was 1.51 times larger (stress profile: 84.2 MB
    // against 55.7 MB).
    return jsonEncode({
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
    } on Object catch (e) {
      // Never thrown by phase 1a; the port promises a Result.
      return Err(
        ValidationError(
          'This backup cannot be read: $e. Nothing was changed.',
          field: 'file',
        ),
      );
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
    try {
      plan = planRestore(json);
    } on RestoreRejected catch (e) {
      return Err(e.toError());
    }
    if (plan.restorableRows == 0) return const Err(_empty);

    final runId = config.newRunId();
    final now = config.clock.now().toUtc().toIso8601String();
    // Review C L-2: the switch of the foreign keys, the transaction and the
    // switch back run inside one exclusive use of the connection (as the
    // migration does), so no other statement can run with the keys off.
    return await _db.exclusively(() async {
      int? keysBefore;
      Result<BackupSummary> result;
      try {
        keysBefore = await _foreignKeys();
        // Safeguard A: never inside a transaction, and verified.
        await _db.customStatement('PRAGMA foreign_keys = OFF');
        if (await _foreignKeys() != 0) {
          throw StateError('Foreign keys could not be switched off.');
        }
        await _phase(RestorePhase.keysOff);
        // Phase 1b reads the device inside the write transaction (review
        // L3), so nothing can change between the checks and the writes; a
        // rejection rolls back a transaction that has written nothing.
        final written = await _db.transaction(() async {
          await _phase(RestorePhase.transactionStarted);
          final decision = await _decide(plan);
          // A new run id per restore (R-07): never one already recorded.
          final taken = await _select(
            'SELECT id FROM migration_runs WHERE id IN (?, ?)',
            [runId, '$runId:integrity'],
          );
          final incoming = {
            for (final r
                in plan.reportRows['migration_runs'] ??
                    const <Map<String, Object?>>[])
              r['id'],
          };
          if (runId.isEmpty ||
              taken.isNotEmpty ||
              incoming.contains(runId) ||
              incoming.contains('$runId:integrity')) {
            throw StateError('The restore run id "$runId" is already in use.');
          }
          return await _write(plan, decision, runId: runId, now: now);
        });
        result = Ok(
          BackupSummary(formatVersion: plan.format, rowCounts: written),
        );
      } on RestoreRejected catch (e) {
        result = Err(e.toError());
      } on Object catch (e) {
        result = Err(
          StorageError('Restore failed; nothing was changed.', cause: e),
        );
      }
      // Switch the keys back; a failure here is a Result too (Review C L-2).
      // A failed restore keeps its own error: that one says why it stopped.
      if (keysBefore != null) {
        Object? cause;
        try {
          await _db.customStatement(
            'PRAGMA foreign_keys = ${keysBefore == 1 ? 'ON' : 'OFF'}',
          );
          if (await _foreignKeys() != keysBefore) {
            cause = StateError('PRAGMA foreign_keys did not change.');
          }
        } on Object catch (e) {
          cause = e;
        }
        if (cause != null && result is Ok) {
          return Err(
            StorageError(
              'The backup was restored, but foreign keys could not be '
              'switched back on. Restart the app.',
              cause: cause,
            ),
          );
        }
      }
      return result;
    });
  }

  Future<int> _foreignKeys() async =>
      (await _db.customSelect('PRAGMA foreign_keys').getSingle())
              .data
              .values
              .first!
          as int;

  late final V8Sql _io = V8Sql(_db);

  Future<List<Map<String, Object?>>> _select(
    String sql, [
    List<Object?> args = const [],
  ]) => _io.select(sql, args);

  // ---- Phase 1b: device-aware validation, no writes ------------------------

  Future<_Decision> _decide(RestorePlan plan) async {
    final problems = <String>[];
    final d = _Decision();

    // Reference and catalogue rows (D04 "Restore conflicts"; Q8, Q15, R-20).
    final deviceRef = <String, Map<String, Map<String, Object?>>>{};
    for (final spec in schemaV8Tables) {
      if (spec.kind != TableKind.reference) continue;
      final rows = await _select('SELECT * FROM ${V8Sql.quote(spec.name)}');
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
              '$table $key: ${c.name} is ${describeBackupValue(r[c.name])} '
              'in the backup and ${describeBackupValue(have[c.name])} on this '
              'device$why',
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

    // Exercises (B-01, decided: field-level ownership): user and imported
    // ones on the device are replaced. A system exercise on the device is
    // catalogue content: its catalogue fields and owned rows win (Q15), the
    // user fields of the backup's version replace the device's
    // ([userOwnedExerciseColumns]); a different system/user classification
    // or provider never rejects the restore by itself.
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
      d.deviceWins[x.id] = await _deviceWinsEvents(x, d);
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

    // Every foreign key of the composed state, before the domain rules read
    // the references.
    _checkComposedForeignKeys(plan, d, deviceRef, keptSystem);

    // The domain rules on every exercise a format 3 restore inserts
    // (review H1; ADR-0008 E Q15), against the composed reference data.
    if (!plan.isLegacy && d.exercisesInsert.isNotEmpty) {
      List<Map<String, Object?>> composed(String table) => [
        ...deviceRef[table]!.values,
        ...?d.referenceInsert[table],
      ];
      final ctx = ExerciseRuleContext(
        reference: referenceDataOf(
          nodes: composed('anatomy_nodes'),
          patterns: composed('movement_patterns'),
          items: composed('equipment_items'),
        ),
        providers: {
          for (final r in composed('content_providers'))
            ProviderId(r['id']! as String),
        },
      );
      for (final x in d.exercisesInsert) {
        problems.addAll(restoreDomainProblems(x, ctx));
      }
    }
    // Formats 1 and 2 keep the migration's dispositions (B-15), with one
    // exception (owner decision 2026-11-06 on H1): a system exercise the
    // restore would insert without a valid primary target rejects the whole
    // restore instead of being blocked.
    if (plan.isLegacy) {
      for (final x in d.exercisesInsert) {
        if (x.isSystem &&
            x.blocks.any(
              (b) => b['reason'] == BlockReason.noPrimaryTarget.name,
            )) {
          problems.add(
            'exercises ${x.id}: a system exercise needs a valid primary '
            'target (IC-204; owner decision 2026-11-06)',
          );
        }
      }
    }

    // Report history: merged by stable id (R-07), never replaced.
    await _decideQuarantine(plan, d);
    await _decideReport(plan, d, problems);

    if (problems.isNotEmpty) {
      throw RestoreRejected(
        'This backup conflicts with the data on this device:',
        problems,
      );
    }
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
  Future<List<ReportEvent>> _deviceWinsEvents(
    ExerciseAggregate x,
    _Decision d,
  ) async {
    final device = (await _select('SELECT * FROM exercises WHERE id = ?', [
      x.id,
    ])).single;
    final events = <ReportEvent>[];
    final spec = schemaV8ByName['exercises']!;
    final userFields = <String, Object?>{};
    for (final c in spec.columns) {
      if (userOwnedExerciseColumns.contains(c.name)) {
        // User state: the backup's value replaces the device's.
        if (device[c.name] != x.row[c.name]) userFields[c.name] = x.row[c.name];
        continue;
      }
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
    if (userFields.isNotEmpty) d.userFieldUpdates[x.id] = userFields;
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

  /// Register B-03, owner decision (b): the device's `legacy_quarantine`
  /// rows are kept; each backup row is matched by content (the same
  /// source, record, reason, original and time is the same quarantined
  /// original, e.g. a restore of the device's own backup or a repeated
  /// restore), else inserted with its id when that id is free, else
  /// renumbered (a new autoincrement id) with the merged entries'
  /// `quarantine_id` rewritten to it.
  Future<void> _decideQuarantine(RestorePlan plan, _Decision d) async {
    final device = await _select('SELECT * FROM legacy_quarantine ORDER BY id');
    final byId = {for (final r in device) r['id']! as int: r};
    // Review O5: a device row matches at most one backup row. First the
    // same id with the same content; then the same content, each device
    // row claimed once (identical originals are counted, not merged).
    final claimed = <int>{};
    final pending = <Map<String, Object?>>[];
    for (final r in plan.legacyQuarantineRows) {
      final id = r['id'] as int?;
      final have = id == null ? null : byId[id];
      if (have != null &&
          _quarantineContent(have) == _quarantineContent(r) &&
          claimed.add(id!)) {
        d.quarantineTarget[r] = id;
        d.quarantineMap[id] = id;
      } else {
        pending.add(r);
      }
    }
    final unclaimed = <String, List<int>>{};
    for (final r in device) {
      final id = r['id']! as int;
      if (claimed.contains(id)) continue;
      unclaimed.putIfAbsent(_quarantineContent(r), () => []).add(id);
    }
    final explicitIds = <int>{};
    for (final r in pending) {
      // A row without an id (autoincrement, as v7 restore accepts it) can
      // carry no link: it is matched by content or gets a new id.
      final id = r['id'] as int?;
      final candidates = unclaimed[_quarantineContent(r)];
      if (candidates != null && candidates.isNotEmpty) {
        final same = candidates.removeAt(0);
        d.quarantineTarget[r] = same;
        if (id != null) d.quarantineMap[id] = same;
      } else if (id == null || byId.containsKey(id) || !explicitIds.add(id)) {
        d.quarantineRenumber.add(r);
      } else {
        d.quarantineTarget[r] = id;
        d.quarantineMap[id] = id;
        d.quarantineExplicit.add(r);
      }
    }
  }

  static String _quarantineContent(Map<String, Object?> r) => jsonEncode([
    r['source_table'],
    r['row_id'],
    r['reason'],
    r['original_json'],
    r['quarantined_at'],
  ]);

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
            'migration_runs ${r['id']}: $c is ${describeBackupValue(r[c])} '
            'in the backup and ${describeBackupValue(have[c])} on this device',
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
        final incoming = c.name == 'quarantine_id'
            ? d.mappedQuarantineId(r[c.name] as int?)
            : r[c.name];
        if (have[c.name] != incoming) {
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
              '$table ${spec.keyOf(r)}: ${fk.column} '
              '${describeBackupValue(v)} has no ${fk.parentTable} row in the '
              'backup or on this device',
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

  /// Inserts [rows] into [table] in order, several rows per statement
  /// (Review C M-2; rowids and autoincrement ids as with one statement per
  /// row).
  Future<void> _insert(String table, Iterable<Map<String, Object?>> rows) =>
      _io.insertMaps(table, rows);

  Future<int> _count(String table) => _io.count(table);

  Future<Map<String, int>> _write(
    RestorePlan plan,
    _Decision d, {
    required String runId,
    required String now,
  }) async {
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
      // legacy_quarantine is kept and merged (register B-03, decided).
      if (spec.kind == TableKind.user && spec.name != 'legacy_quarantine') {
        await _db.customStatement('DELETE FROM ${V8Sql.quote(spec.name)}');
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
      final rows =
          d.referenceInsert[spec.name] ?? const <Map<String, Object?>>[];
      await _insert(spec.name, rows);
      if (rows.isNotEmpty) tally(spec.name, rows.length);
    }
    await _phase(RestorePhase.referenceInserted);

    // Exercises, then each owned table: the rows of every table in the order
    // of one insert per row (exercises in backup order, their children in
    // turn); foreign keys are off, so the order across tables is free.
    await _insert('exercises', [for (final x in d.exercisesInsert) x.row]);
    if (d.exercisesInsert.isNotEmpty) {
      tally('exercises', d.exercisesInsert.length);
    }
    final childRows = <String, List<Map<String, Object?>>>{};
    for (final x in d.exercisesInsert) {
      for (final MapEntry(key: t, value: rows) in x.children.entries) {
        for (final r in rows) {
          (childRows[t] ??= []).add({
            ...r,
            if (t == 'exercise_blocks' && !r.containsKey('blocked_at'))
              'blocked_at': now,
          });
        }
      }
    }
    for (final MapEntry(key: t, value: rows) in childRows.entries) {
      await _insert(t, rows);
      if (rows.isNotEmpty) tally(t, rows.length);
    }
    for (final MapEntry(key: id, value: fields) in d.userFieldUpdates.entries) {
      final cols = fields.keys.toList();
      await _db.customStatement(
        'UPDATE exercises SET ${cols.map((c) => '"$c" = ?').join(', ')} '
        'WHERE id = ?',
        [for (final c in cols) fields[c], id],
      );
    }
    await _phase(RestorePhase.exercisesInserted);

    for (final spec in schemaV8Tables) {
      final rows = plan.userRows[spec.name] ?? const <Map<String, Object?>>[];
      await _insert(spec.name, rows);
      if (rows.isNotEmpty) tally(spec.name, rows.length);
    }
    final release1 = plan.isLegacy ? await _restoreRelease1(plan) : null;
    if (release1?.inserted ?? false) tally('catalogue_releases');
    await _phase(RestorePhase.userDataInserted);

    // Quarantine (register B-03, decided): the device's rows stay; the
    // backup's rows with a free id keep it, a colliding one gets a new id
    // (and the merged entries' links follow it), a row already on the
    // device is not written again; then the restore's new rows.
    await _insert('legacy_quarantine', d.quarantineExplicit);
    if (d.quarantineExplicit.isNotEmpty) {
      tally('legacy_quarantine', d.quarantineExplicit.length);
    }
    for (final r in d.quarantineRenumber) {
      final id = await _db.customInsert(
        'INSERT INTO legacy_quarantine (source_table, row_id, reason, '
        'original_json, quarantined_at) VALUES (?, ?, ?, ?, ?)',
        variables: [
          for (final c in [
            'source_table',
            'row_id',
            'reason',
            'original_json',
            'quarantined_at',
          ])
            Variable.withString(r[c]! as String),
        ],
      );
      d.quarantineTarget[r] = id;
      if (r['id'] case final int old) d.quarantineMap[old] = id;
      tally('legacy_quarantine');
    }
    final preV8Quarantine = <Map<String, Object?>>[
      for (final r in plan.legacyQuarantineRows)
        {...r, 'id': d.quarantineTarget[r]},
    ];
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
    await _insert('migration_runs', [
      for (final r in d.runsInsert)
        if (r['provenance_kind'] == 'device')
          {
            ...r,
            'provenance_kind': 'backup',
            'provenance_source': plan.backupIdentity,
            'merged_at': now,
          }
        else
          r,
    ]);
    if (d.runsInsert.isNotEmpty) tally('migration_runs', d.runsInsert.length);
    await _insert('migration_report_counts', d.countsInsert);
    if (d.countsInsert.isNotEmpty) {
      tally('migration_report_counts', d.countsInsert.length);
    }
    await _insert('migration_report_entries', [
      for (final r in d.entriesInsert)
        {
          ...r,
          'quarantine_id': switch (r['quarantine_id']) {
            final int q => d.quarantineMap[q] ?? (throw StateError('link $q')),
            _ => null,
          },
        },
    ]);
    if (d.entriesInsert.isNotEmpty) {
      tally('migration_report_entries', d.entriesInsert.length);
    }
    await _phase(RestorePhase.reportMerged);

    final restoreRuns = await _writeRestoreReport(
      plan,
      d,
      runId: runId,
      now: now,
      preV8Quarantine: preV8Quarantine,
      quarantineIds: quarantineIds,
      release1: release1,
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
          before['legacy_quarantine']! +
          d.quarantineExplicit.length +
          d.quarantineRenumber.length +
          _quarantineToWrite(plan, d).length,
      'exercises': keptSystem + d.exercisesInsert.length,
      for (final t in exerciseChildTables)
        t:
            keptSystemChildren[t]! +
            d.exercisesInsert.fold(0, (s, x) => s + x.children[t]!.length),
      for (final spec in schemaV8Tables)
        if (spec.kind == TableKind.reference)
          spec.name:
              before[spec.name]! +
              (d.referenceInsert[spec.name] ?? const []).length +
              (spec.name == 'catalogue_releases' &&
                      (release1?.inserted ?? false)
                  ? 1
                  : 0),
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

  /// Release 1 of a restored v7 backup (owner decision R-30 / B-07 option
  /// b: "restored v7 backups follow the same rule" as the migration). Null
  /// when the backup holds no `seedExercisesVersion` setting (nothing
  /// examined). When it parses to 1 or more:
  /// - the device already records release 1 of `repforge` → nothing (the
  ///   device's release log wins, B-04);
  /// - else the bundled seed bytes hash to the pinned v7-era value → one
  ///   row: `applied_at` = the setting's `updated_at` verbatim,
  ///   `applied_at_source` = the migration's, counts and `app_version` NULL
  ///   (not known, never 0);
  /// - else (another hash, or bytes that cannot be loaded) → no record and
  ///   the migration's R-30 warning on the setting.
  Future<({ReportEvent? warning, bool inserted})?> _restoreRelease1(
    RestorePlan plan,
  ) async {
    Map<String, Object?>? setting;
    for (final r
        in plan.userRows['settings'] ?? const <Map<String, Object?>>[]) {
      if (r['key'] == V7ToV8Migration.seedExercisesVersionKey) setting = r;
    }
    if (setting == null) return null;
    final value = setting['value'];
    final applied = value is String ? (int.tryParse(value) ?? 0) : 0;
    if (applied < 1) return (warning: null, inserted: false);
    final recorded = await _select(
      'SELECT 1 FROM catalogue_releases WHERE provider_id = ? AND '
      '"release" = 1',
      [BootstrapReferenceV8.providerId],
    );
    if (recorded.isNotEmpty) return (warning: null, inserted: false);
    final seed = await V7ToV8Migration.seedHash(config.loadSeedBytes);
    if (seed.hash case final hash? when hash == V7ToV8Migration.v7SeedSha256) {
      await _insert('catalogue_releases', [
        V7ToV8Migration.release1Row(
          appliedAt: setting['updated_at'],
          hash: hash,
        ),
      ]);
      return (warning: null, inserted: true);
    }
    // The migration's warning, word for word (shared; Review C L-3).
    return (
      warning: V7ToV8Migration.release1Warning(
        value: value,
        hash: seed.hash,
        loadError: seed.loadError,
      ),
      inserted: false,
    );
  }

  /// Every foreign-key violation in the database, keyed by table, record,
  /// columns and parent as the migration keys its findings (shared; Review C
  /// L-3).
  Future<Set<String>> _foreignKeyFindings() async => {
    for (final v in await _io.foreignKeyViolations(await _io.userTables()))
      v.key(V7ToV8Migration.foreignKeyRule),
  };

  Future<({int runs, int entries, int counts})> _writeRestoreReport(
    RestorePlan plan,
    _Decision d, {
    required String runId,
    required String now,
    required List<Map<String, Object?>> preV8Quarantine,
    required Map<String, int> quarantineIds,
    required ({ReportEvent? warning, bool inserted})? release1,
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
    if (release1 != null) {
      // The seed setting, examined as the migration examines it (R-30).
      builder.examine(
        table: V7ToV8Migration.settingsTable,
        recordId: V7ToV8Migration.seedExercisesVersionKey,
        cleanOutcome: ReportCategory.preserved,
        events: [?release1.warning],
      );
      examined[V7ToV8Migration.settingsTable] = 1;
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
    await _insert('migration_runs', [
      {
        'id': runId,
        'trigger_kind': 'restore',
        'from_version': plan.schemaVersion,
        'to_version': backupSchemaV8,
        'generated_at': now,
        'app_version': config.appVersion,
        'provenance_kind': 'backup',
        'provenance_source': plan.backupIdentity,
        'merged_at': now,
      },
    ]);
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
      await _insert('migration_runs', [
        {
          'id': integrity.run.runId,
          'trigger_kind': 'integrityCheck',
          'from_version': null,
          'to_version': null,
          'generated_at': now,
          'app_version': config.appVersion,
          'provenance_kind': 'device',
          'provenance_source': config.installLabel,
          'merged_at': null,
        },
      ]);
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
      final column = V8Sql.quote(r.column);
      final rows = await _select(
        'SELECT ${pk.map(V8Sql.quote).join(', ')}, $column AS ref '
        'FROM ${V8Sql.quote(r.table)} t WHERE t.$column IS NOT NULL AND NOT '
        'EXISTS (SELECT 1 FROM exercises e WHERE e.id = t.$column)',
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

  /// Writes the entries and counts of [report] with the migration's writer
  /// (shared; Review C L-3): both count dimensions for every examined table,
  /// zeros included.
  Future<({int entries, int counts})> _writeReport(
    MigrationReport report,
    Map<String, int> quarantineIds,
    Map<String, String> exerciseOf,
  ) async {
    final w = await V7ToV8Migration.writeReportRows(
      _io,
      report,
      quarantineIds,
      exerciseOf,
    );
    return (entries: w.entries.length, counts: w.counts.length);
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

/// The catalogue completeness rules of `validateExercise` that a restore
/// does not apply (register B-15): the classifications a system exercise
/// needs before a catalogue tranche (IC-205 patterns, IC-207 mechanics,
/// IC-208 laterality, IC-209 difficulty, IC-211 aliases) and the recorded
/// author (IC-212 on `provenance`, which v8 does not store). Of IC-201 only
/// the 60-character limit is exempt (review O2): an empty name rejects.
/// Release 1 content, migrated from v7, has none of them, so applying them
/// would refuse every migrated device's own backup. They stay the catalogue
/// release's checks (3c).
const Set<String> restoreExemptCompletenessCodes = {
  'IC-205',
  'IC-207',
  'IC-208',
  'IC-209',
  'IC-211',
};

/// The domain problems of one exercise a format 3 restore would insert
/// (review H1; B-15 accepted conditionally). Empty when it may be restored.
///
/// - Every error-severity finding of `validateExercise` (system or
///   user/imported rules, as the domain splits them) rejects, except the
///   completeness rules in [restoreExemptCompletenessCodes], the IC-201
///   length limit of a non-empty name and IC-212 on `provenance`; IC-315 is
///   reported by its own check. IC-101 (system id pattern) rejects (B-15:
///   the owner's choice on the migration's IC-101 rows is pending).
/// - A **user** exercise with an unresolved `noPrimaryTarget` block row in
///   the backup is valid as blocked: its IC-204 is excused, nothing else.
///   `system` and `imported` exercises are never excused.
/// - Unreadable data (decision of 2026-11-06): an exercise whose stored
///   `type`, `category` or `aliases_json` is not a domain value is valid
///   only while blocked for it (an unresolved `invalidClassification` or
///   `invalidAliases` row), so a restore never makes hidden information
///   newly visible; its other rules are still checked, with a placeholder
///   for the unreadable value (review O4).
List<String> restoreDomainProblems(
  ExerciseAggregate x,
  ExerciseRuleContext ctx,
) {
  final where = 'exercises ${x.id}';
  for (final c in ['created_at', 'updated_at', 'retired_at']) {
    final v = x.row[c];
    if (v is String && DateTime.tryParse(v) == null) {
      return ['$where: $c ${describeBackupValue(v)} is not a date-time'];
    }
  }
  final active = {
    for (final b in x.blocks)
      if (b['resolved_at'] == null) b['reason'],
  };
  final unblocked = [
    for (final reason in unreadableBlockReasons(x))
      if (!active.contains(reason.name)) reason.name,
  ];
  if (unblocked.isNotEmpty) {
    final problem =
        '$where: its type, category or aliases are not domain values and it '
        'has no unresolved ${unblocked.join(' or ')} block row (restoring '
        'it would make hidden information visible)';
    return [problem];
  }
  final e = catalogueExerciseOf(x, placeholders: true);
  if (e == null) return ['$where: it cannot be read in the domain'];
  final named = (x.row['name']! as String).trim().isNotEmpty;
  final blockedNoPrimary =
      x.source == 'user' && active.contains(BlockReason.noPrimaryTarget.name);
  return [
    for (final f in validateExercise(e, ctx))
      if (f.severity == Severity.error &&
          f.code != 'IC-315' &&
          !restoreExemptCompletenessCodes.contains(f.code) &&
          !(f.code == 'IC-201' && named) &&
          !(f.code == 'IC-212' && f.field == 'provenance') &&
          !(f.code == 'IC-204' && blockedNoPrimary))
        '$where: ${f.message} (${f.code})',
  ];
}

/// The user-owned columns of `exercises` (B-01, decided 2026-11-06):
/// user archiving (R-24) and the user's own deletion (`deleted_at`; a
/// catalogue never deletes, it retires). On a system exercise kept from the
/// device they take the backup's value; every other column and owned row is
/// catalogue content and stays the device's.
const Set<String> userOwnedExerciseColumns = {'archived', 'deleted_at'};

/// What phase 1b decided.
final class _Decision {
  final Map<String, List<Map<String, Object?>>> referenceInsert = {};
  final Map<String, Map<String, List<ReportEvent>>> referenceWarnings = {};
  final List<ExerciseAggregate> exercisesInsert = [];
  final Map<String, List<ReportEvent>> deviceWins = {};
  final List<Map<String, Object?>> runsInsert = [];
  final List<Map<String, Object?>> entriesInsert = [];
  final List<Map<String, Object?>> countsInsert = [];

  /// User fields of a device-kept system exercise taken from the backup
  /// (B-01), by exercise id.
  final Map<String, Map<String, Object?>> userFieldUpdates = {};

  /// Backup `legacy_quarantine` id → id on this device after the restore
  /// (register B-03): the matching device row, the same id, or (after
  /// phase 2 inserts it) the new id of a renumbered row.
  final Map<int, int> quarantineMap = {};

  /// Each backup `legacy_quarantine` row (by identity) → its id on this
  /// device after the restore.
  final Map<Map<String, Object?>, int> quarantineTarget = Map.identity();
  final List<Map<String, Object?>> quarantineExplicit = [];
  final List<Map<String, Object?>> quarantineRenumber = [];

  /// The link a merged entry will hold; for a row still to be renumbered
  /// the id is not known yet, so it can never equal a stored link.
  Object? mappedQuarantineId(int? q) =>
      q == null ? null : (quarantineMap[q] ?? 'renumbered:$q');
  int bootstrapMissing = 0;
}
