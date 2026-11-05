import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/measurements/measurements.dart';

import '../../../helpers/pump.dart';
import 'measurement_harness.dart';

/// Stage 2 review items carried to stage 3b: N3 (keyboard Next) and N4 (the
/// focused field's error under a tall summary).
void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  Finder input(MeasurementSite s) => find.descendant(
    of: find.byKey(Key('field-${s.name}')),
    matching: find.byType(TextField),
  );

  group('N3: keyboard Next', () {
    testWidgets('moves to the next field, never to an info button, and ends '
        'in the note', (tester) async {
      await pumpTrack(
        tester,
        db,
        location: RfRoutes.trackEntry,
        size: const Size(360, 690),
      );
      const order = [
        MeasurementSite.weight,
        MeasurementSite.neck,
        MeasurementSite.chest,
        MeasurementSite.waist,
        MeasurementSite.hips,
        MeasurementSite.thighLeft,
        MeasurementSite.thighRight,
        MeasurementSite.calfLeft,
        MeasurementSite.calfRight,
        MeasurementSite.bicepsLeft,
        MeasurementSite.bicepsRight,
        MeasurementSite.forearmLeft,
        MeasurementSite.forearmRight,
      ];
      await tester.tap(input(order.first));
      await tester.pump();
      for (var i = 0; i < order.length - 1; i++) {
        expect(
          tester.widget<TextField>(input(order[i])).focusNode!.hasFocus,
          isTrue,
          reason: '${order[i].name} focused',
        );
        await tester.testTextInput.receiveAction(TextInputAction.next);
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(input(order[i + 1])).focusNode!.hasFocus,
          isTrue,
          reason: 'Next from ${order[i].name} reaches ${order[i + 1].name}',
        );
      }
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byKey(const Key('note-input')),
                matching: find.byType(TextField),
              ),
            )
            .focusNode
            ?.hasFocus,
        isTrue,
      );
      await unmount(tester);
    });

    testWidgets('the info buttons stay reachable by tap', (tester) async {
      await pumpTrack(tester, db, location: RfRoutes.trackEntry);
      await tester.tap(find.byKey(const Key('info-neck')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('help-neck')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('N4: error of the focused field at text scale 2.0 with keyboard', () {
    testWidgets('stays visible above the summary and Save', (tester) async {
      await pumpTrack(
        tester,
        db,
        location: RfRoutes.trackEntry,
        size: const Size(360, 690),
        textScale: 2,
      );
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      // Several errors make the summary long.
      for (final s in [
        MeasurementSite.weight,
        MeasurementSite.neck,
        MeasurementSite.chest,
        MeasurementSite.waist,
      ]) {
        await tester.ensureVisible(input(s));
        await tester.enterText(input(s), '5');
      }
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('save-measurements')));
      await tester.pumpAndSettle();

      final focused = [
        for (final s in MeasurementSite.values)
          if (tester.widget<TextField>(input(s)).focusNode!.hasFocus) s,
      ];
      expect(focused, [MeasurementSite.weight]);
      final error = find.text('Enter a value from 20.0 to 500.0 kg.');
      expect(error, findsOneWidget);
      final errorRect = tester.getRect(error);
      final summaryTop = tester
          .getRect(find.byKey(const Key('entry-error')))
          .top;
      final appBarBottom = tester.getRect(find.byType(AppBar)).bottom;
      expect(errorRect.bottom, lessThanOrEqualTo(summaryTop));
      expect(errorRect.top, greaterThanOrEqualTo(appBarBottom));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  });
}
