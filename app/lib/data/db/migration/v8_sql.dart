import 'dart:convert';

import 'package:drift/drift.dart';

/// Small SQL helpers over a drift connection, shared by the v7 → v8 step
/// (`v7_to_v8.dart`) and the unconnected v8 backup repository
/// (`lib/data/repositories/v8/`). **Not connected to the app** (the
/// architecture gates in `test/architecture/` list every importer).
///
/// WP 8 3b-10 (Review C L-3, L-5, M-2): one copy of the select/variable
/// helpers, quoted identifiers with `"` escaped, the foreign-key finding key
/// and multi-row inserts (one statement per [maxSqlVariables] values instead
/// of one per row; each statement crosses the isolate boundary once).
final class V8Sql {
  V8Sql(this.db);

  final DatabaseConnectionUser db;

  /// Host parameters per statement: SQLite's compile-time limit before
  /// 3.32 (`SQLITE_MAX_VARIABLE_NUMBER`), safe on every build.
  static const int maxSqlVariables = 999;

  /// [identifier] as an SQL quoted identifier (`"` doubled).
  static String quote(String identifier) =>
      '"${identifier.replaceAll('"', '""')}"';

  /// A drift variable for a stored value (NULL, TEXT, INTEGER or REAL).
  static Variable<Object> variable(Object? a) => switch (a) {
    null => const Variable(null),
    final String s => Variable.withString(s),
    final int i => Variable.withInt(i),
    final double d => Variable.withReal(d),
    _ => throw ArgumentError.value(a, 'a', 'unsupported variable'),
  };

  Future<void> run(String sql, [List<Object?> args = const []]) =>
      db.customStatement(sql, args);

  Future<List<Map<String, Object?>>> select(
    String sql, [
    List<Object?> args = const [],
  ]) async => [
    for (final r
        in await db
            .customSelect(sql, variables: [for (final a in args) variable(a)])
            .get())
      r.data,
  ];

  Future<int> single(String sql, [List<Object?> args = const []]) async =>
      (await select(sql, args)).single.values.first! as int;

  Future<int> count(String table) =>
      single('SELECT count(*) AS c FROM ${quote(table)}');

  Future<bool> entityExists(String type, String name) async => (await select(
    'SELECT 1 FROM sqlite_master WHERE type = ? AND name = ?',
    [type, name],
  )).isNotEmpty;

  Future<bool> tableExists(String name) => entityExists('table', name);

