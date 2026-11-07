import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/analytics/nutrition_analytics.dart';
import 'package:repforge/domain/analytics/target_history.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/nutrition/summaries.dart';
import 'package:repforge/domain/units/units.dart';

int _n = 0;
final _t = DateTime.utc(2026, 11);

FoodLogEntry _e(
  String day,
  double kcal, {
  double? protein = 10,
  double? fibre = 2,
  DataProvenance provenance = DataProvenance.verified,
}) => FoodLogEntry(
  id: 'e${_n++}',
  day: day,
  meal: MealSlot.lunch,
  name: 'item',
  quantity: Quantity.fromStored(100, ReferenceUnit.grams),
  nutrients: NutrientAmounts(
    kcal: kcal,
    proteinG: protein,
    carbsG: 20,
    fatG: 5,
    fibreG: fibre,
  ),
  provenance: provenance,
  loggedAt: _t,
  createdAt: _t,
  updatedAt: _t,
);

Goal _kcal(
  double target,
  DateTime start, {
  bool active = true,
  DateTime? upd,
}) => Goal(
  id: 'k${_n++}',
  kind: GoalKind.calories,
  target: target,
  startDate: start.toUtc(),
  createdAt: start.toUtc(),
  updatedAt: (upd ?? start).toUtc(),
  active: active,
);

AnalyticsPeriod get _week =>
    AnalyticsPeriod.thisWeek(DateTime(2026, 11, 4, 12), 1);

NutritionWeek _build(
  List<FoodLogEntry> entries, {
  TargetHistory? history,
  AnalyticsPeriod? period,
  int dayStart = 0,
}) => NutritionWeek.build(
  period: period ?? _week,
  entries: entries,
  history: history ?? TargetHistory.fromGoals(const []),
  dayStartHour: dayStart,
);

