import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/platform/fake_user_file_gateway.dart';
import 'package:repforge/data/repositories/drift_measurement_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/files/user_file_gateway.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/measurements_csv.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/measurements/application/export_measurements_csv.dart';

Measurement _m(String id, MeasurementSite site, double v, DateTime at) =>
    Measurement(
      id: id,
      site: site,
      value: site.isWeight
          ? MeasurementValue.kg(Kilograms.fromStored(v))
          : MeasurementValue.cm(Centimetres.fromStored(v)),
      recordedAt: at.toUtc(),
      createdAt: at.toUtc(),
      updatedAt: at.toUtc(),
    );

void main() {
  // Local wall clock so the file name date holds in any time zone.
  final now = DateTime(2026, 11, 5, 23, 50);
  late AppDatabase db;
  late DriftMeasurementRepository repo;
  late FakeUserFileGateway gateway;
  late ExportMeasurementsCsv export;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.inMemory();
    final clock = FixedClock(now);
    repo = DriftMeasurementRepository(db, clock: clock);
    gateway = FakeUserFileGateway();
    export = ExportMeasurementsCsv(
      repository: repo,
      gateway: gateway,
      clock: clock,
    );
  });
  tearDown(() => db.close());

  Future<void> insertRaw(String id, String site, double value) => db
      .into(db.measurements)
      .insert(
        MeasurementsCompanion.insert(
          id: id,
          site: site,
          value: value,
          recordedAt: DateTime.utc(2026, 11, 2),
          createdAt: DateTime.utc(2026, 11, 2),
          updatedAt: DateTime.utc(2026, 11, 2),
        ),
      );

  group('ExportMeasurementsCsv', () {
    test('hands a UTF-8 CSV named by the local date to the gateway', () async {
      await repo.insertAll([
        _m('a', MeasurementSite.weight, 80.5, DateTime(2026, 11, 1, 8)),
        _m('b', MeasurementSite.waist, 87.5, DateTime(2026, 11, 3, 8, 30)),
        _m('c', MeasurementSite.thighLeft, 55, DateTime(2026, 11, 2, 7)),
      ]);

      final result = await export();

      final value = (result as Ok<CsvExportResult>).value;
      expect(value.rows, 3);
      expect(value.unreadableCount, 0);
      expect(value.outcome, ExportOutcome.shared);
      expect(value.nothingToExport, isFalse);
      final sent = gateway.exports.single;
      expect(sent.fileName, 'repforge-measurements-2026-11-05.csv');
      expect(value.fileName, sent.fileName);
      expect(sent.mimeType, 'text/csv');
      expect(sent.subject, 'RepForge measurements');
      final lines = sent.text.split('\r\n');
      expect(lines.first, measurementsCsvHeader);
      expect(lines.last, '', reason: 'every record ends with CRLF');
      expect(lines, hasLength(5));
      // Oldest first.
      expect(lines[1], endsWith(',Weight,80.5,kg'));
      expect(lines[2], endsWith(',Left thigh,55.0,cm'));
      expect(lines[3], endsWith(',Waist,87.5,cm'));
    });

    test('UTF-8 without a byte order mark; the content is ASCII', () async {
      await repo.insert(
        _m('a', MeasurementSite.weight, 80.5, DateTime(2026, 11, 1, 8)),
      );
      await export();
      final bytes = gateway.exports.single.bytes;
      expect(bytes.take(3), isNot([0xEF, 0xBB, 0xBF]));
      expect(bytes.every((b) => b < 0x80), isTrue);
      expect(utf8.decode(bytes), startsWith('date,type,value,unit\r\n'));
    });

    test('the CSV parses back to exactly the stored readings', () async {
      final source = [
        _m('a', MeasurementSite.weight, 80.5, DateTime(2026, 11, 1, 8, 5, 9)),
        _m('b', MeasurementSite.waist, 87.5, DateTime(2026, 11, 3, 8, 30)),
        _m('c', MeasurementSite.bicepsRight, 33.1, DateTime(2026, 10, 2, 7)),
        _m('d', MeasurementSite.weight, 79.9, DateTime(2026, 11, 4, 6, 45)),
      ];
      await repo.insertAll(source);

      await export();

      final rows = [
        for (final line in gateway.exports.single.text.split('\r\n').skip(1))
          if (line.isNotEmpty) line.split(','),
      ];
      expect(rows, hasLength(source.length));
      final parsed = [
        for (final r in rows)
          (
            at: DateTime.parse(r[0]),
            type: r[1],
            value: double.parse(r[2]),
            unit: r[3],
          ),
      ];
      final expected = [
        for (final m in source)
          (
            at: m.recordedAt,
            type: m.site.label,
            value: m.value.raw,
            unit: m.site.unit,
          ),
      ]..sort((a, b) => a.at.compareTo(b.at));
      for (var i = 0; i < expected.length; i++) {
        expect(
          parsed[i].at.isAtSameMomentAs(expected[i].at),
          isTrue,
          reason: 'row $i instant',
        );
        expect(parsed[i].type, expected[i].type);
        expect(parsed[i].value, expected[i].value);
        expect(parsed[i].unit, expected[i].unit);
      }
    });

    test('a single type exports only that type, with its name in the '
        'file name', () async {
      await repo.insertAll([
        _m('a', MeasurementSite.weight, 80.5, DateTime(2026, 11, 1, 8)),
        _m('b', MeasurementSite.waist, 87.5, DateTime(2026, 11, 3, 8)),
        _m('c', MeasurementSite.waist, 86.5, DateTime(2026, 11, 4, 8)),
      ]);

      final result = await export(site: MeasurementSite.waist);

      expect((result as Ok<CsvExportResult>).value.rows, 2);
      final sent = gateway.exports.single;
      expect(sent.fileName, 'repforge-measurements-waist-2026-11-05.csv');
      expect(sent.text, isNot(contains('Weight')));
      expect('Waist'.allMatches(sent.text), hasLength(2));
    });

    test('deleted readings are not exported', () async {
      await repo.insertAll([
        _m('a', MeasurementSite.weight, 80.5, DateTime(2026, 11, 1, 8)),
        _m('b', MeasurementSite.weight, 81.5, DateTime(2026, 11, 2, 8)),
      ]);
      await repo.delete('b');
      await export();
      expect(gateway.exports.single.text, contains('80.5'));
      expect(gateway.exports.single.text, isNot(contains('81.5')));
    });

    for (final outcome in ExportOutcome.values) {
      test('passes the $outcome outcome through', () async {
        await repo.insert(
          _m('a', MeasurementSite.weight, 80.5, DateTime(2026, 11, 1, 8)),
        );
        gateway.exportResult = Result.ok(outcome);
        final result = await export();
        expect((result as Ok<CsvExportResult>).value.outcome, outcome);
      });
    }

    test('an unavailable share sheet is an UnavailableError', () async {
      await repo.insert(
        _m('a', MeasurementSite.weight, 80.5, DateTime(2026, 11, 1, 8)),
      );
      gateway.exportResult = const Result.err(UnavailableError('no sharing'));
      final result = await export();
      expect((result as Err<CsvExportResult>).error, isA<UnavailableError>());
    });

    test('nothing to export: no sheet is opened', () async {
      final result = await export();
      final value = (result as Ok<CsvExportResult>).value;
      expect(value.nothingToExport, isTrue);
      expect(value.rows, 0);
      expect(value.outcome, isNull);
      expect(gateway.exports, isEmpty);
    });

    test('unreadable readings are left out and counted', () async {
      await repo.insert(
        _m('a', MeasurementSite.waist, 87.5, DateTime(2026, 11, 1, 8)),
      );
      await insertRaw('bad1', 'waist', 400); // out of range
      await insertRaw('bad2', 'weight', 80.05); // off step
      await insertRaw('bad3', 'earlobe', 3); // unknown site

      final all = await export();
      final value = (all as Ok<CsvExportResult>).value;
      expect(value.rows, 1);
      expect(value.unreadableCount, 3);
      expect(gateway.exports.single.text.split('\r\n'), hasLength(3));
      expect(gateway.exports.single.text, isNot(contains('400')));

      // Per type: only the unreadable rows of that type are counted.
      final waist = await export(site: MeasurementSite.waist);
      expect((waist as Ok<CsvExportResult>).value.unreadableCount, 1);
    });

    test(
      'only unreadable readings: nothing to export, count reported',
      () async {
        await insertRaw('bad', 'waist', 400);
        final result = await export();
        final value = (result as Ok<CsvExportResult>).value;
        expect(value.nothingToExport, isTrue);
        expect(value.unreadableCount, 1);
        expect(gateway.exports, isEmpty);
      },
    );

    test('the file name uses the device-local date', () {
      expect(
        ExportMeasurementsCsv.fileNameFor(DateTime(2026, 1, 9, 23, 59)),
        'repforge-measurements-2026-01-09.csv',
      );
    });
  });
}
