import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';

/// Use case: set or clear one body weight, measurement or sessions-per-week
/// goal (GOL-003..005). One goal is active per kind, and per site for a
/// measurement goal; saving replaces the active one in one repository
/// transaction (`GoalRepository.replaceActive`), so the earlier target stays
/// in the target history (GOL-006).
///
/// Calorie and macro targets are daily targets and stay with
/// `SaveDailyTargets`.
final class SaveGoal {
  const SaveGoal({
    required this.repository,
    required this.clock,
    required this.newId,
  });

  final GoalRepository repository;
  final Clock clock;
  final IdGenerator newId;

  /// The kinds this use case handles.
  static const List<GoalKind> kinds = [
    GoalKind.bodyWeight,
    GoalKind.measurement,
    GoalKind.sessionsPerWeek,
  ];

  /// The active goal of [kind] (and [site]), or null when none is set.
  Future<Result<Goal?>> current(GoalKind kind, {MeasurementSite? site}) async {
    try {
      final match = (await repository.active()).where(
        (g) =>
            g.kind == kind && (kind != GoalKind.measurement || g.site == site),
      );
      return Ok(match.isEmpty ? null : match.last);
    } on Object catch (e) {
      return Err(StorageError('Could not read the goal.', cause: e));
    }
  }

  /// Validates and saves the goal. [targetText] is what the user typed;
  /// [endDateText] is an optional `YYYY-MM-DD` deadline that must not lie
  /// before today. Errors carry the field `target`, `site` or `endDate`.
  Future<Result<Goal>> call({
    required GoalKind kind,
    required String targetText,
    MeasurementSite? site,
    String? endDateText,
  }) async {
    if (!kinds.contains(kind)) {
      return const Err(ValidationError('This goal type is not supported.'));
    }
    final MeasurementSite? goalSite;
    if (kind == GoalKind.measurement) {
      if (site == null || site.isWeight) {
        return const Err(ValidationError('Choose a body site.', field: 'site'));
      }
      goalSite = site;
    } else {
      goalSite = null;
    }

    final text = targetText.trim().replaceAll(',', '.');
    final parsed = double.tryParse(text);
    if (parsed == null) {
      return const Err(ValidationError('Enter a number.', field: 'target'));
    }
    if (kind == GoalKind.sessionsPerWeek &&
        parsed != parsed.truncateToDouble()) {
      return const Err(
        ValidationError('Enter a whole number.', field: 'target'),
      );
    }
    final double target;
    switch (validateTarget(kind, parsed)) {
      case Ok(:final value):
        target = value;
      case Err(:final error):
        return Err(ValidationError(error.message, field: 'target'));
    }

    final now = clock.now();
    final today = CalendarDate.fromInstant(now);
    final DateTime? endDate;
    final endText = (endDateText ?? '').trim();
    if (endText.isEmpty) {
      endDate = null;
    } else {
      final day = _parseDay(endText);
      if (day == null) {
        return const Err(
          ValidationError('Use the form YYYY-MM-DD.', field: 'endDate'),
        );
      }
      if (day.isBefore(today)) {
        return const Err(
          ValidationError('The date cannot be in the past.', field: 'endDate'),
        );
      }
      endDate = DateTime(day.year, day.month, day.day).toUtc();
    }

    final stamp = now.toUtc();
    final goal = Goal(
      id: newId(),
      kind: kind,
      site: goalSite,
      target: target,
      startDate: stamp,
      endDate: endDate,
      createdAt: stamp,
      updatedAt: stamp,
    );
    try {
      await repository.replaceActive(kind, goal, site: goalSite);
    } on Object catch (e) {
      return Err(StorageError('Could not save the goal.', cause: e));
    }
    return Ok(goal);
  }

  /// Clears the active goal of [kind] (and [site]); the target history keeps
  /// it. Ok even when no goal was set.
  Future<Result<bool>> clear(GoalKind kind, {MeasurementSite? site}) async {
    if (!kinds.contains(kind)) {
      return const Err(ValidationError('This goal type is not supported.'));
    }
    final goalSite = kind == GoalKind.measurement ? site : null;
    if (kind == GoalKind.measurement && goalSite == null) {
      return const Err(ValidationError('Choose a body site.', field: 'site'));
    }
    try {
      final had = (await repository.active()).any(
        (g) =>
            g.kind == kind &&
            (kind != GoalKind.measurement || g.site == goalSite),
      );
      await repository.replaceActive(kind, null, site: goalSite);
      return Ok(had);
    } on Object catch (e) {
      return Err(StorageError('Could not clear the goal.', cause: e));
    }
  }

  static CalendarDate? _parseDay(String text) {
    final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(text);
    if (m == null) return null;
    final day = CalendarDate(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
    );
    return day.iso == text ? day : null;
  }
}
