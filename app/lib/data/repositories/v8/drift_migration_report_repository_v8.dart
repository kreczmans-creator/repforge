import 'package:drift/drift.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/library/exercise_availability.dart';
import 'package:repforge/domain/library/library_enums.dart' show enumByName;
import 'package:repforge/domain/library/migration_report.dart';

/// Reads the stored migration report of schema v8 (WP 8 sub-stage 3b-8;
/// `quality-and-duplicates.md` section 4; D04 §7, 2026-11-06 "Report
/// detail" and "3b check scope"; register R-03 to R-08).
///
/// **Not connected to the app** (see `drift_library_repository_v8.dart`).
///
/// - [runs]: every run with its trigger and structured provenance (R-08);
/// - [totals]: the stored counts of a run by table, both dimensions
///   (category and disposition), plus the entry totals by category, action
///   and rule that head the report (section 4.2);
/// - [entries]: the entries, paged, never truncated, in a stable order;
/// - [blockedExercises]: every blocked exercise with its stable id and each
///   reason (R-01), active and, on request, resolved;
/// - [acknowledge]: records the user's acknowledgement of one entry; it
///   never deletes the entry, the quarantined original or anything else
///   (section 4.3);
/// - [storedReport]: a run read back as a domain [MigrationReport], so
///   `reconcileReport` can prove that the stored counts reconcile.
final class DriftMigrationReportRepositoryV8 {
  DriftMigrationReportRepositoryV8(this._db, {required this._clock});

  final AppDatabaseV8 _db;
  final Clock _clock;

  /// Every run, oldest first (generated time, then id).
  Future<List<StoredReportRun>> runs() async {
    final rows =
        await (_db.select(_db.migrationRuns)..orderBy([
              (t) => OrderingTerm.asc(t.generatedAt),
              (t) => OrderingTerm.asc(t.id),
            ]))
            .get();
    return [for (final r in rows) StoredReportRun._(r)];
  }

  /// The run [runId]; null when it does not exist.
  Future<StoredReportRun?> run(String runId) async {
    final row = await (_db.select(
      _db.migrationRuns,
    )..where((t) => t.id.equals(runId))).getSingleOrNull();
    return row == null ? null : StoredReportRun._(row);
  }

  /// The totals of run [runId]: the stored counts by table and the entry
  /// tallies of the report header.
  Future<StoredReportTotals> totals(String runId) async {
    final counts =
        await (_db.select(_db.migrationReportCounts)
              ..where((t) => t.runId.equals(runId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.sourceTable),
                (t) => OrderingTerm.asc(t.dimension),
                (t) => OrderingTerm.asc(t.code),
              ]))
            .get();
    final byTable = <String, StoredTableTotals>{};
    for (final c in counts) {
      final t = byTable.putIfAbsent(
        c.sourceTable,
        () => StoredTableTotals._(c.sourceTable),
      );
      switch (c.dimension) {
        case 'category':
          t._categories[c.code] = c.recordCount;
        case 'disposition':
          t._dispositions[c.code] = c.recordCount;
        default:
          throw StateError('count dimension ${c.dimension}');
      }
    }
    final entries = await (_db.select(
      _db.migrationReportEntries,
    )..where((t) => t.runId.equals(runId))).get();
    Map<String, int> tally(Iterable<String> keys) {
      final out = <String, int>{};
      for (final k in keys) {
        out.update(k, (n) => n + 1, ifAbsent: () => 1);
      }
      return out;
    }

