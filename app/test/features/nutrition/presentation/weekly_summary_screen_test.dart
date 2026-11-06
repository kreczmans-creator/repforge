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

FoodLogEntry _partial(
  String id,
  String day, {
  double kcal = 500,
  double? protein,
  double? carbs,
  double? fat,
  double? fibre,
}) => _entry(id, day, kcal, 0).copyWith(
  nutrients: NutrientAmounts(
    kcal: kcal,
    proteinG: protein,
    carbsG: carbs,
    fatG: fat,
    fibreG: fibre,
  ),
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
    expect(find.text('per logged day · no target'), findsNWidgets(4));
    expect(
      find.text('per logged day · no target · not available'),
      findsOneWidget,
    );
    expect(find.text('not logged'), findsNWidgets(5));
    expect(find.text('1800 kcal'), findsOneWidget);
    expect(find.text('P 120 g · C 10 g · F 5 g · Fibre n/a'), findsOneWidget);
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

  Finder avgText(String key, String text) =>
      find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

  testWidgets('shows all five measures as average and in each day row', (
    tester,
  ) async {
    final log = container.read(foodLogRepositoryProvider);
    await log.insert(
      _partial(
        'a',
        '2026-11-01',
        kcal: 1800,
        protein: 100,
        carbs: 200,
        fat: 60,
        fibre: 30,
      ),
    );
    await log.insert(
      _partial(
        'b',
        '2026-11-03',
        kcal: 2200,
        protein: 140,
        carbs: 240,
        fat: 80,
        fibre: 20,
      ),
    );
    await pump(tester);
    expect(avgText('week-avg-kcal', '2000'), findsOneWidget);
    expect(avgText('week-avg-protein', '120'), findsOneWidget);
    expect(avgText('week-avg-carbs', '220'), findsOneWidget);
    expect(avgText('week-avg-fat', '70'), findsOneWidget);
    expect(avgText('week-avg-fibre', '25'), findsOneWidget);
    expect(
      find.text('P 100 g · C 200 g · F 60 g · Fibre 30 g'),
      findsOneWidget,
    );
    expect(
      find.text('P 140 g · C 240 g · F 80 g · Fibre 20 g'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('unknown values read n/a, not 0, and average logged days only', (
    tester,
  ) async {
    final log = container.read(foodLogRepositoryProvider);
    // Day 1: nothing but energy is known. Day 2: protein known, one entry
    // without protein. Fibre is never known. 5 days are not logged.
    await log.insert(_partial('a', '2026-11-01', kcal: 1000));
    await log.insert(_partial('b', '2026-11-03', kcal: 1000, protein: 90));
    await log.insert(_partial('c', '2026-11-03', kcal: 1000));
    await pump(tester);
    // Energy averages over the 2 logged days: (1000 + 2000) / 2. Protein is
    // averaged over the ONE day that knows it (90), never over the day that
    // knows nothing as if it were 0; that day is reported as unknown.
    expect(avgText('week-avg-kcal', '1500'), findsOneWidget);
    expect(avgText('week-avg-protein', '90'), findsOneWidget);
    expect(
      avgText('week-avg-protein', 'per logged day · no target · 1 day unknown'),
      findsOneWidget,
    );
    expect(avgText('week-avg-carbs', 'n/a'), findsOneWidget);
    expect(avgText('week-avg-fibre', 'n/a'), findsOneWidget);
    expect(
      avgText('week-avg-fibre', 'per logged day · no target · not available'),
      findsOneWidget,
    );
    expect(avgText('week-avg-fibre', '0'), findsNothing);
    expect(find.text('P n/a · C n/a · F n/a · Fibre n/a'), findsOneWidget);
    expect(
      find.text('P 90 g · 1 unknown · C n/a · F n/a · Fibre n/a'),
      findsOneWidget,
    );
    expect(find.text('not logged'), findsNWidgets(5));
    await unmount(tester);
  });
}
