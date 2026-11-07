import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/analytics/goal_progress.dart';
import 'package:repforge/domain/analytics/metric.dart';
import 'package:repforge/domain/analytics/training_analytics.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/personal_records.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';
import 'package:repforge/domain/units/units.dart';

int _n = 0;

SessionSet _set(
  String sessionId,
  SetData data, {
  String exercise = 'bench',
  bool completed = true,
  SetKind kind = SetKind.working,
}) => SessionSet(
  id: 's${_n++}',
  sessionId: sessionId,
  exerciseId: exercise,
  exerciseOrder: 0,
  setOrder: _n,
  data: data,
  completed: completed,
  kind: kind,
);

SetData _w(double kg, int reps) =>
    SetData.weighted(load: LoadKg.fromStored(kg), reps: reps);

WorkoutSession _session(
  DateTime start,
  List<SetData> sets, {
  bool ended = true,
  String exercise = 'bench',
  String? id,
}) {
  final sid = id ?? 'w${_n++}';
  return WorkoutSession(
    id: sid,
    name: 'Session',
    startedAt: start.toUtc(),
    endedAt: ended ? start.add(const Duration(hours: 1)).toUtc() : null,
    createdAt: start.toUtc(),
    updatedAt: start.toUtc(),
    sets: [for (final d in sets) _set(sid, d, exercise: exercise)],
  );
}

final _week = AnalyticsPeriod.thisWeek(DateTime(2026, 11, 4, 12), 1);
const _settings = AppSettings();

ExerciseSessionHistory _hist(
  DateTime start,
  List<SessionSet> sets, {
  String? id,
}) => ExerciseSessionHistory(
  sessionId: id ?? 'h${_n++}',
  sessionName: 'S',
  startedAt: start.toUtc(),
  sets: sets,
);

