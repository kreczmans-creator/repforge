import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/exercise_use_cases.dart';
import 'package:repforge/features/training/application/import_exercise_library.dart';
import 'package:repforge/features/training/application/plan_use_cases.dart';
import 'package:repforge/features/training/application/record_set.dart';

/// Asset holding the bundled exercise library (WP 8, OQ-09).
const exerciseLibraryAsset = 'assets/seed/exercise_library.json';

/// The library filtered and ordered by a query (TRN-008..012).
// ignore: specify_nonobvious_property_types, the family type is not exported
final exerciseLibraryProvider = StreamProvider.autoDispose
    .family<List<Exercise>, ExerciseQuery>(
      (ref, query) => ref.watch(exerciseRepositoryProvider).watchLibrary(query),
    );

final saveCustomExerciseProvider = Provider<SaveCustomExercise>(
  (ref) => SaveCustomExercise(
    exercises: ref.watch(exerciseRepositoryProvider),
    sessions: ref.watch(workoutSessionRepositoryProvider),
    plans: ref.watch(workoutPlanRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final copySuppliedExerciseProvider = Provider<CopySuppliedExercise>(
  (ref) => CopySuppliedExercise(
    exercises: ref.watch(exerciseRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final archiveExerciseProvider = Provider<ArchiveExercise>(
  (ref) => ArchiveExercise(exercises: ref.watch(exerciseRepositoryProvider)),
);

final recordSetProvider = Provider<RecordSet>(
  (ref) => RecordSet(
    exercises: ref.watch(exerciseRepositoryProvider),
    sessions: ref.watch(workoutSessionRepositoryProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final savePlanProvider = Provider<SavePlan>(
  (ref) => SavePlan(
    plans: ref.watch(workoutPlanRepositoryProvider),
    exercises: ref.watch(exerciseRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

final saveSplitProvider = Provider<SaveSplit>(
  (ref) => SaveSplit(
    splits: ref.watch(trainingSplitRepositoryProvider),
    plans: ref.watch(workoutPlanRepositoryProvider),
    clock: ref.watch(clockProvider),
    newId: ref.watch(idGeneratorProvider),
  ),
);

/// The one-time library import. Run from the app bootstrap (`main.dart`),
/// never from a widget.
final importExerciseLibraryProvider = Provider<ImportExerciseLibrary>(
  (ref) => ImportExerciseLibrary(
    exercises: ref.watch(exerciseRepositoryProvider),
    settings: ref.watch(settingsRepositoryProvider),
    clock: ref.watch(clockProvider),
    loadJson: () => rootBundle.loadString(exerciseLibraryAsset),
  ),
);
