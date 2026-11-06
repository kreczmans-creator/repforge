import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/isolate.dart' show DriftRemoteException;
import 'package:meta/meta.dart';
import 'package:repforge/data/db/migration/bootstrap_reference_v8.dart';
import 'package:repforge/data/db/migration/historical_steps.dart'
    show MigrationStep;
import 'package:repforge/data/db/migration/schema_v8_shapes.g.dart';
import 'package:repforge/data/db/migration/schema_versions.g.dart' show Schema7;
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/library/integrity_preflight.dart';
import 'package:repforge/domain/library/legacy_v8_mapping.dart';
import 'package:repforge/domain/library/migration_report.dart';
import 'package:repforge/domain/library/sha256_hex.dart';

/// The v7 → v8 migration step (WP 8 sub-stage 3b-4). **Not connected to the
/// app**: only `AppDatabaseV8` uses it, and production stays on
/// `AppDatabase` at schema version 7 (D04 section 7, 2026-11-06).
///
/// Run by `RepforgeMigration` (`repforge_migration.dart`) after the
/// historical steps v1 → v7, inside the step's single transaction, with
/// foreign keys switched off before the transaction and verified off
/// (safeguard A). `PRAGMA user_version = 8` is the last statement of that
/// transaction, so a failure anywhere leaves the database at version 7 with
/// every row as it was.
///
/// What it does, in order (each a [V8MigrationPhase]):
/// 1. preflight ([V7ToV8Migration.preflight], before any transaction):
///    `PRAGMA quick_check` decided by the WS4 [evaluateIntegrityPreflight];
///    on failure it throws [IntegrityPreflightFailure] and writes nothing;
/// 2. baseline: every foreign-key violation and every unresolved exercise
///    reference (IC-901 to IC-903), keyed by primary key;
/// 3. the v8 tables and indexes that do not exist yet ([Schema8]);
/// 4. the run rows: the migration run (its id from the [MigrationRunLedger]:
///    reused when an earlier attempt failed, new otherwise; R-07) and its
///    integrity-check companion run;
/// 5. the reference bootstrap ([BootstrapReferenceV8], device wins, R-23);
/// 6. every exercise through the WS4 [mapLegacyExercise]: quarantine of
///    originals that do not convert faithfully, targets (contiguous, R-11),
///    equipment links (ADR-0008 B), blocks (R-01, R-02);
/// 7. `exercises` rebuilt (option A, drift `TableMigration`): the legacy
///    columns are dropped, `source`, `provider_id` and `revision` come from
///    the mapping (R-14, R-15);
/// 8. every set through the WS4 [classifyLegacyExertion]: the original pair
///    of an offending set is quarantined, both columns cleared (R-28), and
///    `session_sets` rebuilt with the TRN-020 CHECK;
/// 9. release 1 of provider `repforge` when the v7 seed was applied
///    (`seedExercisesVersion`, plan section 6 step 9), hashed from the exact
///    bundled seed bytes (R-10);
/// 10. the broader integrity review: damage that existed before the step is
///    reported in the integrity run, never blocks;
/// 11. the report of both runs (entries and counts by category and
///    disposition) through the WS4 [MigrationReportBuilder];
/// 12. the targeted foreign-key check: any violation or unresolved reference
///    not in the baseline aborts the step;
/// 13. self-checks: both reports reconcile ([reconcileReport], including the
///    mapping's own block and quarantine lists), row counts of the rebuilt
///    tables are unchanged, the stored report equals the built one.
///
/// Nothing is invented, inferred, rounded, corrected or deleted: every value
/// that does not migrate one to one stays in `legacy_quarantine` and has its
/// own report entry; blocked exercises keep their id, row and history.

// ---------------------------------------------------------------------------
// Errors.

/// The integrity preflight stopped the upgrade (D04 section 7, 2026-11-06,
/// "Damaged database at upgrade"): nothing was written and the database
/// stays at [PreflightOutcome.schemaVersion].
final class IntegrityPreflightFailure implements Exception {
  const IntegrityPreflightFailure(this.outcome);

  /// The WS4 decision, its verbatim diagnostics and the user message.
  final PreflightOutcome outcome;

  @override
  String toString() =>
      'IntegrityPreflightFailure: quick_check failed at schema version '
      '${outcome.schemaVersion}; nothing was changed. '
      '${outcome.diagnostics.join(' | ')}';
}

/// Why the v8 step refused or aborted. The step's transaction rolls back, so
/// the database stays at version 7 with every row as it was.
enum V8MigrationFailureKind {
  /// A foreign-key violation or unresolved reference that was not in the
  /// pre-migration baseline (safeguard A).
  newIntegrityViolation,

  /// A self-check failed: the report does not reconcile, a rebuilt table
  /// changed its row count, or a stored value differs from the mapping.
  selfCheckFailed,

  /// The database is in a state the step does not recognise (for example
  /// `exercises` already in the v8 shape without a recorded v8 run).
  unexpectedState,

  /// An option that needs an owner decision first was switched on.
  unsupportedOption,
}

/// The v8 step failed; [details] lists every finding, in full.
final class V8MigrationFailure implements Exception {
  V8MigrationFailure(this.kind, List<String> details)
    : details = List.unmodifiable(details);

  final V8MigrationFailureKind kind;
  final List<String> details;

  @override
  String toString() =>
      'V8MigrationFailure(${kind.name}): ${details.join('; ')}';
}

/// [error] with every [DriftRemoteException] layer removed: drift wraps an
/// error raised in a background isolate (for example the SQLite error of a
/// damaged file) in one, keeping the original as `remoteCause`.
Object unwrapRemoteError(Object error) {
  var e = error;
  while (e is DriftRemoteException) {
    e = e.remoteCause;
  }
  return e;
}

/// The [IntegrityPreflightFailure] behind [error], if any, also when drift
/// delivered it wrapped in a [DriftRemoteException].
IntegrityPreflightFailure? findIntegrityPreflightFailure(Object error) {
  final e = unwrapRemoteError(error);
  return e is IntegrityPreflightFailure ? e : null;
}

/// Runs `PRAGMA quick_check` on [db]: the rows verbatim, or the error
/// message (unwrapped from [DriftRemoteException]) when the pragma cannot
/// run, for example on a file that is not a database.
Future<QuickCheckResult> runQuickCheck(DatabaseConnectionUser db) async {
  try {
    final rows = await db.customSelect('PRAGMA quick_check').get();
    return QuickCheckRows([
      for (final r in rows)
        '${r.data.values.isEmpty ? '' : r.data.values.first}',
    ]);
  } on Object catch (error) {
    final cause = unwrapRemoteError(error);
    return QuickCheckError(cause.toString());
  }
}

// ---------------------------------------------------------------------------
// Run id ledger (R-07).

/// A migration run that has been started and may not have committed: its id
/// and generation time, and what it is bound to. It is reused only by an
/// attempt on the same database (canonical path and header fingerprint)
/// with the same app version.
@immutable
final class PendingMigrationRun {
  const PendingMigrationRun({
    required this.runId,
    required this.generatedAt,
    required this.database,
    required this.fingerprint,
    required this.appVersion,
  });

