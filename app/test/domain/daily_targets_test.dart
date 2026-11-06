import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/units/units.dart';

Goal _goal(GoalKind k, double v, {int day = 1, bool active = true}) => Goal(
  id: '${k.name}-$day',
  kind: k,
  target: v,
  startDate: DateTime.utc(2026, 11, day),
  createdAt: DateTime.utc(2026, 11, day),
  updatedAt: DateTime.utc(2026, 11, day),
  active: active,
);

FoodLogEntry _entry(double kcal, double p, double c, double f, {double? fib}) =>
    FoodLogEntry(
      id: 'e$kcal',
      day: '2026-11-03',
      meal: MealSlot.lunch,
      name: 'x',
      quantity: Quantity.fromStored(100, ReferenceUnit.grams),
      nutrients: NutrientAmounts(
        kcal: kcal,
        proteinG: p,
        carbsG: c,
        fatG: f,
        fibreG: fib,
      ),
      provenance: DataProvenance.userEntered,
      loggedAt: DateTime.utc(2026, 11, 3, 12),
      createdAt: DateTime.utc(2026, 11, 3, 12),
      updatedAt: DateTime.utc(2026, 11, 3, 12),
    );

void main() {
  group('DailyTargets.fromGoals', () {
    test('takes the most recently updated active goal per kind', () {
      final t = DailyTargets.fromGoals([
        _goal(GoalKind.calories, 2400),
        _goal(GoalKind.calories, 2200, day: 2),
        _goal(GoalKind.protein, 180),
        _goal(GoalKind.fat, 70, active: false),
        _goal(GoalKind.bodyWeight, 84),
      ]);
      expect(t.kcal, 2200);
      expect(t.proteinG, 180);
      expect(t.carbsG, isNull);
      expect(t.fatG, isNull); // inactive ignored
      expect(t.isEmpty, isFalse);
    });

    test('is empty with no nutrition goals', () {
      expect(DailyTargets.fromGoals(const []).isEmpty, isTrue);
    });
  });

  group('validateTarget', () {
    test('accepts calories in 800–10000 and rejects outside', () {
      expect(validateTarget(GoalKind.calories, 2400), isA<Ok<double>>());
      expect(validateTarget(GoalKind.calories, 500), isA<Err<double>>());
      expect(validateTarget(GoalKind.calories, 20000), isA<Err<double>>());
    });
    test('macros 0–1000 g, NaN rejected', () {
      expect(validateTarget(GoalKind.protein, 0), isA<Ok<double>>());
      expect(validateTarget(GoalKind.protein, 1001), isA<Err<double>>());
      expect(validateTarget(GoalKind.fat, double.nan), isA<Err<double>>());
    });
  });

  group('DailySummary', () {
    test('sums entries and reports remaining calories', () {
      final s = DailySummary.fromEntries(
        day: '2026-11-03',
        entries: [_entry(200, 20, 10, 5, fib: 2), _entry(350, 30, 40, 12)],
        targets: const DailyTargets(kcal: 2000, proteinG: 150),
      );
      expect(s.entryCount, 2);
      expect(s.intake.kcal, 550);
      expect(s.intake.proteinG, 50);
      expect(s.intake.fibreG, 2); // null + 2 keeps 2
      expect(s.kcalRemaining, 1450);
    });

    test('remaining is null without a calorie target', () {
      final s = DailySummary.fromEntries(
        day: '2026-11-03',
        entries: const [],
        targets: DailyTargets.none,
      );
      expect(s.kcalRemaining, isNull);
      expect(s.intake, NutrientAmounts.zero);
    });
  });
}
