import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/personal_records.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/training/volume.dart';

/// Personal records of one exercise, derived from its history (TRN-026).
class ExerciseRecords {
  const ExerciseRecords({required this.current, required this.recordSetIds});

  /// The standing record of each slot.
  final Map<PrKey, PersonalRecord> current;

  /// Sets that were a record when they were recorded (the PR indicator).
  final Set<String> recordSetIds;
}

/// Use case: the personal records of an exercise. Reads the recorded history
/// every time, so an edit or a delete is reflected immediately.
final class GetExerciseRecords {
  const GetExerciseRecords({required this.sessions});

  final WorkoutSessionRepository sessions;

  Future<Result<ExerciseRecords>> call(String exerciseId) async {
    try {
      final history = await sessions.performedSets(exerciseId);
      return Ok(
        ExerciseRecords(
          current: PersonalRecordRules.currentRecords(history),
          recordSetIds: PersonalRecordRules.recordSetIds(history),
        ),
      );
    } on Object catch (e) {
      return Err(StorageError('Could not read the records.', cause: e));
    }
  }
}

/// Use case: weekly training volume for the whole weeks touched by [from, to)
/// (TRN-027(4)), with the week start and day start from `settings`. The range
/// is widened to week boundaries (a week starts on `weekStartDay` at
/// `dayStartHour`), so a mid-week `from` or `to` never yields a part-week
/// total: every session of a returned week is counted.
final class GetWeeklyVolume {
  const GetWeeklyVolume({required this.sessions, required this.exercises});

  final WorkoutSessionRepository sessions;
  final ExerciseRepository exercises;

  Future<Result<List<WeekVolume>>> call({
    required DateTime from,
    required DateTime to,
    required AppSettings settings,
  }) async {
    try {
      final first = VolumeRules.weekStart(
        from,
        weekStartDay: settings.weekStartDay,
        dayStartHour: settings.dayStartHour,
      );
      final lastWeek = VolumeRules.weekStart(
        to.isAfter(from) ? to.subtract(const Duration(microseconds: 1)) : from,
        weekStartDay: settings.weekStartDay,
        dayStartHour: settings.dayStartHour,
      );
      // Calendar arithmetic (not a 7-day Duration) so a DST change does not
      // shift the boundary.
      final list = await sessions.sessionsBetween(
        DateTime(first.year, first.month, first.day, settings.dayStartHour),
        DateTime(
          lastWeek.year,
          lastWeek.month,
          lastWeek.day + 7,
          settings.dayStartHour,
        ),
      );
      final byId = <String, Exercise>{};
      for (final id in {
        for (final s in list) ...s.sets.map((x) => x.exerciseId),
      }) {
        final e = await exercises.byId(id);
        if (e != null) byId[id] = e;
      }
      return Ok(
        VolumeRules.byWeek(
          list,
          byId,
          weekStartDay: settings.weekStartDay,
          dayStartHour: settings.dayStartHour,
        ),
      );
    } on Object catch (e) {
      return Err(StorageError('Could not read the volume.', cause: e));
    }
  }
}
