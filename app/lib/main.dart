import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/platform/camera_capability_channel.dart';
import 'package:repforge/data/platform/mobile_scanner_barcode_scanner.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/features/nutrition/application/scanner_preview.dart';
import 'package:repforge/features/recipes/application/recipe_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer(overrides: _platformOverrides());
  runApp(
    UncontrolledProviderScope(container: container, child: const RepForgeApp()),
  );
  // One-time starter-recipe import (WP 7). Started after the first frame is
  // scheduled and not awaited, so it never delays startup. A failure leaves
  // the import unrecorded and it is retried on the next launch.
  unawaited(_importStarterRecipes(container));
}

Future<void> _importStarterRecipes(ProviderContainer container) async {
  final result = await container.read(importLegacyRecipesProvider).call();
  if (result case Err(:final error)) {
    debugPrint('Starter recipe import failed: ${error.message}');
  }
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
