import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:repforge/domain/settings/meal_labels.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';

part 'settings.freezed.dart';

/// App theme preference.
enum ThemePreference { dark, light, system }

/// Persisted user settings (replaces the prototype's in-memory targets).
@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    @Default(UnitSystem.metric) UnitSystem units,
    @Default(ThemePreference.dark) ThemePreference theme,
    @Default(ExertionScale.rpe) ExertionScale exertionScale,

    /// Hour (0–23) at which a new diary day starts; 0 = local midnight.
    @Default(0) int dayStartHour,

    /// 1 = Monday … 7 = Sunday.
    @Default(1) int weekStartDay,
  }) = _AppSettings;
}

abstract interface class SettingsRepository {
  Stream<AppSettings> watch();
  Future<AppSettings> read();
  Future<void> save(AppSettings settings);

  /// Live meal names and order (NUT-011); [MealLabels.defaults] until saved.
  Stream<MealLabels> watchMealLabels();
  Future<MealLabels> readMealLabels();
  Future<void> saveMealLabels(MealLabels labels);

  /// Whether the recipe list shows favourites only (RCP-011); persists
  /// across restarts. False until set.
  Stream<bool> watchRecipeFavouritesOnly();
  Future<void> saveRecipeFavouritesOnly({required bool value});

  /// Equipment the user has available (TRN-011(2)); persists across
  /// restarts. Empty until set, which means "do not filter".
  Stream<Set<Equipment>> watchAvailableEquipment();
  Future<void> saveAvailableEquipment(Set<Equipment> equipment);

  /// Whether the library shows bodyweight-only exercises (TRN-011(1)): a
  /// distinct choice from "no equipment filter". False until set.
  Stream<bool> watchBodyweightOnly();
  Future<void> saveBodyweightOnly({required bool value});

  /// Version of the bundled seed recipes already imported (0 = none yet).
  Future<int> readSeedRecipesVersion();
  Future<void> saveSeedRecipesVersion(int version);

  /// Version of the bundled exercise library already imported (0 = none).
  Future<int> readSeedExercisesVersion();
  Future<void> saveSeedExercisesVersion(int version);
}
