import 'package:drift/drift.dart';
import 'package:repforge/data/db/tables.dart';

/// Schema v8 tables (WP 8 stage 3b-2). Defined, tested and dumped, but **not
/// connected to the app**: production stays on schema v7 (`AppDatabase`)
/// until the owner accepts stage 3b and authorises the switch (D04 §7,
/// 2026-11-06). Sources: `docs/wp8-delivery-plan.md` section 5, ADR-0008
/// (with the approved clarification, sections A to E), ADR-0009, ADR-0010,
/// `docs/catalogue/quality-and-duplicates.md` section 4 and the owner
/// decisions of 2026-11-06. Every choice the sources leave open is listed in
/// the assumption register of `docs/schema-v8.md`.
///
/// Tables that do not change in v8 are the v7 classes of `tables.dart`,
/// listed unchanged in `AppDatabaseV8`. Only `exercises` and `session_sets`
/// change; every other table here is new. Class names avoid the domain
/// model's names (`ExerciseEquipment`, `ContentProvider`, ...), and every
/// data class ends in `Row`.

// ---- Changed tables ---------------------------------------------------------

/// Exercise library, schema v8 (plan section 5; ADR-0008 clarification A).
///
/// Compared with v7: `primary_muscle` and `secondary_muscles_json` move to
/// `exercise_targets`, `supplied` becomes `source`, `equipment_json` moves to
/// `exercise_equipment` (owner decision Q13). New: provenance (`source`,
/// `provider_id`, `revision`), the closed classifications `mechanics`,
/// `laterality` and `difficulty`, `retired_at`, and the seven optional,
/// single-valued attributes, one typed column each. Every classification and
/// attribute is nullable with no default: NULL means "no recorded or
/// applicable value" and nothing reads it as "not applicable" (owner
/// decision Q5 and implementation clarification 1).
@DataClassName('ExerciseV8Row')
class ExercisesV8 extends Table with SyncColumns {
  @override
  String get tableName => 'exercises';

  TextColumn get name => text()();
  TextColumn get type => text()();
  TextColumn get category => text()();
  TextColumn get aliasesJson => text().withDefault(const Constant('[]'))();
  TextColumn get searchKey => text().withDefault(const Constant(''))();
  TextColumn get copiedFromId => text().nullable()();
  BoolColumn get archived => boolean().withDefault(const Constant(false))();

  /// `system`, `user` or `imported` (ADR-0009 decision 1). No default
  /// (owner decision R-15): every insert states the source. It is immutable
  /// after creation (ADR-0009); its enforcement is register R-26.
  TextColumn get source => text().customConstraint(
    "NOT NULL CHECK (source IN ('system','user','imported'))",
  )();

