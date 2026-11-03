import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';
import 'package:repforge/features/nutrition/presentation/food_search_screen.dart';
import 'package:repforge/features/nutrition/presentation/fuel_screen.dart';
import 'package:repforge/ui/theme.dart';

import '../../helpers/pump.dart';

final _now = DateTime(2026, 11, 3, 9); // local, morning

/// Fake online lookup: one Chobani hit, or a configurable failure.
final class _FakeLookup implements FoodLookupService {
  _FakeLookup({this.failure});
  final LookupFailure? failure;
  int calls = 0;

  @override
  Future<Result<List<Food>>> search(String query, {int limit = 20}) async {
    calls++;
    if (failure != null) return Err(lookupError(failure!));
    return Ok([
      Food(
        id: 'off:1',
        name: 'Greek Yogurt',
        brand: 'Chobani',
        barcode: '1',
        profile: const NutrientProfile(
          per100: ReferenceUnit.grams,
          per100Amounts: NutrientAmounts(
            kcal: 59,
            proteinG: 10,
            carbsG: 3.6,
            fatG: 0.4,
          ),
          provenance: DataProvenance.crowdsourced,
        ),
        source: FoodSource.openFoodFacts,
        createdAt: _now,
        updatedAt: _now,
      ),
    ]);
  }

  @override
  Future<Result<Food?>> byBarcode(String barcode) async => const Ok(null);
}

Widget _app(AppDatabase db, FoodLookupService lookup, Widget home) =>
    ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(_now)),
        foodLookupServiceProvider.overrideWithValue(lookup),
        minuteTickProvider.overrideWith((ref) => const Stream.empty()),
      ],
      child: MaterialApp(theme: rfTheme(Brightness.dark), home: home),
    );

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  /// Tall viewport so the lazily built diary sections are all on screen.
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('search online, choose a portion, log, see it in the diary', (
    tester,
  ) async {
    tallView(tester);
    final lookup = _FakeLookup();
    await tester.pumpWidget(
      _app(db, lookup, const Scaffold(body: FuelScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Nothing logged.'), findsNWidgets(4));

    // Open the search screen directly (navigation is covered by router test).
    await tester.pumpWidget(_app(db, lookup, const FoodSearchScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food-query')), 'greek');
    await tester.pump(const Duration(milliseconds: 500)); // debounce
    await tester.pumpAndSettle();
    expect(lookup.calls, 1);
    expect(find.byKey(const Key('online-off:1')), findsOneWidget);
    expect(find.text('Community data'), findsOneWidget);

    await tester.tap(find.byKey(const Key('online-off:1')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('portion-amount')), findsOneWidget);
    expect(find.text('Breakfast'), findsOneWidget); // default meal at 09:00
    await tester.enterText(find.byKey(const Key('portion-amount')), '170');
    await tester.pumpAndSettle();
    expect(find.text('100'), findsOneWidget); // 59 × 1.7 = 100.3 kcal preview
    await tester.tap(find.byKey(const Key('portion-log')));
    await tester.pumpAndSettle();

    final entries = await db.select(db.foodLogEntries).get();
    expect(entries.single.name, 'Greek Yogurt (Chobani)');
    expect(entries.single.amount, 170);
    expect(entries.single.meal, 'breakfast');
    // Online food cached locally.
    expect((await db.select(db.foods).get()).single.id, 'off:1');

    await tester.pumpWidget(
      _app(db, lookup, const Scaffold(body: FuelScreen())),
    );
    await tester.pumpAndSettle();
    expect(find.text('Greek Yogurt (Chobani)'), findsOneWidget);
    expect(find.textContaining('Breakfast · 100 kcal'), findsOneWidget);
    expect(find.text('Nothing logged.'), findsNWidgets(3));
    await unmount(tester);
  });

  testWidgets('offline search still shows local foods', (tester) async {
    final lookup = _FakeLookup(failure: const LookupOffline());
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(_now)),
      ],
    );
    addTearDown(container.dispose);
    await container
        .read(foodRepositoryProvider)
        .upsert(
          Food(
            id: 'u1',
            name: 'Crème fraîche',
            profile: const NutrientProfile(
              per100: ReferenceUnit.grams,
              per100Amounts: NutrientAmounts(
                kcal: 292,
                proteinG: 2.4,
                carbsG: 2.9,
                fatG: 30,
              ),
              provenance: DataProvenance.userEntered,
            ),
            source: FoodSource.userCreated,
            createdAt: _now,
            updatedAt: _now,
          ),
        );
    await tester.pumpWidget(_app(db, lookup, const FoodSearchScreen()));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food-query')), 'creme');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('local-u1')), findsOneWidget);
    expect(find.byKey(const Key('online-failure')), findsOneWidget);
    expect(find.textContaining('offline'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('day navigation moves away from today and back', (tester) async {
    await tester.pumpWidget(
      _app(db, _FakeLookup(), const Scaffold(body: FuelScreen())),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('day-previous')));
    await tester.pumpAndSettle();
    expect(find.text('Mon 2 Nov'), findsOneWidget);
    expect(find.byKey(const Key('day-today')), findsOneWidget);
    await tester.tap(find.byKey(const Key('day-today')));
    await tester.pumpAndSettle();
    expect(find.text('Today'), findsOneWidget);
    await unmount(tester);
  });
}
