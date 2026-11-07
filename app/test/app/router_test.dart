import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/delivery/application/blocker_providers.dart';

import '../features/delivery/blocker_fixtures.dart';
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
    expect(find.byKey(const Key('add-measurements')), findsOneWidget);
    expect(find.byKey(const Key('site-weight')), findsOneWidget);
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
    expect(find.byKey(const Key('goals-empty')), findsOneWidget);
    expect(find.text('NOT YET AVAILABLE'), findsNothing);
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
    expect(RfRoutes.trainSession('s1'), '/train/session/s1');
    expect(RfRoutes.trainHistory, '/train/history');
    expect(RfRoutes.trainHistoryDetail('s1'), '/train/history/s1');

    final expected = <String, String>{
      RfRoutes.trainPlans: 'new-plan',
      RfRoutes.trainPlanNew: 'plan-name-field',
      RfRoutes.trainPlan('missing'): 'plan-missing',
      RfRoutes.trainSplitNew: 'split-name-field',
      RfRoutes.trainSplit('missing'): 'split-missing',
      RfRoutes.trainSchedule: 'schedule-on-date',
      RfRoutes.trainSession('missing'): 'session-missing',
      RfRoutes.trainHistory: 'history-list-empty',
      RfRoutes.trainHistoryDetail('missing'): 'detail-missing',
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

  testWidgets('measurement routes resolve (WP 10)', (tester) async {
    expect(RfRoutes.settingsBackup, '/settings/backup');
    expect(RfRoutes.trackEntry, '/track/entry');
    expect(RfRoutes.trackUnreadable, '/track/unreadable');
    expect(RfRoutes.trackProgress, '/track/progress');
    expect(
      RfRoutes.trackSite(MeasurementSite.thighLeft),
      '/track/site/thighLeft',
    );
    expect(RfRoutes.trackCompare(), '/track/compare');
    expect(
      RfRoutes.trackCompare(MeasurementSite.waist),
      '/track/compare?site=waist',
    );

    final expected = <String, String>{
      RfRoutes.trackEntry: 'field-weight',
      RfRoutes.settingsBackup: 'export-backup',
      RfRoutes.trackUnreadable: 'unreadable-empty',
      RfRoutes.trackProgress: 'progress-empty',
      RfRoutes.trackSite(MeasurementSite.weight): 'site-empty',
      '/track/site/nonsense': 'site-unknown',
      RfRoutes.trackCompare(): 'compare-site-picker',
      RfRoutes.trackCompare(MeasurementSite.waist): 'outcome-nodata-first',
      '/track/compare?mode=periods': 'period-empty-first',
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

  testWidgets('owner action routes resolve', (tester) async {
    expect(RfRoutes.settingsOwnerActions, '/settings/owner-actions');
    expect(
      RfRoutes.settingsOwnerAction('OB-1'),
      '/settings/owner-actions/OB-1',
    );
    final expected = <String, String>{
      RfRoutes.settingsOwnerActions: 'blockers-summary',
      RfRoutes.settingsOwnerAction('missing'): 'blocker-missing',
    };
    for (final entry in expected.entries) {
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            databaseProvider.overrideWithValue(db),
            ownerBlockerRegisterProvider.overrideWithValue(testRegister),
          ],
          child: RepForgeApp(router: createRouter(initialLocation: entry.key)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(Key(entry.value)), findsOneWidget, reason: entry.key);
      await unmount(tester);
    }
  });
  testWidgets('goals routes resolve (WP 11)', (tester) async {
    expect(RfRoutes.goals, '/goals');
    expect(RfRoutes.goalsEdit(GoalKind.bodyWeight), '/goals/edit/bodyWeight');
    expect(
      RfRoutes.goalsEdit(GoalKind.measurement, MeasurementSite.waist),
      '/goals/edit/measurement?site=waist',
    );
    expect(RfRoutes.goalsHistory, '/goals/history');
    expect(RfRoutes.goalsWeekly, '/goals/weekly');
    expect(RfRoutes.goalsCompare, '/goals/compare');
    expect(RfRoutes.goalsTraining, '/goals/training');
    expect(RfRoutes.goalsExercise('e1'), '/goals/training/exercise/e1');
    expect(RfRoutes.goalsRecomposition, '/goals/recomposition');

    final expected = <String, String>{
      RfRoutes.goals: 'goals-empty',
      RfRoutes.goalsEdit(GoalKind.bodyWeight): 'goal-save',
      RfRoutes.goalsEdit(GoalKind.measurement, MeasurementSite.waist):
          'goal-site-choice',
      RfRoutes.goalsEdit(GoalKind.sessionsPerWeek): 'goal-save',
      '/goals/edit/calories': 'goal-unknown',
      RfRoutes.goalsHistory: 'target-history-empty',
      RfRoutes.goalsWeekly: 'weekly-nutrition',
      RfRoutes.goalsCompare: 'compare-table',
      RfRoutes.goalsTraining: 'training-empty',
      RfRoutes.goalsExercise('missing'): 'exercise-progress-empty',
      RfRoutes.goalsRecomposition: 'recomposition-points-weight',
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
