import 'dart:convert';

import 'package:meta/meta.dart';

/// Dart mirror of the schema v8 tables for backup format 3 and the restore
/// of formats 1 to 3 into v8 (WP 8 sub-stage 3b-7; `docs/backup-format-3.md`).
///
/// **Not connected to the app.** Only `drift_backup_repository_v8.dart`
/// uses it, and nothing in `lib/app`, `lib/features` or `lib/ui` imports
/// that (architecture test).
///
/// Every column, default, key, `UNIQUE` set, `CHECK` clause and foreign key
/// of `AppDatabaseV8` is written out here, so the restore can validate every
/// row **before** it writes anything (phase 1), with a clear message per
/// row. The database constraints stay the authority and fire again in phase
/// 2 as a backstop. Tests prove the mirror equal to a fresh v8 database:
/// columns, types, NOT NULL, defaults, keys, unique sets and foreign keys
/// against the `PRAGMA`s, the number of CHECK clauses per table against the
/// stored DDL, and every CHECK verdict against SQLite on mutated rows
/// (`test/data/backup_v8/backup_schema_v8_test.dart`).

/// SQLite storage class a column accepts in a backup. The restore is
/// type-strict (stricter than SQLite affinity): TEXT takes a JSON string,
/// INTEGER a JSON integer (or a boolean, stored as 1 or 0, as production
/// restore binds it), REAL any JSON number.
enum ColumnType { text, integer, real }

/// Sentinel: the column has no `DEFAULT`.
const Object noDefault = _NoDefault();

final class _NoDefault {
  const _NoDefault();
}

@immutable
final class ColumnSpec {
  const ColumnSpec(
    this.name,
    this.type, {
    this.notNull = false,
    this.defaultValue = noDefault,
    this.autoIncrement = false,
  });

  final String name;
  final ColumnType type;
  final bool notNull;

  /// The `DEFAULT` value, or [noDefault].
  final Object? defaultValue;

  /// `INTEGER PRIMARY KEY AUTOINCREMENT`: SQLite assigns the value when the
  /// row gives none (only `legacy_quarantine.id`).
  final bool autoIncrement;

  bool get hasDefault => !identical(defaultValue, noDefault);
}

/// One `CHECK` clause: [sql] as stored in the v8 DDL and its Dart mirror.
/// [passes] returns false only when SQLite would evaluate the clause to
/// false (a NULL result passes, as in SQL).
@immutable
final class CheckSpec {
  const CheckSpec(this.sql, this.passes);
  final String sql;
  final bool Function(Map<String, Object?> row) passes;
}

/// A single-column foreign key.
@immutable
final class ForeignKeySpec {
  const ForeignKeySpec(this.column, this.parentTable, this.parentColumn);
  final String column;
  final String parentTable;
  final String parentColumn;
}

/// How a restore treats a table (`docs/backup-format-3.md` section 3).
enum TableKind {
  /// User data: every row is replaced by the backup's rows.
  user,

  /// `exercises` and the exercise-owned tables: user and imported exercises
  /// are user data (replaced); system exercises are catalogue content
  /// (never deleted; device wins; missing ones inserted).
  exerciseAggregate,

  /// Reference and catalogue data: never deleted; missing rows inserted;
  /// an existing device row wins; the same key with different immutable
  /// content rejects the whole restore (D04 "Restore conflicts").
  reference,

  /// Report history: merged by stable id, never replaced (D04 "Restore
  /// conflicts", R-07, R-08).
  report,
}

@immutable
final class TableSpec {
  const TableSpec({
    required this.name,
    required this.kind,
    required this.columns,
    required this.primaryKey,
    this.uniques = const [],
    this.checks = const [],
    this.foreignKeys = const [],
    this.immutableColumns = const [],
  });

  final String name;
  final TableKind kind;
  final List<ColumnSpec> columns;
  final List<String> primaryKey;
  final List<List<String>> uniques;
  final List<CheckSpec> checks;
  final List<ForeignKeySpec> foreignKeys;

  /// For [TableKind.reference] (and system exercises): the columns whose
  /// difference for the same key rejects the whole restore. Every other
  /// column is device-wins content (`docs/backup-format-3.md` register
  /// B-04).
  final List<String> immutableColumns;

  ColumnSpec? column(String name) {
    for (final c in columns) {
      if (c.name == name) return c;
    }
    return null;
  }

  Set<String> get columnNames => {for (final c in columns) c.name};

  /// The record id of [row]: the single key value as text, or the JSON array
  /// of a composite key (the same form as the v7 → v8 migration's report).
  String keyOf(Map<String, Object?> row) => primaryKey.length == 1
      ? '${row[primaryKey.single]}'
      : jsonEncode([for (final c in primaryKey) row[c]]);
}

// ---- SQL value helpers ------------------------------------------------------

bool _isNull(Map<String, Object?> r, String c) => r[c] == null;

/// `c IS NULL OR c IN (values)`; a NOT NULL column never reaches the NULL
/// branch.
CheckSpec _inList(String sql, String c, List<Object> values) =>
    CheckSpec(sql, (r) => _isNull(r, c) || values.contains(r[c]));

CheckSpec _bool(String c) => _inList('CHECK ("$c" IN (0, 1))', c, const [0, 1]);

bool _between(Object? v, num lo, num hi) => v is num && v >= lo && v <= hi;

CheckSpec _nullOrBetween(String c, num lo, num hi) => CheckSpec(
  'CHECK ($c IS NULL OR $c BETWEEN $lo AND $hi)',
  (r) => _isNull(r, c) || _between(r[c], lo, hi),
);

CheckSpec _nullOrPositive(String c) => CheckSpec(
  'CHECK ($c IS NULL OR $c > 0)',
  (r) => _isNull(r, c) || (r[c]! as num) > 0,
);

/// SQLite `CAST(x AS INTEGER)` of a finite REAL: truncation toward zero.
num _castInteger(num x) => x is int ? x : x.truncate();

/// The schema v8 TRN-020 clause of `session_sets`
/// (`exertion_rule_sql.dart`), mirrored. NULL-safe like its `IS 1`.
bool exertionClausePasses(Object? scale, Object? value) {
  if (scale == null && value == null) return true;
  if (value is! num) return false;
  if (scale == 'rpe') {
    return value >= 1 && value <= 10 && value * 2 == _castInteger(value * 2);
  }
  if (scale == 'rir') {
    return value >= 0 && value <= 5 && value == _castInteger(value);
  }
  return false;
}

/// SQLite `length(text)`: characters (code points), not UTF-16 units.
int _sqlLength(String s) => s.runes.length;

