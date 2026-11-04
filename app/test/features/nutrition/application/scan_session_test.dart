import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/platform/fake_barcode_scanner.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/scanning/barcode_scanner.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/nutrition/application/lookup_barcode.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/features/nutrition/application/scan_session.dart';

final _t0 = DateTime(2026, 11, 3, 9);

final class _MutableClock implements Clock {
  DateTime current = _t0;
  @override
  DateTime now() => current;
}

final _food = Food(
  id: 'off:1',
  name: 'Hazelnut spread',
  barcode: '3017624010701',
  profile: const NutrientProfile(
    per100: ReferenceUnit.grams,
    per100Amounts: NutrientAmounts(kcal: 539),
    provenance: DataProvenance.crowdsourced,
  ),
  source: FoodSource.openFoodFacts,
  createdAt: _t0,
  updatedAt: _t0,
);

final class _FakeLookup implements FoodLookupService {
  Food? food = _food;
  LookupFailure? failure;
  Completer<void>? gate;
  final List<String> asked = [];

  @override
  Future<Result<List<Food>>> search(String query, {int limit = 20}) async =>
      const Ok([]);

  @override
  Future<Result<Food?>> byBarcode(String barcode) async {
    asked.add(barcode);
    await gate?.future;
    if (failure != null) return Err(lookupError(failure!));
    return Ok(food);
  }
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  late AppDatabase db;
  late FakeBarcodeScanner scanner;
  late _FakeLookup lookup;
  late _MutableClock clock;
  late ProviderContainer container;

