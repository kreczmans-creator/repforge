import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:permission_handler/permission_handler.dart' as ph;
import 'package:repforge/data/platform/camera_capability_channel.dart';
import 'package:repforge/domain/scanning/barcode_scanner.dart';

/// Camera permission operations, behind a seam so tests need no plugin.
abstract interface class CameraPermissionFacade {
  /// Current camera permission without prompting.
  Future<CameraPermission> status();

  /// Prompts the user (if the OS still allows it) and returns the result.
  Future<CameraPermission> request();

  /// Opens the OS settings page for this app.
  Future<bool> openSettings();
}

/// [CameraPermissionFacade] backed by `permission_handler`.
class PermissionHandlerFacade implements CameraPermissionFacade {
  /// Creates the facade.
  const PermissionHandlerFacade();

  @override
  Future<CameraPermission> status() async =>
      _map(await ph.Permission.camera.status);

  @override
  Future<CameraPermission> request() async =>
      _map(await ph.Permission.camera.request());

  @override
  Future<bool> openSettings() => ph.openAppSettings();

  // Limited only applies to photos on iOS; treated as granted if it appears.
  static CameraPermission _map(ph.PermissionStatus s) {
    if (s.isGranted || s.isLimited) return CameraPermission.granted;
    if (s.isPermanentlyDenied) return CameraPermission.permanentlyDenied;
    if (s.isRestricted) return CameraPermission.restricted;
    return CameraPermission.denied;
  }
}

/// [BarcodeScanner] on top of `mobile_scanner` and `permission_handler`.
///
/// This file and `camera_capability_channel.dart` are the only places that
/// import the scanning plugins (adapter boundary).
class MobileScannerBarcodeScanner implements BarcodeScanner {
  /// Creates the adapter. [controller] and [permissions] are injectable.
  MobileScannerBarcodeScanner({
    required this.capabilityChannel,
    this.permissions = const PermissionHandlerFacade(),
    MobileScannerController? controller,
  }) : // detectionSpeed.normal: a detection every 250 ms while a code is in
       // view, duplicates included. noDuplicates would suppress re-scanning
       // the same product after the lookup sheet is dismissed, so the
       // consumer must stop() (or ignore repeats) after the first code.
       // autoStart is false so the camera only runs between start()/stop().
       controller =
           controller ??
           MobileScannerController(
             formats: const [
               BarcodeFormat.ean13,
               BarcodeFormat.ean8,
               BarcodeFormat.upcA,
               BarcodeFormat.upcE,
             ],
             autoStart: false,
           ) {
    _subscription = this.controller.barcodes.listen(_onCapture);
  }

  /// Native camera-presence query.
  final CameraCapabilityChannel capabilityChannel;

  /// Camera permission operations.
  final CameraPermissionFacade permissions;

  /// The underlying controller (used by [preview]).
  final MobileScannerController controller;

  final StreamController<String> _codes = StreamController<String>.broadcast();
  StreamSubscription<BarcodeCapture>? _subscription;
  bool _disposed = false;

  void _onCapture(BarcodeCapture capture) {
    if (_codes.isClosed) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        _codes.add(value);
        // One code per frame batch is enough; the first valid one wins.
        return;
      }
    }
  }

  @override
  Future<ScannerCapability> capability() => capabilityChannel.query();

  @override
  Future<CameraPermission> permissionStatus() => permissions.status();

  @override
  Future<CameraPermission> requestPermission() => permissions.request();

  @override
  Future<bool> openAppSettings() => permissions.openSettings();

  @override
  Stream<String> get codes => _codes.stream;

  @override
  Future<void> start() async {
    if (_disposed) return;
    try {
      await controller.start();
    } on MobileScannerException catch (e) {
      debugPrint('Scanner start failed: $e');
    } on Object catch (e) {
      debugPrint('Scanner start failed unexpectedly: $e');
    }
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    try {
      await controller.stop();
    } on MobileScannerException catch (e) {
      debugPrint('Scanner stop failed: $e');
    } on Object catch (e) {
      debugPrint('Scanner stop failed unexpectedly: $e');
    }
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    _subscription = null;
    try {
      await controller.dispose();
    } on Object catch (e) {
      debugPrint('Scanner dispose failed: $e');
    }
    await _codes.close();
  }

  /// Camera preview for the scan screen.
  Widget preview(BuildContext context) => MobileScanner(
    controller: controller,
    // fit defaults to BoxFit.cover.
    errorBuilder: (context, error) => const _ScannerError(),
  );
}

class _ScannerError extends StatelessWidget {
  const _ScannerError();

  @override
  Widget build(BuildContext context) => const ColoredBox(
    color: Colors.black,
    child: Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'The camera could not be started. Check that camera access is '
          'allowed for RepForge and that no other app is using the camera, '
          'or enter the barcode by hand.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white),
        ),
      ),
    ),
  );
}
