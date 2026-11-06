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

  test('round trips two ids; a later save of one id keeps the other and '
      'turns the earlier state into history', () async {
    await repo.saveBlockerState('OB-1', a);
    await repo.saveBlockerState('OB-2', b);
    final states = await repo.readBlockerStates();
    expect(states, {'OB-1': a, 'OB-2': b});
    await repo.saveBlockerState('OB-1', b);
    final after = await repo.readBlockerStates();
    expect(after['OB-1'], BlockerState.after(a, b.current));
    expect(after['OB-1']!.history, [a.current]);
    expect(after['OB-2'], b);
  });

  test('a save keeps entries this build cannot read, byte for byte', () async {
    const foreign =
        '{"OB-9":{"status":"deferred","updatedAt":"2026-11-07T06:00:00.000Z"},'
        '"OB-1":{"status":"open","updatedAt":"2026-11-06T06:00:00.000Z"}}';
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: 'ownerBlockerStates',
            value: foreign,
            updatedAt: DateTime.utc(2026),
          ),
        );
    await repo.saveBlockerState('OB-2', b);
    final row = await (db.select(
      db.settings,
    )..where((t) => t.key.equals('ownerBlockerStates'))).getSingle();
    expect(row.value, contains('"OB-9":{"status":"deferred"'));
    final states = await repo.readBlockerStates();
    expect(states.keys, containsAll(['OB-1', 'OB-2']));
    expect(states.containsKey('OB-9'), isFalse, reason: 'unreadable, kept');
  });

  test('a stored value that is not a JSON object makes the save fail '
      'instead of being overwritten', () async {
    await db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: 'ownerBlockerStates',
            value: '[1,2,3]',
            updatedAt: DateTime.utc(2026),
          ),
        );
    await expectLater(
      repo.saveBlockerState('OB-1', a),
      throwsA(isA<FormatException>()),
    );
    final row = await (db.select(
      db.settings,
    )..where((t) => t.key.equals('ownerBlockerStates'))).getSingle();
    expect(row.value, '[1,2,3]');
  });

  test('the watch does not re-emit for an unrelated settings write', () async {
    final emissions = <Map<String, BlockerState>>[];
    final sub = repo.watchBlockerStates().listen(emissions.add);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await repo.saveRecipeFavouritesOnly(value: true);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await sub.cancel();
    expect(emissions, hasLength(1));
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
