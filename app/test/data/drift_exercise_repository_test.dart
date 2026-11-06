import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/training/training.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 3, 12));
final _t = DateTime.utc(2026, 11, 1, 8);

Exercise _exercise(String id, {String name = 'Bench Press'}) => Exercise(
  id: id,
  name: name,
  type: ExerciseType.weighted,
  category: ExerciseCategory.push,
  primaryMuscle: MuscleGroup.chest,
  secondaryMuscles: const [MuscleGroup.triceps, MuscleGroup.frontDelts],
  equipment: const [Equipment.barbell, Equipment.bench],
  aliases: const ['Flat bench'],
  createdAt: _t,
  updatedAt: _t,
);

void main() {
  late AppDatabase db;
  late DriftExerciseRepository repo;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftExerciseRepository(db, clock: _clock);
  });
  tearDown(() => db.close());

  test('round-trips an exercise including lists', () async {
    final e = _exercise('a');
    await repo.upsert(e);
    expect(await repo.byId('a'), e);
    expect((await repo.watchAll().first).single, e);
  });

  test('round-trips every exercise type and empty lists', () async {
    for (final type in ExerciseType.values) {
      final e = Exercise(
        id: type.name,
        name: type.name,
        type: type,
        category: ExerciseCategory.core,
        primaryMuscle: MuscleGroup.abs,
        createdAt: _t,
        updatedAt: _t,
      );
      await repo.upsert(e);
      expect(await repo.byId(type.name), e);
    }
  });

  test('upsert replaces an existing exercise', () async {
    await repo.upsert(_exercise('a'));
    final changed = _exercise('a', name: 'Incline Press');
    await repo.upsert(changed);
    final all = await repo.watchAll().first;
    expect(all, [changed]);
  });

  test('archive hides and unhides', () async {
    await repo.upsert(_exercise('a'));
    await repo.archive('a', archived: true);
    expect(await repo.watchAll().first, isEmpty);
    final withArchived = await repo.watchAll(includeArchived: true).first;
    expect(withArchived.single.archived, isTrue);
    expect(withArchived.single.updatedAt, _clock.now());

    await repo.archive('a', archived: false);
    expect((await repo.watchAll().first).single.archived, isFalse);
  });

  test('byId returns null for a missing or soft-deleted exercise', () async {
    expect(await repo.byId('nope'), isNull);
    await repo.upsert(_exercise('a'));
    await (db.update(db.exercises)..where((t) => t.id.equals('a'))).write(
      ExercisesCompanion(deletedAt: Value(_t)),
    );
    expect(await repo.byId('a'), isNull);
    expect(await repo.watchAll(includeArchived: true).first, isEmpty);
  });

  test('skips a row with an unknown type', () async {
    await repo.upsert(_exercise('ok'));
    await db
        .into(db.exercises)
        .insert(
          ExercisesCompanion.insert(
            id: 'bad',
            name: 'Mystery',
            type: 'teleport',
            category: 'c',
            primaryMuscle: 'm',
            secondaryMusclesJson: '[]',
            equipmentJson: '[]',
            createdAt: _t,
            updatedAt: _t,
          ),
        );
    expect((await repo.watchAll().first).map((e) => e.id), ['ok']);
    expect(await repo.byId('bad'), isNull);
  });
}