  PendingMigrationRun.fromJson(Map<String, Object?> json)
    : this(
        runId: json['runId']! as String,
        generatedAt: json['generatedAt']! as String,
        database: json['database']! as String,
        fingerprint: json['fingerprint']! as String,
        appVersion: json['appVersion']! as String,
      );

  final String runId;

  /// ISO-8601 UTC text, as stored in `migration_runs.generated_at`.
  final String generatedAt;

  /// Canonical path of the database file (empty for an in-memory database).
  final String database;

  /// The database file's fingerprint when the step started, before its
  /// first write (`V7ToV8Migration.fileFingerprint`: header hash, length and
  /// a hash of every byte). A rolled-back attempt restores the file, so a
  /// retry sees the same value; another file, or the same file after any
  /// committed change, does not.
  final String fingerprint;

  /// The app version that started the run.
  final String appVersion;

  /// True when an attempt on [database] with [fingerprint] by [appVersion]
  /// may resume this run.
  bool binds({
    required String database,
    required String fingerprint,
    required String appVersion,
  }) =>
      this.database == database &&
      this.fingerprint == fingerprint &&
      this.appVersion == appVersion;

  Map<String, Object?> toJson() => {
    'runId': runId,
    'generatedAt': generatedAt,
    'database': database,
    'fingerprint': fingerprint,
    'appVersion': appVersion,
  };

  @override
  bool operator ==(Object other) =>
      other is PendingMigrationRun &&
      jsonEncode(other.toJson()) == jsonEncode(toJson());

  @override
  int get hashCode => jsonEncode(toJson()).hashCode;
}

/// Keeps the run id of a started migration **outside** the database (owner
/// decision R-07: a resumed migration reuses its run id; a genuinely new
/// attempt gets a new one). Register R-32 (owner confirmation requested).
///
/// The migration is atomic, so a failed attempt leaves nothing in the
/// database, its run row included; the id must therefore live elsewhere to
/// survive a crash or a process kill. The step writes the pending run before
/// its first database write; the database class clears it after the commit
/// and, at every open of a v8 database, clears an entry whose run id is
/// recorded in `migration_runs` (a process that died between the commit and
/// the clear).
///
/// Entries are keyed by upgrade and database. **Resumed**: a further attempt
/// of the same upgrade on the same database (canonical path and header
/// fingerprint, [PendingMigrationRun.binds]) by the same app version.
/// **Genuinely new**: anything else (no entry, another file at that path,
/// changed content, another app version); its new run overwrites the entry.
abstract interface class MigrationRunLedger {
  /// The pending run of the upgrade [from] → [to] on [database], or null.
  /// Throws [MigrationRunLedgerFailure] when the ledger cannot be read.
  Future<PendingMigrationRun?> read(int from, int to, String database);

  /// Records [run] durably as the pending run of [from] → [to] on
  /// [PendingMigrationRun.database], replacing any earlier one.
  Future<void> write(int from, int to, PendingMigrationRun run);

  /// Forgets the pending run of [from] → [to] on [database].
  Future<void> clear(int from, int to, String database);
}

/// The run ledger cannot be read or written. Nothing in the database was
/// changed. [recoveryRoute] says what to do.
final class MigrationRunLedgerFailure implements Exception {
  const MigrationRunLedgerFailure(this.location, this.cause);

  /// Where the ledger lives (a file path).
  final String location;

  /// What went wrong, verbatim.
  final String cause;

  /// The recovery route: the ledger holds no user data, only the id of an
  /// unfinished migration attempt.
  String get recoveryRoute =>
      'The migration run ledger at $location holds no user data. Move it '
      'aside (or delete it) and open the database again: the next attempt '
      'starts as a new run with a new run id (R-07). The database itself was '
      'not changed.';

  @override
  String toString() =>
      'MigrationRunLedgerFailure: $location: $cause. $recoveryRoute';
}

String _ledgerKey(int from, int to, String database) =>
    jsonEncode([from, to, database]);

/// A [MigrationRunLedger] in memory: survives a failed attempt within one
/// process only. For tests and hosts that cannot store a file.
final class InMemoryMigrationRunLedger implements MigrationRunLedger {
  final Map<String, PendingMigrationRun> _runs = {};

  @override
  Future<PendingMigrationRun?> read(int from, int to, String database) async =>
      _runs[_ledgerKey(from, to, database)];

  @override
  Future<void> write(int from, int to, PendingMigrationRun run) async =>
      _runs[_ledgerKey(from, to, run.database)] = run;

  @override
  Future<void> clear(int from, int to, String database) async =>
      _runs.remove(_ledgerKey(from, to, database));
}

/// A [MigrationRunLedger] in a small JSON file. A write goes to a temporary
/// file with a unique name in the same directory, flushed, then renamed over
/// the ledger, so a crash leaves either the old or the new content. The file
/// is deleted when its last entry is cleared.
///
/// Limitation (Review B, L1): `dart:io` cannot fsync a directory, so after a
/// power loss the rename itself may be lost. Then the ledger holds the
/// previous content or none; the worst outcome is a new run id for a retry
/// (a genuinely new attempt), never the reuse of a wrong one, because every
/// entry is bound to its database ([PendingMigrationRun.binds]).
final class FileMigrationRunLedger implements MigrationRunLedger {
  FileMigrationRunLedger(this.file);

  final File file;

  /// Identifies the file format; a change needs a new tag.
  static const String scheme = 'repforge.migrationRunLedger/2';

  Map<String, Object?> _runs() {
    if (!file.existsSync()) return <String, Object?>{};
    final Object? decoded;
    try {
      decoded = jsonDecode(file.readAsStringSync());
    } on Object catch (e) {
      throw MigrationRunLedgerFailure(file.path, 'unreadable: $e');
    }
    if (decoded is! Map<String, Object?> ||
        decoded['scheme'] != scheme ||
        decoded['runs'] is! Map<String, Object?>) {
      throw MigrationRunLedgerFailure(
        file.path,
        'not a migration run ledger ($scheme)',
      );
    }
    return Map.of(decoded['runs']! as Map<String, Object?>);
  }

  /// Removes temporary files of earlier writes that a crash left behind
  /// (`<ledger>.<pid>.<time>.tmp`; Review B re-check, N7).
  void _removeStaleTemporaries() {
    final dir = file.parent;
    if (!dir.existsSync()) return;
    final name = file.uri.pathSegments.last;
    final stale = RegExp('^${RegExp.escape(name)}\\.\\d+\\.\\d+\\.tmp\$');
    for (final f in dir.listSync().whereType<File>()) {
      if (stale.hasMatch(f.uri.pathSegments.last)) {
        try {
          f.deleteSync();
        } on FileSystemException {
          // Another writer's file in use; left for the next write.
        }
      }
    }
  }

  void _save(Map<String, Object?> runs) {
    if (runs.isEmpty) {
      if (file.existsSync()) file.deleteSync();
      return;
    }
    _removeStaleTemporaries();
    final tmp = File(
      '${file.path}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      tmp
        ..writeAsStringSync(
          jsonEncode({'scheme': scheme, 'runs': runs}),
          flush: true,
        )
        ..renameSync(file.path);
    } on FileSystemException catch (e) {
      if (tmp.existsSync()) tmp.deleteSync();
      throw MigrationRunLedgerFailure(file.path, 'not writable: $e');
    }
  }

