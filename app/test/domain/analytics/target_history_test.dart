import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/analytics/target_history.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';

CalendarDate _d(int y, int m, int d) => CalendarDate(y, m, d);

int _n = 0;

Goal _goal(
  GoalKind kind,
  double target,
  DateTime start, {
  bool active = true,
  MeasurementSite? site,
  DateTime? updated,
  DateTime? created,
  String? id,
}) {
  final c = created ?? start;
  return Goal(
    id: id ?? 'g${_n++}',
    kind: kind,
    target: target,
    startDate: start.toUtc(),
    createdAt: c.toUtc(),
    updatedAt: (updated ?? c).toUtc(),
    site: site,
    active: active,
  );
}

void main() {
  group('TargetHistory (GOL-006)', () {
    // The D04 example: the calorie target changes on 2026-11-10.
    final history = TargetHistory.fromGoals([
      _goal(
        GoalKind.calories,
        2400,
        DateTime(2026, 9, 1, 8),
        active: false,
        updated: DateTime(2026, 11, 10, 9),
      ),
      _goal(GoalKind.calories, 2600, DateTime(2026, 11, 10, 9)),
    ]);

    test('days before the change keep the earlier target', () {
      expect(history.targetsOn(_d(2026, 11, 9)).kcal, 2400);
      expect(history.targetsOn(_d(2026, 10, 1)).kcal, 2400);
      expect(history.targetsOn(_d(2026, 9, 1)).kcal, 2400);
    });

    test('the day of the change and later days use the new target', () {
      expect(history.targetsOn(_d(2026, 11, 10)).kcal, 2600);
      expect(history.targetsOn(_d(2026, 12, 25)).kcal, 2600);
    });

    test('days before the first target have none', () {
      expect(history.targetsOn(_d(2026, 8, 31)).kcal, isNull);
      expect(history.targetsOn(_d(2026, 8, 31)).isEmpty, isTrue);
    });

    test('periodsFor lists both periods oldest first', () {
      final p = history.periodsFor(GoalKind.calories);
      expect(p, hasLength(2));
      expect(p[0].target, 2400);
      expect(p[0].effectiveFrom, _d(2026, 9, 1));
      expect(p[0].effectiveTo, _d(2026, 11, 9));
      expect(p[0].active, isFalse);
      expect(p[1].target, 2600);
      expect(p[1].effectiveFrom, _d(2026, 11, 10));
      expect(p[1].effectiveTo, isNull);
      expect(p[1].active, isTrue);
      expect(history.periodsFor(GoalKind.protein), isEmpty);
      expect(history.allPeriods, hasLength(2));
    });

    test('each nutrient has its own history', () {
      final h = TargetHistory.fromGoals([
        _goal(GoalKind.calories, 2400, DateTime(2026, 11)),
        _goal(GoalKind.protein, 150, DateTime(2026, 11)),
        _goal(
          GoalKind.protein,
          160,
          DateTime(2026, 11, 5),
          created: DateTime(2026, 11, 5),
        ),
        _goal(GoalKind.carbs, 250, DateTime(2026, 11)),
        _goal(GoalKind.fat, 70, DateTime(2026, 11)),
        _goal(GoalKind.fibre, 30, DateTime(2026, 11)),
      ]);
      final before = h.targetsOn(_d(2026, 11, 4));
      expect(before.proteinG, 150);
      expect(before.carbsG, 250);
      expect(before.fatG, 70);
      expect(before.fibreG, 30);
      expect(h.targetsOn(_d(2026, 11, 5)).proteinG, 160);
      expect(h.targetsOn(_d(2026, 11, 5)).kcal, 2400);
    });

    test('a cleared target applies until the day before it was cleared', () {
      final h = TargetHistory.fromGoals([
        _goal(
          GoalKind.fat,
          70,
          DateTime(2026, 11),
          active: false,
          updated: DateTime(2026, 11, 6, 20),
        ),
      ]);
      expect(h.targetsOn(_d(2026, 11, 5)).fatG, 70);
      expect(h.targetsOn(_d(2026, 11, 6)).fatG, isNull);
      expect(h.periodsFor(GoalKind.fat).single.effectiveTo, _d(2026, 11, 5));
    });

    test('a cleared target stays cleared until its successor starts', () {
      final h = TargetHistory.fromGoals([
        _goal(
          GoalKind.calories,
          2000,
          DateTime(2026, 10),
          active: false,
          updated: DateTime(2026, 10, 15, 9),
        ),
        _goal(GoalKind.calories, 2500, DateTime(2026, 11)),
      ]);
      expect(h.targetsOn(_d(2026, 10, 14)).kcal, 2000);
      expect(h.targetsOn(_d(2026, 10, 20)).kcal, isNull);
      expect(h.targetsOn(_d(2026, 11, 1)).kcal, 2500);
    });

    test('a target replaced on the day it was set never applied', () {
      final h = TargetHistory.fromGoals([
        _goal(
          GoalKind.calories,
          2300,
          DateTime(2026, 11, 3, 8),
          created: DateTime(2026, 11, 3, 8),
        ),
        _goal(
          GoalKind.calories,
          2500,
          DateTime(2026, 11, 3, 18),
          created: DateTime(2026, 11, 3, 18),
        ),
      ]);
      expect(h.targetsOn(_d(2026, 11, 3)).kcal, 2500);
      final p = h.periodsFor(GoalKind.calories);
      expect(p, hasLength(2));
      expect(p.first.replacedSameDay, isTrue);
      expect(p.first.covers(_d(2026, 11, 3)), isFalse);
      expect(p.last.replacedSameDay, isFalse);
    });

    test('the order of the input rows does not matter', () {
      final rows = [
        _goal(GoalKind.calories, 2600, DateTime(2026, 11, 10)),
        _goal(
          GoalKind.calories,
          2400,
          DateTime(2026, 9),
          active: false,
          updated: DateTime(2026, 11, 10),
        ),
      ];
      final a = TargetHistory.fromGoals(rows);
      final b = TargetHistory.fromGoals(rows.reversed);
      expect(a.targetsOn(_d(2026, 11, 9)).kcal, 2400);
      expect(b.targetsOn(_d(2026, 11, 9)).kcal, 2400);
      expect(b.targetsOn(_d(2026, 11, 10)).kcal, 2600);
    });

    test('a goal deadline (endDate) does not end its period', () {
      final g = _goal(
        GoalKind.bodyWeight,
        80,
        DateTime(2026, 11),
      ).copyWith(endDate: DateTime(2026, 12));
      final h = TargetHistory.fromGoals([g]);
      expect(h.targetOn(GoalKind.bodyWeight, _d(2027, 3, 1)), 80);
    });

    test('measurement goals are kept per site, left and right apart', () {
      final h = TargetHistory.fromGoals([
        _goal(
          GoalKind.measurement,
          85,
          DateTime(2026, 11),
          site: MeasurementSite.waist,
        ),
        _goal(
          GoalKind.measurement,
          60,
          DateTime(2026, 11),
          site: MeasurementSite.thighLeft,
        ),
        _goal(
          GoalKind.measurement,
          61,
          DateTime(2026, 11),
          site: MeasurementSite.thighRight,
        ),
      ]);
      final day = _d(2026, 11, 2);
      expect(
        h.targetOn(GoalKind.measurement, day, site: MeasurementSite.waist),
        85,
      );
      expect(
        h.targetOn(GoalKind.measurement, day, site: MeasurementSite.thighLeft),
        60,
      );
      expect(
        h.targetOn(GoalKind.measurement, day, site: MeasurementSite.thighRight),
        61,
      );
      expect(
        h.targetOn(GoalKind.measurement, day, site: MeasurementSite.hips),
        isNull,
      );
      expect(
        h.periodsFor(GoalKind.measurement, MeasurementSite.thighLeft),
        hasLength(1),
      );
    });

    test('the start date is the local calendar date of the instant', () {
      final h = TargetHistory.fromGoals([
        _goal(GoalKind.calories, 2000, DateTime(2026, 11, 10, 0, 30)),
      ]);
      expect(h.targetsOn(_d(2026, 11, 9)).kcal, isNull);
      expect(h.targetsOn(_d(2026, 11, 10)).kcal, 2000);
    });
  });
}
