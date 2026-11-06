import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/delivery/owner_blocker.dart';
import 'package:repforge/features/delivery/application/blocker_providers.dart';

import 'blocker_fixtures.dart';

void main() {
  late AppDatabase db;
  late ProviderContainer container;
  setUp(() {
    db = AppDatabase.inMemory();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(FixedClock(DateTime.utc(2026, 11, 6))),
        ownerBlockerRegisterProvider.overrideWithValue(testRegister),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await Future<void>.delayed(Duration.zero);
    await db.close();
  });

  Future<List<BlockerView>> views() async {
    container.listen(blockerViewsProvider, (_, _) {});
    await container.read(blockerStatesProvider.future);
    return container.read(blockerViewsProvider).requireValue;
  }

  test('views are sorted by priority, open first, then id', () async {
    final ids = (await views()).map((v) => v.blocker.id).toList();
    // high: A (open), C (open); medium: D; low: E (open) before B (resolved).
    expect(ids, ['OB-A', 'OB-C', 'OB-D', 'OB-E', 'OB-B']);
  });

  test('a saved state overrides the register status', () async {
    await views();
    final result = await container.read(updateBlockerStatusProvider)(
      blockerId: 'OB-A',
      status: BlockerStatus.resolved,
      note: 'done',
    );
    expect(result.isOk, isTrue);
    // The stream emits asynchronously; wait for the change.
    await Future<void>.delayed(const Duration(milliseconds: 50));
    final list = container.read(blockerViewsProvider).requireValue;
    final a = list.firstWhere((v) => v.blocker.id == 'OB-A');
    expect(a.status, BlockerStatus.resolved);
    expect(a.state?.note, 'done');
    // Resolved high-priority now sorts after the open high one.
    expect(list.map((v) => v.blocker.id).take(2), ['OB-C', 'OB-A']);
  });
}
