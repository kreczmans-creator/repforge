import 'package:meta/meta.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';

/// The numbers the data-quality check compares against (GOL-012).
///
/// The figures are the OWNER's to set (GOL-012, OQ-15, WP 11 plan decision
/// 10). Nothing in the app reads [proposed] by itself: there is no provider
/// and no screen for this check, and no recommendation feature depends on it
/// (GOL-011).
@immutable
final class DataQualityThresholds {
  const DataQualityThresholds({
    required this.minDays,
    required this.minLoggedDayShare,
    required this.minVerifiedEnergyShare,
    required this.minWeightDaysPerWeek,
    this.label = 'unapproved thresholds',
  });

  /// The figures written in D04 GOL-012: proposed, not approved (OQ-15).
  static const DataQualityThresholds proposed = DataQualityThresholds(
    minDays: 28,
    minLoggedDayShare: 0.8,
    minVerifiedEnergyShare: 0.9,
    minWeightDaysPerWeek: 3,
    label: 'proposed, not approved (OQ-15)',
  );

  /// Days of data required; also the length of the window that is checked.
  final int minDays;

  /// Share of the window's days with food logged, 0 to 1.
  final double minLoggedDayShare;

  /// Share of the window's logged energy that is verified or user-entered,
  /// 0 to 1.
  final double minVerifiedEnergyShare;

  /// Days with a weight reading required in every 7-day block of the
  /// window.
  final int minWeightDaysPerWeek;

  /// Where the figures come from, stated beside any result.
  final String label;
}

/// The four criteria of GOL-012.
enum DataQualityCriterionId {
  dataDays('Days of data'),
  loggedDays('Days with food logged'),
  energyProvenance('Energy verified or user-entered'),
  weightFrequency('Weigh-in days per week');

  DataQualityCriterionId(this.label);
  final String label;
}

/// The result of one criterion (GOL-012(2)): what was observed, what is
/// required, pass or fail, and the reason in plain words.
@immutable
final class CriterionResult {
  const CriterionResult({
    required this.id,
    required this.required,
    required this.passed,
    required this.reason,
    this.observed,
  });

  final DataQualityCriterionId id;

  /// The measured value; null when it could not be measured. A share is a
  /// fraction from 0 to 1; days are whole numbers.
  final double? observed;
  final double required;
  final bool passed;
  final String reason;

  String get label => id.label;
}

/// The computed data-quality check (GOL-012). Pure: it only describes the
/// data. It gives no advice and enables nothing (GOL-011).
@immutable
final class DataQualityReport {
  const DataQualityReport._({
    required this.asOf,
    required this.thresholds,
    required this.criteria,
  });

