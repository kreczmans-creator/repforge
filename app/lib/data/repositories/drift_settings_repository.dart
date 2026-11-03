import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
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
