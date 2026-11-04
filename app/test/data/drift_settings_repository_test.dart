import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/settings/meal_labels.dart';
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

    group('meal labels (NUT-011)', () {
      MealLabels labels(String snack, [List<MealSlot>? order]) =>
          (MealLabels.create(
            labels: {
              MealSlot.breakfast: 'Breakfast',
              MealSlot.lunch: 'Lunch',
              MealSlot.dinner: 'Dinner',
              MealSlot.snack: snack,
            },
            order: order ?? MealSlot.values,
          ) as Ok<MealLabels>).value;

      test('defaults before anything is saved', () async {
        expect(await repo.readMealLabels(), MealLabels.defaults);
        expect(await repo.watchMealLabels().first, MealLabels.defaults);
      });

      test('save then read and watch round-trip, order included', () async {
        final saved = labels('Pre-workout', [
          MealSlot.snack,
          MealSlot.breakfast,
          MealSlot.lunch,
          MealSlot.dinner,
        ]);
        final emitted = <MealLabels>[];
        final sub = repo.watchMealLabels().listen(emitted.add);
        await pumpEventQueue();
        await repo.saveMealLabels(saved);
        await pumpEventQueue();
        await sub.cancel();
        expect(await repo.readMealLabels(), saved);
        expect(emitted.first, MealLabels.defaults);
        expect(emitted.last, saved);
      });

      test('other settings changes do not re-emit the labels', () async {
        final emitted = <MealLabels>[];
        final sub = repo.watchMealLabels().listen(emitted.add);
        await pumpEventQueue();
        await repo.save(const AppSettings(dayStartHour: 4));
        await pumpEventQueue();
        await sub.cancel();
        expect(emitted, hasLength(1));
      });

      test('saving app settings keeps the labels', () async {
        final saved = labels('Pre-workout');
        await repo.saveMealLabels(saved);
        await repo.save(const AppSettings(dayStartHour: 4));
        expect(await repo.readMealLabels(), saved);
      });

      test('corrupt stored labels fall back to the defaults', () async {
        for (final raw in [
          'not json',
          '[]',
          '{"order":["breakfast"],"labels":{}}',
          '{"order":["breakfast","lunch","dinner","nope"],"labels":{}}',
        ]) {
          await putRaw('mealLabels', raw);
          expect(await repo.readMealLabels(), MealLabels.defaults, reason: raw);
        }
      });
    });

    test('seed recipes version defaults to 0 and persists', () async {
      expect(await repo.readSeedRecipesVersion(), 0);
      await repo.saveSeedRecipesVersion(1);
      expect(await repo.readSeedRecipesVersion(), 1);
      await putRaw('seedRecipesVersion', 'junk');
      expect(await repo.readSeedRecipesVersion(), 0);
    });
  });
}
