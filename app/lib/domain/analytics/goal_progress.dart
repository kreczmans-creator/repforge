import 'package:meta/meta.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/body_analytics.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurement_comparison.dart'
    show roundToTenth;
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/weight_trend.dart'
    show trendMinReadings, trendWindowDays;

/// Which way the value has to move to reach the target.
enum GoalDirection { decrease, increase }

/// Where a goal stands. Descriptive only (GOL-011).
enum GoalState { notEnoughData, inProgress, atTarget, passedTarget }

/// What the entries behind a figure are, so a screen can open them
/// (GOL-008(2)). The domain names the data; the router is not its concern.
enum DrillDownKind { weightEntries, measurementEntries, sessions }

/// A reference to the entries behind a progress figure.
@immutable
final class DrillDown {
  const DrillDown({
    required this.kind,
    required this.from,
    required this.to,
    this.site,
  });

  final DrillDownKind kind;
  final CalendarDate from;
  final CalendarDate to;
  final MeasurementSite? site;
}

/// Progress of one goal (GOL-008): current value, target, percentage, the
/// basis of the figure and where its entries are.
///
/// Weight goals use the trend value (GOL-003(2)); measurement goals use the
/// latest reading (GOL-004(1)); sessions-per-week goals count completed
/// sessions of the week (GOL-005(1)).
///
/// Direction is derived at read time (plan decision 2a); there is no stored
/// direction. The rule: the direction is the side the current value lies on
/// relative to the target (above the target: decrease). When the goal's
/// first value since its start date is known, it also tells whether the
/// target has been passed: if the first value lay on the other side of the
/// target than the current one, the state is [GoalState.passedTarget] and the
/// direction is the original one. Without a first value the state cannot be
/// "passed".
@immutable
final class GoalProgress {
  const GoalProgress._({
    required this.goal,
    required this.unit,
    required this.current,
    required this.state,
    required this.drillDown,
    required this.statement,
    this.direction,
    this.remaining,
    this.percent,
    this.startValue,
  });

  /// Progress of a body weight goal from the trend value of [summary].
  factory GoalProgress.bodyWeight({
    required Goal goal,
    required WeightSummary summary,
  }) {
    final latest = summary.latestTrend;
    final Metric<double> current;
    if (latest == null) {
      current = NotEnoughData(
        have: summary.recentReadingCount,
        need: trendMinReadings,
        reason:
            'No weight trend value yet: it needs $trendMinReadings '
            'readings in $trendWindowDays days.',
      );
    } else {
      current = MetricValue(
        latest.average!,
        MetricBasis(
          period: summary.period,
          sampleCount: latest.readingsInWindow,
          sources: ['weight trend value of ${latest.date.iso}'],
          dayRule: calendarDayRule,
        ),
      );
    }
    final startDay = CalendarDate.fromInstant(goal.startDate);
    double? start;
    for (final p in summary.trendPoints) {
      if (!p.date.isBefore(startDay)) {
        start = p.average;
        break;
      }
    }
    return GoalProgress._towardTarget(
      goal: goal,
      unit: 'kg',
      current: current,
      start: start,
      drillDown: DrillDown(
        kind: DrillDownKind.weightEntries,
        from: summary.period.from,
        to: summary.period.to,
      ),
    );
  }