  @override
  Future<PendingMigrationRun?> read(int from, int to, String database) async {
    final entry = _runs()[_ledgerKey(from, to, database)];
    if (entry == null) return null;
    try {
      return PendingMigrationRun.fromJson(entry as Map<String, Object?>);
    } on Object catch (e) {
      throw MigrationRunLedgerFailure(file.path, 'malformed entry: $e');
    }
  }

  @override
  Future<void> write(int from, int to, PendingMigrationRun run) async {
    final runs = _runs();
    runs[_ledgerKey(from, to, run.database)] = run.toJson();
    _save(runs);
  }

  @override
  Future<void> clear(int from, int to, String database) async {
    final runs = _runs();
    if (runs.remove(_ledgerKey(from, to, database)) != null) _save(runs);
  }
}

// ---------------------------------------------------------------------------
// Configuration.

/// Maps one v7 exercise row; the production value is the WS4
/// [mapLegacyExercise].
typedef LegacyExerciseMapper = LegacyExerciseMapping Function(
  LegacyExerciseRow row, {
  LegacyMappingOptions options,
});

/// Inputs of the v8 step. Nothing here has a production default: the app
/// does not use v8 yet.
@immutable
final class V8MigrationConfig {
  const V8MigrationConfig({
    required this.clock,
    required this.appVersion,
    required this.installLabel,
    required this.loadSeedBytes,
    required this.runLedger,
    required this.newRunId,
    this.mappingOptions = const LegacyMappingOptions(),
  }) : quickCheck = null,
       mapExercise = mapLegacyExercise,
       fingerprint = V7ToV8Migration.fileFingerprint;

  /// The same inputs plus the test seams (Review B, L10).
  @visibleForTesting
  const V8MigrationConfig.forTesting({
    required this.clock,
    required this.appVersion,
    required this.installLabel,
    required this.loadSeedBytes,
    required this.runLedger,
    required this.newRunId,
    this.mappingOptions = const LegacyMappingOptions(),
    this.quickCheck,
    this.mapExercise = mapLegacyExercise,
    this.fingerprint = V7ToV8Migration.fileFingerprint,
  });

  /// Time of a new run; a resumed run keeps its first time.
  final Clock clock;

  /// `migration_runs.app_version` (R-08).
  final String appVersion;

  /// `migration_runs.provenance_source` of a device run: a stable install or
  /// source label (R-08).
  final String installLabel;

  /// The exact bytes of the bundled seed `assets/seed/exercise_library.json`
  /// (the app reads them from the asset bundle; R-10: nothing re-serialised).
  final Future<List<int>> Function() loadSeedBytes;

  /// Where the run id of a started attempt is kept (R-07).
  final MigrationRunLedger runLedger;

  /// A new, unique run id (for example a UUID).
  final String Function() newRunId;

  /// **OPEN (WS4 review H1 and L9, owner decision pending).** The single
  /// visibility switch of the mapping, [LegacyMappingOptions.
  /// blockInvalidSecondaryTargets]; default false. v8 has no block reason
  /// for it (`exercise_blocks` allows three reasons), so the step refuses to
  /// run with it on until the owner decides and the schema follows.
  final LegacyMappingOptions mappingOptions;

  /// Test seam ([V8MigrationConfig.forTesting] only): replaces
  /// `PRAGMA quick_check` with an injected result.
  final Future<QuickCheckResult> Function(DatabaseConnectionUser db)?
  quickCheck;

  /// Test seam ([V8MigrationConfig.forTesting] only): the mapping of one
  /// exercise; [mapLegacyExercise] otherwise.
  final LegacyExerciseMapper mapExercise;

  /// Test seam ([V8MigrationConfig.forTesting] only): the database file
  /// fingerprint; [V7ToV8Migration.fileFingerprint] otherwise.
  final String Function(File file) fingerprint;
}

/// The checkpoints of the v8 step, in order. A [V8PhaseProbe] that throws at
/// one of them rolls the whole step back.
enum V8MigrationPhase {
  started,
  baselineTaken,
  tablesCreated,
  runRecorded,
  bootstrapInserted,
  exercisesMapped,
  exercisesRebuilt,
  exerciseLinksWritten,
  setsClassified,
  setsRebuilt,
  releaseRecorded,
  integrityReviewed,
  reportWritten,
  foreignKeysChecked,
  selfChecked,
}

/// Observes the v8 step at each [V8MigrationPhase] (failure and kill tests).
typedef V8PhaseProbe = Future<void> Function(V8MigrationPhase phase);

// ---------------------------------------------------------------------------
// The step.

/// The v7 → v8 step and its preflight. One instance per database open.
final class V7ToV8Migration {
  V7ToV8Migration(this.config, {this.phaseProbe});

  final V8MigrationConfig config;

  /// Test seam (null in the app).
  @visibleForTesting
  final V8PhaseProbe? phaseProbe;

  /// Report table of the v6-era quarantine rows (plan section 6 step 7).
  static const String legacyQuarantineTable = 'legacy_quarantine';

  /// Field of a v6-era quarantine entry.
  static const String legacyQuarantineField = 'original_json';

  /// Rule of a declared foreign key that does not resolve. **Awaits owner
  /// confirmation as a report rule code** (like WS4 N3): the check that
  /// applied, `PRAGMA foreign_key_check`.
  static const String foreignKeyRule = 'foreign_key_check';

  /// Suffix of the integrity run that accompanies a migration run.
  static const String integrityRunSuffix = ':integrity';

  /// The v8 step for drift's dispatcher (`schema_v8_shapes.g.dart`).
  MigrationStep get steps => migrationSteps(from7To8: from7To8);

  /// The integrity preflight (D04 section 7, 2026-11-06): `quick_check`
  /// through the WS4 decision. Throws [IntegrityPreflightFailure] when it
  /// fails; runs before any transaction and writes nothing. Also refuses an
  /// option that waits for an owner decision.
  Future<void> preflight(DatabaseConnectionUser db, int from, int to) async {
    if (config.mappingOptions.blockInvalidSecondaryTargets) {
      throw V8MigrationFailure(V8MigrationFailureKind.unsupportedOption, [
        _unsupportedSecondaryBlock,
      ]);
    }
    final result = await (config.quickCheck ?? runQuickCheck)(db);
    final outcome = evaluateIntegrityPreflight(
      schemaVersion: from,
      result: result,
    );
    if (!outcome.mayMigrate) throw IntegrityPreflightFailure(outcome);
  }

  /// The database the step ran on (canonical path), once it ran.
  String? _database;

  /// Forgets the pending run after a committed upgrade. A failure here never
  /// fails the open (Review B, L2): the entry is cleared at the next open
  /// ([forgetCommittedRun]), and it can never be reused by another database.
  Future<void> completed() async {
    final database = _database;
    if (database == null || database.isEmpty) return;
    try {
      await config.runLedger.clear(7, 8, database);
    } on Object {
      // Ignored on purpose; see above.
    }
  }

