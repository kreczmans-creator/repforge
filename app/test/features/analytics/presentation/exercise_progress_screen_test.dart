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

  String? textOf(WidgetTester t, String key) =>
      t.widget<Text>(find.byKey(Key(key))).data;

  Future<void> sessions(
    WidgetTester tester,
    List<(DateTime, List<(double, int)>)> list,
  ) async {
    final c = analyticsContainer(db);
    await tester.runAsync(() async {
      await seedExercise(c, 'bench', 'Bench Press');
      for (final (at, sets) in list) {
        await seedWorkout(c, at, sets);
      }
    });
    await pumpAnalytics(tester, c, location: RfRoutes.goalsExercise('bench'));
  }

  testWidgets('loading state', (tester) async {
    final c = analyticsContainer(
      db,
      overrides: [
        exerciseProgressProvider.overrideWith(
          (ref, id) => Completer<ExerciseProgressView>().future,
        ),
      ],
    );
    await pumpAnalytics(
      tester,
      c,
      location: RfRoutes.goalsExercise('bench'),
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
        exerciseProgressProvider.overrideWith((ref, id) async {
          calls++;
          throw const AnalyticsLoadException(StorageError('x'));
        }),
      ],
    );
    await pumpAnalytics(tester, c, location: RfRoutes.goalsExercise('bench'));
    expect(find.byKey(const Key('exercise-progress-error')), findsOneWidget);
    final before = calls;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(calls, greaterThan(before));
    await unmount(tester);
  });

  testWidgets('empty state for an exercise without sets', (tester) async {
    await sessions(tester, const []);
    expect(find.byKey(const Key('exercise-progress-empty')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('first session', (tester) async {
    await sessions(tester, [
      (DateTime(2026, 11, 3, 9), [(80, 5)]),
    ]);
    expect(
      textOf(tester, 'exercise-progress-statement-topSet'),
      'Top set weight: first session',
    );
    expect(
      textOf(tester, 'exercise-progress-statement-volume'),
      'Session volume: first session',
    );
    expect(find.text('Bench Press'), findsWidgets);
    await unmount(tester);
  });

  testWidgets('increased, with charts, data tables and records', (
    tester,
  ) async {
    await sessions(tester, [
      (DateTime(2026, 10, 28, 9), [(70, 5)]),
      (DateTime(2026, 11, 3, 9), [(80, 5)]),
    ]);
    expect(
      textOf(tester, 'exercise-progress-statement-topSet'),
      'Top set weight: increased',
    );
    expect(
      textOf(tester, 'exercise-progress-statement-volume'),
      'Session volume: increased',
    );
    expect(find.byKey(const Key('exercise-progress-chart')), findsOneWidget);
    expect(find.byKey(const Key('exercise-volume-chart')), findsOneWidget);
    expect(find.text('Data table'), findsNWidgets(2));
    expect(find.byKey(const Key('exercise-records')), findsOneWidget);
    expect(find.textContaining('Heaviest at 5 reps: 80 kg'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('level', (tester) async {
    await sessions(tester, [
      (DateTime(2026, 10, 28, 9), [(80, 5)]),
      (DateTime(2026, 11, 3, 9), [(80, 5)]),
    ]);
    expect(
      textOf(tester, 'exercise-progress-statement-topSet'),
      'Top set weight: level',
    );
    await unmount(tester);
  });

  testWidgets('decreased', (tester) async {
    await sessions(tester, [
      (DateTime(2026, 10, 28, 9), [(80, 5)]),
      (DateTime(2026, 11, 3, 9), [(70, 5)]),
    ]);
    expect(
      textOf(tester, 'exercise-progress-statement-topSet'),
      'Top set weight: decreased',
    );
    expect(
      textOf(tester, 'exercise-progress-statement-volume'),
      'Session volume: decreased',
    );
    await unmount(tester);
  });

  testWidgets('renders at 360 px, text x2, light', (tester) async {
    final c = analyticsContainer(db);
    await tester.runAsync(() async {
      await seedExercise(c, 'bench', 'Bench Press');
      await seedWorkout(c, DateTime(2026, 11, 3, 9), [(80, 5)]);
    });
    await pumpAnalytics(
      tester,
      c,
      location: RfRoutes.goalsExercise('bench'),
      size: const Size(360, 2400),
      textScale: 2,
      light: true,
    );
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
