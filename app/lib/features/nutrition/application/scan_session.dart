import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/scanning/barcode.dart';
import 'package:repforge/domain/scanning/barcode_scanner.dart';
import 'package:repforge/features/nutrition/application/lookup_barcode.dart';
import 'package:repforge/features/nutrition/application/nutrition_providers.dart';

/// What the scan screen shows. The screen only renders this state and calls
/// [ScanSession] methods; it holds no scanning logic.
sealed class ScanState {
  const ScanState();
}

/// Idle, or working out capability and permission.
final class ScanChecking extends ScanState {
  const ScanChecking();
}

/// Scanning cannot work on this device ([reason]); offer manual entry only.
final class ScanUnavailable extends ScanState {
  const ScanUnavailable(this.reason);
  final ScannerCapability reason;
}

/// The camera cannot be used yet. For [CameraPermission.denied] show the
/// rationale and then call `requestPermission`; for `permanentlyDenied` and
/// `restricted` explain how to enable it and offer `openSettings`. Manual
/// entry stays available in every case (PLT-004).
final class ScanPermissionNeeded extends ScanState {
  const ScanPermissionNeeded(this.status);
  final CameraPermission status;
}

/// The camera is running and codes are accepted.
final class ScanScanning extends ScanState {
  const ScanScanning();
}

/// A code was accepted and is being looked up. Further codes are ignored.
final class ScanLookingUp extends ScanState {
  const ScanLookingUp(this.code);
  final String code;
}

/// The product was found; the scanner is stopped.
final class ScanFound extends ScanState {
  const ScanFound(this.food, this.source, this.barcode);
  final Food food;
  final BarcodeLookupSource source;
  final Barcode barcode;
}

/// A valid barcode that no source knows (NUT-006(2)); the scanner is stopped.
final class ScanNotFound extends ScanState {
  const ScanNotFound(this.barcode);
  final Barcode barcode;
}

/// The lookup or validation failed; the scanner is stopped.
///
/// Invalid input (a malformed code from the hardware or a bad manual entry)
/// is reported here too, with a `ValidationError` and a null [barcode], rather
/// than a separate state, so the UI has one error path. [code] is what was
/// scanned or typed. For lookup failures [barcode] is set and the cause is
/// recoverable with `lookupFailureOf(error)` (offline, rate-limited, ...), so
/// the UI can offer retry and manual search.
final class ScanFailed extends ScanState {
  const ScanFailed(this.error, {required this.code, this.barcode});
  final AppError error;
  final String code;
  final Barcode? barcode;
}

/// Drives barcode scanning without any widget code (NUT-006, PLT-001..004).
///
/// Flow: `begin` checks capability, then permission, starts the scanner and
/// listens to its codes. A code is processed only while [ScanScanning]; the
/// state moves to [ScanLookingUp] synchronously, which prevents double
/// submission. Every outcome (found, not found, failed) stops the scanner until
/// `resume`. The same code is ignored for [repeatWindow] after a result, so
/// one label held in front of the camera is not looked up again.
class ScanSession extends Notifier<ScanState> {
  /// How long a code is ignored after it produced a result.
  static const repeatWindow = Duration(seconds: 3);

  StreamSubscription<ScannedCode>? _subscription;
  String? _lastCode;
  DateTime? _lastResultAt;
  int _generation = 0;

  @override
  ScanState build() {
    final scanner = ref.read(barcodeScannerProvider);
    ref.onDispose(() {
      _generation++;
      unawaited(_subscription?.cancel());
      _subscription = null;
      unawaited(_stopScanner(scanner));
    });
    return const ScanChecking();
  }

  BarcodeScanner get _scanner => ref.read(barcodeScannerProvider);

  /// Whether [BarcodeScanner.start] has been called without a matching stop,
  /// so the hardware is stopped exactly once per start (cancel followed by
  /// provider dispose must not stop it twice).
  bool _running = false;

  /// The `start()` call in flight, so a stop requested meanwhile waits for it
  /// instead of racing it and leaving the camera running.
  Future<void>? _starting;

  Future<void> _stopScanner([BarcodeScanner? scanner]) async {
    if (!_running) return;
    _running = false;
    final target = scanner ?? _scanner;
    final starting = _starting;
    if (starting != null) await starting;
    await target.stop();
  }

