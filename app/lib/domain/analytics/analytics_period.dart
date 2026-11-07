import 'package:meta/meta.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/measurements/measurement_period.dart';
import 'package:repforge/domain/nutrition/nutrition.dart' show diaryDayKey;

/// What a period is: a week (first day from the week-start setting), a
/// calendar month, or a free range.
enum AnalyticsPeriodKind { week, month, custom }

/// Day rule label of the body measurements: they belong to the local calendar
/// date of the reading and ignore the day-start setting (WP 11 plan decision
/// 7b, WP 10 behaviour unchanged).
const String calendarDayRule = 'Calendar dates (local midnight)';

/// The diary day (calendar date) an instant belongs to under the day-start
/// hour. It is the date of `diaryDayKey`, the one definition of "today" for
/// nutrition and training.
CalendarDate diaryDay(DateTime instant, int dayStartHour) =>
    calendarDateFromKey(diaryDayKey(instant, dayStartHour));

/// Parses a `YYYY-MM-DD` day key.
///
/// Throws [FormatException] for any other text.
CalendarDate calendarDateFromKey(String key) {
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
  if (m == null) throw FormatException('Not a day key', key);
  return CalendarDate(
    int.parse(m.group(1)!),
    int.parse(m.group(2)!),
    int.parse(m.group(3)!),
  );
}

/// The one period type every analytics aggregate is computed over (WP 11
/// plan section 4). [from] and [to] are inclusive calendar dates.
///
/// All arithmetic is on calendar dates ([CalendarDate.addDays]), never on a
/// `Duration` of 24 hours, so a daylight-saving change cannot shift or repeat
/// a day. [dayStartHour] is the day-start setting: nutrition and training
/// attribute an instant to a day with it, body readings do not (see
/// [dayRule] and [calendarDayRule]).
@immutable
final class AnalyticsPeriod {
  /// A period of the given [kind]; [from] must not be after [to].
  AnalyticsPeriod({
    required this.from,
    required this.to,
    required this.kind,
    this.dayStartHour = 0,
  }) : assert(!from.isAfter(to), 'from must not be after to'),
       assert(dayStartHour >= 0 && dayStartHour <= 23, 'dayStartHour 0-23');

  /// A free range.
  AnalyticsPeriod.custom(
    CalendarDate from,
    CalendarDate to, {
    int dayStartHour = 0,
  }) : this(
         from: from,
         to: to,
         kind: AnalyticsPeriodKind.custom,
         dayStartHour: dayStartHour,
       );

  /// The week that contains the diary day of [now]. [weekStartDay] is
  /// 1 (Monday) to 7 (Sunday), as in the settings.
  factory AnalyticsPeriod.thisWeek(
    DateTime now,
    int weekStartDay, {
    int dayStartHour = 0,
  }) {
    final today = diaryDay(now, dayStartHour);
    final back = (_weekday(today) - weekStartDay + 7) % 7;
    final start = today.addDays(-back);
    return AnalyticsPeriod(
      from: start,
      to: start.addDays(6),
      kind: AnalyticsPeriodKind.week,
      dayStartHour: dayStartHour,
    );
  }

  /// The week before `thisWeek`.
  factory AnalyticsPeriod.lastWeek(
    DateTime now,
    int weekStartDay, {
    int dayStartHour = 0,
  }) => AnalyticsPeriod.thisWeek(
    now,
    weekStartDay,
    dayStartHour: dayStartHour,
  ).previous;

  /// The calendar month that contains the diary day of [now].
  factory AnalyticsPeriod.thisMonth(DateTime now, {int dayStartHour = 0}) {
    final today = diaryDay(now, dayStartHour);
    return AnalyticsPeriod._month(today.year, today.month, dayStartHour);
  }

  /// The calendar month before `thisMonth`.
  factory AnalyticsPeriod.lastMonth(DateTime now, {int dayStartHour = 0}) =>
      AnalyticsPeriod.thisMonth(now, dayStartHour: dayStartHour).previous;

  factory AnalyticsPeriod._month(int year, int month, int dayStartHour) {
    final first = CalendarDate(year, month, 1);
    return AnalyticsPeriod(
      from: first,
      to: CalendarDate(year, month + 1, 1).addDays(-1),
      kind: AnalyticsPeriodKind.month,
      dayStartHour: dayStartHour,
    );
  }

