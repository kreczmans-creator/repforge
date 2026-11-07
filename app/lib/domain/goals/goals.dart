import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/measurements/measurements.dart';

part 'goals.freezed.dart';

/// Goal kinds (GOL-001..).
enum GoalKind {
  calories,
  protein,
  carbs,
  fat,
  fibre,
  bodyWeight,
  measurement,
  sessionsPerWeek,
}

/// A target the user is working towards. Daily nutrition goals have no end
/// date; weight and measurement goals usually do.
@freezed
abstract class Goal with _$Goal {
  const factory Goal({
    required String id,
    required GoalKind kind,
    required double target,
    required DateTime startDate,
    required DateTime createdAt,
    required DateTime updatedAt,
    MeasurementSite? site,
    DateTime? endDate,
    @Default(true) bool active,
  }) = _Goal;
}

abstract interface class GoalRepository {
  Stream<List<Goal>> watchActive();
  Future<List<Goal>> active();

  /// Every stored goal that is not deleted, inactive rows included, newest
  /// first (by start date, then creation time). Read-only: it is the input
  /// of the target history (GOL-006; WP 11 plan decision 3a) and changes no
  /// stored data.
  Future<List<Goal>> history();

  /// Live form of [history].
  Stream<List<Goal>> watchHistory();
  Future<void> upsert(Goal goal);

  /// Atomically deactivates every active goal of [kind] (and [site] when the
  /// kind is a measurement) and inserts [next] when it is not null.
  Future<void> replaceActive(
    GoalKind kind,
    Goal? next, {
    MeasurementSite? site,
  });

  /// Applies [changes] (kind → replacement goal, or null to clear) in ONE
  /// transaction: either every kind is replaced or none is. Site-less kinds
  /// only. Throws [ArgumentError] (after rolling back) when a goal's kind
  /// does not match its key.
  Future<void> replaceActiveAll(Map<GoalKind, Goal?> changes);
  Future<void> delete(String id);
}
