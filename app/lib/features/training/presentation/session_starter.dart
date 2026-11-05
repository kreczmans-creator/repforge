import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/session_use_cases.dart';
import 'package:repforge/features/training/application/session_view.dart';
import 'package:repforge/features/training/application/training_providers.dart';
import 'package:repforge/ui/error_text.dart';

/// Starts a session (TRN-016) and opens the session screen. An error shows in
/// a snackbar and nothing opens; exercises that were skipped (archived or
/// deleted) are handed to the session screen, which lists them.
extension SessionStarter on WidgetRef {
  Future<void> _open(
    BuildContext context,
    Future<Result<StartedSession>> Function() start,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final result = await start();
    switch (result) {
      case Ok(:final value):
        read(startWarningsProvider.notifier)
            .put(value.session.id, value.warnings);
        await router.push<void>(RfRoutes.trainSession(value.session.id));
      case Err(:final error):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  /// An empty session (TRN-016(2)); exercises are added during the workout.
  Future<void> startEmpty(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final result = await read(startEmptySessionProvider)();
    switch (result) {
      case Ok<WorkoutSession>(:final value):
        await router.push<void>(RfRoutes.trainSession(value.id));
      case Err<WorkoutSession>(:final error):
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  /// From a workout plan, optionally linking a scheduled occurrence.
  Future<void> startFromPlan(
    BuildContext context,
    String planId, {
    String? scheduledWorkoutId,
  }) => _open(
    context,
    () => read(startSessionFromPlanProvider)(
      planId: planId,
      scheduledWorkoutId: scheduledWorkoutId,
    ),
  );

  /// From a past session: the same exercises, no sets.
  Future<void> startFromPast(BuildContext context, String pastSessionId) =>
      _open(
        context,
        () => read(startSessionFromPastProvider)(pastSessionId: pastSessionId),
      );
}

/// Text for one skipped exercise.
String startWarningText(StartWarning w) {
  final name = w.exerciseName ?? 'An exercise';
  return switch (w.reason) {
    StartSkipReason.archived => '$name is archived and was left out.',
    StartSkipReason.missing => '$name no longer exists and was left out.',
  };
}
