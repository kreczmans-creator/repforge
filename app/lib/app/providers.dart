import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/db/open_database.dart';
import 'package:repforge/data/repositories/drift_backup_repository.dart';
import 'package:repforge/data/repositories/drift_goal_repository.dart';
import 'package:repforge/data/repositories/drift_measurement_repository.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/data/repositories/drift_weight_repository.dart';
import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurement_repository.dart';
import 'package:repforge/domain/measurements/weight_repository.dart';
import 'package:repforge/domain/settings/settings.dart';
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
  (ref) => DriftWeightRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
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

final measurementRepositoryProvider = Provider<MeasurementRepository>(
  (ref) => DriftMeasurementRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final goalRepositoryProvider = Provider<GoalRepository>(
  (ref) => DriftGoalRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => DriftSettingsRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final backupRepositoryProvider = Provider<BackupRepository>(
  (ref) => DriftBackupRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Live settings; defaults until the first save.
final settingsProvider = StreamProvider<AppSettings>(
  (ref) => ref.watch(settingsRepositoryProvider).watch(),
);
