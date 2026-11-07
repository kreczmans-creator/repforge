import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';

CalendarDate _d(int y, int m, int d) => CalendarDate(y, m, d);

void main() {
  group('AnalyticsPeriod week', () {
    test('Monday start: a Wednesday is in the week of that Monday', () {
      // 2026-11-04 is a Wednesday.
      final p = AnalyticsPeriod.thisWeek(DateTime(2026, 11, 4, 12), 1);
      expect(p.from, _d(2026, 11, 2));
      expect(p.to, _d(2026, 11, 8));
      expect(p.kind, AnalyticsPeriodKind.week);
      expect(p.dayCount, 7);
      expect(p.label, 'Week of 2026-11-02');
    });

    test('Monday itself and Sunday belong to the same Monday week', () {
      expect(
        AnalyticsPeriod.thisWeek(DateTime(2026, 11, 2, 0, 5), 1).from,
        _d(2026, 11, 2),
      );
      expect(
        AnalyticsPeriod.thisWeek(DateTime(2026, 11, 8, 23, 59), 1).from,
        _d(2026, 11, 2),
      );
    });

    test('Sunday start (7) and Wednesday start (3)', () {
      final sun = AnalyticsPeriod.thisWeek(DateTime(2026, 11, 4, 12), 7);
      expect(sun.from, _d(2026, 11, 1));
      expect(sun.to, _d(2026, 11, 7));
      final wed = AnalyticsPeriod.thisWeek(DateTime(2026, 11, 4, 12), 3);
      expect(wed.from, _d(2026, 11, 4));
      final thu = AnalyticsPeriod.thisWeek(DateTime(2026, 11, 4, 12), 4);
      expect(thu.from, _d(2026, 10, 29));
    });

    test('day start hour: 02:30 Monday still belongs to the Sunday before', () {
      final at = DateTime(2026, 11, 2, 2, 30);
      expect(AnalyticsPeriod.thisWeek(at, 1).from, _d(2026, 11, 2));
      final shifted = AnalyticsPeriod.thisWeek(at, 1, dayStartHour: 4);
      expect(shifted.from, _d(2026, 10, 26));
      expect(shifted.to, _d(2026, 11, 1));
      expect(shifted.dayRule, 'Days start at 04:00');
    });

    test('last week is the seven days before this week', () {
      final p = AnalyticsPeriod.lastWeek(DateTime(2026, 11, 4, 12), 1);
      expect(p.from, _d(2026, 10, 26));
      expect(p.to, _d(2026, 11, 1));
      expect(p.kind, AnalyticsPeriodKind.week);
    });

    test('a week across the US daylight-saving change has seven dates', () {
      // Clocks change on 2026-11-01 (US) and 2026-10-25 (EU).
      for (final start in [DateTime(2026, 10, 26, 9), DateTime(2026, 11, 2)]) {
        final p = AnalyticsPeriod.thisWeek(start, 7);
        expect(p.days, hasLength(7));
        expect(p.days.toSet(), hasLength(7));
        expect(p.dayKeys.first, p.fromKey);
        expect(p.dayKeys.last, p.toKey);
      }
      final across = AnalyticsPeriod.thisWeek(DateTime(2026, 11, 3, 9), 6);
      expect(across.from, _d(2026, 10, 31));
      expect(across.to, _d(2026, 11, 6));
      expect(across.dayKeys, [
        '2026-10-31',
        '2026-11-01',
        '2026-11-02',
        '2026-11-03',
        '2026-11-04',
        '2026-11-05',
        '2026-11-06',
      ]);
    });

    test('a spring-forward week keeps its dates (EU 2026-03-29)', () {
      final p = AnalyticsPeriod.thisWeek(DateTime(2026, 3, 29, 12), 1);
      expect(p.from, _d(2026, 3, 23));
      expect(p.to, _d(2026, 3, 29));
      expect(p.previous.from, _d(2026, 3, 16));
    });

    test('instants use local constructors at the day start hour', () {
      final p = AnalyticsPeriod.thisWeek(
        DateTime(2026, 11, 4, 12),
        1,
        dayStartHour: 4,
      );
      expect(p.startInstant, DateTime(2026, 11, 2, 4));
      expect(p.endInstantExclusive, DateTime(2026, 11, 9, 4));
      expect(p.calendarStartInstant, DateTime(2026, 11, 2));
      expect(p.calendarEndInstantExclusive, DateTime(2026, 11, 9));
    });
  });

  group('AnalyticsPeriod month', () {
    test('this month and last month', () {
      final now = DateTime(2026, 11, 7, 10);
      final m = AnalyticsPeriod.thisMonth(now);
      expect(m.from, _d(2026, 11, 1));
      expect(m.to, _d(2026, 11, 30));
      expect(m.label, 'November 2026');
      final l = AnalyticsPeriod.lastMonth(now);
      expect(l.from, _d(2026, 10, 1));
      expect(l.to, _d(2026, 10, 31));
      expect(l.kind, AnalyticsPeriodKind.month);
    });

    test('January has December of the year before as last month', () {
      final l = AnalyticsPeriod.lastMonth(DateTime(2027, 1, 15));
      expect(l.from, _d(2026, 12, 1));
      expect(l.to, _d(2026, 12, 31));
    });

    test('February in a leap year; day start moves the month boundary', () {
      expect(AnalyticsPeriod.thisMonth(DateTime(2028, 2, 10)).to.day, 29);
      // 01:00 on 1 December with a 04:00 day start is still 30 November.
      final p = AnalyticsPeriod.thisMonth(
        DateTime(2026, 12, 1, 1),
        dayStartHour: 4,
      );
      expect(p.from, _d(2026, 11, 1));
    });
  });

  group('AnalyticsPeriod helpers', () {
    test('containsDay is inclusive of both ends', () {
      final p = AnalyticsPeriod.custom(_d(2026, 11, 2), _d(2026, 11, 4));
      expect(p.containsDay(_d(2026, 11, 1)), isFalse);
      expect(p.containsDay(_d(2026, 11, 2)), isTrue);
      expect(p.containsDay(_d(2026, 11, 4)), isTrue);
      expect(p.containsDay(_d(2026, 11, 5)), isFalse);
      expect(p.containsDayKey('2026-11-03'), isTrue);
      expect(p.dayCount, 3);
      expect(p.dateRange.contains(_d(2026, 11, 3)), isTrue);
    });

    test('containsInstant applies the day start hour', () {
      final p = AnalyticsPeriod.custom(
        _d(2026, 11, 2),
        _d(2026, 11, 2),
        dayStartHour: 4,
      );
      expect(p.containsInstant(DateTime(2026, 11, 2, 3, 59)), isFalse);
      expect(p.containsInstant(DateTime(2026, 11, 2, 4)), isTrue);
      expect(p.containsInstant(DateTime(2026, 11, 3, 3, 59)), isTrue);
      expect(p.containsInstant(DateTime(2026, 11, 3, 4)), isFalse);
    });

    test('custom previous has equal length and is adjacent', () {
      final p = AnalyticsPeriod.custom(_d(2026, 11, 5), _d(2026, 11, 9));
      expect(p.previous.from, _d(2026, 10, 31));
      expect(p.previous.to, _d(2026, 11, 4));
      expect(p.previous.dayCount, p.dayCount);
    });

    test('equality and midnight rule label', () {
      final a = AnalyticsPeriod.custom(_d(2026, 11, 2), _d(2026, 11, 4));
      final b = AnalyticsPeriod.custom(_d(2026, 11, 2), _d(2026, 11, 4));
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a.dayRule, 'Days run from local midnight');
      expect(a.label, '2026-11-02 to 2026-11-04');
      expect(
        a,
        isNot(AnalyticsPeriod.custom(_d(2026, 11, 2), _d(2026, 11, 5))),
      );
    });

    test('day key parsing', () {
      expect(calendarDateFromKey('2026-11-07'), _d(2026, 11, 7));
      expect(() => calendarDateFromKey('7 Nov'), throwsFormatException);
      expect(diaryDay(DateTime(2026, 11, 7, 2), 4), _d(2026, 11, 6));
    });
  });

  group('Metric', () {
    const basis = MetricBasis(
      sampleCount: 5,
      sources: ['food log entries'],
      dayRule: 'Days run from local midnight',
      weakestProvenance: DataProvenance.estimated,
    );

    test('MetricValue carries value and basis', () {
      const m = MetricValue<double>(2100, basis);
      expect(m.isAvailable, isTrue);
      expect(m.valueOrNull, 2100);
      expect(m.basis.sampleCount, 5);
    });

    test('NotEnoughData has no value and says what is missing', () {
      const m = NotEnoughData<double>(
        have: 0,
        need: 1,
        reason: 'No day was logged.',
      );
      expect(m.isAvailable, isFalse);
      expect(m.valueOrNull, isNull);
      expect(m.reason, 'No day was logged.');
    });

    test('basis description names sources, count and the day rule', () {
      expect(
        basis.describe(),
        'food log entries · 5 samples · Days run from local midnight',
      );
      expect(
        MetricBasis(
          period: AnalyticsPeriod.custom(_d(2026, 11, 2), _d(2026, 11, 4)),
          sampleCount: 1,
          sources: const ['weight'],
          dayRule: calendarDayRule,
        ).describe(),
        'weight · 2026-11-02 to 2026-11-04 · 1 sample · '
        'Calendar dates (local midnight)',
      );
    });
  });
}
