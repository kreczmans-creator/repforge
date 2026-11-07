import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/analytics/data_quality.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';

import '../../helpers/analytics_fixtures.dart';

final _asOf = CalendarDate(2026, 11, 28);

String _key(CalendarDate d) => d.iso;

/// Food on the last [days] days ending on [_asOf], skipping offsets in
/// [skip] (0 = asOf).
List<FoodLogEntry> _food({
  int days = 28,
  Set<int> skip = const {},
  DataProvenance provenance = DataProvenance.verified,
  double kcal = 2000,
}) => [
  for (var i = 0; i < days; i++)
    if (!skip.contains(i))
      foodEntry(_key(_asOf.addDays(-i)), kcal, provenance: provenance),
];

/// Weight on [perWeek] days of each of the last [weeks] 7-day blocks.
List<Measurement> _weights({int weeks = 4, int perWeek = 3}) => [
  for (var w = 0; w < weeks; w++)
    for (var i = 0; i < perWeek; i++)
      () {
        final d = _asOf.addDays(-(w * 7 + i));
        return weightReading(80, d.month, d.day);
      }(),
];

DataQualityReport _eval(
  List<FoodLogEntry> food,
  List<Measurement> weights, {
  DataQualityThresholds t = DataQualityThresholds.proposed,
}) => DataQualityReport.evaluate(
  asOf: _asOf,
  entries: food,
  weightReadings: weights,
  thresholds: t,
);

