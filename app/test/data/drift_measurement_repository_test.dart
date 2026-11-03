import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_measurement_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 3, 12));

Measurement _kg(String id, double kg, DateTime at, {String? note}) =>
    Measurement(
      id: id,
      site: MeasurementSite.weight,
      value: MeasurementValue.kg(Kilograms.fromStored(kg)),
      recordedAt: at,
      note: note,
      createdAt: at,
      updatedAt: at,
    );

Measurement _cm(
  String id,
  MeasurementSite site,
  double cm,
  DateTime at, {
  String? note,
}) => Measurement(
  id: id,
  site: site,
  value: MeasurementValue.cm(Centimetres.fromStored(cm)),
  recordedAt: at,
  note: note,
  createdAt: at,
  updatedAt: at,
);

void main() {
  group('DriftMeasurementRepository (in-memory)', () {
    late AppDatabase db;
    late DriftMeasurementRepository repo;
    final d1 = DateTime.utc(2026, 11, 1, 8);
    final d2 = DateTime.utc(2026, 11, 2, 8);
    final d3 = DateTime.utc(2026, 11, 3, 8);

    setUp(() {
      db = AppDatabase.inMemory();
      repo = DriftMeasurementRepository(db, clock: _clock);
    });
    tearDown(() => db.close());

    Future<void> insertRaw(String id, String site, double value, DateTime at) =>
        db
            .into(db.measurements)
            .insert(
              MeasurementsCompanion.insert(
                id: id,
                site: site,
                value: value,
                recordedAt: at,
                createdAt: at,
                updatedAt: at,
              ),
            );

    test('inserts and reads a weight and a cm site', () async {
      await repo.insert(_kg('w', 80.5, d1, note: 'fasted'));
      await repo.insert(_cm('c', MeasurementSite.waist, 85.5, d1));

      final all = await repo.watchAll().first;
      expect(all, hasLength(2));
      final w = all.firstWhere((m) => m.id == 'w');
      expect(w.site, MeasurementSite.weight);
      expect(w.value, isA<WeightValue>());
      expect(w.value.raw, 80.5);
      expect(w.note, 'fasted');
      final c = all.firstWhere((m) => m.id == 'c');
      expect(c.value, isA<LengthValue>());
      expect(c.value.raw, 85.5);
      expect(c.note, isNull);
      expect(c.recordedAt.isAtSameMomentAs(d1), isTrue);
    });

    test('watchSite returns only that site, newest first', () async {
      await repo.insert(_cm('a', MeasurementSite.waist, 85, d1));
      await repo.insert(_cm('b', MeasurementSite.waist, 84, d3));
      await repo.insert(_cm('c', MeasurementSite.waist, 84.5, d2));
      await repo.insert(_cm('x', MeasurementSite.chest, 100, d2));
      await repo.insert(_kg('w', 80, d2));

      final waist = await repo.watchSite(MeasurementSite.waist).first;
      expect(waist.map((m) => m.id), ['b', 'c', 'a']);
    });

    test('watchAll orders newest first and honours limit', () async {
      await repo.insert(_kg('a', 80, d1));
      await repo.insert(_cm('b', MeasurementSite.neck, 40, d2));
      await repo.insert(_cm('c', MeasurementSite.hips, 95, d3));

      expect((await repo.watchAll().first).map((m) => m.id), ['c', 'b', 'a']);
      expect((await repo.watchAll(limit: 2).first).map((m) => m.id), [
        'c',
        'b',
      ]);
    });

    test('latest returns the newest per site, null when none', () async {
      expect(await repo.latest(MeasurementSite.waist), isNull);
      await repo.insert(_cm('a', MeasurementSite.waist, 85, d1));
      await repo.insert(_cm('b', MeasurementSite.waist, 84, d2));
      await repo.insert(_cm('c', MeasurementSite.chest, 101, d1));

      expect((await repo.latest(MeasurementSite.waist))!.id, 'b');
      expect((await repo.latest(MeasurementSite.chest))!.id, 'c');
      expect(await repo.latest(MeasurementSite.weight), isNull);
    });

    test('latest skips a newer unreadable row', () async {
      await repo.insert(_cm('a', MeasurementSite.waist, 85, d1));
      await insertRaw('bad', 'waist', 400, d2);
      expect((await repo.latest(MeasurementSite.waist))!.id, 'a');
    });

    test('update changes value and note and stamps updatedAt', () async {
      await repo.insert(_kg('a', 80, d1, note: 'old'));
      await repo.update(_kg('a', 79.4, d1, note: 'new'));

      final m = (await repo.watchAll().first).single;
      expect(m.value.raw, 79.4);
      expect(m.note, 'new');
      expect(m.updatedAt.isAtSameMomentAs(_clock.now()), isTrue);
      expect(m.createdAt.isAtSameMomentAs(d1), isTrue);
    });

    test('delete is soft, hides the row and is idempotent', () async {
      await repo.insert(_kg('a', 80, d1));
      await repo.delete('a');

      expect(await repo.watchAll().first, isEmpty);
      expect(await repo.latest(MeasurementSite.weight), isNull);
      final first = (await db.select(db.measurements).get()).single;
      expect(first.deletedAt, isNotNull);
      expect(first.deletedAt!.isAtSameMomentAs(_clock.now()), isTrue);

      await repo.delete('a');
      await repo.delete('missing');
      final second = (await db.select(db.measurements).get()).single;
      expect(second.updatedAt, first.updatedAt);
      expect(second.deletedAt, first.deletedAt);
    });

    test('skips rows with an unknown site or out-of-range value', () async {
      await repo.insert(_kg('ok', 80, d1));
      await insertRaw('unknown', 'earlobe', 10, d2);
      await insertRaw('light', 'weight', 5, d2);
      await insertRaw('heavy', 'weight', 600, d2);
      await insertRaw('tiny', 'waist', 5, d2);
      await insertRaw('huge', 'chest', 400, d2);

      final all = await repo.watchAll().first;
      expect(all.map((m) => m.id), ['ok']);
      expect(await repo.watchSite(MeasurementSite.waist).first, isEmpty);
    });

    test('per-site ranges are applied', () async {
      // 50 is a valid weight and 25 is a valid cm value; both are readable.
      await insertRaw('kgOk', 'weight', 50, d1);
      await insertRaw('cmOk', 'neck', 25, d1);
      expect(await repo.watchAll().first, hasLength(2));
    });

    test('left and right thigh are distinct sites', () async {
      await repo.insert(_cm('l', MeasurementSite.thighLeft, 55, d1));
      await repo.insert(_cm('r', MeasurementSite.thighRight, 56, d1));

      final left = await repo.watchSite(MeasurementSite.thighLeft).first;
      final right = await repo.watchSite(MeasurementSite.thighRight).first;
      expect(left.single.id, 'l');
      expect(right.single.id, 'r');
      expect((await repo.latest(MeasurementSite.thighLeft))!.value.raw, 55);
      expect((await repo.latest(MeasurementSite.thighRight))!.value.raw, 56);
    });

    test('toRow and toEntity round trip', () {
      final m = _cm('a', MeasurementSite.calfLeft, 38.2, d1, note: 'n');
      final c = DriftMeasurementRepository.toRow(m);
      expect(c.site, const Value('calfLeft'));
      expect(c.value, const Value(38.2));
    });
  });
}