void main() {
  group('WeekTraining volume (TRN-027)', () {
    test('80 x 5 plus 80 x 4 gives 720 kg', () {
      final w = WeekTraining.build(
        period: _week,
        sessions: [
          _session(DateTime(2026, 11, 3, 18), [_w(80, 5), _w(80, 4)]),
        ],
        settings: _settings,
      );
      expect(w.volume.loadKg, 720);
      expect(w.workingSets, 2);
      expect((w.totalVolumeKg as MetricValue<double>).value, 720);
      expect(w.byExercise['bench']!.loadKg, 720);
    });

    test('warm-up and uncompleted sets are excluded', () {
      final session = WorkoutSession(
        id: 'x',
        name: 'x',
        startedAt: DateTime(2026, 11, 3, 18).toUtc(),
        endedAt: DateTime(2026, 11, 3, 19).toUtc(),
        createdAt: DateTime(2026, 11, 3).toUtc(),
        updatedAt: DateTime(2026, 11, 3).toUtc(),
        sets: [
          _set('x', _w(40, 10), kind: SetKind.warmUp),
          _set('x', _w(100, 5), completed: false),
          _set('x', _w(80, 5)),
          _set('x', _w(80, 4), kind: SetKind.failure),
        ],
      );
      final w = WeekTraining.build(
        period: _week,
        sessions: [session],
        settings: _settings,
      );
      expect(w.volume.loadKg, 720);
      expect(w.workingSets, 2);
    });

    test('bodyweight and timed sets keep their own measures, not kg', () {
      final w = WeekTraining.build(
        period: _week,
        sessions: [
          _session(DateTime(2026, 11, 3, 18), [
            const SetData.bodyweight(reps: 12),
            const SetData.timed(duration: Duration(seconds: 45)),
          ], exercise: 'mix'),
        ],
        settings: _settings,
      );
      expect(w.volume.reps, 12);
      expect(w.volume.seconds, 45);
      expect(w.volume.loadKg, 0);
      expect(w.workingSets, 2);
      final m = w.totalVolumeKg;
      expect(m, isA<NotEnoughData<double>>());
    });

    test('an empty week has no volume figure instead of 0', () {
      final w = WeekTraining.build(
        period: _week,
        sessions: const [],
        settings: _settings,
      );
      expect(w.sessionsCompleted, 0);
      expect(w.totalVolumeKg, isA<NotEnoughData<double>>());
      expect(w.activeDays, isEmpty);
    });

    test('sessions outside the period are ignored', () {
      final w = WeekTraining.build(
        period: _week,
        sessions: [
          _session(DateTime(2026, 11, 1, 18), [_w(100, 10)]),
          _session(DateTime(2026, 11, 9, 8), [_w(100, 10)]),
          _session(DateTime(2026, 11, 8, 23), [_w(50, 2)]),
        ],
        settings: _settings,
      );
      expect(w.sessionsCompleted, 1);
      expect(w.volume.loadKg, 100);
    });

    test(
      'the day start hour moves a late-night session into the day before',
      () {
        final session = _session(DateTime(2026, 11, 9, 2, 30), [_w(60, 5)]);
        final monday = AnalyticsPeriod.thisWeek(DateTime(2026, 11, 10, 12), 1);
        expect(
          WeekTraining.build(
            period: monday,
            sessions: [session],
            settings: _settings,
          ).sessionsCompleted,
          1,
        );
        final late = WeekTraining.build(
          period: monday,
          sessions: [session],
          settings: _settings.copyWith(dayStartHour: 4),
        );
        expect(late.sessionsCompleted, 0);
        expect(late.dayRule, 'Days start at 04:00');
        final before = WeekTraining.build(
          period: monday.previous,
          sessions: [session],
          settings: _settings.copyWith(dayStartHour: 4),
        );
        expect(before.sessionsCompleted, 1);
        expect(before.activeDays, [CalendarDate(2026, 11, 8)]);
      },
    );
  });

  group('sessions completed and active days', () {
    final sessions = [
      _session(DateTime(2026, 11, 2, 18), [_w(80, 5)]),
      _session(DateTime(2026, 11, 2, 20), [_w(80, 5)]),
      _session(DateTime(2026, 11, 4, 18), [_w(80, 5)]),
      _session(DateTime(2026, 11, 5, 18), [_w(80, 5)], ended: false),
    ];

    test('only sessions with an end time are completed', () {
      final w = WeekTraining.build(
        period: _week,
        sessions: sessions,
        settings: _settings,
      );
      expect(w.sessionsCompleted, 3);
      expect(w.sessionsInProgress, 1);
      expect(w.activeDays, [
        CalendarDate(2026, 11, 2),
        CalendarDate(2026, 11, 4),
      ]);
    });

    test('"2 of 3 sessions" after two completed sessions (GOL-005)', () {
      final goal = Goal(
        id: 'g',
        kind: GoalKind.sessionsPerWeek,
        target: 3,
        startDate: DateTime(2026, 10).toUtc(),
        createdAt: DateTime(2026, 10).toUtc(),
        updatedAt: DateTime(2026, 10).toUtc(),
      );
      final w = WeekTraining.build(
        period: _week,
        sessions: [sessions[0], sessions[2], sessions[3]],
        settings: _settings,
      );
      final p = GoalProgress.sessionsPerWeek(goal: goal, week: w);
      expect(p.statement, '2 of 3 sessions');
      expect((p.current as MetricValue<double>).value, 2);
      expect(p.state, GoalState.inProgress);
      expect(p.remaining, 1);
      expect(p.percent, 66.7);
      expect(p.drillDown.kind, DrillDownKind.sessions);
      expect(p.drillDown.from, _week.from);
      expect((p.current as MetricValue<double>).basis.period, _week);
    });

    test('goal met and passed, and zero sessions read "0 of 3"', () {
      final goal = Goal(
        id: 'g',
        kind: GoalKind.sessionsPerWeek,
        target: 3,
        startDate: DateTime(2026, 10).toUtc(),
        createdAt: DateTime(2026, 10).toUtc(),
        updatedAt: DateTime(2026, 10).toUtc(),
      );
      GoalProgress at(List<WorkoutSession> s) => GoalProgress.sessionsPerWeek(
        goal: goal,
        week: WeekTraining.build(
          period: _week,
          sessions: s,
          settings: _settings,
        ),
      );
      expect(at(sessions.take(3).toList()).state, GoalState.atTarget);
      expect(at(sessions.take(3).toList()).statement, '3 of 3 sessions');
      final none = at(const []);
      expect(none.statement, '0 of 3 sessions');
      expect(none.percent, 0);
    });
  });

  group('ExerciseProgress (TRN-028)', () {
    List<SessionSet> sets(List<SetData> d) => [for (final x in d) _set('h', x)];

    test('top-set weight and volume per session, oldest first', () {
      final p = ExerciseProgress.build([
        _hist(DateTime(2026, 11, 5), sets([_w(82.5, 5), _w(80, 5)])),
        _hist(DateTime(2026, 11, 2), sets([_w(80, 5), _w(80, 4)])),
      ]);
      expect(p.points.map((x) => x.topSetWeightKg), [80, 82.5]);
      expect(p.points.map((x) => x.volumeKg), [720, 82.5 * 5 + 400]);
      expect(p.points.first.date, CalendarDate(2026, 11, 2));
      expect(p.latest!.sessionId, p.points.last.sessionId);
    });

    test('first session, then increased, level and decreased', () {
      final p = ExerciseProgress.build([
        _hist(DateTime(2026, 11, 2), sets([_w(80, 5)])),
        _hist(DateTime(2026, 11, 4), sets([_w(82.5, 5)])),
        _hist(DateTime(2026, 11, 6), sets([_w(82.5, 5)])),
        _hist(DateTime(2026, 11, 8), sets([_w(80, 5)])),
      ]);
      expect(p.points.map((x) => x.topSetStatement), [
        TrendStatement.firstSession,
        TrendStatement.increased,
        TrendStatement.level,
        TrendStatement.decreased,
      ]);
      expect(p.points.map((x) => x.volumeStatement), [
        TrendStatement.firstSession,
        TrendStatement.increased,
        TrendStatement.level,
        TrendStatement.decreased,
      ]);
      expect(p.points.map((x) => x.topSetStatement!.label), [
        'first session',
        'increased',
        'level',
        'decreased',
      ]);
    });

    test('measures are compared independently', () {
      final p = ExerciseProgress.build([
        _hist(DateTime(2026, 11, 2), sets([_w(100, 5)])),
        // Same top set, less volume.
        _hist(DateTime(2026, 11, 4), sets([_w(100, 3)])),
      ]);
      expect(p.points.last.topSetStatement, TrendStatement.level);
      expect(p.points.last.volumeStatement, TrendStatement.decreased);
    });

    test('warm-up only sessions and uncompleted sets give no point', () {
      final warm = _set('h', _w(40, 10), kind: SetKind.warmUp);
      final notDone = _set('h', _w(200, 1), completed: false);
      final p = ExerciseProgress.build([
        _hist(DateTime(2026, 11, 2), [warm, notDone]),
        _hist(DateTime(2026, 11, 4), [warm, _set('h', _w(60, 8))]),
      ]);
      expect(p.points, hasLength(1));
      expect(p.points.single.topSetWeightKg, 60);
      expect(p.points.single.topSetStatement, TrendStatement.firstSession);
    });

    test('a bodyweight exercise has points without a top-set weight', () {
      final p = ExerciseProgress.build([
        _hist(
          DateTime(2026, 11, 2),
          sets([const SetData.bodyweight(reps: 10)]),
        ),
      ]);
      expect(p.points.single.topSetWeightKg, isNull);
      expect(p.points.single.volumeKg, isNull);
      expect(p.points.single.topSetStatement, isNull);
      expect(p.points.single.totals.reps, 10);
    });

    test('no sessions, no points', () {
      final p = ExerciseProgress.build(const []);
      expect(p.isEmpty, isTrue);
      expect(p.latest, isNull);
    });

    test('statement vocabulary is fixed and descriptive (GOL-011)', () {
      expect(TrendStatement.values.map((s) => s.label), [
        'increased',
        'level',
        'decreased',
        'first session',
      ]);
    });
  });

  group('record events (TRN-026)', () {
    PerformedSet perf(
      String id,
      DateTime start,
      SetData data, {
      SetKind kind = SetKind.working,
      String exercise = 'bench',
    }) => PerformedSet(
      sessionId: 'sess-$id',
      startedAt: start.toUtc(),
      set: SessionSet(
        id: id,
        sessionId: 'sess-$id',
        exerciseId: exercise,
        exerciseOrder: 0,
        setOrder: 0,
        data: data,
        completed: true,
        kind: kind,
      ),
    );

    test('lists the records set in the period against earlier history', () {
      final history = [
        perf('old', DateTime(2026, 10, 20, 18), _w(80, 5)),
        perf('same', DateTime(2026, 11, 3, 18), _w(80, 5)), // tie: no record
        perf('pr', DateTime(2026, 11, 4, 18), _w(82.5, 5)),
        perf('light', DateTime(2026, 11, 5, 18), _w(70, 5)),
        perf(
          'warm',
          DateTime(2026, 11, 5, 18),
          _w(200, 5),
          kind: SetKind.warmUp,
        ),
        perf('later', DateTime(2026, 11, 20, 18), _w(90, 5)),
      ];
      final events = recordEventsIn(history, dayStartHour: 0, period: _week);
      expect(events.map((e) => e.setId), ['pr']);
      expect(events.single.value, 82.5);
      expect(events.single.key, const PrKey(PrMeasure.heaviestAtReps, 5));
      expect(events.single.date, CalendarDate(2026, 11, 4));
      expect(recordEventsIn(history, dayStartHour: 0).map((e) => e.setId), [
        'old',
        'pr',
        'later',
      ]);
    });

    test(
      'exercises are judged separately and assisted sets have no record',
      () {
        final history = [
          perf('a', DateTime(2026, 11, 3), _w(100, 5)),
          perf('b', DateTime(2026, 11, 4), _w(60, 5), exercise: 'row'),
          perf(
            'c',
            DateTime(2026, 11, 4),
            SetData.assisted(reps: 8, assistance: LoadKg.fromStored(20)),
            exercise: 'pullup',
          ),
        ];
        final events = recordEventsIn(history, dayStartHour: 0, period: _week);
        expect(events.map((e) => e.setId), ['a', 'b']);
        expect(events.map((e) => e.exerciseId), ['bench', 'row']);
      },
    );
  });
}
