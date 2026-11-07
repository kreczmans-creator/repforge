import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';
import 'package:repforge/features/nutrition/presentation/fuel_screen.dart';
import 'package:repforge/ui/theme.dart';

import '../../../helpers/pump.dart';

final _now = DateTime(2026, 11, 3, 9);

FoodLogEntry _entry(
  String id,
  NutrientAmounts nutrients, {
  String name = 'Food',
}) => FoodLogEntry(
  id: id,
  day: '2026-11-03',
  meal: MealSlot.lunch,
  name: '$name $id',
  quantity: Quantity.fromStored(100, ReferenceUnit.grams),
  nutrients: nutrients,
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
        minuteTickProvider.overrideWith((ref) => const Stream.empty()),
      ],
    );
  });
  tearDown(() {
    container.dispose();
    return db.close();
  });

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: rfTheme(Brightness.dark),
          home: const Scaffold(body: FuelScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> target(String id, GoalKind kind, double value) => container
      .read(goalRepositoryProvider)
      .upsert(
        Goal(
          id: id,
          kind: kind,
          target: value,
          startDate: _now,
          createdAt: _now,
          updatedAt: _now,
        ),
      );

  Future<void> log(FoodLogEntry e) =>
      container.read(foodLogRepositoryProvider).insert(e);

  testWidgets('known zero is 0, unknown is n/a, no target has no bar', (
    tester,
  ) async {
    await target('t1', GoalKind.protein, 100);
    await target('t2', GoalKind.fat, 70);
    // Protein is a known zero, carbs and fibre are unknown, fat is known.
    await log(
      _entry('a', const NutrientAmounts(kcal: 100, proteinG: 0, fatG: 10)),
    );
    await pump(tester);
    expect(find.text('0 / 100 g'), findsOneWidget); // known zero, target
    expect(find.text('10 / 70 g'), findsOneWidget);
    expect(find.text('n/a · no target'), findsNWidgets(2)); // carbs, fibre
    expect(find.textContaining('/ 0'), findsNothing);
    // Bars only for protein and fat (the two with a target and a value).
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
    // Diary subtitle: P is a known 0, C is unknown, F is known.
    expect(find.textContaining('P 0 · C n/a · F 10'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('known amount without a target says "no target", no bar', (
    tester,
  ) async {
    await log(
      _entry(
        'a',
        const NutrientAmounts(
          kcal: 100,
          proteinG: 30,
          carbsG: 12,
          fatG: 4,
          fibreG: 6,
        ),
      ),
    );
    await pump(tester);
    expect(find.text('30 g · no target'), findsOneWidget);
    expect(find.text('6 g · no target'), findsOneWidget);
    expect(find.textContaining(' / '), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    await unmount(tester);
  });

  testWidgets('a total with an unknown entry shows the known sum and marker', (
    tester,
  ) async {
    await target('t1', GoalKind.protein, 100);
    await log(
      _entry('a', const NutrientAmounts(kcal: 100, proteinG: 50, fibreG: 5)),
    );
    await log(_entry('b', const NutrientAmounts(kcal: 100, proteinG: 30)));
    await log(_entry('c', const NutrientAmounts(kcal: 100)));
    await pump(tester);
    expect(find.text('80 / 100 g · 1 unknown'), findsOneWidget);
    // Fibre: known by one entry only; carbs: known by none.
    expect(find.text('5 g · no target · 2 unknown'), findsOneWidget);
    expect(find.text('n/a · no target'), findsNWidgets(2)); // carbs, fat
    await unmount(tester);
  });

  testWidgets('empty day with a target reads 0 / target, fibre is a known 0', (
    tester,
  ) async {
    await target('t1', GoalKind.protein, 100);
    await pump(tester);
    expect(find.text('0 / 100 g'), findsOneWidget);
    // Nothing eaten: carbs, fat and fibre are all known zeros, not unknown.
    expect(find.text('0 g · no target'), findsNWidgets(3));
    expect(find.text('n/a · no target'), findsNothing);
    await unmount(tester);
  });
  testWidgets('day total shows the weakest provenance of the day (NUT-019)', (
    tester,
  ) async {
    const n = NutrientAmounts(kcal: 100, proteinG: 5, carbsG: 5, fatG: 1);
    await log(_entry('a', n).copyWith(provenance: DataProvenance.verified));
    await log(_entry('b', n));
    await pump(tester);
    final total = find.byKey(const Key('day-total-provenance'));
    expect(
      find.descendant(of: total, matching: find.text('Your entry')),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('a day with an estimated entry shows the estimate badge', (
    tester,
  ) async {
    const n = NutrientAmounts(kcal: 100, proteinG: 5, carbsG: 5, fatG: 1);
    await log(_entry('a', n).copyWith(provenance: DataProvenance.verified));
    await log(_entry('b', n).copyWith(provenance: DataProvenance.estimated));
    await pump(tester);
    expect(
      find.descendant(
        of: find.byKey(const Key('day-total-provenance')),
        matching: find.text('Estimate'),
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('an empty day shows no day-total provenance', (tester) async {
    await pump(tester);
    expect(find.byKey(const Key('day-total-provenance')), findsNothing);
    await unmount(tester);
  });
}
