/// The migration and legacy report contract (`quality-and-duplicates.md`
/// section 4; D04 section 7, 2026-11-06 "Report detail" and "3b-2 register
/// R-01 to R-11 approved"). Pure types and rules: no SQL, no storage.
///
/// - Every examined record has exactly one **outcome** (R-04): [migrated],
///   [preserved], [quarantinedOrUnresolved] or [rejectedOrBlocked]. The four
///   outcome counts of a table sum to the records examined in it.
/// - Every quarantined, cleared, blocked, rejected, skipped, retained or other
///   exceptional value gets its own [ReportEntry]. Clean records appear only
///   in the counts (D04 "Report detail").
/// - [warningForReview] is an entry category, never an outcome: warnings are
///   additional counts that may reference a record in any outcome and never
///   inflate the total.
///
/// **OQ-19 roll-up is not a migration event.** When a primary and a
/// secondary target of one exercise resolve to the same parent group, the
/// attributed set counts credit only the primary at that level
/// (`set_attribution.dart`; owner decision 2026-11-06). That is a calculation
/// rule applied when figures are shown. The target assignments are migrated
/// unchanged, so the migration emits no entry, no warning and no count for
/// it (D04 "Report detail": normal handling, not a warning).
///
/// [migrated]: ReportCategory.migrated
/// [preserved]: ReportCategory.preserved
/// [quarantinedOrUnresolved]: ReportCategory.quarantinedOrUnresolved
/// [rejectedOrBlocked]: ReportCategory.rejectedOrBlocked
/// [warningForReview]: ReportCategory.warningForReview
library;

import 'dart:convert';

import 'package:meta/meta.dart';
import 'package:repforge/domain/library/sha256_hex.dart';

/// The five report categories (owner minimum structure, 2026-11-06; R-05).
///
/// [code] is the stored, persistent identifier (never display text; a change
/// needs an explicit compatibility decision). Display labels are decided
/// separately; [ownerWording] is the owner's wording, for documentation.
enum ReportCategory {
  /// Migrated successfully: the record was converted to the new shape; every
  /// value is represented (a skipped redundant duplicate is listed as an
  /// entry but loses no information).
  migrated('migrated', 'migrated successfully', isOutcome: true),

  /// Preserved unchanged: the record needed no conversion and is kept as it
  /// was.
  preserved('preserved', 'preserved unchanged', isOutcome: true),

  /// Quarantined or unresolved: at least one value could not be accepted;
  /// the original is in `legacy_quarantine` and the operational value is
  /// cleared or not created.
  quarantinedOrUnresolved(
    'quarantinedOrUnresolved',
    'quarantined or unresolved',
    isOutcome: true,
  ),

  /// Rejected or blocked: the record is kept with its id, history and
  /// original data, but blocked from new use or refused by a rule.
  rejectedOrBlocked(
    'rejectedOrBlocked',
    'rejected or blocked',
    isOutcome: true,
  ),

  /// Warnings requiring review: an entry category only, never an outcome.
  warningForReview(
    'warningForReview',
    'warnings requiring review',
    isOutcome: false,
  );

  ReportCategory(this.code, this.ownerWording, {required this.isOutcome});

  /// Persistent stored identifier (R-05).
  final String code;

  /// The owner's wording of the category (not a display label).
  final String ownerWording;

  /// True for the four mutually exclusive record outcomes (R-04).
  final bool isOutcome;

  /// The four record outcomes in reconciliation order.
  static const List<ReportCategory> outcomes = [
    migrated,
    preserved,
    quarantinedOrUnresolved,
    rejectedOrBlocked,
  ];

  /// The category with stored [code]; null for an unknown code.
  static ReportCategory? fromCode(String code) {
    for (final c in values) {
      if (c.code == code) return c;
    }
    return null;
  }
}

/// The action taken on one value (`quality-and-duplicates.md` section 4.2,
/// with `blocked` added by R-03). The stored identifier is [name].
enum ReportAction {
  quarantined,
  cleared,
  retained,
  mapped,
  markerAdded,
  skipped,
  rejected,
  blocked,
  none;

  /// The action with stored [name]; null for an unknown name.
  static ReportAction? fromName(String name) {
    for (final a in values) {
      if (a.name == name) return a;
    }
    return null;
  }
}

/// Why an exercise is blocked (R-01, R-02). Stored identifier: [name].
///
/// An exercise may have several active reasons; each is recorded and
/// resolved on its own, and resolving one never unblocks the exercise while
/// another is active (R-01).
enum BlockReason {
  /// No mappable primary target (D04 2026-11-06, no-primary disposition).
  noPrimaryTarget,

