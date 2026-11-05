import 'package:flutter/services.dart';
import 'package:repforge/domain/training/rest_alert.dart';

/// Default foreground [RestAlert]: a haptic pulse and the system alert sound
/// through Flutter's services (no plugin). Failures are ignored: an alert that
/// cannot play must never break the session screen.
final class HapticRestAlert implements RestAlert {
  const HapticRestAlert();

  @override
  Future<void> fire() async {
    try {
      await HapticFeedback.heavyImpact();
      await SystemSound.play(SystemSoundType.alert);
    } on Object {
      // Best effort only.
    }
  }
}