  /// The content provider of a system exercise (ADR-0009 decision 2).
  /// Catalogue key (owner decision R-12).
  TextColumn get providerId =>
      text().nullable().references(ContentProviders, #id)();

  /// Catalogue revision of a system exercise; NULL or at least 1 (IC-103).
  IntColumn get revision => integer().nullable().customConstraint(
    'CHECK (revision IS NULL OR revision >= 1)',
  )();

  TextColumn get mechanics => text().nullable().customConstraint(
    "CHECK (mechanics IS NULL OR mechanics IN ('compound','isolation'))",
  )();
  TextColumn get laterality => text().nullable().customConstraint(
    'CHECK (laterality IS NULL OR laterality IN '
    "('bilateral','unilateral','alternating'))",
  )();
  TextColumn get difficulty => text().nullable().customConstraint(
    'CHECK (difficulty IS NULL OR difficulty IN '
    "('beginner','intermediate','advanced'))",
  )();

  /// Set when a catalogue release retires the exercise. It is never deleted
  /// and its id is never reused (plan section 17.5).
  DateTimeColumn get retiredAt => dateTime().nullable()();

  // The seven attributes, exactly as ADR-0008 clarification section A
  // states them (names, values in `coverage.json` order, nullable, no
  // default, binary collation).
  TextColumn get angle => text().nullable().customConstraint(
    "CHECK (angle IS NULL OR angle IN ('flat','incline','decline'))",
  )();
  TextColumn get armPosition => text().nullable().customConstraint(
    'CHECK (arm_position IS NULL OR arm_position IN '
    "('besideBody','behindBody','supportedInFront','overhead','flexed90',"
    "'abducted90'))",
  )();
  TextColumn get bodyPosition => text().nullable().customConstraint(
    'CHECK (body_position IS NULL OR body_position IN '
    "('standing','seated','lying','prone','bentOver','kneeling',"
    "'halfKneeling','inclined'))",
  )();
  TextColumn get grip => text().nullable().customConstraint(
    'CHECK (grip IS NULL OR grip IN '
    "('pronated','supinated','neutral','mixed'))",
  )();
  TextColumn get gripWidth => text().nullable().customConstraint(
    'CHECK (grip_width IS NULL OR grip_width IN '
    "('close','standard','wide'))",
  )();
  TextColumn get kneePosition => text().nullable().customConstraint(
    "CHECK (knee_position IS NULL OR knee_position IN ('straight','bent'))",
  )();
  TextColumn get stance => text().nullable().customConstraint(
    'CHECK (stance IS NULL OR stance IN '
    "('narrow','standard','wide','split'))",
  )();

  @override
  Set<Column<Object>> get primaryKey => {id};

  /// Every system exercise records its provider and revision (plan section
  /// 17.6; owner decision R-14).
  @override
  List<String> get customConstraints => [
    // ignore: lines_longer_than_80_chars, drift needs a single literal
    "CHECK (source <> 'system' OR (provider_id IS NOT NULL AND revision IS NOT NULL))",
  ];
}

/// One performed set, schema v8. Identical to v7 `session_sets` (same
/// columns, defaults, keys and indexes) except one constraint: the v7 clause
/// `exertion_value BETWEEN 0 AND 10` is replaced by the TRN-020 rule
/// (`sessionSetsExertionCheck` in `exertion_rule_sql.dart`; owner decision
/// 2026-11-06: rebuild `session_sets`, the table definition enforces the
/// rule). A test keeps the other constraints equal to v7.
@DataClassName('SessionSetV8Row')
@TableIndex(name: 'idx_session_sets_session', columns: {#sessionId})
@TableIndex(name: 'idx_session_sets_exercise', columns: {#exerciseId})
@TableIndex(name: 'idx_session_sets_entry', columns: {#sessionExerciseId})
class SessionSetsV8 extends SessionSets {
  @override
  String get tableName => 'session_sets';

  @override
  List<String> get customConstraints => [
    'CHECK (reps IS NULL OR reps BETWEEN 1 AND 100)',
    'CHECK (load_kg IS NULL OR load_kg BETWEEN 0 AND 1000)',
    'CHECK (assistance_kg IS NULL OR assistance_kg BETWEEN 0 AND 1000)',
    'CHECK (duration_sec IS NULL OR duration_sec > 0)',
    'CHECK (metres IS NULL OR metres > 0)',
    // ignore: lines_longer_than_80_chars, drift needs a single literal
    'CHECK (average_heart_rate IS NULL OR average_heart_rate BETWEEN 30 AND 250)',
    'CHECK (energy_kcal IS NULL OR energy_kcal >= 0)',
    // ignore: lines_longer_than_80_chars, drift needs a single literal
    "CHECK (energy_provenance IS NULL OR energy_provenance IN ('userEntered', 'estimated'))",
    'CHECK ((energy_kcal IS NULL) = (energy_provenance IS NULL))',
    // ignore: lines_longer_than_80_chars, drift needs a single literal
    "CHECK (((exertion_scale IS NULL AND exertion_value IS NULL) OR (exertion_scale = 'rpe' AND exertion_value BETWEEN 1 AND 10 AND exertion_value * 2 = CAST(exertion_value * 2 AS INTEGER)) OR (exertion_scale = 'rir' AND exertion_value BETWEEN 0 AND 5 AND exertion_value = CAST(exertion_value AS INTEGER))) IS 1)",
    'CHECK (rest_seconds IS NULL OR rest_seconds BETWEEN 0 AND 3600)',
  ];
}

// ---- Providers and releases (ADR-0009) --------------------------------------

/// Content provider registry (plan section 5; ADR-0009 decision 2).
/// `repforge` is inserted by the bootstrap with the licence-register
/// template values; `attribution` stays NULL until stage 3c (owner decision
/// R-09).
@DataClassName('ContentProviderRow')
class ContentProviders extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get licence => text()();
  TextColumn get attribution => text().nullable()();
  TextColumn get url => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The immutable record of an applied catalogue release (plan sections 5 and
/// 17.6): provider, release, content hash, counts, app version and time.
/// The hash is SHA-256 of the exact bundled release-file bytes in lowercase
/// hex, and the row states the algorithm and the encoding (owner decision
/// R-10; nothing hashes a re-serialised form).
@DataClassName('CatalogueReleaseRow')
class CatalogueReleases extends Table {
  TextColumn get providerId => text().references(ContentProviders, #id)();
  IntColumn get release =>
      integer().customConstraint('NOT NULL CHECK ("release" >= 1)')();
  DateTimeColumn get appliedAt => dateTime()();
  TextColumn get contentHashAlgorithm => text().customConstraint(
    "NOT NULL CHECK (content_hash_algorithm IN ('sha256'))",
  )();
  TextColumn get contentHashEncoding => text().customConstraint(
    "NOT NULL CHECK (content_hash_encoding IN ('hex-lower'))",
  )();
  TextColumn get contentHash => text().customConstraint(
    'NOT NULL CHECK (length(content_hash) = 64 '
    "AND content_hash NOT GLOB '*[^0-9a-f]*')",
  )();
  IntColumn get inserted =>
      integer().customConstraint('NOT NULL CHECK (inserted >= 0)')();
  IntColumn get updated =>
      integer().customConstraint('NOT NULL CHECK (updated >= 0)')();
  IntColumn get retired =>
      integer().customConstraint('NOT NULL CHECK (retired >= 0)')();
  TextColumn get appVersion => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {providerId, release};
}

// ---- Reference data (ADR-0008 decisions 2 and 4; ADR-0010) -----------------
// Deferred to stage 3c by the owner (2026-11-06): the plan's `release` column
// on the three reference tables (R-13) and reference lifecycle and times
// (R-21). They are added later as new columns; nothing here prevents that.

/// Anatomy node: level 1 region, 2 muscle group, 3 anatomical muscle, 4
/// subdivision or head. `fullBody` is the one non-anatomical, childless
/// level 1 node (ADR-0010). The migration bootstrap inserts 31 nodes; the
/// approved catalogue (126 nodes) arrives with release 2 (stage 3c).
@DataClassName('AnatomyNodeRow')
class AnatomyNodes extends Table {
  TextColumn get id => text()();

  /// Null exactly at level 1 (plan section 3: one parent except L1).
  TextColumn get parentId => text().nullable().references(AnatomyNodes, #id)();
  IntColumn get level =>
      integer().customConstraint('NOT NULL CHECK (level BETWEEN 1 AND 4)')();
  BoolColumn get nonAnatomical => boolean()();
  IntColumn get sortOrder => integer()();
  TextColumn get providerId => text().references(ContentProviders, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK ((level = 1) = (parent_id IS NULL))',
    'CHECK (parent_id IS NULL OR parent_id <> id)',
    'CHECK (non_anatomical = 0 OR level = 1)',
  ];
}

/// Movement pattern: a family (no parent) or a pattern under a family.
/// Catalogue keys on `parent_id` and `provider_id` (owner decision R-12).
@DataClassName('MovementPatternRow')
class MovementPatterns extends Table {
  TextColumn get id => text()();
  TextColumn get parentId =>
      text().nullable().references(MovementPatterns, #id)();
  IntColumn get sortOrder => integer()();
  TextColumn get providerId => text().references(ContentProviders, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (parent_id IS NULL OR parent_id <> id)',
  ];
}

/// Equipment item. `default_role` is the item's default role
/// (`equipment.json` `role`; ADR-0008 clarification B). It is immutable
/// (owner decision Q8). The release reconciler and restore validation
/// enforce it, without a trigger (owner decision R-20). Equipment class and
/// lifecycle wait for stage 3c (owner decision Q11).
@DataClassName('EquipmentItemRow')
class EquipmentItems extends Table {
  TextColumn get id => text()();
  IntColumn get sortOrder => integer()();
  TextColumn get defaultRole => text().customConstraint(
    'NOT NULL CHECK (default_role IN '
    "('load','support','cardio','implement'))",
  )();
  TextColumn get providerId => text().references(ContentProviders, #id)();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Display labels of reference data by locale (ADR-0008 decision 7). Only
/// `en-GB` ships. Labels are never stored domain values (owner decision Q3).
/// Constraints on `kind` and `locale` are a stage 3c item (register R-27).
@DataClassName('ReferenceLabelRow')
class ReferenceLabels extends Table {
  TextColumn get kind => text()();
  TextColumn get id => text()();
  TextColumn get locale => text()();
  TextColumn get label => text()();

  @override
  Set<Column<Object>> get primaryKey => {kind, id, locale};
}

// ---- Exercise classifications ----------------------------------------------

/// Anatomy targets of an exercise (plan section 5; ADR-0008 decision 3): a
/// node at most once per exercise; `ordinal` orders all targets of the
/// exercise from 0 (IC-309). Roles are qualitative only.
@DataClassName('ExerciseTargetRow')
@TableIndex(name: 'idx_exercise_targets_node', columns: {#nodeId})
class ExerciseTargets extends Table {
  TextColumn get exerciseId =>
      text().references(ExercisesV8, #id, onDelete: KeyAction.cascade)();
  TextColumn get nodeId => text().references(AnatomyNodes, #id)();
  TextColumn get role => text().customConstraint(
    "NOT NULL CHECK (role IN ('primary','secondary'))",
  )();
  IntColumn get ordinal =>
      integer().customConstraint('NOT NULL CHECK (ordinal >= 0)')();

  @override
  Set<Column<Object>> get primaryKey => {exerciseId, nodeId};

  @override
  List<String> get customConstraints => ['UNIQUE (exercise_id, ordinal)'];
}

/// Movement patterns of an exercise; the one at ordinal 0 is primary.
/// Exercise-owned rows cascade; the pattern is a catalogue key (R-12).
@DataClassName('ExercisePatternRow')
@TableIndex(name: 'idx_exercise_patterns_pattern', columns: {#patternId})
class ExercisePatterns extends Table {
  TextColumn get exerciseId =>
      text().references(ExercisesV8, #id, onDelete: KeyAction.cascade)();
  TextColumn get patternId => text().references(MovementPatterns, #id)();
  IntColumn get ordinal =>
      integer().customConstraint('NOT NULL CHECK (ordinal >= 0)')();

  @override
  Set<Column<Object>> get primaryKey => {exerciseId, patternId};

  @override
  List<String> get customConstraints => ['UNIQUE (exercise_id, ordinal)'];
}

/// Equipment an exercise needs, with an optional per-exercise role override
/// (ADR-0008 clarification B as approved; owner decisions Q6 to Q10):
/// - key `(exercise_id, equipment_id)` backs IC-307 "listed twice" (Q10);
/// - `ordinal` keeps the stored order; nothing depends on it (Q9);
/// - `role_override` NULL means the item's default role applies; an override
///   is `load` or `support` only and needs a note (IC-315). The note CHECK
///   strips space, tab, line feed and carriage return; the domain check
///   (Dart `trim`) is the authority, the CHECK a backstop;
/// - an override on an item whose default role is `cardio` or `implement`
///   is invalid (Q6). A CHECK cannot read `equipment_items`; the domain
///   check IC-315 enforces it (owner decision R-19); a 3b-7 restore must run
///   IC-315 too, because the schema accepts such a row.
@DataClassName('ExerciseEquipmentRow')
@TableIndex(name: 'idx_exercise_equipment_equipment', columns: {#equipmentId})
class ExerciseEquipmentLinks extends Table {
  @override
  String get tableName => 'exercise_equipment';

  TextColumn get exerciseId =>
      text().references(ExercisesV8, #id, onDelete: KeyAction.cascade)();
  TextColumn get equipmentId => text().references(EquipmentItems, #id)();
  IntColumn get ordinal =>
      integer().customConstraint('NOT NULL CHECK (ordinal >= 0)')();
  TextColumn get roleOverride => text().nullable().customConstraint(
    "CHECK (role_override IS NULL OR role_override IN ('load','support'))",
  )();
  TextColumn get overrideNote => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {exerciseId, equipmentId};

  @override
  List<String> get customConstraints => [
    'UNIQUE (exercise_id, ordinal)',
    // ignore: lines_longer_than_80_chars, drift needs a single literal
    "CHECK (role_override IS NULL OR (override_note IS NOT NULL AND length(trim(override_note, ' ' || char(9,10,13))) > 0))",
  ];
}

// ---- Names and user state ---------------------------------------------
// `exercise_relationships`, `exercise_content` and `exercise_media` (plan
// section 5) are deferred to stage 3c by the owner (R-16 to R-18). No v7
// data maps to them; they are added later as new tables.

/// Names in locales other than `en-GB` (ADR-0008 decision 7); the `en-GB`
/// name and aliases stay on `exercises`. Exercise-owned, so the rows
/// cascade with the exercise (R-12).
@DataClassName('ExerciseNameRow')
class ExerciseNames extends Table {
  TextColumn get exerciseId =>
      text().references(ExercisesV8, #id, onDelete: KeyAction.cascade)();
  TextColumn get locale =>
      text().customConstraint("NOT NULL CHECK (locale <> 'en-GB')")();
  TextColumn get name => text()();
  TextColumn get aliasesJson => text().withDefault(const Constant('[]'))();

  @override
  Set<Column<Object>> get primaryKey => {exerciseId, locale};
}

/// Per-exercise user state (ADR-0008 decision 8): never written by a
/// catalogue release. No database key (owner decision R-12): IC-902 checks
/// the reference and names an orphan by stable id, as for
/// `plan_exercises`.
@DataClassName('ExerciseUserStateRow')
class ExerciseUserState extends Table {
  @override
  String get tableName => 'exercise_user_state';

  TextColumn get exerciseId => text()();
  BoolColumn get favourite => boolean().withDefault(const Constant(false))();
  BoolColumn get hidden => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastUsedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {exerciseId};
}

// ---- Blocked exercises and the migration report ----------------------------

/// Legacy exercises blocked individually (owner decisions of 2026-11-06: no
/// primary target; Q12: unknown, invalid or unmappable equipment). A blocked
/// exercise keeps its id, original data and history, and cannot be selected
/// for new work.
///
/// One row per exercise and reason (owner decision R-01): each reason is
/// recorded and resolved independently; `resolved_at` is set per row by the
/// correction route, which never rewrites history. An exercise is blocked
/// while any of its rows has `resolved_at` NULL. Reasons (R-02):
/// `noPrimaryTarget`, `unknownEquipment` (an id not in the equipment list),
/// `invalidEquipment` (a non-string element or a value that is not a JSON
/// array).
@DataClassName('ExerciseBlockRow')
class ExerciseBlocks extends Table {
  TextColumn get exerciseId =>
      text().references(ExercisesV8, #id, onDelete: KeyAction.cascade)();
  TextColumn get reason => text().customConstraint(
    'NOT NULL CHECK (reason IN '
    "('noPrimaryTarget','unknownEquipment','invalidEquipment'))",
  )();
  TextColumn get originalJson => text()();
  DateTimeColumn get blockedAt => dateTime()();
  DateTimeColumn get resolvedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {exerciseId, reason};
}

/// One run that produced report entries (`quality-and-duplicates.md` 4.2:
/// `reportId`, `generatedAt`, `appVersion`, `trigger` with from and to
/// schema versions for a migration). Provenance is structured (owner
/// decision R-08): `provenance_kind` `device` for a run produced on this
/// device, `backup` for a run merged in from a restored backup;
/// `provenance_source` names the source and is never NULL: for `device` a
/// stable install or source label, for `backup` the backup identity (file
/// name or content hash); `app_version` is never NULL; `merged_at` is set
/// exactly when the run was merged from a backup. `id`, `generated_at` and
/// `app_version` stay as recorded where the run was produced. A resumed
/// migration reuses its run id; a new attempt gets a new one (R-07).
@DataClassName('MigrationRunRow')
class MigrationRuns extends Table {
  TextColumn get id => text()();
  TextColumn get triggerKind => text().customConstraint(
    'NOT NULL CHECK (trigger_kind IN '
    "('migration','restore','integrityCheck','catalogueUpdate'))",
  )();
  IntColumn get fromVersion => integer().nullable()();
  IntColumn get toVersion => integer().nullable()();
  DateTimeColumn get generatedAt => dateTime()();
  TextColumn get appVersion => text()();
  TextColumn get provenanceKind => text().customConstraint(
    "NOT NULL CHECK (provenance_kind IN ('device','backup'))",
  )();
  TextColumn get provenanceSource => text()();
  DateTimeColumn get mergedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    // ignore: lines_longer_than_80_chars, drift needs a single literal
    "CHECK (trigger_kind <> 'migration' OR (from_version IS NOT NULL AND to_version IS NOT NULL AND from_version < to_version))",
    "CHECK ((provenance_kind = 'backup') = (merged_at IS NOT NULL))",
  ];
}

/// Counts of one run by table (owner decisions R-04 and "Report detail").
/// Two dimensions, one row each (Review A, M1):
/// - `category`: `examined` and the five category codes. The four exclusive
///   outcomes (`migrated`, `preserved`, `quarantinedOrUnresolved`,
///   `rejectedOrBlocked`) sum to `examined`; `warningForReview` is an
///   additional count and never part of the sum.
/// - `disposition`: the count per action (`blocked`, `quarantined`,
///   `rejected`, ...), a breakdown that equals the number of entries with
///   that disposition.
/// The cross-row sums are checked by the writer (3b-4) and its tests; a
/// CHECK cannot read other rows.
@DataClassName('MigrationReportCountRow')
class MigrationReportCounts extends Table {
  TextColumn get runId => text().references(MigrationRuns, #id)();
  TextColumn get sourceTable => text()();
  TextColumn get dimension => text().customConstraint(
    "NOT NULL CHECK (dimension IN ('category','disposition'))",
  )();
  TextColumn get code => text()();
  IntColumn get recordCount =>
      integer().customConstraint('NOT NULL CHECK (record_count >= 0)')();

  @override
  Set<Column<Object>> get primaryKey => {runId, sourceTable, dimension, code};

  @override
  List<String> get customConstraints => [
    // ignore: lines_longer_than_80_chars, drift needs a single literal
    "CHECK ((dimension = 'category' AND code IN ('examined','migrated','preserved','quarantinedOrUnresolved','rejectedOrBlocked','warningForReview')) OR (dimension = 'disposition' AND code IN ('quarantined','cleared','retained','mapped','markerAdded','skipped','rejected','blocked','none')))",
  ];
}

/// One row per affected record, never a sample (`quality-and-duplicates.md`
/// 4.2; owner decision of 2026-11-06, "Report detail"). Only exceptions and
/// changes get a row; clean records are counted in
/// `migration_report_counts`.
/// - `event_id`: stable and unique, derived deterministically from run id,
///   table, record id, field, position and rule (owner decision R-07), so a
///   resumed run and a repeated restore write no duplicate.
/// - `category`: one of the five codes (R-05); `disposition`: the section
///   4.2 action, or `blocked` (R-03).
/// - `original_value`, `resulting_value`: JSON text (R-06): SQL NULL is
///   `null`, TEXT a JSON string, INTEGER and REAL a JSON number, BLOB
///   `{"blob":"<base64>"}`. `original_value` is always the WHOLE stored
///   field value, also for an element entry (for example the raw
///   `secondary_muscles_json` text as a JSON string); the element itself is
///   in `element`. So SQL NULL and a JSON null element never share a
///   column. Never NULL, never an empty string.
/// - `position`: index of an element of a stored list (a repeated equipment
///   id, Q10); NULL when the field is not a list element.
/// - `element`: compact JSON of the offending array element (for example
///   one entry of `equipment_json`), NULL when the field is not a list
///   element (WS4 report contract).
/// - `block_reason`: the `exercise_blocks` reason of a `blocked` entry; set
///   exactly when `disposition` is `blocked`. Its list is the same as the
///   block reasons and is extended together with them (a further reason
///   such as `invalidSecondaryTarget` needs owner approval first).
/// - `quarantine_id`: a loose link to `legacy_quarantine.id` (section 4.2).
/// - `acknowledged_at`: set when the user acknowledges the row; nothing is
///   deleted by it (section 4.3).
@DataClassName('MigrationReportEntryRow')
@TableIndex(name: 'idx_migration_report_entries_run', columns: {#runId})
@TableIndex(
  name: 'idx_migration_report_entries_record',
  columns: {#sourceTable, #recordId},
)
class MigrationReportEntries extends Table {
  TextColumn get eventId => text()();
  TextColumn get runId => text().references(MigrationRuns, #id)();
  TextColumn get sourceTable => text()();
  TextColumn get recordId => text()();
  TextColumn get exerciseId => text().nullable()();
  TextColumn get field => text()();
  IntColumn get position => integer().nullable().customConstraint(
    'CHECK (position IS NULL OR position >= 0)',
  )();
  TextColumn get originalValue =>
      text().customConstraint('NOT NULL CHECK (json_valid(original_value))')();
  TextColumn get resultingValue =>
      text().customConstraint('NOT NULL CHECK (json_valid(resulting_value))')();
  TextColumn get element => text().nullable().customConstraint(
    'CHECK (element IS NULL OR json_valid(element))',
  )();
  TextColumn get disposition => text().customConstraint(
    'NOT NULL CHECK (disposition IN '
    "('quarantined','cleared','retained','mapped','markerAdded','skipped',"
    "'rejected','blocked','none'))",
  )();
  TextColumn get blockReason => text().nullable().customConstraint(
    'CHECK (block_reason IS NULL OR block_reason IN '
    "('noPrimaryTarget','unknownEquipment','invalidEquipment'))",
  )();
  TextColumn get rule => text()();
  TextColumn get reason => text()();
  TextColumn get category => text().customConstraint(
    'NOT NULL CHECK (category IN '
    "('migrated','preserved','quarantinedOrUnresolved','rejectedOrBlocked',"
    "'warningForReview'))",
  )();
  IntColumn get quarantineId => integer().nullable()();
  DateTimeColumn get acknowledgedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {eventId};

  @override
  List<String> get customConstraints => [
    "CHECK ((disposition = 'blocked') = (block_reason IS NOT NULL))",
  ];
}