    return StoredReportTotals._(
      runId: runId,
      tables: byTable,
      entries: entries.length,
      acknowledged: entries.where((e) => e.acknowledgedAt != null).length,
      entriesByCategory: tally(entries.map((e) => e.category)),
      entriesByDisposition: tally(entries.map((e) => e.disposition)),
      entriesByRule: tally(entries.map((e) => e.rule)),
    );
  }

  /// One page of entries: those of [runId] (every run when null), of
  /// [exerciseId] when given, without acknowledged ones unless
  /// [includeAcknowledged]. Ordered by run (generated time, then id), then
  /// table, record, field, position (whole-field entries first), rule and
  /// event id; the page total counts every match, so paging never loses an
  /// entry.
  Future<StoredReportPage> entries({
    String? runId,
    String? exerciseId,
    bool includeAcknowledged = true,
    int limit = 50,
    int offset = 0,
  }) async {
    if (limit < 1 || offset < 0) {
      throw ArgumentError('limit must be 1 or more and offset 0 or more');
    }
    final where = <String>[
      if (runId != null) 'e.run_id = ?',
      if (exerciseId != null) 'e.exercise_id = ?',
      if (!includeAcknowledged) 'e.acknowledged_at IS NULL',
    ];
    final args = <Variable<Object>>[
      if (runId != null) Variable<String>(runId),
      if (exerciseId != null) Variable<String>(exerciseId),
    ];
    final filter = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')} ';
    final total = await _db
        .customSelect(
          'SELECT COUNT(*) AS n FROM migration_report_entries e $filter',
          variables: args,
          readsFrom: {_db.migrationReportEntries},
        )
        .getSingle();
    final rows = await _db
        .customSelect(
          'SELECT e.* FROM migration_report_entries e '
          'JOIN migration_runs r ON r.id = e.run_id '
          '$filter'
          'ORDER BY r.generated_at, r.id, e.source_table, e.record_id, '
          'e.field, COALESCE(e.position, -1), e.rule, e.event_id '
          'LIMIT ? OFFSET ?',
          variables: [...args, Variable<int>(limit), Variable<int>(offset)],
          readsFrom: {_db.migrationReportEntries, _db.migrationRuns},
        )
        .get();
    return StoredReportPage._(
      entries: [for (final r in rows) _db.migrationReportEntries.map(r.data)],
      total: total.read<int>('n'),
      offset: offset,
    );
  }

  /// Every exercise with a block row, by id, each with all its reasons
  /// (R-01) and the original value recorded for each. Only exercises with
  /// an active block unless [includeResolved]; resolved rows stay as the
  /// record of the correction and are listed with their `resolvedAt`.
  Future<List<BlockedExerciseRecord>> blockedExercises({
    bool includeResolved = false,
  }) async {
    final rows =
        await (_db.select(_db.exerciseBlocks).join([
              leftOuterJoin(
                _db.exercisesV8,
                _db.exercisesV8.id.equalsExp(_db.exerciseBlocks.exerciseId),
              ),
            ])..orderBy([
              OrderingTerm.asc(_db.exerciseBlocks.exerciseId),
              OrderingTerm.asc(_db.exerciseBlocks.reason),
            ]))
            .get();
    final byExercise = <String, List<TypedResult>>{};
    for (final r in rows) {
      byExercise
          .putIfAbsent(r.readTable(_db.exerciseBlocks).exerciseId, () => [])
          .add(r);
    }
    final out = <BlockedExerciseRecord>[];
    for (final MapEntry(key: id, value: list) in byExercise.entries) {
      final blocks = [
        for (final r in list)
          (
            block: ExerciseBlock(
              reason: _reason(r.readTable(_db.exerciseBlocks).reason),
              blockedAt: r.readTable(_db.exerciseBlocks).blockedAt,
              resolvedAt: r.readTable(_db.exerciseBlocks).resolvedAt,
            ),
            originalJson: r.readTable(_db.exerciseBlocks).originalJson,
          ),
      ];
      final record = BlockedExerciseRecord._(
        exerciseId: id,
        name: list.first.readTableOrNull(_db.exercisesV8)?.name,
        blocks: blocks,
      );
      if (includeResolved || record.isBlocked) out.add(record);
    }
    return out;
  }

  static BlockReason _reason(String stored) =>
      enumByName(BlockReason.values, stored) ??
      (throw StateError('block reason $stored'));

  /// Marks the entry [eventId] acknowledged at [at] (now by default). Only
  /// `acknowledged_at` changes, once: the entry, its quarantined original
  /// and every other row stay (section 4.3). Returns false when the entry
  /// does not exist or is already acknowledged.
  Future<bool> acknowledge(String eventId, {DateTime? at}) async {
    final changed =
        await (_db.update(_db.migrationReportEntries)..where(
              (t) => t.eventId.equals(eventId) & t.acknowledgedAt.isNull(),
            ))
            .write(
              MigrationReportEntriesCompanion(
                acknowledgedAt: Value((at ?? _clock.now()).toUtc()),
              ),
            );
    return changed == 1;
  }

  /// Run [runId] read back as a [MigrationReport] for `reconcileReport`.
  ///
  /// Entries become [ReportEntry.stored] with their stored event ids
  /// (nothing re-derived). Per table, the category counts are the stored
  /// ones; `blocked` and `rejected` (records) and the warning entries are
  /// recounted from the entries, and the disposition breakdown is the stored
  /// one, so `reconcileReport` compares every stored count with the
  /// entries. The clean outcome of a table is the one of `migrated` and
  /// `preserved` with a stored count (a writer counts clean records under
  /// one only; `migrated` when both are zero, which no count depends on).
  Future<MigrationReport> storedReport(String runId) async {
    final runRow = await (_db.select(
      _db.migrationRuns,
    )..where((t) => t.id.equals(runId))).getSingle();
    final rows = await (_db.select(
      _db.migrationReportEntries,
    )..where((t) => t.runId.equals(runId))).get();
    final entries = [
      for (final r in rows)
        ReportEntry.stored(
          runId: r.runId,
          eventId: r.eventId,
          event: ReportEvent(
            table: r.sourceTable,
            recordId: r.recordId,
            field: r.field,
            position: r.position,
            originalValue: r.originalValue,
            element: r.element,
            resultingValue: r.resultingValue,
            action:
                ReportAction.fromName(r.disposition) ??
                (throw StateError('disposition ${r.disposition}')),
            rule: r.rule,
            category:
                ReportCategory.fromCode(r.category) ??
                (throw StateError('category ${r.category}')),
            reason: r.reason,
            blockReason: r.blockReason == null ? null : _reason(r.blockReason!),
          ),
        ),
    ]..sort((a, b) => ReportEvent.compare(a.event, b.event));
    final stored = await totals(runId);
    final counts = <String, TableCounts>{};
    final clean = <String, ReportCategory>{};
    final exceptional = <String, Map<String, ReportCategory>>{};
    for (final t in stored.tables.values) {
      final cleanOutcome =
          t.category(ReportCategory.preserved.code) > 0 &&
              t.category(ReportCategory.migrated.code) == 0
          ? ReportCategory.preserved
          : ReportCategory.migrated;
      clean[t.table] = cleanOutcome;
      final byRecord = <String, List<ReportEvent>>{};
      for (final e in entries) {
        if (e.event.table == t.table) {
          byRecord.putIfAbsent(e.event.recordId, () => []).add(e.event);
        }
      }
      var blocked = 0;
      var rejected = 0;
      var warningEntries = 0;
      final outcomes = <String, ReportCategory>{};
      for (final MapEntry(key: record, value: events) in byRecord.entries) {
        outcomes[record] = recordOutcome(events, cleanOutcome: cleanOutcome);
        if (events.any((e) => e.action == ReportAction.rejected)) {
          rejected++;
        } else if (events.any((e) => e.action == ReportAction.blocked)) {
          blocked++;
        }
        warningEntries += events
            .where((e) => e.category == ReportCategory.warningForReview)
            .length;
      }
      exceptional[t.table] = outcomes;
      counts[t.table] = TableCounts(
        table: t.table,
        examined: t.category('examined'),
        migrated: t.category(ReportCategory.migrated.code),
        preserved: t.category(ReportCategory.preserved.code),
        quarantinedOrUnresolved: t.category(
          ReportCategory.quarantinedOrUnresolved.code,
        ),
        rejectedOrBlocked: t.category(ReportCategory.rejectedOrBlocked.code),
        blocked: blocked,
        rejected: rejected,
        warningEntries: warningEntries,
        recordsWithWarnings: t.category(ReportCategory.warningForReview.code),
        entriesByAction: {
          for (final a in ReportAction.values) a: t.disposition(a.name),
        },
      );
    }
    return MigrationReport.restored(
      run: ReportRun(
        runId: runRow.id,
        trigger:
            enumByName(ReportTrigger.values, runRow.triggerKind) ??
            (throw StateError('trigger ${runRow.triggerKind}')),
        generatedAt: runRow.generatedAt,
        appVersion: runRow.appVersion,
        fromSchemaVersion: runRow.fromVersion,
        toSchemaVersion: runRow.toVersion,
      ),
      entries: entries,
      counts: counts,
      exceptionalOutcomes: exceptional,
      cleanOutcomes: clean,
    );
  }
}