  /// At every open of a v8 database: clears the ledger entry of this
  /// database when its run id is recorded in `migration_runs` (a process that
  /// died between the commit and [completed]). Never fails the open.
  Future<void> forgetCommittedRun(DatabaseConnectionUser db) async {
    try {
      // Only the path: a v8 open never reads the database file (Review B
      // re-check, N1).
      final database = await databasePath(db);
      if (database.isEmpty) return;
      final pending = await config.runLedger.read(7, 8, database);
      if (pending == null) return;
      final io = _Sql(db);
      if (!await io.tableExists('migration_runs')) return;
      final recorded = await io.select(
        'SELECT 1 FROM migration_runs WHERE id = ?',
        [pending.runId],
      );
      if (recorded.isNotEmpty) {
        await config.runLedger.clear(7, 8, database);
      }
    } on Object {
      // A ledger problem never blocks a v8 database; the next upgrade
      // attempt (there is none for a v8 database) would report it.
    }
  }

  /// The names of the v8 tables and indexes that a v7 database never has:
  /// the generated `Schema8` entities minus the frozen `Schema7` snapshot
  /// (Review B re-check, N5).
  static Set<String> v8OnlyEntityNames(GeneratedDatabase db) => {
    for (final e in Schema8(database: db).entities) e.entityName,
  }.difference({for (final e in Schema7(database: db).entities) e.entityName});

  /// The canonical path of [db]'s main file (`PRAGMA database_list`);
  /// empty for an in-memory database.
  static Future<String> databasePath(DatabaseConnectionUser db) async {
    final rows = await _Sql(db).select('PRAGMA database_list');
    final main = rows.firstWhere((r) => r['name'] == 'main');
    final path = '${main['file'] ?? ''}';
    if (path.isEmpty) return '';
    final file = File(path);
    return file.existsSync()
        ? file.resolveSymbolicLinksSync()
        : file.absolute.path;
  }

  /// The fingerprint of a database file before the step's first write:
  /// SHA-256 (lowercase hex) of its 100-byte header, its length and a
  /// 64-bit FNV-1a over all its bytes, plus the same over `<file>-wal` when
  /// one exists.
  ///
  /// Assumption (Review B re-check, N4): the database runs in rollback
  /// journal mode (`delete`, SQLite's default; neither the app nor
  /// drift_flutter switches to WAL). A rolled-back attempt then restores the
  /// file exactly (the journal restores every page and the size), so a
  /// retry sees the same value; another file, or the same file after any
  /// committed change, does not. In WAL mode committed pages may sit in the
  /// `-wal` file, which is why it is included when present. Not a security
  /// digest: it only tells attempts on different databases apart.
  static String fileFingerprint(File file) {
    final main = _digestFile(file, withHeader: true);
    final wal = File('${file.path}-wal');
    return wal.existsSync()
        ? '$main:wal:${_digestFile(wal, withHeader: false)}'
        : main;
  }

  static String _digestFile(File file, {required bool withHeader}) {
    final raf = file.openSync();
    try {
      final header = withHeader ? raf.readSync(100) : const <int>[];
      raf.setPositionSync(0);
      var h = _fnvOffset;
      var length = 0;
      while (true) {
        final chunk = raf.readSync(1 << 20);
        if (chunk.isEmpty) break;
        length += chunk.length;
        for (final b in chunk) {
          h = (h ^ b) * _fnvPrime;
        }
      }
      return '${withHeader ? '${sha256Hex(header)}:' : ''}$length:'
          '${(h >>> 32).toRadixString(16).padLeft(8, '0')}'
          '${(h & 0xffffffff).toRadixString(16).padLeft(8, '0')}';
    } finally {
      raf.closeSync();
    }
  }

  /// 0xcbf29ce484222325 and 0x100000001b3: 64-bit FNV-1a.
  static const int _fnvOffset = (0xcbf29ce4 << 32) | 0x84222325;
  static const int _fnvPrime = 0x100000001b3;

  Future<void> _phase(V8MigrationPhase phase) async {
    final p = phaseProbe;
    if (p != null) await p(phase);
  }

