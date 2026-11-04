import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';

import 'generated_migrations/schema.dart';
import 'generated_migrations/schema_v1.dart' as v1;
import 'generated_migrations/schema_v2.dart' as v2;
import 'generated_migrations/schema_v3.dart' as v3;

/// Every schema version must migrate to the current one without loss. Add a
/// case here for each new version (R-07: data loss from an untested
/// migration is the project's top data-integrity risk).
void main() {
  _v2ToV3();
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
    await verifier.migrateAndValidate(db, 3);

    final migrated = v3.DatabaseAtV3(schema.newConnection());
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

  test('schema v2 upgrades to v3 keeping existing rows', () async {
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
    await verifier.migrateAndValidate(db, 3);

    final migrated = v3.DatabaseAtV3(schema.newConnection());
    addTearDown(migrated.close);
    expect(
      (await migrated.select(migrated.measurements).get()).single.id,
      'm1',
    );
    expect(await migrated.select(migrated.savedMeals).get(), isEmpty);
  });

  test('schema v1 upgrades straight to v3', () async {
    final connection = await verifier.startAt(1);
    final db = AppDatabase(connection);
    addTearDown(db.close);
    await verifier.migrateAndValidate(db, 3);
  });

  test('v2 upgrade can run again after a crash before user_version is '
      'recorded', () async {
    final schema = await verifier.schemaAt(2);
    final first = AppDatabase(schema.newConnection());
    await verifier.migrateAndValidate(first, 3);
    await first.customStatement('PRAGMA user_version = 2');
    await first.close();

    final second = AppDatabase(schema.newConnection());
    addTearDown(second.close);
    expect(await second.select(second.savedMeals).get(), isEmpty);
    final version = await second
        .customSelect('PRAGMA user_version')
        .getSingle();
    expect(version.data.values.single, 3);
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
    await verifier.migrateAndValidate(first, 3);
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
    expect(version.data.values.single, 3);
  });
}
