import 'package:drift/drift.dart' hide isNull;
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;
import 'generated_migrations/schema_v3.dart' as v3;
import 'generated_migrations/schema_v4.dart' as v4;

/// Every schema version must migrate to the current one without loss. Add a
/// case here for each new version (R-07: data loss from an untested
/// migration is the project's top data-integrity risk).
void main() {
  _v2ToV3();
  _v3ToV4();
  late SchemaVerifier verifier;

  setUpAll(() {
    verifier = SchemaVerifier(GeneratedHelper());
  });

  test('v1 weight_entries rows become measurements (site = weight)', () async {
    final schema = await verifier.schemaAt(1);
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb
        .into(oldDb.weightEntries)
        .insert(
          v1.WeightEntriesCompanion.insert(
            id: 'w1',
            recordedAt: '2026-11-01T08:00:00.000Z',
            weightKg: 82.4,
            note: const Value('morning'),
            createdAt: '2026-11-01T08:00:00.000Z',
            updatedAt: '2026-11-01T08:00:00.000Z',
          ),
        );
    await oldDb
        .into(oldDb.weightEntries)
        .insert(
          v1.WeightEntriesCompanion.insert(
            id: 'w2',
            recordedAt: '2026-11-02T08:00:00.000Z',
            weightKg: 81.9,
            createdAt: '2026-11-02T08:00:00.000Z',
            updatedAt: '2026-11-02T08:00:00.000Z',
            deletedAt: const Value('2026-11-03T00:00:00.000Z'),
          ),
        );
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);

    final migrated = v4.DatabaseAtV4(schema.newConnection());
    addTearDown(migrated.close);
    final rows = await (migrated.select(
      migrated.measurements,
    )..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    expect(rows.map((r) => r.id), ['w1', 'w2']);
    expect(rows.first.site, 'weight');
    expect(rows.first.value, 82.4);
    expect(rows.first.note, 'morning');
    expect(rows.first.recordedAt, '2026-11-01T08:00:00.000Z');
    expect(rows.last.deletedAt, '2026-11-03T00:00:00.000Z');
    expect(
      await migrated
          .customSelect(
            'SELECT name FROM sqlite_master '
            "WHERE type='table' AND name='weight_entries'",
          )
          .get(),
      isEmpty,
    );
  });
}

void _v2ToV3() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  test('schema v2 upgrades to v4 keeping existing rows', () async {
    final schema = await verifier.schemaAt(2);
    final oldDb = v2.DatabaseAtV2(schema.newConnection());
    await oldDb
        .into(oldDb.measurements)
        .insert(
          v2.MeasurementsCompanion.insert(
            id: 'm1',
            site: 'weight',
            value: 80.5,
            recordedAt: '2026-11-01T08:00:00.000Z',
            createdAt: '2026-11-01T08:00:00.000Z',
            updatedAt: '2026-11-01T08:00:00.000Z',
          ),
        );
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);

    final migrated = v4.DatabaseAtV4(schema.newConnection());
    addTearDown(migrated.close);
    expect(
      (await migrated.select(migrated.measurements).get()).single.id,
      'm1',
    );
    expect(await migrated.select(migrated.savedMeals).get(), isEmpty);
  });

  test('schema v1 upgrades straight to v4', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);
  });

  test('v2 upgrade can run again after a crash before user_version is '
      'recorded', () async {
    final schema = await verifier.schemaAt(2);
    final first = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(first, 4);
    await first.customStatement('PRAGMA user_version = 2');
    await first.close();

    final second = AppDatabase(schema.newConnection());
    addTearDown(second.close);
    expect(await second.select(second.savedMeals).get(), isEmpty);
    final version = await second
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, 4);
  });

  test('v1 upgrade can run again after a crash before user_version is '
      'recorded', () async {
    // drift writes user_version after onUpgrade returns; a kill in that
    // window leaves the migrated schema with user_version still 1.
    final schema = await verifier.schemaAt(1);
    final oldDb = v1.DatabaseAtV1(schema.newConnection());
    await oldDb
        .into(oldDb.weightEntries)
        .insert(
          v1.WeightEntriesCompanion.insert(
            id: 'w1',
            recordedAt: '2026-11-01T08:00:00.000Z',
            weightKg: 82.4,
            createdAt: '2026-11-01T08:00:00.000Z',
            updatedAt: '2026-11-01T08:00:00.000Z',
          ),
        );
    await oldDb.close();

    final first = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(first, 4);
    await first.customStatement('PRAGMA user_version = 1');
    await first.close();

    final second = AppDatabase(schema.newConnection());
    addTearDown(second.close);
    final rows = await second.select(second.measurements).get();
    expect(rows.map((r) => r.id), ['w1']);
    expect(await second.select(second.savedMeals).get(), isEmpty);
    final version = await second
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, 4);
  });
}