  /// The step itself (runs inside `RepforgeMigration`'s transaction).
  Future<void> from7To8(Migrator m, Schema8 s) async {
    final db = m.database;
    final io = _Sql(db);

    // Guard: a database whose work is complete writes nothing again.
    if (!await io.columnExists('exercises', 'primary_muscle')) {
      if (await io.tableExists('migration_runs') &&
          (await db
                  .customSelect(
                    'SELECT 1 FROM migration_runs WHERE trigger_kind = '
                    "'migration' AND from_version = 7 AND to_version = 8",
                  )
                  .get())
              .isNotEmpty) {
        return;
      }
      throw V8MigrationFailure(V8MigrationFailureKind.unexpectedState, [
        _unexpectedV8Shape,
      ]);
    }

    // v8 tables or indexes in a v7 database: a state the step does not
    // recognise (Review B, L6).
    final v8Only = v8OnlyEntityNames(db);
    final foreign = [
      for (final e in s.entities)
        if (v8Only.contains(e.entityName) &&
            await io.entityExists(e is Index ? 'index' : 'table', e.entityName))
          e.entityName,
    ];
    if (foreign.isNotEmpty) {
      throw V8MigrationFailure(V8MigrationFailureKind.unexpectedState, [
        'v7 database already holds v8 entities: ${foreign.join(', ')}',
      ]);
    }

    // The run id, before the first write (R-07, R-32): reused only when an
    // earlier attempt on this database, with this content and app version,
    // did not commit; otherwise a new run that replaces the entry.
    final database = await databasePath(db);
    _database = database;
    // An in-memory database cannot outlive its process: every attempt is a
    // new one, and nothing goes into the ledger (Review B re-check, N2).
    final fingerprint = database.isEmpty
        ? 'memory'
        : config.fingerprint(File(database));
    var pending = database.isEmpty
        ? null
        : await config.runLedger.read(7, 8, database);
    if (pending == null ||
        !pending.binds(
          database: database,
          fingerprint: fingerprint,
          appVersion: config.appVersion,
        )) {
      pending = PendingMigrationRun(
        runId: config.newRunId(),
        generatedAt: config.clock.now().toUtc().toIso8601String(),
        database: database,
        fingerprint: fingerprint,
        appVersion: config.appVersion,
      );
      if (database.isNotEmpty) await config.runLedger.write(7, 8, pending);
    }
    await _phase(V8MigrationPhase.started);

    // 2. Baseline.
    final preTables = await io.userTables();
    final baseline = await _findings(io, tables: preTables);
    final countsBefore = {
      for (final t in ['exercises', 'session_sets']) t: await io.count(t),
    };
    await _phase(V8MigrationPhase.baselineTaken);

    // 3. Tables and indexes.
    for (final entity in s.entities) {
      if (entity is TableInfo<Table, Object?>) {
        if (!await io.tableExists(entity.actualTableName)) {
          await m.createTable(entity);
        }
      } else if (entity is Index) {
        if (!await io.entityExists('index', entity.entityName)) {
          await m.createIndex(entity);
        }
      }
    }
    await _phase(V8MigrationPhase.tablesCreated);

    // 4. Runs (R-07, R-08).
    final runId = pending.runId;
    final integrityRunId = '$runId$integrityRunSuffix';
    final at = pending.generatedAt;
    await io.run(
      'INSERT INTO migration_runs (id, trigger_kind, from_version, '
      'to_version, generated_at, app_version, provenance_kind, '
      'provenance_source, merged_at) VALUES '
      "(?, 'migration', 7, 8, ?, ?, 'device', ?, NULL), "
      "(?, 'integrityCheck', NULL, NULL, ?, ?, 'device', ?, NULL)",
      [
        runId,
        at,
        config.appVersion,
        config.installLabel,
        integrityRunId,
        at,
        config.appVersion,
        config.installLabel,
      ],
    );
    await _phase(V8MigrationPhase.runRecorded);

    // 5. Bootstrap (device rows win, R-23).
    await BootstrapReferenceV8.insert(db);
    await _phase(V8MigrationPhase.bootstrapInserted);

    final run = ReportRun(
      runId: runId,
      trigger: ReportTrigger.migration,
      generatedAt: DateTime.parse(at),
      appVersion: config.appVersion,
      fromSchemaVersion: 7,
      toSchemaVersion: 8,
    );
    final builder = MigrationReportBuilder(run);
    final quarantineIds = <String, int>{};
    final affected = <String, Map<ReportCategory, Set<String>>>{};
    // Report table|record → the exercise the entry concerns.
    final exerciseOf = <String, String>{};

    Future<void> quarantine(QuarantineRequest q) async {
      final id = await db.customInsert(
        'INSERT INTO legacy_quarantine (source_table, row_id, reason, '
        'original_json, quarantined_at) VALUES (?, ?, ?, ?, ?)',
        variables: [
          Variable.withString(q.table),
          Variable.withString(q.recordId),
          Variable.withString(q.reason),
          Variable.withString(q.originalJson),
          Variable.withString(at),
        ],
      );
      for (final field in q.original.keys) {
        quarantineIds['${q.table}|${q.recordId}|$field'] = id;
      }
    }

    // v6-era quarantine rows (read before this step adds any).
    final legacyRows = await db
        .customSelect(
          'SELECT id, source_table, row_id, reason, original_json, '
          'quarantined_at FROM legacy_quarantine ORDER BY id',
        )
        .get();

    // 6. Exercises.
    final exerciseRows = await db
        .customSelect(
          'SELECT id, primary_muscle, secondary_muscles_json, equipment_json, '
          'supplied FROM exercises ORDER BY id',
        )
        .get();
    final mappings = <LegacyExerciseMapping>[];
    final originals = <String, Map<String, Object?>>{};
    for (final r in exerciseRows) {
      final d = r.data;
      originals[d['id']! as String] = d;
      final mapping = config.mapExercise(
        LegacyExerciseRow(
          id: d['id']! as String,
          primaryMuscle: d['primary_muscle'],
          secondaryMusclesJson: d['secondary_muscles_json'],
          equipmentJson: d['equipment_json'],
          supplied: d['supplied'],
        ),
        options: config.mappingOptions,
      );
      mappings.add(mapping);
      exerciseOf['${LegacyV7Columns.exercisesTable}|${mapping.id.value}'] =
          mapping.id.value;
      for (final q in mapping.quarantine) {
        await quarantine(q);
      }
      builder.examine(
        table: LegacyV7Columns.exercisesTable,
        recordId: mapping.id.value,
        cleanOutcome: ReportCategory.migrated,
        events: mapping.events,
      );
    }
    if (mappings.isNotEmpty) {
      affected[LegacyV7Columns.exercisesTable] = {
        ReportCategory.rejectedOrBlocked: {
          for (final x in mappings)
            if (x.blocks.isNotEmpty) x.id.value,
        },
        ReportCategory.quarantinedOrUnresolved: {
          for (final x in mappings)
            if (x.blocks.isEmpty && x.quarantine.isNotEmpty) x.id.value,
        },
      };
    }
    await _phase(V8MigrationPhase.exercisesMapped);

    // 7. Rebuild `exercises` with source, provider and revision from the
    // mapping (a temporary table, so WS4 stays the only source of truth).
    await io.run('DROP TABLE IF EXISTS temp.v8_exercise_provenance');
    await io.run(
      'CREATE TEMP TABLE v8_exercise_provenance (id TEXT NOT NULL PRIMARY '
      'KEY, source TEXT NOT NULL, provider_id TEXT, revision INTEGER)',
    );
    for (final x in mappings) {
      await io.run(
        'INSERT INTO temp.v8_exercise_provenance VALUES (?, ?, ?, ?)',
        [x.id.value, x.source.name, x.providerId?.value, x.revision],
      );
    }
    String fromProvenance(String column) =>
        '(SELECT p.$column FROM temp.v8_exercise_provenance p '
        'WHERE p.id = exercises.id)';
    final ex = s.exercises;
    await m.alterTable(
      TableMigration(
        ex,
        columnTransformer: {
          ex.source: CustomExpression<String>(fromProvenance('source')),
          ex.providerId: CustomExpression<String>(
            fromProvenance('provider_id'),
          ),
          ex.revision: CustomExpression<int>(fromProvenance('revision')),
        },
        newColumns: [
          ex.mechanics,
          ex.laterality,
          ex.difficulty,
          ex.retiredAt,
          ex.angle,
          ex.armPosition,
          ex.bodyPosition,
          ex.grip,
          ex.gripWidth,
          ex.kneePosition,
          ex.stance,
        ],
      ),
    );
    await io.run('DROP TABLE temp.v8_exercise_provenance');
    await _phase(V8MigrationPhase.exercisesRebuilt);

    // Targets, equipment and blocks.
    for (final x in mappings) {
      final id = x.id.value;
      for (var i = 0; i < x.targets.length; i++) {
        final t = x.targets[i];
        if (t.ordinal != i) {
          throw V8MigrationFailure(V8MigrationFailureKind.selfCheckFailed, [
            '$id: target ordinals are not contiguous (R-11)',
          ]);
        }
        await io.run(
          'INSERT INTO exercise_targets (exercise_id, node_id, role, ordinal) '
          'VALUES (?, ?, ?, ?)',
          [id, t.node.value, t.role.name, t.ordinal],
        );
      }
      for (final e in x.equipment) {
        await io.run(
          'INSERT INTO exercise_equipment (exercise_id, equipment_id, '
          'ordinal, role_override, override_note) VALUES (?, ?, ?, NULL, '
          'NULL)',
          [id, e.item.value, e.ordinal],
        );
      }
      final original = originals[id]!;
      for (final b in x.blocks) {
        await io.run(
          'INSERT INTO exercise_blocks (exercise_id, reason, original_json, '
          'blocked_at, resolved_at) VALUES (?, ?, ?, ?, NULL)',
          [id, b.reason.name, blockOriginalJson(b.reason, original), at],
        );
      }
    }
    await _phase(V8MigrationPhase.exerciseLinksWritten);

    // 8. TRN-020 on every set.
    final setRows = await db
        .customSelect(
          'SELECT id, exercise_id, exertion_scale, exertion_value '
          'FROM session_sets ORDER BY id',
        )
        .get();
    final clearedSets = <String>{};
    for (final r in setRows) {
      final d = r.data;
      final setId = d['id']! as String;
      if (d['exercise_id'] case final String exerciseId) {
        exerciseOf['${LegacyV7Columns.sessionSetsTable}|$setId'] = exerciseId;
      }
      final c = classifyLegacyExertion(
        setId: setId,
        scale: d['exertion_scale'],
        value: d['exertion_value'],
      );
      if (c.quarantine case final q?) {
        await quarantine(q);
        await io.run(
          'UPDATE session_sets SET exertion_scale = NULL, '
          'exertion_value = NULL WHERE id = ?',
          [setId],
        );
        clearedSets.add(setId);
      }
      builder.examine(
        table: LegacyV7Columns.sessionSetsTable,
        recordId: setId,
        cleanOutcome: ReportCategory.preserved,
        events: c.events,
      );
    }
    if (setRows.isNotEmpty) {
      affected[LegacyV7Columns.sessionSetsTable] = {
        ReportCategory.quarantinedOrUnresolved: clearedSets,
        ReportCategory.rejectedOrBlocked: const {},
      };
    }
    await _phase(V8MigrationPhase.setsClassified);
    await m.alterTable(TableMigration(s.sessionSets));
    await _phase(V8MigrationPhase.setsRebuilt);

    // 9. Release 1 (plan section 6 step 9; R-10).
    await _recordRelease1(db, io);
    await _phase(V8MigrationPhase.releaseRecorded);

    // v6-era quarantine rows into the report (plan section 6 step 7).
    final legacyIds = <String>{};
    for (final r in legacyRows) {
      final d = r.data;
      final id = '${d['id']}';
      legacyIds.add(id);
      quarantineIds['$legacyQuarantineTable|$id|$legacyQuarantineField'] =
          d['id']! as int;
      final rowId = d['row_id'];
      if (d['source_table'] == LegacyV7Columns.exercisesTable &&
          rowId is String) {
        exerciseOf['$legacyQuarantineTable|$id'] = rowId;
      }
      builder.examine(
        table: legacyQuarantineTable,
        recordId: id,
        cleanOutcome: ReportCategory.preserved,
        events: [legacyQuarantineEvent(d)],
      );
    }
    if (legacyIds.isNotEmpty) {
      affected[legacyQuarantineTable] = {
        ReportCategory.quarantinedOrUnresolved: legacyIds,
      };
    }

    // 10. Broader integrity: damage that existed before the step.
    final after = await _findings(io, tables: await io.userTables());
    final newAnywhere = [
      for (final k in after.keys)
        if (!baseline.containsKey(k)) after[k]!.describe(),
    ];
    if (newAnywhere.isNotEmpty) {
      throw V8MigrationFailure(
        V8MigrationFailureKind.newIntegrityViolation,
        newAnywhere,
      );
    }
    final integrity = await _integrityReport(
      io,
      runId: integrityRunId,
      generatedAt: at,
      scope: preTables,
      findings: [for (final k in baseline.keys) ?after[k]],
    );
    await _phase(V8MigrationPhase.integrityReviewed);

    // 11. Report.
    final report = builder.build();
    final written = {
      runId: await _writeReport(io, report, quarantineIds, exerciseOf),
      integrityRunId: await _writeReport(
        io,
        integrity.report,
        const {},
        integrity.exerciseOf,
      ),
    };
    await _phase(V8MigrationPhase.reportWritten);

    // 12. Targeted foreign-key check (safeguard A) against the baseline.
    final targeted = await _findings(
      io,
      tables: [
        for (final t in targetedTables)
          if (await io.tableExists(t)) t,
      ],
    );
    final newViolations = [
      for (final k in targeted.keys)
        if (!baseline.containsKey(k)) targeted[k]!.describe(),
    ];
    if (newViolations.isNotEmpty) {
      throw V8MigrationFailure(
        V8MigrationFailureKind.newIntegrityViolation,
        newViolations,
      );
    }
    await _phase(V8MigrationPhase.foreignKeysChecked);

    // 13. Self-checks.
    final problems = <String>[];
    final examined = {
      for (final t in [
        LegacyV7Columns.exercisesTable,
        LegacyV7Columns.sessionSetsTable,
      ])
        if (countsBefore[t]! > 0) t: countsBefore[t]!,
      if (legacyIds.isNotEmpty) legacyQuarantineTable: legacyIds.length,
    };
    final rec = reconcileReport(
      report,
      examinedByTable: examined,
      affectedByTable: affected,
    );
    problems.addAll(rec.problems.map((p) => 'migration run: $p'));
    final recIntegrity = reconcileReport(
      integrity.report,
      examinedByTable: integrity.examined,
      affectedByTable: integrity.affected,
    );
    problems.addAll(recIntegrity.problems.map((p) => 'integrity run: $p'));
    for (final MapEntry(key: t, value: n) in countsBefore.entries) {
      final now = await io.count(t);
      if (now != n) problems.add('$t: $n rows before, $now after');
    }
    final stored = await db
        .customSelect(
          'SELECT id, source, provider_id, revision FROM exercises ORDER BY id',
        )
        .get();
    final byId = {for (final x in mappings) x.id.value: x};
    for (final r in stored) {
      final x = byId[r.data['id']];
      if (x == null ||
          r.data['source'] != x.source.name ||
          r.data['provider_id'] != x.providerId?.value ||
          r.data['revision'] != x.revision) {
        problems.add('exercises/${r.data['id']}: provenance differs');
      }
    }
    // The stored report equals the built one, entries and counts (L5).
    for (final MapEntry(key: id, value: rows) in written.entries) {
      final entries = {
        for (final r in await io.select(
          'SELECT * FROM migration_report_entries WHERE run_id = ?',
          [id],
        ))
          r['event_id']! as String: jsonEncode([
            for (final c in _entryColumns) r[c],
          ]),
      };
      if (jsonEncode(_sortedPairs(entries)) !=
          jsonEncode(_sortedPairs(rows.entries))) {
        problems.add('run $id: stored entries differ from the built report');
      }
      final counts = {
        for (final r in await io.select(
          'SELECT source_table, dimension, code, record_count '
          'FROM migration_report_counts WHERE run_id = ? '
          'ORDER BY source_table, dimension, code',
          [id],
        ))
          '${r['source_table']}|${r['dimension']}|${r['code']}':
              r['record_count'],
      };
      if (jsonEncode(_sortedPairs(counts)) !=
          jsonEncode(_sortedPairs(rows.counts))) {
        problems.add('run $id: stored counts differ from the built report');
      }
    }
    if (problems.isNotEmpty) {
      throw V8MigrationFailure(
        V8MigrationFailureKind.selfCheckFailed,
        problems,
      );
    }
    await _phase(V8MigrationPhase.selfChecked);
  }

