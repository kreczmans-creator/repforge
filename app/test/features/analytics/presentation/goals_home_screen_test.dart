import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/analytics/goal_progress.dart';
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

  testWidgets('loading state while the progress is read', (tester) async {
    final c = analyticsContainer(
      db,
      overrides: [
        goalProgressProvider.overrideWith(
          (ref) => Completer<List<GoalProgress>>().future,
        ),
      ],
    );
    await pumpAnalytics(tester, c, settle: false);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('empty state offers every goal action and summary', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await pumpAnalytics(tester, c);
    expect(find.byKey(const Key('goals-empty')), findsOneWidget);
    for (final key in [
      'goal-set-bodyWeight',
      'goal-set-measurement',
      'goal-set-sessionsPerWeek',
      'goals-open-weekly',
      'goals-open-compare',
      'goals-open-training',
      'goals-open-recomposition',
      'goals-open-history',
    ]) {
      expect(find.byKey(Key(key)), findsOneWidget, reason: key);
    }
    await unmount(tester);
  });

  testWidgets('error state retries through the provider', (tester) async {
    var failing = true;
    final c = analyticsContainer(
      db,
      overrides: [
        goalProgressProvider.overrideWith((ref) async {
          if (failing) {
            throw const AnalyticsLoadException(StorageError('boom'));
          }
          return <GoalProgress>[];
        }),
      ],
    );
    await pumpAnalytics(tester, c);
    expect(find.byKey(const Key('goals-error')), findsOneWidget);
    expect(find.textContaining('boom'), findsNothing);
    failing = false;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goals-empty')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('cards show current, target, percentage, range and basis', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await tester.runAsync(() async {
      final goals = c.read(goalRepositoryProvider);
      await goals.upsert(goalOf(GoalKind.bodyWeight, 80));
      await goals.upsert(
        goalOf(GoalKind.measurement, 80, site: MeasurementSite.waist),
      );
      await goals.upsert(goalOf(GoalKind.sessionsPerWeek, 3));
      final m = c.read(measurementRepositoryProvider);
      await m.insertAll([
        for (final d in [3, 4, 5])
          readingAt(MeasurementSite.weight, 85, DateTime(2026, 11, d, 8)),
        readingAt(MeasurementSite.waist, 86, DateTime(2026, 10, 2, 8)),
        readingAt(MeasurementSite.waist, 84, DateTime(2026, 11, 5, 8)),
      ]);
      await seedWorkout(c, DateTime(2026, 11, 3, 9), [(80, 5)]);
    });
    await pumpAnalytics(tester, c);

    expect(
      find.descendant(
        of: find.byKey(const Key('goal-card-bodyWeight')),
        matching: find.text('5.0 kg to go'),
      ),
      findsOneWidget,
    );
    expect(find.byKey(const Key('goal-current-bodyWeight')), findsOneWidget);
    expect(find.text('85 kg'), findsOneWidget);
    expect(find.text('80 kg'), findsOneWidget);
    expect(find.byKey(const Key('goal-percent-bodyWeight')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('goal-range-bodyWeight'))).data,
      contains('2026-10-01 to 2026-11-07'),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('goal-basis-bodyWeight'))).data,
      contains('weight trend value'),
    );

    final waist = find.byKey(const Key('goal-card-measurement-waist'));
    expect(waist, findsOneWidget);
    expect(find.text('Waist'), findsOneWidget);
    expect(find.text('84 cm'), findsOneWidget);
    expect(
      find.descendant(of: waist, matching: find.text('33.3 %')),
      findsOneWidget,
    );

    expect(find.text('1 of 3 sessions'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a goal with no readings says not enough data, never 0', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await tester.runAsync(
      () => c
          .read(goalRepositoryProvider)
          .upsert(goalOf(GoalKind.bodyWeight, 80)),
    );
    await pumpAnalytics(tester, c);
    final card = find.byKey(const Key('goal-card-bodyWeight'));
    expect(
      find.descendant(of: card, matching: find.text('not enough data')),
      findsNWidgets(2),
    );
    expect(
      find.descendant(of: card, matching: find.text('0 kg')),
      findsNothing,
    );
    await unmount(tester);
  });

  testWidgets('a sessions goal with no session reads 0 of 3', (tester) async {
    final c = analyticsContainer(db);
    await tester.runAsync(
      () => c
          .read(goalRepositoryProvider)
          .upsert(goalOf(GoalKind.sessionsPerWeek, 3)),
    );
    await pumpAnalytics(tester, c);
    expect(find.text('0 of 3 sessions'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('tapping a card opens the entries behind the figure', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await tester.runAsync(() async {
      final goals = c.read(goalRepositoryProvider);
      await goals.upsert(goalOf(GoalKind.bodyWeight, 80));
      await goals.upsert(goalOf(GoalKind.sessionsPerWeek, 3));
      await goals.upsert(
        goalOf(GoalKind.measurement, 80, site: MeasurementSite.waist),
      );
    });
    await pumpAnalytics(tester, c);

    await tester.tap(find.byKey(const Key('goal-card-bodyWeight')));
    await tester.pumpAndSettle();
    expect(find.text('Weight'), findsWidgets);
    expect(find.byKey(const Key('site-chart')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goal-entries-measurement-waist')));
    await tester.pumpAndSettle();
    expect(find.text('Waist'), findsWidgets);
    expect(find.byKey(const Key('site-chart')), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('goal-entries-sessionsPerWeek')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-list-empty')), findsOneWidget);
    await unmount(tester);
  });

  for (final light in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('renders at 360 px without exceptions '
          '(${light ? 'light' : 'dark'}, text x$scale)', (tester) async {
        final c = analyticsContainer(db);
        await tester.runAsync(() async {
          final goals = c.read(goalRepositoryProvider);
          await goals.upsert(goalOf(GoalKind.bodyWeight, 80));
          await goals.upsert(goalOf(GoalKind.sessionsPerWeek, 3));
          await c.read(measurementRepositoryProvider).insertAll([
            for (final d in [3, 4, 5])
              readingAt(MeasurementSite.weight, 85, DateTime(2026, 11, d, 8)),
          ]);
        });
        await pumpAnalytics(
          tester,
          c,
          size: const Size(360, 2400),
          textScale: scale,
          light: light,
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(const Key('goal-card-bodyWeight')), findsOneWidget);
        await unmount(tester);
      });
    }
  }
}