  /// An equipment element is a string that is not one of the 21 equipment
  /// ids (ADR-0008 section E, Q12).
  unknownEquipment,

  /// `equipment_json` is not a JSON array, or an element is not a string
  /// (R-02).
  invalidEquipment,
}

/// What started the report run (`quality-and-duplicates.md` section 4.2).
enum ReportTrigger { migration, restore, integrityCheck, catalogueUpdate }

/// Rule codes the v8 migration cites. Every code comes from an approved
/// source; none is new.
abstract final class MigrationRuleCodes {
  /// At least one primary target (`quality-and-duplicates.md` IC-204); cited
  /// by the `noPrimaryTarget` block.
  static const String noPrimaryTarget = 'IC-204';

  /// Target node exists in the anatomy list (IC-301); cited by an unmapped
  /// muscle value.
  static const String unknownNode = 'IC-301';

  /// A node appears once per exercise (IC-302); cited by a secondary repeated
  /// in one list (section 4.1, F10).
  static const String repeatedNode = 'IC-302';

  /// A primary node is not repeated as secondary (IC-305); cited by a
  /// secondary equal to the primary (section 4.1, F10).
  static const String primaryAsSecondary = 'IC-305';

  /// Equipment id exists, and is listed once (IC-307; `exercise_rules.dart`
  /// reports "listed twice" under the same code). ADR-0008 section B step 14.
  static const String equipment = 'IC-307';

  /// WP 8 decision 3, the legacy-data rule (no clamping or correction;
  /// original kept in quarantine). Cited by a value that is not readable at
  /// all: non-array JSON text, a non-string element (ADR-0008 B step 14).
  static const String legacyData = 'WP8-D3';

  /// `fullBody` as a secondary target, kept historically (ADR-0010 rule 5;
  /// section 4.1 F08).
  static const String fullBodySecondary = 'ADR-0010';

  /// Exertion rule (D04 TRN-020).
  static const String exertion = 'TRN-020';
}

/// Encodes one stored SQLite value as JSON text (R-06).
///
/// The encoding keeps SQL NULL, strings, integers, reals and blobs distinct
/// and never produces an empty string:
/// - SQL NULL → `null`;
/// - TEXT → a JSON string (stored text `null` → `"null"`, empty text → `""`);
/// - INTEGER → a JSON number without fraction or exponent (`7`);
/// - REAL → a JSON number that always has a fraction or an exponent (`7.0`,
///   `1e+21`), so INTEGER 7 and REAL 7.0 stay distinct; a non-finite REAL →
///   `{"real":"Infinity"}`, `{"real":"-Infinity"}` or `{"real":"NaN"}`;
/// - BLOB (a `List<int>` of bytes) → `{"blob":"<base64>"}`.
///
/// Any other Dart value is not a SQLite storage value and throws
/// [ArgumentError]. A JSON null *inside* a JSON text column is part of that
/// TEXT and is therefore encoded as a JSON string, never as `null`.
String encodeStoredValue(Object? value) {
  switch (value) {
    case null:
      return 'null';
    case final String s:
      return jsonEncode(s);
    case final int i:
      return i.toString();
    case final double d:
      if (d.isNaN) return '{"real":"NaN"}';
      if (d.isInfinite) {
        return d > 0 ? '{"real":"Infinity"}' : '{"real":"-Infinity"}';
      }
      final text = jsonEncode(d);
      // Dart always writes a '.' or an exponent for a double; guard anyway.
      return text.contains('.') || text.contains('e') ? text : '$text.0';
    case final List<int> bytes:
      for (final b in bytes) {
        if (b < 0 || b > 255) {
          throw ArgumentError.value(value, 'value', 'a blob holds bytes only');
        }
      }
      return '{"blob":${jsonEncode(base64Encode(bytes))}}';
    default:
      throw ArgumentError.value(
        value,
        'value',
        'not a SQLite storage value (null, String, int, double, bytes)',
      );
  }
}

