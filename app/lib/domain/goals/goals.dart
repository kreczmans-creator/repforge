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
  Future<void> upsert(Goal goal);

  /// Atomically deactivates every active goal of [kind] (and [site] when the
  /// kind is a measurement) and inserts [next] when it is not null.
  Future<void> replaceActive(
    GoalKind kind,
    Goal? next, {
    MeasurementSite? site,
  });
  Future<void> delete(String id);
}
