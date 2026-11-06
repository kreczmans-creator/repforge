import 'dart:convert';

import 'package:flutter/foundation.dart' show FlutterError;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/exercise_use_cases.dart';
import 'package:repforge/features/training/application/import_exercise_library.dart';

Map<String, Object?> _entry(
  String id,
  String name, {
  List<String> aliases = const [],
  String type = 'weighted',
  String category = 'push',
  String primary = 'chest',
  List<String> secondary = const [],
  List<String> equipment = const [],
}) => {
  'id': id,
  'name': name,
  'aliases': aliases,
  'type': type,
  'category': category,
  'primaryMuscle': primary,
  'secondaryMuscles': secondary,
  'equipment': equipment,
};

String _doc(List<Map<String, Object?>> exercises) =>
    jsonEncode({'formatVersion': 1, 'exercises': exercises});

final String _json = _doc([
  _entry(
    'lib-bench',
    'Bench Press',
    aliases: ['Flat bench', 'Développé couché'],
    secondary: ['triceps', 'frontDelts'],
    equipment: ['barbell', 'bench'],
  ),
  _entry('lib-plank', 'Plank', type: 'timed', category: 'core', primary: 'abs'),
  _entry(
    'lib-run',
    'Treadmill run',
    type: 'cardio',
    category: 'cardio',
    primary: 'fullBody',
    equipment: ['treadmill'],
  ),
]);

