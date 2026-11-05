# ADR-0007: Rest-timer alerts through a notification adapter (flutter_local_notifications)

- Status: **Proposed** (WP 9; owner approval requested at WP 9 delivery; OQ-05 remains open)
- Date: 2026-11-05

## Context
WP 9 adds the rest timer (D04 TRN-021) and its end alert (TRN-022, P2): an alert at 0 s in the foreground (haptic pattern, visual state and announcement; no sound is promised), and a local notification within 2 s of the end time when the app is backgrounded, where the platform allows. PLT-007 requires notifications to stay off until the user opts in, with permission requested only then. PLT-008(2) forbids relying on a background task for correctness. D06 WP 9 acceptance: the timer fires in the background on Android, and when the app is foregrounded on iOS (documented limitation). OQ-05 (must the alert work in the background or with the screen locked?) is open. ADR-0006 requires plugin imports to stay in `lib/data/platform/`.

## Options considered
1. **`flutter_local_notifications`** to schedule one local notification at the timer's wall-clock end time, cancelled on pause, skip or finish and rescheduled on extend; foreground alert through Flutter's `HapticFeedback` (no plugin): a short pattern of strong haptic pulses, an emphasised "Rest over" state in the timer panel and a screen-reader announcement. There is no foreground sound (`SystemSound.alert` is silent on Android and iOS); a sound comes only from the notification when the app is in the background, and the device's touch-vibration or haptics setting can suppress the pulses.
2. A foreground service or background isolate that counts down: needs a persistent notification and battery cost, and contradicts PLT-008(2).
3. Foreground alert only: meets TRN-022(1) only.

## Decision (proposed)
Option 1, behind a Flutter-free domain interface `RestAlertScheduler` (schedule at an end time, cancel, permission status and request). One adapter in `lib/data/platform/` owns every plugin import; a fake adapter drives widget and integration tests. The timer's state stays the pure wall-clock `RestTimer` rule (WP 9 stage 1), so on return to the app the remaining or elapsed time is computed from the clock and shown even if no notification fired. Notifications are scheduled only when the `restTimerNotifications` setting is on; enabling it requests permission (PLT-007(1)); disabling it cancels any scheduled alert (PLT-007(2)).
- Version: `flutter_local_notifications` pinned to an exact release at least two weeks old (22.3.2 proposed), subject to the Android build with the current AGP and compileSdk; any SDK or desugaring change is recorded in D03.
- Android: exact scheduling when the exact-alarm permission is available, otherwise inexact (the 2 s target may then be missed; recorded as a limitation).
- iOS: the notification is scheduled the same way; device behaviour is unverified until the owner's device campaign. D06's documented limitation (foreground only) stays the acceptance baseline until then.

### Implementation record (WP 9 stage 3b)
Pinned `flutter_local_notifications` 22.3.2 and `timezone` 0.11.2 (compileSdk 36 and minSdk 24, so no SDK change; core library desugaring added to the app Gradle file; recorded in D03). Android mode: `exactAllowWhileIdle` when `canScheduleExactNotifications()` is true, otherwise `inexactAllowWhileIdle`; `SCHEDULE_EXACT_ALARM` is declared, `USE_EXACT_ALARM` is not, and the exact-alarm settings screen is not opened. The domain interface also has `openSettings()` for the denied-permission path. Status remains Proposed.

Changes after the final review: notifications are scheduled only while the app is not in the foreground (scheduled on inactive, hidden or paused, cancelled on resume), and scheduler calls run in request order. The Android small icon is a monochrome vector (`ic_stat_rest`) kept by `res/raw/keep.xml`; Flutter release builds use R8 by default and plugin 22.3.2 ships its own Gson rules, so no ProGuard file is added; CI builds the release APK.

## Rationale
One scheduled notification at a known end time is the smallest mechanism that meets TRN-022(2) without a background task. The adapter keeps platform code out of feature code (ADR-0006 standing constraint) and lets the timer be tested without a device.

## Consequences
- One new pinned plugin (and its `timezone` dependency); Android manifest entries for notifications and, if used, exact alarms.
- Timer alert timing on real devices is verified only in the owner's device campaign (WP 9 manual device test).
- OQ-05 stays open: if the owner decides background alerts are not required, the adapter can be reduced to the foreground alert without touching feature code.
