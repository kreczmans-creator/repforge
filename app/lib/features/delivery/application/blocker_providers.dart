import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/delivery/owner_blocker.dart';
import 'package:repforge/domain/delivery/owner_blocker_register.dart';
import 'package:repforge/features/delivery/application/update_blocker_status.dart';

/// The canonical register. Tests override it with a small fixture.
final ownerBlockerRegisterProvider = Provider<List<OwnerBlocker>>(
  (_) => ownerBlockerRegister,
);

/// Live owner-recorded status changes, keyed by blocker id.
final blockerStatesProvider = StreamProvider<Map<String, BlockerState>>(
  (ref) => ref.watch(settingsRepositoryProvider).watchBlockerStates(),
);

/// Register entries with their effective state, most urgent first.
final blockerViewsProvider = Provider<AsyncValue<List<BlockerView>>>((ref) {
  final register = ref.watch(ownerBlockerRegisterProvider);
  return ref
      .watch(blockerStatesProvider)
      .whenData(
        (states) => [
          for (final b in register)
            BlockerView(blocker: b, state: states[b.id]),
        ]..sort(compareBlockerViews),
      );
});

final updateBlockerStatusProvider = Provider<UpdateBlockerStatus>(
  (ref) => UpdateBlockerStatus(
    repository: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
    register: ref.watch(ownerBlockerRegisterProvider),
  ),
);
