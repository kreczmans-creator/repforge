import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/format.dart';

part 'daily_targets.freezed.dart';

/// Daily nutrition targets derived from the active [Goal]s (GOL-001/002).
/// Null means "no target set" and the UI shows the amount without a bar.
@freezed
abstract class DailyTargets with _$DailyTargets {
  const factory DailyTargets({
    double? kcal,
    double? proteinG,
    double? carbsG,
    double? fatG,
    double? fibreG,
  }) = _DailyTargets;

  const DailyTargets._();

  /// Picks the latest active goal of each nutrition kind.
  factory DailyTargets.fromGoals(Iterable<Goal> goals) {
    double? pick(GoalKind k) {
      Goal? best;
      for (final g in goals) {
        if (g.kind != k || !g.active) continue;
        if (best == null || g.updatedAt.isAfter(best.updatedAt)) best = g;
      }
      return best?.target;
    }

    return DailyTargets(
      kcal: pick(GoalKind.calories),
      proteinG: pick(GoalKind.protein),
      carbsG: pick(GoalKind.carbs),
      fatG: pick(GoalKind.fat),
      fibreG: pick(GoalKind.fibre),
    );
  }

  static const none = DailyTargets();

  bool get isEmpty =>
      kcal == null &&
      proteinG == null &&
      carbsG == null &&
      fatG == null &&
      fibreG == null;
}

/// Validation for a target value entered by the user (GOL, OQ-13 lower
/// limits are provisional: calories 800–10000 kcal, macros 0–1000 g).
Result<double> validateTarget(GoalKind kind, double value) {
  if (value.isNaN || value.isInfinite) {
    return Err(ValidationError('Enter a number.', field: kind.name));
  }
  final (min, max) = switch (kind) {
    GoalKind.calories => (800.0, 10000.0),
    GoalKind.protein ||
    GoalKind.carbs ||
    GoalKind.fat ||
    GoalKind.fibre => (0.0, 1000.0),
    GoalKind.bodyWeight => (20.0, 500.0),
    GoalKind.measurement => (10.0, 300.0),
    GoalKind.sessionsPerWeek => (0.0, 14.0),
  };
  if (value < min || value > max) {
    return Err(
      ValidationError(
        'Must be between ${formatNumber(min)} and ${formatNumber(max)}.',
        field: kind.name,
      ),
    );
  }
  return Ok(value);
}

/// Today's intake against targets (dashboard, NUT-020). [totals] carries the
/// known sums plus how many entries lacked each nutrient.
@freezed
abstract class DailySummary with _$DailySummary {
  const factory DailySummary({
    required String day,
    required NutrientTotals totals,
    required DailyTargets targets,
    required int entryCount,
  }) = _DailySummary;

  const DailySummary._();

  factory DailySummary.fromEntries({
    required String day,
    required Iterable<FoodLogEntry> entries,
    required DailyTargets targets,
  }) {
    final list = entries.toList();
    return DailySummary(
      day: day,
      totals: NutrientTotals.of(list.map((e) => e.nutrients)),
      targets: targets,
      entryCount: list.length,
    );
  }

  /// Sum of the known intake values. A nutrient is null when no entry knew
  /// it; see [totals] for how many entries were unknown.
  NutrientAmounts get intake => totals.known;

  double? get kcalRemaining =>
      targets.kcal == null ? null : targets.kcal! - intake.kcal;
}
