import 'package:meta/meta.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';

/// One stretch of days during which one target value was in effect.
@immutable
final class TargetPeriod {
  const TargetPeriod({
    required this.goalId,
    required this.kind,
    required this.target,
    required this.effectiveFrom,
    required this.active,
    this.replacedSameDay = false,
    this.site,
    this.effectiveTo,
  });

  final String goalId;
  final GoalKind kind;
  final MeasurementSite? site;
  final double target;

  /// First day the target applied (inclusive).
  final CalendarDate effectiveFrom;

  /// Last day the target applied (inclusive); null while it is still in
  /// effect.
  final CalendarDate? effectiveTo;

  /// Whether the stored goal row is still the active one.
  final bool active;

  /// Set when the target was replaced or cleared on the day it started, so
  /// it applied on no day. Kept for the history view; [covers] is false.
  final bool replacedSameDay;

  /// Whether the target applied on [day].
  bool covers(CalendarDate day) =>
      day.compareTo(effectiveFrom) >= 0 &&
      (effectiveTo == null || day.compareTo(effectiveTo!) <= 0);
}

/// The targets in effect on any past day (GOL-006). Built from every goal
/// row, inactive ones included, so a changed target never rewrites the days
/// before the change.
///
/// The rule, exactly:
///
/// 1. Goals are grouped by kind, and by site for measurement goals (left and
///    right limbs are separate sites).
/// 2. A goal's start is the local calendar date of its `startDate`. Within a
///    group, goals are ordered by that date, then by creation time, then by id.
/// 3. A goal applies from its start date until the day before the next goal
///    of the same group starts. The last goal of a group applies with no end
///    while it is active.
/// 4. An inactive row applies until the day before it was deactivated (the
///    date of its `updatedAt`, set by `GoalRepository.replaceActive`), or
///    until the day before its successor starts, whichever is earlier. So a
///    target cleared on 15 Oct stays cleared when a new one starts on 1 Nov.
/// 5. A goal replaced or cleared on the date it started never applied on any
///    day. It stays in the periods with `replacedSameDay` set, for the
///    history view, and `targetsOn` never returns it.
/// 6. Days before the first goal of a group have no target (null), and a
///    goal's `endDate` (a deadline) does not end its period.
@immutable
final class TargetHistory {
  const TargetHistory._(this._periods);

  /// Builds the history from every goal row (any order).
  factory TargetHistory.fromGoals(Iterable<Goal> goals) {
    final groups = <(GoalKind, MeasurementSite?), List<Goal>>{};
    for (final g in goals) {
      final site = g.kind == GoalKind.measurement ? g.site : null;
      (groups[(g.kind, site)] ??= []).add(g);
    }
    final periods = <TargetPeriod>[];
    for (final entry in groups.entries) {
      final list = entry.value
        ..sort((a, b) {
          final c = _startDay(a).compareTo(_startDay(b));
          if (c != 0) return c;
          final byCreated = a.createdAt.compareTo(b.createdAt);
          return byCreated != 0 ? byCreated : a.id.compareTo(b.id);
        });
      for (var i = 0; i < list.length; i++) {
        final g = list[i];
        final from = _startDay(g);
        CalendarDate? to;
        if (i + 1 < list.length) {
          to = _startDay(list[i + 1]).addDays(-1);
        } else if (g.active) {
          to = null;
        } else {
          to = _deactivatedDay(g);
        }
        if (!g.active && i + 1 < list.length) {
          final ended = _deactivatedDay(g);
          if (to != null && ended.isBefore(to)) to = ended;
        }
        final replacedSameDay = to != null && to.isBefore(from);
        periods.add(
          TargetPeriod(
            goalId: g.id,
            kind: g.kind,
            site: entry.key.$2,
            target: g.target,
            effectiveFrom: from,
            effectiveTo: to,
            active: g.active,
            replacedSameDay: replacedSameDay,
          ),
        );
      }
    }
    periods.sort((a, b) {
      final c = a.kind.index.compareTo(b.kind.index);
      if (c != 0) return c;
      final s = (a.site?.index ?? -1).compareTo(b.site?.index ?? -1);
      return s != 0 ? s : a.effectiveFrom.compareTo(b.effectiveFrom);
    });
    return TargetHistory._(List.unmodifiable(periods));
  }

  /// The last day an inactive row applied: the day before it was
  /// deactivated (its `updatedAt` date).
  static CalendarDate _deactivatedDay(Goal g) =>
      CalendarDate.fromInstant(g.updatedAt).addDays(-1);

  static CalendarDate _startDay(Goal g) =>
      CalendarDate.fromInstant(g.startDate);

  final List<TargetPeriod> _periods;

  /// Every period of every group, grouped by kind then site, oldest first.
  List<TargetPeriod> get allPeriods => _periods;

  /// The periods of one kind (and site for a measurement goal), oldest first:
  /// the history view (GOL-006(2)).
  List<TargetPeriod> periodsFor(GoalKind kind, [MeasurementSite? site]) => [
    for (final p in _periods)
      if (p.kind == kind && (kind != GoalKind.measurement || p.site == site)) p,
  ];

  /// The target of [kind] (and [site]) in effect on [day], or null when none
  /// was.
  double? targetOn(GoalKind kind, CalendarDate day, {MeasurementSite? site}) {
    for (final p in periodsFor(kind, site)) {
      if (p.covers(day)) return p.target;
    }
    return null;
  }

  /// The daily nutrition targets in effect on [day]. A nutrient without a
  /// target on that day is null ("no target set").
  DailyTargets targetsOn(CalendarDate day) => DailyTargets(
    kcal: targetOn(GoalKind.calories, day),
    proteinG: targetOn(GoalKind.protein, day),
    carbsG: targetOn(GoalKind.carbs, day),
    fatG: targetOn(GoalKind.fat, day),
    fibreG: targetOn(GoalKind.fibre, day),
  );
}
