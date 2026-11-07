import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';

import '../../../helpers/pump.dart';
import 'analytics_harness.dart';

/// GOL-011: the analytics screens describe; they never tell the user what to
/// do. Every visible text of every screen, seeded with data, is checked
/// against a list of advice words.
final _advice = RegExp(
  r'\b(should|consider|recommend\w*|suggest\w*|aim|you need|you could|'
  r'try|improve|eat more|eat less|cut|bulk|reduce your|increase your)\b',
  caseSensitive: false,
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  final locations = {
    'goals home': RfRoutes.goals,
    'goal editor': RfRoutes.goalsEdit(GoalKind.bodyWeight),
    'target history': RfRoutes.goalsHistory,
    'weekly summary': RfRoutes.goalsWeekly,
    'comparison': RfRoutes.goalsCompare,
    'training': RfRoutes.goalsTraining,
    'exercise progress': RfRoutes.goalsExercise('bench'),
    'recomposition': RfRoutes.goalsRecomposition,
  };

  for (final entry in locations.entries) {
    testWidgets('${entry.key} has no advice text', (tester) async {
      final c = analyticsContainer(db);
      await tester.runAsync(() async {
        await seedExercise(c, 'bench', 'Bench Press');
        await seedWorkout(c, DateTime(2026, 10, 28, 9), [(70, 5)]);
        await seedWorkout(c, DateTime(2026, 11, 3, 9), [(80, 5), (80, 4)]);
        await c.read(foodLogRepositoryProvider).insertAll([
          foodAt('2026-11-03', 2000),
        ]);
        await c.read(measurementRepositoryProvider).insertAll([
          for (var d = 1; d <= 6; d++)
            readingAt(MeasurementSite.weight, 85, DateTime(2026, 11, d, 8)),
        ]);
        final goals = c.read(goalRepositoryProvider);
        await goals.upsert(goalOf(GoalKind.bodyWeight, 80));
        await goals.upsert(goalOf(GoalKind.sessionsPerWeek, 3));
      });
      await pumpAnalytics(tester, c, location: entry.value);
      final texts = [
        for (final e in find.byType(Text).evaluate())
          if ((e.widget as Text).data case final String d) d,
      ];
      expect(texts, isNotEmpty);
      for (final t in texts) {
        expect(_advice.hasMatch(t), isFalse, reason: '${entry.key}: "$t"');
      }
      await unmount(tester);
    });
  }
}