/// Decodes the output of [encodeStoredValue]. Throws [FormatException] for
/// text outside the contract.
Object? decodeStoredValue(String encoded) {
  final Object? v;
  try {
    v = jsonDecode(encoded);
  } on FormatException {
    throw FormatException('not an encoded stored value', encoded);
  }
  switch (v) {
    case null:
    case String():
      return v;
    case int():
      return encoded.contains('.') || encoded.contains('e') ? v.toDouble() : v;
    case double():
      return v;
    case Map(length: 1, :final keys):
      final key = keys.single;
      final payload = v[key];
      if (key == 'blob' && payload is String) {
        try {
          return base64Decode(payload);
        } on FormatException {
          throw FormatException('not an encoded stored value', encoded);
        }
      }
      if (key == 'real') {
        switch (payload) {
          case 'NaN':
            return double.nan;
          case 'Infinity':
            return double.infinity;
          case '-Infinity':
            return double.negativeInfinity;
        }
      }
      throw FormatException('not an encoded stored value', encoded);
    default:
      throw FormatException('not an encoded stored value', encoded);
  }
}

/// Encodes a stored row (column → stored value) as one JSON object whose
/// values follow [encodeStoredValue], in the given column order. The form
/// for `legacy_quarantine.original_json`.
String encodeStoredRow(Map<String, Object?> row) {
  final parts = [
    for (final MapEntry(:key, :value) in row.entries)
      '${jsonEncode(key)}:${encodeStoredValue(value)}',
  ];
  return '{${parts.join(',')}}';
}

/// The version tag of the event id serialisation. A change needs a new tag.
const String migrationEventIdScheme = 'repforge.migrationEvent/1';

/// The stable event id of one report entry (R-07): SHA-256, lowercase hex,
/// of the canonical serialisation
/// `["repforge.migrationEvent/1", runId, table, recordId, field, position,
/// rule]` as compact JSON (`jsonEncode`; `position` is a JSON number or
/// `null`). JSON array encoding makes the serialisation unambiguous: no
/// choice of strings can make two different tuples serialise alike.
///
/// The same run, record, field, position and rule always give the same id,
/// so a resumed migration (same run id) or a repeated restore of the same
/// report never duplicates an entry. A genuinely new attempt uses a new run
/// id and so gets new ids.
String migrationEventId({
  required String runId,
  required String table,
  required String recordId,
  required String field,
  required int? position,
  required String rule,
}) {
  if (runId.isEmpty) throw ArgumentError.value(runId, 'runId', 'empty');
  final canonical = jsonEncode([
    migrationEventIdScheme,
    runId,
    table,
    recordId,
    field,
    position,
    rule,
  ]);
  return sha256Hex(utf8.encode(canonical));
}

/// One exceptional value found while examining a record, before it belongs
/// to a run. [ReportEntry] adds the run and the event id.
@immutable
final class ReportEvent {
  ReportEvent({
    required this.table,
    required this.recordId,
    required this.field,
    required this.originalValue,
    required this.action,
    required this.rule,
    required this.category,
    required this.reason,
    this.position,
    this.element,
    this.resultingValue,
    this.blockReason,
  }) {
    if (table.isEmpty || recordId.isEmpty || field.isEmpty || rule.isEmpty) {
      throw ArgumentError('table, recordId, field and rule must be set');
    }
    if (reason.trim().isEmpty) throw ArgumentError('reason must be set');
    if (position != null && position! < 0) {
      throw ArgumentError.value(position, 'position', 'must be 0 or more');
    }
    decodeStoredValue(originalValue); // validates the R-06 encoding
    if (resultingValue != null) decodeStoredValue(resultingValue!);
    if ((action == ReportAction.blocked) != (blockReason != null)) {
      throw ArgumentError('blockReason is set exactly for a blocked action');
    }
    if (action == ReportAction.blocked &&
        category != ReportCategory.rejectedOrBlocked) {
      throw ArgumentError('a blocked action is rejectedOrBlocked');
    }
  }

  /// The affected table, for example `exercises`.
  final String table;

  /// Stable id of the affected record (its primary key as text).
  final String recordId;

  /// The affected column, for example `equipment_json`.
  final String field;

  /// Zero-based index of the element inside a JSON array column; null for a
  /// whole-column value.
  final int? position;

  /// The whole stored column value before migration, encoded per R-06
  /// ([encodeStoredValue]).
  final String originalValue;

  /// For an element entry ([position] set): the element as compact JSON
  /// text (`"barbell"`, `null`, `3`). Null for a whole-column entry.
  final String? element;

  /// The value now used operationally, encoded per R-06 (`null` means the
  /// operational value is SQL NULL). Dart null means not applicable, for
  /// example a column the v8 schema no longer has.
  final String? resultingValue;

  final ReportAction action;

