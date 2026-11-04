import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/presentation/weekly_summary_screen.dart';
import 'package:repforge/ui/theme.dart';

import '../../../helpers/pump.dart';

final _now = DateTime(2026, 11, 3, 9);

FoodLogEntry _entry(String id, String day, double kcal, double protein) =>
    FoodLogEntry(
      id: id,
      day: day,
      meal: MealSlot.lunch,
      name: 'Food $id',
      quantity: Quantity.fromStored(100, ReferenceUnit.grams),
      nutrients: NutrientAmounts(
        kcal: kcal,
        proteinG: protein,
        carbsG: 10,
        fatG: 5,
      ),
      provenance: DataProvenance.userEntered,
      loggedAt: _now.toUtc(),
      createdAt: _now.toUtc(),
      updatedAt: _now.toUtc(),
    );

void main() {
  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase.inMemory();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(_now)),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: rfTheme(Brightness.dark),
          home: const WeeklySummaryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('shows the empty state and zero logged days', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('week-empty')), findsOneWidget);
    expect(find.textContaining('0 of 7 days logged'), findsOneWidget);
    expect(find.textContaining('Nov 28'), findsNothing);
    await unmount(tester);
  });

  testWidgets('averages only the logged days and marks the others', (
    tester,
  ) async {
    final log = container.read(foodLogRepositoryProvider);
    await log.insert(_entry('a', '2026-11-01', 1800, 120));
    await log.insert(_entry('b', '2026-11-03', 2200, 160));
    await pump(tester);
    expect(find.textContaining('2 of 7 days logged'), findsOneWidget);
    expect(find.textContaining('Oct 28 to Nov 3'), findsOneWidget);
    final avg = find.byKey(const Key('week-avg-kcal'));
    expect(
      find.descendant(of: avg, matching: find.text('2000')),
      findsOneWidget,
    );
    expect(find.text('per logged day'), findsNWidgets(2));
    expect(find.text('not logged'), findsNWidgets(5));
    expect(find.text('1800 kcal · P 120'), findsOneWidget);
    expect(
      find.text('Averages use only the days with at least one entry.'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('shows targets as captions and fills bars against them', (
    tester,
  ) async {
    final goals = container.read(goalRepositoryProvider);
    Goal goal(String id, GoalKind k, double t) => Goal(
      id: id,
      kind: k,
      target: t,
      startDate: _now,
      createdAt: _now,
      updatedAt: _now,
    );
    await goals.upsert(goal('g1', GoalKind.calories, 2000));
    await goals.upsert(goal('g2', GoalKind.protein, 150));
    await container
        .read(foodLogRepositoryProvider)
        .insert(_entry('a', '2026-11-03', 1000, 100));
    await pump(tester);
    expect(find.text('target 2000'), findsOneWidget);
    expect(find.text('target 150'), findsOneWidget);
    final bar = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(bar.value, 0.5);
    await unmount(tester);
  });
}
