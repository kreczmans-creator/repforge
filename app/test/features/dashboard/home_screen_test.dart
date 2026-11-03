import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/goals/goals.dart';
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
}