  /// Evaluates the data of the `thresholds.minDays` days ending on [asOf].
  ///
  /// - Days of data: from the earliest food entry or weight reading to
  ///   [asOf], inclusive.
  /// - Days with food logged: logged days in the window over the window
  ///   length.
  /// - Energy provenance: the share of the window's logged kcal from
  ///   `verified` or `userEntered` entries (`crowdsourced` and `estimated`
  ///   do not count towards it).
  /// - Weigh-ins: the window is cut into 7-day blocks counted back from
  ///   [asOf]; the block with the fewest weigh-in days is the observed
  ///   value (the exact reading of "3 days per week" is for the owner to
  ///   confirm).
  ///
  /// Entries and readings after [asOf] are ignored.
  factory DataQualityReport.evaluate({
    required CalendarDate asOf,
    required Iterable<FoodLogEntry> entries,
    required Iterable<Measurement> weightReadings,
    required DataQualityThresholds thresholds,
  }) {
    final windowDays = thresholds.minDays;
    final windowFrom = asOf.addDays(-(windowDays - 1));
    final foodDays = <CalendarDate, List<FoodLogEntry>>{};
    for (final e in entries) {
      final d = calendarDateFromKey(e.day);
      if (d.isAfter(asOf)) continue;
      (foodDays[d] ??= []).add(e);
    }
    final weightDays = <CalendarDate>{
      for (final m in weightReadings)
        if (m.site == MeasurementSite.weight &&
            !CalendarDate.fromInstant(m.recordedAt).isAfter(asOf))
          CalendarDate.fromInstant(m.recordedAt),
    };

    // 1. Days of data.
    final all = [...foodDays.keys, ...weightDays]..sort();
    final span = all.isEmpty ? 0 : all.first.daysUntil(asOf) + 1;
    final dataDays = CriterionResult(
      id: DataQualityCriterionId.dataDays,
      observed: span.toDouble(),
      required: windowDays.toDouble(),
      passed: span >= windowDays,
      reason: all.isEmpty
          ? 'No food or weight was recorded; $windowDays days are required.'
          : 'Data spans $span ${_days(span)}; at least $windowDays are '
                'required.',
    );

    // 2. Days with food logged.
    final logged = [
      for (var i = 0; i < windowDays; i++)
        if (foodDays.containsKey(windowFrom.addDays(i))) i,
    ].length;
    final loggedShare = windowDays == 0 ? 0.0 : logged / windowDays;
    final loggedDaysResult = CriterionResult(
      id: DataQualityCriterionId.loggedDays,
      observed: loggedShare,
      required: thresholds.minLoggedDayShare,
      passed: loggedShare + 1e-12 >= thresholds.minLoggedDayShare,
      reason:
          'Food was logged on $logged of $windowDays days '
          '(${_pct(loggedShare)}); at least '
          '${_pct(thresholds.minLoggedDayShare)} is required.',
    );

    // 3. Energy provenance.
    var totalKcal = 0.0;
    var strongKcal = 0.0;
    for (var i = 0; i < windowDays; i++) {
      for (final e
          in foodDays[windowFrom.addDays(i)] ?? const <FoodLogEntry>[]) {
        totalKcal += e.nutrients.kcal;
        if (e.provenance == DataProvenance.verified ||
            e.provenance == DataProvenance.userEntered) {
          strongKcal += e.nutrients.kcal;
        }
      }
    }
    final CriterionResult energy;
    if (totalKcal <= 0) {
      energy = CriterionResult(
        id: DataQualityCriterionId.energyProvenance,
        required: thresholds.minVerifiedEnergyShare,
        passed: false,
        reason:
            'No energy was logged in the last $windowDays days; at least '
            '${_pct(thresholds.minVerifiedEnergyShare)} verified or '
            'user-entered is required.',
      );
    } else {
      final share = strongKcal / totalKcal;
      energy = CriterionResult(
        id: DataQualityCriterionId.energyProvenance,
        observed: share,
        required: thresholds.minVerifiedEnergyShare,
        passed: share + 1e-12 >= thresholds.minVerifiedEnergyShare,
        reason:
            '${_pct(share)} of logged energy is verified or user-entered; '
            'at least ${_pct(thresholds.minVerifiedEnergyShare)} is '
            'required.',
      );
    }

    // 4. Weigh-in days per 7-day block.
    final blocks = windowDays < 7 ? 1 : windowDays ~/ 7;
    final blockLength = windowDays < 7 ? windowDays : 7;
    var fewest = blockLength;
    for (var b = 0; b < blocks; b++) {
      final end = asOf.addDays(-b * blockLength);
      var n = 0;
      for (var i = 0; i < blockLength; i++) {
        if (weightDays.contains(end.addDays(-i))) n++;
      }
      if (n < fewest) fewest = n;
    }
    final weight = CriterionResult(
      id: DataQualityCriterionId.weightFrequency,
      observed: fewest.toDouble(),
      required: thresholds.minWeightDaysPerWeek.toDouble(),
      passed: fewest >= thresholds.minWeightDaysPerWeek,
      reason:
          'The $blockLength-day block with the fewest weigh-ins had '
          '$fewest ${_days(fewest)} (of $blocks '
          '${blocks == 1 ? 'block' : 'blocks'} checked); at least '
          '${thresholds.minWeightDaysPerWeek} are required.',
    );

    return DataQualityReport._(
      asOf: asOf,
      thresholds: thresholds,
      criteria: List.unmodifiable([dataDays, loggedDaysResult, energy, weight]),
    );
  }

  static String _days(int n) => n == 1 ? 'day' : 'days';

  static String _pct(double share) => '${(share * 100).toStringAsFixed(0)} %';

  final CalendarDate asOf;
  final DataQualityThresholds thresholds;

  /// One result per criterion, in the order of [DataQualityCriterionId].
  final List<CriterionResult> criteria;

  /// Whether every criterion passed.
  bool get passed => criteria.every((c) => c.passed);

  /// The result of [id].
  CriterionResult of(DataQualityCriterionId id) =>
      criteria.firstWhere((c) => c.id == id);

  /// Where the thresholds come from, to be shown with any result.
  String get thresholdsLabel => thresholds.label;
}