  /// First day, inclusive.
  final CalendarDate from;

  /// Last day, inclusive.
  final CalendarDate to;
  final AnalyticsPeriodKind kind;

  /// The day-start setting (0 = local midnight) the nutrition and training
  /// figures of this period use.
  final int dayStartHour;

  static int _weekday(CalendarDate d) =>
      DateTime.utc(d.year, d.month, d.day).weekday;

  static const _months = [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// Number of calendar days in the period.
  int get dayCount => from.daysUntil(to) + 1;

  /// Every date of the period, oldest first.
  List<CalendarDate> get days => [
    for (var i = 0; i < dayCount; i++) from.addDays(i),
  ];

  /// Every diary day key of the period, oldest first.
  List<String> get dayKeys => [for (final d in days) d.iso];

  /// `YYYY-MM-DD` of [from].
  String get fromKey => from.iso;

  /// `YYYY-MM-DD` of [to].
  String get toKey => to.iso;

  /// Whether [day] lies in the period.
  bool containsDay(CalendarDate day) =>
      day.compareTo(from) >= 0 && day.compareTo(to) <= 0;

  /// Whether the diary day key [key] lies in the period.
  bool containsDayKey(String key) => containsDay(calendarDateFromKey(key));

  /// Whether the diary day of [instant] (day-start rule) lies in the period.
  bool containsInstant(DateTime instant) =>
      containsDay(diaryDay(instant, dayStartHour));

  /// The period as a [DateRange] of calendar dates.
  DateRange get dateRange => DateRange(from, to);

  /// The first moment of [from] under the day-start rule (local time).
  DateTime get startInstant =>
      DateTime(from.year, from.month, from.day, dayStartHour);

  /// The first moment after [to] under the day-start rule (local time).
  DateTime get endInstantExclusive =>
      DateTime(to.year, to.month, to.day + 1, dayStartHour);

  /// The local midnight that starts [from]: the bound for body readings.
  DateTime get calendarStartInstant =>
      DateTime(from.year, from.month, from.day);

  /// The local midnight after [to]: the bound for body readings.
  DateTime get calendarEndInstantExclusive =>
      DateTime(to.year, to.month, to.day + 1);

  /// The period of the same kind that ends the day before this one starts: a
  /// week gives the week before, a month the month before, a custom range the
  /// range of equal length before it.
  AnalyticsPeriod get previous => switch (kind) {
    AnalyticsPeriodKind.week => AnalyticsPeriod(
      from: from.addDays(-7),
      to: from.addDays(-1),
      kind: kind,
      dayStartHour: dayStartHour,
    ),
    AnalyticsPeriodKind.month => AnalyticsPeriod._month(
      from.year,
      from.month - 1,
      dayStartHour,
    ),
    AnalyticsPeriodKind.custom => AnalyticsPeriod(
      from: from.addDays(-dayCount),
      to: from.addDays(-1),
      kind: kind,
      dayStartHour: dayStartHour,
    ),
  };

  /// A short name: "Week of 2026-11-02", "November 2026", "2026-11-01 to
  /// 2026-11-09".
  String get label => switch (kind) {
    AnalyticsPeriodKind.week => 'Week of ${from.iso}',
    AnalyticsPeriodKind.month => '${_months[from.month - 1]} ${from.year}',
    AnalyticsPeriodKind.custom => '${from.iso} to ${to.iso}',
  };

  /// The day boundary the nutrition and training figures of this period
  /// use, stated beside them (plan decision 7b).
  String get dayRule => dayRuleFor(dayStartHour);

  /// The label of the day boundary for a day-start setting.
  static String dayRuleFor(int dayStartHour) => dayStartHour == 0
      ? 'Days run from local midnight'
      : 'Days start at ${dayStartHour.toString().padLeft(2, '0')}:00';

  @override
  bool operator ==(Object other) =>
      other is AnalyticsPeriod &&
      other.from == from &&
      other.to == to &&
      other.kind == kind &&
      other.dayStartHour == dayStartHour;

  @override
  int get hashCode => Object.hash(from, to, kind, dayStartHour);

  @override
  String toString() => 'AnalyticsPeriod($label, $from..$to)';
}
