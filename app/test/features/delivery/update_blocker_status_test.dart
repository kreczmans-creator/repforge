import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/delivery/owner_blocker.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/features/delivery/application/update_blocker_status.dart';

import 'blocker_fixtures.dart';

class _FakeRepo implements SettingsRepository {
  _FakeRepo({this.fail = false});

  final bool fail;
  final saved = <String, BlockerState>{};

  @override
  Future<Map<String, BlockerState>> readBlockerStates() async {
    if (fail) throw Exception('disk full');
    return Map.of(saved);
  }

  @override
  Future<void> saveBlockerState(String blockerId, BlockerState state) async {
    if (fail) throw Exception('disk full');
    saved[blockerId] = state;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.parse('2026-11-06T10:00:00+02:00');
  UpdateBlockerStatus useCase(SettingsRepository repo) => UpdateBlockerStatus(
    repository: repo,
    clock: FixedClock(now),
    register: testRegister,
  );

  test('saves status with a trimmed note and a UTC timestamp', () async {
    final repo = _FakeRepo();
    final result = await useCase(repo)(
      blockerId: 'OB-A',
      status: BlockerStatus.resolved,
      note: '  approved  ',
    );
    final state = (result as Ok<BlockerState>).value;
    expect(state.status, BlockerStatus.resolved);
    expect(state.note, 'approved');
    expect(state.updatedAt, DateTime.utc(2026, 11, 6, 8));
    expect(state.updatedAt.isUtc, isTrue);
    expect(repo.saved['OB-A'], state);
  });

  test('an empty or blank note becomes null', () async {
    final repo = _FakeRepo();
    final result = await useCase(repo)(
      blockerId: 'OB-A',
      status: BlockerStatus.open,
      note: '   ',
    );
    expect((result as Ok<BlockerState>).value.note, isNull);
  });

  test('rejects an id that is not in the register', () async {
    final repo = _FakeRepo();
    final result = await useCase(repo)(
      blockerId: 'OB-NOPE',
      status: BlockerStatus.open,
    );
    expect(result, isA<Err<BlockerState>>());
    expect((result as Err<BlockerState>).error, isA<ValidationError>());
    expect(repo.saved, isEmpty);
  });

  test('rejects a note over 500 characters, accepts exactly 500', () async {
    final repo = _FakeRepo();
    final long = await useCase(repo)(
      blockerId: 'OB-A',
      status: BlockerStatus.open,
      note: 'x' * 501,
    );
    final error = (long as Err<BlockerState>).error as ValidationError;
    expect(error.field, 'note');
    expect(repo.saved, isEmpty);
    final ok = await useCase(repo)(
      blockerId: 'OB-A',
      status: BlockerStatus.open,
      note: 'x' * 500,
    );
    expect(ok.isOk, isTrue);
  });

  test('a storage failure becomes a StorageError', () async {
    final result = await useCase(_FakeRepo(fail: true))(
      blockerId: 'OB-A',
      status: BlockerStatus.open,
    );
    expect((result as Err<BlockerState>).error, isA<StorageError>());
  });

  test('a second change keeps the first as history, oldest first', () async {
    final repo = _FakeRepo();
    final uc = useCase(repo);
    await uc(blockerId: 'OB-A', status: BlockerStatus.inProgress);
    final result = await uc(
      blockerId: 'OB-A',
      status: BlockerStatus.awaitingOwner,
      note: 'sent to the owner',
    );
    final state = (result as Ok<BlockerState>).value;
    expect(state.status, BlockerStatus.awaitingOwner);
    expect(state.history, hasLength(1));
    expect(state.history.single.status, BlockerStatus.inProgress);
    expect(state.allChanges.last.note, 'sent to the owner');
    expect(repo.saved['OB-A'], state);
  });

  test('resolving an owner decision, scope approval or acceptance needs a '
      'note; a device action does not', () async {
    final repo = _FakeRepo();
    final uc = useCase(repo);
    for (final id in ['OB-A', 'OB-C', 'OB-E']) {
      final blocker = testRegister.firstWhere((b) => b.id == id);
      final r = await uc(blockerId: id, status: BlockerStatus.resolved);
      if (UpdateBlockerStatus.needsResolutionNote(blocker)) {
        expect(r, isA<Err<BlockerState>>(), reason: id);
        expect(
          ((r as Err<BlockerState>).error as ValidationError).field,
          'note',
        );
      } else {
        expect(r, isA<Ok<BlockerState>>(), reason: id);
      }
    }
    final withNote = await uc(
      blockerId: 'OB-A',
      status: BlockerStatus.resolved,
      note: 'Option (b) chosen.',
    );
    expect(withNote, isA<Ok<BlockerState>>());
  });

  test('a non-Exception error from storage is still a StorageError', () async {
    final repo = _ThrowingRepo();
    final r = await useCase(repo)(
      blockerId: 'OB-A',
      status: BlockerStatus.open,
    );
    expect((r as Err<BlockerState>).error, isA<StorageError>());
  });
}

class _ThrowingRepo implements SettingsRepository {
  @override
  // What foreign stored data can raise.
  dynamic noSuchMethod(Invocation invocation) => throw TypeError();
}
