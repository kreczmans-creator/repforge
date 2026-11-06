import 'package:integration_test/integration_test_driver.dart';

/// Host side of `flutter drive` for integration tests run in profile mode
/// (`tool/device_timing.sh`). It writes the test's `reportData` to
/// `build/integration_response_data.json`, also when the test fails (the
/// harness puts its error there). The full device timing run takes minutes,
/// so the driver waits up to 60.
///
/// `package:flutter_driver` is not a direct dev dependency: this file
/// imports only `integration_test`, which depends on it, and `flutter drive`
/// resolves it through the package config (verified: the driver compiles
/// and the analyzer is clean without it).
Future<void> main() => integrationDriver(
  writeResponseOnFailure: true,
  timeout: const Duration(minutes: 60),
);
