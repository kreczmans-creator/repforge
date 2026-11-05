import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurement_comparison.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/measurements/measurement_rules.dart';
import 'package:repforge/domain/measurements/measurement_site_help.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/measurements/measurements_csv.dart';
import 'package:repforge/domain/measurements/progress_summary.dart';
import 'package:repforge/domain/measurements/weight_trend.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';

int _seq = 0;

/// A reading at a LOCAL wall-clock time, so expectations hold in any zone.
Measurement _m(
  MeasurementSite site,
  double v,
  int y,
  int mo,
  int d, [
  int h = 12,
  int min = 0,
]) {
  final at = DateTime(y, mo, d, h, min);
  return Measurement(
    id: 'm${_seq++}',
    site: site,
    value: site.isWeight
        ? MeasurementValue.kg(Kilograms.fromStored(v))
        : MeasurementValue.cm(Centimetres.fromStored(v)),
    recordedAt: at.toUtc(),
    createdAt: at.toUtc(),
    updatedAt: at.toUtc(),
  );
}

Measurement _w(double v, int d, [int h = 12, int mo = 11]) =>
    _m(MeasurementSite.weight, v, 2026, mo, d, h);
Measurement _waist(double v, int mo, int d, [int h = 12]) =>
    _m(MeasurementSite.waist, v, 2026, mo, d, h);

CalendarDate _d(int y, int m, int d) => CalendarDate(y, m, d);