void main() {
  late AppDatabase db;
  late DriftExerciseRepository exercises;
  late DriftSettingsRepository settings;
  var loads = 0;
  final clock = FixedClock(DateTime.utc(2026, 11, 5, 9));

  ImportExerciseLibrary importer([String? json]) => ImportExerciseLibrary(
    exercises: exercises,
    settings: settings,
    clock: clock,
    loadJson: () async {
      loads++;
      return json ?? _json;
    },
  );

  Future<ExerciseLibraryImportSummary> run([String? json]) async =>
      (await importer(json)() as Ok<ExerciseLibraryImportSummary>).value;

  setUp(() {
    db = AppDatabase.inMemory();
    exercises = DriftExerciseRepository(db, clock: clock);
    settings = DriftSettingsRepository(db, clock: clock);
    loads = 0;
  });
  tearDown(() => db.close());

  test('imports every exercise as supplied with its classification', () async {
    final summary = await run();
    expect(
      [summary.imported, summary.alreadyPresent, summary.alreadyDone],
      [3, 0, false],
    );
    final bench = (await exercises.byId('lib-bench'))!;
    expect(bench.name, 'Bench Press');
    expect(bench.supplied, isTrue);
    expect(bench.isCustom, isFalse);
    expect(bench.copiedFromId, isNull);
    expect(bench.archived, isFalse);
    expect(bench.type, ExerciseType.weighted);
    expect(bench.category, ExerciseCategory.push);
    expect(bench.primaryMuscle, MuscleGroup.chest);
    expect(bench.secondaryMuscles, [
      MuscleGroup.triceps,
      MuscleGroup.frontDelts,
    ]);
    expect(bench.equipment, [Equipment.barbell, Equipment.bench]);
    expect(bench.aliases, ['Flat bench', 'Développé couché']);
    expect(bench.createdAt, clock.now());
    expect((await exercises.byId('lib-plank'))!.type, ExerciseType.timed);
    expect(await exercises.search(const ExerciseQuery()), hasLength(3));
    // Alias search works on the imported library (TRN-008(3)).
    expect(
      (await exercises.search(const ExerciseQuery(text: 'developpe')))
          .single
          .id,
      'lib-bench',
    );
  });

  test(
    'runs once: the version is recorded and a second run does nothing',
    () async {
      await run();
      expect(await settings.readSeedExercisesVersion(), 1);
      final again = await run();
      expect(again.alreadyDone, isTrue);
      expect(again.imported, 0);
      expect(loads, 1, reason: 'the file was not even read');
    },
  );

  test('is idempotent even if the version marker is lost', () async {
    await run();
    await settings.saveSeedExercisesVersion(0);
    final again = await run();
    expect([again.imported, again.alreadyPresent], [0, 3]);
    expect(await db.select(db.exercises).get(), hasLength(3));
  });

  test('a deleted supplied exercise is never re-created', () async {
    await run();
    await exercises.delete('lib-plank');
    await settings.saveSeedExercisesVersion(0);
    final r = await run();
    expect([r.imported, r.alreadyPresent], [0, 3]);
    expect(await exercises.byId('lib-plank'), isNull);
    expect(await exercises.exists('lib-plank'), isTrue);
  });

  test('an archived supplied exercise stays archived and is not '
      're-created', () async {
    await run();
    await ArchiveExercise(exercises: exercises)('lib-run');
    await settings.saveSeedExercisesVersion(0);
    await run();
    expect((await exercises.byId('lib-run'))!.archived, isTrue);
    expect(await db.select(db.exercises).get(), hasLength(3));
  });

  test('an existing exercise with the same id is not overwritten', () async {
    await exercises.upsert(
      Exercise(
        id: 'lib-plank',
        name: 'My plank',
        type: ExerciseType.timed,
        category: ExerciseCategory.core,
        primaryMuscle: MuscleGroup.abs,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    final r = await run();
    expect([r.imported, r.alreadyPresent], [2, 1]);
    expect((await exercises.byId('lib-plank'))!.name, 'My plank');
  });

  test(
    'a new bundled exercise appears after the version marker is bumped',
    () async {
      await run(_doc([_entry('a', 'A')]));
      await settings.saveSeedExercisesVersion(0);
      final r = await run(_doc([_entry('a', 'A'), _entry('b', 'B')]));
      expect([r.imported, r.alreadyPresent], [1, 1]);
    },
  );

  test('an unreadable or invalid file imports nothing and does not record '
      'the version', () async {
    final bad = <String>[
      'not json',
      '[]',
      jsonEncode({'formatVersion': 2, 'exercises': <Object?>[]}),
      jsonEncode({'formatVersion': 1}),
      jsonEncode({
        'formatVersion': 1,
        'exercises': [
          {'id': 'x'},
        ],
      }),
      _doc([_entry('a', 'A', type: 'teleport')]),
      _doc([_entry('a', 'A', category: 'Push')]),
      _doc([_entry('a', 'A', primary: 'bicep')]),
      _doc([
        _entry('a', 'A', secondary: ['wings']),
      ]),
      _doc([
        _entry('a', 'A', equipment: ['jetpack']),
      ]),
      // Fails exercise validation: primary repeated as secondary.
      _doc([
        _entry('a', 'A', secondary: ['chest']),
      ]),
      _doc([_entry('a', ' ')]),
      // Duplicate ids and empty ids.
      _doc([_entry('a', 'A'), _entry('a', 'B')]),
      _doc([_entry('', 'A')]),
      // One bad entry rejects the file, the good one included.
      _doc([_entry('ok', 'OK'), _entry('b', 'B', type: 'x')]),
    ];
    for (final json in bad) {
      final r = await importer(json)();
      expect((r as Err).error, isA<ValidationError>(), reason: json);
    }
    expect(await db.select(db.exercises).get(), isEmpty);
    expect(await settings.readSeedExercisesVersion(), 0);
  });

  test('a load failure is a StorageError and records nothing', () async {
    final r = await ImportExerciseLibrary(
      exercises: exercises,
      settings: settings,
      clock: clock,
      loadJson: () async => throw Exception('asset missing'),
    )();
    expect((r as Err).error, isA<StorageError>());
    expect(await settings.readSeedExercisesVersion(), 0);
  });

  test('a missing asset (FlutterError, an Error) is a typed failure and a '
      'later launch still imports', () async {
    final r = await ImportExerciseLibrary(
      exercises: exercises,
      settings: settings,
      clock: clock,
      loadJson: () async => throw FlutterError('Unable to load asset'),
    )();
    expect((r as Err).error, isA<StorageError>());
    expect(await db.select(db.exercises).get(), isEmpty);
    expect(await settings.readSeedExercisesVersion(), 0);
    expect((await run()).imported, 3);
  });

  test('a synchronous throw from the loader is also caught', () async {
    final r = await ImportExerciseLibrary(
      exercises: exercises,
      settings: settings,
      clock: clock,
      loadJson: () => throw StateError('boom'),
    )();
    expect(r.isErr, isTrue);
  });
}