  /// Progress of a measurement goal from the latest reading of its site.
  /// [readings] may hold other sites and dates after [period] ends; both are
  /// ignored. Left and right sites are separate goals with separate sites.
  factory GoalProgress.measurement({
    required Goal goal,
    required Iterable<Measurement> readings,
    required AnalyticsPeriod period,
  }) {
    final site = goal.site;
    final unit = site?.unit ?? 'cm';
    final drill = DrillDown(
      kind: DrillDownKind.measurementEntries,
      from: period.from,
      to: period.to,
      site: site,
    );
    if (site == null) {
      return GoalProgress._towardTarget(
        goal: goal,
        unit: unit,
        current: const NotEnoughData(
          have: 0,
          need: 1,
          reason: 'The goal names no body site.',
        ),
        drillDown: drill,
      );
    }
    final own = readingsOf(
      readings,
      site,
      range: DateRange(CalendarDate(1900, 1, 1), period.to),
    );
    if (own.isEmpty) {
      return GoalProgress._towardTarget(
        goal: goal,
        unit: unit,
        current: NotEnoughData(
          have: 0,
          need: 1,
          reason: 'No ${site.label.toLowerCase()} reading yet.',
        ),
        drillDown: drill,
      );
    }
    final latest = own.last;
    final latestDay = CalendarDate.fromInstant(latest.recordedAt).iso;
    final startDay = CalendarDate.fromInstant(goal.startDate);
    double? start;
    for (final m in own) {
      if (!CalendarDate.fromInstant(m.recordedAt).isBefore(startDay)) {
        start = m.value.raw;
        break;
      }
    }
    return GoalProgress._towardTarget(
      goal: goal,
      unit: unit,
      current: MetricValue(
        latest.value.raw,
        MetricBasis(
          period: period,
          sampleCount: own.length,
          sources: ['latest ${site.label.toLowerCase()} reading of $latestDay'],
          dayRule: calendarDayRule,
        ),
      ),
      start: start,
      drillDown: drill,
    );
  }

  factory GoalProgress._towardTarget({
    required Goal goal,
    required String unit,
    required Metric<double> current,
    required DrillDown drillDown,
    double? start,
  }) {
    final cur = current.valueOrNull;
    final target = goal.target;
    if (cur == null) {
      return GoalProgress._(
        goal: goal,
        unit: unit,
        current: current,
        state: GoalState.notEnoughData,
        drillDown: drillDown,
        statement: 'Not enough data',
      );
    }
    final diff = cur - target;
    final startDirection = start == null || start == target
        ? null
        : (start > target ? GoalDirection.decrease : GoalDirection.increase);
    if (roundToTenth(diff) == 0) {
      return GoalProgress._(
        goal: goal,
        unit: unit,
        current: current,
        state: GoalState.atTarget,
        direction: startDirection,
        remaining: 0,
        percent: 100,
        startValue: start,
        drillDown: drillDown,
        statement: 'At target',
      );
    }
    final now = diff > 0 ? GoalDirection.decrease : GoalDirection.increase;
    final left = roundToTenth(diff.abs());
    if (startDirection != null && startDirection != now) {
      return GoalProgress._(
        goal: goal,
        unit: unit,
        current: current,
        state: GoalState.passedTarget,
        direction: startDirection,
        remaining: left,
        percent: 100,
        startValue: start,
        drillDown: drillDown,
        statement: 'Passed target by ${left.toStringAsFixed(1)} $unit',
      );
    }
    double? percent;
    if (start != null && start != target) {
      percent = roundToTenth(
        ((start - cur) / (start - target) * 100).clamp(0, 100),
      );
    }
    return GoalProgress._(
      goal: goal,
      unit: unit,
      current: current,
      state: GoalState.inProgress,
      direction: now,
      remaining: left,
      percent: percent,
      startValue: start,
      drillDown: drillDown,
      statement: '${left.toStringAsFixed(1)} $unit to go',
    );
  }

  final Goal goal;

  /// kg, cm or sessions.
  final String unit;

  /// The current value with its basis, or not enough data.
  final Metric<double> current;
  final GoalState state;

  /// The direction of travel to the target; null while unknown.
  final GoalDirection? direction;

  /// Distance to the target (or overshoot past it), to 0.1; null without a
  /// current value.
  final double? remaining;

  /// Share of the way from the first value to the target, 0 to 100; null
  /// when there is no first value to measure from.
  final double? percent;

  /// The first value since the goal started, when known.
  final double? startValue;

  /// Where the entries behind the figure are (GOL-008(2)).
  final DrillDown drillDown;

  /// A descriptive line: "5.0 kg to go", "At target", "2 of 3 sessions".
  /// It never tells the user what to do (GOL-011).
  final String statement;

  /// The target value.
  double get target => goal.target;
}