  /// The decision or check code that applied ([MigrationRuleCodes]).
  final String rule;
  final ReportCategory category;

  /// One plain sentence.
  final String reason;

  /// Set exactly when [action] is [ReportAction.blocked].
  final BlockReason? blockReason;

  /// The deterministic order of entries: table, record, field, position
  /// (whole-column first), rule.
  static int compare(ReportEvent a, ReportEvent b) {
    var c = a.table.compareTo(b.table);
    if (c != 0) return c;
    c = a.recordId.compareTo(b.recordId);
    if (c != 0) return c;
    c = a.field.compareTo(b.field);
    if (c != 0) return c;
    c = (a.position ?? -1).compareTo(b.position ?? -1);
    if (c != 0) return c;
    return a.rule.compareTo(b.rule);
  }

  List<Object?> get _props => [
    table,
    recordId,
    field,
    position,
    originalValue,
    element,
    resultingValue,
    action,
    rule,
    category,
    reason,
    blockReason,
  ];

  @override
  bool operator ==(Object other) {
    if (other is! ReportEvent) return false;
    final a = _props;
    final b = other._props;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_props);

  @override
  String toString() =>
      '${category.code} ${action.name} $table/$recordId.$field'
      '${position == null ? '' : '[$position]'} $rule';
}

/// One row of the report: an event in a run, with its stable id.
@immutable
final class ReportEntry {
  ReportEntry(this.runId, this.event)
    : eventId = migrationEventId(
        runId: runId,
        table: event.table,
        recordId: event.recordId,
        field: event.field,
        position: event.position,
        rule: event.rule,
      );

  final String runId;
  final String eventId;
  final ReportEvent event;

  @override
  bool operator ==(Object other) =>
      other is ReportEntry &&
      other.eventId == eventId &&
      other.runId == runId &&
      other.event == event;

  @override
  int get hashCode => Object.hash(eventId, runId, event);

  @override
  String toString() => '$eventId $event';
}

/// Identifies a report run (`quality-and-duplicates.md` section 4.2:
/// `reportId`, `generatedAt`, `appVersion`, `trigger`).
@immutable
final class ReportRun {
  ReportRun({
    required this.runId,
    required this.trigger,
    required this.generatedAt,
    required this.appVersion,
    this.fromSchemaVersion,
    this.toSchemaVersion,
  }) {
    if (runId.isEmpty) throw ArgumentError.value(runId, 'runId', 'empty');
    if (trigger == ReportTrigger.migration &&
        (fromSchemaVersion == null || toSchemaVersion == null)) {
      throw ArgumentError('a migration run names both schema versions');
    }
  }

  /// The run id: reused by a resumed migration, new for a new attempt (R-07).
  final String runId;
  final ReportTrigger trigger;
  final DateTime generatedAt;
  final String appVersion;
  final int? fromSchemaVersion;
  final int? toSchemaVersion;
}

/// Where a merged report came from (R-08).
enum ReportOrigin { device, backup }

/// Provenance of report history after a merge (R-08): source, app version
/// and merge time. Each report keeps its own (D04 "Restore conflicts").
@immutable
final class ReportProvenance {
  const ReportProvenance({
    required this.origin,
    required this.appVersion,
    required this.mergedAt,
  });

  final ReportOrigin origin;
  final String appVersion;
  final DateTime mergedAt;

  @override
  bool operator ==(Object other) =>
      other is ReportProvenance &&
      other.origin == origin &&
      other.appVersion == appVersion &&
      other.mergedAt == mergedAt;

  @override
  int get hashCode => Object.hash(origin, appVersion, mergedAt);
}

/// Reconciled counts of one table (R-04), with the disposition breakdown
/// (D04 "Report detail": blocked, quarantined and rejected stated
/// separately).
@immutable
final class TableCounts {
  TableCounts({
    required this.table,
    required this.examined,
    required this.migrated,
    required this.preserved,
    required this.quarantinedOrUnresolved,
    required this.rejectedOrBlocked,
    required this.blocked,
    required this.rejected,
    required this.warningEntries,
    required this.recordsWithWarnings,
    Map<ReportAction, int> entriesByAction = const {},
  }) : entriesByAction = Map.unmodifiable({
         for (final a in ReportAction.values)
           if (entriesByAction[a] case final n? when n != 0) a: n,
       });

  final String table;

  /// Records examined: the input.
  final int examined;
  final int migrated;
  final int preserved;
  final int quarantinedOrUnresolved;
  final int rejectedOrBlocked;