  /// Tables whose foreign keys and exercise references the step checks
  /// against the baseline before commit (safeguard A; owner decision 3 of
  /// the 3b approach): the rebuilt tables, the tables that reference them,
  /// the exercise-owned children, the reference tables and the report.
  static const List<String> targetedTables = [
    'exercises',
    'session_sets',
    'session_exercises',
    'plan_exercises',
    'exercise_targets',
    'exercise_patterns',
    'exercise_equipment',
    'exercise_names',
    'exercise_blocks',
    'exercise_user_state',
    'anatomy_nodes',
    'movement_patterns',
    'equipment_items',
    'catalogue_releases',
    'migration_report_counts',
    'migration_report_entries',
  ];

  /// `exercise_blocks.original_json` of [reason] (R-06 encoding): the
  /// original target state for `noPrimaryTarget` (`primary_muscle` and
  /// `secondary_muscles_json`), the original `equipment_json` otherwise.
  static String blockOriginalJson(
    BlockReason reason,
    Map<String, Object?> exercise,
  ) => encodeStoredRow(switch (reason) {
    BlockReason.noPrimaryTarget || BlockReason.invalidSecondaryTarget => {
      LegacyV7Columns.primaryMuscle: exercise[LegacyV7Columns.primaryMuscle],
      LegacyV7Columns.secondaryMuscles:
          exercise[LegacyV7Columns.secondaryMuscles],
    },
    BlockReason.unknownEquipment || BlockReason.invalidEquipment => {
      LegacyV7Columns.equipment: exercise[LegacyV7Columns.equipment],
    },
  });

