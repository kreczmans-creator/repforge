import 'dart:convert';

import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v5.dart' as v5;
import 'generated_migrations/schema_v7.dart' as v7;

const _t = '2026-11-01T08:00:00.000Z';

/// Schema v5 -> v6 (WP 8): exercises, plan exercises, session sets, splits and
/// the CHECK constraints of TD-25.
void main() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  Future<void> exercise(
    v5.DatabaseAtV5 db,
    String id, {
    required String name,
    required int isCustom,
    String category = 'Push',
    String primary = 'front delts',
    String secondary = '["Triceps","front delts"]',
    String equipment = '["Barbell","bench"]',
  }) => db.customStatement(
    'INSERT INTO exercises (id, created_at, updated_at, name, type, '
    'category, primary_muscle, secondary_muscles_json, equipment_json, '
    'is_custom, archived) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 0)',
    [
      id,
      _t,
      _t,
      name,
      'weighted',
      category,
      primary,
      secondary,
      equipment,
      isCustom,
    ],
  );

  Future<void> set(
    v5.DatabaseAtV5 db,
    String id,
    int order,
    String type, {
    double? load,
    int? reps,
    double? assistance,
    int? duration,
    double? metres,
    int? hr,
    double? exertion,
  }) => db.customStatement(
    'INSERT INTO session_sets (id, session_id, exercise_id, exercise_order, '
    'set_order, type, load_kg, reps, assistance_kg, duration_sec, metres, '
    'average_heart_rate, completed, exertion_scale, exertion_value) '
    "VALUES (?, 's1', ?, 0, ?, ?, ?, ?, ?, ?, ?, ?, 1, ?, ?)",
    [
      id,
      'ex-$type',
      order,
      type,
      load,
      reps,
      assistance,
      duration,
      metres,
      hr,
      if (exertion == null) null else 'rpe',
      exertion,
    ],
  );

  Future<void> insertV5Training(v5.DatabaseAtV5 db) async {
    await exercise(db, 'e-lib', name: 'Écarté', isCustom: 0);
    await exercise(
      db,
      'e-mine',
      name: 'My Press',
      isCustom: 1,
      category: 'weird',
      primary: 'chest',
      secondary: '[]',
      equipment: '[]',
    );
    await db.customStatement(
      'INSERT INTO workout_plans (id, created_at, updated_at, name, '
      "scheduled_weekdays_json, archived) VALUES ('p1', '$_t', '$_t', "
      "'Push A', '[1,3]', 0)",
    );
    await db.customStatement(
      'INSERT INTO plan_exercises (id, plan_id, exercise_id, sort_order, '
      'target_sets, target_reps, target_load_kg, target_duration_sec, '
      "rest_seconds) VALUES ('pe1', 'p1', 'e-lib', 0, 3, 8, 62.5, 45, 90)",
    );
    await db.customStatement(
      'INSERT INTO workout_sessions (id, created_at, updated_at, name, '
      "started_at, notes) VALUES ('s1', '$_t', '$_t', 'Push', '$_t', '')",
    );
    await set(db, 'w', 0, 'weighted', load: 80, reps: 5, exertion: 8);
    await set(db, 'b', 1, 'bodyweight', load: 10, reps: 8);
    await set(db, 'a', 2, 'assisted', assistance: 20, reps: 6);
    await set(db, 't', 3, 'timed', duration: 90, load: 5);
    await set(db, 'd', 4, 'distance', metres: 400, duration: 80);
    await set(db, 'c', 5, 'cardio', duration: 1800, hr: 140);
  }

  test('v5 upgrade to v6 keeps exercises, plan exercises and a set of every '
      'type; supplied = NOT is_custom; target_reps fills the range', () async {
    final schema = await verifier.schemaAt(5);
    final old = v5.DatabaseAtV5(schema.newConnection());
    await insertV5Training(old);
    await old.close();
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 7);

    final migrated = v7.DatabaseAtV7(schema.newConnection());
    addTearDown(migrated.close);

    final exercises = {
      for (final e in await migrated.select(migrated.exercises).get()) e.id: e,
    };
    expect(exercises.keys, unorderedEquals(['e-lib', 'e-mine']));
    final lib = exercises['e-lib']!;
    expect(lib.supplied, 1, reason: 'is_custom = 0 means supplied');
    expect(exercises['e-mine']!.supplied, 0);
    expect(lib.aliasesJson, '[]');
    expect(lib.copiedFromId, isNull);
    // Free text that names a taxonomy identifier is rewritten, case and
    // spaces ignored; anything else is kept as it was.
    expect(lib.category, 'push');
    expect(lib.primaryMuscle, 'frontDelts');
    expect(jsonDecode(lib.secondaryMusclesJson), ['triceps', 'frontDelts']);
    expect(jsonDecode(lib.equipmentJson), ['barbell', 'bench']);
    // An unrecognised required value is never invented: the row is kept as
    // it is (unreadable by the mapper) and a quarantine entry records it.
    expect(exercises['e-mine']!.category, 'weird');
    expect(exercises['e-mine']!.primaryMuscle, 'chest');
    // Search key: normalised name (diacritics folded) and aliases.
    expect(lib.searchKey, 'ecarte');
    expect(exercises['e-mine']!.searchKey, 'my press');

    final pe = (await migrated.select(migrated.planExercises).get()).single;
    expect(pe.planId, 'p1', reason: 'the plan row was not cascade-deleted');
    expect(
      [
        pe.targetSets,
        pe.repsMin,
        pe.repsMax,
        pe.targetLoadKg,
        pe.targetDurationSec,
        pe.targetMetres,
        pe.restSeconds,
      ],
      [3, 8, 8, 62.5, 45, null, 90],
    );
    expect(await migrated.select(migrated.workoutPlans).get(), hasLength(1));

    final sets = {
      for (final s in await migrated.select(migrated.sessionSets).get())
        s.id: s,
    };
    expect(sets.keys, unorderedEquals(['w', 'b', 'a', 't', 'd', 'c']));
    expect(
      [sets['w']!.loadKg, sets['w']!.reps, sets['w']!.exertionValue],
      [80, 5, 8],
    );
    expect([sets['b']!.loadKg, sets['b']!.reps], [10, 8]);
    expect([sets['a']!.assistanceKg, sets['a']!.reps], [20, 6]);
    expect([sets['t']!.durationSec, sets['t']!.loadKg], [90, 5]);
    expect([sets['d']!.metres, sets['d']!.durationSec], [400, 80]);
    expect([sets['c']!.durationSec, sets['c']!.averageHeartRate], [1800, 140]);
    for (final s in sets.values) {
      expect(s.energyKcal, isNull);
      expect(s.energyProvenance, isNull);
    }
    final quarantined = await migrated.select(migrated.legacyQuarantine).get();
    expect(quarantined, hasLength(1), reason: 'only the weird category');
    expect(
      [quarantined.single.sourceTable, quarantined.single.rowId],
      ['exercises', 'e-mine'],
    );
    expect(quarantined.single.reason, contains('category "weird"'));
    expect(
      (jsonDecode(quarantined.single.originalJson) as Map)['category'],
      'weird',
    );
    expect(await migrated.select(migrated.trainingSplits).get(), isEmpty);
    expect(await migrated.select(migrated.splitDays).get(), isEmpty);
  });

  test('the migrated tables enforce the CHECK constraints (TD-25)', () async {
    final schema = await verifier.schemaAt(5);
    final old = v5.DatabaseAtV5(schema.newConnection());
    await insertV5Training(old);
    await old.close();
    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 7);
    final migrated = v7.DatabaseAtV7(schema.newConnection());
    addTearDown(migrated.close);

    Future<void> setSql(
      String column,
      Object? value,
    ) => migrated.customStatement(
      'INSERT INTO session_sets (id, session_id, exercise_id, exercise_order, '
      "set_order, type, $column) VALUES ('x${column}_$value', 's1', 'e', 9, 9, "
      "'weighted', ?)",
      [value],
    );
    Future<void> planSql(String columns, List<Object?> values) =>
        migrated.customStatement(
          'INSERT INTO plan_exercises (id, plan_id, exercise_id, sort_order, '
          "$columns) VALUES ('px${values.join()}', 'p1', 'e', 5, "
          '${List.filled(values.length, '?').join(', ')})',
          values,
        );

    for (final (column, bad) in <(String, Object)>[
      ('reps', 0),
      ('reps', 101),
      ('load_kg', -1),
      ('load_kg', 1001),
      ('assistance_kg', -0.25),
      ('duration_sec', 0),
      ('metres', 0),
      ('average_heart_rate', 300),
      ('average_heart_rate', 29),
      ('energy_kcal', -5),
      ('energy_provenance', 'verified'),
      ('exertion_value', 11),
      ('rest_seconds', 3601),
    ]) {
      await expectLater(
        setSql(column, bad),
        throwsA(anything),
        reason: '$column=$bad',
      );
    }
    // Energy and its label travel together.
    await expectLater(setSql('energy_kcal', 200), throwsA(anything));
    await setSql('reps', 100); // the upper bound is allowed

    await expectLater(planSql('target_sets', [0]), throwsA(anything));
    await expectLater(planSql('target_sets', [21]), throwsA(anything));
    await expectLater(
      planSql('target_sets, reps_min, reps_max', [3, 10, 8]),
      throwsA(anything),
      reason: 'min above max',
    );
    await expectLater(
      planSql('target_sets, reps_min', [3, 8]),
      throwsA(anything),
      reason: 'range needs both ends',
    );
    await expectLater(
      planSql('target_sets, target_metres', [3, 0]),
      throwsA(anything),
    );
    await expectLater(
      planSql('target_sets, rest_seconds', [3, -1]),
      throwsA(anything),
    );
    await planSql('target_sets, reps_min, reps_max', [3, 8, 10]);

    Future<void> splitSql(int days) => migrated.customStatement(
      'INSERT INTO training_splits (id, created_at, updated_at, name, '
      "cycle_days) VALUES ('sp$days', '$_t', '$_t', 'S', ?)",
      [days],
    );
    await expectLater(splitSql(0), throwsA(anything));
    await expectLater(splitSql(15), throwsA(anything));
    await splitSql(14);
    await migrated.customStatement(
      'INSERT INTO split_days (id, split_id, day_index) '
      "VALUES ('d0', 'sp14', 0)",
    );
    await expectLater(
      migrated.customStatement(
        'INSERT INTO split_days (id, split_id, day_index) '
        "VALUES ('d0b', 'sp14', 0)",
      ),
      throwsA(anything),
      reason: 'one entry per cycle day',
    );
    // Deleting the split cascades to its days (foreign keys are on).
    await migrated.customStatement('PRAGMA foreign_keys = ON');
    await migrated.customStatement(
      "DELETE FROM training_splits WHERE id = 'sp14'",
    );
    expect(await migrated.select(migrated.splitDays).get(), isEmpty);
  });

  test('rows that violate the new CHECKs are not clamped: nullable values '
      'become NULL, an unrepresentable row moves out, and the original is '
      'kept in legacy_quarantine', () async {
    final schema = await verifier.schemaAt(5);
    final old = v5.DatabaseAtV5(schema.newConnection());
    await insertV5Training(old);
    // v5 had no constraints, so these could exist.
    await set(old, 'bad-reps', 6, 'weighted', load: 50, reps: 0);
    await set(old, 'bad-hr', 7, 'cardio', duration: 600, hr: 300, metres: 0);
    await old.customStatement(
      'INSERT INTO plan_exercises (id, plan_id, exercise_id, sort_order, '
      'target_sets, target_reps, rest_seconds) '
      "VALUES ('bad-reps-pe', 'p1', 'e-lib', 1, 3, 150, 90), "
      "('bad-sets-pe', 'p1', 'e-lib', 2, 0, 8, 60)",
    );
    await old.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 7);
    final migrated = v7.DatabaseAtV7(schema.newConnection());
    addTearDown(migrated.close);

    // Every row survives, except the plan exercise with 0 sets.
    final sets = {
      for (final s in await migrated.select(migrated.sessionSets).get())
        s.id: s,
    };
    expect(sets, hasLength(8));
    expect(sets['bad-reps']!.reps, isNull);
    expect(sets['bad-reps']!.loadKg, 50, reason: 'valid columns are kept');
    expect(sets['bad-hr']!.averageHeartRate, isNull);
    expect(sets['bad-hr']!.metres, isNull);
    expect(sets['bad-hr']!.durationSec, 600);
    expect(sets['w']!.reps, 5, reason: 'valid rows are untouched');

    final plans = {
      for (final p in await migrated.select(migrated.planExercises).get())
        p.id: p,
    };
    expect(plans.keys, unorderedEquals(['pe1', 'bad-reps-pe']));
    expect(
      [plans['bad-reps-pe']!.repsMin, plans['bad-reps-pe']!.repsMax],
      [null, null],
    );
    expect(plans['bad-reps-pe']!.restSeconds, 90);

    final q = {
      for (final r in await migrated.select(migrated.legacyQuarantine).get())
        r.rowId: r,
    };
    expect(
      q.keys,
      unorderedEquals([
        'bad-reps',
        'bad-hr',
        'bad-reps-pe',
        'bad-sets-pe',
        'e-mine',
      ]),
    );
    final original = jsonDecode(q['bad-reps']!.originalJson) as Map;
    expect([original['reps'], original['load_kg']], [0, 50]);
    expect(q['bad-reps']!.sourceTable, 'session_sets');
    expect(q['bad-reps']!.reason, contains('reps'));
    final lost = jsonDecode(q['bad-sets-pe']!.originalJson) as Map;
    expect([lost['target_sets'], lost['target_reps']], [0, 8]);
    expect(q['bad-sets-pe']!.sourceTable, 'plan_exercises');
    expect(
      (jsonDecode(q['bad-hr']!.originalJson) as Map)['average_heart_rate'],
      300,
    );
  });

  test('v5 upgrade can run again after a crash before user_version is '
      'recorded, keeping v6-only data and not quarantining twice', () async {
    final schema = await verifier.schemaAt(5);
    final old = v5.DatabaseAtV5(schema.newConnection());
    await insertV5Training(old);
    await set(old, 'bad-reps', 6, 'weighted', load: 50, reps: 0);
    await old.close();

    final first = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(first, 7);
    // Data that only exists in v6, so a re-run would show lost columns.
    await first.customStatement(
      "UPDATE exercises SET aliases_json = '[\"Flye\"]', "
      "copied_from_id = 'e-lib' WHERE id = 'e-mine'",
    );
    await first.customStatement(
      'UPDATE plan_exercises SET reps_max = 10, target_metres = 250.5 '
      "WHERE id = 'pe1'",
    );
    await first.customStatement(
      'UPDATE session_sets SET energy_kcal = 210, '
      "energy_provenance = 'estimated' WHERE id = 'c'",
    );
    await first.customStatement(
      'INSERT INTO training_splits (id, created_at, updated_at, name, '
      "cycle_days) VALUES ('sp', '$_t', '$_t', 'U/L', 2)",
    );
    await first.customStatement('PRAGMA user_version = 5');
    await first.close();

    final second = AppDatabase(schema.newConnection());
    addTearDown(second.close);
    final mine = await (second.select(
      second.exercises,
    )..where((e) => e.id.equals('e-mine'))).getSingle();
    expect([mine.aliasesJson, mine.copiedFromId], ['["Flye"]', 'e-lib']);
    final pe = await (second.select(
      second.planExercises,
    )..where((p) => p.id.equals('pe1'))).getSingle();
    expect([pe.repsMin, pe.repsMax, pe.targetMetres], [8, 10, 250.5]);
    final c = await (second.select(
      second.sessionSets,
    )..where((s) => s.id.equals('c'))).getSingle();
    expect([c.energyKcal, c.energyProvenance], [210, 'estimated']);
    expect(await second.select(second.trainingSplits).get(), hasLength(1));
    expect(
      await second.select(second.legacyQuarantine).get(),
      hasLength(2),
      reason: 'bad-reps and the weird category, once each',
    );
    final version = await second
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, 7);
  });

  test(
    'free-text taxonomy values migrate by identifier, label or synonym; '
    'unmatched optional values are dropped with a quarantine record; '
    'unmatched required values are quarantined and the row is kept (M4)',
    () async {
      final schema = await verifier.schemaAt(5);
      final old = v5.DatabaseAtV5(schema.newConnection());
      await exercise(
        old,
        'by-label',
        name: 'DB Press',
        isCustom: 1,
        category: 'Full body',
        primary: 'Quads',
        secondary: '["Hams","Lats"]',
        equipment: '["Dumbbells","Cable station","Bodyweight"]',
      );
      await exercise(
        old,
        'drops-optional',
        name: 'Odd Row',
        isCustom: 1,
        category: 'pull',
        primary: 'lats',
        secondary: '["Tentacles","biceps"]',
        equipment: '["Flux capacitor","barbell"]',
      );
      await exercise(
        old,
        'bad-required',
        name: 'Mystery',
        isCustom: 1,
        category: 'Hybrid',
        primary: 'Delts',
        secondary: '[]',
        equipment: '[]',
      );
      await old.close();
      final db = AppDatabase(schema.newConnection());
      addTearDown(db.close);
      await verifier.migrateAndValidate(db, 7);
      final migrated = v7.DatabaseAtV7(schema.newConnection());
      addTearDown(migrated.close);

      final rows = {
        for (final e in await migrated.select(migrated.exercises).get())
          e.id: e,
      };
      final label = rows['by-label']!;
      expect(label.category, 'fullBody');
      expect(label.primaryMuscle, 'quadriceps');
      expect(jsonDecode(label.secondaryMusclesJson), ['hamstrings', 'lats']);
      expect(jsonDecode(label.equipmentJson), ['dumbbell', 'cable']);

      final drops = rows['drops-optional']!;
      expect(jsonDecode(drops.secondaryMusclesJson), ['biceps']);
      expect(jsonDecode(drops.equipmentJson), ['barbell']);

      final bad = rows['bad-required']!;
      expect([bad.category, bad.primaryMuscle], ['Hybrid', 'Delts']);

      final q = {
        for (final r in await migrated.select(migrated.legacyQuarantine).get())
          r.rowId: r,
      };
      expect(q.keys, unorderedEquals(['drops-optional', 'bad-required']));
      expect(q['drops-optional']!.reason, contains('Tentacles'));
      expect(q['drops-optional']!.reason, contains('Flux capacitor'));
      expect(
        (jsonDecode(q['drops-optional']!.originalJson)
            as Map)['equipment_json'],
        '["Flux capacitor","barbell"]',
        reason: 'the original row is kept as it was',
      );
      expect(q['bad-required']!.reason, contains('category "Hybrid"'));
      expect(q['bad-required']!.reason, contains('primary_muscle "Delts"'));
      expect(q.containsKey('by-label'), isFalse);
    },
  );
}
