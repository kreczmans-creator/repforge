import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/platform/fake_barcode_scanner.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/scanner_preview.dart';

/// End-to-end flows on a real device or emulator. The first test uses an
/// in-memory database so it leaves nothing behind; the last test uses the
/// real on-device database file to prove that the production open path,
/// migrations and persistence across an app rebuild work on the device.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(
    WidgetTester tester, {
    AppDatabase? db,
    List<Override> overrides = const [],
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (db != null) databaseProvider.overrideWithValue(db),
          ...overrides,
        ],
        child: const RepForgeApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// On a device, `pumpAndSettle` returns as soon as no frame is scheduled,
  /// which happens while the app awaits a database write (no frame is
  /// pending during I/O). Pump until [finder] matches or [timeout] elapses.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isEmpty) {
      if (DateTime.now().isAfter(end)) {
        fail('Timed out waiting for $finder');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  /// Counterpart of [pumpUntil] for a widget that must disappear.
  Future<void> pumpUntilGone(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 15),
  }) async {
    final end = DateTime.now().add(timeout);
    while (finder.evaluate().isNotEmpty) {
      if (DateTime.now().isAfter(end)) {
        fail('Timed out waiting for $finder to disappear');
      }
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  /// Forms are lazy `ListView`s: on a phone-sized screen the save button is
  /// not built until scrolled into view, so `ensureVisible` cannot find it.
  /// The soft keyboard is dismissed first: its inset animation re-lays the
  /// list after the scroll and can unbuild the target again (run
  /// 41818013580 found `food-save` and then lost it before the tap).
  Future<void> scrollTo(WidgetTester tester, Finder finder) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    for (var attempt = 0; attempt < 3; attempt++) {
      await tester.scrollUntilVisible(
        finder,
        200,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      if (finder.evaluate().isNotEmpty) return;
    }
    fail('Could not keep $finder in view');
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
    // A close that never completes (streams still open after a failed
    // assertion) must not hang the whole emulator job.
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 10), onTimeout: () {}),
    );
    await pumpApp(tester, db: db);

    // Dashboard starts empty.
    expect(find.byKey(const Key('latest-weight')), findsOneWidget);
    expect(find.text('—'), findsOneWidget);

    // Track: log a weight.
    await tester.tap(find.byKey(const Key('nav-track')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('weight-input')), '83.2');
    await tester.tap(find.byKey(const Key('save-weight')));
    await pumpUntil(tester, find.text('83.2 kg'));
    expect(find.text('83.2 kg'), findsOneWidget);

    // Settings: calorie target.
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target-calories')), '2100');
    await scrollTo(tester, find.byKey(const Key('save-targets')));
    await tester.tap(find.byKey(const Key('save-targets')));
    await pumpUntil(tester, find.text('Targets saved'));
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
    await scrollTo(tester, find.byKey(const Key('food-save')));
    await tester.tap(find.byKey(const Key('food-save')));
    // Portion sheet opens for the new food once the insert completes.
    await pumpUntil(tester, find.byKey(const Key('portion-amount')));
    expect(find.byKey(const Key('portion-amount')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('portion-amount')), '150');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('portion-log')));
    // Back on the diary: 380 × 1.5 = 570 kcal.
    await pumpUntil(tester, find.text('Test oats'));
    expect(find.text('Test oats'), findsOneWidget);
    expect(find.text('570'), findsWidgets);

    // Dashboard reflects both after a simulated restart on the same db.
    await restart(tester, db: db);
    await pumpUntil(tester, find.text('570 of 2100'));
    expect(find.text('570 of 2100'), findsOneWidget);
    expect(find.text('83.2'), findsOneWidget);
  });

  testWidgets('scan a known barcode and log it (fake scanner)', (tester) async {
    final db = AppDatabase.inMemory();
    addTearDown(
      () => db.close().timeout(const Duration(seconds: 10), onTimeout: () {}),
    );
    final now = DateTime.now();
    final seeder = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    await seeder
        .read(foodRepositoryProvider)
        .upsert(
          Food(
            id: 'it-hazelnut',
            name: 'Scan test spread',
            barcode: '3017624010701',
            profile: const NutrientProfile(
              per100: ReferenceUnit.grams,
              per100Amounts: NutrientAmounts(kcal: 500),
              provenance: DataProvenance.userEntered,
            ),
            source: FoodSource.userCreated,
            createdAt: now,
            updatedAt: now,
          ),
        );
    seeder.dispose();

    final scanner = FakeBarcodeScanner();
    await pumpApp(
      tester,
      db: db,
      overrides: [
        barcodeScannerProvider.overrideWithValue(scanner),
        scannerPreviewBuilderProvider.overrideWithValue(
          (_) => const ColoredBox(color: Colors.black),
        ),
        foodLookupServiceProvider.overrideWithValue(_NoMatchLookup()),
      ],
    );

    Future<void> openScan() async {
      await tester.tap(find.byKey(const Key('nav-fuel')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('log-food')));
      await tester.pumpAndSettle();
      await pumpUntil(tester, find.byKey(const Key('scan-barcode')));
      await tester.tap(find.byKey(const Key('scan-barcode')));
      await pumpUntil(tester, find.byKey(const Key('scan-cancel')));
    }

    await openScan();
    scanner
      ..emit('3017624010701')
      ..emit('3017624010701'); // same label held in view
    await pumpUntil(tester, find.byKey(const Key('portion-amount')));
    await tester.enterText(find.byKey(const Key('portion-amount')), '25');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('portion-log')));
    await pumpUntil(tester, find.text('Scan test spread'));
    expect(find.text('Scan test spread'), findsOneWidget);
    expect(find.text('125'), findsWidgets); // 500 kcal/100 g x 25 g

    // A further emission shortly after must do nothing: the scanner is
    // stopped, no sheet opens and no second entry appears.
    scanner.emit('3017624010701');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('portion-amount')), findsNothing);
    expect(find.text('Scan test spread'), findsOneWidget);
    expect(await db.select(db.foodLogEntries).get(), hasLength(1));

    // Not-found path: nothing is created or logged.
    await tester.tap(find.byKey(const Key('log-food')));
    await tester.pumpAndSettle();
    await pumpUntil(tester, find.byKey(const Key('scan-barcode')));
    await tester.tap(find.byKey(const Key('scan-barcode')));
    await pumpUntil(tester, find.byKey(const Key('scan-cancel')));
    scanner.emit('2000000000008');
    await pumpUntil(tester, find.byKey(const Key('scan-not-found')));
    expect(find.byKey(const Key('scan-create-food')), findsOneWidget);
    expect(find.byKey(const Key('scan-search-manually')), findsOneWidget);
    expect(await db.select(db.foodLogEntries).get(), hasLength(1));
    expect(await db.select(db.foods).get(), hasLength(1));
  });

  testWidgets('real on-device database opens, migrates, persists a weight '
      'and a target across a fresh connection', (tester) async {
    await pumpApp(tester); // production providers: real file database
    await tester.tap(find.byKey(const Key('nav-track')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('weight-input')), '77.7');
    await tester.enterText(
      find.byKey(const Key('note-input')),
      'integration-test',
    );
    await tester.tap(find.byKey(const Key('save-weight')));
    await pumpUntil(tester, find.text('77.7 kg'));
    expect(find.text('77.7 kg'), findsOneWidget);

    // WP 4 B1: a target written through Settings must survive a restart.
    // restart() disposes the ProviderScope, which closes the file database
    // (databaseProvider.onDispose) and the rebuilt app opens a FRESH
    // connection to the same persisted file.
    await tester.tap(find.byKey(const Key('nav-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target-calories')), '2345');
    await scrollTo(tester, find.byKey(const Key('save-targets')));
    await tester.tap(find.byKey(const Key('save-targets')));
    await pumpUntil(tester, find.text('Targets saved'));

    await restart(tester);
    await pumpUntil(tester, find.text('0 of 2345'));
    expect(find.text('0 of 2345'), findsOneWidget);

    // Clean up the target so repeated runs on one device start clean.
    await tester.tap(find.byKey(const Key('open-settings')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('target-calories')), '');
    await scrollTo(tester, find.byKey(const Key('save-targets')));
    await tester.tap(find.byKey(const Key('save-targets')));
    await pumpUntil(tester, find.text('Targets saved'));
    await tester.pageBack();
    await pumpUntilGone(tester, find.text('0 of 2345'));

    await tester.tap(find.byKey(const Key('nav-track')));
    await pumpUntil(tester, find.textContaining('integration-test'));
    expect(find.textContaining('integration-test'), findsOneWidget);

    // Clean up so repeated runs on one device do not accumulate rows.
    final tile = find.ancestor(
      of: find.textContaining('integration-test'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: tile, matching: find.byTooltip('Delete entry')),
    );
    await pumpUntilGone(tester, find.textContaining('integration-test'));
    expect(find.textContaining('integration-test'), findsNothing);
  });
}

/// Online lookup that knows nothing, so unknown barcodes are "not found".
final class _NoMatchLookup implements FoodLookupService {
  @override
  Future<Result<List<Food>>> search(String query, {int limit = 20}) async =>
      const Ok([]);

  @override
  Future<Result<Food?>> byBarcode(String barcode) async => const Ok(null);
}
