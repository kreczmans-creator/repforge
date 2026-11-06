import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/training/rest_timer.dart';
import 'package:repforge/features/training/application/rest_timer_controller.dart';
import 'package:repforge/features/training/presentation/set_format.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/tokens.dart';

/// The rest-timer countdown with pause / resume, +15 s and skip (TRN-021).
/// It shows nothing while the timer is idle. The display is recomputed from
/// the clock every second while running, and every few seconds once the rest
/// is over (so "ended ... ago" stays current); the state itself is the
/// wall-clock end time owned by [RestTimerController]. When the rest ends the
/// panel switches to an emphasised "Rest over" state, is a live region and
/// announces it to screen readers; the haptic cue is the `RestAlert`.
class RestTimerPanel extends ConsumerStatefulWidget {
  const RestTimerPanel({super.key});

  @override
  ConsumerState<RestTimerPanel> createState() => _RestTimerPanelState();
}

/// How often "ended ... ago" is refreshed once the rest is over.
const restOverRefresh = Duration(seconds: 5);

class _RestTimerPanelState extends ConsumerState<RestTimerPanel> {
  Timer? _tick;
  Timer? _overTick;

  @override
  void initState() {
    super.initState();
    ref.listenManual(restTimerProvider, (prev, next) {
      _sync(next);
      if (prev != null && !prev.alerted && next.alerted) _announce();
    }, fireImmediately: true);
  }

  void _announce() {
    if (!mounted) return;
    try {
      unawaited(
        SemanticsService.sendAnnouncement(
          View.of(context),
          'Rest over',
          Directionality.of(context),
          assertiveness: Assertiveness.assertive,
        ),
      );
    } on Object {
      // An announcement that cannot be sent must not break the screen.
    }
  }

  /// Ticks only while the countdown runs, so a paused or finished timer
  /// schedules no work.
  void _sync(RestTimerState s) {
    final isRunning = s.timer.status == RestTimerStatus.running;
    final isDone = s.timer.isDone(ref.read(clockProvider).now());
    final running = isRunning && !isDone;
    final over = isRunning && isDone;
    if (over && _overTick == null) {
      _overTick = Timer.periodic(restOverRefresh, (_) {
        if (mounted) setState(() {});
      });
    } else if (!over) {
      _overTick?.cancel();
      _overTick = null;
    }
    if (running && _tick == null) {
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        ref.read(restTimerProvider.notifier).check();
        final now = ref.read(clockProvider).now();
        if (ref.read(restTimerProvider).timer.isDone(now)) {
          _tick?.cancel();
          _tick = null;
          _sync(ref.read(restTimerProvider));
        }
        setState(() {});
      });
    } else if (!running) {
      _tick?.cancel();
      _tick = null;
    }
  }

  @override
  void dispose() {
    _tick?.cancel();
    _overTick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(restTimerProvider);
    final timer = state.timer;
    if (timer.status == RestTimerStatus.idle) return const SizedBox.shrink();
    final now = ref.watch(clockProvider).now();
    final controller = ref.read(restTimerProvider.notifier);
    final left = timer.remaining(now);
    final done = timer.isDone(now);
    final shown = Duration(seconds: (left.inMilliseconds + 999) ~/ 1000);
    final paused = timer.status == RestTimerStatus.paused;
    final text = done ? 'Rest over' : formatClock(shown);
    final over = done && timer.endAt != null
        ? now.difference(timer.endAt!)
        : Duration.zero;
    final rf = context.rf;
    return Material(
      color: done ? rf.accentSubtle : rf.surface2,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: RfSpace.gutter,
            vertical: RfSpace.s2,
          ),
          child: Semantics(
            container: true,
            liveRegion: done,
            label: 'Rest timer',
            value: done
                ? 'Rest over'
                : '${paused ? 'Paused, ' : ''}${formatClock(shown)} left',
            child: Wrap(
              key: const Key('rest-timer-panel'),
              spacing: RfSpace.s2,
              runSpacing: RfSpace.s1,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (done)
                  ExcludeSemantics(
                    child: Icon(
                      Icons.notifications_active,
                      key: const Key('rest-over-icon'),
                      color: rf.accentText,
                    ),
                  ),
                ExcludeSemantics(
                  child: Text(
                    text,
                    key: const Key('rest-remaining'),
                    style: done
                        ? context.rfText.dataL.copyWith(
                            color: rf.accentText,
                            fontWeight: FontWeight.w800,
                          )
                        : context.rfText.dataL,
                  ),
                ),
                if (done && over.inSeconds >= 1)
                  ExcludeSemantics(
                    child: Text(
                      'ended ${formatClock(over)} ago',
                      key: const Key('rest-over-for'),
                      style: context.rfText.caption,
                    ),
                  ),
                if (!done)
                  RfButton(
                    key: Key(paused ? 'rest-resume' : 'rest-pause'),
                    label: paused ? 'Resume' : 'Pause',
                    icon: paused ? Icons.play_arrow : Icons.pause,
                    variant: RfButtonVariant.secondary,
                    expand: false,
                    onPressed: paused ? controller.resume : controller.pause,
                  ),
                RfButton(
                  key: const Key('rest-extend'),
                  label: '+15 s',
                  variant: RfButtonVariant.secondary,
                  expand: false,
                  onPressed: controller.extend,
                ),
                RfButton(
                  key: const Key('rest-skip'),
                  label: done ? 'Dismiss' : 'Skip',
                  icon: Icons.skip_next,
                  variant: RfButtonVariant.tertiary,
                  expand: false,
                  onPressed: controller.skip,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