  Future<bool> columnExists(String table, String column) async =>
      (await select('PRAGMA table_info(${quote(table)})'))
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
      for (final r in await select('PRAGMA table_info(${quote(table)})'))
        if ((r['pk']! as int) > 0) r,
    ]..sort((a, b) => (a['pk']! as int).compareTo(b['pk']! as int));
    return cols.isEmpty
        ? ['rowid']
        : [for (final c in cols) c['name']! as String];
  }

  /// Every record key of [table], sorted.
  Future<List<String>> primaryKeys(String table) async {
    final pk = await primaryKeyColumns(table);
    final cols = pk.map(quote).join(', ');
    return [
      for (final r in await select(
        'SELECT $cols FROM ${quote(table)} ORDER BY $cols',
      ))
        keyOf(pk, r),
    ];
  }

  /// The record id of [row]: the single key value as text, or the JSON array
  /// of a composite key.
  static String keyOf(List<String> pk, Map<String, Object?> row) =>
      pk.length == 1
      ? '${row[pk.single]}'
      : jsonEncode([for (final c in pk) row[c]]);

  /// Inserts [rows] (each the values of [columns], in that order) into
  /// [table], in order, with as many rows per statement as
  /// [maxSqlVariables] allows. SQLite inserts the rows of one `VALUES` list
  /// in list order, so rowids and autoincrement ids are exactly those of
  /// one statement per row.
  /// [schema] qualifies the table (`temp`). More than [maxSqlVariables]
  /// columns cannot fit one row in a statement and are refused (Review C
  /// re-check N-4).
  Future<void> insertAll(
    String table,
    List<String> columns,
    Iterable<List<Object?>> rows, {
    String? schema,
  }) async {
    if (columns.isEmpty || columns.length > maxSqlVariables) {
      throw ArgumentError.value(
        columns.length,
        'columns',
        'must be 1 to $maxSqlVariables columns',
      );
    }
    final perStatement = maxSqlVariables ~/ columns.length;
    final target = schema == null
        ? quote(table)
        : '${quote(schema)}.${quote(table)}';
    final head =
        'INSERT INTO $target (${columns.map(quote).join(', ')}) '
        'VALUES ';
    final tuple = '(${List.filled(columns.length, '?').join(', ')})';
    var args = <Object?>[];
    var n = 0;
    Future<void> flush() async {
      if (n == 0) return;
      await run('$head${List.filled(n, tuple).join(', ')}', args);
      args = <Object?>[];
      n = 0;
    }

    for (final r in rows) {
      if (r.length != columns.length) {
        throw ArgumentError.value(
          r,
          'rows',
          'expected ${columns.length} values',
        );
      }
      args.addAll(r);
      if (++n == perStatement) await flush();
    }
    await flush();
  }

  /// Inserts [rows] (column → value) into [table] in order: consecutive rows
  /// with the same columns share multi-row statements ([insertAll]).
  Future<void> insertMaps(
    String table,
    Iterable<Map<String, Object?>> rows,
  ) async {
    var columns = const <String>[];
    var group = <List<Object?>>[];
    for (final r in rows) {
      final keys = r.keys.toList();
      if (group.isEmpty || !_sameList(columns, keys)) {
        if (group.isNotEmpty) await insertAll(table, columns, group);
        columns = keys;
        group = <List<Object?>>[];
      }
      group.add([for (final c in keys) r[c]]);
    }
    if (group.isNotEmpty) await insertAll(table, columns, group);
  }

  static bool _sameList(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Every `PRAGMA foreign_key_check` violation in [tables], with the
  /// violating row's record key ([keyOf]), the child columns of the
  /// violated key, and the row's [primaryKeyColumns], key columns and
  /// `exercise_id` (when the table has one) for the caller's report.
  Future<List<ForeignKeyViolation>> foreignKeyViolations(
    Iterable<String> tables,
  ) async {
    final out = <ForeignKeyViolation>[];
    for (final table in tables) {
      final fks = await select('PRAGMA foreign_key_list(${quote(table)})');
      if (fks.isEmpty) continue;
      final violations = await select(
        'PRAGMA foreign_key_check(${quote(table)})',
      );
      if (violations.isEmpty) continue;
      final pk = await primaryKeyColumns(table);
      final hasExercise = await columnExists(table, 'exercise_id');
      for (final v in violations) {
        final fkid = v['fkid'];
        final columns = [
          for (final f in fks)
            if (f['id'] == fkid) f['from']! as String,
        ];
        final selected = [
          ...pk,
          ...columns,
          if (hasExercise) 'exercise_id',
        ].map(quote).join(', ');
        final row = (await select(
          'SELECT $selected FROM ${quote(table)} WHERE rowid = ?',
          [v['rowid']],
        )).single;
        out.add(
          ForeignKeyViolation(
            table: table,
            recordId: keyOf(pk, row),
            columns: columns,
            parent: v['parent']! as String,
            row: row,
            hasExercise: hasExercise,
          ),
        );
      }
    }
    return out;
  }
}

/// One `PRAGMA foreign_key_check` violation ([V8Sql.foreignKeyViolations]).
final class ForeignKeyViolation {
  ForeignKeyViolation({
    required this.table,
    required this.recordId,
    required this.columns,
    required this.parent,
    required this.row,
    required this.hasExercise,
  });

  final String table;

  /// The violating row's record key ([V8Sql.keyOf]).
  final String recordId;

  /// The child columns of the violated key.
  final List<String> columns;
  final String parent;

  /// The row's key columns, [columns] and `exercise_id` (when
  /// [hasExercise]).
  final Map<String, Object?> row;
  final bool hasExercise;

  /// The value of the violated key: the single column's value, else the JSON
  /// array of the values.
  Object? get value => columns.length == 1
      ? row[columns.single]
      : jsonEncode([for (final c in columns) row[c]]);

  /// [findingKey] of this violation under [rule].
  String key(String rule) => findingKey(
    table: table,
    recordId: recordId,
    column: columns.join(','),
    parent: parent,
    rule: rule,
  );
}

/// The key of one integrity finding (a foreign-key violation or an
/// unresolved exercise reference): table, record, column, parent and rule.
/// The migration and the restore compare a baseline with the state after
/// their writes by these keys (safeguard A).
String findingKey({
  required String table,
  required String recordId,
  required String column,
  required String parent,
  required String rule,
}) => jsonEncode([table, recordId, column, parent, rule]);