void main() {
  group('weakest provenance (NUT-019)', () {
    test('a day of verified and estimated entries is estimated', () {
      final w = _build([
        _e('2026-11-02', 500),
        _e('2026-11-02', 300, provenance: DataProvenance.estimated),
      ]);
      expect(w.days.first.provenance, DataProvenance.estimated);
      expect(w.weakestProvenanceOfPeriod, DataProvenance.estimated);
    });

    test(
      'follows the order verified, crowdsourced, user-entered, estimated',
      () {
        DataProvenance? of(List<DataProvenance> ps) =>
            _build([for (final p in ps) _e('2026-11-02', 100, provenance: p)])
                .days
                .first
                .provenance;
        expect(
          of([DataProvenance.verified, DataProvenance.userEntered]),
          DataProvenance.userEntered,
        );
        expect(
          of([DataProvenance.crowdsourced, DataProvenance.verified]),
          DataProvenance.crowdsourced,
        );
        expect(
          of([DataProvenance.userEntered, DataProvenance.crowdsourced]),
          DataProvenance.userEntered,
        );
        expect(of([DataProvenance.verified]), DataProvenance.verified);
      },
    );

    test('the week takes the weakest label over its days', () {
      final w = _build([
        _e('2026-11-02', 500),
        _e('2026-11-03', 500, provenance: DataProvenance.userEntered),
        _e('2026-11-04', 500, provenance: DataProvenance.crowdsourced),
      ]);
      expect(w.weakestProvenanceOfPeriod, DataProvenance.userEntered);
      final avg = w.averageEnergyKcal as MetricValue<double>;
      expect(avg.basis.weakestProvenance, DataProvenance.userEntered);
    });

    test('an unlogged day has no provenance', () {
      final w = _build([_e('2026-11-02', 500)]);
      expect(w.days[1].provenance, isNull);
      expect(_build(const []).weakestProvenanceOfPeriod, isNull);
    });
  });

  group('days logged (NUT-016)', () {
    test('entries on 5 of 7 days: average over those 5 days', () {
      final w = _build([
        for (var d = 2; d <= 6; d++) _e('2026-11-0$d', 2000.0 + d * 100),
      ]);
      expect(w.loggedDays, 5);
      expect(w.notLoggedDays, 2);
      expect(w.daysLoggedText, '5 of 7 days logged');
      final avg = w.averageEnergyKcal as MetricValue<double>;
      expect(avg.value, closeTo((2200 + 2300 + 2400 + 2500 + 2600) / 5, 1e-9));
      expect(avg.basis.sampleCount, 5);
      expect(avg.basis.sources, ['food log entries']);
      expect(avg.basis.dayRule, 'Days run from local midnight');
      expect(avg.basis.period, _week);
    });

    test('unlogged days are listed as not logged, not as zero', () {
      final w = _build([_e('2026-11-02', 500)]);
      expect(w.days, hasLength(7));
      expect(w.days.where((d) => !d.isLogged), hasLength(6));
      expect(w.days.first.isLogged, isTrue);
      expect(w.days[3].entryCount, 0);
    });

    test('several entries on one day count as one logged day', () {
      final w = _build([
        _e('2026-11-02', 500),
        _e('2026-11-02', 700),
        _e('2026-11-03', 800),
      ]);
      expect(w.loggedDays, 2);
      expect((w.averageEnergyKcal as MetricValue<double>).value, 1000);
    });

    test('no logged day gives not enough data, not zero', () {
      final w = _build(const []);
      expect(w.loggedDays, 0);
      expect(w.daysLoggedText, '0 of 7 days logged');
      final m = w.averageEnergyKcal;
      expect(m, isA<NotEnoughData<double>>());
      expect((m as NotEnoughData<double>).have, 0);
      expect(m.need, 1);
      expect(w.averageProteinG, isA<NotEnoughData<double>>());
    });

    test('entries outside the period are ignored', () {
      final w = _build([
        _e('2026-11-01', 5000),
        _e('2026-11-09', 5000),
        _e('2026-11-03', 1000),
      ]);
      expect(w.loggedDays, 1);
      expect((w.averageEnergyKcal as MetricValue<double>).value, 1000);
    });

    test('matches the WeeklySummary rules it is built on', () {
      final entries = [
        _e('2026-11-02', 400, protein: null),
        _e('2026-11-03', 900),
      ];
      final w = _build(entries);
      final s = WeeklySummary.fromEntries(
        days: _week.dayKeys,
        entries: entries,
      );
      expect(
        (w.averageProteinG as MetricValue<double>).value,
        s.averagePerLoggedDay!.proteinG,
      );
      expect(w.summary.loggedDays, s.loggedDays);
    });

    test('the day rule is stated for a 04:00 day start', () {
      final w = _build([_e('2026-11-02', 500)], dayStart: 4);
      expect(w.dayRule, 'Days start at 04:00');
      expect(
        (w.averageEnergyKcal as MetricValue<double>).basis.dayRule,
        'Days start at 04:00',
      );
    });
  });

  group('unknown nutrients (NUT-021)', () {
    test('a day with an unknown protein is flagged and not summed as zero', () {
      final w = _build([
        _e('2026-11-02', 500),
        _e('2026-11-02', 300, protein: null),
      ]);
      final day = w.days.first;
      expect(day.hasMissingData, isTrue);
      expect(day.totals.unknownProteinCount, 1);
      expect(day.totals.known.proteinG, 10);
      expect(w.hasMissingData, isTrue);
      expect(w.days[1].hasMissingData, isFalse);
    });

    test('a day where no entry knows protein is left out of that average', () {
      final w = _build([
        _e('2026-11-02', 500, protein: null),
        _e('2026-11-03', 500, protein: 40),
        _e('2026-11-04', 500, protein: 60),
      ]);
      final avg = w.averageProteinG as MetricValue<double>;
      expect(avg.value, 50);
      expect(avg.basis.sampleCount, 2);
      expect(w.unknownDays(NutritionMeasure.proteinG), 1);
      expect(w.unknownDays(NutritionMeasure.kcal), 0);
      expect((w.averageEnergyKcal as MetricValue<double>).basis.sampleCount, 3);
    });

    test('a nutrient unknown on every logged day is not enough data', () {
      final w = _build([_e('2026-11-02', 500, fibre: null)]);
      final m = w.average(NutritionMeasure.fibreG);
      expect(m, isA<NotEnoughData<double>>());
      expect((m as NotEnoughData<double>).reason, contains('fibre'));
    });
  });

  group('targets in effect (GOL-006)', () {
    test('each day is evaluated against the target of that day', () {
      final history = TargetHistory.fromGoals([
        _kcal(
          2400,
          DateTime(2026, 9),
          active: false,
          upd: DateTime(2026, 11, 4),
        ),
        _kcal(2600, DateTime(2026, 11, 4)),
      ]);
      final w = _build([
        _e('2026-11-03', 2000),
        _e('2026-11-04', 2000),
      ], history: history);
      expect(w.days[1].targetsInEffect.kcal, 2400); // Tue 3 Nov
      expect(w.days[2].targetsInEffect.kcal, 2600); // Wed 4 Nov
      expect(w.days[0].targetsInEffect.kcal, 2400);
    });

    test('a day before any target has no target', () {
      final history = TargetHistory.fromGoals([
        _kcal(2400, DateTime(2026, 11, 5)),
      ]);
      final w = _build(const [], history: history);
      expect(w.days[0].targetsInEffect.kcal, isNull);
      expect(w.days[2].targetsInEffect.kcal, isNull);
      expect(w.days[3].targetsInEffect.kcal, 2400);
    });
  });

  test('DayNutrition.build reuses the daily summary totals', () {
    final d = DayNutrition.build(
      day: CalendarDate(2026, 11, 2),
      entries: [_e('2026-11-02', 100), _e('2026-11-02', 250)],
      targets: DailyTargets.none,
    );
    expect(d.totals.known.kcal, 350);
    expect(d.entryCount, 2);
    expect(d.dayKey, '2026-11-02');
  });

  test('a month period works the same way', () {
    final w = _build([
      _e('2026-10-05', 2000),
      _e('2026-10-31', 3000),
    ], period: AnalyticsPeriod.lastMonth(DateTime(2026, 11, 7)));
    expect(w.daysLoggedText, '2 of 31 days logged');
    expect((w.averageEnergyKcal as MetricValue<double>).value, 2500);
  });

  test('a week in progress does not count future days as not logged', () {
    final w = NutritionWeek.build(
      period: _week,
      entries: [_e('2026-11-02', 2000), _e('2026-11-03', 2000)],
      history: TargetHistory.fromGoals(const []),
      dayStartHour: 0,
      asOf: CalendarDate(2026, 11, 4),
    );
    expect(w.elapsedDays, 3);
    expect(w.daysLoggedText, '2 of 3 days logged');
    expect(w.notLoggedDays, 1);
    expect(w.days, hasLength(7));
  });

  test('a period entirely in the future reads "not started"', () {
    final w = NutritionWeek.build(
      period: _week,
      entries: const [],
      history: TargetHistory.fromGoals(const []),
      dayStartHour: 0,
      asOf: CalendarDate(2026, 10, 30),
    );
    expect(w.elapsedDays, 0);
    expect(w.daysLoggedText, 'not started');
    expect(w.notLoggedDays, 0);
  });
}