/// `trim(x, ' ' || char(9,10,13))`: strips space, tab, line feed and carriage
/// return at both ends only.
String _sqlTrimNote(String s) {
  const strip = {0x20, 0x09, 0x0a, 0x0d};
  var start = 0;
  var end = s.length;
  while (start < end && strip.contains(s.codeUnitAt(start))) {
    start++;
  }
  while (end > start && strip.contains(s.codeUnitAt(end - 1))) {
    end--;
  }
  return s.substring(start, end);
}

/// SQLite `json_valid(x)` for TEXT (RFC 8259 JSON).
bool _jsonValid(Object? v) {
  if (v is! String) return false;
  try {
    jsonDecode(v);
    return true;
  } on FormatException {
    return false;
  }
}

// ---- Shared column groups ---------------------------------------------------

const _id = ColumnSpec('id', ColumnType.text, notNull: true);
const List<ColumnSpec> _sync = [
  _id,
  ColumnSpec('created_at', ColumnType.text, notNull: true),
  ColumnSpec('updated_at', ColumnType.text, notNull: true),
  ColumnSpec('deleted_at', ColumnType.text),
];
const _macros = [
  ColumnSpec('protein_g', ColumnType.real),
  ColumnSpec('carbs_g', ColumnType.real),
  ColumnSpec('fat_g', ColumnType.real),
  ColumnSpec('fibre_g', ColumnType.real),
];
const _pkId = ['id'];

const _categoryCodes = [
  'migrated',
  'preserved',
  'quarantinedOrUnresolved',
  'rejectedOrBlocked',
  'warningForReview',
];
const _dispositions = [
  'quarantined',
  'cleared',
  'retained',
  'mapped',
  'markerAdded',
  'skipped',
  'rejected',
  'blocked',
  'none',
  'corrected',
];
const _blockReasons = [
  'noPrimaryTarget',
  'unknownEquipment',
  'invalidEquipment',
  'invalidSecondaryTarget',
  'invalidClassification',
  'invalidAliases',
];

