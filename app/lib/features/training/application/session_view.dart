import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/personal_records.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/features/training/application/session_use_cases.dart';
import 'package:repforge/features/training/application/training_providers.dart';

/// What a session entry pre-fills and hints (TRN-016(1), TRN-018): the plan
/// row it came from and the sets of the previous session with the exercise.
class EntryPrefill {
  const EntryPrefill({
    required this.sessionExerciseId,
    required this.exerciseId,
    this.previous = const [],
    this.target,
  });

  final String sessionExerciseId;
  final String exerciseId;

  /// Completed sets of the most recent other session with this exercise that
  /// started before (or with) this one, in performed order; empty when none.
  final List<SessionSet> previous;

  /// The plan row the entry was created from, when the session has a plan
  /// that still lists the exercise.
  final PlanExercise? target;
}

/// Everything the session screen and the history detail show, read in one go.
class SessionView {
  const SessionView({
    required this.session,
    required this.exercises,
    required this.prefill,
    required this.recordSetIds,
  });

  final WorkoutSession session;

  /// Exercises of the entries by id (archived ones included); an exercise
  /// that was deleted is absent.
  final Map<String, Exercise> exercises;
  final Map<String, EntryPrefill> prefill;

  /// Sets that were a personal record when recorded (TRN-026), derived from
  /// the history on every read so an edit or delete is reflected.
  final Set<String> recordSetIds;

  List<SessionSet> setsOf(String entryId) => [
    for (final s in session.sets)
      if (s.sessionExerciseId == entryId) s,
  ]..sort((a, b) => a.setOrder.compareTo(b.setOrder));
}

/// Use case (read): loads a session with its exercises, pre-fill data and
/// personal-record flags. Returns null inside `Ok` when the session does not
/// exist or is deleted.
final class LoadSessionView {
  const LoadSessionView({
    required this.sessions,
    required this.exercises,
    required this.plans,
  });

  final WorkoutSessionRepository sessions;
  final ExerciseRepository exercises;
  final WorkoutPlanRepository plans;

  /// The completed sets of the newest other session with [exerciseId] that
  /// started no later than [session], so correcting an old session hints with
  /// what was done before it, however many newer sessions exist. Pages
  /// through the history newest first until one qualifies.
  Future<List<SessionSet>> _previousSets(
    WorkoutSession session,
    String exerciseId,
  ) async {
    const page = 20;
    for (var offset = 0; ; offset += page) {
      final history = await sessions.sessionsForExercise(
        exerciseId,
        limit: page,
        offset: offset,
      );
      for (final h in history) {
        if (h.sessionId != session.id &&
            !h.startedAt.isAfter(session.startedAt)) {
          return h.sets;
        }
      }
      if (history.length < page) return const [];
    }
  }

  Future<Result<SessionView?>> call(String sessionId) async {
    try {
      final session = await sessions.byId(sessionId);
      if (session == null) return const Ok(null);
      final plan = session.planId == null
          ? null
          : await plans.byId(session.planId!);
      final ids = {for (final e in session.exercises) e.exerciseId};
      final byId = <String, Exercise>{};
      final previous = <String, List<SessionSet>>{};
      final records = <String>{};
      for (final id in ids) {
        final e = await exercises.byId(id);
        if (e != null) byId[id] = e;
        previous[id] = await _previousSets(session, id);
        records.addAll(
          PersonalRecordRules.recordSetIds(await sessions.performedSets(id)),
        );
      }
      // The k-th entry of an exercise takes the k-th plan row of it.
      final seen = <String, int>{};
      final prefill = <String, EntryPrefill>{};
      final ordered = [...session.exercises]
        ..sort((a, b) => a.position.compareTo(b.position));
      for (final entry in ordered) {
        final k = seen.update(
          entry.exerciseId,
          (n) => n + 1,
          ifAbsent: () => 1,
        );
        final rows = [
          if (plan != null)
            for (final p in plan.exercises)
              if (p.exerciseId == entry.exerciseId) p,
        ]..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
        prefill[entry.id] = EntryPrefill(
          sessionExerciseId: entry.id,
          exerciseId: entry.exerciseId,
          previous: previous[entry.exerciseId] ?? const [],
          target: k - 1 < rows.length ? rows[k - 1] : null,
        );
      }
      return Ok(
        SessionView(
          session: session.copyWith(exercises: ordered),
          exercises: byId,
          prefill: prefill,
          recordSetIds: records,
        ),
      );
    } on Object catch (e) {
      return Err(StorageError('Could not load the session.', cause: e));
    }
  }
}

