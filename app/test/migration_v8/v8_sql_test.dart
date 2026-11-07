import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/migration/v8_sql.dart';
import 'package:repforge/data/db/v8/app_database_v8.dart';

/// WP 8 3b-10, Review C M-2, L-3, L-5: the shared SQL helpers. Multi-row
/// inserts give exactly the rows, rowids and autoincrement ids of one
/// statement per row; quoted identifiers escape `"`; foreign-key findings
/// work on any table name.
void main() {
  late AppDatabaseV8 db;
  late V8Sql io;

  setUp(() async {
    db = AppDatabaseV8(NativeDatabase.memory());
    io = V8Sql(db);
    await db.customStatement(
      'CREATE TABLE "we""ird" (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'a TEXT, b REAL, c INTEGER)',
    );
    await db.customStatement(
      'CREATE TABLE "one by one" (id INTEGER PRIMARY KEY AUTOINCREMENT, '
      'a TEXT, b REAL, c INTEGER)',
    );
  });
  tearDown(() => db.close());

  Future<List<Map<String, Object?>>> dump(String table) => io.select(
    'SELECT rowid AS r, * FROM ${V8Sql.quote(table)} ORDER BY rowid',
  );

  test('quote doubles "', () {
    expect(V8Sql.quote('a'), '"a"');
    expect(V8Sql.quote('we"ird'), '"we""ird"');
  });

  test('insertAll in several statements gives the rows, rowids and '
      'AUTOINCREMENT ids of one statement per row', () async {
    // 3 columns: 333 rows per statement; 1,000 rows need four.
    final rows = [
      for (var i = 0; i < 1000; i++)
        [if (i.isEven) 'text $i' else null, i / 4, if (i.isOdd) i else null],
    ];
    await io.insertAll('we"ird', const ['a', 'b', 'c'], rows);
    for (final r in rows) {
      await io.run('INSERT INTO "one by one" (a, b, c) VALUES (?, ?, ?)', r);
    }
    expect(await dump('we"ird'), await dump('one by one'));
    expect(await io.count('we"ird'), 1000);
    expect(
      await io.single("SELECT seq FROM sqlite_sequence WHERE name = 'we\"ird'"),
      1000,
    );
  });

  test(
    'insertMaps keeps the order across rows with different columns',
    () async {
      final rows = [
        {'a': 'x', 'b': 1.5},
        {'a': 'y', 'b': 2.5},
        {'id': 50, 'a': 'z', 'b': 0.0},
        {'a': 'after', 'b': 3.0},
        {'c': 7},
      ];
      await io.insertMaps('we"ird', rows);
      for (final r in rows) {
        final cols = r.keys.toList();
        await io.run(
          'INSERT INTO "one by one" (${cols.map(V8Sql.quote).join(', ')}) '
          'VALUES (${List.filled(cols.length, '?').join(', ')})',
          [for (final c in cols) r[c]],
        );
      }
      expect(await dump('we"ird'), await dump('one by one'));
      expect(
        [for (final r in await dump('we"ird')) r['id']],
        [1, 2, 50, 51, 52],
      );
      await io.insertMaps('we"ird', const []);
      expect(await io.count('we"ird'), 5);
    },
  );

  test('insertAll refuses no columns and more columns than a statement '
      'takes, before any write', () async {
    await expectLater(
      io.insertAll('we"ird', const [], [const <Object?>[]]),
      throwsArgumentError,
    );
    final wide = [for (var i = 0; i <= V8Sql.maxSqlVariables; i++) 'c$i'];
    await expectLater(
      io.insertAll('we"ird', wide, [List<Object?>.filled(wide.length, 1)]),
      throwsArgumentError,
    );
    expect(await io.count('we"ird'), 0);
  });

  test('a row with the wrong number of values is refused before any '
      'write', () async {
    await expectLater(
      io.insertAll(
        'we"ird',
        const ['a', 'b'],
        [
          ['x', 1.0],
          ['y'],
        ],
      ),
      throwsArgumentError,
    );
    expect(await io.count('we"ird'), 0);
  });

  test('foreign-key findings and table helpers on a table whose name holds '
      '"', () async {
    // Damage as a v7 device can hold it: written with the keys off.
    await db.customStatement('PRAGMA foreign_keys = OFF');
    await db.customStatement('CREATE TABLE "pa""rent" (id TEXT PRIMARY KEY)');
    await db.customStatement(
      'CREATE TABLE "ch""ild" (id TEXT PRIMARY KEY, exercise_id TEXT, '
      'parent_id TEXT REFERENCES "pa""rent" (id))',
    );
    await db.customStatement(
      'INSERT INTO "ch""ild" VALUES (\'c1\', \'ex-1\', \'missing\')',
    );
    expect(await io.columnExists('ch"ild', 'parent_id'), isTrue);
    expect(await io.primaryKeyColumns('ch"ild'), ['id']);
    expect(await io.primaryKeys('ch"ild'), ['c1']);
    final found = await io.foreignKeyViolations(['ch"ild', 'pa"rent']);
    expect(found, hasLength(1));
    final v = found.single;
    expect(v.table, 'ch"ild');
    expect(v.recordId, 'c1');
    expect(v.columns, ['parent_id']);
    expect(v.parent, 'pa"rent');
    expect(v.value, 'missing');
    expect(v.hasExercise, isTrue);
    expect(v.row['exercise_id'], 'ex-1');
    expect(
      v.key('foreign_key_check'),
      findingKey(
        table: 'ch"ild',
        recordId: 'c1',
        column: 'parent_id',
        parent: 'pa"rent',
        rule: 'foreign_key_check',
      ),
    );
  });
}