/// Every table of schema v8, in `AppDatabaseV8` order (parents before
/// children within each kind; the restore orders its writes itself).
final List<TableSpec> schemaV8Tables = List.unmodifiable([
  const TableSpec(
    name: 'measurements',
    kind: TableKind.user,
    columns: [
      ..._sync,
      ColumnSpec('site', ColumnType.text, notNull: true),
      ColumnSpec('value', ColumnType.real, notNull: true),
      ColumnSpec('recorded_at', ColumnType.text, notNull: true),
      ColumnSpec('note', ColumnType.text),
    ],
    primaryKey: _pkId,
  ),
  const TableSpec(
    name: 'foods',
    kind: TableKind.user,
    columns: [
      ..._sync,
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec('brand', ColumnType.text),
      ColumnSpec('barcode', ColumnType.text),
      ColumnSpec('per100_unit', ColumnType.text, notNull: true),
      ColumnSpec('kcal', ColumnType.real, notNull: true),
      ..._macros,
      ColumnSpec('provenance', ColumnType.text, notNull: true),
      ColumnSpec('source', ColumnType.text, notNull: true),
      ColumnSpec('search_key', ColumnType.text, notNull: true),
    ],
    primaryKey: _pkId,
  ),
  const TableSpec(
    name: 'food_servings',
    kind: TableKind.user,
    columns: [
      _id,
      ColumnSpec('food_id', ColumnType.text, notNull: true),
      ColumnSpec('label', ColumnType.text, notNull: true),
      ColumnSpec('amount', ColumnType.real, notNull: true),
      ColumnSpec('unit', ColumnType.text, notNull: true),
      ColumnSpec('sort_order', ColumnType.integer, notNull: true),
    ],
    primaryKey: _pkId,
    foreignKeys: [ForeignKeySpec('food_id', 'foods', 'id')],
  ),
  const TableSpec(
    name: 'food_log_entries',
    kind: TableKind.user,
    columns: [
      ..._sync,
      ColumnSpec('day', ColumnType.text, notNull: true),
      ColumnSpec('meal', ColumnType.text, notNull: true),
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec('food_id', ColumnType.text),
      ColumnSpec('recipe_id', ColumnType.text),
      ColumnSpec('amount', ColumnType.real, notNull: true),
      ColumnSpec('unit', ColumnType.text, notNull: true),
      ColumnSpec('kcal', ColumnType.real, notNull: true),
      ..._macros,
      ColumnSpec('provenance', ColumnType.text, notNull: true),
      ColumnSpec('logged_at', ColumnType.text, notNull: true),
    ],
    primaryKey: _pkId,
  ),
  const TableSpec(
    name: 'saved_meals',
    kind: TableKind.user,
    columns: [
      ..._sync,
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec('default_meal', ColumnType.text),
    ],
    primaryKey: _pkId,
  ),
  const TableSpec(
    name: 'saved_meal_items',
    kind: TableKind.user,
    columns: [
      _id,
      ColumnSpec('saved_meal_id', ColumnType.text, notNull: true),
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec('food_id', ColumnType.text),
      ColumnSpec('recipe_id', ColumnType.text),
      ColumnSpec('amount', ColumnType.real, notNull: true),
      ColumnSpec('unit', ColumnType.text, notNull: true),
      ColumnSpec('sort_order', ColumnType.integer, notNull: true),
      ColumnSpec('kcal', ColumnType.real, notNull: true),
      ..._macros,
      ColumnSpec('provenance', ColumnType.text, notNull: true),
    ],
    primaryKey: _pkId,
    foreignKeys: [ForeignKeySpec('saved_meal_id', 'saved_meals', 'id')],
  ),
  TableSpec(
    name: 'recipes',
    kind: TableKind.user,
    columns: const [
      ..._sync,
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec('category', ColumnType.text, notNull: true),
      ColumnSpec(
        'description',
        ColumnType.text,
        notNull: true,
        defaultValue: '',
      ),
      ColumnSpec('portions', ColumnType.real, notNull: true),
      ColumnSpec('prep_minutes', ColumnType.integer),
      ColumnSpec('cook_minutes', ColumnType.integer),
      ColumnSpec('storage', ColumnType.text),
      ColumnSpec(
        'freezing',
        ColumnType.text,
        notNull: true,
        defaultValue: 'unknown',
      ),
      ColumnSpec('reheating', ColumnType.text),
      ColumnSpec(
        'favourite',
        ColumnType.integer,
        notNull: true,
        defaultValue: 0,
      ),
      ColumnSpec(
        'prep_steps_json',
        ColumnType.text,
        notNull: true,
        defaultValue: '[]',
      ),
      ColumnSpec(
        'cook_steps_json',
        ColumnType.text,
        notNull: true,
        defaultValue: '[]',
      ),
      ColumnSpec('total_weight_g', ColumnType.real),
      ColumnSpec('portion_weight_g', ColumnType.real),
      ColumnSpec('declared_kcal', ColumnType.real),
      ColumnSpec('declared_protein_g', ColumnType.real),
      ColumnSpec('declared_carbs_g', ColumnType.real),
      ColumnSpec('declared_fat_g', ColumnType.real),
      ColumnSpec('declared_fibre_g', ColumnType.real),
      ColumnSpec('nutrition_note', ColumnType.text),
      ColumnSpec(
        'ingredient_notes_json',
        ColumnType.text,
        notNull: true,
        defaultValue: '[]',
      ),
    ],
    primaryKey: _pkId,
    checks: [_bool('favourite')],
  ),
  const TableSpec(
    name: 'recipe_ingredients',
    kind: TableKind.user,
    columns: [
      _id,
      ColumnSpec('recipe_id', ColumnType.text, notNull: true),
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec('food_id', ColumnType.text),
      ColumnSpec('amount', ColumnType.real, notNull: true),
      ColumnSpec('unit', ColumnType.text, notNull: true),
      ColumnSpec('sort_order', ColumnType.integer, notNull: true),
      ColumnSpec('note', ColumnType.text),
      ColumnSpec('kcal', ColumnType.real),
      ..._macros,
      ColumnSpec('provenance', ColumnType.text),
      ColumnSpec('serving_label', ColumnType.text),
      ColumnSpec('serving_count', ColumnType.real),
    ],
    primaryKey: _pkId,
    foreignKeys: [ForeignKeySpec('recipe_id', 'recipes', 'id')],
  ),
  const TableSpec(
    name: 'recipe_substitutes',
    kind: TableKind.user,
    columns: [
      _id,
      ColumnSpec('recipe_ingredient_id', ColumnType.text, notNull: true),
      ColumnSpec('sort_order', ColumnType.integer, notNull: true),
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec('food_id', ColumnType.text),
      ColumnSpec('amount', ColumnType.real, notNull: true),
      ColumnSpec('unit', ColumnType.text, notNull: true),
      ColumnSpec('kcal', ColumnType.real, notNull: true),
      ..._macros,
      ColumnSpec('provenance', ColumnType.text, notNull: true),
    ],
    primaryKey: _pkId,
    foreignKeys: [
      ForeignKeySpec('recipe_ingredient_id', 'recipe_ingredients', 'id'),
    ],
  ),
  const TableSpec(
    name: 'meal_plan_items',
    kind: TableKind.user,
    columns: [
      ..._sync,
      ColumnSpec('day', ColumnType.text, notNull: true),
      ColumnSpec('meal', ColumnType.text, notNull: true),
      ColumnSpec('kind', ColumnType.text, notNull: true),
      ColumnSpec('ref_id', ColumnType.text, notNull: true),
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec('amount', ColumnType.real, notNull: true),
      ColumnSpec('unit', ColumnType.text, notNull: true),
      ColumnSpec('eaten_entry_id', ColumnType.text),
      ColumnSpec('sort_order', ColumnType.integer, notNull: true),
    ],
    primaryKey: _pkId,
  ),
  TableSpec(
    name: 'prep_batches',
    kind: TableKind.user,
    columns: const [
      ..._sync,
      ColumnSpec('recipe_id', ColumnType.text, notNull: true),
      ColumnSpec('prepared_at', ColumnType.text, notNull: true),
      ColumnSpec('portions_made', ColumnType.real, notNull: true),
      ColumnSpec('portions_remaining', ColumnType.real, notNull: true),
    ],
    primaryKey: _pkId,
    checks: [
      CheckSpec(
        'CHECK("portions_remaining" >= 0.0)',
        (r) => (r['portions_remaining']! as num) >= 0,
      ),
    ],
    foreignKeys: const [ForeignKeySpec('recipe_id', 'recipes', 'id')],
  ),
  const TableSpec(
    name: 'content_providers',
    kind: TableKind.reference,
    columns: [
      _id,
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec('licence', ColumnType.text, notNull: true),
      ColumnSpec('attribution', ColumnType.text),
      ColumnSpec('url', ColumnType.text),
    ],
    primaryKey: _pkId,
  ),
  TableSpec(
    name: 'exercises',
    kind: TableKind.exerciseAggregate,
    columns: const [
      ..._sync,
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec('type', ColumnType.text, notNull: true),
      ColumnSpec('category', ColumnType.text, notNull: true),
      ColumnSpec(
        'aliases_json',
        ColumnType.text,
        notNull: true,
        defaultValue: '[]',
      ),
      ColumnSpec(
        'search_key',
        ColumnType.text,
        notNull: true,
        defaultValue: '',
      ),
      ColumnSpec('copied_from_id', ColumnType.text),
      ColumnSpec(
        'archived',
        ColumnType.integer,
        notNull: true,
        defaultValue: 0,
      ),
      ColumnSpec('source', ColumnType.text, notNull: true),
      ColumnSpec('provider_id', ColumnType.text),
      ColumnSpec('revision', ColumnType.integer),
      ColumnSpec('mechanics', ColumnType.text),
      ColumnSpec('laterality', ColumnType.text),
      ColumnSpec('difficulty', ColumnType.text),
      ColumnSpec('retired_at', ColumnType.text),
      ColumnSpec('angle', ColumnType.text),
      ColumnSpec('arm_position', ColumnType.text),
      ColumnSpec('body_position', ColumnType.text),
      ColumnSpec('grip', ColumnType.text),
      ColumnSpec('grip_width', ColumnType.text),
      ColumnSpec('knee_position', ColumnType.text),
      ColumnSpec('stance', ColumnType.text),
    ],
    primaryKey: _pkId,
    checks: [
      _bool('archived'),
      _inList(
        "CHECK (source IN ('system','user','imported'))",
        'source',
        const ['system', 'user', 'imported'],
      ),
      CheckSpec(
        'CHECK (revision IS NULL OR revision >= 1)',
        (r) => _isNull(r, 'revision') || (r['revision']! as num) >= 1,
      ),
      _inList(
        "CHECK (mechanics IS NULL OR mechanics IN ('compound','isolation'))",
        'mechanics',
        const ['compound', 'isolation'],
      ),
      _inList(
        'CHECK (laterality IS NULL OR laterality IN '
            "('bilateral','unilateral','alternating'))",
        'laterality',
        const ['bilateral', 'unilateral', 'alternating'],
      ),
      _inList(
        'CHECK (difficulty IS NULL OR difficulty IN '
            "('beginner','intermediate','advanced'))",
        'difficulty',
        const ['beginner', 'intermediate', 'advanced'],
      ),
      _inList(
        "CHECK (angle IS NULL OR angle IN ('flat','incline','decline'))",
        'angle',
        const ['flat', 'incline', 'decline'],
      ),
      _inList(
        'CHECK (arm_position IS NULL OR arm_position IN '
            "('besideBody','behindBody','supportedInFront','overhead',"
            "'flexed90','abducted90'))",
        'arm_position',
        const [
          'besideBody',
          'behindBody',
          'supportedInFront',
          'overhead',
          'flexed90',
          'abducted90',
        ],
      ),
      _inList(
        'CHECK (body_position IS NULL OR body_position IN '
            "('standing','seated','lying','prone','bentOver','kneeling',"
            "'halfKneeling','inclined'))",
        'body_position',
        const [
          'standing',
          'seated',
          'lying',
          'prone',
          'bentOver',
          'kneeling',
          'halfKneeling',
          'inclined',
        ],
      ),
      _inList(
        'CHECK (grip IS NULL OR grip IN '
            "('pronated','supinated','neutral','mixed'))",
        'grip',
        const ['pronated', 'supinated', 'neutral', 'mixed'],
      ),
      _inList(
        'CHECK (grip_width IS NULL OR grip_width IN '
            "('close','standard','wide'))",
        'grip_width',
        const ['close', 'standard', 'wide'],
      ),
      _inList(
        "CHECK (knee_position IS NULL OR knee_position IN ('straight','bent'))",
        'knee_position',
        const ['straight', 'bent'],
      ),
      _inList(
        'CHECK (stance IS NULL OR stance IN '
            "('narrow','standard','wide','split'))",
        'stance',
        const ['narrow', 'standard', 'wide', 'split'],
      ),
      CheckSpec(
        "CHECK (source <> 'system' OR (provider_id IS NOT NULL AND "
        'revision IS NOT NULL))',
        (r) =>
            r['source'] != 'system' ||
            (r['provider_id'] != null && r['revision'] != null),
      ),
    ],
    foreignKeys: const [
      ForeignKeySpec('provider_id', 'content_providers', 'id'),
    ],
    // No immutable column: B-01 (decided after B-04) lets a different
    // classification or provider of a device-kept system exercise never
    // reject the restore; field ownership decides
    // (`userOwnedExerciseColumns`).
  ),
  TableSpec(
    name: 'workout_plans',
    kind: TableKind.user,
    columns: const [
      ..._sync,
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec('split', ColumnType.text),
      ColumnSpec('scheduled_weekdays_json', ColumnType.text, notNull: true),
      ColumnSpec(
        'archived',
        ColumnType.integer,
        notNull: true,
        defaultValue: 0,
      ),
    ],
    primaryKey: _pkId,
    checks: [_bool('archived')],
  ),
  TableSpec(
    name: 'plan_exercises',
    kind: TableKind.user,
    columns: const [
      _id,
      ColumnSpec('plan_id', ColumnType.text, notNull: true),
      ColumnSpec('exercise_id', ColumnType.text, notNull: true),
      ColumnSpec('sort_order', ColumnType.integer, notNull: true),
      ColumnSpec('target_sets', ColumnType.integer, notNull: true),
      ColumnSpec('reps_min', ColumnType.integer),
      ColumnSpec('reps_max', ColumnType.integer),
      ColumnSpec('target_load_kg', ColumnType.real),
      ColumnSpec('target_duration_sec', ColumnType.integer),
      ColumnSpec('target_metres', ColumnType.real),
      ColumnSpec('rest_seconds', ColumnType.integer),
    ],
    primaryKey: _pkId,
    checks: [
      CheckSpec(
        'CHECK (sort_order >= 0)',
        (r) => (r['sort_order']! as num) >= 0,
      ),
      CheckSpec(
        'CHECK (target_sets BETWEEN 1 AND 20)',
        (r) => _between(r['target_sets'], 1, 20),
      ),
      _nullOrBetween('reps_min', 1, 100),
      _nullOrBetween('reps_max', 1, 100),
      CheckSpec(
        'CHECK ((reps_min IS NULL) = (reps_max IS NULL))',
        (r) => _isNull(r, 'reps_min') == _isNull(r, 'reps_max'),
      ),
      CheckSpec(
        'CHECK (reps_min IS NULL OR reps_min <= reps_max)',
        (r) =>
            _isNull(r, 'reps_min') ||
            _isNull(r, 'reps_max') ||
            (r['reps_min']! as num) <= (r['reps_max']! as num),
      ),
      _nullOrBetween('target_load_kg', 0, 1000),
      _nullOrPositive('target_duration_sec'),
      _nullOrPositive('target_metres'),
      _nullOrBetween('rest_seconds', 0, 3600),
    ],
    foreignKeys: const [ForeignKeySpec('plan_id', 'workout_plans', 'id')],
  ),
  const TableSpec(
    name: 'workout_sessions',
    kind: TableKind.user,
    columns: [
      ..._sync,
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec('plan_id', ColumnType.text),
      ColumnSpec('started_at', ColumnType.text, notNull: true),
      ColumnSpec('ended_at', ColumnType.text),
      ColumnSpec('notes', ColumnType.text, notNull: true, defaultValue: ''),
    ],
    primaryKey: _pkId,
  ),
  TableSpec(
    name: 'session_exercises',
    kind: TableKind.user,
    columns: const [
      _id,
      ColumnSpec('session_id', ColumnType.text, notNull: true),
      ColumnSpec('position', ColumnType.integer, notNull: true),
      ColumnSpec('exercise_id', ColumnType.text, notNull: true),
      ColumnSpec('note', ColumnType.text),
    ],
    primaryKey: _pkId,
    checks: [
      CheckSpec('CHECK (position >= 0)', (r) => (r['position']! as num) >= 0),
      CheckSpec(
        'CHECK (note IS NULL OR length(note) <= 4000)',
        (r) => _isNull(r, 'note') || _sqlLength(r['note']! as String) <= 4000,
      ),
    ],
    foreignKeys: const [ForeignKeySpec('session_id', 'workout_sessions', 'id')],
  ),
  TableSpec(
    name: 'session_sets',
    kind: TableKind.user,
    columns: const [
      _id,
      ColumnSpec('session_id', ColumnType.text, notNull: true),
      ColumnSpec('exercise_id', ColumnType.text, notNull: true),
      ColumnSpec('exercise_order', ColumnType.integer, notNull: true),
      ColumnSpec('set_order', ColumnType.integer, notNull: true),
      ColumnSpec('type', ColumnType.text, notNull: true),
      ColumnSpec('load_kg', ColumnType.real),
      ColumnSpec('reps', ColumnType.integer),
      ColumnSpec('assistance_kg', ColumnType.real),
      ColumnSpec('duration_sec', ColumnType.integer),
      ColumnSpec('metres', ColumnType.real),
      ColumnSpec('average_heart_rate', ColumnType.integer),
      ColumnSpec('energy_kcal', ColumnType.real),
      ColumnSpec('energy_provenance', ColumnType.text),
      ColumnSpec(
        'completed',
        ColumnType.integer,
        notNull: true,
        defaultValue: 1,
      ),
      ColumnSpec('exertion_scale', ColumnType.text),
      ColumnSpec('exertion_value', ColumnType.real),
      ColumnSpec('rest_seconds', ColumnType.integer),
      ColumnSpec('note', ColumnType.text),
      ColumnSpec(
        'set_kind',
        ColumnType.text,
        notNull: true,
        defaultValue: 'working',
      ),
      ColumnSpec('session_exercise_id', ColumnType.text),
    ],
    primaryKey: _pkId,
    checks: [
      _bool('completed'),
      _inList(
        "CHECK (set_kind IN ('warmUp', 'working', 'failure'))",
        'set_kind',
        const ['warmUp', 'working', 'failure'],
      ),
      _nullOrBetween('reps', 1, 100),
      _nullOrBetween('load_kg', 0, 1000),
      _nullOrBetween('assistance_kg', 0, 1000),
      _nullOrPositive('duration_sec'),
      _nullOrPositive('metres'),
      _nullOrBetween('average_heart_rate', 30, 250),
      CheckSpec(
        'CHECK (energy_kcal IS NULL OR energy_kcal >= 0)',
        (r) => _isNull(r, 'energy_kcal') || (r['energy_kcal']! as num) >= 0,
      ),
      _inList(
        'CHECK (energy_provenance IS NULL OR energy_provenance IN '
            "('userEntered', 'estimated'))",
        'energy_provenance',
        const ['userEntered', 'estimated'],
      ),
      CheckSpec(
        'CHECK ((energy_kcal IS NULL) = (energy_provenance IS NULL))',
        (r) => _isNull(r, 'energy_kcal') == _isNull(r, 'energy_provenance'),
      ),
      CheckSpec(
        'CHECK (TRN-020 exertion rule, exertion_rule_sql.dart)',
        (r) => exertionClausePasses(r['exertion_scale'], r['exertion_value']),
      ),
      _nullOrBetween('rest_seconds', 0, 3600),
    ],
    foreignKeys: const [
      ForeignKeySpec('session_id', 'workout_sessions', 'id'),
      ForeignKeySpec('session_exercise_id', 'session_exercises', 'id'),
    ],
  ),
  TableSpec(
    name: 'scheduled_workouts',
    kind: TableKind.user,
    columns: const [
      ..._sync,
      ColumnSpec('day', ColumnType.text, notNull: true),
      ColumnSpec('source_day', ColumnType.text, notNull: true),
      ColumnSpec('plan_id', ColumnType.text, notNull: true),
      ColumnSpec('origin', ColumnType.text, notNull: true),
      ColumnSpec('status', ColumnType.text, notNull: true),
      ColumnSpec('session_id', ColumnType.text),
    ],
    primaryKey: _pkId,
    checks: [
      _inList(
        "CHECK (origin IN ('date', 'weekday', 'split'))",
        'origin',
        const ['date', 'weekday', 'split'],
      ),
      _inList(
        "CHECK (status IN ('planned', 'skipped', 'done'))",
        'status',
        const ['planned', 'skipped', 'done'],
      ),
    ],
  ),
  TableSpec(
    name: 'training_splits',
    kind: TableKind.user,
    columns: const [
      ..._sync,
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec('cycle_days', ColumnType.integer, notNull: true),
      ColumnSpec(
        'sort_order',
        ColumnType.integer,
        notNull: true,
        defaultValue: 0,
      ),
    ],
    primaryKey: _pkId,
    checks: [
      CheckSpec(
        'CHECK (cycle_days BETWEEN 1 AND 14)',
        (r) => _between(r['cycle_days'], 1, 14),
      ),
    ],
  ),
  TableSpec(
    name: 'split_days',
    kind: TableKind.user,
    columns: const [
      _id,
      ColumnSpec('split_id', ColumnType.text, notNull: true),
      ColumnSpec('day_index', ColumnType.integer, notNull: true),
      ColumnSpec('plan_id', ColumnType.text),
    ],
    primaryKey: _pkId,
    uniques: const [
      ['split_id', 'day_index'],
    ],
    checks: [
      CheckSpec(
        'CHECK (day_index BETWEEN 0 AND 13)',
        (r) => _between(r['day_index'], 0, 13),
      ),
    ],
    foreignKeys: const [ForeignKeySpec('split_id', 'training_splits', 'id')],
  ),
  const TableSpec(
    name: 'legacy_quarantine',
    kind: TableKind.user,
    columns: [
      ColumnSpec('id', ColumnType.integer, notNull: true, autoIncrement: true),
      ColumnSpec('source_table', ColumnType.text, notNull: true),
      ColumnSpec('row_id', ColumnType.text, notNull: true),
      ColumnSpec('reason', ColumnType.text, notNull: true),
      ColumnSpec('original_json', ColumnType.text, notNull: true),
      ColumnSpec('quarantined_at', ColumnType.text, notNull: true),
    ],
    primaryKey: _pkId,
  ),
  TableSpec(
    name: 'goals',
    kind: TableKind.user,
    columns: const [
      ..._sync,
      ColumnSpec('kind', ColumnType.text, notNull: true),
      ColumnSpec('site', ColumnType.text),
      ColumnSpec('target', ColumnType.real, notNull: true),
      ColumnSpec('start_date', ColumnType.text, notNull: true),
      ColumnSpec('end_date', ColumnType.text),
      ColumnSpec('active', ColumnType.integer, notNull: true, defaultValue: 1),
    ],
    primaryKey: _pkId,
    checks: [_bool('active')],
  ),
  const TableSpec(
    name: 'settings',
    kind: TableKind.user,
    columns: [
      ColumnSpec('key', ColumnType.text, notNull: true),
      ColumnSpec('value', ColumnType.text, notNull: true),
      ColumnSpec('updated_at', ColumnType.text, notNull: true),
    ],
    primaryKey: ['key'],
  ),
  TableSpec(
    name: 'catalogue_releases',
    kind: TableKind.reference,
    columns: const [
      ColumnSpec('provider_id', ColumnType.text, notNull: true),
      ColumnSpec('release', ColumnType.integer, notNull: true),
      ColumnSpec('applied_at', ColumnType.text, notNull: true),
      ColumnSpec('applied_at_source', ColumnType.text, notNull: true),
      ColumnSpec('content_hash_algorithm', ColumnType.text, notNull: true),
      ColumnSpec('content_hash_encoding', ColumnType.text, notNull: true),
      ColumnSpec('content_hash', ColumnType.text, notNull: true),
      ColumnSpec('inserted', ColumnType.integer),
      ColumnSpec('updated', ColumnType.integer),
      ColumnSpec('retired', ColumnType.integer),
      ColumnSpec('app_version', ColumnType.text),
    ],
    primaryKey: const ['provider_id', 'release'],
    checks: [
      CheckSpec('CHECK ("release" >= 1)', (r) => (r['release']! as num) >= 1),
      CheckSpec(
        'CHECK (length(applied_at_source) > 0)',
        (r) => _sqlLength(r['applied_at_source']! as String) > 0,
      ),
      _inList(
        "CHECK (content_hash_algorithm IN ('sha256'))",
        'content_hash_algorithm',
        const ['sha256'],
      ),
      _inList(
        "CHECK (content_hash_encoding IN ('hex-lower'))",
        'content_hash_encoding',
        const ['hex-lower'],
      ),
      CheckSpec(
        'CHECK (length(content_hash) = 64 AND content_hash NOT GLOB '
        "'*[^0-9a-f]*')",
        (r) => RegExp(r'^[0-9a-f]{64}$').hasMatch(r['content_hash']! as String),
      ),
      // R-30 / B-07 option b: NULL means not known, never 0.
      for (final c in const ['inserted', 'updated', 'retired'])
        CheckSpec(
          'CHECK ($c IS NULL OR $c >= 0)',
          (r) => _isNull(r, c) || (r[c]! as num) >= 0,
        ),
    ],
    foreignKeys: const [
      ForeignKeySpec('provider_id', 'content_providers', 'id'),
    ],
    immutableColumns: const [
      'content_hash_algorithm',
      'content_hash_encoding',
      'content_hash',
    ],
  ),
  TableSpec(
    name: 'anatomy_nodes',
    kind: TableKind.reference,
    columns: const [
      _id,
      ColumnSpec('parent_id', ColumnType.text),
      ColumnSpec('level', ColumnType.integer, notNull: true),
      ColumnSpec('non_anatomical', ColumnType.integer, notNull: true),
      ColumnSpec('sort_order', ColumnType.integer, notNull: true),
      ColumnSpec('provider_id', ColumnType.text, notNull: true),
    ],
    primaryKey: _pkId,
    checks: [
      CheckSpec(
        'CHECK (level BETWEEN 1 AND 4)',
        (r) => _between(r['level'], 1, 4),
      ),
      _bool('non_anatomical'),
      CheckSpec(
        'CHECK ((level = 1) = (parent_id IS NULL))',
        (r) => (r['level'] == 1) == _isNull(r, 'parent_id'),
      ),
      CheckSpec(
        'CHECK (parent_id IS NULL OR parent_id <> id)',
        (r) => _isNull(r, 'parent_id') || r['parent_id'] != r['id'],
      ),
      CheckSpec(
        'CHECK (non_anatomical = 0 OR level = 1)',
        (r) => r['non_anatomical'] == 0 || r['level'] == 1,
      ),
    ],
    foreignKeys: const [
      ForeignKeySpec('parent_id', 'anatomy_nodes', 'id'),
      ForeignKeySpec('provider_id', 'content_providers', 'id'),
    ],
    immutableColumns: const [
      'parent_id',
      'level',
      'non_anatomical',
      'provider_id',
    ],
  ),
  TableSpec(
    name: 'movement_patterns',
    kind: TableKind.reference,
    columns: const [
      _id,
      ColumnSpec('parent_id', ColumnType.text),
      ColumnSpec('sort_order', ColumnType.integer, notNull: true),
      ColumnSpec('provider_id', ColumnType.text, notNull: true),
    ],
    primaryKey: _pkId,
    checks: [
      CheckSpec(
        'CHECK (parent_id IS NULL OR parent_id <> id)',
        (r) => _isNull(r, 'parent_id') || r['parent_id'] != r['id'],
      ),
    ],
    foreignKeys: const [
      ForeignKeySpec('parent_id', 'movement_patterns', 'id'),
      ForeignKeySpec('provider_id', 'content_providers', 'id'),
    ],
    immutableColumns: const ['parent_id', 'provider_id'],
  ),
  TableSpec(
    name: 'equipment_items',
    kind: TableKind.reference,
    columns: const [
      _id,
      ColumnSpec('sort_order', ColumnType.integer, notNull: true),
      ColumnSpec('default_role', ColumnType.text, notNull: true),
      ColumnSpec('provider_id', ColumnType.text, notNull: true),
    ],
    primaryKey: _pkId,
    checks: [
      _inList(
        "CHECK (default_role IN ('load','support','cardio','implement'))",
        'default_role',
        const ['load', 'support', 'cardio', 'implement'],
      ),
    ],
    foreignKeys: const [
      ForeignKeySpec('provider_id', 'content_providers', 'id'),
    ],
    // ADR-0008 E Q8 and clarification 2; register R-20.
    immutableColumns: const ['default_role', 'provider_id'],
  ),
  const TableSpec(
    name: 'reference_labels',
    kind: TableKind.reference,
    columns: [
      ColumnSpec('kind', ColumnType.text, notNull: true),
      ColumnSpec('id', ColumnType.text, notNull: true),
      ColumnSpec('locale', ColumnType.text, notNull: true),
      ColumnSpec('label', ColumnType.text, notNull: true),
    ],
    primaryKey: ['kind', 'id', 'locale'],
  ),
  TableSpec(
    name: 'exercise_targets',
    kind: TableKind.exerciseAggregate,
    columns: const [
      ColumnSpec('exercise_id', ColumnType.text, notNull: true),
      ColumnSpec('node_id', ColumnType.text, notNull: true),
      ColumnSpec('role', ColumnType.text, notNull: true),
      ColumnSpec('ordinal', ColumnType.integer, notNull: true),
    ],
    primaryKey: const ['exercise_id', 'node_id'],
    uniques: const [
      ['exercise_id', 'ordinal'],
    ],
    checks: [
      _inList("CHECK (role IN ('primary','secondary'))", 'role', const [
        'primary',
        'secondary',
      ]),
      CheckSpec('CHECK (ordinal >= 0)', (r) => (r['ordinal']! as num) >= 0),
    ],
    foreignKeys: const [
      ForeignKeySpec('exercise_id', 'exercises', 'id'),
      ForeignKeySpec('node_id', 'anatomy_nodes', 'id'),
    ],
  ),
  TableSpec(
    name: 'exercise_patterns',
    kind: TableKind.exerciseAggregate,
    columns: const [
      ColumnSpec('exercise_id', ColumnType.text, notNull: true),
      ColumnSpec('pattern_id', ColumnType.text, notNull: true),
      ColumnSpec('ordinal', ColumnType.integer, notNull: true),
    ],
    primaryKey: const ['exercise_id', 'pattern_id'],
    uniques: const [
      ['exercise_id', 'ordinal'],
    ],
    checks: [
      CheckSpec('CHECK (ordinal >= 0)', (r) => (r['ordinal']! as num) >= 0),
    ],
    foreignKeys: const [
      ForeignKeySpec('exercise_id', 'exercises', 'id'),
      ForeignKeySpec('pattern_id', 'movement_patterns', 'id'),
    ],
  ),
  TableSpec(
    name: 'exercise_equipment',
    kind: TableKind.exerciseAggregate,
    columns: const [
      ColumnSpec('exercise_id', ColumnType.text, notNull: true),
      ColumnSpec('equipment_id', ColumnType.text, notNull: true),
      ColumnSpec('ordinal', ColumnType.integer, notNull: true),
      ColumnSpec('role_override', ColumnType.text),
      ColumnSpec('override_note', ColumnType.text),
    ],
    primaryKey: const ['exercise_id', 'equipment_id'],
    uniques: const [
      ['exercise_id', 'ordinal'],
    ],
    checks: [
      CheckSpec('CHECK (ordinal >= 0)', (r) => (r['ordinal']! as num) >= 0),
      _inList(
        'CHECK (role_override IS NULL OR role_override IN '
            "('load','support'))",
        'role_override',
        const ['load', 'support'],
      ),
      CheckSpec(
        'CHECK (role_override IS NULL OR (override_note IS NOT NULL AND '
        "length(trim(override_note, ' ' || char(9,10,13))) > 0))",
        (r) =>
            _isNull(r, 'role_override') ||
            (r['override_note'] is String &&
                _sqlTrimNote(r['override_note']! as String).isNotEmpty),
      ),
    ],
    foreignKeys: const [
      ForeignKeySpec('exercise_id', 'exercises', 'id'),
      ForeignKeySpec('equipment_id', 'equipment_items', 'id'),
    ],
  ),
  TableSpec(
    name: 'exercise_names',
    kind: TableKind.exerciseAggregate,
    columns: const [
      ColumnSpec('exercise_id', ColumnType.text, notNull: true),
      ColumnSpec('locale', ColumnType.text, notNull: true),
      ColumnSpec('name', ColumnType.text, notNull: true),
      ColumnSpec(
        'aliases_json',
        ColumnType.text,
        notNull: true,
        defaultValue: '[]',
      ),
    ],
    primaryKey: const ['exercise_id', 'locale'],
    checks: [
      CheckSpec("CHECK (locale <> 'en-GB')", (r) => r['locale'] != 'en-GB'),
    ],
    foreignKeys: const [ForeignKeySpec('exercise_id', 'exercises', 'id')],
  ),
  TableSpec(
    name: 'exercise_user_state',
    kind: TableKind.user,
    columns: const [
      ColumnSpec('exercise_id', ColumnType.text, notNull: true),
      ColumnSpec(
        'favourite',
        ColumnType.integer,
        notNull: true,
        defaultValue: 0,
      ),
      ColumnSpec('hidden', ColumnType.integer, notNull: true, defaultValue: 0),
      ColumnSpec('last_used_at', ColumnType.text),
    ],
    primaryKey: const ['exercise_id'],
    checks: [_bool('favourite'), _bool('hidden')],
  ),
  TableSpec(
    name: 'exercise_blocks',
    kind: TableKind.exerciseAggregate,
    columns: const [
      ColumnSpec('exercise_id', ColumnType.text, notNull: true),
      ColumnSpec('reason', ColumnType.text, notNull: true),
      ColumnSpec('original_json', ColumnType.text, notNull: true),
      ColumnSpec('blocked_at', ColumnType.text, notNull: true),
      ColumnSpec('resolved_at', ColumnType.text),
    ],
    primaryKey: const ['exercise_id', 'reason'],
    checks: [
      _inList(
        'CHECK (reason IN '
            "('noPrimaryTarget','unknownEquipment','invalidEquipment', ...))",
        'reason',
        _blockReasons,
      ),
    ],
    foreignKeys: const [ForeignKeySpec('exercise_id', 'exercises', 'id')],
  ),
  TableSpec(
    name: 'migration_runs',
    kind: TableKind.report,
    columns: const [
      _id,
      ColumnSpec('trigger_kind', ColumnType.text, notNull: true),
      ColumnSpec('from_version', ColumnType.integer),
      ColumnSpec('to_version', ColumnType.integer),
      ColumnSpec('generated_at', ColumnType.text, notNull: true),
      ColumnSpec('app_version', ColumnType.text, notNull: true),
      ColumnSpec('provenance_kind', ColumnType.text, notNull: true),
      ColumnSpec('provenance_source', ColumnType.text, notNull: true),
      ColumnSpec('merged_at', ColumnType.text),
    ],
    primaryKey: _pkId,
    checks: [
      _inList(
        'CHECK (trigger_kind IN '
            "('migration','restore','integrityCheck','catalogueUpdate',"
            "'userCorrection'))",
        'trigger_kind',
        const [
          'migration',
          'restore',
          'integrityCheck',
          'catalogueUpdate',
          'userCorrection',
        ],
      ),
      _inList(
        "CHECK (provenance_kind IN ('device','backup'))",
        'provenance_kind',
        const ['device', 'backup'],
      ),
      CheckSpec(
        "CHECK (trigger_kind <> 'migration' OR (from_version IS NOT NULL AND "
        'to_version IS NOT NULL AND from_version < to_version))',
        (r) =>
            r['trigger_kind'] != 'migration' ||
            (r['from_version'] != null &&
                r['to_version'] != null &&
                (r['from_version']! as num) < (r['to_version']! as num)),
      ),
      CheckSpec(
        "CHECK ((provenance_kind = 'backup') = (merged_at IS NOT NULL))",
        (r) => (r['provenance_kind'] == 'backup') == !_isNull(r, 'merged_at'),
      ),
    ],
  ),
  TableSpec(
    name: 'migration_report_counts',
    kind: TableKind.report,
    columns: const [
      ColumnSpec('run_id', ColumnType.text, notNull: true),
      ColumnSpec('source_table', ColumnType.text, notNull: true),
      ColumnSpec('dimension', ColumnType.text, notNull: true),
      ColumnSpec('code', ColumnType.text, notNull: true),
      ColumnSpec('record_count', ColumnType.integer, notNull: true),
    ],
    primaryKey: const ['run_id', 'source_table', 'dimension', 'code'],
    checks: [
      _inList(
        "CHECK (dimension IN ('category','disposition'))",
        'dimension',
        const ['category', 'disposition'],
      ),
      CheckSpec(
        'CHECK (record_count >= 0)',
        (r) => (r['record_count']! as num) >= 0,
      ),
      CheckSpec(
        "CHECK ((dimension = 'category' AND code IN ('examined', ...)) OR "
        "(dimension = 'disposition' AND code IN ('quarantined', ...)))",
        (r) =>
            (r['dimension'] == 'category' &&
                (r['code'] == 'examined' ||
                    _categoryCodes.contains(r['code']))) ||
            (r['dimension'] == 'disposition' &&
                _dispositions.contains(r['code'])),
      ),
    ],
    foreignKeys: const [ForeignKeySpec('run_id', 'migration_runs', 'id')],
  ),
  TableSpec(
    name: 'migration_report_entries',
    kind: TableKind.report,
    columns: const [
      ColumnSpec('event_id', ColumnType.text, notNull: true),
      ColumnSpec('run_id', ColumnType.text, notNull: true),
      ColumnSpec('source_table', ColumnType.text, notNull: true),
      ColumnSpec('record_id', ColumnType.text, notNull: true),
      ColumnSpec('exercise_id', ColumnType.text),
      ColumnSpec('field', ColumnType.text, notNull: true),
      ColumnSpec('position', ColumnType.integer),
      ColumnSpec('original_value', ColumnType.text, notNull: true),
      ColumnSpec('resulting_value', ColumnType.text, notNull: true),
      ColumnSpec('element', ColumnType.text),
      ColumnSpec('disposition', ColumnType.text, notNull: true),
      ColumnSpec('block_reason', ColumnType.text),
      ColumnSpec('rule', ColumnType.text, notNull: true),
      ColumnSpec('reason', ColumnType.text, notNull: true),
      ColumnSpec('category', ColumnType.text, notNull: true),
      ColumnSpec('quarantine_id', ColumnType.integer),
      ColumnSpec('acknowledged_at', ColumnType.text),
    ],
    primaryKey: const ['event_id'],
    checks: [
      CheckSpec(
        'CHECK (position IS NULL OR position >= 0)',
        (r) => _isNull(r, 'position') || (r['position']! as num) >= 0,
      ),
      CheckSpec(
        'CHECK (json_valid(original_value))',
        (r) => _jsonValid(r['original_value']),
      ),
      CheckSpec(
        'CHECK (json_valid(resulting_value))',
        (r) => _jsonValid(r['resulting_value']),
      ),
      CheckSpec(
        'CHECK (element IS NULL OR json_valid(element))',
        (r) => _isNull(r, 'element') || _jsonValid(r['element']),
      ),
      _inList(
        "CHECK (disposition IN ('quarantined', ...))",
        'disposition',
        _dispositions,
      ),
      _inList(
        "CHECK (block_reason IS NULL OR block_reason IN ('noPrimaryTarget', "
            '...))',
        'block_reason',
        _blockReasons,
      ),
      _inList(
        "CHECK (category IN ('migrated', ...))",
        'category',
        _categoryCodes,
      ),
      CheckSpec(
        "CHECK ((disposition = 'blocked') = (block_reason IS NOT NULL))",
        (r) => (r['disposition'] == 'blocked') == !_isNull(r, 'block_reason'),
      ),
    ],
    foreignKeys: const [ForeignKeySpec('run_id', 'migration_runs', 'id')],
  ),
]);

