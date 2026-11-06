import 'package:repforge/domain/training/rest_alert_scheduler.dart';

/// One call recorded by [FakeRestAlertScheduler].
final class SchedulerCall {
  const SchedulerCall(this.kind, {this.id, this.endsAt});

  /// `schedule`, `cancel`, `cancelAll`, `request`, `status`, `openSettings`,
  /// `exactTimingStatus` or `requestExactTiming`.
  final String kind;
  final String? id;
  final DateTime? endsAt;

  @override
  String toString() => 'SchedulerCall($kind, $id, $endsAt)';
}

/// Test double for [RestAlertScheduler]: records calls and keeps the set of
/// currently scheduled alerts. Fakes over mocks.
final class FakeRestAlertScheduler implements RestAlertScheduler {
  FakeRestAlertScheduler({
    this.permission = NotificationPermission.granted,
    this.requestResult,
    this.settingsOpens = true,
    this.exactTiming = ExactTiming.available,
    this.exactGrantedByRequest = false,
    this.exactDelay = Duration.zero,
    this.failing = false,
    this.scheduleDelay = Duration.zero,
    this.cancelDelay = Duration.zero,
  });

  /// Answer of [status]; updated by [request].
  NotificationPermission permission;

  /// What [request] yields; `null` keeps the current [permission].
  NotificationPermission? requestResult;

  /// What [openSettings] returns.
  bool settingsOpens;

  /// Answer of [exactTimingStatus]; tests change it to script the system.
  ExactTiming exactTiming;

  /// When true [requestExactTiming] turns [exactTiming] to available (the
  /// user allows it on the system screen); otherwise it is left as is.
  bool exactGrantedByRequest;

  /// How long [requestExactTiming] stays open (the user is in settings).
  Duration exactDelay;

  /// When true every operation throws (the real adapter never does; this
  /// proves callers also survive a misbehaving port).
  bool failing;

  /// How long [schedule] and [cancel] take before they take effect, to
  /// reproduce a slow platform.
  Duration scheduleDelay;
  Duration cancelDelay;

  /// Every call in order.
  final List<SchedulerCall> calls = [];

  /// Alerts currently scheduled: id to end time.
  final Map<String, DateTime> scheduled = {};

  /// Titles and bodies of scheduled alerts by id.
  final Map<String, (String, String)> texts = {};

  /// Calls of one [kind].
  List<SchedulerCall> of(String kind) => [
    for (final c in calls)
      if (c.kind == kind) c,
  ];

  void _record(SchedulerCall call) {
    calls.add(call);
    if (failing) throw StateError('fake scheduler failure');
  }

  @override
  Future<NotificationPermission> status() async {
    _record(const SchedulerCall('status'));
    return permission;
  }

  @override
  Future<NotificationPermission> request() async {
    _record(const SchedulerCall('request'));
    return permission = requestResult ?? permission;
  }

  @override
  Future<bool> openSettings() async {
    _record(const SchedulerCall('openSettings'));
    return settingsOpens;
  }

  @override
  Future<ExactTiming> exactTimingStatus() async {
    _record(const SchedulerCall('exactTimingStatus'));
    return exactTiming;
  }

  @override
  Future<void> requestExactTiming() async {
    _record(const SchedulerCall('requestExactTiming'));
    if (exactDelay > Duration.zero) await Future<void>.delayed(exactDelay);
    if (exactGrantedByRequest) exactTiming = ExactTiming.available;
  }

  @override
  Future<void> schedule({
    required String id,
    required DateTime endsAt,
    required String title,
    required String body,
  }) async {
    _record(SchedulerCall('schedule', id: id, endsAt: endsAt));
    if (scheduleDelay > Duration.zero) {
      await Future<void>.delayed(scheduleDelay);
    }
    scheduled[id] = endsAt;
    texts[id] = (title, body);
  }

  @override
  Future<void> cancel(String id) async {
    _record(SchedulerCall('cancel', id: id));
    if (cancelDelay > Duration.zero) await Future<void>.delayed(cancelDelay);
    scheduled.remove(id);
    texts.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    _record(const SchedulerCall('cancelAll'));
    scheduled.clear();
    texts.clear();
  }
}
