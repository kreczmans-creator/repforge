import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';

/// The current week or month from `currentPeriodProvider` (settings and
/// clock), stepped [back] periods into the past (0 = the current one).
AnalyticsPeriod periodFromSettings(
  WidgetRef ref,
  AnalyticsPeriodKind kind, {
  int back = 0,
}) {
  var period = ref.watch(
    currentPeriodProvider(
      kind == AnalyticsPeriodKind.month
          ? PeriodChoice.thisMonth
          : PeriodChoice.thisWeek,
    ),
  );
  for (var i = 0; i < back; i++) {
    period = period.previous;
  }
  return period;
}