  /// Checks capability and permission, then starts scanning if possible.
  Future<void> begin() async {
    final gen = ++_generation;
    state = const ScanChecking();
    final capability = await _scanner.capability();
    if (!_current(gen)) return;
    if (capability != ScannerCapability.available) {
      state = ScanUnavailable(capability);
      return;
    }
    final permission = await _scanner.permissionStatus();
    if (!_current(gen)) return;
    await _afterPermission(permission, gen);
  }

  /// Shows the system permission prompt. Call after the rationale.
  Future<void> requestPermission() async {
    final gen = _generation;
    final permission = await _scanner.requestPermission();
    if (!_current(gen)) return;
    await _afterPermission(permission, gen);
  }

  /// Opens system settings so a permanently denied permission can be enabled.
  Future<bool> openSettings() => _scanner.openAppSettings();

  /// Manual entry fallback (PLT-002(2), PLT-004(1)). Works in any state
  /// except while a lookup is running. Invalid text becomes [ScanFailed] with
  /// a `ValidationError`.
  Future<void> submitManual(String text) async {
    if (state is ScanLookingUp) return;
    final gen = ++_generation;
    await _lookup(ScannedCode(text), gen);
  }

  /// Returns to scanning after a result and restarts the scanner.
  Future<void> resume() async {
    final gen = ++_generation;
    await _afterPermission(await _scanner.permissionStatus(), gen);
  }

  /// Stops the scanner and cancels the subscription; the state returns to
  /// [ScanChecking]. Any lookup in flight is discarded.
  Future<void> cancel() async {
    _generation++;
    final sub = _subscription;
    _subscription = null;
    await sub?.cancel();
    await _stopScanner();
    if (ref.mounted) state = const ScanChecking();
  }

  bool _current(int gen) => ref.mounted && gen == _generation;

  Future<void> _afterPermission(CameraPermission permission, int gen) async {
    if (permission != CameraPermission.granted) {
      state = ScanPermissionNeeded(permission);
      return;
    }
    _subscription ??= _scanner.codes.listen(_onCode);
    // Mark running before awaiting: a cancel or dispose that lands while a
    // real camera is still starting must find it running and stop it.
    _running = true;
    final starting = _starting = _scanner.start();
    await starting;
    if (identical(_starting, starting)) _starting = null;
    if (!_current(gen)) {
      // Cancelled, disposed or superseded while starting. Stop the camera
      // unless a newer start now owns it.
      if (!ref.mounted || (_starting == null && state is! ScanScanning)) {
        await _stopScanner();
      }
      return;
    }
    state = const ScanScanning();
  }

  void _onCode(ScannedCode scanned) {
    if (state is! ScanScanning) return;
    final code = scanned.raw;
    final at = _lastResultAt;
    if (code == _lastCode &&
        at != null &&
        ref.read(clockProvider).now().difference(at) < repeatWindow) {
      return;
    }
    final gen = ++_generation;
    unawaited(_lookup(scanned, gen));
  }

  Future<void> _lookup(ScannedCode scanned, int gen) async {
    final trimmed = scanned.raw.trim();
    state = ScanLookingUp(trimmed);
    final validated = validateBarcode(trimmed, hint: scanned.format);
    if (validated case Err(:final error)) {
      await _finish(ScanFailed(error, code: trimmed), trimmed, gen);
      return;
    }
    final barcode = (validated as Ok<Barcode>).value;
    final result = await ref.read(lookupBarcodeProvider)(
      barcode.raw,
      format: scanned.format,
    );
    if (!_current(gen)) return;
    final next = switch (result) {
      Ok(value: BarcodeFound(:final food, :final source)) => ScanFound(
        food,
        source,
        barcode,
      ),
      Ok(value: BarcodeNotFound()) => ScanNotFound(barcode),
      Err(:final error) => ScanFailed(error, code: trimmed, barcode: barcode),
    };
    await _finish(next, trimmed, gen);
  }

  Future<void> _finish(ScanState next, String code, int gen) async {
    _lastCode = code;
    _lastResultAt = ref.read(clockProvider).now();
    state = next;
    await _stopScanner();
  }
}
