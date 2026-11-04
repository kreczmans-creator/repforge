import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/settings/meal_labels.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';

/// Key/value-backed [SettingsRepository]. Unknown or malformed values fall
/// back to the defaults in [AppSettings].
final class DriftSettingsRepository implements SettingsRepository {
  DriftSettingsRepository(this._db, {required this._clock});

  final AppDatabase _db;
  final Clock _clock;

  static const _units = 'units';
  static const _theme = 'theme';
  static const _exertion = 'exertionScale';
  static const _dayStart = 'dayStartHour';
  static const _weekStart = 'weekStartDay';
  static const _mealLabels = 'mealLabels';
  static const _recipeFavouritesOnly = 'recipeFavouritesOnly';
  static const _seedRecipesVersion = 'seedRecipesVersion';

  @override
  Stream<AppSettings> watch() =>
      _db.select(_db.settings).watch().map(_fromRows);

  @override
  Future<AppSettings> read() async =>
      _fromRows(await _db.select(_db.settings).get());

  @override
  Future<void> save(AppSettings s) async {
    final now = _clock.now().toUtc();
    final values = {
      _units: s.units.name,
      _theme: s.theme.name,
      _exertion: s.exertionScale.name,
      _dayStart: s.dayStartHour.toString(),
      _weekStart: s.weekStartDay.toString(),
    };
    await _db.transaction(() async {
      for (final e in values.entries) {
        await _db
            .into(_db.settings)
            .insertOnConflictUpdate(
              SettingsCompanion.insert(
                key: e.key,
                value: e.value,
                updatedAt: now,
              ),
            );
      }
    });
  }

  Future<String?> _readValue(String key) async {
    final row = await (_db.select(
      _db.settings,
    )..where((t) => t.key.equals(key))).getSingleOrNull();
    return row?.value;
  }

  Future<void> _writeValue(String key, String value) => _db
      .into(_db.settings)
      .insertOnConflictUpdate(
        SettingsCompanion.insert(
          key: key,
          value: value,
          updatedAt: _clock.now().toUtc(),
        ),
      );

  @override
  Stream<MealLabels> watchMealLabels() =>
      (_db.select(_db.settings)..where((t) => t.key.equals(_mealLabels)))
          .watchSingleOrNull()
          .map((row) => MealLabels.fromJson(row?.value))
          .distinct();

  @override
  Future<MealLabels> readMealLabels() async =>
      MealLabels.fromJson(await _readValue(_mealLabels));

  @override
  Future<void> saveMealLabels(MealLabels labels) =>
      _writeValue(_mealLabels, labels.toJson());

  @override
  Stream<bool> watchRecipeFavouritesOnly() =>
      (_db.select(_db.settings)
            ..where((t) => t.key.equals(_recipeFavouritesOnly)))
          .watchSingleOrNull()
          .map((row) => row?.value == 'true')
          .distinct();

  @override
  Future<void> saveRecipeFavouritesOnly({required bool value}) =>
      _writeValue(_recipeFavouritesOnly, value.toString());

  @override
  Future<int> readSeedRecipesVersion() async =>
      int.tryParse(await _readValue(_seedRecipesVersion) ?? '') ?? 0;

  @override
  Future<void> saveSeedRecipesVersion(int version) =>
      _writeValue(_seedRecipesVersion, version.toString());

  static AppSettings _fromRows(List<SettingRow> rows) {
    final map = {for (final r in rows) r.key: r.value};
    const defaults = AppSettings();
    final dayStart = int.tryParse(map[_dayStart] ?? '');
    final weekStart = int.tryParse(map[_weekStart] ?? '');
    return AppSettings(
      units: UnitSystem.values.asNameMap()[map[_units]] ?? defaults.units,
      theme: ThemePreference.values.asNameMap()[map[_theme]] ?? defaults.theme,
      exertionScale:
          ExertionScale.values.asNameMap()[map[_exertion]] ??
          defaults.exertionScale,
      dayStartHour: (dayStart != null && dayStart >= 0 && dayStart <= 23)
          ? dayStart
          : defaults.dayStartHour,
      weekStartDay: (weekStart != null && weekStart >= 1 && weekStart <= 7)
          ? weekStart
          : defaults.weekStartDay,
    );
  }
}
