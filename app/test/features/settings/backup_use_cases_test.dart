import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/platform/fake_user_file_gateway.dart';
import 'package:repforge/data/repositories/drift_backup_repository.dart';
import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/files/user_file_gateway.dart';
import 'package:repforge/features/settings/application/backup_use_cases.dart';

final _exported = DateTime.utc(2026, 11, 3, 12);

Future<void> _addMeasurement(AppDatabase db, String id, double kg) => db
    .into(db.measurements)
    .insert(
      MeasurementsCompanion.insert(
        id: id,
        site: 'weight',
        value: kg,
        recordedAt: DateTime.utc(2026, 11),
        createdAt: DateTime.utc(2026, 11),
        updatedAt: DateTime.utc(2026, 11),
      ),
    );

void main() {
  late AppDatabase db;
  late DriftBackupRepository repo;
  late FakeUserFileGateway gateway;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftBackupRepository(db, clock: FixedClock(_exported));
    gateway = FakeUserFileGateway();
  });
  tearDown(() => db.close());

  /// A backup file of a database holding [ids] as measurements.
  Future<String> backupOf(List<String> ids) async {
    final other = AppDatabase.inMemory();
    addTearDown(other.close);
    for (final id in ids) {
      await _addMeasurement(other, id, 70);
    }
    return await DriftBackupRepository(
      other,
      clock: FixedClock(_exported),
    ).exportJson();
  }

  Future<List<String>> stored() async => [
    for (final r in await db.select(db.measurements).get()) r.id,
  ];

  group('ExportBackup', () {
    test(
      'exports the existing JSON as UTF-8 named by the local date',
      () async {
        await _addMeasurement(db, 'm1', 80);
        final export = ExportBackup(
          repository: repo,
          gateway: gateway,
          clock: FixedClock(DateTime(2026, 11, 5, 23, 50)),
        );

        final result = await export();

        expect(result, isA<Ok<ExportOutcome>>());
        final sent = gateway.exports.single;
        expect(sent.fileName, 'repforge-backup-2026-11-05.json');
        expect(sent.mimeType, 'application/json');
        expect(sent.text, await repo.exportJson());
        // The file is the one mechanism: it previews and restores as it is.
        final preview =
            (repo.previewJson(sent.text) as Ok<BackupPreview>).value;
        expect(preview.rowCounts['measurements'], 1);
      },
    );

    for (final outcome in ExportOutcome.values) {
      test('passes the $outcome outcome through', () async {
        gateway.exportResult = Result.ok(outcome);
        final result = await ExportBackup(
          repository: repo,
          gateway: gateway,
          clock: FixedClock(_exported),
        )();
        expect((result as Ok<ExportOutcome>).value, outcome);
      });
    }

    test('an unavailable share sheet is an UnavailableError', () async {
      gateway.exportResult = const Result.err(UnavailableError('none'));
      final result = await ExportBackup(
        repository: repo,
        gateway: gateway,
        clock: FixedClock(_exported),
      )();
      expect((result as Err<ExportOutcome>).error, isA<UnavailableError>());
    });
  });

  group('PreviewBackup', () {
    late PreviewBackup preview;
    setUp(() => preview = PreviewBackup(repository: repo, gateway: gateway));

    test('asks for a JSON file and shows the date and the counts without '
        'changing anything', () async {
      await _addMeasurement(db, 'mine', 80);
      final before = await repo.exportJson();
      gateway.queuePick('b.json', utf8.encode(await backupOf(['x', 'y'])));

      final result = await preview();

      final value = (result as Ok<PreviewedBackup?>).value!;
      expect(value.fileName, 'b.json');
      expect(value.preview.exportedAt, _exported);
      expect(value.preview.rowCounts['measurements'], 2);
      expect(value.preview.totalRows, 2);
      final pick = gateway.picks.single;
      // No Android filter (providers misreport .json); iOS filters by UTI.
      expect(pick.extensions, isEmpty);
      expect(pick.mimeTypes, isEmpty);
      expect(pick.uniformTypeIdentifiers, ['public.json']);
      // Data unchanged: same ids, byte-identical export.
      expect(await stored(), ['mine']);
      expect(await repo.exportJson(), before);
    });

    test('cancelling the picker is Ok(null) and changes nothing', () async {
      await _addMeasurement(db, 'mine', 80);
      final result = await preview();
      expect((result as Ok<PreviewedBackup?>).value, isNull);
      expect(await stored(), ['mine']);
    });

    Future<AppError> rejected(List<int> bytes) async {
      await _addMeasurement(db, 'mine', 80);
      final before = await repo.exportJson();
      gateway.queuePick('bad.json', bytes);
      final result = await preview();
      expect(await stored(), ['mine'], reason: 'data unchanged');
      expect(await repo.exportJson(), before, reason: 'database unchanged');
      return (result as Err<PreviewedBackup?>).error;
    }

    test('not JSON is rejected', () async {
      final e = await rejected(utf8.encode('not json {'));
      expect(e, isA<ValidationError>());
      expect(e.message, 'Backup is not valid JSON.');
    });

    test('bytes that are not UTF-8 text are rejected', () async {
      final e = await rejected([0xFF, 0xFE, 0x00, 0x41]);
      expect(e, isA<ValidationError>());
    });

    test('another JSON document is not a RepForge backup', () async {
      final e = await rejected(utf8.encode('{"app":"other","tables":{}}'));
      expect(e.message, 'This file is not a RepForge backup.');
    });

    test('a newer format version is rejected', () async {
      final e = await rejected(
        utf8.encode(
          jsonEncode({
            'app': 'repforge',
            'formatVersion': DriftBackupRepository.formatVersion + 1,
            'tables': <String, Object?>{},
          }),
        ),
      );
      expect(e.message, 'This backup was made by a newer version of RepForge.');
    });

    test('a file without tables is rejected', () async {
      final e = await rejected(
        utf8.encode(jsonEncode({'app': 'repforge', 'formatVersion': 2})),
      );
      expect(e.message, 'Backup has no tables.');
    });

    test('a backup with no restorable record is rejected', () async {
      for (final tables in <Object?>[
        <String, Object?>{},
        {'mystery': <Object?>[]},
        {'measurements': 'nope', 'goals': <Object?>[]},
        {
          'recipes': <Object?>['not a row'],
        },
      ]) {
        final e = await rejected(
          utf8.encode(
            jsonEncode({
              'app': 'repforge',
              'formatVersion': 2,
              'tables': tables,
            }),
          ),
        );
        expect(e, isA<ValidationError>(), reason: '$tables');
        expect(e.message, 'This backup contains no records.');
        // rejected() seeds 'mine' again each time; reset for the next loop.
        await db.delete(db.measurements).go();
      }
    });

    test('an oversized file (FileTooLargeError) is rejected', () async {
      await _addMeasurement(db, 'mine', 80);
      gateway.pickResults.add(
        const Result.err(FileTooLargeError('too big', maxBytes: 10)),
      );
      final result = await preview();
      expect((result as Err<PreviewedBackup?>).error, isA<FileTooLargeError>());
      expect(await stored(), ['mine']);
    });

    test('a file over the picker limit never reaches the use case', () async {
      // The fake enforces maxBytes like the adapter; the use case uses the
      // port default (50 MB), so a larger payload is refused by the port.
      await _addMeasurement(db, 'mine', 80);
      gateway.queuePick('big.json', Uint8List(maxPickedFileBytes + 1));
      final result = await preview();
      expect((result as Err<PreviewedBackup?>).error, isA<FileTooLargeError>());
      expect(await stored(), ['mine']);
    });

    test('an unavailable picker is an UnavailableError', () async {
      gateway.pickResults.add(const Result.err(UnavailableError('none')));
      final result = await preview();
      expect((result as Err<PreviewedBackup?>).error, isA<UnavailableError>());
    });

    test('a BOM at the start of the file is tolerated', () async {
      gateway.queuePick('b.json', [
        0xEF,
        0xBB,
        0xBF,
        ...utf8.encode(await backupOf(['x'])),
      ]);
      final result = await preview();
      expect((result as Ok<PreviewedBackup?>).value!.preview.totalRows, 1);
    });
  });

  group('RestoreBackup', () {
    test('after preview and confirmation the data is replaced', () async {
      await _addMeasurement(db, 'old1', 80);
      await _addMeasurement(db, 'old2', 81);
      gateway.queuePick('b.json', utf8.encode(await backupOf(['n1'])));
      final previewed =
          ((await PreviewBackup(repository: repo, gateway: gateway)())
                  as Ok<PreviewedBackup?>)
              .value!;
      expect(await stored(), unorderedEquals(['old1', 'old2']));

      final result = await RestoreBackup(repository: repo)(previewed);

      final summary = (result as Ok<BackupSummary>).value;
      expect(summary.rowCounts['measurements'], 1);
      expect(await stored(), ['n1']);
    });

    test('a failing restore changes nothing', () async {
      await _addMeasurement(db, 'old', 80);
      // Passes the envelope check, fails on the second row.
      final broken = jsonEncode({
        'app': 'repforge',
        'formatVersion': 2,
        'tables': {
          'measurements': [
            {
              'id': 'n1',
              'site': 'waist',
              'value': 90.0,
              'recorded_at': '2026-11-01T00:00:00Z',
              'created_at': '2026-11-01T00:00:00Z',
              'updated_at': '2026-11-01T00:00:00Z',
            },
            {'id': 'n2'},
          ],
        },
      });
      gateway.queuePick('b.json', utf8.encode(broken));
      final previewed =
          ((await PreviewBackup(repository: repo, gateway: gateway)())
                  as Ok<PreviewedBackup?>)
              .value!;

      final result = await RestoreBackup(repository: repo)(previewed);

      expect((result as Err<BackupSummary>).error, isA<StorageError>());
      expect(await stored(), ['old']);
    });
  });
}
