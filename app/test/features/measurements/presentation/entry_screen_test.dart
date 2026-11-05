import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/measurements/measurement_site_help.dart';
import 'package:repforge/domain/measurements/measurements.dart';

import '../../../helpers/pump.dart';
import 'measurement_harness.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  Future<void> type(WidgetTester t, MeasurementSite s, String text) =>
      t.enterText(
        find.descendant(
          of: find.byKey(Key('field-${s.name}')),
          matching: find.byType(TextField),
        ),
        text,
      );

  testWidgets('any subset is saved; blank fields store nothing', (
    tester,
  ) async {
    final c = await pumpTrack(tester, db, location: RfRoutes.trackEntry);
    await type(tester, MeasurementSite.weight, '80.1');
    await type(tester, MeasurementSite.waist, '85,5');
    await type(tester, MeasurementSite.thighLeft, '55.0');
    await tester.enterText(find.byKey(const Key('note-input')), 'morning');
    await tester.tap(find.byKey(const Key('save-measurements')));
    await tester.pumpAndSettle();

    final rows = await storedReadings(tester, c);
    expect(rows.map((m) => m.site).toSet(), {
      MeasurementSite.weight,
      MeasurementSite.waist,
      MeasurementSite.thighLeft,
    });
    expect(rows.every((m) => m.note == 'morning'), isTrue);
    // The right thigh was left blank: no row, not even a zero.
    expect(rows.where((m) => m.site == MeasurementSite.thighRight), isEmpty);
    expect(find.text('Saved 3 measurements'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('all field errors show next to their fields; nothing saved', (
    tester,
  ) async {
    final c = await pumpTrack(tester, db, location: RfRoutes.trackEntry);
    await type(tester, MeasurementSite.weight, '12');
    await type(tester, MeasurementSite.waist, '5');
    await type(tester, MeasurementSite.neck, '40.05');
    await tester.tap(find.byKey(const Key('save-measurements')));
    await tester.pumpAndSettle();

    String errorOf(MeasurementSite s) {
      final tf = tester.widget<TextField>(
        find.descendant(
          of: find.byKey(Key('field-${s.name}')),
          matching: find.byType(TextField),
        ),
      );
      return tf.decoration!.errorText!;
    }

    expect(
      errorOf(MeasurementSite.weight),
      'Enter a value from 20.0 to 500.0 kg.',
    );
    expect(
      errorOf(MeasurementSite.waist),
      'Enter a value from 10.0 to 300.0 cm.',
    );
    expect(errorOf(MeasurementSite.neck), 'Use steps of 0.1 cm.');
    // No message repeats a field label (review N3).
    for (final s in [
      MeasurementSite.weight,
      MeasurementSite.waist,
      MeasurementSite.neck,
    ]) {
      expect(errorOf(s).toLowerCase(), isNot(contains(s.label.toLowerCase())));
    }
    expect(await storedReadings(tester, c), isEmpty);
    // Fixing a field clears only its own error.
    await type(tester, MeasurementSite.neck, '40.5');
    await tester.pump();
    expect(find.text('Use steps of 0.1 cm.'), findsNothing);
    expect(find.text('Enter a value from 10.0 to 300.0 cm.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('saving with every field blank asks for a measurement', (
    tester,
  ) async {
    await pumpTrack(tester, db, location: RfRoutes.trackEntry);
    await tester.tap(find.byKey(const Key('save-measurements')));
    await tester.pumpAndSettle();
    expect(find.text('Enter at least one measurement.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('date and time default to now; the future cannot be picked', (
    tester,
  ) async {
    await pumpTrack(tester, db, location: RfRoutes.trackEntry);
    expect(find.text('Date: Nov 5, 2026'), findsOneWidget);
    expect(find.text('Time: 14:30'), findsOneWidget);

    await tester.tap(find.byKey(const Key('pick-date')));
    await tester.pumpAndSettle();
    // Tomorrow (6th) is disabled: tapping it and confirming keeps today.
    await tester.tap(find.text('6'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Date: Nov 5, 2026'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a back-dated entry defaults to 12:00 and is stored so', (
    tester,
  ) async {
    final c = await pumpTrack(tester, db, location: RfRoutes.trackEntry);
    await tester.tap(find.byKey(const Key('pick-date')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Date: Nov 3, 2026'), findsOneWidget);
    expect(find.text('Time: 12:00'), findsOneWidget);

    await type(tester, MeasurementSite.weight, '81.0');
    await tester.tap(find.byKey(const Key('save-measurements')));
    await tester.pumpAndSettle();
    final rows = await storedReadings(tester, c);
    expect(rows.single.recordedAt.toLocal(), DateTime(2026, 11, 3, 12));
    await unmount(tester);
  });

  testWidgets('a time in the future is rejected next to the date and time', (
    tester,
  ) async {
    final clock = MovableClock(testNow);
    final c = await pumpTrack(
      tester,
      db,
      location: RfRoutes.trackEntry,
      clock: clock,
    );
    await type(tester, MeasurementSite.weight, '80.0');
    // The default time is 14:30; the clock is now an hour earlier.
    clock.value = DateTime(2026, 11, 5, 13, 30);
    await tester.tap(find.byKey(const Key('save-measurements')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('when-error')), findsOneWidget);
    expect(
      find.text('The date and time cannot be in the future.'),
      findsOneWidget,
    );
    expect(await storedReadings(tester, c), isEmpty);
    await unmount(tester);
  });

  testWidgets('every site has an info affordance showing its help text', (
    tester,
  ) async {
    await pumpTrack(tester, db, location: RfRoutes.trackEntry);
    expect(find.byKey(const Key('help-waist')), findsNothing);
    await tester.tap(find.byKey(const Key('info-waist')));
    await tester.pump();
    expect(find.text(MeasurementSite.waist.helpText), findsOneWidget);
    expect(find.textContaining('navel'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('info-waist'))).shortestSide,
      greaterThanOrEqualTo(48),
    );
    await tester.tap(find.byKey(const Key('info-waist')));
    await tester.pump();
    expect(find.byKey(const Key('help-waist')), findsNothing);
    for (final s in MeasurementSite.values) {
      expect(find.byKey(Key('info-${s.name}')), findsOneWidget, reason: s.name);
    }
    await unmount(tester);
  });

  testWidgets('number fields use a decimal keyboard; limbs have own fields', (
    tester,
  ) async {
    final c = await pumpTrack(tester, db, location: RfRoutes.trackEntry);
    final tf = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('field-waist')),
        matching: find.byType(TextField),
      ),
    );
    expect(
      tf.keyboardType,
      const TextInputType.numberWithOptions(decimal: true),
    );
    // Left and right are separate fields (BCM-003): one side alone stores
    // one row.
    await type(tester, MeasurementSite.calfRight, '38.0');
    await tester.tap(find.byKey(const Key('save-measurements')));
    await tester.pumpAndSettle();
    expect((await storedReadings(tester, c)).map((m) => m.site), [
      MeasurementSite.calfRight,
    ]);
    await unmount(tester);
  });
}
