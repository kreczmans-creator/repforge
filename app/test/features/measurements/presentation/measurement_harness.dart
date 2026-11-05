import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/files/user_file_gateway.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';

/// Clock whose time a test can move.
class MovableClock implements Clock {
  MovableClock(this.value);
  DateTime value;

  @override
  DateTime now() => value;
}

/// Local "now" used by the presentation tests: 2026-11-05 14:30.
final DateTime testNow = DateTime(2026, 11, 5, 14, 30);

var _seq = 0;

/// A reading of [site] at local time [at].
Measurement reading(MeasurementSite site, double value, DateTime at) {
  final id = 'm${_seq++}';
  return Measurement(
    id: id,
    site: site,
    value: site.isWeight
        ? MeasurementValue.kg(Kilograms.fromStored(value))
        : MeasurementValue.cm(Centimetres.fromStored(value)),
    recordedAt: at.toUtc(),
    createdAt: at.toUtc(),
    updatedAt: at.toUtc(),
  );
}

/// Pumps the real app at [location] with an in-memory database that holds
/// [seed], a fixed clock, an optional file [gateway] (default: unavailable)
/// and the given view size and text scale. Returns the
/// container for assertions.
Future<ProviderContainer> pumpTrack(
  WidgetTester tester,
  AppDatabase db, {
  String location = RfRoutes.track,
  List<Measurement> seed = const [],
  Clock? clock,
  UserFileGateway? gateway,
  Size size = const Size(390, 3000),
  double textScale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(clock ?? FixedClock(testNow)),
      if (gateway != null) userFileGatewayProvider.overrideWithValue(gateway),
    ],
  );
  addTearDown(container.dispose);
  if (seed.isNotEmpty) {
    await tester.runAsync(
      () => container.read(measurementRepositoryProvider).insertAll(seed),
    );
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepForgeApp(router: createRouter(initialLocation: location)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

/// Scrolls the first list down in steps, failing on any layout exception.
Future<void> scrollThrough(WidgetTester tester, {int steps = 12}) async {
  final list = find.byType(Scrollable).first;
  for (var i = 0; i < steps; i++) {
    await tester.drag(list, const Offset(0, -400));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }
}

/// The stored readings, newest first. drift streams need real async, which
/// fake-async widget tests only get inside `runAsync`.
Future<List<Measurement>> storedReadings(
  WidgetTester tester,
  ProviderContainer container,
) async => (await tester.runAsync(
  () => container.read(measurementRepositoryProvider).watchAll().first,
))!;

/// Runs [action] (a use case call or a repository write) with real async.
Future<T> realAsync<T>(
  WidgetTester tester,
  Future<T> Function() action,
) async => (await tester.runAsync(action)) as T;
