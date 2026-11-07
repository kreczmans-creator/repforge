import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/analytics/weekly_report.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';
import 'package:repforge/features/nutrition/presentation/provenance_badge.dart';

import '../../../helpers/pump.dart';
import 'analytics_harness.dart';

Text _text(WidgetTester t, String key) => t.widget<Text>(find.byKey(Key(key)));

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  testWidgets('loading state', (tester) async {
    final c = analyticsContainer(
      db,
      overrides: [
        weeklyReportProvider.overrideWith(
          (ref, period) => Completer<WeeklyReport>().future,
        ),
      ],
    );
    await pumpAnalytics(
      tester,
      c,
      location: RfRoutes.goalsWeekly,
      settle: false,
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('error state retries', (tester) async {
    var calls = 0;
    final c = analyticsContainer(
      db,
      overrides: [
        weeklyReportProvider.overrideWith((ref, period) async {
          calls++;
          throw const AnalyticsLoadException(StorageError('x'));
        }),
      ],
    );
    await pumpAnalytics(tester, c, location: RfRoutes.goalsWeekly);
    expect(find.byKey(const Key('weekly-error')), findsOneWidget);
    expect(find.textContaining('x'), findsNothing);
    final before = calls;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(before));
    await unmount(tester);
  });

  testWidgets('an empty week says not enough data in every section', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await pumpAnalytics(tester, c, location: RfRoutes.goalsWeekly);
    for (final section in [
      'weekly-nutrition',
      'weekly-training',
      'weekly-body',
    ]) {
      expect(
        find.descendant(
          of: find.byKey(Key(section)),
          matching: find.text('not enough data'),
        ),
        findsWidgets,
        reason: section,
      );
    }
    // Nothing logged is "0 of 6 days" (a known count), the averages are not
    // enough data.
    expect(find.text('0 of 6'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(
      _text(tester, 'weekly-period-label').data,
      contains('2026-11-02 to 2026-11-08'),
    );
    await unmount(tester);
  });

  testWidgets('shows the figures of a week with data', (tester) async {
    final c = analyticsContainer(db);
    await tester.runAsync(() async {
      await c.read(foodLogRepositoryProvider).insertAll([
        foodAt('2026-11-03', 2000, protein: 150),
        foodAt(
          '2026-11-04',
          2200,
          protein: 170,
          provenance: DataProvenance.estimated,
        ),
      ]);
      await c
          .read(goalRepositoryProvider)
          .upsert(goalOf(GoalKind.sessionsPerWeek, 3));
      await seedWorkout(c, DateTime(2026, 11, 3, 9), [(80, 5), (80, 4)]);
      await c.read(measurementRepositoryProvider).insertAll([
        for (final (d, v) in [
          (2, 86.0),
          (3, 86.0),
          (4, 86.0),
          (5, 85.0),
          (6, 85.0),
          (7, 85.0),
        ])
          readingAt(MeasurementSite.weight, v, DateTime(2026, 11, d, 8)),
      ]);
    });
    await pumpAnalytics(tester, c, location: RfRoutes.goalsWeekly);

    expect(find.text('2 of 6'), findsOneWidget);
    expect(find.text('2100 kcal'), findsOneWidget);
    expect(find.text('160 g'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const Key('weekly-nutrition')),
        matching: find.byType(ProvenanceBadge),
      ),
      findsOneWidget,
    );
    expect(find.text('Estimate'), findsOneWidget);
    expect(find.text('1 of 3 sessions'), findsOneWidget);
    expect(find.text('720 kg'), findsOneWidget);
    expect(find.byKey(const Key('weekly-sets')), findsOneWidget);
    final change = find.descendant(
      of: find.byKey(const Key('weekly-weight-change')),
      matching: find.textContaining('kg'),
    );
    expect(change, findsOneWidget);
    expect(find.text('6'), findsOneWidget);
    // The day rule appears once per section.
    expect(find.text('Days run from local midnight'), findsNWidgets(2));
    expect(find.text('Calendar dates (local midnight)'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('reps, seconds and metres are absent when not recorded', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await tester.runAsync(() async {
      await seedWorkout(c, DateTime(2026, 11, 3, 9), [(80, 5)]);
    });
    await pumpAnalytics(tester, c, location: RfRoutes.goalsWeekly);
    expect(find.byKey(const Key('weekly-reps')), findsNothing);
    expect(find.byKey(const Key('weekly-seconds')), findsNothing);
    expect(find.byKey(const Key('weekly-metres')), findsNothing);
    await unmount(tester);
  });

  testWidgets('bodyweight, timed and distance sets add their figures', (
    tester,
  ) async {
    final c2 = analyticsContainer(db);
    await tester.runAsync(() async {
      await seedWorkoutData(c2, DateTime(2026, 11, 3, 9), [
        const SetData.bodyweight(reps: 12),
        const SetData.timed(duration: Duration(seconds: 60)),
        const SetData.distance(metres: 500),
      ]);
    });
    await pumpAnalytics(tester, c2, location: RfRoutes.goalsWeekly);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('60 s'), findsOneWidget);
    expect(find.text('500 m'), findsOneWidget);
    // A bodyweight-only week has a real 0 kg volume, not "not enough data".
    expect(
      find.descendant(
        of: find.byKey(const Key('weekly-volume')),
        matching: find.text('0 kg'),
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('the period picker steps to the previous week and back', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await tester.runAsync(
      () => c.read(foodLogRepositoryProvider).insertAll([
        foodAt('2026-10-28', 1800),
      ]),
    );
    await pumpAnalytics(tester, c, location: RfRoutes.goalsWeekly);
    expect(
      tester
          .widget<IconButton>(find.byKey(const Key('weekly-period-next')))
          .onPressed,
      isNull,
    );
    await tester.tap(find.byKey(const Key('weekly-period-prev')));
    await tester.pumpAndSettle();
    expect(
      _text(tester, 'weekly-period-label').data,
      contains('2026-10-26 to 2026-11-01'),
    );
    expect(find.text('1 of 7'), findsOneWidget);
    expect(find.text('1800 kcal'), findsOneWidget);
    await tester.tap(find.byKey(const Key('weekly-period-next')));
    await tester.pumpAndSettle();
    expect(find.text('1 of 7'), findsNothing);
    await unmount(tester);
  });

  for (final light in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'renders at 360 px (${light ? 'light' : 'dark'}, text x$scale)',
        (tester) async {
          final c = analyticsContainer(db);
          await tester.runAsync(() async {
            await c.read(foodLogRepositoryProvider).insertAll([
              foodAt('2026-11-03', 2000),
            ]);
            await seedWorkout(c, DateTime(2026, 11, 3, 9), [(80, 5)]);
          });
          await pumpAnalytics(
            tester,
            c,
            location: RfRoutes.goalsWeekly,
            size: const Size(360, 2400),
            textScale: scale,
            light: light,
          );
          expect(tester.takeException(), isNull);
          expect(find.byKey(const Key('weekly-body')), findsOneWidget);
          await unmount(tester);
        },
      );
    }
  }
}