/// A stored run (R-08 provenance).
final class StoredReportRun {
  StoredReportRun._(MigrationRunRow row)
    : id = row.id,
      trigger = row.triggerKind,
      fromVersion = row.fromVersion,
      toVersion = row.toVersion,
      generatedAt = row.generatedAt,
      appVersion = row.appVersion,
      provenanceKind = row.provenanceKind,
      provenanceSource = row.provenanceSource,
      mergedAt = row.mergedAt;

  final String id;

  /// `migration`, `restore`, `integrityCheck` or `catalogueUpdate`.
  final String trigger;
  final int? fromVersion;
  final int? toVersion;
  final DateTime generatedAt;
  final String appVersion;

  /// `device` or `backup`.
  final String provenanceKind;
  final String provenanceSource;
  final DateTime? mergedAt;
}

/// The stored counts of one table in one run (both dimensions).
final class StoredTableTotals {
  StoredTableTotals._(this.table);

  final String table;
  final Map<String, int> _categories = {};
  final Map<String, int> _dispositions = {};

  /// Category counts by code (`examined` and the five categories).
  Map<String, int> get categories => Map.unmodifiable(_categories);

  /// Disposition counts by action name (entries, R-03 and Review A M1).
  Map<String, int> get dispositions => Map.unmodifiable(_dispositions);

