import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/db/drift_transactor.dart';
import 'package:repforge/data/db/open_database.dart';
import 'package:repforge/data/external/open_food_facts_client.dart';
import 'package:repforge/data/repositories/drift_backup_repository.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/data/repositories/drift_food_repository.dart';
import 'package:repforge/data/repositories/drift_goal_repository.dart';
import 'package:repforge/data/repositories/drift_meal_plan_repository.dart';
import 'package:repforge/data/repositories/drift_measurement_repository.dart';
import 'package:repforge/data/repositories/drift_prep_batch_repository.dart';
import 'package:repforge/data/repositories/drift_recipe_repository.dart';
import 'package:repforge/data/repositories/drift_saved_meal_repository.dart';
import 'package:repforge/data/repositories/drift_scheduled_workout_repository.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/data/repositories/drift_training_split_repository.dart';
import 'package:repforge/data/repositories/drift_weight_repository.dart';
import 'package:repforge/data/repositories/drift_workout_plan_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/backup/backup.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/ids.dart';
import 'package:repforge/domain/core/transactor.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurement_repository.dart';
import 'package:repforge/domain/measurements/weight_repository.dart';
import 'package:repforge/domain/nutrition/food_lookup_service.dart';
import 'package:repforge/domain/nutrition/food_repository.dart';
import 'package:repforge/domain/nutrition/saved_meal_repository.dart';
import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/planning/prep_batch.dart';
import 'package:repforge/domain/recipes/recipe_repository.dart';
import 'package:repforge/domain/scanning/barcode_scanner.dart';
import 'package:repforge/domain/settings/meal_labels.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/rest_alert_scheduler.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/features/measurements/application/delete_weight_entry.dart';
import 'package:repforge/features/measurements/application/record_body_weight.dart';
import 'package:repforge/features/settings/application/save_daily_targets.dart';
import 'package:repforge/features/settings/application/save_meal_labels.dart';
import 'package:repforge/features/settings/application/save_settings.dart';
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

/// Atomic multi-repository operations (see [Transactor]).
final transactorProvider = Provider<Transactor>(
  (ref) => DriftTransactor(ref.watch(databaseProvider)),
);

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

/// Live meal names and order (NUT-011); the defaults until the user renames
/// or reorders. Entries store the slot key, so a rename relabels existing
/// entries too.
final mealLabelsProvider = StreamProvider<MealLabels>(
  (ref) => ref.watch(settingsRepositoryProvider).watchMealLabels(),
);

final saveMealLabelsProvider = Provider<SaveMealLabels>(
  (ref) => SaveMealLabels(repository: ref.watch(settingsRepositoryProvider)),
);

final foodRepositoryProvider = Provider<FoodRepository>(
  (ref) => DriftFoodRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final foodLogRepositoryProvider = Provider<FoodLogRepository>(
  (ref) => DriftFoodLogRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final recipeRepositoryProvider = Provider<RecipeRepository>(
  (ref) => DriftRecipeRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final exerciseRepositoryProvider = Provider<ExerciseRepository>(
  (ref) => DriftExerciseRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final workoutPlanRepositoryProvider = Provider<WorkoutPlanRepository>(
  (ref) => DriftWorkoutPlanRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final trainingSplitRepositoryProvider = Provider<TrainingSplitRepository>(
  (ref) => DriftTrainingSplitRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final scheduledWorkoutRepositoryProvider = Provider<ScheduledWorkoutRepository>(
  (ref) => DriftScheduledWorkoutRepository(ref.watch(databaseProvider)),
);

final workoutSessionRepositoryProvider = Provider<WorkoutSessionRepository>(
  (ref) => DriftWorkoutSessionRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final saveDailyTargetsProvider = Provider<SaveDailyTargets>(
  (ref) => SaveDailyTargets(
    repository: ref.watch(goalRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final saveSettingsProvider = Provider<SaveSettings>(
  (ref) => SaveSettings(repository: ref.watch(settingsRepositoryProvider)),
);

final savedMealRepositoryProvider = Provider<SavedMealRepository>(
  (ref) => DriftSavedMealRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Shared HTTP client. Tests override [foodLookupServiceProvider] instead.
final dioProvider = Provider<Dio>((ref) {
  final dio = Dio();
  ref.onDispose(dio.close);
  return dio;
});

final foodLookupServiceProvider = Provider<FoodLookupService>(
  (ref) => OpenFoodFactsClient(
    dio: ref.watch(dioProvider),
    clock: ref.watch(clockProvider),
  ),
);

/// Camera and barcode scanning (PLT-001, PLT-002). The default throws: the
/// platform adapter is bound in `main.dart` by overriding this provider, and
/// tests override it with `FakeBarcodeScanner`.
final barcodeScannerProvider = Provider<BarcodeScanner>(
  (_) => throw UnimplementedError('bound in main.dart by the platform adapter'),
);

/// Whether this device can scan barcodes (PLT-003). Features hide the scan
/// action unless this resolves to [ScannerCapability.available].
final scannerCapabilityProvider = FutureProvider<ScannerCapability>(
  (ref) => ref.watch(barcodeScannerProvider).capability(),
);

/// Background notification scheduling (ADR-0007). The default schedules
/// nothing; `main.dart` binds the platform adapter on Android and iOS and
/// tests override it with `FakeRestAlertScheduler`.
final restAlertSchedulerProvider = Provider<RestAlertScheduler>(
  (_) => const NoopRestAlertScheduler(),
);

final mealPlanRepositoryProvider = Provider<MealPlanRepository>(
  (ref) => DriftMealPlanRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);

final prepBatchRepositoryProvider = Provider<PrepBatchRepository>(
  (ref) => DriftPrepBatchRepository(
    ref.watch(databaseProvider),
    clock: ref.watch(clockProvider),
  ),
);
