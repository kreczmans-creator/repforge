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
/// `check` (called by the screen's tick) covers a late wake-up. The state is
/// in memory: it survives the app going to the background, not the process
/// being killed.
///
/// Background alert (TRN-022(2), ADR-0007): while the app is not in the
/// foreground, a running timer with the `restTimerNotifications` setting on
/// has one notification scheduled at its end time. Going to the background
/// schedules it, returning to the foreground cancels it (so no heads-up or
/// channel sound shows beside the in-app cue), and while in the background
/// pause, skip, finish and an idle replacement cancel it and start, extend
/// and resume (re)schedule it. Calls to the scheduler run one after another
/// in the order they were requested, so a cancel can never overtake a
/// schedule. Nothing here depends on the notification for correctness
/// (PLT-008(2)), and a scheduler failure is ignored so it can never block
/// logging.
class RestTimerController extends Notifier<RestTimerState> {
  Timer? _fire;
  int _syncGeneration = 0;
  bool _scheduled = false;
  Future<void> _chain = Future<void>.value();
  AppLifecycleListener? _lifecycleListener;
  bool _foreground = true;

  @override
  RestTimerState build() {
    ref.onDispose(() {
      _fire?.cancel();
      _lifecycleListener?.dispose();
    });
    _watchLifecycle();
    return const RestTimerState();
  }

  void _watchLifecycle() {
    try {
      final binding = WidgetsBinding.instance;
      final current = binding.lifecycleState;
      _foreground = current == null || current == AppLifecycleState.resumed;
      _lifecycleListener = AppLifecycleListener(
        binding: binding,
        onStateChange: _onLifecycle,
      );
    } on Object {
      // No binding (a plain Dart test): treated as foreground.
    }
  }

  void _onLifecycle(AppLifecycleState lifecycle) {
    final foreground = lifecycle == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    _syncSchedule();
  }

  DateTime _now() => ref.read(clockProvider).now();

  void _set(RestTimer timer, {bool alerted = false}) {
    state = RestTimerState(timer: timer, alerted: alerted);
    _arm();
    _syncSchedule();
  }

  /// Queues [op] behind every scheduler call requested before it.
  Future<void> _enqueue(Future<void> Function() op) {
    final next = _chain.then((_) => op()).catchError((Object e) {
      debugPrint('Rest notification call failed: $e');
    });
    _chain = next;
    return next;
  }

  /// Brings the scheduled notification in line with [state] and the
  /// lifecycle: scheduled only while a timer runs and the app is not in the
  /// foreground.
  void _syncSchedule() {
    final generation = ++_syncGeneration;
    final s = state;
    final endsAt = s.timer.endAt;
    if (_foreground ||
        s.timer.status != RestTimerStatus.running ||
        s.alerted ||
        endsAt == null) {
      unawaited(_enqueue(_cancelScheduled));
      return;
    }
    unawaited(_enqueue(() => _schedule(generation, endsAt)));
  }

  Future<void> _schedule(int generation, DateTime endsAt) async {
    // A newer change superseded this one while it waited in the queue.
    if (generation != _syncGeneration) return;
    final settings = await ref.read(settingsRepositoryProvider).read();
    // ... or while the settings were read.
    if (generation != _syncGeneration) return;
    if (!settings.restTimerNotifications) return;
    _scheduled = true;
    await ref
        .read(restAlertSchedulerProvider)
        .schedule(
          id: restNotificationId,
          endsAt: endsAt,
          title: restNotificationTitle,
          body: restNotificationBody,
        );
  }

  Future<void> _cancelScheduled() async {
    if (!_scheduled) return;
    _scheduled = false;
    await ref.read(restAlertSchedulerProvider).cancel(restNotificationId);
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
    // In the background the scheduled notification stays; coming back to the
    // foreground cancels it (and removes it if shown).
  }
}

final restTimerProvider = NotifierProvider<RestTimerController, RestTimerState>(
  RestTimerController.new,
);
