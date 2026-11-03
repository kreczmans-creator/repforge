import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';

final _clock = FixedClock(DateTime.utc(2026, 11, 3, 12));

void main() {
  group('DriftSettingsRepository (in-memory)', () {
    late AppDatabase db;
    late DriftSettingsRepository repo;

    setUp(() {
      db = AppDatabase.inMemory();
      repo = DriftSettingsRepository(db, clock: _clock);
    });
    tearDown(() => db.close());

    Future<void> putRaw(String key, String value) => db
        .into(db.settings)
        .insertOnConflictUpdate(
          SettingsCompanion.insert(
            key: key,
            value: value,
            updatedAt: _clock.now(),
          ),
        );

    test('read returns defaults on an empty table', () async {
      expect(await repo.read(), const AppSettings());
    });

    test('save then read round-trips every field', () async {
      const s = AppSettings(
        units: UnitSystem.imperial,
        theme: ThemePreference.system,
        exertionScale: ExertionScale.rir,
        dayStartHour: 4,
        weekStartDay: 7,
      );
      await repo.save(s);
      expect(await repo.read(), s);
      expect(await db.select(db.settings).get(), hasLength(5));
    });

    test('every enum value round-trips', () async {
      for (final u in UnitSystem.values) {
        for (final t in ThemePreference.values) {
          for (final e in ExertionScale.values) {
            final s = AppSettings(units: u, theme: t, exertionScale: e);
            await repo.save(s);
            expect(await repo.read(), s);
          }
        }
      }
    });

    test('boundary hours and weekdays are accepted', () async {
      for (final (h, d) in [(0, 1), (23, 7)]) {
        final s = AppSettings(dayStartHour: h, weekStartDay: d);
        await repo.save(s);
        expect(await repo.read(), s);
      }
    });

    test('save overwrites previous values', () async {
      await repo.save(
        const AppSettings(
          units: UnitSystem.imperial,
          theme: ThemePreference.light,
          dayStartHour: 5,
        ),
      );
      await repo.save(const AppSettings(dayStartHour: 2, weekStartDay: 3));
      final s = await repo.read();
      expect(s.units, UnitSystem.metric);
      expect(s.theme, ThemePreference.dark);
      expect(s.dayStartHour, 2);
      expect(s.weekStartDay, 3);
      expect(await db.select(db.settings).get(), hasLength(5));
    });

    test('save stamps updatedAt from the clock', () async {
      await repo.save(const AppSettings());
      final rows = await db.select(db.settings).get();
      for (final r in rows) {
        expect(r.updatedAt.isAtSameMomentAs(_clock.now()), isTrue);
      }
    });

    test('watch emits the current value and then on save', () async {
      final emitted = <AppSettings>[];
      final sub = repo.watch().listen(emitted.add);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      expect(emitted.last, const AppSettings());

      const s = AppSettings(theme: ThemePreference.light, dayStartHour: 6);
      await repo.save(s);
      await pumpEventQueue();
      expect(emitted.last, s);
    });

    test('malformed stored values fall back to defaults', () async {
      await putRaw('dayStartHour', '99');
      await putRaw('theme', 'purple');
      await putRaw('units', 'cubits');
      await putRaw('exertionScale', '');
      await putRaw('weekStartDay', 'monday');
      expect(await repo.read(), const AppSettings());
    });

    test('out-of-range numbers fall back individually', () async {
      await putRaw('dayStartHour', '-1');
      await putRaw('weekStartDay', '0');
      await putRaw('theme', 'light');
      final s = await repo.read();
      expect(s.dayStartHour, 0);
      expect(s.weekStartDay, 1);
      expect(s.theme, ThemePreference.light);

      await putRaw('dayStartHour', '24');
      await putRaw('weekStartDay', '8');
      final t = await repo.read();
      expect(t.dayStartHour, 0);
      expect(t.weekStartDay, 1);
    });
  });
}
