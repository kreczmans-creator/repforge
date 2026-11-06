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
  Future<void> saveBlockerState(String blockerId, BlockerState state) async {
    if (fail) throw Exception('disk full');
    saved[blockerId] = state;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  final now = DateTime.parse('2026-11-06T10:00:00+02:00');
  UpdateBlockerStatus useCase(_FakeRepo repo) => UpdateBlockerStatus(
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
}
