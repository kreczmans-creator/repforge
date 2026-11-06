import 'package:integration_test/integration_test_driver.dart';

/// Host side of `flutter drive` for integration tests run in profile mode
/// (`tool/device_timing.sh`). It writes the test's `reportData` to
/// `build/integration_response_data.json`.
Future<void> main() => integrationDriver();
