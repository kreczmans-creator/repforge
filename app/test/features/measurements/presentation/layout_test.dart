import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/measurements/measurements.dart';

import '../../../helpers/pump.dart';
import 'measurement_harness.dart';

/// No overflow at 320 dp wide and at 360x690 with text scale 1.3.
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  List<Measurement> seed() => [
    for (var i = 0; i < 12; i++)
      reading(
        MeasurementSite.weight,
        80.0 + i * 0.1,
        DateTime(2026, 10, 20 + i % 14, 8),
      ),
    for (var i = 0; i < 6; i++) ...[
      reading(
        MeasurementSite.thighLeft,
        55.0 + i,
        DateTime(2026, 10, 1 + i * 5, 8),
      ),
      reading(
        MeasurementSite.thighRight,
        54.0 + i,
        DateTime(2026, 10, 1 + i * 5, 8),
      ),
      reading(
        MeasurementSite.waist,
        90.0 - i * 0.5,
        DateTime(2026, 10, 1 + i * 5, 8),
      ),
    ],
  ];

  final screens = <String, String>{
    'track home': RfRoutes.track,
    'entry': RfRoutes.trackEntry,
    'weight history and chart': RfRoutes.trackSite(MeasurementSite.weight),
    'bilateral history and chart': RfRoutes.trackSite(
      MeasurementSite.thighLeft,
    ),
    'progress': RfRoutes.trackProgress,
    'compare dates': '/track/compare?site=waist&a=2026-10-02&b=2026-11-01',
    'compare periods':
        '/track/compare?site=waist&mode=periods'
        '&a1=2026-10-01&a2=2026-10-15&b1=2026-10-16&b2=2026-11-05',
  };
  final configs = <String, (Size, double)>{
    '320 dp wide': (const Size(320, 640), 1),
    '360x690 at 1.3 text scale': (const Size(360, 690), 1.3),
  };

  for (final MapEntry(key: config, value: (size, scale)) in configs.entries) {
    for (final MapEntry(key: name, value: location) in screens.entries) {
      testWidgets('$name has no overflow at $config', (tester) async {
        await pumpTrack(
          tester,
          db,
          location: location,
          seed: seed(),
          size: size,
          textScale: scale,
        );
        expect(tester.takeException(), isNull);
        await scrollThrough(tester);
        await unmount(tester);
      });
    }
  }

  // UXD-005(2): text scale 2.0.
  for (final MapEntry(key: name, value: location) in {
    'entry': RfRoutes.trackEntry,
    'weight history and chart': RfRoutes.trackSite(MeasurementSite.weight),
    'bilateral history and chart': RfRoutes.trackSite(
      MeasurementSite.thighLeft,
    ),
  }.entries) {
    testWidgets('$name has no overflow at text scale 2.0', (tester) async {
      await pumpTrack(
        tester,
        db,
        location: location,
        seed: seed(),
        size: const Size(360, 690),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      await scrollThrough(tester);
      await unmount(tester);
    });
  }

  testWidgets('the chart data table has no overflow at 320 dp and 1.3 scale', (
    tester,
  ) async {
    await pumpTrack(
      tester,
      db,
      location: RfRoutes.trackSite(MeasurementSite.thighLeft),
      seed: seed(),
      size: const Size(320, 640),
      textScale: 1.3,
    );
    await tester.ensureVisible(find.byKey(const Key('chart-data-table')));
    await tester.tap(find.byKey(const Key('chart-data-table')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await scrollThrough(tester);
    await unmount(tester);
  });

  testWidgets('the edit sheet and delete dialog fit at 320 dp and 1.3 scale', (
    tester,
  ) async {
    final m = reading(MeasurementSite.waist, 90, DateTime(2026, 11, 3, 8));
    await pumpTrack(
      tester,
      db,
      location: RfRoutes.trackSite(MeasurementSite.waist),
      seed: [m],
      size: const Size(320, 640),
      textScale: 1.3,
    );
    await tester.scrollUntilVisible(find.byKey(Key('edit-${m.id}')), 300);
    await tester.ensureVisible(find.byKey(Key('edit-${m.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('edit-${m.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Edit Waist'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const Key('edit-cancel')));
    await tester.tap(find.byKey(const Key('edit-cancel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(Key('delete-${m.id}')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.byKey(const Key('delete-cancel')));
    await tester.pumpAndSettle();
    await unmount(tester);
  });
}