  /// Of [rejectedOrBlocked]: records with a blocked action and no rejected
  /// one.
  final int blocked;

  /// Of [rejectedOrBlocked]: records with a rejected action.
  final int rejected;

  /// Warning entries ([ReportCategory.warningForReview]): additional, never
  /// part of the outcome total.
  final int warningEntries;

  /// Distinct records with at least one warning entry, in any outcome.
  final int recordsWithWarnings;

  /// Entries of this table by disposition (`quality-and-duplicates.md`
  /// section 4.2 actions plus `blocked`, R-03), in [ReportAction] order;
  /// zero counts are omitted. A breakdown of the entries, never of the
  /// outcome total: one record can have several entries.
  final Map<ReportAction, int> entriesByAction;

  /// Entries with disposition [action] (zero when none).
  int entries(ReportAction action) => entriesByAction[action] ?? 0;

  /// Records counted for an outcome.
  int count(ReportCategory outcome) => switch (outcome) {
    ReportCategory.migrated => migrated,
    ReportCategory.preserved => preserved,
    ReportCategory.quarantinedOrUnresolved => quarantinedOrUnresolved,
    ReportCategory.rejectedOrBlocked => rejectedOrBlocked,
    ReportCategory.warningForReview => throw ArgumentError(
      'warningForReview is not an outcome',
    ),
  };

  /// The four outcomes sum to the records examined.
  int get outcomeTotal =>
      migrated + preserved + quarantinedOrUnresolved + rejectedOrBlocked;

  @override
  String toString() =>
      '$table: examined $examined = migrated $migrated + preserved '
      '$preserved + quarantined $quarantinedOrUnresolved + rejectedOrBlocked '
      '$rejectedOrBlocked (blocked $blocked, rejected $rejected); '
      'warnings $warningEntries on $recordsWithWarnings records; entries '
      '${_actionSummary()}';

  String _actionSummary() => [
    for (final MapEntry(:key, :value) in entriesByAction.entries)
      '${key.name} $value',
  ].join(', ');
}

/// The outcome of a record from its events (R-04): rejected or blocked if
/// any event is in that category; else quarantined or unresolved if any
/// event is; else [cleanOutcome] ([ReportCategory.migrated] or
/// [ReportCategory.preserved]). Skipped, retained and warning entries do not
/// change the outcome.
ReportCategory recordOutcome(
  Iterable<ReportEvent> events, {
  required ReportCategory cleanOutcome,
}) {
  if (cleanOutcome != ReportCategory.migrated &&
      cleanOutcome != ReportCategory.preserved) {
    throw ArgumentError.value(
      cleanOutcome,
      'cleanOutcome',
      'must be migrated or preserved',
    );
  }
  var quarantined = false;
  for (final e in events) {
    if (e.category == ReportCategory.rejectedOrBlocked) {
      return ReportCategory.rejectedOrBlocked;
    }
    if (e.category == ReportCategory.quarantinedOrUnresolved) {
      quarantined = true;
    }
  }
  return quarantined ? ReportCategory.quarantinedOrUnresolved : cleanOutcome;
}

/// The finished report of one run.
@immutable
final class MigrationReport {
  /// A report from its parts, for a report read back from storage or a
  /// backup. [reconcileReport] checks it; nothing here trusts the parts.
  /// [MigrationReportBuilder] is the way to produce a new report.
  MigrationReport.restored({
    required this.run,
    required List<ReportEntry> entries,
    required Map<String, TableCounts> counts,
    required Map<String, Map<String, ReportCategory>> exceptionalOutcomes,
    required Map<String, ReportCategory> cleanOutcomes,
  }) : entries = List.unmodifiable(entries),
       counts = Map.unmodifiable(counts),
       exceptionalOutcomes = Map.unmodifiable({
         for (final MapEntry(:key, :value) in exceptionalOutcomes.entries)
           key: Map<String, ReportCategory>.unmodifiable(value),
       }),
       cleanOutcomes = Map.unmodifiable(cleanOutcomes);

  final ReportRun run;

  /// Every entry, in [ReportEvent.compare] order. Never truncated.
  final List<ReportEntry> entries;

  /// Counts by table, in table order.
  final Map<String, TableCounts> counts;

  /// Table → record id → outcome, for every record that has an entry.
  final Map<String, Map<String, ReportCategory>> exceptionalOutcomes;

  /// Table → the outcome its clean records were counted under.
  final Map<String, ReportCategory> cleanOutcomes;

