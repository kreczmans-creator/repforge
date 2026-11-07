import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';
import 'package:repforge/features/analytics/application/training_use_cases.dart';

import '../../../helpers/pump.dart';
import 'analytics_harness.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  testWidgets('loading state', (tester) async {
    final c = analyticsContainer(
      db,
      overrides: [
        weekTrainingProvider.overrideWith(
          (ref, period) => Completer<WeekTrainingView>().future,
        ),
      ],
    );
    await pumpAnalytics(
      tester,
      c,
      location: RfRoutes.goalsTraining,
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
        weekTrainingProvider.overrideWith((ref, period) async {
          calls++;
          throw const AnalyticsLoadException(StorageError('x'));
        }),
      ],
    );
    await pumpAnalytics(tester, c, location: RfRoutes.goalsTraining);
    expect(find.byKey(const Key('training-error')), findsOneWidget);
    final before = calls;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(before));
    await unmount(tester);
  });

  testWidgets('empty state when no workout was recorded', (tester) async {
    final c = analyticsContainer(db);
    await pumpAnalytics(tester, c, location: RfRoutes.goalsTraining);
    expect(find.byKey(const Key('training-empty')), findsOneWidget);
    expect(find.byKey(const Key('training-volume-chart')), findsNothing);
    await unmount(tester);
  });

  testWidgets('volume chart with data table, weeks and exercises', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await tester.runAsync(() async {
      await seedExercise(c, 'bench', 'Bench Press');
      await seedWorkout(c, DateTime(2026, 10, 28, 9), [(70, 5)]);
      await seedWorkout(c, DateTime(2026, 11, 3, 9), [(80, 5), (80, 4)]);
    });
    await pumpAnalytics(tester, c, location: RfRoutes.goalsTraining);

    expect(find.byKey(const Key('training-volume-chart')), findsOneWidget);
    expect(find.text('Data table'), findsOneWidget);
    // Newest week first in the list.
    expect(
      tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(const Key('training-week-0')),
              matching: find.textContaining('sessions'),
            ),
          )
          .data,
      '1 sessions · 2 sets · 720 kg',
    );
    expect(find.text('1 sessions · 1 sets · 350 kg'), findsOneWidget);
    // A week without a session says so, not 0 kg.
    expect(find.text('0 sessions · 0 sets · not enough data'), findsWidgets);

    final tile = find.byKey(const Key('training-exercise-bench'));
    expect(tile, findsOneWidget);
    expect(find.text('Bench Press'), findsOneWidget);
    expect(find.text('2 sets · 720 kg'), findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise-progress-chart')), findsOneWidget);
    await unmount(tester);
  });

  for (final light in [false, true]) {
    testWidgets('renders at 360 px, text x2 (${light ? 'light' : 'dark'})', (
      tester,
    ) async {
      final c = analyticsContainer(db);
      await tester.runAsync(() async {
        await seedExercise(c, 'bench', 'Bench Press');
        await seedWorkout(c, DateTime(2026, 11, 3, 9), [(80, 5)]);
      });
      await pumpAnalytics(
        tester,
        c,
        location: RfRoutes.goalsTraining,
        size: const Size(360, 2400),
        textScale: 2,
        light: light,
      );
      expect(tester.takeException(), isNull);
      await unmount(tester);
    });
  }
}
