import 'package:drift/drift.dart' show Variable, driftRuntimeOptions;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_backup_repository.dart';
import 'package:repforge/data/repositories/drift_measurement_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurement_repository.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/measurements_csv.dart';
import 'package:repforge/domain/measurements/unreadable_measurement.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/measurements/application/delete_measurement.dart';
import 'package:repforge/features/measurements/application/measurement_providers.dart';
import 'package:repforge/features/measurements/application/record_measurement_entry.dart';
import 'package:repforge/features/measurements/application/update_measurement.dart';

void main() {
  // Local wall-clock "now" so the tests hold in any time zone (run under
  // TZ=Pacific/Auckland and TZ=America/Los_Angeles as well).
  final now = DateTime(2026, 11, 5, 23, 50);
  late AppDatabase db;
  late DriftMeasurementRepository repo;
  late RecordMeasurementEntry record;
  late UpdateMeasurement update;
  late DeleteMeasurement delete;
  var n = 0;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.inMemory();
    final clock = FixedClock(now);
    repo = DriftMeasurementRepository(db, clock: clock);
    n = 0;
    record = RecordMeasurementEntry(
      repository: repo,
      clock: clock,
      newId: () => 'id${n++}',
    );
    update = UpdateMeasurement(repository: repo, clock: clock);
    delete = DeleteMeasurement(repository: repo);
  });
  tearDown(() => db.close());

  Future<List<Measurement>> all() => repo.watchAll().first;
  List<Measurement> ok(Result<List<Measurement>> r) =>
      (r as Ok<List<Measurement>>).value;
  ValidationError invalid(Result<Object?> r) =>
      (r as Err<Object?>).error as ValidationError;

  group('RecordMeasurementEntry', () {
    test('writes one row per provided site with the same instant', () async {
      final at = DateTime(2026, 11, 4, 8, 15);
      final r = await record(
        values: {
          MeasurementSite.weight: '80.1',
          MeasurementSite.waist: '85,5',
          MeasurementSite.neck: '   ',
        },
        recordedAt: at,
        note: '  morning ',
      );
      expect(ok(r).map((m) => m.site), [
        MeasurementSite.weight,
        MeasurementSite.waist,
      ]);
      final rows = await all();
      expect(rows, hasLength(2));
      expect(rows.every((m) => m.recordedAt.isAtSameMomentAs(at)), isTrue);
      expect(rows.every((m) => m.note == 'morning'), isTrue);
      expect(rows.firstWhere((m) => m.site.isWeight).value.raw, 80.1);
      expect(rows.firstWhere((m) => !m.site.isWeight).value.raw, 85.5);
      expect(await repo.latest(MeasurementSite.neck), isNull); // not zero
    });

    test('defaults the time to the clock', () async {
      await record(values: {MeasurementSite.chest: '100'});
      expect((await all()).single.recordedAt.isAtSameMomentAs(now), isTrue);
    });

    test('at least one value is required', () async {
      final r = await record(values: {MeasurementSite.weight: ' '});
      expect(invalid(r).field, 'values');
      expect((await record(values: {})).isErr, isTrue);
      expect(await all(), isEmpty);
    });

    test('limits and off-step values are rejected per site', () async {
      for (final text in ['19.9', '500.1', '80.05', '80.15', 'abc']) {
        final r = await record(values: {MeasurementSite.weight: text});
        expect(invalid(r).field, 'weight', reason: text);
      }
      for (final text in ['9.9', '300.1', '85.05', '85.15']) {
        final r = await record(values: {MeasurementSite.hips: text});
        expect(invalid(r).field, 'hips', reason: text);
      }
      for (final text in ['20.0', '80.1', '500.0']) {
        expect(
          (await record(values: {MeasurementSite.weight: text})).isOk,
          isTrue,
          reason: text,
        );
      }
      for (final text in ['10.0', '85.1', '300.0']) {
        expect(
          (await record(values: {MeasurementSite.hips: text})).isOk,
          isTrue,
          reason: text,
        );
      }
    });

    test('every bad field is reported, not just the first', () async {
      final r = await record(
        values: {
          MeasurementSite.weight: '80.05',
          MeasurementSite.waist: '9',
          MeasurementSite.neck: '38',
        },
        recordedAt: DateTime(2026, 11, 7),
      );
      final e = invalid(r);
      expect(e.fieldErrors.keys, ['weight', 'waist', 'recordedAt']);
      expect(e.field, 'weight'); // first error
      expect(e.fieldErrors['weight'], contains('0.1 kg'));
      expect(await all(), isEmpty);
    });

    test('one invalid site writes nothing at all', () async {
      final r = await record(
        values: {MeasurementSite.weight: '80', MeasurementSite.waist: '85.05'},
      );
      expect(invalid(r).field, 'waist');
      expect(await all(), isEmpty);
    });

    test(
      'future instants are rejected near midnight; tolerance 1 min',
      () async {
        final tomorrow = DateTime(2026, 11, 6, 0, 10);
        expect(
          invalid(
            await record(
              values: {MeasurementSite.weight: '80'},
              recordedAt: tomorrow,
            ),
          ).field,
          'recordedAt',
        );
        expect(await all(), isEmpty);
        expect(
          (await record(
            values: {MeasurementSite.weight: '80'},
            recordedAt: DateTime(2026, 11, 5, 23, 50, 30),
          )).isOk,
          isTrue,
        );
      },
    );

    test('back-dating is allowed and several entries per day', () async {
      final day = DateTime(2020, 1, 2, 7);
      await record(values: {MeasurementSite.weight: '80'}, recordedAt: day);
      await record(
        values: {MeasurementSite.weight: '80.2'},
        recordedAt: day.add(const Duration(hours: 12)),
      );
      expect(await repo.watchSite(MeasurementSite.weight).first, hasLength(2));
    });

    test(
      'bilateral independence: right thigh only creates no left row',
      () async {
        await record(values: {MeasurementSite.thighRight: '55.5'});
        expect(await repo.watchSite(MeasurementSite.thighLeft).first, isEmpty);
        expect((await all()).single.site, MeasurementSite.thighRight);
      },
    );

    test('a storage failure of any kind becomes StorageError', () async {
      final bad = RecordMeasurementEntry(
        repository: _Throwing(),
        clock: FixedClock(now),
        newId: () => 'x',
      );
      final r = await bad(values: {MeasurementSite.weight: '80'});
      expect((r as Err).error, isA<StorageError>());
    });

    test('all 13 sites in one entry', () async {
      final r = await record(
        values: {
          for (final s in MeasurementSite.values) s: s.isWeight ? '80' : '40',
        },
      );
      expect(ok(r), hasLength(13));
      expect(ok(r).map((m) => m.id).toSet(), hasLength(13));
    });
  });

  group('UpdateMeasurement', () {
    test(
      'edits value, instant and note; site and other rows unchanged',
      () async {
        final created = ok(
          await record(
            values: {
              MeasurementSite.thighLeft: '55',
              MeasurementSite.thighRight: '56',
            },
            recordedAt: DateTime(2026, 11, 1, 9),
          ),
        );
        final left = created.first;
        final r = await update(
          id: left.id,
          valueText: '54.5',
          recordedAt: DateTime(2026, 11, 2, 9),
          note: ' tape ',
        );
        final u = (r as Ok<Measurement>).value;
        expect(u.site, MeasurementSite.thighLeft);
        expect(u.value.raw, 54.5);
        expect(u.note, 'tape');
        final right = (await repo.byId(created.last.id))!;
        expect(right.value.raw, 56);
        expect(
          right.recordedAt.isAtSameMomentAs(DateTime(2026, 11, 1, 9)),
          true,
        );
        final stored = (await repo.byId(left.id))!;
        expect(stored.value.raw, 54.5);
        expect(stored.createdAt.isAtSameMomentAs(left.createdAt), isTrue);
      },
    );

    test('same rules: strict value, no future, unknown id', () async {
      final m = ok(await record(values: {MeasurementSite.waist: '90'})).single;
      final t = DateTime(2026, 11);
      expect(
        invalid(
          await update(id: m.id, valueText: '90.05', recordedAt: t, note: null),
        ).field,
        'waist',
      );
      expect(
        invalid(
          await update(
            id: m.id,
            valueText: '90',
            recordedAt: DateTime(2026, 11, 6),
            note: null,
          ),
        ).field,
        'recordedAt',
      );
      expect(
        (await update(
          id: 'nope',
          valueText: '90',
          recordedAt: t,
          note: null,
        ) as Err).error,
        isA<NotFoundError>(),
      );
      expect((await repo.byId(m.id))!.value.raw, 90);
    });

    test('blank note clears it; query reflects the edit at once', () async {
      final m = ok(
        await record(values: {MeasurementSite.waist: '90'}, note: 'a'),
      ).single;
      final stream = repo.watchSite(MeasurementSite.waist);
      await update(id: m.id, valueText: '89', recordedAt: now, note: ' ');
      expect((await stream.first).single.note, isNull);
      expect((await stream.first).single.value.raw, 89);
    });

    test('storage failures become StorageError', () async {
      final bad = UpdateMeasurement(
        repository: _Throwing(),
        clock: FixedClock(now),
      );
      final r = await bad(
        id: 'a',
        valueText: '90',
        recordedAt: now,
        note: null,
      );
      expect((r as Err).error, isA<StorageError>());
    });
  });

  group('UpdateMeasurement races and multi-field errors', () {
    test(
      'row deleted between the read and the write -> NotFoundError',
      () async {
        final m = ok(await record(values: {MeasurementSite.waist: '90'}))
            .single;
        final racing = UpdateMeasurement(
          repository: _DeleteAfterRead(repo),
          clock: FixedClock(now),
        );
        final r = await racing(
          id: m.id,
          valueText: '89',
          recordedAt: DateTime(2026, 11),
          note: null,
        );
        expect((r as Err).error, isA<NotFoundError>());
      },
    );

    test('reports the bad value and the future date together', () async {
      final m = ok(await record(values: {MeasurementSite.waist: '90'})).single;
      final r = await update(
        id: m.id,
        valueText: '90.05',
        recordedAt: DateTime(2026, 11, 7),
        note: null,
      );
      final e = (r as Err).error as ValidationError;
      expect(e.fieldErrors.keys, containsAll(['waist', 'recordedAt']));
    });

    test('repository update reports the rows changed', () async {
      final m = ok(await record(values: {MeasurementSite.waist: '90'})).single;
      expect(await repo.update(m), 1);
      await repo.delete(m.id);
      expect(await repo.update(m), 0);
    });
  });

  group('DeleteMeasurement', () {
    test('soft-deletes one side only; history updates', () async {
      final c = ok(
        await record(
          values: {
            MeasurementSite.calfLeft: '38',
            MeasurementSite.calfRight: '38.5',
          },
        ),
      );
      expect((await delete(c.first.id)).isOk, isTrue);
      expect(await repo.watchSite(MeasurementSite.calfLeft).first, isEmpty);
      expect(
        await repo.watchSite(MeasurementSite.calfRight).first,
        hasLength(1),
      );
      final rows = await db.select(db.measurements).get();
      expect(rows, hasLength(2)); // soft delete keeps the row
      expect(rows.firstWhere((r) => r.id == c.first.id).deletedAt, isNotNull);
    });

    test('unknown or already deleted -> NotFoundError', () async {
      expect((await delete('nope') as Err).error, isA<NotFoundError>());
      final m = ok(await record(values: {MeasurementSite.neck: '38'})).single;
      await delete(m.id);
      expect((await delete(m.id) as Err).error, isA<NotFoundError>());
    });

    test('storage failures become StorageError', () async {
      final r = await DeleteMeasurement(repository: _Throwing())('a');
      expect((r as Err).error, isA<StorageError>());
    });
  });

  group('date persistence', () {
    test(
      'instants are stored as UTC text and read back as the same instant',
      () async {
        final at = DateTime(2026, 11, 5, 0, 30); // local; date differs in UTC
        await record(values: {MeasurementSite.weight: '80'}, recordedAt: at);
        final raw = await db
            .customSelect('SELECT recorded_at AS r FROM measurements')
            .getSingle();
        final text = raw.read<String>('r');
        expect(text, endsWith('Z'));
        expect(DateTime.parse(text).isAtSameMomentAs(at), isTrue);
        final back = (await all()).single.recordedAt;
        expect(back.isUtc, isTrue);
        expect(back.isAtSameMomentAs(at), isTrue);
      },
    );

    test(
      'update also writes UTC, so text ordering stays chronological',
      () async {
        final a = ok(
          await record(
            values: {MeasurementSite.weight: '80'},
            recordedAt: DateTime(2026, 11, 1, 9),
          ),
        ).single;
        await update(
          id: a.id,
          valueText: '80',
          recordedAt: DateTime(2026, 11, 3, 9),
          note: null,
        );
        final rows = await db
            .customSelect(
              'SELECT recorded_at AS r FROM measurements WHERE id = ?',
              variables: [Variable<String>(a.id)],
            )
            .getSingle();
        expect(rows.read<String>('r'), endsWith('Z'));
      },
    );

    test('history is newest first across days', () async {
      for (final d in [3, 1, 2]) {
        await record(
          values: {MeasurementSite.weight: '8$d'},
          recordedAt: DateTime(2026, 11, d, 8),
        );
      }
      final w = await repo.watchSite(MeasurementSite.weight).first;
      expect(w.map((m) => m.value.raw), [83, 82, 81]);
    });
  });

  group('unreadable stored rows (owner rule: never drop silently)', () {
    final t = DateTime.utc(2026, 11, 1, 8);
    Future<void> raw(String id, String site, double value) => db
        .into(db.measurements)
        .insert(
          MeasurementsCompanion.insert(
            id: id,
            site: site,
            value: value,
            recordedAt: t,
            createdAt: t,
            updatedAt: t,
          ),
        );

    test(
      'out-of-range and unknown-site rows are listed, preserved, hidden',
      () async {
        await raw('w5', 'weight', 5);
        await raw('w600', 'weight', 600);
        await raw('w1994', 'weight', 19.94);
        await raw('c99', 'waist', 9.9);
        await raw('c3001', 'waist', 300.1);
        await raw('knee', 'kneeLeft', 40);
        await raw('good', 'waist', 85);

        final bad = await repo.watchUnreadable().first;
        expect(bad.map((u) => u.id).toSet(), {
          'w5',
          'w600',
          'w1994',
          'c99',
          'c3001',
          'knee',
        });
        final w600 = bad.firstWhere((u) => u.id == 'w600');
        expect((w600.site, w600.rawValue), ('weight', 600.0));
        expect(w600.recordedAt.isAtSameMomentAs(t), isTrue);
        expect(bad.firstWhere((u) => u.id == 'knee').site, 'kneeLeft');

        // Not shown as history, not in the all-sites list, not found by byId.
        expect((await all()).map((m) => m.id), ['good']);
        expect(await repo.byId('w600'), isNull);
        expect(await repo.latest(MeasurementSite.weight), isNull);
        // But never lost: the rows are untouched in the database.
        final rows = await db.select(db.measurements).get();
        expect(rows, hasLength(7));
        expect(rows.firstWhere((r) => r.id == 'w600').value, 600);
        expect(rows.firstWhere((r) => r.id == 'w1994').value, 19.94);
      },
    );

    test(
      'off-step and just-out-of-range values are reported, never snapped',
      () async {
        await raw('w8005', 'weight', 80.05);
        await raw('c8505', 'waist', 85.05);
        await raw('lo', 'weight', 19.96);
        await raw('hi', 'waist', 300.04);
        await raw('ok', 'chest', 100);
        final bad = await repo.watchUnreadable().first;
        expect(
          {for (final u in bad) u.id: u.rawValue},
          {'w8005': 80.05, 'c8505': 85.05, 'lo': 19.96, 'hi': 300.04},
        );
        // Absent from history, latest and CSV; rows keep their raw value.
        expect((await all()).map((m) => m.id), ['ok']);
        expect(await repo.latest(MeasurementSite.weight), isNull);
        final csv = buildMeasurementsCsv(await all());
        expect(csv, isNot(contains('80.')));
        expect(csv, isNot(contains('85.')));
        final rows = await db.select(db.measurements).get();
        expect(rows.firstWhere((r) => r.id == 'w8005').value, 80.05);
        expect(rows.firstWhere((r) => r.id == 'c8505').value, 85.05);
      },
    );

    test('valid 80.1 and float-noise values remain readable', () async {
      await raw('a', 'weight', 80.1);
      await raw('b', 'weight', 80.10000000000001);
      await raw('c', 'waist', 85.10000000000001);
      expect(await repo.watchUnreadable().first, isEmpty);
      final w = await repo.watchSite(MeasurementSite.weight).first;
      expect(w.map((m) => m.value.raw), [80.1, 80.1]);
      expect((await repo.latest(MeasurementSite.waist))!.value.raw, 85.1);
    });

    test(
      'an unreadable row can be deleted by id; others stay listed',
      () async {
        await raw('w600', 'weight', 600);
        await raw('c99', 'waist', 9.9);
        expect((await delete('w600')).isOk, isTrue);
        expect((await repo.watchUnreadable().first).map((u) => u.id), ['c99']);
        final row = (await db.select(db.measurements).get()).firstWhere(
          (r) => r.id == 'w600',
        );
        expect(row.deletedAt, isNotNull); // soft delete, value untouched
        expect(row.value, 600);
        expect((await delete('w600') as Err).error, isA<NotFoundError>());
      },
    );

    test('an unreadable row cannot be edited (not a measurement)', () async {
      await raw('w600', 'weight', 600);
      final r = await update(
        id: 'w600',
        valueText: '80',
        recordedAt: t,
        note: null,
      );
      expect((r as Err).error, isA<NotFoundError>());
    });

    test('CSV excludes them; the unreadable list reports them', () async {
      await raw('w600', 'weight', 600);
      await raw('good', 'waist', 85);
      final csv = buildMeasurementsCsv(await all());
      expect(csv, isNot(contains('600')));
      expect(csv.trim().split('\r\n'), hasLength(2)); // header + 1 row
      expect(await repo.watchUnreadable().first, hasLength(1));
    });

    test('provider exposes the list and the count', () async {
      await raw('w600', 'weight', 600);
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      final sub = container.listen(unreadableMeasurementsProvider, (_, _) {});
      addTearDown(sub.close);
      while (!sub.read().hasValue) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(sub.read().requireValue.single.id, 'w600');
      expect(container.read(unreadableMeasurementCountProvider), 1);
    });
  });

  group('UTC text invariant (docs/data-model.md)', () {
    Future<List<String>> texts() async {
      final rows = await db
          .customSelect(
            'SELECT recorded_at AS a, created_at AS b, updated_at AS c '
            'FROM measurements',
          )
          .get();
      return [
        for (final r in rows) ...[
          r.read<String>('a'),
          r.read<String>('b'),
          r.read<String>('c'),
        ],
      ];
    }

    test('insert, insertAll, update and a backup restore keep it', () async {
      final local = DateTime(2026, 11, 3, 7, 5);
      final single = Measurement(
        id: 's',
        site: MeasurementSite.neck,
        value: MeasurementValue.cm(Centimetres.fromStored(38)),
        recordedAt: local,
        createdAt: local,
        updatedAt: local,
      );
      await repo.insert(single);
      await record(
        values: {MeasurementSite.weight: '80', MeasurementSite.chest: '100'},
        recordedAt: local,
      );
      await update(id: 's', valueText: '39', recordedAt: local, note: 'x');
      final all1 = await texts();
      expect(all1, hasLength(9));
      expect(all1.every((x) => x.endsWith('Z')), isTrue, reason: '$all1');

      final json = await DriftBackupRepository(
        db,
        clock: FixedClock(now),
      ).exportJson();
      final fresh = AppDatabase.inMemory();
      addTearDown(fresh.close);
      await DriftBackupRepository(
        fresh,
        clock: FixedClock(now),
      ).importJson(json);
      final rows = await fresh
          .customSelect(
            'SELECT recorded_at AS a, created_at AS b, updated_at AS c '
            'FROM measurements',
          )
          .get();
      expect(rows, hasLength(3));
      for (final r in rows) {
        for (final k in ['a', 'b', 'c']) {
          expect(r.read<String>(k), endsWith('Z'), reason: k);
        }
      }
    });
  });

  group('JSON backup round trip (existing mechanism)', () {
    test(
      'measurements survive export and import into a fresh database',
      () async {
        await record(
          values: {
            MeasurementSite.weight: '80.1',
            MeasurementSite.thighRight: '55.5',
          },
          recordedAt: DateTime(2026, 11, 3, 7, 5),
          note: 'n',
        );
        final deleted = ok(await record(values: {MeasurementSite.neck: '38'}))
            .single;
        await delete(deleted.id);

        final json = await DriftBackupRepository(
          db,
          clock: FixedClock(now),
        ).exportJson();
        final fresh = AppDatabase.inMemory();
        addTearDown(fresh.close);
        final result = await DriftBackupRepository(
          fresh,
          clock: FixedClock(now),
        ).importJson(json);
        expect(result.isOk, isTrue);

        final freshRepo = DriftMeasurementRepository(
          fresh,
          clock: FixedClock(now),
        );
        final before = await all();
        final after = await freshRepo.watchAll().first;
        expect(after.map((m) => m.id), before.map((m) => m.id));
        expect(after.map((m) => m.value.raw), before.map((m) => m.value.raw));
        expect(
          after.map((m) => m.recordedAt.millisecondsSinceEpoch),
          before.map((m) => m.recordedAt.millisecondsSinceEpoch),
        );
        expect(after.map((m) => m.note), before.map((m) => m.note));
        expect(after.map((m) => m.site), before.map((m) => m.site));
        // The soft-deleted row is carried too, and stays deleted.
        expect(await fresh.select(fresh.measurements).get(), hasLength(3));
        expect(await freshRepo.byId(deleted.id), isNull);
      },
    );
  });
}