final loadSessionViewProvider = Provider<LoadSessionView>(
  (ref) => LoadSessionView(
    sessions: ref.watch(workoutSessionRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    plans: ref.watch(workoutPlanRepositoryProvider),
  ),
);

/// One session for the session screen and the detail screen; null when it
/// does not exist or is deleted. Screens invalidate it after a change.
// ignore: specify_nonobvious_property_types, the family type is not exported
final sessionViewProvider = FutureProvider.autoDispose
    .family<SessionView?, String>((ref, id) async {
      final result = await ref.watch(loadSessionViewProvider)(id);
      return switch (result) {
        Ok(:final value) => value,
        Err(:final error) => throw StateError(error.message),
      };
    });

/// Ids of the sets of an exercise that were personal records when recorded
/// (TRN-026), for the exercise history.
// ignore: specify_nonobvious_property_types, the family type is not exported
final exerciseRecordSetIdsProvider = FutureProvider.autoDispose
    .family<Set<String>, String>((ref, exerciseId) async {
      final result = await ref.watch(getExerciseRecordsProvider)(exerciseId);
      return switch (result) {
        Ok(:final value) => value.recordSetIds,
        Err(:final error) => throw StateError(error.message),
      };
    });

/// Sessions newest first, `limit` of them (TRN-025 paging: 20, then more).
// ignore: specify_nonobvious_property_types, the family type is not exported
final sessionHistoryProvider = StreamProvider.autoDispose
    .family<List<WorkoutSession>, int>(
      (ref, limit) =>
          ref.watch(workoutSessionRepositoryProvider).watchAll(limit: limit),
    );

/// Sessions shown per page of the history (TRN-025(2)).
const sessionHistoryPage = 20;

/// The session in progress (not finished), if any, for "Continue workout".
final activeSessionProvider = Provider<AsyncValue<WorkoutSession?>>(
  (ref) => ref
      .watch(sessionHistoryProvider(100))
      .whenData((all) => all.where((s) => s.endedAt == null).firstOrNull),
);

/// Use case (read): the session that was started and not finished, if any
/// (newest first among the latest 100), for the "Continue or start new?"
/// question when starting a workout.
final class FindUnfinishedSession {
  const FindUnfinishedSession({required this.sessions});

  final WorkoutSessionRepository sessions;

  /// Null when there is none or the history cannot be read (starting a
  /// workout must not be blocked by a failed lookup).
  Future<WorkoutSession?> call() async {
    try {
      final all = await sessions.watchAll().first;
      return all.where((s) => s.endedAt == null).firstOrNull;
    } on Object {
      return null;
    }
  }
}

final findUnfinishedSessionProvider = Provider<FindUnfinishedSession>(
  (ref) => FindUnfinishedSession(
    sessions: ref.watch(workoutSessionRepositoryProvider),
  ),
);

/// Exercises skipped when a session was started, by session id, so the
/// session screen can show them (TRN-016).
class StartWarningsController
    extends Notifier<Map<String, List<StartWarning>>> {
  @override
  Map<String, List<StartWarning>> build() => const {};

  void put(String sessionId, List<StartWarning> warnings) {
    if (warnings.isEmpty) return;
    state = {...state, sessionId: warnings};
  }

  void dismiss(String sessionId) {
    state = {...state}..remove(sessionId);
  }
}

final startWarningsProvider =
    NotifierProvider<StartWarningsController, Map<String, List<StartWarning>>>(
      StartWarningsController.new,
    );
