import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/delivery/owner_blocker.dart';

void main() {
  late AppDatabase db;
  late DriftSettingsRepository repo;
  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftSettingsRepository(db, clock: FixedClock(DateTime.utc(2026)));
  });
  tearDown(() => db.close());

  final a = BlockerState(
    status: BlockerStatus.resolved,
    updatedAt: DateTime.utc(2026, 11, 6, 8),
    note: 'ok',
  );
  final b = BlockerState(
    status: BlockerStatus.inProgress,
    updatedAt: DateTime.utc(2026, 11, 6, 9),
  );

  test('empty by default', () async {
    expect(await repo.readBlockerStates(), isEmpty);
  });

  test('round trips two ids and a second save keeps the first', () async {
    await repo.saveBlockerState('OB-1', a);
    await repo.saveBlockerState('OB-2', b);
    final states = await repo.readBlockerStates();
    expect(states, {'OB-1': a, 'OB-2': b});
    await repo.saveBlockerState('OB-1', b);
    expect((await repo.readBlockerStates())['OB-1'], b);
    expect((await repo.readBlockerStates())['OB-2'], b);
  });

  test('malformed JSON decodes to empty', () async {
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: 'ownerBlockerStates',
            value: '{not json',
            updatedAt: DateTime.utc(2026),
          ),
        );
    expect(await repo.readBlockerStates(), isEmpty);
  });

  test('watch emits on change', () async {
    final emissions = <Map<String, BlockerState>>[];
    final sub = repo.watchBlockerStates().listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await repo.saveBlockerState('OB-1', a);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(emissions.first, isEmpty);
    expect(emissions.last, {'OB-1': a});
  });
}