  /// Records examined across all tables.
  int get examined => counts.values.fold(0, (s, c) => s + c.examined);

  /// Entries by category code, for the report header.
  Map<ReportCategory, int> get entriesByCategory =>
      _tally(entries.map((e) => e.event.category));

  /// Entries by action (section 4.2: totals by action head the report).
  Map<ReportAction, int> get entriesByAction =>
      _tally(entries.map((e) => e.event.action));

  /// Entries by rule code (section 4.2: totals by rule head the report).
  Map<String, int> get entriesByRule =>
      _tally(entries.map((e) => e.event.rule));

  static Map<K, int> _tally<K>(Iterable<K> keys) {
    final out = <K, int>{};
    for (final k in keys) {
      out.update(k, (n) => n + 1, ifAbsent: () => 1);
    }
    return out;
  }
}

/// Builds a [MigrationReport]. Every examined record is registered exactly
/// once with [examine], with its events (none for a clean record).
final class MigrationReportBuilder {
  MigrationReportBuilder(this.run);

  final ReportRun run;
  final Map<String, Set<String>> _seen = {};
  final Map<String, ReportCategory> _clean = {};
  final Map<String, Map<String, ReportCategory>> _exceptional = {};
  final Map<String, Map<ReportCategory, int>> _outcomeCounts = {};
  final Map<String, int> _blocked = {};
  final Map<String, int> _rejected = {};
  final Map<String, int> _warnings = {};
  final Map<String, int> _recordsWithWarnings = {};
  final Map<String, Map<ReportAction, int>> _actions = {};
  final List<ReportEntry> _entries = [];
  final Set<String> _eventIds = {};

  /// Registers one examined record of [table]. [cleanOutcome] is the outcome
  /// of the table's records without exceptional events (migrated or
  /// preserved); it is fixed per table. Throws [StateError] when the record
  /// was already examined, or when two events share an event id.
  ReportCategory examine({
    required String table,
    required String recordId,
    required ReportCategory cleanOutcome,
    Iterable<ReportEvent> events = const [],
  }) {
    final known = _clean.putIfAbsent(table, () => cleanOutcome);
    if (known != cleanOutcome) {
      throw StateError('table $table already counts clean records as $known');
    }
    if (!_seen.putIfAbsent(table, () => <String>{}).add(recordId)) {
      throw StateError('record $table/$recordId examined twice');
    }
    final list = events.toList();
    for (final e in list) {
      if (e.table != table || e.recordId != recordId) {
        throw ArgumentError('event $e does not belong to $table/$recordId');
      }
    }
    final outcome = recordOutcome(list, cleanOutcome: cleanOutcome);
    _outcomeCounts
        .putIfAbsent(table, () => {})
        .update(outcome, (n) => n + 1, ifAbsent: () => 1);
    if (list.isEmpty) return outcome;

    _exceptional.putIfAbsent(table, () => {})[recordId] = outcome;
    if (outcome == ReportCategory.rejectedOrBlocked) {
      final rejected = list.any((e) => e.action == ReportAction.rejected);
      (rejected ? _rejected : _blocked).update(
        table,
        (n) => n + 1,
        ifAbsent: () => 1,
      );
    }
    final warnings = list
        .where((e) => e.category == ReportCategory.warningForReview)
        .length;
    if (warnings > 0) {
      _warnings.update(table, (n) => n + warnings, ifAbsent: () => warnings);
      _recordsWithWarnings.update(table, (n) => n + 1, ifAbsent: () => 1);
    }
    final actions = _actions.putIfAbsent(table, () => {});
    for (final e in list) {
      actions.update(e.action, (n) => n + 1, ifAbsent: () => 1);
      final entry = ReportEntry(run.runId, e);
      if (!_eventIds.add(entry.eventId)) {
        throw StateError('duplicate event id for $e');
      }
      _entries.add(entry);
    }
    return outcome;
  }

