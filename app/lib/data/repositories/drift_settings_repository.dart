import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/delivery/owner_blocker.dart';
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
  static const _defaultRest = 'defaultRestSeconds';
  static const _restNotifications = 'restTimerNotifications';
  static const _mealLabels = 'mealLabels';
  static const _recipeFavouritesOnly = 'recipeFavouritesOnly';
  static const _availableEquipment = 'availableEquipment';
  static const _bodyweightOnly = 'equipmentBodyweightOnly';
  static const _seedRecipesVersion = 'seedRecipesVersion';
  static const _seedExercisesVersion = 'seedExercisesVersion';
  static const _blockerStates = 'ownerBlockerStates';

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
      _defaultRest: s.defaultRestSeconds.toString(),
      _restNotifications: s.restTimerNotifications.toString(),
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
  Stream<Set<Equipment>> watchAvailableEquipment() =>
      (_db.select(_db.settings)
            ..where((t) => t.key.equals(_availableEquipment)))
          .watchSingleOrNull()
          .map((row) => _equipmentFrom(row?.value))
          .distinct((a, b) => a.length == b.length && a.containsAll(b));

  @override
  Future<void> saveAvailableEquipment(Set<Equipment> equipment) => _writeValue(
    _availableEquipment,
    ([for (final e in equipment) e.name]..sort()).join(','),
  );

  @override
  Stream<bool> watchBodyweightOnly() =>
      (_db.select(_db.settings)..where((t) => t.key.equals(_bodyweightOnly)))
          .watchSingleOrNull()
          .map((row) => row?.value == 'true')
          .distinct();

  @override
  Future<void> saveBodyweightOnly({required bool value}) =>
      _writeValue(_bodyweightOnly, value.toString());

  /// Unknown names are dropped so a renamed item cannot break the filter.
  static Set<Equipment> _equipmentFrom(String? raw) {
    if (raw == null || raw.isEmpty) return const {};
    final byName = Equipment.values.asNameMap();
    return {for (final n in raw.split(',')) ?byName[n]};
  }

  @override
  Future<int> readSeedRecipesVersion() async =>
      int.tryParse(await _readValue(_seedRecipesVersion) ?? '') ?? 0;

  @override
  Future<void> saveSeedRecipesVersion(int version) =>
      _writeValue(_seedRecipesVersion, version.toString());

  @override
  Future<int> readSeedExercisesVersion() async =>
      int.tryParse(await _readValue(_seedExercisesVersion) ?? '') ?? 0;

  @override
  Future<void> saveSeedExercisesVersion(int version) =>
      _writeValue(_seedExercisesVersion, version.toString());

  @override
  Stream<Map<String, BlockerState>> watchBlockerStates() =>
      (_db.select(_db.settings)..where((t) => t.key.equals(_blockerStates)))
          .watchSingleOrNull()
          .map((row) => row?.value)
          .distinct()
          .map(BlockerStateCodec.decode);

  @override
  Future<Map<String, BlockerState>> readBlockerStates() async =>
      BlockerStateCodec.decode(await _readValue(_blockerStates));

  /// Read-modify-write of the raw JSON inside one transaction, so two quick
  /// changes to different blockers never lose each other and entries this
  /// build cannot read are kept as stored. The new state carries the
  /// earlier changes of the same blocker as its history. A stored value
  /// that is not a JSON object makes the save fail (see
  /// [BlockerStateCodec.merge]) instead of being overwritten.
  @override
  Future<void> saveBlockerState(String blockerId, BlockerState state) =>
      _db.transaction(() async {
        final raw = await _readValue(_blockerStates);
        final earlier = BlockerStateCodec.decode(raw)[blockerId];
        final merged = BlockerStateCodec.merge(
          raw,
          blockerId,
          BlockerState.after(earlier, state.current),
        );
        await _writeValue(_blockerStates, merged);
      });

  static AppSettings _fromRows(List<SettingRow> rows) {
    final map = {for (final r in rows) r.key: r.value};
    const defaults = AppSettings();
    final dayStart = int.tryParse(map[_dayStart] ?? '');
    final weekStart = int.tryParse(map[_weekStart] ?? '');
    final defaultRest = int.tryParse(map[_defaultRest] ?? '');
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
      defaultRestSeconds:
          (defaultRest != null && defaultRest >= 0 && defaultRest <= 3600)
          ? defaultRest
          : defaults.defaultRestSeconds,
      restTimerNotifications: map[_restNotifications] == 'true',
    );
  }
}