void main() {
  group('CalendarDate', () {
    test('uses the local calendar date of an instant', () {
      // 23:30 local on 5 Nov is the 5th locally in every zone, even when the
      // UTC date differs.
      expect(
        CalendarDate.fromInstant(DateTime(2026, 11, 5, 23, 30).toUtc()),
        _d(2026, 11, 5),
      );
      expect(
        CalendarDate.fromInstant(DateTime(2026, 11, 5, 0, 30).toUtc()),
        _d(2026, 11, 5),
      );
    });

    test('date arithmetic ignores daylight-saving shifts', () {
      // NZ DST starts 2026-09-27, US DST ends 2026-11-01.
      expect(_d(2026, 9, 20).daysUntil(_d(2026, 10, 4)), 14);
      expect(_d(2026, 10, 28).addDays(7), _d(2026, 11, 4));
      expect(_d(2026, 3, 1).addDays(-1), _d(2026, 2, 28));
      expect(_d(2028, 2, 29).addYears(-1), _d(2027, 3, 1));
      expect(_d(2026, 11, 5).iso, '2026-11-05');
    });
  });

  group('MeasurementPeriod ranges (local dates, inclusive of today)', () {
    final today = _d(2026, 11, 5);

    test('4 weeks = 28 dates ending today', () {
      final r = MeasurementPeriod.weeks4.rangeEndingOn(today)!;
      expect(r.start, _d(2026, 10, 9));
      expect(r.end, today);
      expect(r.start.daysUntil(r.end) + 1, 28);
    });

    test('12 weeks = 84 dates, 1 year = day after same day last year', () {
      expect(
        MeasurementPeriod.weeks12.rangeEndingOn(today)!.start,
        _d(2026, 8, 14),
      );
      expect(
        MeasurementPeriod.year1.rangeEndingOn(today)!.start,
        _d(2025, 11, 6),
      );
      expect(MeasurementPeriod.all.rangeEndingOn(today), isNull);
    });

    test('boundary readings: first and last day in, day before out', () {
      final now = DateTime(2026, 11, 5, 9).toUtc();
      final readings = [
        _w(80, 8, 0, 10), // 8 Oct 00:00 local: day before the range start
        _w(80.1, 9, 0, 10), // 9 Oct 00:00 local: first day, in
        _w(80.2, 5, 23), // today 23:00 local: in
      ];
      final f = filterByPeriod(readings, MeasurementPeriod.weeks4, now);
      expect(f.map((m) => m.value.raw), [80.1, 80.2]);
      expect(
        filterByPeriod(readings, MeasurementPeriod.all, now),
        hasLength(3),
      );
    });

    test('"today" is the local date: late evening local still counts', () {
      // 23:50 local on 5 Nov; a UTC-based date would be the 4th or 6th.
      final now = DateTime(2026, 11, 5, 23, 50).toUtc();
      final r = filterByPeriod([_w(80, 5, 23)], MeasurementPeriod.weeks4, now);
      expect(r, hasLength(1));
    });
  });

  group('future rule', () {
    final now = DateTime(2026, 11, 5, 23, 50).toUtc();

    test('rejects the next local day just after midnight', () {
      final next = DateTime(2026, 11, 6, 0, 10).toUtc();
      expect(checkNotInFuture(next, now), isA<ValidationError>());
    });

    test('accepts earlier today and within one minute of skew', () {
      expect(checkNotInFuture(DateTime(2026, 11, 5, 23).toUtc(), now), isNull);
      expect(
        checkNotInFuture(DateTime(2026, 11, 5, 23, 50, 30).toUtc(), now),
        isNull,
      );
      expect(
        checkNotInFuture(DateTime(2026, 11, 5, 23, 51, 1).toUtc(), now),
        isA<ValidationError>(),
      );
    });

    test('is independent of the UTC/local flag of the inputs', () {
      final local = DateTime(2026, 11, 6, 1);
      expect(checkNotInFuture(local, now), isNotNull);
      expect(checkNotInFuture(local.toUtc(), now.toLocal()), isNotNull);
    });
  });

  group('change (BCM-007)', () {
    test('D04 example: waist 90.0 -> 87.5 = -2.5 cm and -2.8 %', () {
      final c = changeBetweenReadings(_waist(90, 11, 1), _waist(87.5, 12, 1));
      expect(c.absolute, -2.5);
      expect(c.percent, -2.8);
      expect(c.unit, 'cm');
    });

    test('rounds half away from zero, tolerating float noise', () {
      expect(Change.between(200, 200.1, unit: 'kg').percent, 0.1); // 0.05 %
      expect(Change.between(200, 199.9, unit: 'kg').percent, -0.1);
      expect(Change.between(80, 80, unit: 'kg').absolute, 0);
      expect(Change.between(80, 80, unit: 'kg').percent, 0);
      expect(Change.between(0, 5, unit: 'kg').percent, isNull);
    });
  });

  group('compare two dates (D4: no silent substitution)', () {
    final all = [
      _waist(90, 11, 1, 8),
      _waist(91, 11, 1, 20), // latest on 1 Nov
      _waist(88, 11, 10),
      _waist(87.5, 12, 1),
      _m(MeasurementSite.chest, 100, 2026, 11, 1),
    ];

    test('exact readings on both dates give the change', () {
      final r = compareDates(
        all,
        MeasurementSite.waist,
        _d(2026, 11, 1),
        _d(2026, 12, 1),
      );
      expect((r.earlier as ExactReading).reading.value.raw, 91); // latest day
      expect((r.later as ExactReading).reading.value.raw, 87.5);
      expect(r.change!.absolute, -3.5);
      expect(r.change!.percent, -3.8);
    });

    test('argument order does not matter: the earlier date is the base', () {
      final r = compareDates(
        all,
        MeasurementSite.waist,
        _d(2026, 12, 1),
        _d(2026, 11, 10),
      );
      expect(r.earlier.requested, _d(2026, 11, 10));
      expect(r.change!.absolute, -0.5);
    });

    test('a missing date returns both neighbours and computes nothing', () {
      final r = compareDates(
        all,
        MeasurementSite.waist,
        _d(2026, 11, 5),
        _d(2026, 12, 1),
      );
      final choice = r.earlier as NeedsChoice;
      // Nearest earlier = latest reading on 1 Nov; nearest later = 10 Nov.
      expect(choice.before!.value.raw, 91);
      expect(choice.after!.value.raw, 88);
      expect(r.change, isNull);
      expect(r.later, isA<ExactReading>());
    });

    test('only one neighbour exists', () {
      final before = pickForDate(all.take(4), _d(2026, 12, 25)) as NeedsChoice;
      expect(before.after, isNull);
      expect(before.before!.value.raw, 87.5);
      final after = pickForDate(all.take(4), _d(2026, 10, 1)) as NeedsChoice;
      expect(after.before, isNull);
      expect(after.after!.value.raw, 90); // earliest reading of 1 Nov
    });

    test('no readings at all is NoData; other sites are ignored', () {
      final r = compareDates(
        all,
        MeasurementSite.neck,
        _d(2026, 11, 1),
        _d(2026, 12, 1),
      );
      expect(r.earlier, isA<NoData>());
      expect(r.change, isNull);
    });

    test('after the user chooses, the change is computed on the choice', () {
      final r = compareDates(
        all,
        MeasurementSite.waist,
        _d(2026, 11, 5),
        _d(2026, 12, 1),
      );
      final choice = r.earlier as NeedsChoice;
      final c = changeBetweenReadings(
        choice.after!,
        (r.later as ExactReading).reading,
      );
      expect(c.absolute, -0.5);
    });
  });

  group('compare two periods (D4: mean with the number of readings)', () {
    final all = [
      _waist(90, 10, 5),
      _waist(88, 10, 6),
      _waist(89, 10, 7),
      _waist(86, 11, 2),
      _waist(87, 11, 3),
    ];
    final oct = DateRange(_d(2026, 10, 1), _d(2026, 10, 31));
    final nov = DateRange(_d(2026, 11, 1), _d(2026, 11, 30));

    test('mean and count per period; change of the means', () {
      final r = comparePeriods(all, MeasurementSite.waist, nov, oct);
      expect(r.earlier.count, 3);
      expect(r.earlier.mean, 89);
      expect(r.later.count, 2);
      expect(r.later.mean, 86.5);
      expect(r.change!.absolute, -2.5);
      expect(r.change!.percent, -2.8);
    });

    test('an empty period has count 0, no mean and no change', () {
      final dec = DateRange(_d(2026, 12, 1), _d(2026, 12, 31));
      final r = comparePeriods(all, MeasurementSite.waist, oct, dec);
      expect(r.later.count, 0);
      expect(r.later.mean, isNull);
      expect(r.change, isNull);
    });
  });

  group('progress summary (BCM-008)', () {
    final now = DateTime(2026, 11, 5, 18).toUtc();
    final all = [
      _waist(90, 10, 20),
      _waist(88, 11, 1),
      _waist(87.5, 11, 4),
      _w(80, 3),
      _m(MeasurementSite.neck, 38, 2026, 3, 1), // outside 4 weeks
      _m(MeasurementSite.neck, 39, 2026, 11, 2),
    ];

    test('first, latest and difference with at least two readings', () {
      final e = progressFor(
        all,
        MeasurementSite.waist,
        MeasurementPeriod.weeks4,
        now,
      );
      final p = e as SiteProgress;
      expect(p.first.value.raw, 90);
      expect(p.latest.value.raw, 87.5);
      expect(p.count, 3);
      expect(p.change.absolute, -2.5);
      expect(p.change.percent, -2.8);
    });

    test('fewer than two readings in the period is not enough data', () {
      final w = progressFor(
        all,
        MeasurementSite.weight,
        MeasurementPeriod.weeks4,
        now,
      );
      expect(w, isA<NotEnoughData>());
      expect(w.count, 1);
      // Two neck readings overall, but only one inside 4 weeks.
      expect(
        progressFor(all, MeasurementSite.neck, MeasurementPeriod.weeks4, now),
        isA<NotEnoughData>(),
      );
      expect(
        progressFor(all, MeasurementSite.neck, MeasurementPeriod.all, now),
        isA<SiteProgress>(),
      );
      expect(
        progressFor(
          all,
          MeasurementSite.hips,
          MeasurementPeriod.all,
          now,
        ).count,
        0,
      );
    });

    test('summary covers every site in enum order', () {
      final s = progressSummary(all, MeasurementPeriod.weeks4, now);
      expect(s.map((e) => e.site), MeasurementSite.values);
    });
  });

  group('weight trend (D1, owner-approved)', () {
    test('threshold counts readings: 2 readings on 2 days -> no value', () {
      final t = weightTrend([_w(80, 1), _w(81, 2)]);
      expect(t.map((p) => p.average), [null, null]);
      expect(t.last.readingsInWindow, 2);
    });

    test('3 readings on 2 days -> value shown', () {
      final t = weightTrend([_w(80, 1, 8), _w(82, 1, 20), _w(81, 2)]);
      expect(t.last.readingsInWindow, 3);
      // Daily means 81 and 81 -> 81.
      expect(t.last.average, 81);
    });

    test('4 readings on one day -> value equals the daily mean', () {
      final t = weightTrend([
        _w(80, 3, 6),
        _w(81, 3, 10),
        _w(82, 3, 14),
        _w(83, 3, 18),
      ]);
      expect(t, hasLength(1));
      expect(t.single.dailyMean, 81.5);
      expect(t.single.average, 81.5);
    });

    test('daily means are averaged, not individual readings', () {
      // Day 1: 80 x3 (mean 80); day 2: 83 (mean 83). Per-reading mean would
      // be 80.75; per-day mean is 81.5.
      final t = weightTrend([
        _w(80, 1, 6),
        _w(80, 1, 10),
        _w(80, 1, 14),
        _w(83, 2),
      ]);
      expect(t.last.average, 81.5);
    });

    test('trailing seven calendar days: older days drop out, gaps kept', () {
      final t = weightTrend([
        _w(80, 1),
        _w(81, 2),
        _w(82, 3),
        _w(90, 10), // window 4..10 holds only this one reading
        _w(90, 11), // window 5..11: 2 readings
        _w(90, 12), // window 6..12: 3 readings
      ]);
      expect(t.map((p) => p.date.day), [1, 2, 3, 10, 11, 12]);
      expect(t[2].average, 81); // 80, 81, 82
      expect(t[3].average, isNull);
      expect(t[4].average, isNull);
      expect(t[5].average, 90);
      expect(t[5].readingsInWindow, 3);
    });

    test('raw readings are untouched and other sites ignored', () {
      final input = [_w(80, 1), _waist(90, 11, 1)];
      final copy = List.of(input);
      final t = weightTrend(input);
      expect(input, copy);
      expect(t, hasLength(1));
    });

    test('range filter keeps the look-back before the range start', () {
      final all = [_w(80, 1), _w(81, 2), _w(82, 3), _w(83, 4)];
      final p = weightTrendInRange(
        all,
        DateRange(_d(2026, 11, 3), _d(2026, 11, 4)),
      );
      expect(p.map((x) => x.date.day), [3, 4]);
      expect(p.first.average, 81);
    });
  });

  group('CSV (D5, owner-approved)', () {
    test('header, one row per reading, oldest first, one decimal, units', () {
      final csv = buildMeasurementsCsv([
        _waist(87.5, 12, 1, 8),
        _w(80, 2, 7),
        _m(MeasurementSite.thighLeft, 55, 2026, 11, 2, 7),
      ]);
      final lines = csv.split('\r\n');
      expect(lines.first, 'date,type,value,unit');
      expect(lines.last, '');
      expect(lines, hasLength(5));
      expect(
        lines[1],
        matches(RegExp(r'^2026-11-02T07:00:00[+-]\d\d:\d\d,Weight,80\.0,kg$')),
      );
      expect(lines[2], contains(',Left thigh,55.0,cm'));
      expect(lines[3], contains(',Waist,87.5,cm'));
    });

    test('empty input is just the header', () {
      expect(buildMeasurementsCsv([]), 'date,type,value,unit\r\n');
    });

    test('RFC 4180 quoting', () {
      expect(csvField('plain'), 'plain');
      expect(csvField('a,b'), '"a,b"');
      expect(csvField('say "hi"'), '"say ""hi"""');
      expect(csvField('l1\nl2'), '"l1\nl2"');
    });

    test('date is local with the UTC offset of the device zone', () {
      final s = formatLocalIsoWithOffset(DateTime(2026, 11, 5, 14, 30).toUtc());
      final tz = Platform.environment['TZ'];
      final expected = switch (tz) {
        'Pacific/Auckland' => '2026-11-05T14:30:00+13:00',
        'America/Los_Angeles' => '2026-11-05T14:30:00-08:00',
        _ => null,
      };
      if (expected != null) expect(s, expected);
      final off = DateTime(2026, 11, 5, 14, 30).timeZoneOffset;
      final sign = off.isNegative ? '-' : '+';
      final mins = off.inMinutes.abs();
      expect(
        s,
        '2026-11-05T14:30:00$sign'
        '${(mins ~/ 60).toString().padLeft(2, '0')}:'
        '${(mins % 60).toString().padLeft(2, '0')}',
      );
    });
  });

  group('site help', () {
    test('every site has help; waist names the navel; limbs note the side', () {
      for (final s in MeasurementSite.values) {
        expect(s.helpText, isNotEmpty, reason: s.name);
      }
      expect(MeasurementSite.waist.helpText, contains('navel'));
      expect(
        MeasurementSite.thighLeft.helpText,
        contains('same side consistently'),
      );
      expect(MeasurementSite.neck.helpText, isNot(contains('same side')));
    });

    test('counterparts pair the eight limb sites', () {
      expect(MeasurementSite.thighLeft.counterpart, MeasurementSite.thighRight);
      expect(MeasurementSite.waist.counterpart, isNull);
      expect(MeasurementSite.values.where((s) => s.isBilateral), hasLength(8));
    });
  });

  group('parseMeasurementValue', () {
    test('weight uses kg limits, others cm; error field is the site', () {
      expect(
        parseMeasurementValue(MeasurementSite.weight, '80.1').isOk,
        isTrue,
      );
      expect(parseMeasurementValue(MeasurementSite.waist, '9.9').isErr, isTrue);
      final e =
          (parseMeasurementValue(
                MeasurementSite.thighRight,
                '55.05',
              ) as Err<MeasurementValue>).error
              as ValidationError;
      expect(e.field, 'thighRight');
      expect(e.message, contains('Right thigh'));
    });
  });
}
