import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/analytics/period_comparison.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';

import '../../../helpers/pump.dart';
import 'analytics_harness.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  String? textOf(WidgetTester t, String key) =>
      t.widget<Text>(find.byKey(Key(key))).data;

  List<String> texts(WidgetTester t, String measure) => [
    for (final part in ['measure', 'earlier', 'later', 'difference'])
      t.widget<Text>(find.byKey(Key('compare-$measure-$part'))).data!,
  ];

  testWidgets('loading state', (tester) async {
    final c = analyticsContainer(
      db,
      overrides: [
        periodComparisonProvider.overrideWith(
          (ref, pair) => Completer<PeriodComparison>().future,
        ),
      ],
    );
    await pumpAnalytics(
      tester,
      c,
      location: RfRoutes.goalsCompare,
      settle: false,
    );
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('empty periods read not available, never 0', (tester) async {
    final c = analyticsContainer(db);
    await pumpAnalytics(tester, c, location: RfRoutes.goalsCompare);
    expect(find.byKey(const Key('compare-table')), findsOneWidget);
    for (final m in ['energy', 'protein', 'volume', 'weight']) {
      expect(find.byKey(Key('compare-$m-reason')), findsOneWidget);
      expect(texts(tester, m), [
        m[0].toUpperCase() + m.substring(1),
        'not available',
        'not available',
        'not available',
      ]);
    }
    await unmount(tester);
  });

  testWidgets('compares two weeks; an empty one is not available', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await tester.runAsync(() async {
      await c.read(foodLogRepositoryProvider).insertAll([
        foodAt('2026-10-28', 1800, protein: 120),
        foodAt('2026-11-03', 2100, protein: 150),
      ]);
      await seedWorkout(c, DateTime(2026, 10, 28, 9), [(80, 5)]);
      await seedWorkout(c, DateTime(2026, 11, 3, 9), [(80, 5), (80, 4)]);
    });
    await pumpAnalytics(tester, c, location: RfRoutes.goalsCompare);
    expect(texts(tester, 'energy'), ['Energy', '1800', '2100', '+300']);
    expect(texts(tester, 'protein'), ['Protein', '120', '150', '+30']);
    expect(texts(tester, 'volume'), ['Volume', '400', '720', '+320']);
    expect(texts(tester, 'weight'), [
      'Weight',
      'not available',
      'not available',
      'not available',
    ]);
    expect(
      tester.widget<Text>(find.byKey(const Key('compare-later-label'))).data,
      contains('2026-11-02 to 2026-11-08'),
    );
    await unmount(tester);
  });

  testWidgets('month mode compares this month with last month', (tester) async {
    final c = analyticsContainer(db);
    await tester.runAsync(
      () => c.read(foodLogRepositoryProvider).insertAll([
        foodAt('2026-10-15', 2000),
        foodAt('2026-11-03', 2200),
      ]),
    );
    await pumpAnalytics(tester, c, location: RfRoutes.goalsCompare);
    await tester.tap(find.text('Month'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<Text>(find.byKey(const Key('compare-later-label'))).data,
      contains('November 2026'),
    );
    expect(texts(tester, 'energy'), ['Energy', '2000', '2200', '+200']);
    await unmount(tester);
  });

  testWidgets('states a period still in progress and the weight basis', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await pumpAnalytics(tester, c, location: RfRoutes.goalsCompare);
    expect(
      textOf(tester, 'compare-partial-note'),
      'Week of 2026-11-02 so far: 6 of 7 days',
    );
    expect(
      textOf(tester, 'compare-weight-note'),
      PeriodComparison.weightBasisNote,
    );
    await unmount(tester);
  });

  for (final light in [false, true]) {
    testWidgets('renders at 360 px, text x2 (${light ? 'light' : 'dark'})', (
      tester,
    ) async {
      final c = analyticsContainer(db);
      await pumpAnalytics(
        tester,
        c,
        location: RfRoutes.goalsCompare,
        size: const Size(360, 2400),
        textScale: 2,
        light: light,
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
