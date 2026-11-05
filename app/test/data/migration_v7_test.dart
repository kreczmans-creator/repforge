import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v6.dart' as v6;
import 'generated_migrations/schema_v7.dart' as v7;

const _t = '2026-11-01T08:00:00.000Z';

/// Schema v6 -> v7 (WP 9): set kind, session exercise entries, scheduled
/// workouts. Additive only; no existing value changes.
void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  Future<void> session(v6.DatabaseAtV6 db, String id, {String? deleted}) =>
      db.customStatement(
        'INSERT INTO workout_sessions (id, created_at, updated_at, '
        'deleted_at, name, started_at, notes) '
        "VALUES (?, '$_t', '$_t', ?, 'Push', '$_t', 'kept note')",
        [id, deleted],
      );

  Future<void> set(
    v6.DatabaseAtV6 db,
    String id,
    String session,
    String exercise,
    int exerciseOrder,
    int setOrder,
  ) => db.customStatement(
    'INSERT INTO session_sets (id, session_id, exercise_id, exercise_order, '
    'set_order, type, load_kg, reps, completed, exertion_scale, '
    'exertion_value, note) '
    "VALUES (?, ?, ?, ?, ?, 'weighted', 80, 5, 1, 'rpe', 8.5, 'n')",
    [id, session, exercise, exerciseOrder, setOrder],
  );

  Future<void> insertV6(v6.DatabaseAtV6 db) async {
    await session(db, 's1');
    await session(db, 's2', deleted: _t);
    // s1: bench (order 0, two sets), squat (order 1), and a legacy oddity:
    // row at order 1 for another exercise (two exercises sharing an order).
    await set(db, 'a', 's1', 'bench', 0, 0);
    await set(db, 'b', 's1', 'bench', 0, 1);
    await set(db, 'c', 's1', 'squat', 1, 0);
    await set(db, 'd', 's1', 'row', 1, 1);
    // s2 (soft-deleted) is migrated too.
    await set(db, 'e', 's2', 'bench', 3, 0);
    await db.customStatement(
      'INSERT INTO workout_plans (id, created_at, updated_at, name, '
      "scheduled_weekdays_json, archived) VALUES ('p1', '$_t', '$_t', "
      "'Push A', '[1,3]', 0)",
    );
  }

  Future<List<Map<String, Object?>>> rows(AppDatabase db, String sql) async => [
    for (final r in await db.customSelect(sql).get()) r.data,
  ];

  test('v6 upgrade to v7 gives every set an entry and the kind working, '
      'changing no existing value', () async {
    final schema = await verifier.schemaAt(6);
    final old = v6.DatabaseAtV6(schema.newConnection());
    await insertV6(old);
    final before = await old
        .customSelect(
          'SELECT id, session_id, exercise_id, exercise_order, set_order, '
          'type, load_kg, reps, completed, exertion_scale, exertion_value, '
          'note '
          'FROM session_sets ORDER BY id',
        )
        .get();
    await old.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 7);

    final after = await db
        .customSelect(
          'SELECT id, session_id, exercise_id, exercise_order, set_order, '
          'type, load_kg, reps, completed, exertion_scale, exertion_value, '
          'note '
          'FROM session_sets ORDER BY id',
        )
        .get();
    expect(
      [for (final r in after) r.data],
      [for (final r in before) r.data],
      reason: 'no existing set value is changed (exercise_order included)',
    );
    expect(await rows(db, 'SELECT DISTINCT set_kind FROM session_sets'), [
      {'set_kind': 'working'},
    ]);
    expect(
      await rows(
        db,
        'SELECT session_id, position, exercise_id FROM session_exercises '
        'ORDER BY session_id, position',
      ),
      [
        // exercise_order 0, then the two exercises that shared order 1 in
        // their first-row order, each with its own position.
        {'session_id': 's1', 'position': 0, 'exercise_id': 'bench'},
        {'session_id': 's1', 'position': 1, 'exercise_id': 'squat'},
        {'session_id': 's1', 'position': 2, 'exercise_id': 'row'},
        {'session_id': 's2', 'position': 0, 'exercise_id': 'bench'},
      ],
    );
    expect(
      await rows(
        db,
        'SELECT s.id AS id, e.position AS position FROM session_sets s '
        'JOIN session_exercises e ON e.id = s.session_exercise_id '
        'ORDER BY s.id',
      ),
      [
        {'id': 'a', 'position': 0},
        {'id': 'b', 'position': 0},
        {'id': 'c', 'position': 1},
        {'id': 'd', 'position': 2},
        {'id': 'e', 'position': 0},
      ],
      reason: 'every set is linked to an entry',
    );
    expect(await rows(db, 'SELECT * FROM scheduled_workouts'), isEmpty);
    // Sessions and plans keep their rows, including the soft-deleted one.
    expect(
      await rows(
        db,
        'SELECT id, notes, deleted_at FROM workout_sessions '
        'ORDER BY id',
      ),
      [
        {'id': 's1', 'notes': 'kept note', 'deleted_at': null},
        {'id': 's2', 'notes': 'kept note', 'deleted_at': _t},
      ],
    );
    expect(await rows(db, 'SELECT id FROM workout_plans'), hasLength(1));
  });

  test('the v7 tables enforce their CHECK constraints', () async {
    final schema = await verifier.schemaAt(6);
    final old = v6.DatabaseAtV6(schema.newConnection());
    await insertV6(old);
    await old.close();
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 7);

    Future<void> setKind(String kind) => db.customStatement(
      'UPDATE session_sets SET set_kind = ? WHERE id = ?',
      [kind, 'a'],
    );
    await setKind('warmUp');
    await setKind('failure');
    await expectLater(setKind('dropSet'), throwsA(isA<Object>()));
    await expectLater(
      db.customStatement(
        'INSERT INTO scheduled_workouts (id, created_at, updated_at, day, '
        "source_day, plan_id, origin, status) VALUES ('w', '$_t', '$_t', "
        "'2026-11-02', '2026-11-02', 'p1', 'whim', 'planned')",
      ),
      throwsA(isA<Object>()),
    );
    await expectLater(
      db.customStatement(
        'INSERT INTO session_exercises (id, session_id, position, '
        "exercise_id, note) VALUES ('x', 's1', -1, 'bench', NULL)",
      ),
      throwsA(isA<Object>()),
    );
    await expectLater(
      db.customStatement(
        'INSERT INTO session_exercises (id, session_id, position, '
        "exercise_id, note) VALUES ('y', 's1', 9, 'bench', ?)",
        ['x' * 4001],
      ),
      throwsA(isA<Object>()),
    );
    await db.customStatement(
      'INSERT INTO session_exercises (id, session_id, position, '
      "exercise_id, note) VALUES ('z', 's1', 9, 'bench', ?)",
      ['x' * 4000],
    );
  });

  test('v6 upgrade can run again after a crash before user_version is '
      'recorded, keeping v7-only data and not duplicating entries', () async {
    final schema = await verifier.schemaAt(6);
    final old = v6.DatabaseAtV6(schema.newConnection());
    await insertV6(old);
    await old.close();

    final first = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(first, 7);
    // v7-only data written after the migration, then the crash window: the
    // migrated schema is on disk but user_version still says 6.
    await first.customStatement(
      "UPDATE session_exercises SET note = 'exercise note' WHERE id = "
      "'legacy:s1:0'",
    );
    await first.customStatement(
      "UPDATE session_sets SET set_kind = 'warmUp' WHERE id = 'a'",
    );
    await first.customStatement(
      'INSERT INTO scheduled_workouts (id, created_at, updated_at, day, '
      "source_day, plan_id, origin, status) VALUES ('w', '$_t', '$_t', "
      "'2026-11-02', '2026-11-02', 'p1', 'weekday', 'planned')",
    );
    await first.customStatement('PRAGMA user_version = 6');
    await first.close();

    final second = AppDatabase(schema.newConnection());
    addTearDown(second.close);
    await verifier.migrateAndValidate(second, 7);
    expect(
      await rows(second, 'SELECT id FROM session_exercises'),
      hasLength(4),
    );
    expect(
      await rows(
        second,
        "SELECT note FROM session_exercises WHERE id = 'legacy:s1:0'",
      ),
      [
        {'note': 'exercise note'},
      ],
    );
    expect(
      await rows(second, "SELECT set_kind FROM session_sets WHERE id = 'a'"),
      [
        {'set_kind': 'warmUp'},
      ],
    );
    expect(
      await rows(second, 'SELECT id FROM scheduled_workouts'),
      hasLength(1),
    );
    final version = await second
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, 7);
  });

  test('a v7 schema snapshot has the new tables and columns', () async {
    final schema = await verifier.schemaAt(7);
    final db = v7.DatabaseAtV7(schema.newConnection());
    addTearDown(db.close);
    expect(
      (await db
              .customSelect(
                'SELECT name FROM sqlite_master '
                "WHERE type = 'table' AND name IN "
                "('session_exercises', 'scheduled_workouts')",
              )
              .get())
          .length,
      2,
    );
  });
}
