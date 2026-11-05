import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/core/search_key.dart';
import 'package:repforge/domain/nutrition/nutrition.dart' show DataProvenance;
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_rules.dart';
import 'package:repforge/domain/units/format.dart';

/// Longest accepted exercise, plan or split name.
const maxTrainingNameLength = 100;

/// Most aliases one exercise may carry.
const maxExerciseAliases = 20;

ValidationError _err(String message, String field) =>
    ValidationError(message, field: field);

/// Parses a duration typed by the user (TRN-005(2)). Accepted forms:
/// `mm:ss` (`1:30` is 90 s; minutes may exceed 59, seconds may not),
/// `h:mm:ss` (minutes and seconds 0-59) and a plain count of seconds (`90`).
/// Whitespace around the text is ignored. Zero, negative, fractional and
/// malformed input is rejected; the result is stored as whole seconds.
Result<Duration> parseDuration(String input) {
  const bad = ValidationError(
    'Enter a duration as mm:ss, h:mm:ss or seconds.',
    field: 'duration',
  );
  final text = input.trim();
  if (text.isEmpty) return const Err(bad);
  final parts = text.split(':');
  if (parts.length > 3 || parts.any((p) => !RegExp(r'^\d{1,6}$').hasMatch(p))) {
    return const Err(bad);
  }
  final n = [for (final p in parts) int.parse(p)];
  final int seconds;
  if (n.length == 1) {
    seconds = n[0];
  } else if (n.length == 2) {
    if (n[1] > 59) return const Err(bad);
    seconds = n[0] * 60 + n[1];
  } else {
    if (n[1] > 59 || n[2] > 59) return const Err(bad);
    seconds = n[0] * 3600 + n[1] * 60 + n[2];
  }
  if (seconds <= 0) {
    return const Err(_zeroDuration);
  }
  return Ok(Duration(seconds: seconds));
}

const _zeroDuration = ValidationError(
  'Duration must be greater than zero.',
  field: 'duration',
);

/// Display form of a distance (TRN-006(2)): metres below 1000 (`400 m`,
/// `999.5 m`), kilometres from 1000 m with one decimal (`1.2 km`, `10 km`).
/// Display only: the stored metres value is never changed.
String formatDistance(double metres) {
  if (metres >= 1000) {
    return '${formatNumber(metres / 1000)} km';
  }
  return '${formatNumber(metres)} m';
}

/// Normalises library search text: lower-cased, diacritics folded, trimmed,
/// runs of whitespace collapsed (TRN-008(3)). Shares the folding used by
/// food search.
String normaliseExerciseSearch(String input) =>
    normaliseSearchKey(input).trim().replaceAll(RegExp(r'\s+'), ' ');

/// Validates an exercise for saving (TRN-012(1)) and returns it normalised
/// (name and aliases trimmed, empty and duplicate aliases removed, secondary
/// muscles and equipment de-duplicated, order kept).
///
/// Rules: a non-empty name of at most [maxTrainingNameLength] characters;
/// type, category and primary muscle are required by the type system; the
/// primary muscle is not repeated among the secondary muscles; at most
/// [maxExerciseAliases] aliases.
Result<Exercise> validateExercise(Exercise exercise) {
  final name = exercise.name.trim();
  if (name.isEmpty) return Err(_err('Enter a name.', 'name'));
  if (name.length > maxTrainingNameLength) {
    return Err(
      _err(
        'The name can be at most $maxTrainingNameLength characters.',
        'name',
      ),
    );
  }
  if (exercise.secondaryMuscles.contains(exercise.primaryMuscle)) {
    return Err(
      _err(
        'The primary muscle group cannot also be a secondary one.',
        'secondaryMuscles',
      ),
    );
  }
  final seen = <String>{};
  final aliases = <String>[];
  for (final a in exercise.aliases) {
    final t = a.trim();
    if (t.isEmpty) continue;
    if (t.length > maxTrainingNameLength) {
      return Err(_err('An alias is too long.', 'aliases'));
    }
    if (seen.add(normaliseExerciseSearch(t))) aliases.add(t);
  }
  if (aliases.length > maxExerciseAliases) {
    return Err(
      _err('At most $maxExerciseAliases aliases are allowed.', 'aliases'),
    );
  }
  return Ok(
    exercise.copyWith(
      name: name,
      aliases: aliases,
      secondaryMuscles: exercise.secondaryMuscles.toSet().toList(),
      equipment: exercise.equipment.toSet().toList(),
    ),
  );
}

Duration _wholeSeconds(Duration d) => Duration(seconds: d.inSeconds);

double _roundMetres(double m) => (m * 10).roundToDouble() / 10;

Result<Duration> _positiveDuration(Duration d, String field) {
  if (d.inSeconds < 1) {
    return Err(_err('Duration must be greater than zero.', field));
  }
  return Ok(_wholeSeconds(d));
}

