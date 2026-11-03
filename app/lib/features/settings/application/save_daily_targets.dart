import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/goals/goals.dart';

/// Use case: validate and persist the daily nutrition targets as active
/// goals. Blank input for a kind removes that target. Reads the current
/// goals itself and replaces each kind atomically, so a stale UI snapshot
/// or a mid-way failure cannot leave duplicates or a missing target.
final class SaveDailyTargets {
  const SaveDailyTargets({
    required this.repository,
    required this.clock,
    required this.newId,
  });

  final GoalRepository repository;
  final Clock clock;
  final IdGenerator newId;

  static const List<GoalKind> kinds = [
    GoalKind.calories,
    GoalKind.protein,
    GoalKind.carbs,
    GoalKind.fat,
    GoalKind.fibre,
  ];

  Future<Result<DailyTargets>> call({
    required Map<GoalKind, String> input,
  }) async {
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
      final existing = await repository.active();
      for (final k in kinds) {
        final current = existing.where((g) => g.kind == k).toList();
        final v = parsed[k];
        if (v == null) {
          if (current.isNotEmpty) await repository.replaceActive(k, null);
        } else if (current.length == 1 && current.single.target == v) {
          continue;
        } else {
          await repository.replaceActive(
            k,
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