  MigrationReport build() {
    final tables = _seen.keys.toList()..sort();
    final counts = <String, TableCounts>{
      for (final t in tables)
        t: TableCounts(
          table: t,
          examined: _seen[t]!.length,
          migrated: _outcomeCounts[t]?[ReportCategory.migrated] ?? 0,
          preserved: _outcomeCounts[t]?[ReportCategory.preserved] ?? 0,
          quarantinedOrUnresolved:
              _outcomeCounts[t]?[ReportCategory.quarantinedOrUnresolved] ?? 0,
          rejectedOrBlocked:
              _outcomeCounts[t]?[ReportCategory.rejectedOrBlocked] ?? 0,
          blocked: _blocked[t] ?? 0,
          rejected: _rejected[t] ?? 0,
          warningEntries: _warnings[t] ?? 0,
          recordsWithWarnings: _recordsWithWarnings[t] ?? 0,
          entriesByAction: _actions[t] ?? const {},
        ),
    };
    final sorted = _entries.toList()
      ..sort((a, b) => ReportEvent.compare(a.event, b.event));
    return MigrationReport.restored(
      run: run,
      entries: sorted,
      counts: counts,
      exceptionalOutcomes: _exceptional,
      cleanOutcomes: _clean,
    );
  }
}

/// The result of [reconcileReport]: empty [problems] means the counts
/// reconcile.
@immutable
final class ReconciliationResult {
  ReconciliationResult(List<String> problems)
    : problems = List.unmodifiable(problems);

  final List<String> problems;

  bool get reconciles => problems.isEmpty;

  @override
  String toString() =>
      reconciles ? 'reconciles' : 'does not reconcile: ${problems.join('; ')}';
}

/// Proves that [report] reconciles (R-04; D04 "Report detail"):
/// 1. per table, examined = migrated + preserved + quarantined or unresolved
///    + rejected or blocked, and blocked + rejected = rejected or blocked,
///    with rejected = the records that have a rejected entry;
/// 2. when [examinedByTable] is given (records counted independently from
///    the input), every table's examined count equals it, and no table is
///    missing on either side;
/// 3. every entry belongs to an examined record with an exceptional outcome,
///    each such record is counted once, and its outcome equals the outcome
///    recomputed from its entries;
/// 4. every quarantined and rejected-or-blocked record has an entry (no
///    exceptional record is reported as a count only);
/// 5. event ids are unique and equal their derivation from the entry fields;
/// 6. warning counts equal the warning entries and never exceed the records
///    examined;
/// 7. each disposition count of a table equals the number of its entries
///    with that disposition.
ReconciliationResult reconcileReport(
  MigrationReport report, {
  Map<String, int>? examinedByTable,
}) {
  final problems = <String>[];
  final byRecord = <String, Map<String, List<ReportEvent>>>{};
  final ids = <String>{};
  for (final entry in report.entries) {
    final e = entry.event;
    if (entry.runId != report.run.runId) {
      problems.add('entry ${entry.eventId} belongs to run ${entry.runId}');
    }
    final derived = migrationEventId(
      runId: entry.runId,
      table: e.table,
      recordId: e.recordId,
      field: e.field,
      position: e.position,
      rule: e.rule,
    );
    if (derived != entry.eventId) {
      problems.add('event id ${entry.eventId} does not match its fields');
    }
    if (!ids.add(entry.eventId)) {
      problems.add('event id ${entry.eventId} appears twice');
    }
    byRecord
        .putIfAbsent(e.table, () => {})
        .putIfAbsent(e.recordId, () => [])
        .add(e);
  }

  if (examinedByTable != null) {
    for (final t in {...examinedByTable.keys, ...report.counts.keys}) {
      final expected = examinedByTable[t];
      final actual = report.counts[t]?.examined;
      if (expected != actual) {
        problems.add(
          '$t: examined ${actual ?? 'missing'}, input '
          '${expected ?? 'missing'}',
        );
      }
    }
  }

  for (final c in report.counts.values) {
    if (c.outcomeTotal != c.examined) {
      problems.add(
        '${c.table}: outcomes sum to ${c.outcomeTotal}, examined '
        '${c.examined}',
      );
    }
    if (c.blocked + c.rejected != c.rejectedOrBlocked) {
      problems.add(
        '${c.table}: blocked ${c.blocked} + rejected ${c.rejected} '
        '!= rejectedOrBlocked ${c.rejectedOrBlocked}',
      );
    }
    if (c.recordsWithWarnings > c.examined) {
      problems.add('${c.table}: more records with warnings than examined');
    }
    final exceptional = report.exceptionalOutcomes[c.table] ?? const {};
    final clean = report.cleanOutcomes[c.table];
    for (final outcome in [
      ReportCategory.quarantinedOrUnresolved,
      ReportCategory.rejectedOrBlocked,
    ]) {
      final listed = exceptional.values.where((o) => o == outcome).length;
      if (listed != c.count(outcome)) {
        problems.add(
          '${c.table}: ${outcome.code} count ${c.count(outcome)} '
          'but $listed records have entries',
        );
      }
    }
    for (final outcome in [ReportCategory.migrated, ReportCategory.preserved]) {
      final listed = exceptional.values.where((o) => o == outcome).length;
      if (listed > c.count(outcome) ||
          (outcome != clean && c.count(outcome) != 0)) {
        problems.add(
          '${c.table}: ${outcome.code} count ${c.count(outcome)} '
          'does not cover its $listed listed records',
        );
      }
    }
    final records = byRecord[c.table] ?? const {};
    var warnings = 0;
    var withWarnings = 0;
    var rejectedRecords = 0;
    for (final MapEntry(key: id, value: events) in records.entries) {
      final listed = exceptional[id];
      if (listed == null) {
        problems.add('${c.table}/$id has entries but no counted outcome');
        continue;
      }
      final recomputed = recordOutcome(events, cleanOutcome: clean!);
      if (recomputed != listed) {
        problems.add(
          '${c.table}/$id counted as ${listed.code}, entries say '
          '${recomputed.code}',
        );
      }
      if (listed == ReportCategory.rejectedOrBlocked &&
          events.any((e) => e.action == ReportAction.rejected)) {
        rejectedRecords++;
      }
      final w = events
          .where((e) => e.category == ReportCategory.warningForReview)
          .length;
      warnings += w;
      if (w > 0) withWarnings++;
    }
    for (final id in exceptional.keys) {
      if (!records.containsKey(id)) {
        problems.add('${c.table}/$id has an exceptional outcome but no entry');
      }
    }
    if (rejectedRecords != c.rejected) {
      problems.add(
        '${c.table}: rejected ${c.rejected} but $rejectedRecords '
        'records have a rejected entry',
      );
    }
    if (warnings != c.warningEntries || withWarnings != c.recordsWithWarnings) {
      problems.add('${c.table}: warning counts do not match the entries');
    }
    for (final action in ReportAction.values) {
      var listed = 0;
      for (final events in records.values) {
        listed += events.where((e) => e.action == action).length;
      }
      if (listed != c.entries(action)) {
        problems.add(
          '${c.table}: ${action.name} count ${c.entries(action)} '
          'but $listed entries',
        );
      }
    }
  }
  for (final t in byRecord.keys) {
    if (!report.counts.containsKey(t)) {
      problems.add('entries for table $t, which has no counts');
    }
  }
  return ReconciliationResult(problems);
}