Result<double> _positiveMetres(double m, String field) {
  if (m.isNaN || m.isInfinite) return Err(_err('Enter a distance.', field));
  final r = _roundMetres(m);
  if (r <= 0) {
    return Err(_err('Distance must be greater than zero.', field));
  }
  return Ok(r);
}

/// Validates [data] for [exercise] and returns it normalised (durations in
/// whole seconds, metres to 0.1 m). Used by `RecordSet`, so invalid
/// combinations are rejected at use-case level (D06 WP 8 acceptance).
///
/// - the set's type must equal the exercise's type (a weighted set on a timed
///   exercise is rejected);
/// - repetitions 1-100 ([TrainingRules.validReps]);
/// - loads and assistance are valid by construction (`LoadKg.of` rejects
///   off-step and negative input);
/// - durations and metres greater than zero;
/// - average heart rate 30-250 bpm;
/// - energy at least 0, and present only together with a provenance of
///   `userEntered` or `estimated` (TRN-007(2)); never read by nutrition;
/// - [exertion], when given, passes [TrainingRules.validExertion].
Result<SetData> validateSetForExercise(
  Exercise exercise,
  SetData data, {
  Exertion? exertion,
}) {
  if (data.type != exercise.type) {
    return Err(
      _err(
        'A ${data.type.name} set cannot be recorded for a '
            '${exercise.type.name} exercise.',
        'type',
      ),
    );
  }
  if (exertion != null && !TrainingRules.validExertion(exertion)) {
    return Err(
      _err(
        exertion.scale == ExertionScale.rpe
            ? 'RPE must be ${TrainingRules.rpeMin} to ${TrainingRules.rpeMax} '
                  'in half steps.'
            : 'RIR must be a whole number from ${TrainingRules.rirMin} to '
                  '${TrainingRules.rirMax}.',
        'exertion',
      ),
    );
  }
  Err<SetData>? repsError(int reps) => TrainingRules.validReps(reps)
      ? null
      : Err(_err('Repetitions must be 1 to 100.', 'reps'));

  switch (data) {
    case WeightedSet(:final reps):
      final e = repsError(reps);
      if (e != null) return e;
      return Ok(data);
    case BodyweightSet(:final reps):
      final e = repsError(reps);
      if (e != null) return e;
      return Ok(data);
    case AssistedSet(:final reps):
      final e = repsError(reps);
      if (e != null) return e;
      return Ok(data);
    case TimedSet(:final duration, :final addedLoad):
      final d = _positiveDuration(duration, 'duration');
      if (d case Err(:final error)) return Err(error);
      return Ok(
        TimedSet(duration: (d as Ok<Duration>).value, addedLoad: addedLoad),
      );
    case DistanceSet(:final metres, :final duration):
      final m = _positiveMetres(metres, 'metres');
      if (m case Err(:final error)) return Err(error);
      final checked = duration == null
          ? null
          : _positiveDuration(duration, 'duration');
      if (checked case Err(:final error)) return Err(error);
      return Ok(
        DistanceSet(
          metres: (m as Ok<double>).value,
          duration: (checked as Ok<Duration>?)?.value,
        ),
      );
    case final CardioSet cardio:
      final d = _positiveDuration(cardio.duration, 'duration');
      if (d case Err(:final error)) return Err(error);
      final rawMetres = cardio.metres;
      final metres = rawMetres == null
          ? null
          : _positiveMetres(rawMetres, 'metres');
      if (metres case Err(:final error)) return Err(error);
      final hr = cardio.averageHeartRate;
      if (hr != null && (hr < 30 || hr > 250)) {
        return Err(
          _err('Average heart rate must be 30 to 250 bpm.', 'averageHeartRate'),
        );
      }
      final kcal = cardio.energyKcal;
      final provenance = cardio.energyProvenance;
      if (kcal != null) {
        if (kcal.isNaN || kcal.isInfinite || kcal < 0) {
          return Err(_err('Energy must be zero or more.', 'energyKcal'));
        }
        if (provenance != DataProvenance.userEntered &&
            provenance != DataProvenance.estimated) {
          return Err(
            _err(
              'Energy must be labelled user-entered or estimated.',
              'energyProvenance',
            ),
          );
        }
      } else if (provenance != null) {
        return Err(
          _err('An energy label needs an energy value.', 'energyProvenance'),
        );
      }
      return Ok(
        CardioSet(
          duration: (d as Ok<Duration>).value,
          metres: (metres as Ok<double>?)?.value,
          averageHeartRate: hr,
          energyKcal: kcal,
          energyProvenance: provenance,
        ),
      );
  }
}

