import 'package:flutter/services.dart';
import 'package:repforge/domain/scanning/barcode_scanner.dart';

/// Asks the host platform whether the device has any camera (PLT-003).
///
/// One method, `hasCamera`, implemented natively in `MainActivity.kt`
/// (`FEATURE_CAMERA_ANY`) and `AppDelegate.swift`
/// (`AVCaptureDevice.default(for: .video)`). Never throws.
class CameraCapabilityChannel {
  /// Creates the channel; [channel] is overridable for tests.
  const CameraCapabilityChannel({
    this.channel = const MethodChannel(channelName),
  });

  /// Name shared with the Kotlin and Swift implementations.
  static const String channelName = 'com.tempest.repforge/camera';

  /// Native method returning a bool.
  static const String hasCameraMethod = 'hasCamera';

  /// The underlying method channel.
  final MethodChannel channel;

  /// true maps to available, false to noCamera; a missing native handler or
  /// any platform error (or a non-bool reply) maps to unsupported.
  Future<ScannerCapability> query() async {
    try {
      final hasCamera = await channel.invokeMethod<bool>(hasCameraMethod);
      if (hasCamera == null) {
        return ScannerCapability.unsupported;
      }
      return hasCamera
          ? ScannerCapability.available
          : ScannerCapability.noCamera;
    } on MissingPluginException {
      return ScannerCapability.unsupported;
    } on PlatformException {
      return ScannerCapability.unsupported;
    }
  }
}
