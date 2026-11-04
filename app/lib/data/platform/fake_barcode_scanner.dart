import 'dart:async';

import 'package:repforge/domain/scanning/barcode.dart';
import 'package:repforge/domain/scanning/barcode_scanner.dart';

/// Test double for [BarcodeScanner], used by unit, widget and integration
/// tests so flows run without a camera (PLT-001(2)). Fakes over mocks.
final class FakeBarcodeScanner implements BarcodeScanner {
  FakeBarcodeScanner({
    this.onStart,
    this.capabilityAnswer = ScannerCapability.available,
    this.permission = CameraPermission.granted,
    List<CameraPermission> requestResults = const [],
    this.settingsOpens = true,
  }) : _requestResults = List.of(requestResults);

  /// Optional gate awaited inside [start] (after it is counted), to simulate
  /// a slow camera start.
  Future<void> Function()? onStart;

  /// Answer of [capability].
  ScannerCapability capabilityAnswer;

  /// Answer of [permissionStatus]; updated by [requestPermission].
  CameraPermission permission;

  /// What [openAppSettings] returns.
  bool settingsOpens;

  final List<CameraPermission> _requestResults;
  final StreamController<ScannedCode> _codes =
      StreamController<ScannedCode>.broadcast();

  /// Times [start] was called.
  int started = 0;

  /// Times [stop] was called.
  int stopped = 0;

  /// Times [dispose] was called.
  int disposed = 0;

  /// Times [requestPermission] was called.
  int permissionRequests = 0;

  /// Times [openAppSettings] was called.
  int settingsOpened = 0;

  /// Whether detection is currently running.
  bool get isRunning => _running;
  bool _running = false;

  /// Whether anything is listening to [codes].
  bool get hasListener => _codes.hasListener;

  /// Simulates the hardware detecting [code]. Like a real camera it only
  /// reports while started.
  void emit(String code, {BarcodeFormat? format}) {
    if (_running) _codes.add(ScannedCode(code, format: format));
  }

  @override
  Future<ScannerCapability> capability() async => capabilityAnswer;

  @override
  Future<CameraPermission> permissionStatus() async => permission;

  /// Pops the next scripted result; once the script is exhausted the current
  /// [permission] is returned unchanged.
  @override
  Future<CameraPermission> requestPermission() async {
    permissionRequests++;
    if (_requestResults.isNotEmpty) permission = _requestResults.removeAt(0);
    return permission;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return settingsOpens;
  }

  @override
  Stream<ScannedCode> get codes => _codes.stream;

  @override
  Future<void> start() async {
    started++;
    await onStart?.call();
    _running = true;
  }

  @override
  Future<void> stop() async {
    stopped++;
    _running = false;
  }

  @override
  Future<void> dispose() async {
    disposed++;
    _running = false;
    await _codes.close();
  }
}
