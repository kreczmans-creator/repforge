import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/platform/fake_barcode_scanner.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/scanning/barcode_scanner.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';
import 'package:repforge/ui/theme.dart';

import '../../../helpers/pump.dart';

final _now = DateTime(2026, 11, 3, 9);
const _known = '3017624010701';
const _unknown = '2000000000008';

final class _FakeLookup implements FoodLookupService {
  LookupFailure? failure;
  Food? food;
  final List<String> asked = [];

  @override
  Future<Result<List<Food>>> search(String query, {int limit = 20}) async =>
      const Ok([]);

  @override
  Future<Result<Food?>> byBarcode(String barcode) async {
    asked.add(barcode);
    if (failure != null) return Err(lookupError(failure!));
    return Ok(food);
  }
}

Food _seed() => Food(
  id: 'u-nutella',
  name: 'Hazelnut spread',
  barcode: _known,
  profile: const NutrientProfile(
    per100: ReferenceUnit.grams,
    per100Amounts: NutrientAmounts(kcal: 539),
    provenance: DataProvenance.userEntered,
  ),
  source: FoodSource.userCreated,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late AppDatabase db;
  late FakeBarcodeScanner scanner;
  late _FakeLookup lookup;

  setUp(() {
    db = AppDatabase.inMemory();
    scanner = FakeBarcodeScanner();
    lookup = _FakeLookup();
  });
  tearDown(() => db.close());

  Future<void> pumpApp(
    WidgetTester tester, {
    String start = RfRoutes.fuelSearch,
    bool seed = true,
  }) async {
    tester.view.physicalSize = const Size(390, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    if (seed) await container.read(foodRepositoryProvider).upsert(_seed());
    container.dispose();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(FixedClock(_now)),
          foodLookupServiceProvider.overrideWithValue(lookup),
          barcodeScannerProvider.overrideWithValue(scanner),
          minuteTickProvider.overrideWith((ref) => const Stream.empty()),
        ],
        child: MaterialApp.router(
          theme: rfTheme(Brightness.dark),
          routerConfig: createRouter(initialLocation: start),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> openScan(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('scan-barcode')));
    await tester.pumpAndSettle();
  }

  Future<void> emit(WidgetTester tester, String code) async {
    scanner.emit(code);
    await tester.pumpAndSettle();
  }

  testWidgets('unavailable camera hides the action and explains', (
    tester,
  ) async {
    scanner.capabilityAnswer = ScannerCapability.noCamera;
    await pumpApp(tester);
    expect(find.byKey(const Key('scan-barcode')), findsNothing);
    expect(
      find.text('Barcode scanning is not available on this device'),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('unavailable scan screen still offers manual entry', (
    tester,
  ) async {
    scanner.capabilityAnswer = ScannerCapability.unsupported;
    await pumpApp(tester, start: RfRoutes.fuelScan);
    expect(find.textContaining('not supported here'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('scan-manual-input')), _known);
    await tester.tap(find.byKey(const Key('scan-manual-submit')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('portion-amount')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('permission rationale, allow, then scanning', (tester) async {
    scanner = FakeBarcodeScanner(
      permission: CameraPermission.denied,
      requestResults: [CameraPermission.granted],
    );
    await pumpApp(tester);
    await openScan(tester);
    expect(find.textContaining('needs the camera'), findsOneWidget);
    expect(scanner.permissionRequests, 0);
    await tester.tap(find.byKey(const Key('scan-retry')));
    await tester.pumpAndSettle();
    expect(scanner.permissionRequests, 1);
    expect(scanner.isRunning, isTrue);
    expect(find.byKey(const Key('scan-cancel')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('permanently denied offers open settings', (tester) async {
    scanner = FakeBarcodeScanner(
      permission: CameraPermission.permanentlyDenied,
    );
    await pumpApp(tester);
    await openScan(tester);
    expect(find.byKey(const Key('scan-open-settings')), findsOneWidget);
    expect(find.byKey(const Key('scan-manual-input')), findsOneWidget);
    await tester.tap(find.byKey(const Key('scan-open-settings')));
    await tester.pumpAndSettle();
    expect(scanner.settingsOpened, 1);
    await unmount(tester);
  });

  testWidgets('returning from settings with the camera allowed starts '
      'scanning without leaving the screen', (tester) async {
    scanner = FakeBarcodeScanner(
      permission: CameraPermission.permanentlyDenied,
    );
    await pumpApp(tester);
    await openScan(tester);
    expect(find.byKey(const Key('scan-open-settings')), findsOneWidget);
    // The user allows the camera in system settings and comes back.
    scanner.permission = CameraPermission.granted;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scan-cancel')), findsOneWidget);
    expect(scanner.isRunning, isTrue);
    await unmount(tester);
  });

  testWidgets('check again re-checks a permanently denied permission', (
    tester,
  ) async {
    scanner = FakeBarcodeScanner(
      permission: CameraPermission.permanentlyDenied,
    );
    await pumpApp(tester);
    await openScan(tester);
    await tester.tap(find.byKey(const Key('scan-check-again')));
    await tester.pumpAndSettle();
    // Still denied: the same guidance stays, nothing starts.
    expect(find.byKey(const Key('scan-open-settings')), findsOneWidget);
    expect(scanner.isRunning, isFalse);
    scanner.permission = CameraPermission.granted;
    await tester.tap(find.byKey(const Key('scan-check-again')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scan-cancel')), findsOneWidget);
    expect(scanner.isRunning, isTrue);
    await unmount(tester);
  });

  testWidgets('known code opens the portion sheet, logs and pops', (
    tester,
  ) async {
    await pumpApp(tester);
    await openScan(tester);
    await emit(tester, _known);
    expect(find.byKey(const Key('portion-amount')), findsOneWidget);
    await tester.enterText(find.byKey(const Key('portion-amount')), '25');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('portion-log')));
    await tester.pumpAndSettle();
    final entries = await db.select(db.foodLogEntries).get();
    expect(entries.single.amount, 25);
    expect(entries.single.name, 'Hazelnut spread');
    expect(lookup.asked, isEmpty); // found locally
    expect(find.byKey(const Key('scan-cancel')), findsNothing);
    expect(find.byKey(const Key('scan-barcode')), findsNothing);
    await unmount(tester);
  });

  testWidgets('dismissing the sheet resumes scanning, nothing logged', (
    tester,
  ) async {
    await pumpApp(tester);
    await openScan(tester);
    await emit(tester, _known);
    expect(find.byKey(const Key('portion-amount')), findsOneWidget);
    await tester.tapAt(const Offset(10, 10)); // barrier
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scan-cancel')), findsOneWidget);
    expect(scanner.isRunning, isTrue);
    expect(await db.select(db.foodLogEntries).get(), isEmpty);
    await unmount(tester);
  });

  testWidgets('unknown code: not found, create custom food pre-filled', (
    tester,
  ) async {
    await pumpApp(tester);
    await openScan(tester);
    await emit(tester, _unknown);
    expect(find.byKey(const Key('scan-not-found')), findsOneWidget);
    expect(find.textContaining('Not in the database'), findsOneWidget);
    expect(await db.select(db.foodLogEntries).get(), isEmpty);
    await tester.tap(find.byKey(const Key('scan-create-food')));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('food-barcode')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, _unknown);
    await tester.enterText(find.byKey(const Key('food-name')), 'House label');
    await tester.enterText(find.byKey(const Key('food-kcal')), '100');
    await tester.ensureVisible(find.byKey(const Key('food-save')));
    await tester.tap(find.byKey(const Key('food-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('portion-amount')), findsOneWidget);
    final foods = await db.select(db.foods).get();
    expect(foods.where((f) => f.barcode == _unknown), hasLength(1));
    await tester.enterText(find.byKey(const Key('portion-amount')), '50');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('portion-log')));
    await tester.pumpAndSettle();
    expect((await db.select(db.foodLogEntries).get()).single.amount, 50);
    await unmount(tester);
  });

  testWidgets('offline lookup shows retry and stores nothing', (tester) async {
    lookup.failure = const LookupOffline();
    await pumpApp(tester);
    await openScan(tester);
    await emit(tester, _unknown);
    expect(
      find.text("You're offline. Cached foods still work."),
      findsOneWidget,
    );
    expect(find.byKey(const Key('scan-retry')), findsOneWidget);
    expect(find.byKey(const Key('scan-search-manually')), findsOneWidget);
    expect(await db.select(db.foods).get(), hasLength(1)); // seed only
    expect(await db.select(db.foodLogEntries).get(), isEmpty);
    await tester.tap(find.byKey(const Key('scan-retry')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scan-cancel')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('malformed manual entry shows the message, no lookup', (
    tester,
  ) async {
    await pumpApp(tester);
    await openScan(tester);
    await tester.enterText(find.byKey(const Key('scan-manual-input')), '12345');
    await tester.tap(find.byKey(const Key('scan-manual-submit')));
    await tester.pumpAndSettle();
    expect(find.text('Enter 8, 12 or 13 digits.'), findsOneWidget);
    expect(lookup.asked, isEmpty);
    await tester.enterText(
      find.byKey(const Key('scan-manual-input')),
      '3017624010702',
    );
    await tester.tap(find.byKey(const Key('scan-manual-submit')));
    await tester.pumpAndSettle();
    expect(find.text('That barcode is not valid.'), findsOneWidget);
    expect(lookup.asked, isEmpty);
    await unmount(tester);
  });

  testWidgets('repeated emission of the same code causes one lookup', (
    tester,
  ) async {
    await pumpApp(tester, seed: false);
    await openScan(tester);
    scanner
      ..emit(_unknown)
      ..emit(_unknown)
      ..emit(_unknown);
    await tester.pumpAndSettle();
    expect(lookup.asked, [_unknown]);
    await unmount(tester);
  });

  testWidgets('cancel stops the scanner and leaves the screen', (tester) async {
    await pumpApp(tester);
    await openScan(tester);
    expect(scanner.isRunning, isTrue);
    await tester.tap(find.byKey(const Key('scan-cancel')));
    // Cancelling a stream subscription completes in the root zone, outside
    // fake async, so yield to the real event loop.
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pumpAndSettle();
    expect(scanner.stopped, 1); // exactly once per start (owner control)
    expect(scanner.isRunning, isFalse);
    expect(scanner.hasListener, isFalse);
    expect(find.byKey(const Key('scan-cancel')), findsNothing);
    expect(find.byKey(const Key('scan-barcode')), findsOneWidget);
    await unmount(tester);
  });
}
