import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/volume.dart';
import 'package:repforge/domain/units/units.dart';

LoadKg _kg(double v) => LoadKg.fromStored(v);

SessionSet _s(
  SetData data, {
  String id = 's',
  String exerciseId = 'bench',
  SetKind kind = SetKind.working,
  bool completed = true,
}) => SessionSet(
  id: id,
  sessionId: 'x',
  exerciseId: exerciseId,
  exerciseOrder: 0,
  setOrder: 0,
  data: data,
  completed: completed,
  kind: kind,
);

SetData _w(double kg, int reps) => SetData.weighted(load: _kg(kg), reps: reps);

Exercise _ex(
  String id,
  MuscleGroup primary, [
  List<MuscleGroup> secondary = const [],
]) => Exercise(
  id: id,
  name: id,
  type: ExerciseType.weighted,
  category: ExerciseCategory.push,
  primaryMuscle: primary,
  secondaryMuscles: secondary,
  createdAt: DateTime.utc(2026),
  updatedAt: DateTime.utc(2026),
);

WorkoutSession _session(String id, DateTime at, List<SessionSet> sets) =>
    WorkoutSession(
      id: id,
      name: id,
      startedAt: at,
      createdAt: at,
      updatedAt: at,
      sets: sets,
    );

void main() {
  test('TRN-027(1): 80 x 5 and 80 x 4 give 720 kg', () {
    final v = VolumeRules.total([_s(_w(80, 5)), _s(_w(80, 4))]);
    expect(v.loadKg, 720);
    expect(v.sets, 2);
  });

  test('warm-up sets and sets not completed are excluded', () {
    final v = VolumeRules.total([
      _s(_w(100, 5), kind: SetKind.warmUp),
      _s(_w(80, 5), completed: false),
      _s(_w(80, 5)),
      _s(_w(70, 5), kind: SetKind.failure),
    ]);
    expect(v.loadKg, 400 + 350);
    expect(v.sets, 2);
  });

  test('TRN-027(2): other types report their own measures, never kg', () {
    final v = VolumeRules.total([
      _s(SetData.bodyweight(reps: 10, addedLoad: _kg(20))),
      _s(SetData.assisted(reps: 6, assistance: _kg(25))),
      _s(const SetData.timed(duration: Duration(seconds: 45))),
      _s(const SetData.distance(metres: 400)),
      _s(const SetData.cardio(duration: Duration(minutes: 10), metres: 2000)),
      _s(const SetData.cardio(duration: Duration(minutes: 5))),
    ]);
    expect(v.loadKg, 0, reason: 'added load is not kg volume');
    expect(v.reps, 16);
    expect(v.seconds, 45 + 600 + 300);
    expect(v.metres, 2400);
    expect(v.sets, 6);
  });

  test('per exercise and per session', () {
    final session = _session('a', DateTime.utc(2026, 11, 2), [
      _s(_w(80, 5)),
      _s(_w(80, 4)),
      _s(_w(60, 10), exerciseId: 'fly'),
    ]);
    expect(VolumeRules.byExercise(session.sets), {
      'bench': const VolumeTotals(loadKg: 720, sets: 2),
      'fly': const VolumeTotals(loadKg: 600, sets: 1),
    });
    expect(VolumeRules.ofSession(session).loadKg, 1320);
  });

  group('muscle groups (TRN-027(3))', () {
    final exercises = {
      'bench': _ex('bench', MuscleGroup.chest, [
        MuscleGroup.triceps,
        MuscleGroup.frontDelts,
      ]),
      'dip': _ex('dip', MuscleGroup.triceps),
    };

    test('primary in full, secondary reported separately and not added', () {
      final m = VolumeRules.byMuscle([
        _s(_w(80, 5)),
        _s(_w(40, 10), exerciseId: 'dip'),
      ], exercises);
      expect(m[MuscleGroup.chest]!.primary.loadKg, 400);
      expect(m[MuscleGroup.chest]!.secondary.loadKg, 0);
      expect(m[MuscleGroup.triceps]!.primary.loadKg, 400);
      expect(m[MuscleGroup.triceps]!.secondary.loadKg, 400);
      expect(m[MuscleGroup.frontDelts]!.primary.sets, 0);
      expect(m[MuscleGroup.frontDelts]!.secondary.loadKg, 400);
    });

    test('warm-ups add nothing; an unknown exercise is not attributed', () {
      final m = VolumeRules.byMuscle([
        _s(_w(80, 5), kind: SetKind.warmUp),
        _s(_w(80, 5), exerciseId: 'gone'),
      ], exercises);
      expect(m, isEmpty);
    });
  });

  group('weeks (TRN-027(3), OQ-18 settings)', () {
    DateTime d(int day, [int hour = 12]) => DateTime(2026, 11, day, hour);

    test('weeks run Monday to Sunday by default', () {
      // 2026-11-02 is a Monday, 2026-11-08 a Sunday, 2026-11-09 a Monday.
      expect(VolumeRules.weekStart(d(2)), DateTime(2026, 11, 2));
      expect(VolumeRules.weekStart(d(8)), DateTime(2026, 11, 2));
      expect(VolumeRules.weekStart(d(9)), DateTime(2026, 11, 9));
    });

    test('the week start day setting moves the boundary', () {
      // Sunday start: Sunday 8 Nov starts a new week.
      expect(
        VolumeRules.weekStart(d(8), weekStartDay: 7),
        DateTime(2026, 11, 8),
      );
      expect(VolumeRules.weekStart(d(7), weekStartDay: 7), DateTime(2026, 11));
    });

    test('the day start hour attributes late-night sessions to the previous '
        'day, like the nutrition diary', () {
      // Monday 02:00 with a 04:00 day start belongs to Sunday: last week.
      expect(
        VolumeRules.weekStart(d(9, 2), dayStartHour: 4),
        DateTime(2026, 11, 2),
      );
      expect(
        VolumeRules.weekStart(d(9, 5), dayStartHour: 4),
        DateTime(2026, 11, 9),
      );
      expect(VolumeRules.weekStart(d(9, 2)), DateTime(2026, 11, 9));
    });

    test('byWeek totals per week, exercise and muscle', () {
      final exercises = {'bench': _ex('bench', MuscleGroup.chest)};
      final weeks = VolumeRules.byWeek([
        _session('a', DateTime(2026, 11, 3, 18), [
          _s(_w(80, 5)),
          _s(_w(80, 4)),
        ]),
        _session('b', DateTime(2026, 11, 6, 18), [_s(_w(100, 3))]),
        _session('c', DateTime(2026, 11, 10, 18), [_s(_w(50, 10))]),
      ], exercises);
      expect(weeks.map((w) => w.weekStart), [
        DateTime(2026, 11, 2),
        DateTime(2026, 11, 9),
      ]);
      expect(weeks[0].total.loadKg, 720 + 300);
      expect(weeks[0].byExercise['bench']!.sets, 3);
      expect(weeks[0].byMuscle[MuscleGroup.chest]!.primary.loadKg, 1020);
      expect(weeks[1].total.loadKg, 500);
    });
  });

  test('VolumeTotals equality and zero', () {
    expect(
      VolumeTotals.zero + const VolumeTotals(reps: 3),
      const VolumeTotals(reps: 3),
    );
    expect(
      const VolumeTotals(reps: 3).hashCode,
      const VolumeTotals(reps: 3).hashCode,
    );
    expect(VolumeTotals.zero.toString(), contains('kg: 0'));
  });
}
