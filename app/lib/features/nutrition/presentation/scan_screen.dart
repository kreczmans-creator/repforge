import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/scanning/barcode_scanner.dart';
import 'package:repforge/features/nutrition/application/lookup_barcode.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';
import 'package:repforge/features/nutrition/application/scan_session.dart';
import 'package:repforge/features/nutrition/application/scanner_preview.dart';
import 'package:repforge/features/nutrition/presentation/portion_sheet.dart';
import 'package:repforge/features/nutrition/presentation/provenance_badge.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Scan a barcode (NUT-006, PLT-001..004). Renders `scanSessionProvider`;
/// all scanning logic lives in `ScanSession`. Pops with the logged
/// `FoodLogEntry` when the user logs the found food.
class ScanScreen extends ConsumerStatefulWidget {
  const ScanScreen({super.key});

  @override
  ConsumerState<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends ConsumerState<ScanScreen> {
  final _manual = TextEditingController();
  late final ScanSession _session;
  bool _sheetOpen = false;

  @override
  void initState() {
    super.initState();
    _session = ref.read(scanSessionProvider.notifier);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_session.begin());
    });
  }

  @override
  void dispose() {
    // Leaving the screen (back or cancel) disposes the autoDispose session,
    // whose onDispose cancels the subscription and stops the scanner.
    _manual.dispose();
    super.dispose();
  }

  Future<void> _cancel() async {
    await _session.cancel();
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  Future<void> _logFood(Food food, {required bool resumeOnDismiss}) async {
    if (_sheetOpen) return;
    _sheetOpen = true;
    final now = ref.read(clockProvider).now().toLocal();
    final entry = await showPortionSheet(
      context,
      food,
      initialMeal: defaultMealFor(now),
    );
    _sheetOpen = false;
    if (!mounted) return;
    if (entry != null) {
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop(entry);
      return;
    }
    if (resumeOnDismiss) unawaited(_session.resume());
  }

  Future<void> _createFood(String barcode) async {
    final food = await context.push<Food>(
      Uri(
        path: RfRoutes.fuelNewFood,
        queryParameters: {'barcode': barcode},
      ).toString(),
    );
    if (!mounted || food == null) return;
    await _logFood(food, resumeOnDismiss: false);
  }

  void _searchManually() {
    if (Navigator.of(context).canPop()) {
      unawaited(_cancel());
    } else {
      unawaited(context.push(RfRoutes.fuelSearch));
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<ScanState>(scanSessionProvider, (_, next) {
      if (next is ScanFound) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) unawaited(_logFood(next.food, resumeOnDismiss: true));
        });
      }
    });
    final state = ref.watch(scanSessionProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan barcode')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const SizedBox(height: RfSpace.s3),
          ..._body(context, state),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }

  List<Widget> _body(BuildContext context, ScanState state) {
    final theme = Theme.of(context);
    const gap = SizedBox(height: RfSpace.s3);
    switch (state) {
      case ScanChecking():
        return [Semantics(label: 'Checking camera', child: const RfLoading())];
      case ScanUnavailable(:final reason):
        return [
          RfEmptyState(
            key: const Key('scan-unavailable'),
            icon: Icons.no_photography_outlined,
            message: reason == ScannerCapability.noCamera
                ? 'This device has no camera. Enter the barcode instead.'
                : 'Scanning is not supported here. Enter the barcode instead.',
          ),
          gap,
          _manualEntry(),
          gap,
          _searchButton(),
        ];
      case ScanPermissionNeeded(:final status):
        final denied = status == CameraPermission.denied;
        return [
          RfEmptyState(
            key: const Key('scan-permission'),
            icon: Icons.camera_alt_outlined,
            message: denied
                ? 'RepForge needs the camera to read barcodes. No images are '
                      'stored or sent.'
                : status == CameraPermission.restricted
                ? 'Camera access is blocked on this device by a system or '
                      'policy setting. Enter the barcode instead, or ask '
                      'your administrator.'
                : 'Camera access is turned off for RepForge. Open settings '
                      'and allow the camera to scan. No images are stored or '
                      'sent.',
          ),
          gap,
          if (denied)
            RfButton(
              key: const Key('scan-retry'),
              label: 'Allow camera',
              icon: Icons.camera_alt_outlined,
              onPressed: () => unawaited(_session.requestPermission()),
            )
          else
            RfButton(
              key: const Key('scan-open-settings'),
              label: 'Open settings',
              icon: Icons.settings_outlined,
              onPressed: () => unawaited(_session.openSettings()),
            ),
          gap,
          _manualEntry(),
        ];
      case ScanScanning():
        return [
          _preview(context, dimmed: false),
          gap,
          Text(
            'Point the camera at the barcode. It is read automatically.',
            style: theme.textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
          gap,
          _manualEntry(),
          gap,
          _cancelButton(),
        ];
      case ScanLookingUp(:final code):
        return [
          _preview(context, dimmed: true),
          gap,
          Semantics(
            liveRegion: true,
            label: 'Looking up $code',
            child: Column(
              children: [
                Text(
                  'Looking up $code…',
                  key: const Key('scan-looking-up'),
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: RfSpace.s2),
                const LinearProgressIndicator(),
              ],
            ),
          ),
          gap,
          _cancelButton(),
        ];
      case ScanFound(:final food, :final source):
        return [
          RfCard(
            key: const Key('scan-found'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  food.name,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: RfSpace.s2),
                Row(
                  children: [
                    ProvenanceBadge(food.profile.provenance),
                    const SizedBox(width: RfSpace.s2),
                    Expanded(
                      child: Text(
                        source == BarcodeLookupSource.local
                            ? 'from local cache'
                            : 'from Open Food Facts',
                        key: const Key('scan-source'),
                        style: context.rfText.caption,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          gap,
          RfButton(
            key: const Key('scan-rescan'),
            label: 'Scan again',
            variant: RfButtonVariant.secondary,
            onPressed: () => unawaited(_session.resume()),
          ),
        ];
      case ScanNotFound(:final barcode):
        return [
          RfEmptyState(
            key: const Key('scan-not-found'),
            icon: Icons.search_off,
            message: 'Not in the database. Nothing matches ${barcode.raw}.',
          ),
          gap,
          RfButton(
            key: const Key('scan-create-food'),
            label: 'Create custom food',
            icon: Icons.add,
            onPressed: () => unawaited(_createFood(barcode.raw)),
          ),
          gap,
          RfButton(
            key: const Key('scan-search-manually'),
            label: 'Search manually',
            variant: RfButtonVariant.secondary,
            onPressed: _searchManually,
          ),
          gap,
          RfButton(
            key: const Key('scan-rescan'),
            label: 'Scan again',
            variant: RfButtonVariant.tertiary,
            onPressed: () => unawaited(_session.resume()),
          ),
        ];
      case ScanFailed(:final error, :final barcode):
        final failure = lookupFailureOf(error);
        if (error is ValidationError || barcode == null) {
          return [
            RfErrorState(
              key: const Key('scan-failed'),
              message: userMessageFor(error),
            ),
            gap,
            _manualEntry(autofocus: true),
            gap,
            RfButton(
              key: const Key('scan-retry'),
              label: 'Retry',
              variant: RfButtonVariant.secondary,
              onPressed: () => unawaited(_session.resume()),
            ),
          ];
        }
        return [
          RfErrorState(
            key: const Key('scan-failed'),
            message: switch (failure) {
              LookupOffline() => "You're offline. Cached foods still work.",
              LookupRateLimited() =>
                'Open Food Facts is busy. Try again in a minute.',
              _ => 'Could not look up ${barcode.raw}. Try again.',
            },
          ),
          gap,
          RfButton(
            key: const Key('scan-retry'),
            label: 'Retry',
            onPressed: () => unawaited(_session.resume()),
          ),
          gap,
          RfButton(
            key: const Key('scan-search-manually'),
            label: 'Search manually',
            variant: RfButtonVariant.secondary,
            onPressed: _searchManually,
          ),
        ];
    }
  }

  Widget _searchButton() => RfButton(
    key: const Key('scan-search-manually'),
    label: 'Search manually',
    variant: RfButtonVariant.secondary,
    onPressed: _searchManually,
  );

  Widget _cancelButton() => RfButton(
    key: const Key('scan-cancel'),
    label: 'Cancel',
    variant: RfButtonVariant.tertiary,
    onPressed: () => unawaited(_cancel()),
  );

  Widget _manualEntry({bool autofocus = false}) {
    void submit() {
      final text = _manual.text;
      unawaited(_session.submitManual(text));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: RfTextField.integer(
            key: const Key('scan-manual-input'),
            controller: _manual,
            label: 'Enter barcode',
            hint: '8, 12 or 13 digits',
            autofocus: autofocus,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => submit(),
          ),
        ),
        const SizedBox(width: RfSpace.s2),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: RfButton(
            key: const Key('scan-manual-submit'),
            label: 'Look up',
            expand: false,
            onPressed: submit,
          ),
        ),
      ],
    );
  }

  Widget _preview(BuildContext context, {required bool dimmed}) {
    final builder = ref.watch(scannerPreviewBuilderProvider);
    return Semantics(
      label: 'Camera preview. Point at a barcode.',
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(RfRadius.md),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: context.rf.surface1),
              builder(context),
              const IgnorePointer(child: _Viewfinder()),
              if (dimmed) const ColoredBox(color: Color(0x99000000)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Corner-bracket viewfinder drawn over the camera preview.
class _Viewfinder extends StatelessWidget {
  const _Viewfinder();

  @override
  Widget build(BuildContext context) =>
      CustomPaint(painter: _ViewfinderPainter(context.rf.accent));
}

class _ViewfinderPainter extends CustomPainter {
  const _ViewfinderPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    final rect = Rect.fromCenter(
      center: size.center(Offset.zero),
      width: size.width * 0.7,
      height: size.height * 0.45,
    );
    const len = 24.0;
    for (final (corner, dx, dy) in [
      (rect.topLeft, 1.0, 1.0),
      (rect.topRight, -1.0, 1.0),
      (rect.bottomLeft, 1.0, -1.0),
      (rect.bottomRight, -1.0, -1.0),
    ]) {
      canvas
        ..drawLine(corner, corner + Offset(len * dx, 0), paint)
        ..drawLine(corner, corner + Offset(0, len * dy), paint);
    }
  }

  @override
  bool shouldRepaint(_ViewfinderPainter old) => old.color != color;
}
