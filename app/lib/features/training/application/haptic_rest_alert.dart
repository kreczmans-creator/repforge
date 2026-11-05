import 'package:flutter/services.dart';
import 'package:repforge/domain/training/rest_alert.dart';

/// Default foreground [RestAlert]: a short pattern of strong haptic pulses
/// through Flutter's services (no plugin). The system alert sound is not used
/// because it is silent on Android and iOS; the sound of the rest alert comes
/// from the notification when the app is in the background. The visual
/// "Rest over" state and its screen-reader announcement are the panel's job.
///
/// The pattern can be suppressed by the device: a disabled touch-vibration
/// setting (Android) or system haptics setting (iOS) turns the pulses off, so
/// the visual state and the announcement carry the alert too.
///
/// Failures are ignored: an alert that cannot play must never break the
/// session screen.
final class HapticRestAlert implements RestAlert {
  const HapticRestAlert({
    this.pulses = 3,
    this.gap = const Duration(milliseconds: 200),
    this.pulse = HapticFeedback.heavyImpact,
    this.wait = _wait,
  });

  /// Number of pulses in the pattern.
  final int pulses;

  /// Pause between two pulses.
  final Duration gap;

  /// One pulse; replaced in tests.
  final Future<void> Function() pulse;

  /// Pause function; replaced in tests.
  final Future<void> Function(Duration) wait;

  static Future<void> _wait(Duration d) => Future<void>.delayed(d);

  @override
  Future<void> fire() async {
    try {
      for (var i = 0; i < pulses; i++) {
        if (i > 0) await wait(gap);
        await pulse();
      }
    } on Object {
      // Best effort only.
    }
  }
}