void _v3ToV4() {
  late SchemaVerifier verifier;
  setUpAll(() => verifier = SchemaVerifier(GeneratedHelper()));

  const t = '2026-11-01T08:00:00.000Z';

  Future<void> insertV3Rows(v3.DatabaseAtV3 old) async {
    await old
        .into(old.foods)
        .insert(
          v3.FoodsCompanion.insert(
            id: 'f1',
            name: 'Oats',
            per100Unit: 'grams',
            kcal: 370,
            proteinG: 13,
            carbsG: 60,
            fatG: 7,
            fibreG: const Value(10),
            provenance: 'userEntered',
            source: 'userCreated',
            searchKey: 'oats',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await old
        .into(old.foodServings)
        .insert(
          v3.FoodServingsCompanion.insert(
            id: 'f1:0',
            foodId: 'f1',
            label: 'bowl',
            amount: 40,
            unit: 'grams',
            sortOrder: 0,
          ),
        );
    await old
        .into(old.foodLogEntries)
        .insert(
          v3.FoodLogEntriesCompanion.insert(
            id: 'e1',
            day: '2026-11-01',
            meal: 'breakfast',
            name: 'Oats',
            amount: 40,
            unit: 'grams',
            kcal: 148,
            proteinG: 5.2,
            carbsG: 24,
            fatG: 2.8,
            provenance: 'userEntered',
            loggedAt: t,
            createdAt: t,
            updatedAt: t,
          ),
        );
    await old
        .into(old.savedMeals)
        .insert(
          v3.SavedMealsCompanion.insert(
            id: 'sm1',
            name: 'Usual',
            createdAt: t,
            updatedAt: t,
          ),
        );
    await old
        .into(old.savedMealItems)
        .insert(
          v3.SavedMealItemsCompanion.insert(
            id: 'i1',
            savedMealId: 'sm1',
            name: 'Oats',
            amount: 40,
            unit: 'grams',
            sortOrder: 0,
            kcal: 148,
            proteinG: 5.2,
            carbsG: 24,
            fatG: 2.8,
            provenance: 'userEntered',
          ),
        );
  }

  Future<void> expectRowsKept(v4.DatabaseAtV4 db) async {
    final food = (await db.select(db.foods).get()).single;
    expect(
      [food.id, food.proteinG, food.carbsG, food.fatG, food.fibreG],
      ['f1', 13, 60, 7, 10],
    );
    expect((await db.select(db.foodServings).get()).single.id, 'f1:0');
    final entry = (await db.select(db.foodLogEntries).get()).single;
    expect([entry.id, entry.kcal, entry.proteinG], ['e1', 148, 5.2]);
    final item = (await db.select(db.savedMealItems).get()).single;
    expect([item.id, item.carbsG, item.fatG], ['i1', 24, 2.8]);
  }

  test('v3 upgrade to v4 keeps a food, a log entry and a saved-meal item, '
      'and allows unknown macros afterwards', () async {
    final schema = await verifier.schemaAt(3);
    final oldDb = v3.DatabaseAtV3(schema.newConnection());
    await insertV3Rows(oldDb);
    await oldDb.close();

    final db = AppDatabase(schema.newConnection());
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 4);

    final migrated = v4.DatabaseAtV4(schema.newConnection());
    addTearDown(migrated.close);
    await expectRowsKept(migrated);

    await migrated
        .into(migrated.foodLogEntries)
        .insert(
          v4.FoodLogEntriesCompanion.insert(
            id: 'e2',
            day: '2026-11-01',
            meal: 'snack',
            name: 'Mystery',
            amount: 100,
            unit: 'grams',
            kcal: 100,
            provenance: 'crowdsourced',
            loggedAt: t,
            createdAt: t,
            updatedAt: t,
          ),
        );
    final e2 = await (migrated.select(
      migrated.foodLogEntries,
    )..where((r) => r.id.equals('e2'))).getSingle();
    expect(e2.proteinG, isNull);
  });

  test('v3 upgrade can run again after a crash before user_version is '
      'recorded', () async {
    final schema = await verifier.schemaAt(3);
    final oldDb = v3.DatabaseAtV3(schema.newConnection());
    await insertV3Rows(oldDb);
    await oldDb.close();

    final first = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(first, 4);
    await first.customStatement('PRAGMA user_version = 3');
    await first.close();

    final second = AppDatabase(schema.newConnection());
    addTearDown(second.close);
    expect((await second.select(second.foods).get()).single.id, 'f1');
    expect((await second.select(second.foodServings).get()).single.id, 'f1:0');
    expect((await second.select(second.foodLogEntries).get()).single.id, 'e1');
    expect((await second.select(second.savedMealItems).get()).single.id, 'i1');
    final version = await second
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, 4);
  });
}
