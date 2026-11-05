import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/scheduled_workout.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';

const _storageMessage = 'Could not save the schedule.';

/// Outcome of generating scheduled workouts: what was created and how many
/// dates were left alone because the occurrence already existed (or the
/// workout is already on that date).
class ScheduleOutcome {
  const ScheduleOutcome({required this.created, required this.alreadyThere});

  final List<ScheduledWorkout> created;
  final int alreadyThere;
}

/// Shared planning of new occurrences.
///
/// Duplicate rule (WP 9): an occurrence is identified by (plan, source date,
/// origin). Generating again never creates an occurrence whose identity
/// exists (whatever its status: a skipped or moved one is not brought back),
/// nor a second occurrence of the plan on a date where it already has a
/// planned or done one. A skipped occurrence on a date does not block it.
class _Scheduler {
  const _Scheduler(this.scheduled, this.clock, this.newId);

  final ScheduledWorkoutRepository scheduled;
  final Clock clock;
  final IdGenerator newId;

  Future<ScheduleOutcome> generate(
    String planId,
    ScheduleOrigin origin,
    Iterable<DateTime> dates,
  ) async {
    final existing = await scheduled.forPlan(planId);
    final identities = {
      for (final w in existing)
        if (w.origin == origin) scheduleDayKey(w.sourceDay),
    };
    final occupied = {
      for (final w in existing)
        if (w.status != ScheduleStatus.skipped) scheduleDayKey(w.day),
    };
    final now = clock.now().toUtc();
    final created = <ScheduledWorkout>[];
    var skipped = 0;
    for (final date in dates) {
      final key = scheduleDayKey(date);
      if (identities.contains(key) || occupied.contains(key)) {
        skipped++;
        continue;
      }
      final w = ScheduledWorkout(
        id: newId(),
        day: scheduleDate(date),
        sourceDay: scheduleDate(date),
        planId: planId,
        origin: origin,
        status: ScheduleStatus.planned,
        createdAt: now,
        updatedAt: now,
      );
      await scheduled.upsert(w);
      created.add(w);
      identities.add(key);
      occupied.add(key);
    }
    return ScheduleOutcome(created: created, alreadyThere: skipped);
  }
}

Future<Result<WorkoutPlan>> _schedulablePlan(
  WorkoutPlanRepository plans,
  String planId,
) async {
  final plan = await plans.byId(planId);
  if (plan == null) {
    return const Err(NotFoundError('That workout no longer exists.'));
  }
  if (plan.archived) {
    return const Err(
      ValidationError(
        'That workout is archived. Restore it first.',
        field: 'planId',
      ),
    );
  }
  return Ok(plan);
}

/// Use case: schedule a workout on one date (TRN-015). Refused when the plan
/// already has a planned or done occurrence on that date.
final class ScheduleOnDate {
  const ScheduleOnDate({
    required this.plans,
    required this.scheduled,
    required this.clock,
    required this.newId,
  });