  int category(String code) => _categories[code] ?? 0;
  int disposition(String action) => _dispositions[action] ?? 0;

  /// The four exclusive outcomes summed (R-04: equals `examined`).
  int get outcomeTotal =>
      [for (final o in ReportCategory.outcomes) category(o.code)]
          .fold(0, (a, b) => a + b);
}

/// The totals of one run.
final class StoredReportTotals {
  StoredReportTotals._({
    required this.runId,
    required Map<String, StoredTableTotals> tables,
    required this.entries,
    required this.acknowledged,
    required Map<String, int> entriesByCategory,
    required Map<String, int> entriesByDisposition,
    required Map<String, int> entriesByRule,
  }) : tables = Map.unmodifiable(tables),
       entriesByCategory = Map.unmodifiable(entriesByCategory),
       entriesByDisposition = Map.unmodifiable(entriesByDisposition),
       entriesByRule = Map.unmodifiable(entriesByRule);

  final String runId;

  /// Stored counts by table.
  final Map<String, StoredTableTotals> tables;

  /// Entries of the run, and how many of them are acknowledged.
  final int entries;
  final int acknowledged;

  /// Entry tallies for the report header (section 4.2: totals by action and
  /// by rule head the report).
  final Map<String, int> entriesByCategory;
  final Map<String, int> entriesByDisposition;
  final Map<String, int> entriesByRule;
}

/// One page of report entries.
final class StoredReportPage {
  StoredReportPage._({
    required List<MigrationReportEntryRow> entries,
    required this.total,
    required this.offset,
  }) : entries = List.unmodifiable(entries);

  final List<MigrationReportEntryRow> entries;

  /// Every matching entry, across all pages.
  final int total;
  final int offset;

  bool get hasMore => offset + entries.length < total;
}

/// A blocked exercise in the report: stable id, name (null when the
/// exercise row is missing, which the cascade makes impossible) and every
/// reason with its original value (R-01; D04 no-primary disposition: "the
/// migration report gives its id, original target state and reason").
final class BlockedExerciseRecord {
  BlockedExerciseRecord._({
    required this.exerciseId,
    required this.name,
    required List<({ExerciseBlock block, String originalJson})> blocks,
  }) : blocks = List.unmodifiable(blocks);

  final String exerciseId;
  final String? name;
  final List<({ExerciseBlock block, String originalJson})> blocks;

  /// Active reasons (R-01).
  Set<BlockReason> get activeReasons =>
      activeBlockReasons(blocks.map((b) => b.block));

  bool get isBlocked => activeReasons.isNotEmpty;
}
