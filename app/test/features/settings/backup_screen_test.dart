import 'dart:convert';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/platform/fake_user_file_gateway.dart';
import 'package:repforge/data/repositories/drift_backup_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/files/user_file_gateway.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/measurements/application/measurement_providers.dart';

import '../../helpers/pump.dart';
import '../measurements/presentation/measurement_harness.dart';

final _madeAt = DateTime.utc(2026, 10, 30, 9, 15);

/// Backup file text of a database holding measurements [ids] (plus a goal and
/// a setting, so the preview lists several tables).
Future<String> _backupFile(WidgetTester tester, List<String> ids) async {
  final other = AppDatabase.inMemory();
  try {
    return (await tester.runAsync(() async {
      for (final id in ids) {
        await other
            .into(other.measurements)
            .insert(
              MeasurementsCompanion.insert(
                id: id,
                site: 'weight',
                value: 70.5,
                recordedAt: DateTime.utc(2026, 10),
                createdAt: DateTime.utc(2026, 10),
                updatedAt: DateTime.utc(2026, 10),
              ),
            );
      }
      await other
          .into(other.goals)
          .insert(
            GoalsCompanion.insert(
              id: 'g1',
              kind: 'calories',
              target: 2400,
              startDate: DateTime.utc(2026, 10),
              createdAt: DateTime.utc(2026, 10),
              updatedAt: DateTime.utc(2026, 10),
            ),
          );
      await other
          .into(other.settings)
          .insert(
            SettingsCompanion.insert(
              key: 'theme',
              value: 'light',
              updatedAt: DateTime.utc(2026, 10),
            ),
          );
      return await DriftBackupRepository(
        other,
        clock: FixedClock(_madeAt),
      ).exportJson();
    }))!;
  } finally {
    await tester.runAsync(other.close);
  }
}

