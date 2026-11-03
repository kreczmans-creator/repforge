import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_weight_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/measurements/weight_entry.dart';
import 'package:repforge/domain/units/kilograms.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 3, 12));

WeightEntry _entry(String id, double kg, DateTime at, {String? note}) =>
    WeightEntry(
      id: id,
      recordedAt: at,
      weight: Kilograms.fromStored(kg),
      note: note,
      createdAt: at,
      updatedAt: at,
    );

void main() {
  group('DriftWeightRepository (in-memory)', () {
    late AppDatabase db;
    late DriftWeightRepository repo;

    setUp(() {
      db = AppDatabase.inMemory();
      repo = DriftWeightRepository(db, clock: _clock);
    });
    tearDown(() => db.close());

    test('watchAll emits entries newest first and reacts to inserts', () async {
      final t1 = DateTime.utc(2026, 11, 1, 8);
      final t2 = DateTime.utc(2026, 11, 2, 8);
      await repo.insert(_entry('a', 80, t1));
      await repo.insert(_entry('b', 79.5, t2, note: 'fasted'));

      final first = await repo.watchAll().first;
      expect(first.map((e) => e.id), ['b', 'a']);
      expect(first.first.note, 'fasted');
      expect(first.first.weight.value, 79.5);
    });

    test('delete soft-deletes and hides the row', () async {
      final t = DateTime.utc(2026, 11, 1, 8);
      await repo.insert(_entry('a', 80, t));
      await repo.delete('a');

      expect(await repo.watchAll().first, isEmpty);
      expect(await repo.latest(), isNull);
      final raw = await db.select(db.measurements).get();
      expect(raw.single.deletedAt, isNotNull);
    });

    test('delete stamps deletedAt from the clock and is idempotent', () async {
      final t = DateTime.utc(2026, 11, 1, 8);
      await repo.insert(_entry('a', 80, t));
      await repo.delete('a');
      final first = (await db.select(db.measurements).get()).single;
      expect(first.deletedAt, _clock.now());

      await repo.delete('a'); // second delete must not re-stamp
      final second = (await db.select(db.measurements).get()).single;
      expect(second.updatedAt, first.updatedAt);
    });

    test('skips a row whose stored weight is out of range', () async {
      final t = DateTime.utc(2026, 11, 1, 8);
      await repo.insert(_entry('ok', 80, t));
      await db
          .into(db.measurements)
          .insert(
            MeasurementsCompanion.insert(
              id: 'bad',
              site: 'weight',
              value: 5, // below Kilograms.min
              recordedAt: t.add(const Duration(days: 1)),
              createdAt: t,
              updatedAt: t,
            ),
          );
      final visible = await repo.watchAll().first;
      expect(visible.map((e) => e.id), ['ok']);
      expect((await repo.latest())?.id, 'ok');
    });

    test('latest returns null when empty', () async {
      expect(await repo.latest(), isNull);
    });

    test('round-trips a DateTime with millisecond precision', () async {
      final t = DateTime.utc(2026, 11, 1, 8, 15, 30, 123);
      await repo.insert(_entry('a', 80, t));
      expect((await repo.latest())!.recordedAt, t);
    });
  });

  group('DriftWeightRepository (file persistence)', () {
    test('data survives closing and reopening the database file', () async {
      final dir = await Directory.systemTemp.createTemp('repforge-test-');
      final file = File(p.join(dir.path, 'repforge.sqlite'));
      addTearDown(() => dir.delete(recursive: true));

      final t = DateTime.utc(2026, 11, 1, 8);
      final db1 = AppDatabase(NativeDatabase(file));
      await DriftWeightRepository(
        db1,
        clock: _clock,
      ).insert(_entry('a', 81.2, t));
      await db1.close();

      final db2 = AppDatabase(NativeDatabase(file));
      addTearDown(db2.close);
      final latest = await DriftWeightRepository(db2, clock: _clock).latest();
      expect(latest?.id, 'a');
      expect(latest?.weight.value, 81.2);
    });
  });
}
