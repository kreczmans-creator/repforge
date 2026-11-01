import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_weight_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/weight_entry.dart';
import 'package:repforge/domain/measurements/weight_repository.dart';
import 'package:repforge/features/measurements/application/record_body_weight.dart';

final class _FailingRepository implements WeightRepository {
  @override
  Future<void> delete(String id) async {}

  @override
  Future<void> insert(WeightEntry entry) async => throw Exception('disk full');

  @override
  Future<WeightEntry?> latest() async => null;

  @override
  Stream<List<WeightEntry>> watchAll() => const Stream.empty();
}

void main() {
  final fixedNow = DateTime.utc(2026, 11, 1, 9, 30);
  late AppDatabase db;
  late DriftWeightRepository repo;
  late RecordBodyWeight useCase;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftWeightRepository(db);
    var counter = 0;
    useCase = RecordBodyWeight(
      repository: repo,
      clock: FixedClock(fixedNow),
      newId: () => 'id-${++counter}',
    );
  });

  tearDown(() => db.close());

  test('persists a valid weight with trimmed note and generated id', () async {
    final result = await useCase(weightText: '82.4', note: '  morning  ');

    expect(result, isA<Ok<WeightEntry>>());
    final entry = (result as Ok<WeightEntry>).value;
    expect(entry.id, 'id-1');
    expect(entry.weight.value, 82.4);
    expect(entry.note, 'morning');
    expect(entry.recordedAt, fixedNow);
    expect(entry.createdAt, fixedNow);

    final stored = await repo.latest();
    expect(stored, entry);
  });

  test('stores an empty note as null', () async {
    final result = await useCase(weightText: '80', note: '   ');
    expect((result as Ok<WeightEntry>).value.note, isNull);
  });

  test('rejects an invalid weight without touching the repository', () async {
    final result = await useCase(weightText: '12');
    expect(result, isA<Err<WeightEntry>>());
    expect((result as Err<WeightEntry>).error, isA<ValidationError>());
    expect(await repo.latest(), isNull);
  });

  test('rejects a recorded time more than a minute in the future', () async {
    final result = await useCase(
      weightText: '80',
      recordedAt: fixedNow.add(const Duration(minutes: 2)),
    );
    final err = (result as Err<WeightEntry>).error as ValidationError;
    expect(err.field, 'recordedAt');
  });

  test('tolerates a recorded time within one minute of now', () async {
    final result = await useCase(
      weightText: '80',
      recordedAt: fixedNow.add(const Duration(seconds: 30)),
    );
    expect(result, isA<Ok<WeightEntry>>());
  });

  test('maps a repository failure to StorageError', () async {
    final failing = RecordBodyWeight(
      repository: _FailingRepository(),
      clock: FixedClock(fixedNow),
      newId: () => 'x',
    );
    final result = await failing(weightText: '80');
    expect((result as Err<WeightEntry>).error, isA<StorageError>());
  });
}
