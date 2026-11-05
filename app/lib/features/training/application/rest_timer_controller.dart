import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/training/rest_alert.dart';
import 'package:repforge/domain/training/rest_timer.dart';
import 'package:repforge/features/training/application/haptic_rest_alert.dart';

/// The foreground alert fired at 0 s. Tests override it with a fake; stage 3b
/// adds background scheduling behind its own port (ADR-0007).
final restAlertProvider = Provider<RestAlert>((_) => const HapticRestAlert());

/// The rest timer as the screen sees it: the pure [RestTimer] rule plus
/// whether the alert for this run has already fired.
@immutable
class RestTimerState {
  const RestTimerState({
    this.timer = const RestTimer.idle(),
    this.alerted = false,
  });

  final RestTimer timer;
  final bool alerted;
}

/// Owns the rest timer (TRN-021, TRN-022(1)). All state derives from the
/// injected clock (wall-clock end time), so it stays right after the app was
/// in the background; the one-shot timer only makes the alert prompt, and
/// `check` (called by the screen's tick) covers a late wake-up.
class RestTimerController extends Notifier<RestTimerState> {
  Timer? _fire;

  @override
  RestTimerState build() {
    ref.onDispose(() => _fire?.cancel());
    return const RestTimerState();
  }

  DateTime _now() => ref.read(clockProvider).now();

  void _set(RestTimer timer, {bool alerted = false}) {
    state = RestTimerState(timer: timer, alerted: alerted);
    _arm();
  }

  void _arm() {
    _fire?.cancel();
    _fire = null;
    final t = state.timer;
    if (t.status != RestTimerStatus.running || state.alerted) return;
    final left = t.remaining(_now());
    _fire = Timer(left + const Duration(milliseconds: 1), check);
  }

  /// Starts a countdown from the planned rest, or the default (TRN-021(1)). A
  /// rest of 0 s starts no timer.
  void start({required int defaultRestSeconds, int? plannedRestSeconds}) {
    final now = _now();
    final t = RestTimer.start(
      now,
      defaultRestSeconds: defaultRestSeconds,
      plannedRestSeconds: plannedRestSeconds,
    );
    _set(t.remaining(now) == Duration.zero ? const RestTimer.idle() : t);
  }

  void pause() => _set(state.timer.pause(_now()), alerted: state.alerted);

  void resume() => _set(state.timer.resume(_now()), alerted: state.alerted);

  /// Adds 15 s (TRN-021(2)); a finished timer restarts from now.
  void extend() => _set(state.timer.extend(_now()));

  void skip() => _set(state.timer.skip());

  /// Fires the alert once when a running timer has reached zero.
  void check() {
    final s = state;
    if (s.alerted || !s.timer.isDone(_now())) {
      if (!s.alerted) _arm();
      return;
    }
    state = RestTimerState(timer: s.timer, alerted: true);
    unawaited(ref.read(restAlertProvider).fire());
  }
}

final restTimerProvider = NotifierProvider<RestTimerController, RestTimerState>(
  RestTimerController.new,
);