/// How report history from a backup or an earlier run merges into the
/// device's history (D04 "Restore conflicts": merged, never replaced;
/// stable event ids prevent duplicates).
@immutable
final class ReportMergePlan {
  ReportMergePlan({
    required List<ReportEntry> toInsert,
    required List<ReportEntry> alreadyPresent,
    required List<ReportEntry> conflicting,
    required this.provenance,
  }) : toInsert = List.unmodifiable(toInsert),
       alreadyPresent = List.unmodifiable(alreadyPresent),
       conflicting = List.unmodifiable(conflicting);

  /// New entries, inserted with [provenance].
  final List<ReportEntry> toInsert;

  /// Entries whose event id and content already exist: nothing is written.
  final List<ReportEntry> alreadyPresent;

  /// Incoming entries whose event id exists with different content. The
  /// existing entry is kept; the caller reports the conflict (a decision on
  /// rejecting the whole restore is outside this contract).
  final List<ReportEntry> conflicting;

  /// Provenance of the merged entries (R-08).
  final ReportProvenance provenance;
}

/// Plans a merge of [incoming] into [existing] (keyed by event id). Pure: the
/// caller writes [ReportMergePlan.toInsert]. Repeated merges of the same
/// entries insert nothing the second time.
ReportMergePlan planReportMerge({
  required Map<String, ReportEntry> existing,
  required Iterable<ReportEntry> incoming,
  required ReportProvenance provenance,
}) {
  final insert = <ReportEntry>[];
  final present = <ReportEntry>[];
  final conflicts = <ReportEntry>[];
  final planned = <String, ReportEntry>{};
  for (final e in incoming) {
    final have = existing[e.eventId] ?? planned[e.eventId];
    if (have == null) {
      planned[e.eventId] = e;
      insert.add(e);
    } else if (have == e) {
      present.add(e);
    } else {
      conflicts.add(e);
    }
  }
  return ReportMergePlan(
    toInsert: insert,
    alreadyPresent: present,
    conflicting: conflicts,
    provenance: provenance,
  );
}
