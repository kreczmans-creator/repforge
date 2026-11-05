import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/measurements/measurements.dart';

import '../../../helpers/pump.dart';
import 'measurement_harness.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  String summary(WidgetTester t) =>
      t.widget<Text>(find.byKey(const Key('chart-summary'))).data!;

  testWidgets('empty history shows the empty state and an empty chart', (
    tester,
  ) async {
    await pumpTrack(
      tester,
      db,
      location: RfRoutes.trackSite(MeasurementSite.waist),
    );
    expect(find.byKey(const Key('site-empty')), findsOneWidget);
    expect(find.text('No readings in this period.'), findsOneWidget);
    expect(summary(tester), contains('no readings'));
    await unmount(tester);
  });

  testWidgets('history is newest first and works offline from the database', (
    tester,
  ) async {
    final a = reading(MeasurementSite.waist, 90, DateTime(2026, 10, 20, 8));
    final b = reading(MeasurementSite.waist, 89, DateTime(2026, 10, 28, 8));
    final c = reading(MeasurementSite.waist, 88, DateTime(2026, 11, 3, 8));
    await pumpTrack(
      tester,
      db,
      location: RfRoutes.trackSite(MeasurementSite.waist),
      seed: [a, c, b],
    );
    double y(Measurement m) =>
        tester.getTopLeft(find.byKey(Key('reading-${m.id}'))).dy;
    expect(y(c), lessThan(y(b)));
    expect(y(b), lessThan(y(a)));
    await unmount(tester);
  });

  testWidgets('editing updates the list, the chart summary and the data table '
      'at once', (tester) async {
    final a = reading(MeasurementSite.waist, 90, DateTime(2026, 10, 28, 8));
    final b = reading(MeasurementSite.waist, 88, DateTime(2026, 11, 3, 8));
    await pumpTrack(
      tester,
      db,
      location: RfRoutes.trackSite(MeasurementSite.waist),
      seed: [a, b],
    );
    expect(summary(tester), contains('latest 88.0 cm'));

    await tester.tap(find.byKey(Key('edit-${b.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('edit-value')),
        matching: find.byType(TextField),
      ),
      '5',
    );
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();
    // Invalid: the sheet stays open with the message next to the field.
    expect(find.text('Enter a value from 10.0 to 300.0 cm.'), findsOneWidget);

    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('edit-value')),
        matching: find.byType(TextField),
      ),
      '87.5',
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const Key('edit-note')),
        matching: find.byType(TextField),
      ),
      'after run',
    );
    await tester.tap(find.byKey(const Key('edit-save')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('edit-save')), findsNothing);
    expect(find.text('87.5 cm'), findsOneWidget);
    expect(find.text('88.0 cm'), findsNothing);
    expect(find.text('after run'), findsOneWidget);
    expect(summary(tester), contains('latest 87.5 cm'));
    await unmount(tester);
  });

  testWidgets('delete asks first; cancel keeps the reading, confirm removes it '
      'and the chart follows', (tester) async {
    final a = reading(MeasurementSite.waist, 90, DateTime(2026, 10, 28, 8));
    final b = reading(MeasurementSite.waist, 88, DateTime(2026, 11, 3, 8));
    await pumpTrack(
      tester,
      db,
      location: RfRoutes.trackSite(MeasurementSite.waist),
      seed: [a, b],
    );
    expect(summary(tester), contains('2 readings'));

    await tester.tap(find.byKey(Key('delete-${b.id}')));
    await tester.pumpAndSettle();
    expect(find.text('Delete this reading?'), findsOneWidget);
    await tester.tap(find.byKey(const Key('delete-cancel')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('reading-${b.id}')), findsOneWidget);

    await tester.tap(find.byKey(Key('delete-${b.id}')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete-confirm')));
    await tester.pumpAndSettle();
    expect(find.byKey(Key('reading-${b.id}')), findsNothing);
    expect(summary(tester), contains('1 reading,'));
    expect(summary(tester), contains('latest 90.0 cm'));
    await unmount(tester);
  });

  testWidgets('the range selector filters the chart to the period', (
    tester,
  ) async {
    final old = reading(MeasurementSite.waist, 95, DateTime(2026, 5, 1, 8));
    final mid = reading(MeasurementSite.waist, 92, DateTime(2026, 9, 20, 8));
    final recent = reading(MeasurementSite.waist, 90, DateTime(2026, 11, 3, 8));
    await pumpTrack(
      tester,
      db,
      location: RfRoutes.trackSite(MeasurementSite.waist),
      seed: [old, mid, recent],
    );
    // Default 12 weeks: 2026-08-13 .. 2026-11-05 holds mid and recent.
    expect(summary(tester), contains('last 12 weeks: 2 readings'));
    await tester.tap(find.byKey(const Key('period-weeks4')));
    await tester.pumpAndSettle();
    expect(summary(tester), contains('last 4 weeks: 1 reading,'));
    await tester.tap(find.byKey(const Key('period-year1')));
    await tester.pumpAndSettle();
    expect(summary(tester), contains('last 1 year: 3 readings'));
    await tester.tap(find.byKey(const Key('period-all')));
    await tester.pumpAndSettle();
    expect(summary(tester), contains('all time: 3 readings'));
    // The history list is not limited by the chart period.
    expect(find.byKey(Key('reading-${old.id}')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a left/right site shows both sides as labelled series and a '
      'screen-reader data table', (tester) async {
    final handle = tester.ensureSemantics();
    final t = DateTime(2026, 11, 3, 8);
    await pumpTrack(
      tester,
      db,
      location: RfRoutes.trackSite(MeasurementSite.thighLeft),
      seed: [
        reading(MeasurementSite.thighLeft, 55, t),
        reading(MeasurementSite.thighRight, 54.5, t),
        reading(MeasurementSite.thighLeft, 55.5, DateTime(2026, 11, 4, 8)),
      ],
    );
    // Legend names both series; the summary describes each side.
    expect(find.text('Left thigh'), findsWidgets);
    expect(find.text('Right thigh'), findsWidgets);
    expect(summary(tester), contains('Left thigh, last 12 weeks: 2 readings'));
    expect(summary(tester), contains('Right thigh, last 12 weeks: 1 reading'));
    // The chart itself announces its series.
    expect(
      find.bySemanticsLabel(RegExp('Series: Left thigh, Right thigh')),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('chart-data-table')));
    await tester.pumpAndSettle();
    // One semantics node per row, reading date, then each series.
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Nov 3, 2026 08:00\. Left thigh: 55\.0 cm\. Right thigh: 54\.5 cm',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'Nov 4, 2026 08:00\. Left thigh: 55\.5 cm\. Right thigh: no reading',
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp('Date, Left thigh, Right thigh, values in cm'),
      ),
      findsOneWidget,
    );
    handle.dispose();
    await unmount(tester);
  });

  testWidgets('weight: no trend with fewer than three readings, trend from '
      'three (D1)', (tester) async {
    final c = await pumpTrack(
      tester,
      db,
      location: RfRoutes.trackSite(MeasurementSite.weight),
      seed: [
        reading(MeasurementSite.weight, 80, DateTime(2026, 11, 3, 8)),
        reading(MeasurementSite.weight, 81, DateTime(2026, 11, 4, 8)),
      ],
    );
    expect(summary(tester), contains('No 7-day trend'));
    expect(summary(tester), isNot(contains('proposed')));

    await realAsync(
      tester,
      () => c.read(recordMeasurementEntryProvider)(
        values: {MeasurementSite.weight: '82.0'},
        recordedAt: DateTime(2026, 11, 5, 8),
      ),
    );
    await tester.pumpAndSettle();
    // Mean of the three daily means: (80 + 81 + 82) / 3 = 81.0.
    expect(summary(tester), contains('7-day trend, latest 81.0 kg'));
    expect(find.text('7-day trend'), findsWidgets); // legend entry
    expect(find.text('Weight readings'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('an unknown type shows a message instead of crashing', (
    tester,
  ) async {
    await pumpTrack(tester, db, location: '/track/site/nonsense');
    expect(find.byKey(const Key('site-unknown')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('edit and delete buttons are at least 48 dp', (tester) async {
    final a = reading(MeasurementSite.waist, 90, DateTime(2026, 10, 28, 8));
    await pumpTrack(
      tester,
      db,
      location: RfRoutes.trackSite(MeasurementSite.waist),
      seed: [a],
    );
    for (final k in ['edit-${a.id}', 'delete-${a.id}']) {
      final size = tester.getSize(find.byKey(Key(k)));
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    await unmount(tester);
  });
}