/// Validates a plan exercise (TRN-013(1)) and returns it normalised (target
/// duration in whole seconds, metres to 0.1 m).
///
/// Sets 1-20; reps as a range with both ends or neither, each 1-100 and
/// min at most max (a fixed target has min = max); rest 0-3600 s; target
/// duration and distance greater than zero; sort order at least 0. When
/// [type] is given, targets must fit it: reps for weighted, bodyweight and
/// assisted; duration for timed, distance and cardio; distance for distance
/// and cardio; load for every type except distance and cardio.
Result<PlanExercise> validatePlanExercise(
  PlanExercise e, {
  ExerciseType? type,
}) {
  if (e.targetSets < 1 || e.targetSets > 20) {
    return Err(_err('Sets must be 1 to 20.', 'targetSets'));
  }
  if (e.sortOrder < 0) return Err(_err('Invalid position.', 'sortOrder'));
  final min = e.repsMin;
  final max = e.repsMax;
  if ((min == null) != (max == null)) {
    return Err(_err('Enter both ends of the rep range.', 'reps'));
  }
  if (min != null && max != null) {
    if (!TrainingRules.validReps(min) || !TrainingRules.validReps(max)) {
      return Err(_err('Repetitions must be 1 to 100.', 'reps'));
    }
    if (min > max) {
      return Err(_err('The minimum reps cannot exceed the maximum.', 'reps'));
    }
  }
  final rest = e.restSeconds;
  if (rest != null && (rest < 0 || rest > 3600)) {
    return Err(_err('Rest must be 0 to 3600 seconds.', 'restSeconds'));
  }
  Duration? duration;
  if (e.targetDuration != null) {
    final d = _positiveDuration(e.targetDuration!, 'targetDuration');
    if (d case Err(:final error)) return Err(error);
    duration = (d as Ok<Duration>).value;
  }
  double? metres;
  if (e.targetMetres != null) {
    final m = _positiveMetres(e.targetMetres!, 'targetMetres');
    if (m case Err(:final error)) return Err(error);
    metres = (m as Ok<double>).value;
  }
  if (type != null) {
    const repTypes = {
      ExerciseType.weighted,
      ExerciseType.bodyweight,
      ExerciseType.assisted,
    };
    if (min != null && !repTypes.contains(type)) {
      return Err(_err('A ${type.name} exercise has no rep target.', 'reps'));
    }
    if (duration != null && repTypes.contains(type)) {
      return Err(
        _err('A ${type.name} exercise has no duration target.', 'duration'),
      );
    }
    if (metres != null &&
        type != ExerciseType.distance &&
        type != ExerciseType.cardio) {
      return Err(
        _err('A ${type.name} exercise has no distance target.', 'metres'),
      );
    }
    if (e.targetLoad != null &&
        (type == ExerciseType.distance || type == ExerciseType.cardio)) {
      return Err(_err('A ${type.name} exercise has no load target.', 'load'));
    }
  }
  return Ok(e.copyWith(targetDuration: duration, targetMetres: metres));
}

/// Validates a split (TRN-014): a trimmed name of 1-[maxTrainingNameLength]
/// characters, a cycle of 1 to 14 days, no day with a blank plan reference
/// (a rest day is [SplitDay.planId] null, never blank), and at least one
/// workout day. Returns it with the name trimmed.
Result<TrainingSplit> validateSplit(TrainingSplit split) {
  final name = split.name.trim();
  if (name.isEmpty) return Err(_err('Enter a name.', 'name'));
  if (name.length > maxTrainingNameLength) {
    return Err(
      _err(
        'The name can be at most $maxTrainingNameLength characters.',
        'name',
      ),
    );
  }
  if (split.days.isEmpty || split.days.length > 14) {
    return Err(_err('A cycle has 1 to 14 days.', 'days'));
  }
  if (split.days.any((d) => d.planId != null && d.planId!.trim().isEmpty)) {
    return Err(_err('Every day needs a workout or rest.', 'days'));
  }
  if (split.days.every((d) => d.isRest)) {
    return Err(_err('Add at least one workout to the cycle.', 'days'));
  }
  return Ok(split.copyWith(name: name));
}

/// Moves the element at [from] so it ends at index [to] in the returned list
/// (move-up / move-down / drag, TRN-013(2)). Other elements keep their order.
/// Returns an error when an index is outside the list; [from] == [to] returns
/// an equal copy.
Result<List<T>> reorder<T>(List<T> list, int from, int to) {
  if (from < 0 || from >= list.length || to < 0 || to >= list.length) {
    return Err(_err('That position does not exist.', 'index'));
  }
  final out = [...list];
  out.insert(to, out.removeAt(from));
  return Ok(out);
}

/// [reorder] for plan exercises, renumbering `sortOrder` 0..n-1 in the new
/// order so the stored order matches.
Result<List<PlanExercise>> reorderPlanExercises(
  List<PlanExercise> exercises,
  int from,
  int to,
) => switch (reorder(exercises, from, to)) {
  Ok(:final value) => Ok([
    for (var i = 0; i < value.length; i++) value[i].copyWith(sortOrder: i),
  ]),
  Err(:final error) => Err(error),
};
