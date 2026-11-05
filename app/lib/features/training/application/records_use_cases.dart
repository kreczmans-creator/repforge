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

/// Use case: weekly training volume for the weeks touched by sessions that
/// started in [from, to), with the week start and day start from [settings].
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
      final list = await sessions.sessionsBetween(from, to);
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
