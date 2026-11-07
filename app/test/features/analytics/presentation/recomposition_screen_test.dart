import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/analytics/recomposition.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';

import '../../../helpers/pump.dart';
import 'analytics_harness.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  String? textOf(WidgetTester t, String key) =>
      t.widget<Text>(find.byKey(Key(key))).data;

  Future<void> seedAll(WidgetTester tester, ProviderContainer c) =>
      tester.runAsync(() async {
        await seedExercise(c, 'bench', 'Bench Press');
        await seedWorkout(c, DateTime(2026, 10, 28, 9), [(70, 5)]);
        await seedWorkout(c, DateTime(2026, 11, 3, 9), [(80, 5)]);
        await c.read(measurementRepositoryProvider).insertAll([
          for (var d = 1; d <= 6; d++)
            readingAt(MeasurementSite.weight, 85, DateTime(2026, 11, d, 8)),
          for (final d in [1, 3, 6])
            readingAt(MeasurementSite.waist, 84, DateTime(2026, 11, d, 8)),
          // Another site must not leak into the waist series.
          readingAt(MeasurementSite.chest, 100, DateTime(2026, 11, 2, 8)),
        ]);
      });

  testWidgets('loading state', (tester) async {
    final c = analyticsContainer(
      db,
      overrides: [
        recompositionSeriesProvider.overrideWith(
          (ref, key) => Completer<RecompositionSeries>().future,
        ),
      ],
    );
    await pumpAnalytics(
      tester,
      c,
      location: RfRoutes.goalsRecomposition,
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
        recompositionSeriesProvider.overrideWith((ref, key) async {
          calls++;
          throw const AnalyticsLoadException(StorageError('x'));
        }),
      ],
    );
    await pumpAnalytics(tester, c, location: RfRoutes.goalsRecomposition);
    expect(find.byKey(const Key('recomposition-error')), findsOneWidget);
    final before = calls;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(before));
    await unmount(tester);
  });

  testWidgets('empty data: three panels each stating 0 points', (tester) async {
    final c = analyticsContainer(db);
    await pumpAnalytics(tester, c, location: RfRoutes.goalsRecomposition);
    expect(
      textOf(tester, 'recomposition-points-weight'),
      'Weight trend: 0 points',
    );
    expect(textOf(tester, 'recomposition-points-waist'), 'Waist: 0 points');
    expect(
      textOf(tester, 'recomposition-points-strength'),
      'Top set weight: 0 points',
    );
    expect(find.text('No exercise chosen.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('point counts, data tables and a remembered exercise', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await seedAll(tester, c);
    await pumpAnalytics(tester, c);
    await tester.tap(find.byKey(const Key('goals-open-recomposition')));
    await tester.pumpAndSettle();

    expect(textOf(tester, 'recomposition-points-waist'), 'Waist: 3 points');
    expect(
      textOf(tester, 'recomposition-points-weight'),
      matches(RegExp(r'^Weight trend: [1-9]\d* points?$')),
    );
    expect(
      textOf(tester, 'recomposition-points-strength'),
      'Top set weight: 0 points',
    );
    expect(find.text('Data table'), findsNWidgets(2));
    expect(
      textOf(tester, 'recomposition-range-label'),
      'Date range 2026-08-16 to 2026-11-07',
    );

    await tester.tap(find.byKey(const Key('recomposition-exercise-pick')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('picker-exercise-bench')));
    await tester.pumpAndSettle();
    expect(find.text('Strength: Bench Press'), findsOneWidget);
    expect(
      textOf(tester, 'recomposition-points-strength'),
      'Top set weight: 2 points',
    );

    // Leaving and returning keeps the choice for the session.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goals-open-recomposition')));
    await tester.pumpAndSettle();
    expect(find.text('Strength: Bench Press'), findsOneWidget);
    expect(
      textOf(tester, 'recomposition-points-strength'),
      'Top set weight: 2 points',
    );

    // A shorter range drops the older session; the range label follows.
    await tester.tap(find.text('4 weeks'));
    await tester.pumpAndSettle();
    expect(
      textOf(tester, 'recomposition-range-label'),
      'Date range 2026-10-11 to 2026-11-07',
    );
    await unmount(tester);
  });

  for (final light in [false, true]) {
    testWidgets('renders at 360 px, text x2 (${light ? 'light' : 'dark'})', (
      tester,
    ) async {
      final c = analyticsContainer(db);
      await seedAll(tester, c);
      await pumpAnalytics(
        tester,
        c,
        location: RfRoutes.goalsRecomposition,
        size: const Size(360, 3000),
        textScale: 2,
        light: light,
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
