import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/summaries.dart';
import 'package:repforge/domain/units/units.dart';

FoodLogEntry _e(String day, double kcal, {double? proteinG = 1}) =>
    FoodLogEntry(
      id: '$day-$kcal',
      day: day,
      meal: MealSlot.lunch,
      name: 'x',
      quantity: Quantity.fromStored(100, ReferenceUnit.grams),
      nutrients: NutrientAmounts(
        kcal: kcal,
        proteinG: proteinG,
        carbsG: 1,
        fatG: 1,
      ),
      provenance: DataProvenance.userEntered,
      loggedAt: DateTime.utc(2026),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  test('lastSevenDays ends on the given day, oldest first', () {
    final days = lastSevenDays(DateTime(2026, 11, 3));
    expect(days.first, '2026-10-28');
    expect(days.last, '2026-11-03');
    expect(days.length, 7);
  });

  test('averages over logged days only', () {
    final w = WeeklySummary.fromEntries(
      days: lastSevenDays(DateTime(2026, 11, 3)),
      entries: [
        _e('2026-11-01', 2000),
        _e('2026-11-01', 400),
        _e('2026-11-03', 1800),
      ],
    );
    expect(w.loggedDays, 2);
    expect(w.averagePerLoggedDay!.kcal, 2100);
    expect(w.total.kcal, 4200);
    expect(w.perDay['2026-11-02'], isNull);
  });

  test('empty week has no average', () {
    final w = WeeklySummary.fromEntries(
      days: lastSevenDays(DateTime(2026, 11, 3)),
      entries: const [],
    );
    expect(w.averagePerLoggedDay, isNull);
    expect(w.total, NutrientAmounts.zero);
  });

  test('average leaves out days that do not know a nutrient', () {
    final w = WeeklySummary.fromEntries(
      days: lastSevenDays(DateTime(2026, 11, 3)),
      entries: [
        _e('2026-11-01', 1000, proteinG: null),
        _e('2026-11-03', 2000, proteinG: 90),
      ],
    );
    final avg = w.averagePerLoggedDay!;
    expect(avg.kcal, 1500); // energy is always known: over 2 days
    expect(avg.proteinG, 90); // only the day that knows protein
    expect(avg.carbsG, 1); // known on both days
    expect(avg.fibreG, isNull); // no day knows fibre
    expect(w.unknownDays(Nutrient.proteinG), 1);
    expect(w.unknownDays(Nutrient.fibreG), 2);
  });
}