  /// The report event of one quarantine row that existed before the step
  /// (plan section 6 step 7, `quality-and-duplicates.md` section 4.1: rows
  /// moved to `legacy_quarantine` by the v6 migration). The row stays as it
  /// is; the entry lists it under rule WP8-D3, the legacy-data rule that
  /// quarantined it.
  static ReportEvent legacyQuarantineEvent(Map<String, Object?> row) =>
      ReportEvent(
        table: legacyQuarantineTable,
        recordId: '${row['id']}',
        field: legacyQuarantineField,
        originalValue: encodeStoredValue(row['original_json']),
        resultingValue: encodeStoredValue(null),
        action: ReportAction.quarantined,
        rule: MigrationRuleCodes.legacyData,
        category: ReportCategory.quarantinedOrUnresolved,
        reason:
            'Quarantined before schema v8 from ${row['source_table']} '
            'record ${row['row_id']} (${row['reason']}); kept unchanged in '
            'legacy_quarantine.',
      );

  Future<void> _recordRelease1(GeneratedDatabase db, _Sql io) async {
    final rows = await db
        .customSelect(
          'SELECT value, updated_at FROM settings '
          "WHERE key = 'seedExercisesVersion'",
        )
        .get();
    if (rows.isEmpty) return;
    final value = rows.single.data['value'];
    final applied = value is String ? (int.tryParse(value) ?? 0) : 0;
    if (applied < 1) return;
    final bytes = await config.loadSeedBytes();
    await io.run(
      'INSERT INTO catalogue_releases (provider_id, "release", applied_at, '
      'content_hash_algorithm, content_hash_encoding, content_hash, '
      'inserted, updated, retired, app_version) VALUES '
      "(?, 1, ?, 'sha256', 'hex-lower', ?, 0, 0, 0, NULL)",
      [
        BootstrapReferenceV8.providerId,
        rows.single.data['updated_at'],
        sha256Hex(bytes),
      ],
    );
  }

  Future<_WrittenReport> _writeReport(
    _Sql io,
    MigrationReport report,
    Map<String, int> quarantineIds,
    Map<String, String> exerciseOf,
  ) async {
    final writtenEntries = <String, String>{};
    final writtenCounts = <String, int>{};
    for (final entry in report.entries) {
      final e = entry.event;
      final values = <Object?>[
        entry.eventId,
        entry.runId,
        e.table,
        e.recordId,
        exerciseOf['${e.table}|${e.recordId}'],
        e.field,
        e.position,
        e.originalValue,
        e.resultingValue ?? encodeStoredValue(null),
        e.element,
        e.action.name,
        e.blockReason?.name,
        e.rule,
        e.reason,
        e.category.code,
        quarantineIds['${e.table}|${e.recordId}|${e.field}'],
        null,
      ];
      writtenEntries[entry.eventId] = jsonEncode(values);
      await io.run(
        'INSERT INTO migration_report_entries (event_id, run_id, '
        'source_table, record_id, exercise_id, field, position, '
        'original_value, resulting_value, element, disposition, '
        'block_reason, rule, reason, category, quarantine_id, '
        'acknowledged_at) VALUES '
        '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
        values,
      );
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
        writtenCounts['${c.table}|$dimension|$code'] = n;
        await io.run(
          'INSERT INTO migration_report_counts (run_id, source_table, '
          'dimension, code, record_count) VALUES (?, ?, ?, ?, ?)',
          [report.run.runId, c.table, dimension, code, n],
        );
      }
    }
    return _WrittenReport(writtenEntries, writtenCounts);
  }

  Future<_IntegrityReport> _integrityReport(
    _Sql io, {
    required String runId,
    required String generatedAt,
    required List<String> scope,
    required List<_Finding> findings,
  }) async {
    final builder = MigrationReportBuilder(
      ReportRun(
        runId: runId,
        trigger: ReportTrigger.integrityCheck,
        generatedAt: DateTime.parse(generatedAt),
        appVersion: config.appVersion,
      ),
    );
    final byRecord = <String, Map<String, List<ReportEvent>>>{};
    final exerciseOf = <String, String>{};
    for (final f in findings) {
      final event = f.toEvent();
      if (f.exerciseId case final x?) {
        exerciseOf['${f.table}|${f.recordId}'] = x;
      }
      byRecord
          .putIfAbsent(f.table, () => {})
          .putIfAbsent(f.recordId, () => [])
          .add(event);
    }
    final examined = <String, int>{};
    final affected = <String, Map<ReportCategory, Set<String>>>{};
    for (final table in scope) {
      if (!await _hasReferences(io, table)) continue;
      final keys = await io.primaryKeys(table);
      if (keys.isEmpty) continue;
      examined[table] = keys.length;
      final records = byRecord[table] ?? const {};
      affected[table] = {
        ReportCategory.quarantinedOrUnresolved: records.keys.toSet(),
      };
      for (final key in keys) {
        builder.examine(
          table: table,
          recordId: key,
          cleanOutcome: ReportCategory.preserved,
          events: records[key] ?? const [],
        );
      }
    }
    return _IntegrityReport(builder.build(), examined, affected, exerciseOf);
  }

  static Future<bool> _hasReferences(_Sql io, String table) async =>
      _looseReferences.any((r) => r.table == table) ||
      (await io.select('PRAGMA foreign_key_list("$table")')).isNotEmpty;

  /// Every foreign-key violation and unresolved exercise reference in
  /// [tables], keyed by table, primary key, column, parent and rule.
  Future<Map<String, _Finding>> _findings(
    _Sql io, {
    required List<String> tables,
  }) async {
    final out = <String, _Finding>{};
    void add(_Finding f) => out[f.key] = f;
    for (final table in tables) {
      final fks = await io.select('PRAGMA foreign_key_list("$table")');
      if (fks.isEmpty) continue;
      final violations = await io.select('PRAGMA foreign_key_check("$table")');
      if (violations.isEmpty) continue;
      final pk = await io.primaryKeyColumns(table);
      final hasExercise = await io.columnExists(table, 'exercise_id');
      for (final v in violations) {
        final fkid = v['fkid'];
        final columns = [
          for (final f in fks)
            if (f['id'] == fkid) f['from']! as String,
        ];
        final parent = v['parent']! as String;
        final selected = [
          ...pk,
          ...columns,
          if (hasExercise) 'exercise_id',
        ].map((c) => '"$c"').join(', ');
        final row = (await io.select(
          'SELECT $selected FROM "$table" WHERE rowid = ?',
          [v['rowid']],
        )).single;
        add(
          _Finding(
            table: table,
            recordId: _Sql.keyOf(pk, row),
            column: columns.join(','),
            value: columns.length == 1
                ? row[columns.single]
                : jsonEncode([for (final c in columns) row[c]]),
            parent: parent,
            rule: foreignKeyRule,
            exerciseId: table == 'exercises'
                ? _Sql.keyOf(pk, row)
                : (hasExercise ? row['exercise_id'] as String? : null),
          ),
        );
      }
    }
    for (final r in _looseReferences) {
      if (!tables.contains(r.table) ||
          !await io.columnExists(r.table, r.column) ||
          !await io.tableExists('exercises')) {
        continue;
      }
      final pk = await io.primaryKeyColumns(r.table);
      final rows = await io.select(
        'SELECT ${pk.map((c) => '"$c"').join(', ')}, "${r.column}" AS ref '
        'FROM "${r.table}" t WHERE t."${r.column}" IS NOT NULL AND NOT '
        'EXISTS (SELECT 1 FROM exercises e WHERE e.id = t."${r.column}")',
      );
      for (final row in rows) {
        add(
          _Finding(
            table: r.table,
            recordId: _Sql.keyOf(pk, row),
            column: r.column,
            value: row['ref'],
            parent: 'exercises',
            rule: r.rule,
            // The exercise the record belongs to: the exercise itself for
            // `copied_from_id`, else the (unresolved) `exercise_id`.
            exerciseId: r.table == 'exercises'
                ? _Sql.keyOf(pk, row)
                : switch (row['ref']) {
                    final String ref => ref,
                    _ => null,
                  },
          ),
        );
      }
    }
    return out;
  }

  /// Exercise ids without a foreign key (`quality-and-duplicates.md`
  /// IC-900): reported, never repaired.
  static const List<({String table, String column, String rule})>
  _looseReferences = [
    (table: 'session_sets', column: 'exercise_id', rule: 'IC-901'),
    (table: 'session_exercises', column: 'exercise_id', rule: 'IC-901'),
    (table: 'plan_exercises', column: 'exercise_id', rule: 'IC-902'),
    (table: 'exercise_user_state', column: 'exercise_id', rule: 'IC-902'),
    (table: 'exercises', column: 'copied_from_id', rule: 'IC-903'),
  ];
}

