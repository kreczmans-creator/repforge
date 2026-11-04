import 'package:meta/meta.dart';
import 'package:repforge/domain/scanning/barcode.dart';

/// A string detected by the hardware together with the symbology it reported.
@immutable
final class ScannedCode {
  const ScannedCode(this.raw, {this.format});

  /// The digits as detected.
  final String raw;

  /// The symbology the hardware reported, or `null` when unknown (manual
  /// entry, or a symbology the app does not use).
  final BarcodeFormat? format;

  @override
  bool operator ==(Object other) =>
      other is ScannedCode && other.raw == raw && other.format == format;

  @override
  int get hashCode => Object.hash(raw, format);

  @override
  String toString() => 'ScannedCode($raw, $format)';
}

/// Whether this device can scan barcodes at all (PLT-003).
enum ScannerCapability {
  /// A camera and a scanning engine are present.
  available,

  /// The device has no usable camera.
  noCamera,

  /// Scanning is not supported on this platform or build.
  unsupported,
}

/// State of the camera permission (PLT-004).
enum CameraPermission {
  /// The user allowed camera access.
  granted,

  /// Not granted yet, or refused once; the app may ask again.
  denied,

  /// Refused with "don't ask again"; only system settings can change it.
  permanentlyDenied,

  /// Blocked by the OS or a policy (for example parental controls).
  restricted,
}

/// Camera and barcode scanning behind a platform abstraction (PLT-001,
/// PLT-002).
///
/// Feature code uses only this interface; it never imports a camera or
/// scanner plugin. The platform adapter implements it and is bound in
/// `barcodeScannerProvider` at the composition root; tests use
/// `FakeBarcodeScanner`. The camera preview widget is not part of this
/// Flutter-free interface: the adapter layer supplies it separately through
/// the presentation-level `scannerPreviewBuilderProvider`.
abstract interface class BarcodeScanner {
  /// Reports whether scanning can work on this device.
  Future<ScannerCapability> capability();

  /// The current camera permission, without prompting.
  Future<CameraPermission> permissionStatus();

  /// Shows the system permission prompt (when allowed) and returns the result.
  Future<CameraPermission> requestPermission();

  /// Opens the system settings page for this app. `false` if it could not.
  Future<bool> openAppSettings();

  /// Codes as detected by the hardware, with the reported symbology. The same
  /// label may be reported many times in a row, and a string may not be a
  /// valid barcode.
  Stream<ScannedCode> get codes;

  /// Starts the camera and detection. Idempotent.
  Future<void> start();

  /// Stops detection and releases the camera, keeping the scanner reusable.
  Future<void> stop();

  /// Releases everything. The scanner cannot be used afterwards.
  Future<void> dispose();
}
