import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Builds the live camera preview shown on the scan screen.
///
/// The domain `BarcodeScanner` interface is Flutter-free, so the preview
/// widget comes separately from the platform adapter layer, which overrides
/// this provider in `main.dart`. The default renders nothing (tests, and
/// platforms without a camera).
final scannerPreviewBuilderProvider = Provider<Widget Function(BuildContext)>(
  (_) =>
      (_) => const SizedBox.shrink(),
);
