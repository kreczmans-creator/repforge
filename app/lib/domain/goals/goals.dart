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
  Future<void> upsert(Goal goal);
  Future<void> delete(String id);
}
