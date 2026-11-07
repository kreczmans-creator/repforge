import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/features/analytics/application/save_goal.dart';

/// Saves or clears a body weight, measurement or sessions-per-week goal.
final saveGoalProvider = Provider<SaveGoal>(
  (ref) => SaveGoal(
    repository: ref.watch(goalRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);
