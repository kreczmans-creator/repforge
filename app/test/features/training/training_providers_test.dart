import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/training_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late ProviderContainer container;
  var ids = 0;

  setUp(() {
    db = AppDatabase.inMemory();
    ids = 0;
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(
          FixedClock(DateTime.utc(2026, 11, 5, 9)),
        ),
        idGeneratorProvider.overrideWithValue(() => 'id${++ids}'),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('use cases are wired to the database', () async {
    final created = await container.read(saveCustomExerciseProvider)(
      name: 'Cable Fly',
      type: ExerciseType.weighted,
      category: ExerciseCategory.push,
      primaryMuscle: MuscleGroup.chest,
    );
    final id = (created as Ok<Exercise>).value.id;
    expect(
      (await container.read(copySuppliedExerciseProvider)(sourceId: id)).isErr,
      isTrue,
      reason: 'not supplied',
    );
    final plan = await container.read(savePlanProvider)(
      name: 'Push',
      planExercises: const [],
    );
    expect(plan.isOk, isTrue);
    final planId = (plan as Ok<WorkoutPlan>).value.id;
    expect(
      (await container.read(saveSplitProvider)(
        name: 'One',
        days: [planId, null],
      )).isOk,
      isTrue,
    );
    expect(
      (await container.read(recordSetProvider)(
        sessionId: 'none',
        exerciseId: id,
        data: SetData.weighted(load: LoadKg.fromStored(60), reps: 5),
      )).isErr,
      isTrue,
      reason: 'no such session',
    );
    expect((await container.read(archiveExerciseProvider)(id)).isOk, isTrue);
  });

  test('the library provider streams the filtered exercises', () async {
    await container.read(saveCustomExerciseProvider)(
      name: 'Cable Fly',
      type: ExerciseType.weighted,
      category: ExerciseCategory.push,
      primaryMuscle: MuscleGroup.chest,
    );
    final sub = container.listen(
      exerciseLibraryProvider(const ExerciseQuery(text: 'fly')),
      (_, _) {},
    );
    final list = await container.read(
      exerciseLibraryProvider(const ExerciseQuery(text: 'fly')).future,
    );
    expect(list.single.name, 'Cable Fly');
    sub.close();
    const none = ExerciseQuery(text: 'zzz');
    final sub2 = container.listen(exerciseLibraryProvider(none), (_, _) {});
    expect(await container.read(exerciseLibraryProvider(none).future), isEmpty);
    sub2.close();
  });

  test(
    'the bundled exercise library asset is registered and imports',
    () async {
      final file = File('assets/seed/exercise_library.json');
      final r = await container.read(importExerciseLibraryProvider).call();
      if (!file.existsSync()) {
        expect(r.isErr, isTrue, reason: 'a missing asset is a typed failure');
        return;
      }
      expect(r.isOk, isTrue);
      final all = await container
          .read(exerciseRepositoryProvider)
          .search(const ExerciseQuery());
      expect(all, isNotEmpty);
      expect(all.every((e) => e.supplied), isTrue);
    },
  );
}