/// [schemaV8Tables] by name.
final Map<String, TableSpec> schemaV8ByName = Map.unmodifiable({
  for (final t in schemaV8Tables) t.name: t,
});

/// The tables of schema v7 (`AppDatabase` at schema 7; formats 1 and 2
/// carry a subset of them). Every v7 table except `exercises` has the same
/// columns in v8 (`docs/schema-v8.md` section 2; `session_sets` differs
/// only by a CHECK clause).
const List<String> schemaV7TableNames = [
  'measurements',
  'foods',
  'food_servings',
  'food_log_entries',
  'saved_meals',
  'saved_meal_items',
  'recipes',
  'recipe_ingredients',
  'recipe_substitutes',
  'meal_plan_items',
  'prep_batches',
  'exercises',
  'workout_plans',
  'plan_exercises',
  'workout_sessions',
  'session_exercises',
  'session_sets',
  'scheduled_workouts',
  'training_splits',
  'split_days',
  'legacy_quarantine',
  'goals',
  'settings',
];

/// Columns of v7 `exercises` (`drift_schema_v7.json`), with their v7
/// `NOT NULL` flag and default.
const List<ColumnSpec> v7ExerciseColumns = [
  ColumnSpec('id', ColumnType.text, notNull: true),
  ColumnSpec('created_at', ColumnType.text, notNull: true),
  ColumnSpec('updated_at', ColumnType.text, notNull: true),
  ColumnSpec('deleted_at', ColumnType.text),
  ColumnSpec('name', ColumnType.text, notNull: true),
  ColumnSpec('type', ColumnType.text, notNull: true),
  ColumnSpec('category', ColumnType.text, notNull: true),
  ColumnSpec('primary_muscle', ColumnType.text, notNull: true),
  ColumnSpec('secondary_muscles_json', ColumnType.text, notNull: true),
  ColumnSpec('equipment_json', ColumnType.text, notNull: true),
  ColumnSpec(
    'aliases_json',
    ColumnType.text,
    notNull: true,
    defaultValue: '[]',
  ),
  ColumnSpec('search_key', ColumnType.text, notNull: true, defaultValue: ''),
  ColumnSpec('supplied', ColumnType.integer, notNull: true, defaultValue: 0),
  ColumnSpec('copied_from_id', ColumnType.text),
  ColumnSpec('archived', ColumnType.integer, notNull: true, defaultValue: 0),
];

/// Columns of the pre-v6 and pre-v5 eras that the restore consumes through
/// the legacy mappings (production `DriftBackupRepository._fromOlderSchema`,
/// `LegacyTrainingRowsV6`). Production restore dropped any other unknown
/// column silently; the v8 restore rejects it (register B-09).
const Map<String, Set<String>> legacyConsumedColumns = {
  'recipes': {'method_steps_json', 'freezer_friendly'},
  'exercises': {'is_custom'},
  'plan_exercises': {'target_reps'},
};
