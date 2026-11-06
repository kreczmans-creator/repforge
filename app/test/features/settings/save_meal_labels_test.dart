import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_food_log_repository.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/settings/meal_labels.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/settings/application/save_meal_labels.dart';

final _t = DateTime.utc(2026, 11, 4, 9);

FoodLogEntry _entry(String id, MealSlot meal) => FoodLogEntry(
  id: id,
  day: '2026-11-04',
  meal: meal,
  name: 'Apple',
  quantity: Quantity.fromStored(100, ReferenceUnit.grams),
  nutrients: const NutrientAmounts(kcal: 52),
  provenance: DataProvenance.verified,
  loggedAt: _t,
  createdAt: _t,
  updatedAt: _t,
);

const Map<MealSlot, String> _renamed = {
  MealSlot.breakfast: 'Breakfast',
  MealSlot.lunch: 'Lunch',
  MealSlot.dinner: 'Dinner',
  MealSlot.snack: 'Pre-workout',
};

void main() {
  late AppDatabase db;
  late DriftSettingsRepository settings;
  late DriftFoodLogRepository log;
  late SaveMealLabels save;
  final clock = FixedClock(_t);

  setUp(() {
    db = AppDatabase.inMemory();
    settings = DriftSettingsRepository(db, clock: clock);
    log = DriftFoodLogRepository(db, clock: clock);
    save = SaveMealLabels(repository: settings);
  });
  tearDown(() => db.close());

  test('NUT-011(1) a logged entry is shown under its chosen meal', () async {
    await log.insert(_entry('e1', MealSlot.snack));
    await log.insert(_entry('e2', MealSlot.breakfast));
    final labels = await settings.readMealLabels();
    final entries = await log.forDays('2026-11-04', '2026-11-04');
    final sections = {
      for (final slot in labels.order)
        labels.labelOf(slot): [
          for (final e in entries)
            if (e.meal == slot) e.id,
        ],
    };
    expect(sections.keys, ['Breakfast', 'Lunch', 'Dinner', 'Snacks']);
    expect(sections['Snacks'], ['e1']);
    expect(sections['Breakfast'], ['e2']);
  });

  test('NUT-011(2) renaming Snacks to Pre-workout relabels existing and new '
      'entries', () async {
    await log.insert(_entry('old', MealSlot.snack));

    final r = await save(labels: _renamed, order: MealSlot.values);
    expect(r, isA<Ok<MealLabels>>());

    await log.insert(_entry('new', MealSlot.snack));
    final labels = await settings.readMealLabels();
    final entries = await log.forDays('2026-11-04', '2026-11-04');
    expect(
      {for (final e in entries) e.id: labels.labelOf(e.meal)},
      {'old': 'Pre-workout', 'new': 'Pre-workout'},
    );
    // The stored entries still carry the slot key, not the label.
    expect(entries.map((e) => e.meal), everyElement(MealSlot.snack));
  });

  test('reordering is persisted', () async {
    final order = [
      MealSlot.snack,
      MealSlot.breakfast,
      MealSlot.lunch,
      MealSlot.dinner,
    ];
    await save(labels: _renamed, order: order);
    expect((await settings.readMealLabels()).order, order);
  });

  test('invalid input is a ValidationError and saves nothing', () async {
    final dup = {..._renamed, MealSlot.snack: 'lunch'};
    expect(
      ((await save(labels: dup, order: MealSlot.values)) as Err).error,
      isA<ValidationError>(),
    );
    expect(
      ((await save(labels: _renamed, order: [MealSlot.lunch])) as Err).error,
      isA<ValidationError>(),
    );
    expect(await settings.readMealLabels(), MealLabels.defaults);
  });

  test('mealLabelsProvider streams the saved labels', () async {
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        clockProvider.overrideWithValue(clock),
      ],
    );
    addTearDown(container.dispose);
    final seen = <MealLabels>[];
    container.listen(
      mealLabelsProvider,
      (_, next) => next.whenData(seen.add),
      fireImmediately: true,
    );
    await pumpEventQueue();
    await container.read(saveMealLabelsProvider)(
      labels: _renamed,
      order: MealSlot.values,
    );
    await pumpEventQueue();
    expect(seen.first, MealLabels.defaults);
    expect(seen.last.labelOf(MealSlot.snack), 'Pre-workout');
  });
}