  void setUpWith(FakeBarcodeScanner s) {
    scanner = s;
    db = AppDatabase.inMemory();
    lookup = _FakeLookup();
    clock = _MutableClock();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
        barcodeScannerProvider.overrideWithValue(scanner),
        foodLookupServiceProvider.overrideWithValue(lookup),
      ],
    )..listen(scanSessionProvider, (_, _) {}); // keeps autoDispose alive
  }

  setUp(() => setUpWith(FakeBarcodeScanner()));
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  ScanSession session() => container.read(scanSessionProvider.notifier);
  ScanState state() => container.read(scanSessionProvider);

  test('begin starts the scanner when available and permitted', () async {
    await session().begin();
    expect(state(), isA<ScanScanning>());
    expect(scanner.started, 1);
    expect(scanner.hasListener, isTrue);
  });

  test(
    'begin reports unavailable without a camera, without starting',
    () async {
      scanner.capabilityAnswer = ScannerCapability.noCamera;
      await session().begin();
      expect((state() as ScanUnavailable).reason, ScannerCapability.noCamera);
      expect(scanner.started, 0);
    },
  );

  test('begin asks for a rationale when permission is denied', () async {
    scanner.permission = CameraPermission.denied;
    await session().begin();
    expect((state() as ScanPermissionNeeded).status, CameraPermission.denied);
    expect(scanner.permissionRequests, 0);
    expect(scanner.started, 0);
  });

  test('requestPermission granted starts scanning', () async {
    setUpWith(
      FakeBarcodeScanner(
        permission: CameraPermission.denied,
        requestResults: [CameraPermission.granted],
      ),
    );
    await session().begin();
    await session().requestPermission();
    expect(state(), isA<ScanScanning>());
    expect(scanner.started, 1);
  });

  test('refusing in the prompt leads to permanently denied guidance', () async {
    setUpWith(
      FakeBarcodeScanner(
        permission: CameraPermission.denied,
        requestResults: [CameraPermission.permanentlyDenied],
      ),
    );
    await session().begin();
    await session().requestPermission();
    expect(
      (state() as ScanPermissionNeeded).status,
      CameraPermission.permanentlyDenied,
    );
    expect(await session().openSettings(), isTrue);
    expect(scanner.settingsOpened, 1);
  });

  test('restricted permission is reported without prompting', () async {
    scanner.permission = CameraPermission.restricted;
    await session().begin();
    expect(
      (state() as ScanPermissionNeeded).status,
      CameraPermission.restricted,
    );
  });

  test('a detected code is looked up and found, scanner stopped', () async {
    await session().begin();
    scanner.emit('3017624010701');
    await _pump();
    final s = state() as ScanFound;
    expect(s.food.id, 'off:1');
    expect(s.source, BarcodeLookupSource.online);
    expect(s.barcode.raw, '3017624010701');
    expect(scanner.stopped, 1);
    expect(scanner.isRunning, isFalse);
  });

  test('a second code while looking up is ignored', () async {
    lookup.gate = Completer<void>();
    await session().begin();
    scanner.emit('3017624010701');
    await _pump();
    expect(state(), isA<ScanLookingUp>());
    scanner.emit('4006381333931');
    await _pump();
    lookup.gate!.complete();
    await _pump();
    expect(lookup.asked, ['3017624010701']);
    expect(state(), isA<ScanFound>());
  });

  test('codes emitted after a result are ignored until resume', () async {
    await session().begin();
    scanner.emit('3017624010701');
    await _pump();
    scanner.emit('4006381333931');
    await _pump();
    expect(lookup.asked, hasLength(1));
    expect(state(), isA<ScanFound>());
  });

  test('the same code is ignored for 3 seconds after a result', () async {
    await session().begin();
    scanner.emit('3017624010701');
    await _pump();
    await session().resume();
    expect(state(), isA<ScanScanning>());
    expect(scanner.started, 2);

    clock.current = _t0.add(const Duration(seconds: 2, milliseconds: 900));
    scanner.emit('3017624010701');
    await _pump();
    expect(state(), isA<ScanScanning>());
    expect(lookup.asked, hasLength(1));

    clock.current = _t0.add(const Duration(seconds: 3));
    scanner.emit('3017624010701');
    await _pump();
    // Accepted again; answered from the cache the first lookup filled.
    expect((state() as ScanFound).source, BarcodeLookupSource.local);
    expect(lookup.asked, hasLength(1));
  });

  test('a different code right after a result is accepted', () async {
    await session().begin();
    scanner.emit('3017624010701');
    await _pump();
    await session().resume();
    lookup.food = null;
    scanner.emit('4006381333931');
    await _pump();
    expect(state(), isA<ScanNotFound>());
  });

  test('a malformed hardware code fails with validation, no lookup', () async {
    await session().begin();
    scanner.emit('3017624010702');
    await _pump();
    final s = state() as ScanFailed;
    expect(s.error, isA<ValidationError>());
    expect(s.code, '3017624010702');
    expect(s.barcode, isNull);
    expect(lookup.asked, isEmpty);
    expect(scanner.isRunning, isFalse);
  });

  test('an unknown barcode ends in notFound with the barcode', () async {
    lookup.food = null;
    await session().begin();
    scanner.emit('3017624010701');
    await _pump();
    expect((state() as ScanNotFound).barcode.lookupKey, '3017624010701');
    expect(scanner.isRunning, isFalse);
  });

  test('an offline lookup fails with the typed cause and the code', () async {
    lookup.failure = const LookupOffline();
    await session().begin();
    scanner.emit('3017624010701');
    await _pump();
    final s = state() as ScanFailed;
    expect(lookupFailureOf(s.error), isA<LookupOffline>());
    expect(s.barcode!.raw, '3017624010701');
    expect(s.code, '3017624010701');
    expect(scanner.isRunning, isFalse);
  });

  test('manual entry works without a camera', () async {
    scanner.capabilityAnswer = ScannerCapability.unsupported;
    await session().begin();
    await session().submitManual(' 3017624010701 ');
    expect(state(), isA<ScanFound>());
  });

  test('manual entry works when permission is permanently denied', () async {
    scanner.permission = CameraPermission.permanentlyDenied;
    await session().begin();
    await session().submitManual('3017624010701');
    expect(state(), isA<ScanFound>());
    expect(scanner.started, 0);
  });

  test('invalid manual entry fails with the validation message', () async {
    await session().submitManual('1234');
    final s = state() as ScanFailed;
    expect((s.error as ValidationError).message, 'Enter 8, 12 or 13 digits.');
    expect(lookup.asked, isEmpty);
  });

  test('manual entry while scanning stops the scanner', () async {
    await session().begin();
    await session().submitManual('3017624010701');
    expect(scanner.isRunning, isFalse);
  });

  test('cancel stops the scanner and cancels the subscription', () async {
    await session().begin();
    await session().cancel();
    expect(scanner.stopped, 1);
    expect(scanner.hasListener, isFalse);
    scanner.emit('3017624010701');
    await _pump();
    expect(lookup.asked, isEmpty);
  });

  test('cancel discards a lookup that is still in flight', () async {
    lookup.gate = Completer<void>();
    await session().begin();
    scanner.emit('3017624010701');
    await _pump();
    await session().cancel();
    lookup.gate!.complete();
    await _pump();
    expect(state(), isA<ScanChecking>());
  });

  test('disposing the provider stops the scanner and unsubscribes', () async {
    await session().begin();
    container.dispose();
    await _pump();
    expect(scanner.stopped, 1);
    expect(scanner.hasListener, isFalse);
  });

  test('resume after permission was revoked asks for it again', () async {
    await session().begin();
    scanner.emit('3017624010701');
    await _pump();
    scanner.permission = CameraPermission.denied;
    await session().resume();
    expect(state(), isA<ScanPermissionNeeded>());
  });
}
