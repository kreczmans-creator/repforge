import 'dart:convert';

import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/training/training_validation.dart';

/// Result of [ImportExerciseLibrary].
final class ExerciseLibraryImportSummary {
  const ExerciseLibraryImportSummary({
    required this.imported,
    required this.alreadyPresent,
    required this.alreadyDone,
  });

  /// Exercises created by this run.
  final int imported;

  /// Exercises skipped because their id exists, archived or deleted included.
  final int alreadyPresent;

  /// True when an earlier run had already imported the bundled version.
  final bool alreadyDone;
}

/// Use case: import the bundled exercise library
/// `assets/seed/exercise_library.json` (TRN-008).
///
/// File format: `{"formatVersion": 1, "exercises": [{"id", "name",
/// "aliases": [...], "type", "category", "primaryMuscle",
/// "secondaryMuscles": [...], "equipment": [...]}]}` with identifiers from
/// `docs/training-taxonomy.md`. Every exercise is imported as supplied and
/// validated like a user exercise; one invalid entry rejects the whole file.
///
/// Runs once: on success the bundled version is recorded in settings
/// (`seedExercisesVersion`) and later calls do nothing. An exercise whose id
/// already exists, including one the user archived or deleted, is never
/// created again (and an existing one is never overwritten). The JSON text is
/// injected so tests need no asset. Whatever fails, including a missing
/// asset, returns a typed error and records nothing; a failure part-way
/// leaves the version unrecorded and the next run skips what was created.
final class ImportExerciseLibrary {
  const ImportExerciseLibrary({
    required this.exercises,
    required this.settings,
    required this.clock,
    required this.loadJson,
  });

  /// Version recorded in settings once this seed has been imported.
  static const seedVersion = 1;

  final ExerciseRepository exercises;
  final SettingsRepository settings;
  final Clock clock;

  /// Supplies the JSON text of the asset.
  final Future<String> Function() loadJson;

  Future<Result<ExerciseLibraryImportSummary>> call() async {
    try {
      if (await settings.readSeedExercisesVersion() >= seedVersion) {
        return const Ok(
          ExerciseLibraryImportSummary(
            imported: 0,
            alreadyPresent: 0,
            alreadyDone: true,
          ),
        );
      }
      final parsed = _parse(await loadJson(), clock.now().toUtc());
      if (parsed case Err(:final error)) return Err(error);
      var imported = 0;
      var present = 0;
      for (final exercise in (parsed as Ok<List<Exercise>>).value) {
        if (await exercises.exists(exercise.id)) {
          present++;
          continue;
        }
        await exercises.upsert(exercise);
        imported++;
      }
      await settings.saveSeedExercisesVersion(seedVersion);
      return Ok(
        ExerciseLibraryImportSummary(
          imported: imported,
          alreadyPresent: present,
          alreadyDone: false,
        ),
      );
    } on Object catch (e) {
      // Not only Exceptions: a missing asset makes rootBundle.loadString
      // throw a FlutterError (an Error).
      return Err(
        StorageError('Could not import the exercise library.', cause: e),
      );
    }
  }

  static Result<List<Exercise>> _parse(String json, DateTime now) {
    const bad = ValidationError('The exercise library file is not valid.');
    try {
      final root = jsonDecode(json);
      if (root is! Map<String, Object?> || root['formatVersion'] != 1) {
        return const Err(bad);
      }
      final list = root['exercises'];
      if (list is! List) return const Err(bad);
      T pick<T extends Enum>(Object? name, List<T> values) =>
          values.asNameMap()[name]!;
      List<T> picks<T extends Enum>(Object? names, List<T> values) => [
        for (final n in (names as List?) ?? const <Object?>[]) pick(n, values),
      ];
      final out = <Exercise>[];
      final ids = <String>{};
      for (final item in list) {
        final m = item! as Map<String, Object?>;
        final exercise = Exercise(
          id: m['id']! as String,
          name: m['name']! as String,
          aliases: [
            for (final a in (m['aliases'] as List?) ?? const <Object?>[])
              a! as String,
          ],
          type: pick(m['type'], ExerciseType.values),
          category: pick(m['category'], ExerciseCategory.values),
          primaryMuscle: pick(m['primaryMuscle'], MuscleGroup.values),
          secondaryMuscles: picks(m['secondaryMuscles'], MuscleGroup.values),
          equipment: picks(m['equipment'], Equipment.values),
          supplied: true,
          createdAt: now,
          updatedAt: now,
        );
        if (exercise.id.isEmpty || !ids.add(exercise.id)) {
          return const Err(bad);
        }
        switch (validateExercise(exercise)) {
          case Err():
            return const Err(bad);
          case Ok(:final value):
            out.add(value);
        }
      }
      return Ok(out);
    } on Object {
      // Any shape error in a bundled file: nothing is imported.
      return const Err(bad);
    }
  }
}