void main() {
  late AppDatabase db;
  late FakeUserFileGateway gateway;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  setUp(() {
    db = AppDatabase.inMemory();
    gateway = FakeUserFileGateway();
  });
  tearDown(() => db.close());

  /// Real-time wait (drift needs the real event loop) until [done].
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue, reason: 'timed out');
  }

  Finder key(String k) => find.byKey(Key(k));
  bool shown(String k) => key(k).evaluate().isNotEmpty;

  Future<ProviderContainer> open(
    WidgetTester tester, {
    List<Measurement> seed = const [],
    Size size = const Size(390, 1200),
    double scale = 1,
  }) => pumpTrack(
    tester,
    db,
    location: RfRoutes.settingsBackup,
    seed: seed,
    gateway: gateway,
    size: size,
    textScale: scale,
  );

  Measurement mine(String id) =>
      reading(MeasurementSite.weight, 80, DateTime(2026, 11, 1, 8));

  Future<List<String>> ids(WidgetTester tester, ProviderContainer c) async => [
    for (final m in await storedReadings(tester, c)) m.id,
  ];

  String status(WidgetTester tester) =>
      tester.widget<Text>(key('backup-status')).data!;

  /// Taps restore and waits for the preview dialog or a status line.
  Future<void> chooseFile(WidgetTester tester) async {
    await tester.scrollUntilVisible(key('restore-backup'), 200);
    await tester.ensureVisible(key('restore-backup'));
    await tester.pumpAndSettle();
    await tester.tap(key('restore-backup'));
    await waitFor(
      tester,
      () => shown('restore-dialog') || shown('backup-status'),
    );
    await tester.pumpAndSettle();
  }

  group('export', () {
    testWidgets('hands the full JSON backup to the share sheet', (
      tester,
    ) async {
      await open(tester, seed: [mine('a')]);
      await tester.tap(key('export-backup'));
      await waitFor(tester, () => shown('backup-status'));
      await tester.pumpAndSettle();

      final sent = gateway.exports.single;
      expect(sent.fileName, 'repforge-backup-2026-11-05.json');
      expect(sent.mimeType, 'application/json');
      final doc = jsonDecode(sent.text) as Map<String, Object?>;
      expect(doc['app'], 'repforge');
      expect(
        (doc['tables']! as Map<String, Object?>)['measurements']! as List,
        hasLength(1),
      );
      // F6: a destination was chosen, never "saved".
      expect(status(tester), 'Export shared with the app you chose.');
      await unmount(tester);
    });

    for (final (outcome, text) in [
      (ExportOutcome.dismissed, 'Share sheet closed.'),
      (
        ExportOutcome.resultUnknown,
        'Export sent to the share sheet. RepForge cannot tell where it went.',
      ),
    ]) {
      testWidgets('$outcome is neutral and does not claim a save', (
        tester,
      ) async {
        gateway.exportResult = Result.ok(outcome);
        await open(tester);
        await tester.tap(key('export-backup'));
        await waitFor(tester, () => shown('backup-status'));
        expect(status(tester), text);
        expect(status(tester).toLowerCase(), isNot(contains('saved')));
        await unmount(tester);
      });
    }

    testWidgets('no sharing on this device gives a clear message', (
      tester,
    ) async {
      gateway.exportResult = const Result.err(UnavailableError('none'));
      await open(tester);
      await tester.tap(key('export-backup'));
      await waitFor(tester, () => shown('backup-status'));
      expect(
        status(tester),
        'Exporting files is not available on this device.',
      );
      await unmount(tester);
    });
  });

  group('restore', () {
    testWidgets('preview shows the date and the counts and changes nothing '
        'until confirmed; confirming replaces all data', (tester) async {
      final c = await open(tester, seed: [mine('old')]);
      final oldIds = await ids(tester, c);
      // Streams must see the replacement.
      final live = c.listen(allMeasurementsProvider, (_, _) {});
      gateway.queuePick(
        'backup.json',
        utf8.encode(await _backupFile(tester, ['n1', 'n2', 'n3'])),
      );

      await chooseFile(tester);

      expect(shown('restore-dialog'), isTrue);
      expect(
        tester.widget<Text>(key('restore-date')).data,
        'Backup made: '
        '${DateFormat.yMMMd().add_Hm().format(_madeAt.toLocal())}',
      );
      expect(
        find.descendant(
          of: key('restore-count-measurements'),
          matching: find.text('3'),
        ),
        findsOneWidget,
      );
      expect(key('restore-count-goals'), findsOneWidget);
      expect(key('restore-count-settings'), findsOneWidget);
      expect(find.text('File: backup.json'), findsOneWidget);
      expect(find.text('Records in this backup (5):'), findsOneWidget);
      expect(
        tester.widget<Text>(key('restore-warning')).data,
        contains('replaces'),
      );
      // The picker asked for JSON.
      expect(gateway.picks.single.extensions, isEmpty);
      // Nothing changed while the dialog is open.
      expect(await ids(tester, c), oldIds);

      await tester.tap(key('restore-confirm'));
      await waitFor(tester, () => shown('backup-status'));
      await tester.pumpAndSettle();

      expect(status(tester), startsWith('Restored 5 records from the backup.'));
      expect((await ids(tester, c))..sort(), ['n1', 'n2', 'n3']);
      expect(oldIds, isNot(contains('n1')));
      // The live stream saw the replacement too.
      await waitFor(
        tester,
        () => live.read().value?.map((m) => m.id).toSet().length == 3,
      );
      live.close();
      await unmount(tester);
    });

    testWidgets('cancelling the confirmation leaves the data unchanged', (
      tester,
    ) async {
      final c = await open(tester, seed: [mine('old')]);
      final before = await ids(tester, c);
      gateway.queuePick(
        'backup.json',
        utf8.encode(await _backupFile(tester, ['n1'])),
      );
      await chooseFile(tester);
      await tester.tap(key('restore-cancel'));
      await tester.pumpAndSettle();

      expect(shown('restore-dialog'), isFalse);
      expect(status(tester), 'Restore cancelled. Nothing was changed.');
      expect(await ids(tester, c), before);
      await unmount(tester);
    });

    testWidgets('dismissing the dialog (barrier) is not a confirmation', (
      tester,
    ) async {
      final c = await open(tester, seed: [mine('old')]);
      final before = await ids(tester, c);
      gateway.queuePick(
        'backup.json',
        utf8.encode(await _backupFile(tester, ['n1'])),
      );
      await chooseFile(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(shown('restore-dialog'), isFalse);
      expect(await ids(tester, c), before);
      await unmount(tester);
    });

    testWidgets('cancelling the file picker changes nothing', (tester) async {
      final c = await open(tester, seed: [mine('old')]);
      final before = await ids(tester, c);
      await chooseFile(tester); // the fake answers Ok(null)
      expect(shown('restore-dialog'), isFalse);
      expect(status(tester), 'No file was chosen. Nothing was changed.');
      expect(await ids(tester, c), before);
      await unmount(tester);
    });

    final rejected = <String, (List<int>, String)>{
      'invalid JSON': (utf8.encode('{not json'), 'Backup is not valid JSON.'),
      'corrupt (not text)': ([0xFF, 0xFE, 0x41], 'not a RepForge backup'),
      'another JSON file': (
        utf8.encode('{"hello": 1}'),
        'This file is not a RepForge backup.',
      ),
      'newer format version': (
        utf8.encode(
          jsonEncode({
            'app': 'repforge',
            'formatVersion': 99,
            'tables': <String, Object?>{},
          }),
        ),
        'made by a newer version of RepForge',
      ),
      'no records': (
        utf8.encode(
          jsonEncode({
            'app': 'repforge',
            'formatVersion': 2,
            'tables': <String, Object?>{},
          }),
        ),
        'This backup contains no records.',
      ),
      'missing tables': (
        utf8.encode(jsonEncode({'app': 'repforge', 'formatVersion': 2})),
        'Backup has no tables.',
      ),
    };
    for (final MapEntry(key: name, value: (bytes, text)) in rejected.entries) {
      testWidgets('$name is rejected with a message and no change', (
        tester,
      ) async {
        final c = await open(tester, seed: [mine('old')]);
        final before = await ids(tester, c);
        gateway.queuePick('bad.json', bytes);

        await chooseFile(tester);

        expect(shown('restore-dialog'), isFalse, reason: 'no confirmation');
        expect(status(tester), contains(text));
        expect(status(tester), endsWith('Nothing was changed.'));
        expect(await ids(tester, c), before);
        await unmount(tester);
      });
    }

    testWidgets('an oversized file (FileTooLargeError) is rejected', (
      tester,
    ) async {
      final c = await open(tester, seed: [mine('old')]);
      final before = await ids(tester, c);
      gateway.pickResults.add(
        const Result.err(FileTooLargeError('big', maxBytes: 50 * 1024 * 1024)),
      );
      await chooseFile(tester);
      expect(
        status(tester),
        'That file is too large to be a backup (the limit is 50 MB). '
        'Nothing was changed.',
      );
      expect(await ids(tester, c), before);
      await unmount(tester);
    });

    testWidgets('no file chooser on this device gives a clear message', (
      tester,
    ) async {
      gateway.pickResults.add(const Result.err(UnavailableError('none')));
      await open(tester);
      await chooseFile(tester);
      expect(
        status(tester),
        'Choosing a file is not available on this device. '
        'Nothing was changed.',
      );
      await unmount(tester);
    });
  });

  group('layout', () {
    final configs = <String, (Size, double)>{
      '320 dp wide': (const Size(320, 640), 1),
      '360x690 at 1.3': (const Size(360, 690), 1.3),
      '360x690 at 2.0': (const Size(360, 690), 2),
    };
    for (final MapEntry(key: name, value: (size, scale)) in configs.entries) {
      testWidgets('screen, status and confirmation fit at $name', (
        tester,
      ) async {
        await open(tester, size: size, scale: scale);
        expect(tester.takeException(), isNull);
        gateway.queuePick(
          'a-rather-long-backup-file-name-2026-10-30.json',
          utf8.encode(await _backupFile(tester, ['n1', 'n2'])),
        );
        await chooseFile(tester);
        expect(tester.takeException(), isNull);
        // The confirm button can be reached (the content scrolls).
        await tester.ensureVisible(key('restore-confirm'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        WidgetController.hitTestWarningShouldBeFatal = true;
        addTearDown(() => WidgetController.hitTestWarningShouldBeFatal = false);
        await tester.tap(key('restore-cancel'));
        await tester.pumpAndSettle();
        expect(status(tester), contains('cancelled'));
        // A long error status wraps without overflow.
        gateway.pickResults.add(
          const Result.err(
            FileTooLargeError('big', maxBytes: 50 * 1024 * 1024),
          ),
        );
        await chooseFile(tester);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      });
    }
  });

  testWidgets('Settings leads to the backup screen and back', (tester) async {
    await pumpTrack(
      tester,
      db,
      location: RfRoutes.settings,
      gateway: gateway,
      size: const Size(390, 3600),
    );
    await tester.ensureVisible(key('open-backup'));
    await tester.tap(key('open-backup'));
    await tester.pumpAndSettle();
    expect(key('export-backup'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(key('open-backup'), findsOneWidget);
    await unmount(tester);
  });
}
