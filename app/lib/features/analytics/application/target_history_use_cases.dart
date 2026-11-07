import 'package:repforge/domain/analytics/target_history.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/features/analytics/application/analytics_guard.dart';

/// Use case: the target history built from every goal row, inactive ones
/// included (GOL-006).
final class LoadTargetHistory {
  const LoadTargetHistory({required this.goals});

  final GoalRepository goals;

  Future<Result<TargetHistory>> call() => guardAnalytics(
    'Could not read the target history.',
    () async => TargetHistory.fromGoals(await goals.history()),
  );
}
