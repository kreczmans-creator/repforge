import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/features/settings/application/save_settings.dart';

void main() {
  late AppDatabase db;
  late DriftSettingsRepository repo;
  late SaveSettings save;

  setUp(() {
    db = AppDatabase.inMemory();
    repo = DriftSettingsRepository(
      db,
      clock: FixedClock(DateTime.utc(2026, 11, 5)),
    );
    save = SaveSettings(repository: repo);
  });
  tearDown(() => db.close());

  Future<ValidationError> refused(AppSettings s) async {
    final r = await save(s);
    expect(r.isErr, isTrue);
    return (r as Err<AppSettings>).error as ValidationError;
  }

  test('rest timer settings are saved and read back', () async {
    const s = AppSettings(
      defaultRestSeconds: 120,
      restTimerNotifications: true,
    );
    expect((await save(s)).isOk, isTrue);
    expect(await repo.read(), s);
  });

  test('default rest accepts 0 and 3600 and refuses outside, storing '
      'nothing', () async {
    expect((await save(const AppSettings(defaultRestSeconds: 0))).isOk, isTrue);
    expect(
      (await save(const AppSettings(defaultRestSeconds: 3600))).isOk,
      isTrue,
    );
    for (final bad in [-1, 3601]) {
      final e = await refused(AppSettings(defaultRestSeconds: bad));
      expect(e.field, 'defaultRestSeconds');
    }
    expect((await repo.read()).defaultRestSeconds, 3600);
  });

  test('existing validation is unchanged', () async {
    expect(
      (await refused(const AppSettings(dayStartHour: 24))).field,
      'dayStartHour',
    );
    expect(
      (await refused(const AppSettings(weekStartDay: 8))).field,
      'weekStartDay',
    );
  });
}