  final WorkoutPlanRepository plans;
  final ScheduledWorkoutRepository scheduled;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<ScheduledWorkout>> call({
    required String planId,
    required DateTime date,
  }) async {
    try {
      final plan = await _schedulablePlan(plans, planId);
      if (plan case Err(:final error)) return Err(error);
      final outcome = await _Scheduler(
        scheduled,
        clock,
        newId,
      ).generate(planId, ScheduleOrigin.date, [date]);
      if (outcome.created.isEmpty) {
        return const Err(
          ValidationError(
            'That workout is already scheduled on that date.',
            field: 'date',
          ),
        );
      }
      return Ok(outcome.created.single);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

/// Use case: schedule a workout on a weekday pattern for the next 8 weeks
/// from `start` (TRN-015(1)). `weekdays` (1 Monday to 7 Sunday) defaults to
/// the plan's own `scheduledWeekdays`; an empty pattern is refused. Safe to
/// run again: existing occurrences are not duplicated.
final class ScheduleWeekdays {
  const ScheduleWeekdays({
    required this.plans,
    required this.scheduled,
    required this.clock,
    required this.newId,
  });

  final WorkoutPlanRepository plans;
  final ScheduledWorkoutRepository scheduled;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<ScheduleOutcome>> call({
    required String planId,
    required DateTime start,
    List<int>? weekdays,
  }) async {
    try {
      final plan = await _schedulablePlan(plans, planId);
      if (plan case Err(:final error)) return Err(error);
      final days =
          weekdays ?? (plan as Ok<WorkoutPlan>).value.scheduledWeekdays;
      if (days.isEmpty ||
          days.any((d) => d < 1 || d > 7) ||
          days.toSet().length != days.length) {
        return const Err(
          ValidationError(
            'Choose weekdays from 1 (Monday) to 7 (Sunday), each once.',
            field: 'weekdays',
          ),
        );
      }
      return Ok(
        await _Scheduler(
          scheduled,
          clock,
          newId,
        ).generate(planId, ScheduleOrigin.weekday, weekdayDates(start, days)),
      );
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

/// Use case: schedule a split's cycle for the next 8 weeks (TRN-015, TRN-014):
/// cycle day 0 on `start`, repeating; rest days produce nothing. A workout of
/// the cycle that was deleted or archived is left out and counted in
/// [SplitScheduleOutcome.missingPlans]. Safe to run again.
final class ScheduleSplitCycle {
  const ScheduleSplitCycle({
    required this.splits,
    required this.plans,
    required this.scheduled,
    required this.clock,
    required this.newId,
  });

  final TrainingSplitRepository splits;
  final WorkoutPlanRepository plans;
  final ScheduledWorkoutRepository scheduled;
  final Clock clock;
  final IdGenerator newId;

  Future<Result<SplitScheduleOutcome>> call({
    required String splitId,
    required DateTime start,
  }) async {
    try {
      final split = await splits.byId(splitId);
      if (split == null) {
        return const Err(NotFoundError('That split no longer exists.'));
      }
      final usable = <String>{};
      final missing = <String>{};
      for (final id in split.days.map((d) => d.planId).whereType<String>()) {
        final plan = await plans.byId(id);
        (plan == null || plan.archived ? missing : usable).add(id);
      }
      final byPlan = <String, List<DateTime>>{};
      for (final o in splitOccurrences(split, start)) {
        if (usable.contains(o.planId)) {
          byPlan.putIfAbsent(o.planId, () => []).add(o.date);
        }
      }
      final created = <ScheduledWorkout>[];
      var already = 0;
      final scheduler = _Scheduler(scheduled, clock, newId);
      for (final entry in byPlan.entries) {
        final outcome = await scheduler.generate(
          entry.key,
          ScheduleOrigin.split,
          entry.value,
        );
        created.addAll(outcome.created);
        already += outcome.alreadyThere;
      }
      created.sort((a, b) => a.day.compareTo(b.day));
      return Ok(
        SplitScheduleOutcome(
          created: created,
          alreadyThere: already,
          missingPlans: missing.length,
        ),
      );
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

/// Outcome of [ScheduleSplitCycle].
class SplitScheduleOutcome extends ScheduleOutcome {
  const SplitScheduleOutcome({
    required super.created,
    required super.alreadyThere,
    required this.missingPlans,
  });

  /// Distinct workouts of the cycle that no longer exist or are archived.
  final int missingPlans;
}

/// Use case: move a planned occurrence to another date (TRN-015(2)). Only the
/// scheduled row changes; the plan is never touched. Refused when it is not
/// planned or the plan already has a planned or done occurrence on the new
/// date.
final class MoveScheduledWorkout {
  const MoveScheduledWorkout({required this.scheduled, required this.clock});

  final ScheduledWorkoutRepository scheduled;
  final Clock clock;

  Future<Result<ScheduledWorkout>> call({
    required String scheduledWorkoutId,
    required DateTime newDate,
  }) async {
    try {
      final w = await scheduled.byId(scheduledWorkoutId);
      if (w == null) {
        return const Err(
          NotFoundError('That scheduled workout no longer exists.'),
        );
      }
      if (w.status != ScheduleStatus.planned) {
        return const Err(
          ValidationError('Only a planned workout can be moved.'),
        );
      }
      final key = scheduleDayKey(newDate);
      final clash = (await scheduled.forPlan(w.planId)).any(
        (o) =>
            o.id != w.id &&
            o.status != ScheduleStatus.skipped &&
            scheduleDayKey(o.day) == key,
      );
      if (clash) {
        return const Err(
          ValidationError(
            'That workout is already scheduled on that date.',
            field: 'date',
          ),
        );
      }
      final moved = w.copyWith(
        day: scheduleDate(newDate),
        updatedAt: clock.now().toUtc(),
      );
      await scheduled.upsert(moved);
      return Ok(moved);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

/// Use case: skip a planned occurrence (TRN-015(2)). It stays on its date as
/// skipped, so regenerating the schedule does not bring it back; the plan is
/// never touched.
final class SkipScheduledWorkout {
  const SkipScheduledWorkout({required this.scheduled, required this.clock});

  final ScheduledWorkoutRepository scheduled;
  final Clock clock;

  Future<Result<ScheduledWorkout>> call(String scheduledWorkoutId) async {
    try {
      final w = await scheduled.byId(scheduledWorkoutId);
      if (w == null) {
        return const Err(
          NotFoundError('That scheduled workout no longer exists.'),
        );
      }
      if (w.status != ScheduleStatus.planned) {
        return const Err(
          ValidationError('Only a planned workout can be skipped.'),
        );
      }
      final skipped = w.copyWith(
        status: ScheduleStatus.skipped,
        updatedAt: clock.now().toUtc(),
      );
      await scheduled.upsert(skipped);
      return Ok(skipped);
    } on Object catch (e) {
      return Err(StorageError(_storageMessage, cause: e));
    }
  }
}

/// Use case: the scheduled workouts from `from` to `to` inclusive (dates).
final class ScheduledWorkoutsInRange {
  const ScheduledWorkoutsInRange({required this.scheduled});

  final ScheduledWorkoutRepository scheduled;

  Future<Result<List<ScheduledWorkout>>> call(
    DateTime from,
    DateTime to,
  ) async {
    if (scheduleDate(to).isBefore(scheduleDate(from))) {
      return const Err(
        ValidationError('The end date is before the start.', field: 'to'),
      );
    }
    try {
      return Ok(await scheduled.inRange(from, to));
    } on Object catch (e) {
      return Err(StorageError('Could not read the schedule.', cause: e));
    }
  }
}
