import 'package:drift/drift.dart';

import '../data/generated_migrations/schema_v7.dart' as v7;

/// Planned v8 `exercises` table, written by hand in the style of the
/// generated schema classes so drift's `TableMigration` can rebuild into it.
///
/// Trial assumptions (the plan names the columns but not every constraint):
/// `source` is NOT NULL, default `user`, CHECK `system|user|imported`;
/// `mechanics`, `laterality`, `difficulty` use the closed value lists of
/// ADR-0008; `revision` must be at least 1 when present.
class TrialExercisesV8 extends Table with TableInfo<TrialExercisesV8, Object> {
  TrialExercisesV8(this.attachedDatabase, [this._alias]);

  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;

  GeneratedColumn<String> _text(
    String name,
    String constraints, {
    bool nullable = false,
    String? defaultSql,
  }) => GeneratedColumn<String>(
    name,
    aliasedName,
    nullable,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    $customConstraints: constraints,
    defaultValue: defaultSql == null ? null : CustomExpression(defaultSql),
  );

  late final GeneratedColumn<String> id = _text('id', 'NOT NULL');
  late final GeneratedColumn<String> createdAt = _text(
    'created_at',
    'NOT NULL',
  );
  late final GeneratedColumn<String> updatedAt = _text(
    'updated_at',
    'NOT NULL',
  );
  late final GeneratedColumn<String> deletedAt = _text(
    'deleted_at',
    'NULL',
    nullable: true,
  );
  late final GeneratedColumn<String> name = _text('name', 'NOT NULL');
  late final GeneratedColumn<String> type = _text('type', 'NOT NULL');
  late final GeneratedColumn<String> category = _text('category', 'NOT NULL');
  late final GeneratedColumn<String> equipmentJson = _text(
    'equipment_json',
    'NOT NULL',
  );
  late final GeneratedColumn<String> aliasesJson = _text(
    'aliases_json',
    "NOT NULL DEFAULT '[]'",
    defaultSql: "'[]'",
  );
  late final GeneratedColumn<String> searchKey = _text(
    'search_key',
    "NOT NULL DEFAULT ''",
    defaultSql: "''",
  );
  late final GeneratedColumn<String> copiedFromId = _text(
    'copied_from_id',
    'NULL',
    nullable: true,
  );
  late final GeneratedColumn<int> archived = GeneratedColumn<int>(
    'archived',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NOT NULL DEFAULT 0 CHECK (archived IN (0, 1))',
    defaultValue: const CustomExpression('0'),
  );
  late final GeneratedColumn<String> source = _text(
    'source',
    "NOT NULL DEFAULT 'user' CHECK (source IN ('system', 'user', 'imported'))",
    defaultSql: "'user'",
  );
  late final GeneratedColumn<String> providerId = _text(
    'provider_id',
    'NULL',
    nullable: true,
  );
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    $customConstraints: 'NULL CHECK (revision IS NULL OR revision >= 1)',
  );
  late final GeneratedColumn<String> mechanics = _text(
    'mechanics',
    "NULL CHECK (mechanics IN ('compound', 'isolation'))",
    nullable: true,
  );
  late final GeneratedColumn<String> laterality = _text(
    'laterality',
    "NULL CHECK (laterality IN ('bilateral', 'unilateral', 'alternating'))",
    nullable: true,
  );
  late final GeneratedColumn<String> difficulty = _text(
    'difficulty',
    "NULL CHECK (difficulty IN ('beginner', 'intermediate', 'advanced'))",
    nullable: true,
  );
  late final GeneratedColumn<String> retiredAt = _text(
    'retired_at',
    'NULL',
    nullable: true,
  );

  @override
  List<GeneratedColumn> get $columns => [
    id,
    createdAt,
    updatedAt,
    deletedAt,
    name,
    type,
    category,
    equipmentJson,
    aliasesJson,
    searchKey,
    copiedFromId,
    archived,
    source,
    providerId,
    revision,
    mechanics,
    laterality,
    difficulty,
    retiredAt,
  ];

  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'exercises';
  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Object map(Map<String, dynamic> data, {String? tablePrefix}) =>
      throw UnsupportedError('trial table is used for DDL only');
  @override
  TrialExercisesV8 createAlias(String alias) =>
      TrialExercisesV8(attachedDatabase, alias);
  @override
  List<String> get customConstraints => const ['PRIMARY KEY(id)'];
  @override
  bool get dontWriteConstraints => true;
}

/// The planned TRN-020 rule for `exertion_scale` and `exertion_value`
/// (plan safeguard C), as a boolean SQL expression over the given column
/// references. NULL-safe: it yields 1 or 0 only.
String exertionRuleSql({String scale = 'exertion_scale', String? value}) {
  final v = value ?? 'exertion_value';
  return '''
(($scale IS NULL AND $v IS NULL)
 OR ($scale = 'rpe' AND $v BETWEEN 1 AND 10
     AND $v * 2 = CAST($v * 2 AS INTEGER))
 OR ($scale = 'rir' AND $v BETWEEN 0 AND 5
     AND $v = CAST($v AS INTEGER))) IS 1''';
}

/// `session_sets` with the TRN-020 rule as table CHECKs. The old
/// `exertion_value BETWEEN 0 AND 10` check is replaced by the scale rule.
class TrialSessionSetsV8 extends v7.SessionSets {
  TrialSessionSetsV8(super.attachedDatabase, [super.alias]);

  @override
  TrialSessionSetsV8 createAlias(String alias) =>
      TrialSessionSetsV8(attachedDatabase, alias);

  @override
  List<String> get customConstraints => [
    for (final c in super.customConstraints)
      if (!c.contains('exertion_value')) c,
    'CHECK(${exertionRuleSql().replaceAll('\n', ' ')})',
  ];
}