void main() {
  group('thresholds', () {
    test('the proposed figures are labelled as not approved', () {
      const t = DataQualityThresholds.proposed;
      expect(t.minDays, 28);
      expect(t.minLoggedDayShare, 0.8);
      expect(t.minVerifiedEnergyShare, 0.9);
      expect(t.minWeightDaysPerWeek, 3);
      expect(t.label, 'proposed, not approved (OQ-15)');
      expect(_eval(const [], const []).thresholdsLabel, t.label);
    });
  });

  group('DataQualityReport (GOL-012)', () {
    test('passes when every proposed criterion is met', () {
      final r = _eval(_food(), _weights());
      expect(r.passed, isTrue);
      expect(r.criteria, hasLength(4));
      expect(r.criteria.every((c) => c.passed), isTrue);
      expect(r.of(DataQualityCriterionId.dataDays).observed, 28);
      expect(r.of(DataQualityCriterionId.loggedDays).observed, 1);
      expect(r.of(DataQualityCriterionId.verifiedEnergyShare).observed, 1);
      expect(r.of(DataQualityCriterionId.weightFrequency).observed, 3);
      expect(r.asOf, _asOf);
    });

    test('days of data: fails with 10 days, with observed and required', () {
      final r = _eval(_food(days: 10), _weights(weeks: 1));
      final c = r.of(DataQualityCriterionId.dataDays);
      expect(c.passed, isFalse);
      expect(c.observed, 10);
      expect(c.required, 28);
      expect(c.reason, 'Data spans 10 days; at least 28 are required.');
      expect(r.passed, isFalse);
    });

    test('days of data: no data at all', () {
      final r = _eval(const [], const []);
      final c = r.of(DataQualityCriterionId.dataDays);
      expect(c.passed, isFalse);
      expect(c.observed, 0);
      expect(c.reason, contains('No food or weight'));
      expect(r.passed, isFalse);
    });

    test('days of data: weight alone can start the span', () {
      final r = _eval(_food(days: 5), _weights());
      // The oldest weigh-in is 23 days before the as-of date: 24 days.
      expect(r.of(DataQualityCriterionId.dataDays).observed, 24);
    });

    test('logged days: 23 of 28 passes (82 %), 22 of 28 fails (79 %)', () {
      final pass = _eval(_food(skip: {1, 3, 5, 7, 9}), _weights());
      final p = pass.of(DataQualityCriterionId.loggedDays);
      expect(p.passed, isTrue);
      expect(p.reason, contains('23 of 28 days (82 %)'));
      final fail = _eval(_food(skip: {1, 3, 5, 7, 9, 11}), _weights());
      final f = fail.of(DataQualityCriterionId.loggedDays);
      expect(f.passed, isFalse);
      expect(f.observed, closeTo(22 / 28, 1e-12));
      expect(f.required, 0.8);
      expect(
        f.reason,
        'Food was logged on 22 of 28 days (79 %); at least 80 % is required.',
      );
      expect(fail.passed, isFalse);
    });

    test('logged days: only the window counts, older days do not', () {
      final r = _eval([
        ..._food(days: 10),
        foodEntry('2026-09-01', 2000),
      ], _weights());
      expect(r.of(DataQualityCriterionId.dataDays).observed, 89);
      expect(
        r.of(DataQualityCriterionId.loggedDays).reason,
        contains('10 of 28'),
      );
    });

    test('energy provenance: exactly 90 % passes, below fails', () {
      List<FoodLogEntry> mix(double weakKcal) => [
        ..._food(days: 27),
        foodEntry(
          _key(_asOf.addDays(-27)),
          weakKcal,
          provenance: DataProvenance.estimated,
        ),
      ];
      // 27 days x 2000 verified = 54000; weak 6000 gives exactly 90 %.
      final pass = _eval(mix(6000), _weights());
      expect(
        pass.of(DataQualityCriterionId.verifiedEnergyShare).passed,
        isTrue,
      );
      final fail = _eval(mix(7000), _weights());
      final c = fail.of(DataQualityCriterionId.verifiedEnergyShare);
      expect(c.passed, isFalse);
      expect(c.observed, closeTo(54000 / 61000, 1e-12));
      expect(c.reason, contains('89 % of logged energy is verified'));
      expect(c.reason, contains('at least 90 %'));
    });

    test('energy provenance: user-entered counts, crowdsourced does not', () {
      final user = _eval(
        _food(provenance: DataProvenance.userEntered),
        _weights(),
      );
      expect(user.of(DataQualityCriterionId.verifiedEnergyShare).observed, 1);
      final crowd = _eval(
        _food(provenance: DataProvenance.crowdsourced),
        _weights(),
      );
      expect(crowd.of(DataQualityCriterionId.verifiedEnergyShare).observed, 0);
      expect(
        crowd.of(DataQualityCriterionId.verifiedEnergyShare).passed,
        isFalse,
      );
    });

    test('energy provenance: no energy logged cannot be measured', () {
      final r = _eval(const [], _weights());
      final c = r.of(DataQualityCriterionId.verifiedEnergyShare);
      expect(c.observed, isNull);
      expect(c.passed, isFalse);
      expect(c.reason, contains('No energy was logged'));
    });

    test('weigh-ins: the week with the fewest days decides', () {
      final weights = [..._weights(), ..._weights(weeks: 1)];
      expect(
        _eval(
          _food(),
          weights,
        ).of(DataQualityCriterionId.weightFrequency).passed,
        isTrue,
      );
      // Three weeks with 3 days and one week with 2.
      final thin = [
        ..._weights(weeks: 3),
        for (var i = 0; i < 2; i++)
          weightReading(
            80,
            _asOf.addDays(-(21 + i)).month,
            _asOf.addDays(-(21 + i)).day,
          ),
      ];
      final r = _eval(_food(), thin);
      final c = r.of(DataQualityCriterionId.weightFrequency);
      expect(c.passed, isFalse);
      expect(c.observed, 2);
      expect(c.required, 3);
      expect(c.reason, contains('had 2 days'));
      expect(c.reason, contains('4 blocks'));
      expect(c.reason, contains('at least 3 are required'));
    });

    test('weigh-ins: several readings on one day count once; none fails', () {
      final oneDay = [for (var h = 0; h < 5; h++) weightReading(80, 11, 28)];
      final r = _eval(_food(), oneDay);
      expect(r.of(DataQualityCriterionId.weightFrequency).observed, 0);
      expect(
        r.of(DataQualityCriterionId.weightFrequency).reason,
        contains('0 days'),
      );
      expect(_eval(_food(), const []).passed, isFalse);
    });

    test('data after the as-of date is ignored', () {
      final r = _eval(
        [..._food(), foodEntry('2026-12-15', 99999)],
        [..._weights(), weightReading(80, 12, 15)],
      );
      expect(r.passed, isTrue);
    });

    test('a different, owner-set threshold is respected', () {
      const strict = DataQualityThresholds(
        minDays: 14,
        minLoggedDayShare: 1,
        minVerifiedEnergyShare: 1,
        minWeightDaysPerWeek: 5,
        label: 'test thresholds',
      );
      final r = _eval(
        _food(days: 14),
        _weights(weeks: 2, perWeek: 5),
        t: strict,
      );
      expect(r.passed, isTrue);
      expect(r.thresholdsLabel, 'test thresholds');
      final r2 = _eval(
        _food(days: 14, skip: {2}),
        _weights(weeks: 2, perWeek: 5),
        t: strict,
      );
      expect(r2.of(DataQualityCriterionId.loggedDays).passed, isFalse);
    });

    test('accepted provenances and the weigh-in rule are parameters', () {
      const lenient = DataQualityThresholds(
        minDays: 28,
        minLoggedDayShare: 0.8,
        minVerifiedEnergyShare: 0.9,
        minWeightDaysPerWeek: 3,
        acceptedEnergyProvenances: {
          DataProvenance.verified,
          DataProvenance.userEntered,
          DataProvenance.crowdsourced,
        },
        weightRule: WeightFrequencyRule.averagePerWeek,
      );
      final crowd = _eval(
        _food(provenance: DataProvenance.crowdsourced),
        _weights(),
        t: lenient,
      );
      expect(
        crowd.of(DataQualityCriterionId.verifiedEnergyShare).passed,
        isTrue,
      );
      // 4 + 3 + 3 + 2 weigh-in days: weakest block 2 fails, average 3 passes.
      final uneven = [
        ..._weights(weeks: 3),
        for (final i in [21, 22, 28])
          weightReading(80, _asOf.addDays(-i).month, _asOf.addDays(-i).day),
        weightReading(80, _asOf.addDays(-5).month, _asOf.addDays(-5).day),
      ];
      final weakest = _eval(_food(), uneven);
      final average = _eval(_food(), uneven, t: lenient);
      expect(
        weakest.of(DataQualityCriterionId.weightFrequency).passed,
        isFalse,
      );
      expect(
        average.of(DataQualityCriterionId.weightFrequency).reason,
        contains('on average'),
      );
    });

    test('reasons contain no instruction to the user (GOL-011)', () {
      final r = _eval(_food(days: 3), const []);
      for (final c in r.criteria) {
        expect(
          c.reason,
          isNot(matches(RegExp('should|try|consider|log more'))),
        );
      }
    });
  });
}