const String _unsupportedSecondaryBlock =
    'blockInvalidSecondaryTargets is OPEN (WS4 H1 and L9): v8 has no '
    'invalidSecondaryTarget block reason until the owner decides';

const String _unexpectedV8Shape =
    'exercises has no primary_muscle column, but no v7 → v8 run is recorded';

/// The columns of `migration_report_entries`, in insert order.
const List<String> _entryColumns = [
  'event_id',
  'run_id',
  'source_table',
  'record_id',
  'exercise_id',
  'field',
  'position',
  'original_value',
  'resulting_value',
  'element',
  'disposition',
  'block_reason',
  'rule',
  'reason',
  'category',
  'quarantine_id',
  'acknowledged_at',
];

/// What [V7ToV8Migration] wrote for one run: event id → JSON of the row
/// values in [_entryColumns] order, and `table|dimension|code` → count.
final class _WrittenReport {
  _WrittenReport(this.entries, this.counts);
  final Map<String, String> entries;
  final Map<String, int> counts;
}

/// [m] as sorted `key=value` lines (order-independent comparison).
List<String> _sortedPairs(Map<String, Object?> m) =>
    [for (final e in m.entries) '${e.key}=${e.value}']..sort();

final class _IntegrityReport {
  _IntegrityReport(this.report, this.examined, this.affected, this.exerciseOf);
  final MigrationReport report;
  final Map<String, int> examined;
  final Map<String, Map<ReportCategory, Set<String>>> affected;

  /// Report table|record → the exercise the finding concerns.
  final Map<String, String> exerciseOf;
}

/// One foreign-key violation or unresolved reference.
final class _Finding {
  _Finding({
    required this.table,
    required this.recordId,
    required this.column,
    required this.value,
    required this.parent,
    required this.rule,
    required this.exerciseId,
  });

  final String table;
  final String recordId;
  final String column;
  final Object? value;
  final String parent;
  final String rule;
  final String? exerciseId;

  String get key => jsonEncode([table, recordId, column, parent, rule]);

  String describe() =>
      '$table/$recordId.$column = ${encodeStoredValue(value)} does not '
      'resolve in $parent ($rule)';

  ReportEvent toEvent() => ReportEvent(
    table: table,
    recordId: recordId,
    field: column,
    originalValue: encodeStoredValue(value),
    resultingValue: encodeStoredValue(value),
    action: ReportAction.none,
    rule: rule,
    category: ReportCategory.quarantinedOrUnresolved,
    reason:
        '$table.$column ${encodeStoredValue(value)} does not resolve in '
        '$parent. The damage existed before the v8 migration; it is '
        'reported, not repaired, and did not block the migration.',
  );
}

/// Small SQL helpers over a drift connection.
final class _Sql {
  _Sql(this.db);

  final DatabaseConnectionUser db;

  Future<void> run(String sql, [List<Object?> args = const []]) =>
      db.customStatement(sql, args);

  Future<List<Map<String, Object?>>> select(
    String sql, [
    List<Object?> args = const [],
  ]) async => [
    for (final r
        in await db
            .customSelect(sql, variables: [for (final a in args) _variable(a)])
            .get())
      r.data,
  ];

  Future<int> single(String sql, [List<Object?> args = const []]) async =>
      (await select(sql, args)).single.values.first! as int;

  static Variable<Object> _variable(Object? a) => switch (a) {
    null => const Variable(null),
    final String s => Variable.withString(s),
    final int i => Variable.withInt(i),
    final double d => Variable.withReal(d),
    _ => throw ArgumentError.value(a, 'a', 'unsupported variable'),
  };

  Future<int> count(String table) =>
      single('SELECT count(*) AS c FROM "$table"');

  Future<bool> entityExists(String type, String name) async => (await select(
    'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ?',
    [type, name],
  )).isNotEmpty;

  Future<bool> tableExists(String name) => entityExists('table', name);

  Future<bool> columnExists(String table, String column) async =>
      (await select('PRAGMA table_info("$table")'))
          .any((r) => r['name'] == column);

  Future<List<String>> userTables() async => [
    for (final r in await select(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name NOT LIKE 'sqlite_%' ORDER BY name",
    ))
      r['name']! as String,
  ];

  /// Primary-key columns of [table] in key order; `rowid` when it has none.
  Future<List<String>> primaryKeyColumns(String table) async {
    final cols = [
      for (final r in await select('PRAGMA table_info("$table")'))
        if ((r['pk']! as int) > 0) r,
    ]..sort((a, b) => (a['pk']! as int).compareTo(b['pk']! as int));
    return cols.isEmpty
        ? ['rowid']
        : [for (final c in cols) c['name']! as String];
  }

  /// Every record key of [table], sorted.
  Future<List<String>> primaryKeys(String table) async {
    final pk = await primaryKeyColumns(table);
    final cols = pk.map((c) => '"$c"').join(', ');
    return [
      for (final r in await select('SELECT $cols FROM "$table" ORDER BY $cols'))
        keyOf(pk, r),
    ];
  }

  /// The record id of [row]: the single key value as text, or the JSON array
  /// of a composite key.
  static String keyOf(List<String> pk, Map<String, Object?> row) =>
      pk.length == 1
      ? '${row[pk.single]}'
      : jsonEncode([for (final c in pk) row[c]]);
}
