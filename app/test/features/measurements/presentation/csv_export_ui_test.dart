import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/platform/fake_user_file_gateway.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/files/user_file_gateway.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/measurements_csv.dart';

import '../../../helpers/pump.dart';
import 'measurement_harness.dart';

/// Export CSV on the Track home and on a type screen (BCM-009(1), D5, F6).
void main() {
  late AppDatabase db;
  late FakeUserFileGateway gateway;
  setUp(() {
    db = AppDatabase.inMemory();
    gateway = FakeUserFileGateway();
  });
  tearDown(() => db.close());

  List<Measurement> seed() => [
    reading(MeasurementSite.weight, 80.5, DateTime(2026, 11, 1, 8)),
    reading(MeasurementSite.waist, 87.5, DateTime(2026, 11, 3, 8)),
  ];

  /// drift queries need the real event loop (the fake-async test zone never
  /// completes them): wait in real time until [done] holds, pumping frames.
  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 200 && !done(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(done(), isTrue, reason: 'timed out');
  }

  Future<void> tapExport(
    WidgetTester tester, [
    String key = 'export-csv',
  ]) async {
    final button = find.byKey(Key(key));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await waitFor(
      tester,
      () => find.byKey(const Key('export-feedback')).evaluate().isNotEmpty,
    );
    await tester.pumpAndSettle();
  }

  String snack(WidgetTester tester) => tester
      .widget<Text>(
        find.descendant(
          of: find.byKey(const Key('export-feedback')),
          matching: find.byType(Text),
        ),
      )
      .data!;

  group('Track home', () {
    testWidgets('hands the CSV with header and readings to the gateway', (
      tester,
    ) async {
      await pumpTrack(tester, db, seed: seed(), gateway: gateway);
      await tapExport(tester);

      final sent = gateway.exports.single;
      expect(sent.fileName, 'repforge-measurements-2026-11-05.csv');
      expect(sent.mimeType, 'text/csv');
      final lines = sent.text.split('\r\n');
      expect(lines.first, measurementsCsvHeader);
      expect(lines[1], endsWith(',Weight,80.5,kg'));
      expect(lines[2], endsWith(',Waist,87.5,cm'));
      // F6: a destination was chosen; the file is not claimed to be saved.
      expect(snack(tester), 'Export shared with the app you chose.');
      expect(snack(tester).toLowerCase(), isNot(contains('saved')));
      await unmount(tester);
    });

    testWidgets('dismissing the share sheet is neutral', (tester) async {
      gateway.exportResult = const Result.ok(ExportOutcome.dismissed);
      await pumpTrack(tester, db, seed: seed(), gateway: gateway);
      await tapExport(tester);
      expect(snack(tester), 'Share sheet closed.');
      await unmount(tester);
    });

    testWidgets('an unknown result does not claim a save', (tester) async {
      gateway.exportResult = const Result.ok(ExportOutcome.resultUnknown);
      await pumpTrack(tester, db, seed: seed(), gateway: gateway);
      await tapExport(tester);
      expect(
        snack(tester),
        'Export sent to the share sheet. RepForge cannot tell where it went.',
      );
      expect(snack(tester).toLowerCase(), isNot(contains('saved')));
      await unmount(tester);
    });

    testWidgets('no sharing on this device gives a clear message', (
      tester,
    ) async {
      // Default gateway: unavailable.
      await pumpTrack(tester, db, seed: seed());
      await tapExport(tester);
      expect(snack(tester), 'Exporting files is not available on this device.');
      await unmount(tester);
    });

    testWidgets('a failing share is reported', (tester) async {
      gateway.exportResult = const Result.err(UnexpectedError('boom'));
      await pumpTrack(tester, db, seed: seed(), gateway: gateway);
      await tapExport(tester);
      expect(
        snack(tester),
        'Could not open the share sheet. Please try again.',
      );
      await unmount(tester);
    });

    testWidgets('nothing to export: the sheet is not opened', (tester) async {
      await pumpTrack(tester, db, gateway: gateway);
      await tapExport(tester);
      expect(snack(tester), 'Nothing to export.');
      expect(gateway.exports, isEmpty);
      await unmount(tester);
    });

    Future<void> insertUnreadable(
      WidgetTester tester,
      List<(String, String, double)> rows,
    ) => tester.runAsync(() async {
      for (final (id, site, v) in rows) {
        await db
            .into(db.measurements)
            .insert(
              MeasurementsCompanion.insert(
                id: id,
                site: site,
                value: v,
                recordedAt: DateTime.utc(2026, 11, 2),
                createdAt: DateTime.utc(2026, 11, 2),
                updatedAt: DateTime.utc(2026, 11, 2),
              ),
            );
      }
    });

    testWidgets('unreadable readings are counted in the message and left '
        'out of the file', (tester) async {
      await insertUnreadable(tester, [
        ('u1', 'waist', 400.0),
        ('u2', 'weight', 80.05),
      ]);
      await pumpTrack(tester, db, seed: seed(), gateway: gateway);
      await tapExport(tester);
      expect(
        snack(tester),
        'Export shared with the app you chose. '
        '2 unreadable readings were not included.',
      );
      expect(gateway.exports.single.text.split('\r\n'), hasLength(4));
      await unmount(tester);
    });

    testWidgets('only unreadable readings: nothing to export, count shown', (
      tester,
    ) async {
      await insertUnreadable(tester, [('u1', 'waist', 400.0)]);
      await pumpTrack(tester, db, gateway: gateway);
      await tapExport(tester);
      expect(
        snack(tester),
        'Nothing to export. 1 unreadable reading was not included.',
      );
      expect(gateway.exports, isEmpty);
      await unmount(tester);
    });

    testWidgets('the button is busy during the export (one tap, one file)', (
      tester,
    ) async {
      gateway.delay = const Duration(milliseconds: 300);
      await pumpTrack(tester, db, seed: seed(), gateway: gateway);
      final button = find.byKey(const Key('export-csv'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump(const Duration(milliseconds: 100));
      // A second tap while the first export runs does nothing.
      await tester.tap(button, warnIfMissed: false);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await waitFor(
        tester,
        () => find.byKey(const Key('export-feedback')).evaluate().isNotEmpty,
      );
      await tester.pumpAndSettle();
      expect(gateway.exports, hasLength(1));
      await unmount(tester);
    });
  });

  group('type screen', () {
    testWidgets('exports only the current type', (tester) async {
      await pumpTrack(
        tester,
        db,
        location: RfRoutes.trackSite(MeasurementSite.waist),
        seed: [
          ...seed(),
          reading(MeasurementSite.waist, 86.5, DateTime(2026, 11, 4, 8)),
        ],
        gateway: gateway,
      );
      await tapExport(tester, 'export-site-csv');

      final sent = gateway.exports.single;
      expect(sent.fileName, 'repforge-measurements-waist-2026-11-05.csv');
      expect(sent.text, isNot(contains('Weight')));
      expect(sent.text.split('\r\n'), hasLength(4));
      expect(snack(tester), 'Export shared with the app you chose.');
      await unmount(tester);
    });

    testWidgets('a type without readings says there is nothing to export', (
      tester,
    ) async {
      await pumpTrack(
        tester,
        db,
        location: RfRoutes.trackSite(MeasurementSite.neck),
        seed: seed(),
        gateway: gateway,
      );
      await tapExport(tester, 'export-site-csv');
      expect(snack(tester), 'Nothing to export.');
      expect(gateway.exports, isEmpty);
      await unmount(tester);
    });
  });
}
