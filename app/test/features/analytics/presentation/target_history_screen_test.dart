import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/analytics/target_history.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';

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
        targetHistoryProvider.overrideWith(
          (ref) => Completer<TargetHistory>().future,
        ),
      ],
    );
    await pumpAnalytics(
      tester,
      c,
      location: RfRoutes.goalsHistory,
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('empty state', (tester) async {
    final c = analyticsContainer(db);
    await pumpAnalytics(tester, c, location: RfRoutes.goalsHistory);
    expect(find.byKey(const Key('target-history-empty')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('error state with retry', (tester) async {
    var failing = true;
    final c = analyticsContainer(
      db,
      overrides: [
        targetHistoryProvider.overrideWith((ref) async {
          if (failing) throw const AnalyticsLoadException(StorageError('x'));
          return TargetHistory.fromGoals(const []);
        }),
      ],
    );
    await pumpAnalytics(tester, c, location: RfRoutes.goalsHistory);
    expect(find.byKey(const Key('target-history-error')), findsOneWidget);
    failing = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('target-history-empty')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('lists the periods of each kind and site, newest current', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await tester.runAsync(() async {
      final goals = c.read(goalRepositoryProvider);
      // Calories 2200 from 2026-10-01 until 2026-11-04, then 2000.
      await goals.upsert(
        goalOf(
          GoalKind.calories,
          2200,
          active: false,
          start: DateTime(2026, 10),
        ),
      );
      await goals.upsert(
        goalOf(GoalKind.calories, 2000, start: DateTime(2026, 11, 5)),
      );
      await goals.upsert(
        goalOf(GoalKind.measurement, 80, site: MeasurementSite.waist),
      );
      await goals.upsert(
        goalOf(GoalKind.measurement, 60, site: MeasurementSite.thighLeft),
      );
    });
    await pumpAnalytics(tester, c, location: RfRoutes.goalsHistory);

    expect(find.byKey(const Key('target-history-list')), findsOneWidget);
    expect(find.byKey(const Key('target-group-calories')), findsOneWidget);
    expect(
      find.byKey(const Key('target-group-measurement-waist')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('target-group-measurement-thighLeft')),
      findsOneWidget,
    );
    expect(find.byKey(const Key('target-period-0')), findsOneWidget);
    expect(find.byKey(const Key('target-period-3')), findsOneWidget);
    expect(find.text('2200 kcal'), findsOneWidget);
    expect(find.text('From 2026-10-01 to 2026-11-04'), findsOneWidget);
    expect(find.text('2000 kcal'), findsOneWidget);
    expect(find.text('From 2026-11-05 to current'), findsOneWidget);
    expect(find.text('80 cm'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('opens from the Goals tab', (tester) async {
    final c = analyticsContainer(db);
    await pumpAnalytics(tester, c);
    await tester.tap(find.byKey(const Key('goals-open-history')));
    await tester.pumpAndSettle();
    expect(find.text('Target history'), findsWidgets);
    expect(find.byKey(const Key('target-history-empty')), findsOneWidget);
    await unmount(tester);
  });
}
