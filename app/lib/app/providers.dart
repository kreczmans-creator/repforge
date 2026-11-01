import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/db/open_database.dart';
import 'package:repforge/data/repositories/drift_weight_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/measurements/weight_repository.dart';
import 'package:repforge/features/measurements/application/delete_weight_entry.dart';
import 'package:repforge/features/measurements/application/record_body_weight.dart';
import 'package:uuid/uuid.dart';

/// Composition root. Tests override [databaseProvider] (and [clockProvider],
/// [idGeneratorProvider] when determinism matters) via `ProviderScope`.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase(openAppDatabase());
  ref.onDispose(db.close);
  return db;
});

final clockProvider = Provider<Clock>((_) => const SystemClock());

final idGeneratorProvider = Provider<IdGenerator>((_) {
  const uuid = Uuid();
  return uuid.v4;
});

final weightRepositoryProvider = Provider<WeightRepository>(
  (ref) => DriftWeightRepository(ref.watch(databaseProvider)),
);

final recordBodyWeightProvider = Provider<RecordBodyWeight>(
  (ref) => RecordBodyWeight(
    repository: ref.watch(weightRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final deleteWeightEntryProvider = Provider<DeleteWeightEntry>(
  (ref) => DeleteWeightEntry(repository: ref.watch(weightRepositoryProvider)),
);
