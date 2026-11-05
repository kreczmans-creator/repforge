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

/// True while a start is in progress (the unfinished-workout question
/// included), so a double tap cannot create two sessions.
class SessionStartBusy extends Notifier<bool> {
  @override
  bool build() => false;

  // Method, not a setter: Riverpod notifiers expose state changes this way.
  // ignore: use_setters_to_change_properties
  void set({required bool busy}) => state = busy;
}

final sessionStartBusyProvider = NotifierProvider<SessionStartBusy, bool>(
  SessionStartBusy.new,
);

enum _UnfinishedChoice { continueCurrent, startNew }

/// Asks whether to continue the unfinished workout [active] or start a new
/// one; null when dismissed.
Future<_UnfinishedChoice?> _askUnfinished(
  BuildContext context,
  WorkoutSession active,
) => showDialog<_UnfinishedChoice>(
  context: context,
  builder: (context) => AlertDialog(
    key: const Key('unfinished-dialog'),
    title: const Text('Workout in progress'),
    content: Text(
      '"${active.name}" is not finished. Continue current workout or start '
      'a new one?',
    ),
    actions: [
      TextButton(
        key: const Key('unfinished-new'),
        onPressed: () => Navigator.of(context).pop(_UnfinishedChoice.startNew),
        child: const Text('Start new'),
      ),
      FilledButton(
        key: const Key('unfinished-continue'),
        onPressed: () =>
            Navigator.of(context).pop(_UnfinishedChoice.continueCurrent),
        child: const Text('Continue current'),
      ),
    ],
  ),
);

/// Starts a session (TRN-016) and opens the session screen. An error shows in
/// a snackbar and nothing opens; exercises that were skipped (archived or
/// deleted) are handed to the session screen, which lists them. A second tap
/// while a start is in progress is ignored, and when a workout is unfinished
/// the user chooses between continuing it and starting a new one.
extension SessionStarter on WidgetRef {
  /// Runs [start] once: ignores a call while another is in progress and asks
  /// about an unfinished workout first. Returns the route to open.
  Future<String?> _guarded(
    BuildContext context,
    Future<String?> Function() start,
  ) async {
    final busy = read(sessionStartBusyProvider.notifier);
    if (read(sessionStartBusyProvider)) return null;
    busy.set(busy: true);
    try {
      final active = await read(findUnfinishedSessionProvider)();
      if (active != null) {
        if (!context.mounted) return null;
        final choice = await _askUnfinished(context, active);
        if (choice == null) return null;
        if (choice == _UnfinishedChoice.continueCurrent) {
          return RfRoutes.trainSession(active.id);
        }
      }
      return await start();
    } finally {
      busy.set(busy: false);
    }
  }

  Future<void> _open(
    BuildContext context,
    Future<Result<StartedSession>> Function() start,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final route = await _guarded(context, () async {
      final result = await start();
      switch (result) {
        case Ok(:final value):
          read(startWarningsProvider.notifier)
              .put(value.session.id, value.warnings);
          return RfRoutes.trainSession(value.session.id);
        case Err(:final error):
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(userMessageFor(error))));
          return null;
      }
    });
    if (route != null) await router.push<void>(route);
  }

  /// An empty session (TRN-016(2)); exercises are added during the workout.
  Future<void> startEmpty(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final route = await _guarded(context, () async {
      final result = await read(startEmptySessionProvider)();
      switch (result) {
        case Ok<WorkoutSession>(:final value):
          return RfRoutes.trainSession(value.id);
        case Err<WorkoutSession>(:final error):
          messenger
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(userMessageFor(error))));
          return null;
      }
    });
    if (route != null) await router.push<void>(route);
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
