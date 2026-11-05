import 'package:meta/meta.dart';

/// Longest rest or timer value, in seconds (the plan-exercise rest limit).
const maxRestSeconds = 3600;

/// Default rest when neither the exercise nor the user chose one (TRN-021).
const defaultRestSecondsFallback = 90;

/// Length of one extension step (TRN-021(2)).
const restExtendStep = Duration(seconds: 15);

enum RestTimerStatus { idle, running, paused }

/// Immutable rest-timer state (D04 TRN-021). A running timer holds the
/// wall-clock moment it ends, so it stays correct while the app is in the
/// background or killed; a paused timer holds the time left. Every operation
/// takes the current time and returns a new state; nothing reads a clock.
@immutable
final class RestTimer {
  const RestTimer._(this.status, this._endAt, this._left);

  /// No timer.
  const RestTimer.idle() : this._(RestTimerStatus.idle, null, null);

  /// Starts a countdown at [now] from [plannedRestSeconds] when it is a valid
  /// rest (0 to 3600), otherwise from [defaultRestSeconds] (clamped to that
  /// range). Replaces any timer that was running.
  factory RestTimer.start(
    DateTime now, {
    required int defaultRestSeconds,
    int? plannedRestSeconds,
  }) {
    final planned = plannedRestSeconds;
    final seconds =
        (planned != null && planned >= 0 && planned <= maxRestSeconds)
        ? planned
        : defaultRestSeconds.clamp(0, maxRestSeconds);
    return RestTimer._(
      RestTimerStatus.running,
      now.add(Duration(seconds: seconds)),
      null,
    );
  }

  final RestTimerStatus status;
  final DateTime? _endAt;
  final Duration? _left;

  /// When a running timer ends; null otherwise.
  DateTime? get endAt => status == RestTimerStatus.running ? _endAt : null;

  /// Time left at [now]; zero when done or idle.
  Duration remaining(DateTime now) {
    switch (status) {
      case RestTimerStatus.idle:
        return Duration.zero;
      case RestTimerStatus.paused:
        return _left!;
      case RestTimerStatus.running:
        final d = _endAt!.difference(now);
        return d.isNegative ? Duration.zero : d;
    }
  }

  /// True when a running timer has reached zero at [now]. A paused or idle
  /// timer is not done.
  bool isDone(DateTime now) =>
      status == RestTimerStatus.running && !now.isBefore(_endAt!);

  /// Pauses a running timer keeping the time left; no effect otherwise (a
  /// timer already done is left as it is).
  RestTimer pause(DateTime now) {
    if (status != RestTimerStatus.running || isDone(now)) return this;
    return RestTimer._(RestTimerStatus.paused, null, remaining(now));
  }

  /// Resumes a paused timer from the time it kept; no effect otherwise.
  RestTimer resume(DateTime now) {
    if (status != RestTimerStatus.paused) return this;
    return RestTimer._(RestTimerStatus.running, now.add(_left!), null);
  }

  /// Adds [steps] steps of 15 s to a running or paused timer, to at most 3600
  /// s left. A timer that has already reached zero restarts from [now]. No
  /// effect on an idle timer or when [steps] is not positive.
  RestTimer extend(DateTime now, {int steps = 1}) {
    if (status == RestTimerStatus.idle || steps < 1) return this;
    final added = restExtendStep * steps;
    const cap = Duration(seconds: maxRestSeconds);
    var left = remaining(now) + added;
    if (left > cap) left = cap;
    return status == RestTimerStatus.paused
        ? RestTimer._(RestTimerStatus.paused, null, left)
        : RestTimer._(RestTimerStatus.running, now.add(left), null);
  }

  /// Skips the rest: back to no timer.
  RestTimer skip() => const RestTimer.idle();

  @override
  bool operator ==(Object other) =>
      other is RestTimer &&
      other.status == status &&
      other._endAt == _endAt &&
      other._left == _left;

  @override
  int get hashCode => Object.hash(status, _endAt, _left);

  @override
  String toString() => 'RestTimer($status, endAt: $_endAt, left: $_left)';
}
