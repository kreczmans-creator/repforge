import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/platform/camera_capability_channel.dart';
import 'package:repforge/data/platform/mobile_scanner_barcode_scanner.dart';
import 'package:repforge/features/nutrition/application/scanner_preview.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ProviderScope(overrides: _platformOverrides(), child: const RepForgeApp()),
  );
}

/// Real camera scanning exists only on Android and iOS; elsewhere the
/// providers keep their throwing defaults.
List<Override> _platformOverrides() {
  final isMobile =
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);
  if (!isMobile) return const [];

  final scanner = MobileScannerBarcodeScanner(
    capabilityChannel: const CameraCapabilityChannel(),
  );
  return [
    barcodeScannerProvider.overrideWithValue(scanner),
    scannerPreviewBuilderProvider.overrideWithValue(scanner.preview),
  ];
}
