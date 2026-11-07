import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/settings/settings.dart';

/// The one place the presentation builds a week or month from the settings
/// (week start, day-start hour) and the clock. [back] steps that many periods
/// into the past (0 = the current one).
///
/// Replace the body with the application layer's `periodFor` once it
/// exists, so screens share one definition of "this week".
AnalyticsPeriod periodFromSettings(
  WidgetRef ref,
  AnalyticsPeriodKind kind, {
  int back = 0,
}) {
  final settings = ref.watch(settingsProvider).value ?? const AppSettings();
  final now = ref.watch(clockProvider).now();
  var period = switch (kind) {
    AnalyticsPeriodKind.month => AnalyticsPeriod.thisMonth(
      now,
      dayStartHour: settings.dayStartHour,
    ),
    _ => AnalyticsPeriod.thisWeek(
      now,
      settings.weekStartDay,
      dayStartHour: settings.dayStartHour,
    ),
  };
  for (var i = 0; i < back; i++) {
    period = period.previous;
  }
  return period;
}
