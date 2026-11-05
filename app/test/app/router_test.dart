import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';

import '../helpers/pump.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  testWidgets('bottom navigation switches between the five pillars', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: RepForgeApp(router: createRouter()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('kcal-tile')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-track')));
    await tester.pumpAndSettle();
    expect(find.text('Track'), findsWidgets);
    expect(find.byKey(const Key('weight-input')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-fuel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('log-food')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-train')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('exercise-search')), findsOneWidget);
    expect(find.byKey(const Key('new-exercise')), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-goals')));
    await tester.pumpAndSettle();
    expect(find.text('Goals'), findsWidgets);
    expect(find.text('NOT YET AVAILABLE'), findsOneWidget);
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('kcal-tile')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('training plan, split and schedule routes resolve', (
    tester,
  ) async {
    expect(RfRoutes.trainPlans, '/train/plans');
    expect(RfRoutes.trainPlanNew, '/train/plans/new');
    expect(RfRoutes.trainPlan('p1'), '/train/plans/p1');
    expect(RfRoutes.trainSplitNew, '/train/splits/new');
    expect(RfRoutes.trainSplit('s1'), '/train/splits/s1');
    expect(RfRoutes.trainSchedule, '/train/schedule');

    final expected = <String, String>{
      RfRoutes.trainPlans: 'new-plan',
      RfRoutes.trainPlanNew: 'plan-name-field',
      RfRoutes.trainPlan('missing'): 'plan-missing',
      RfRoutes.trainSplitNew: 'split-name-field',
      RfRoutes.trainSplit('missing'): 'split-missing',
      RfRoutes.trainSchedule: 'schedule-on-date',
    };
    for (final entry in expected.entries) {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [databaseProvider.overrideWithValue(db)],
          child: RepForgeApp(router: createRouter(initialLocation: entry.key)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(Key(entry.value)), findsOneWidget, reason: entry.key);
      await unmount(tester);
    }
  });
}
