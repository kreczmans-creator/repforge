import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/training/rest_alert.dart';
import 'package:repforge/domain/training/rest_timer.dart';
import 'package:repforge/features/training/application/haptic_rest_alert.dart';

/// The foreground alert fired at 0 s. Tests override it with a fake.
final restAlertProvider = Provider<RestAlert>((_) => const HapticRestAlert());

/// Id of the one rest notification (there is one timer for the app).
const restNotificationId = 'rest-timer';

/// Notification text.
const restNotificationTitle = 'Rest over';
const restNotificationBody = 'Time for your next set.';

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

/// Owns the rest timer (TRN-021, TRN-022). All state derives from the
/// injected clock (wall-clock end time), so it stays right after the app was
/// in the background; the one-shot timer only makes the alert prompt, and
/// `check` (called by the screen's tick) covers a late wake-up.
///
/// Background alert (TRN-022(2), ADR-0007): while a timer runs and the
/// `restTimerNotifications` setting is on, one notification is scheduled at
/// its end time. Every state change goes through [_set], which reconciles the
/// schedule: pause, skip, finish and an idle replacement cancel it; start,
/// extend and resume (re)schedule it. Nothing here depends on the
/// notification for correctness (PLT-008(2)), and a scheduler failure is
/// ignored so it can never block logging.
class RestTimerController extends Notifier<RestTimerState> {
  Timer? _fire;
  int _syncGeneration = 0;
  bool _scheduled = false;

  @override
  RestTimerState build() {
    ref.onDispose(() => _fire?.cancel());
    return const RestTimerState();
  }

  DateTime _now() => ref.read(clockProvider).now();

  void _set(RestTimer timer, {bool alerted = false}) {
    state = RestTimerState(timer: timer, alerted: alerted);
    _arm();
    _syncSchedule();
  }

  /// Brings the scheduled notification in line with [state].
  void _syncSchedule() {
    final generation = ++_syncGeneration;
    final s = state;
    final endsAt = s.timer.endAt;
    if (s.timer.status != RestTimerStatus.running ||
        s.alerted ||
        endsAt == null) {
      _cancelScheduled();
      return;
    }
    unawaited(_schedule(generation, endsAt));
  }

  Future<void> _schedule(int generation, DateTime endsAt) async {
    try {
      final settings = await ref.read(settingsRepositoryProvider).read();
      // A newer change superseded this one while settings were read.
      if (generation != _syncGeneration) return;
      if (!settings.restTimerNotifications) {
        _cancelScheduled();
        return;
      }
      _scheduled = true;
      await ref
          .read(restAlertSchedulerProvider)
          .schedule(
            id: restNotificationId,
            endsAt: endsAt,
            title: restNotificationTitle,
            body: restNotificationBody,
          );
    } on Object catch (e) {
      debugPrint('Rest notification not scheduled: $e');
    }
  }

  void _cancelScheduled() {
    if (!_scheduled) return;
    _scheduled = false;
    unawaited(_cancelGuarded());
  }

  Future<void> _cancelGuarded() async {
    try {
      await ref.read(restAlertSchedulerProvider).cancel(restNotificationId);
    } on Object catch (e) {
      debugPrint('Rest notification not cancelled: $e');
    }
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

  bool _inForeground() {
    try {
      final lifecycle = WidgetsBinding.instance.lifecycleState;
      return lifecycle == null || lifecycle == AppLifecycleState.resumed;
    } on Object {
      return false;
    }
  }

  /// Fires the alert once when a running timer has reached zero.
  void check() {
    final s = state;
    if (s.alerted || !s.timer.isDone(_now())) {
      if (!s.alerted) _arm();
      return;
    }
    state = RestTimerState(timer: s.timer, alerted: true);
    unawaited(ref.read(restAlertProvider).fire());
    // In the foreground the haptic alert is the cue; drop the notification so
    // it does not appear as well. In the background it stays.
    if (_inForeground()) {
      _syncGeneration++;
      _cancelScheduled();
    }
  }
}

final restTimerProvider = NotifierProvider<RestTimerController, RestTimerState>(
  RestTimerController.new,
);