final class _Boom {
  const _Boom();
}

/// Deletes the row right after it was read, as a concurrent delete would.
final class _DeleteAfterRead implements MeasurementRepository {
  _DeleteAfterRead(this.inner);
  final DriftMeasurementRepository inner;

  @override
  Future<Measurement?> byId(String id) async {
    final m = await inner.byId(id);
    await inner.delete(id);
    return m;
  }

  @override
  Future<void> delete(String id) => inner.delete(id);
  @override
  Future<bool> exists(String id) => inner.exists(id);
  @override
  Future<void> insert(Measurement m) => inner.insert(m);
  @override
  Future<void> insertAll(List<Measurement> items) => inner.insertAll(items);
  @override
  Future<Measurement?> latest(MeasurementSite site) => inner.latest(site);
  @override
  Future<List<Measurement>> readingsBetween(
    DateTime from,
    DateTime to, {
    MeasurementSite? site,
  }) => inner.readingsBetween(from, to, site: site);
  @override
  Future<int> update(Measurement m) => inner.update(m);
  @override
  Stream<List<Measurement>> watchAll({int? limit}) =>
      inner.watchAll(limit: limit);
  @override
  Stream<List<Measurement>> watchSite(MeasurementSite site) =>
      inner.watchSite(site);
  @override
  Stream<List<UnreadableMeasurement>> watchUnreadable() =>
      inner.watchUnreadable();
}

/// Throws a non-Exception object to prove `catch Object` -> StorageError.
// ignore_for_file: only_throw_errors
final class _Throwing implements MeasurementRepository {
  @override
  Future<Measurement?> byId(String id) => throw StateError('db gone');
  @override
  Future<void> delete(String id) => throw const _Boom();
  @override
  Future<void> insert(Measurement m) => throw const _Boom();
  @override
  Future<void> insertAll(List<Measurement> items) => throw const _Boom();
  @override
  Future<Measurement?> latest(MeasurementSite site) => throw const _Boom();
  @override
  Future<List<Measurement>> readingsBetween(
    DateTime from,
    DateTime to, {
    MeasurementSite? site,
  }) => throw const _Boom();
  @override
  Future<int> update(Measurement m) => throw const _Boom();
  @override
  Future<bool> exists(String id) => throw const _Boom();
  @override
  Stream<List<UnreadableMeasurement>> watchUnreadable() => throw const _Boom();
  @override
  Stream<List<Measurement>> watchAll({int? limit}) => throw const _Boom();
  @override
  Stream<List<Measurement>> watchSite(MeasurementSite site) =>
      throw const _Boom();
}
