import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';

/// Equipment the user has available (TRN-011(2)); empty means the library is
/// not filtered by equipment. Stored in settings so it survives a restart.
final availableEquipmentProvider = StreamProvider<Set<Equipment>>(
  (ref) => ref.watch(settingsRepositoryProvider).watchAvailableEquipment(),
);

/// Use case: remember the user's available equipment.
final class SetAvailableEquipment {
  const SetAvailableEquipment(this._settings);
  final SettingsRepository _settings;

  Future<Result<void>> call(Set<Equipment> equipment) async {
    try {
      await _settings.saveAvailableEquipment(equipment);
    } on Exception catch (e) {
      return Err(StorageError('Could not save your equipment.', cause: e));
    }
    return const Ok(null);
  }
}

final setAvailableEquipmentProvider = Provider<SetAvailableEquipment>(
  (ref) => SetAvailableEquipment(ref.watch(settingsRepositoryProvider)),
);

/// One exercise by id, archived ones included (history stays reachable,
/// TRN-012(2)); null when it does not exist or was deleted.
// ignore: specify_nonobvious_property_types, the family type is not exported
final exerciseByIdProvider = StreamProvider.autoDispose
    .family<Exercise?, String>(
      (ref, id) => ref
          .watch(exerciseRepositoryProvider)
          .watchAll(includeArchived: true)
          .map((all) {
            for (final e in all) {
              if (e.id == id) return e;
            }
            return null;
          }),
    );

/// The most recent sessions that include an exercise, with their sets
/// (TRN-025).
// ignore: specify_nonobvious_property_types, the family type is not exported
final exerciseHistoryProvider = FutureProvider.autoDispose
    .family<List<ExerciseSessionHistory>, String>(
      (ref, id) => ref
          .watch(workoutSessionRepositoryProvider)
          .sessionsForExercise(id, limit: exerciseHistoryLimit),
    );

/// Sessions shown in an exercise's history.
const exerciseHistoryLimit = 20;

/// True when any set references the exercise; locks its type.
// ignore: specify_nonobvious_property_types, the family type is not exported
final exerciseHasHistoryProvider = FutureProvider.autoDispose
    .family<bool, String>(
      (ref, id) => ref.watch(workoutSessionRepositoryProvider).hasHistory(id),
    );
