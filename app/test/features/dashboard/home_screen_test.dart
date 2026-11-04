import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/weight_entry.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/dashboard/presentation/home_screen.dart';
import 'package:repforge/ui/theme.dart';

import '../../helpers/pump.dart';

final _now = DateTime(2026, 11, 3, 9); // local

Widget _harness(AppDatabase db) => ProviderScope(
  overrides: [
    databaseProvider.overrideWithValue(db),
    clockProvider.overrideWithValue(FixedClock(_now)),
  ],
  child: MaterialApp(
    theme: rfTheme(Brightness.dark),
    home: const Scaffold(body: HomeScreen()),
  ),
);

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  testWidgets('shows empty states when nothing is stored', (tester) async {
    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('nutrition-empty')), findsOneWidget);
    expect(find.byKey(const Key('training-empty')), findsOneWidget);
    expect(find.byKey(const Key('activity-empty')), findsOneWidget);
    expect(find.text('Good morning'), findsOneWidget);
    expect(find.text('No target set'), findsNWidgets(2));
    await unmount(tester);
  });

  testWidgets('shows intake against targets from the database', (tester) async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(_now)),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(goalRepositoryProvider)
        .upsert(
          Goal(
            id: 'g1',
            kind: GoalKind.calories,
            target: 2000,
            startDate: _now,
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    await container
        .read(goalRepositoryProvider)
        .upsert(
          Goal(
            id: 'g2',
            kind: GoalKind.protein,
            target: 150,
            startDate: _now,
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    await container
        .read(foodLogRepositoryProvider)
        .insert(
          FoodLogEntry(
            id: 'e1',
            day: dayKey(_now),
            meal: MealSlot.breakfast,
            name: 'Oats',
            quantity: Quantity.fromStored(80, ReferenceUnit.grams),
            nutrients: const NutrientAmounts(
              kcal: 300,
              proteinG: 10,
              carbsG: 50,
              fatG: 6,
            ),
            provenance: DataProvenance.userEntered,
            loggedAt: _now,
            createdAt: _now,
            updatedAt: _now,
          ),
        );

    await tester.pumpWidget(_harness(db));
    await tester.pumpAndSettle();

    expect(find.text('Calories left'.toUpperCase()), findsOneWidget);
    expect(find.text('1700'), findsOneWidget); // 2000 - 300
    expect(find.text('300 of 2000'), findsOneWidget);
    expect(find.text('10'), findsOneWidget); // protein tile
    expect(find.byKey(const Key('nutrition-empty')), findsNothing);
    await unmount(tester);
  });

  group('updates live while mounted', () {
    ProviderContainer containerOf(WidgetTester tester) =>
        ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

    Finder tileText(String key, String text) =>
        find.descendant(of: find.byKey(Key(key)), matching: find.text(text));

    testWidgets('weight entry appears and disappears without remounting', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(db));
      await tester.pumpAndSettle();
      final container = containerOf(tester);

      expect(find.byKey(const Key('activity-empty')), findsOneWidget);
      expect(tileText('latest-weight', '—'), findsOneWidget);
      expect(tileText('latest-weight', 'Nothing logged yet'), findsOneWidget);
      expect(tileText('weight-count', '0'), findsOneWidget);

      final result = await container.read(recordBodyWeightProvider)(
        weightText: '82.5',
      );
      expect(result, isA<Ok<WeightEntry>>());
      final entry = (result as Ok<WeightEntry>).value;
      await tester.pumpAndSettle();

      expect(tileText('latest-weight', '82.5'), findsOneWidget);
      expect(tileText('latest-weight', 'Nothing logged yet'), findsNothing);
      expect(tileText('weight-count', '1'), findsOneWidget);
      expect(find.byKey(const Key('activity-empty')), findsNothing);
      expect(find.text('Weigh-in'), findsOneWidget);
      expect(find.textContaining('82.5 kg'), findsOneWidget);

      // A second, later entry replaces the latest value in place.
      await container.read(recordBodyWeightProvider)(
        weightText: '81.0',
        recordedAt: _now.add(const Duration(seconds: 30)),
      );
      await tester.pumpAndSettle();
      expect(tileText('latest-weight', '81.0'), findsOneWidget);
      expect(tileText('weight-count', '2'), findsOneWidget);
      expect(find.text('Weigh-in'), findsNWidgets(2));

      // Deleting both returns every weight surface to its empty state.
      final latest = await container.read(weightRepositoryProvider).latest();
      await container.read(deleteWeightEntryProvider)(latest!.id);
      await container.read(deleteWeightEntryProvider)(entry.id);
      await tester.pumpAndSettle();

      expect(tileText('latest-weight', '—'), findsOneWidget);
      expect(tileText('latest-weight', 'Nothing logged yet'), findsOneWidget);
      expect(tileText('weight-count', '0'), findsOneWidget);
      expect(find.byKey(const Key('activity-empty')), findsOneWidget);
      expect(find.text('Weigh-in'), findsNothing);
      await unmount(tester);
    });

    testWidgets('target then food entry update the nutrition panel', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(db));
      await tester.pumpAndSettle();
      final container = containerOf(tester);

      expect(find.byKey(const Key('nutrition-empty')), findsOneWidget);
      expect(find.text('No target set'), findsNWidgets(2));

      final saved = await container.read(saveDailyTargetsProvider)(
        input: {GoalKind.calories: '2000', GoalKind.protein: '150'},
      );
      expect(saved, isA<Ok<DailyTargets>>());
      await tester.pumpAndSettle();

      expect(find.text('No target set'), findsNothing);
      expect(tileText('kcal-tile', '0 of 2000'), findsOneWidget);
      expect(tileText('kcal-tile', '2000'), findsOneWidget);
      expect(tileText('protein-tile', 'of 150 g'), findsOneWidget);
      // Targets alone are enough to leave the empty state.
      expect(find.byKey(const Key('nutrition-empty')), findsNothing);

      await container
          .read(foodLogRepositoryProvider)
          .insert(
            FoodLogEntry(
              id: 'live-e1',
              day: dayKey(_now),
              meal: MealSlot.breakfast,
              name: 'Oats',
              quantity: Quantity.fromStored(80, ReferenceUnit.grams),
              nutrients: const NutrientAmounts(
                kcal: 300,
                proteinG: 10,
                carbsG: 50,
                fatG: 6,
              ),
              provenance: DataProvenance.userEntered,
              loggedAt: _now,
              createdAt: _now,
              updatedAt: _now,
            ),
          );
      await tester.pumpAndSettle();

      expect(find.text('Calories left'.toUpperCase()), findsOneWidget);
      expect(tileText('kcal-tile', '1700'), findsOneWidget); // 2000 - 300
      expect(tileText('kcal-tile', '300 of 2000'), findsOneWidget);
      expect(tileText('protein-tile', '10'), findsOneWidget);
      expect(find.byKey(const Key('nutrition-empty')), findsNothing);

      // Removing the entry restores zero intake against the same target.
      await container.read(foodLogRepositoryProvider).delete('live-e1');
      await tester.pumpAndSettle();
      expect(tileText('kcal-tile', '0 of 2000'), findsOneWidget);
      expect(tileText('kcal-tile', '2000'), findsOneWidget);
      await unmount(tester);
    });
  });
}
