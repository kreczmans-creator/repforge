import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/measurements/measurements.dart';

import '../../../helpers/pump.dart';
import 'measurement_harness.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  Future<void> insertRaw(
    WidgetTester tester,
    String id,
    String site,
    double value,
    DateTime at,
  ) => realAsync(
    tester,
    () => db
        .into(db.measurements)
        .insert(
          MeasurementsCompanion.insert(
            id: id,
            site: site,
            value: value,
            recordedAt: at.toUtc(),
            createdAt: at.toUtc(),
            updatedAt: at.toUtc(),
          ),
        ),
  );

  group('Track home', () {
    testWidgets('lists all 13 types, empty state when nothing is logged', (
      tester,
    ) async {
      await pumpTrack(tester, db);
      expect(find.byKey(const Key('measurements-empty')), findsOneWidget);
      for (final s in MeasurementSite.values) {
        expect(find.byKey(Key('site-${s.name}')), findsOneWidget);
      }
      expect(find.text('No readings yet'), findsNWidgets(13));
      expect(find.byKey(const Key('unreadable-notice')), findsNothing);
      await unmount(tester);
    });

    testWidgets('shows the latest value and date per type and opens history', (
      tester,
    ) async {
      await pumpTrack(
        tester,
        db,
        seed: [
          reading(MeasurementSite.waist, 90, DateTime(2026, 10, 1, 8)),
          reading(MeasurementSite.waist, 88.5, DateTime(2026, 11, 3, 8)),
          reading(MeasurementSite.weight, 80.4, DateTime(2026, 11, 4, 7)),
        ],
      );
      expect(find.text('88.5 cm · Nov 3, 2026'), findsOneWidget);
      expect(find.text('80.4 kg · Nov 4, 2026'), findsOneWidget);
      expect(find.byKey(const Key('measurements-empty')), findsNothing);
      await tester.tap(find.byKey(const Key('site-waist')));
      await tester.pumpAndSettle();
      expect(find.text('Waist'), findsWidgets);
      expect(find.byKey(const Key('chart-summary')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('entry, progress and compare are reachable', (tester) async {
      await pumpTrack(tester, db);
      await tester.tap(find.byKey(const Key('add-measurements')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('save-measurements')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-progress')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('progress-empty')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('open-compare')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('compare-site-picker')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('unreadable stored rows: notice, raw list, confirmed delete', (
      tester,
    ) async {
      final t = DateTime(2026, 11, 2, 9);
      await pumpTrack(
        tester,
        db,
        seed: [reading(MeasurementSite.waist, 90, t)],
      );
      expect(find.byKey(const Key('unreadable-notice')), findsNothing);
      await insertRaw(tester, 'bad1', 'waist', 5, t);
      await insertRaw(tester, 'bad2', 'wrist', 17, t);
      await tester.pumpAndSettle();
      expect(find.text('2 stored readings cannot be shown'), findsOneWidget);
      // The readable waist reading is still listed.
      expect(find.text('90.0 cm · Nov 2, 2026'), findsOneWidget);

      await tester.tap(find.byKey(const Key('open-unreadable')));
      await tester.pumpAndSettle();
      // Raw value, stored site and date, exactly as stored.
      expect(find.text('Value 5.0'), findsOneWidget);
      expect(find.text('Type: waist'), findsOneWidget);
      expect(find.text('Value 17.0'), findsOneWidget);
      expect(find.text('Type: wrist'), findsOneWidget);
      expect(find.text('Nov 2, 2026 09:00'), findsNWidgets(2));
      // No edit action exists for them.
      expect(find.byIcon(Icons.edit_outlined), findsNothing);

      await tester.tap(find.byKey(const Key('delete-bad1')));
      await tester.pumpAndSettle();
      expect(find.text('Delete this reading?'), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete-cancel')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('unreadable-bad1')), findsOneWidget);
      await tester.tap(find.byKey(const Key('delete-bad1')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('unreadable-bad1')), findsNothing);
      expect(find.byKey(const Key('unreadable-bad2')), findsOneWidget);

      await tester.tap(find.byKey(const Key('delete-bad2')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('delete-confirm')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('unreadable-empty')), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('unreadable-notice')), findsNothing);
      await unmount(tester);
    });

    testWidgets('the notice uses the singular for one row', (tester) async {
      await pumpTrack(tester, db);
      await insertRaw(tester, 'bad1', 'waist', 5, DateTime(2026, 11, 2, 9));
      await tester.pumpAndSettle();
      expect(find.text('1 stored reading cannot be shown'), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Comparison (BCM-007, D4)', () {
    final december = FixedClock(DateTime(2026, 12, 15, 9));

    testWidgets('D04 example: waist 90.0 then 87.5 shows -2.5 cm and -2.8 %', (
      tester,
    ) async {
      await pumpTrack(
        tester,
        db,
        location: '/track/compare?site=waist&a=2026-11-01&b=2026-12-01',
        clock: december,
        seed: [
          reading(MeasurementSite.waist, 90, DateTime(2026, 11, 1, 8)),
          reading(MeasurementSite.waist, 87.5, DateTime(2026, 12, 1, 8)),
        ],
      );
      expect(find.byKey(const Key('outcome-value-first')), findsOneWidget);
      expect(find.text('90.0 cm'), findsOneWidget);
      expect(find.text('87.5 cm'), findsOneWidget);
      expect(find.text('−2.5 cm'), findsOneWidget);
      expect(find.text('−2.8 %'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a rise shows plus signs; the earlier date is the base', (
      tester,
    ) async {
      await pumpTrack(
        tester,
        db,
        // Dates given in reverse order.
        location: '/track/compare?site=waist&a=2026-12-01&b=2026-11-01',
        clock: december,
        seed: [
          reading(MeasurementSite.waist, 80, DateTime(2026, 11, 1, 8)),
          reading(MeasurementSite.waist, 84, DateTime(2026, 12, 1, 8)),
        ],
      );
      expect(find.text('+4.0 cm'), findsOneWidget);
      expect(find.text('+5.0 %'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets(
      'a date without a reading needs a choice; no change before it',
      (tester) async {
        await pumpTrack(
          tester,
          db,
          location: '/track/compare?site=waist&a=2026-11-01&b=2026-11-03',
          seed: [
            reading(MeasurementSite.waist, 90, DateTime(2026, 10, 28, 8)),
            reading(MeasurementSite.waist, 86, DateTime(2026, 11, 2, 18)),
            reading(MeasurementSite.waist, 88, DateTime(2026, 11, 3, 8)),
          ],
        );
        // 1 Nov has none: both neighbours with their actual dates, unchosen.
        expect(
          find.byKey(const Key('outcome-needs-choice-first')),
          findsOneWidget,
        );
        expect(
          find.text('Earlier: 90.0 cm on Oct 28, 2026 08:00'),
          findsOneWidget,
        );
        expect(
          find.text('Later: 86.0 cm on Nov 2, 2026 18:00'),
          findsOneWidget,
        );
        expect(find.byKey(const Key('compare-change')), findsNothing);
        expect(find.byKey(const Key('compare-choose-prompt')), findsOneWidget);
        expect(find.textContaining('%'), findsNothing);

        await tester.tap(find.byKey(const Key('choice-first-before')));
        await tester.pumpAndSettle();
        // 90.0 -> 88.0 = -2.0 cm, -2.2 %.
        expect(find.byKey(const Key('compare-change')), findsOneWidget);
        expect(find.text('−2.0 cm'), findsOneWidget);
        expect(find.text('−2.2 %'), findsOneWidget);
        expect(
          find.textContaining(
            'From 90.0 cm on Oct 28, 2026 to 88.0 cm on Nov 3',
          ),
          findsOneWidget,
        );

        // Changing the choice changes the result: 86.0 -> 88.0.
        await tester.tap(find.byKey(const Key('choice-first-after')));
        await tester.pumpAndSettle();
        expect(find.text('+2.0 cm'), findsOneWidget);
        expect(find.text('+2.3 %'), findsOneWidget);
        await unmount(tester);
      },
    );

    testWidgets('both dates without readings need two choices', (tester) async {
      await pumpTrack(
        tester,
        db,
        location: '/track/compare?site=waist&a=2026-11-01&b=2026-11-04',
        seed: [
          reading(MeasurementSite.waist, 90, DateTime(2026, 10, 28, 8)),
          reading(MeasurementSite.waist, 88, DateTime(2026, 11, 3, 8)),
        ],
      );
      await tester.tap(find.byKey(const Key('choice-first-before')));
      await tester.pumpAndSettle();
      // The second date still has to be chosen.
      expect(find.byKey(const Key('compare-change')), findsNothing);
      expect(find.byKey(const Key('choice-second-before')), findsOneWidget);
      await tester.tap(find.byKey(const Key('choice-second-before')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('compare-change')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a type without readings says so', (tester) async {
      await pumpTrack(
        tester,
        db,
        location: '/track/compare?site=neck&a=2026-11-01&b=2026-11-03',
      );
      expect(find.byKey(const Key('outcome-nodata-first')), findsOneWidget);
      expect(find.byKey(const Key('compare-no-change')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('periods: means with reading counts and the change', (
      tester,
    ) async {
      await pumpTrack(
        tester,
        db,
        location:
            '/track/compare?site=waist&mode=periods'
            '&a1=2026-10-01&a2=2026-10-31&b1=2026-11-01&b2=2026-11-30',
        seed: [
          reading(MeasurementSite.waist, 90, DateTime(2026, 10, 5, 8)),
          reading(MeasurementSite.waist, 89, DateTime(2026, 10, 25, 8)),
          reading(MeasurementSite.waist, 88, DateTime(2026, 11, 3, 8)),
        ],
      );
      expect(find.text('Mean 89.5 cm'), findsOneWidget);
      expect(find.text('2 readings'), findsOneWidget);
      expect(find.text('Mean 88.0 cm'), findsOneWidget);
      expect(find.text('1 reading'), findsOneWidget);
      // 89.5 -> 88.0 = -1.5 cm, -1.7 %.
      expect(find.text('−1.5 cm'), findsOneWidget);
      expect(find.text('−1.7 %'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('a period without readings shows no change', (tester) async {
      await pumpTrack(
        tester,
        db,
        location:
            '/track/compare?site=waist&mode=periods'
            '&a1=2026-09-01&a2=2026-09-30&b1=2026-11-01&b2=2026-11-30',
        seed: [reading(MeasurementSite.waist, 88, DateTime(2026, 11, 3, 8))],
      );
      expect(find.byKey(const Key('period-empty-first')), findsOneWidget);
      expect(find.byKey(const Key('compare-change')), findsNothing);
      expect(find.byKey(const Key('compare-no-change')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('the mode switch and a picked date update the comparison', (
      tester,
    ) async {
      await pumpTrack(
        tester,
        db,
        location: '/track/compare?site=waist&a=2026-11-01&b=2026-11-03',
        seed: [reading(MeasurementSite.waist, 88, DateTime(2026, 11, 3, 8))],
      );
      await tester.tap(find.byKey(const Key('compare-date-a')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3'));
      await tester.pump();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(find.text('Date A: Nov 3, 2026'), findsOneWidget);
      expect(find.byKey(const Key('outcome-value-first')), findsOneWidget);

      await tester.tap(find.text('Periods'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('compare-period-a')), findsOneWidget);
      await unmount(tester);
    });
  });

  group('Progress summary (BCM-008)', () {
    testWidgets(
      'first, latest and change; not enough data under two readings',
      (tester) async {
        await pumpTrack(
          tester,
          db,
          location: RfRoutes.trackProgress,
          seed: [
            reading(MeasurementSite.waist, 90, DateTime(2026, 10, 1, 8)),
            reading(MeasurementSite.waist, 87.5, DateTime(2026, 11, 3, 8)),
            reading(MeasurementSite.neck, 38, DateTime(2026, 11, 3, 8)),
          ],
        );
        expect(find.text('First 90.0 cm · Latest 87.5 cm'), findsOneWidget);
        expect(find.byKey(const Key('change-abs-waist')), findsOneWidget);
        expect(find.text('−2.5 cm'), findsOneWidget);
        expect(find.text('−2.8 %'), findsOneWidget);
        // Neck has one reading, the others none.
        expect(find.text('Not enough data (1 reading)'), findsOneWidget);
        expect(find.text('Not enough data'), findsNWidgets(11));
        await unmount(tester);
      },
    );

    testWidgets('the period selector changes which readings count', (
      tester,
    ) async {
      await pumpTrack(
        tester,
        db,
        location: RfRoutes.trackProgress,
        seed: [
          reading(MeasurementSite.waist, 95, DateTime(2026, 6, 1, 8)),
          reading(MeasurementSite.waist, 90, DateTime(2026, 10, 20, 8)),
          reading(MeasurementSite.waist, 88, DateTime(2026, 11, 3, 8)),
        ],
      );
      // 12 weeks: 90.0 -> 88.0.
      expect(find.text('First 90.0 cm · Latest 88.0 cm'), findsOneWidget);
      await tester.tap(find.byKey(const Key('period-all')));
      await tester.pumpAndSettle();
      expect(find.text('First 95.0 cm · Latest 88.0 cm'), findsOneWidget);
      await tester.tap(find.byKey(const Key('period-weeks4')));
      await tester.pumpAndSettle();
      expect(find.text('First 90.0 cm · Latest 88.0 cm'), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('editing history updates the summary at once', (tester) async {
      final a = reading(MeasurementSite.waist, 90, DateTime(2026, 10, 20, 8));
      final b = reading(MeasurementSite.waist, 88, DateTime(2026, 11, 3, 8));
      final c = await pumpTrack(
        tester,
        db,
        location: RfRoutes.trackProgress,
        seed: [a, b],
      );
      expect(find.text('−2.0 cm'), findsOneWidget);
      await realAsync(tester, () => c.read(deleteMeasurementProvider)(b.id));
      await tester.pumpAndSettle();
      expect(find.text('Not enough data (1 reading)'), findsOneWidget);
      await unmount(tester);
    });
  });
}
