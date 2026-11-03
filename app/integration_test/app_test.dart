import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';

/// End-to-end flows on a real device or emulator. The first test uses an
/// in-memory database so it leaves nothing behind; the last test uses the
/// real on-device database file to prove that the production open path,
/// migrations and persistence across an app rebuild work on the device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(WidgetTester tester, {AppDatabase? db}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [if (db != null) databaseProvider.overrideWithValue(db)],
        child: const RepForgeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> restart(WidgetTester tester, {AppDatabase? db}) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await pumpApp(tester, db: db);
  }

  testWidgets('weight, targets and food logging end to end (in-memory db)', (
    tester,
  ) async {
    final db = AppDatabase.inMemory();
    addTearDown(db.close);
    await pumpApp(tester, db: db);

    // Dashboard starts empty.
    expect(find.byKey(const Key('latest-weight')), findsOneWidget);
    expect(find.text('—'), findsOneWidget);

    // Track: log a weight.
    await tester.tap(find.byKey(const Key('nav-track')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('weight-input')), '83.2');
    await tester.tap(find.byKey(const Key('save-weight')));
    await tester.pumpAndSettle();
    expect(find.text('83.2 kg'), findsOneWidget);

    // Settings: calorie target.
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target-calories')), '2100');
    await tester.ensureVisible(find.byKey(const Key('save-targets')));
    await tester.tap(find.byKey(const Key('save-targets')));
    await tester.pumpAndSettle();
    expect(find.text('Targets saved'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    // Fuel: create a custom food through the UI and log 150 g of it.
    await tester.tap(find.byKey(const Key('nav-fuel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('log-food')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('new-food')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('food-name')), 'Test oats');
    await tester.enterText(find.byKey(const Key('food-kcal')), '380');
    await tester.enterText(find.byKey(const Key('food-protein')), '13');
    await tester.enterText(find.byKey(const Key('food-carbs')), '60');
    await tester.enterText(find.byKey(const Key('food-fat')), '7');
    await tester.ensureVisible(find.byKey(const Key('food-save')));
    await tester.tap(find.byKey(const Key('food-save')));
    await tester.pumpAndSettle();
    // Portion sheet opens for the new food.
    expect(find.byKey(const Key('portion-amount')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('portion-amount')), '150');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('portion-log')));
    await tester.pumpAndSettle();
    // Back on the diary: 380 × 1.5 = 570 kcal.
    expect(find.text('Test oats'), findsOneWidget);
    expect(find.text('570'), findsWidgets);

    // Dashboard reflects both after a simulated restart on the same db.
    await restart(tester, db: db);
    expect(find.text('570 of 2100'), findsOneWidget);
    expect(find.text('83.2'), findsOneWidget);
  });

  testWidgets('real on-device database opens, migrates and persists', (
    tester,
  ) async {
    await pumpApp(tester); // production providers: real file database
    await tester.tap(find.byKey(const Key('nav-track')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('weight-input')), '77.7');
    await tester.enterText(
      find.byKey(const Key('note-input')),
      'integration-test',
    );
    await tester.tap(find.byKey(const Key('save-weight')));
    await tester.pumpAndSettle();
    expect(find.text('77.7 kg'), findsOneWidget);

    await restart(tester);
    await tester.tap(find.byKey(const Key('nav-track')));
    await tester.pumpAndSettle();
    expect(find.textContaining('integration-test'), findsOneWidget);

    // Clean up so repeated runs on one device do not accumulate rows.
    final tile = find.ancestor(
      of: find.textContaining('integration-test'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: tile, matching: find.byTooltip('Delete entry')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('integration-test'), findsNothing);
  });
}
