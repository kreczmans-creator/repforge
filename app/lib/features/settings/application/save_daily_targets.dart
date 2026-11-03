import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/features/measurements/application/record_body_weight.dart';

/// Use case: validate and persist the daily nutrition targets as active
/// goals. Blank input for a kind removes that target (deactivates the goal).
final class SaveDailyTargets {
  const SaveDailyTargets({
    required this.repository,
    required this.clock,
    required this.newId,
  });

  final GoalRepository repository;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<DailyTargets>> call({
    required Map<GoalKind, String> input,
    required List<Goal> existing,
  }) async {
    const kinds = [
      GoalKind.calories,
      GoalKind.protein,
      GoalKind.carbs,
      GoalKind.fat,
      GoalKind.fibre,
    ];
    final parsed = <GoalKind, double?>{};
    for (final k in kinds) {
      final text = (input[k] ?? '').trim().replaceAll(',', '.');
      if (text.isEmpty) {
        parsed[k] = null;
        continue;
      }
      final v = double.tryParse(text);
      if (v == null) {
        return Err(ValidationError('Enter a number.', field: k.name));
      }
      switch (validateTarget(k, v)) {
        case Ok(:final value):
          parsed[k] = value;
        case Err(:final error):
          return Err(error);
      }
    }
    final now = clock.now().toUtc();
    try {
      for (final k in kinds) {
        final current = existing.where((g) => g.kind == k && g.active).toList();
        final v = parsed[k];
        if (v == null) {
          for (final g in current) {
            await repository.upsert(g.copyWith(active: false, updatedAt: now));
          }
        } else if (current.length == 1 && current.single.target == v) {
          continue;
        } else {
          for (final g in current) {
            await repository.upsert(g.copyWith(active: false, updatedAt: now));
          }
          await repository.upsert(
            Goal(
              id: newId(),
              kind: k,
              target: v,
              startDate: now,
              createdAt: now,
              updatedAt: now,
            ),
          );
        }
      }
    } on Exception catch (e) {
      return Err(StorageError('Could not save targets.', cause: e));
    }
    return Ok(
      DailyTargets(
        kcal: parsed[GoalKind.calories],
        proteinG: parsed[GoalKind.protein],
        carbsG: parsed[GoalKind.carbs],
        fatG: parsed[GoalKind.fat],
        fibreG: parsed[GoalKind.fibre],
      ),
    );
  }
}
