import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/training/personal_records.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';

LoadKg _kg(double v) => LoadKg.fromStored(v);

var _n = 0;

PerformedSet _p(
  SetData data, {
  DateTime? at,
  String session = 's',
  int exerciseOrder = 0,
  int setOrder = 0,
  SetKind kind = SetKind.working,
  bool completed = true,
  String? id,
}) {
  final setId = id ?? 'set${_n++}';
  return PerformedSet(
    sessionId: session,
    startedAt: at ?? DateTime.utc(2026, 11),
    set: SessionSet(
      id: setId,
      sessionId: session,
      exerciseId: 'ex',
      exerciseOrder: exerciseOrder,
      setOrder: setOrder,
      data: data,
      completed: completed,
      kind: kind,
    ),
  );
}

SetData _w(double kg, int reps) => SetData.weighted(load: _kg(kg), reps: reps);

void main() {
  group('TRN-026 weighted: heaviest load at each rep count 1 to 12', () {
    test('D04 example: previous best 80 x 5, new 82.5 x 5 is a PR; deleting '
        'it leaves no PR for the new set', () {
      final old = _p(_w(80, 5), at: DateTime.utc(2026, 10), id: 'old');
      final fresh = _p(_w(82.5, 5), at: DateTime.utc(2026, 11), id: 'new');
      expect(
        PersonalRecordRules.isRecordWhenRecorded([old, fresh], 'new'),
        isTrue,
      );
      expect(PersonalRecordRules.recordKeysOfSet([old, fresh], 'new'), [
        const PrKey(PrMeasure.heaviestAtReps, 5),
      ]);
      // Deleted: the history without it. The old set stays the record.
      expect(PersonalRecordRules.recordSetIds([old]), {'old'});
      expect(PersonalRecordRules.isRecordWhenRecorded([old], 'new'), isFalse);
      expect(
        PersonalRecordRules.currentRecords([
          old,
        ])[const PrKey(PrMeasure.heaviestAtReps, 5)]!.value,
        80,
      );
    });

    test('editing the set so it no longer beats the best removes the PR', () {
      final old = _p(_w(80, 5), at: DateTime.utc(2026, 10), id: 'old');
      final edited = _p(_w(77.5, 5), at: DateTime.utc(2026, 11), id: 'new');
      expect(
        PersonalRecordRules.isRecordWhenRecorded([old, edited], 'new'),
        isFalse,
      );
    });

    test('records are per exact rep count: 100 x 3 does not beat 90 x 5', () {
      final five = _p(_w(90, 5), at: DateTime.utc(2026, 10), id: 'five');
      final three = _p(_w(100, 3), at: DateTime.utc(2026, 11), id: 'three');
      expect(PersonalRecordRules.recordSetIds([five, three]), {
        'five',
        'three',
      });
      expect(
        PersonalRecordRules.currentRecords([five, three]).keys,
        unorderedEquals([
          const PrKey(PrMeasure.heaviestAtReps, 5),
          const PrKey(PrMeasure.heaviestAtReps, 3),
        ]),
      );
    });

    test('a tie is not a PR; the earlier set keeps the record', () {
      final a = _p(_w(80, 5), at: DateTime.utc(2026, 10), id: 'a');
      final b = _p(_w(80, 5), at: DateTime.utc(2026, 11), id: 'b');
      expect(PersonalRecordRules.recordSetIds([a, b]), {'a'});
      expect(
        PersonalRecordRules.currentRecords([b, a]).values.single.setId,
        'a',
      );
    });

    test('the first set at a rep count is a PR', () {
      final a = _p(_w(60, 8), id: 'a');
      expect(PersonalRecordRules.recordSetIds([a]), {'a'});
    });

    test('1 to 12 reps count, 13 does not', () {
      final twelve = _p(_w(40, 12), id: 'twelve');
      final thirteen = _p(_w(30, 13), id: 'thirteen');
      expect(PersonalRecordRules.recordSetIds([twelve, thirteen]), {'twelve'});
    });

    test('history order does not depend on the list order: chronological by '
        'session start, then session, exercise order and set order', () {
      final late = _p(_w(85, 5), at: DateTime.utc(2026, 11, 3), id: 'late');
      final early = _p(_w(82.5, 5), at: DateTime.utc(2026, 11), id: 'early');
      final mid = _p(_w(80, 5), at: DateTime.utc(2026, 11, 2), id: 'mid');
      // early is first (record), mid does not beat it, late does.
      expect(PersonalRecordRules.recordSetIds([late, mid, early]), {
        'early',
        'late',
      });
      // Within one session: set order decides which of two equal sets is the
      // record.
      final s1 = _p(_w(90, 3), setOrder: 1, id: 's1');
      final s0 = _p(_w(90, 3), id: 's0');
      expect(PersonalRecordRules.recordSetIds([s1, s0]), {'s0'});
    });
  });

  group('TRN-019 warm-up sets and sets not completed never count', () {
    test('a heavy warm-up is not a PR and does not block a working set', () {
      final warm = _p(_w(200, 5), kind: SetKind.warmUp, id: 'warm');
      final work = _p(_w(80, 5), setOrder: 1, id: 'work');
      expect(PersonalRecordRules.recordSetIds([warm, work]), {'work'});
      expect(PersonalRecordRules.currentRecords([warm]), isEmpty);
    });

    test('failure sets count like working sets', () {
      final fail = _p(_w(80, 5), kind: SetKind.failure, id: 'fail');
      expect(PersonalRecordRules.recordSetIds([fail]), {'fail'});
    });

    test('a set that is not completed is ignored', () {
      final planned = _p(_w(80, 5), completed: false, id: 'planned');
      expect(PersonalRecordRules.recordSetIds([planned]), isEmpty);
    });
  });

  group('other types', () {
    test('timed: longest duration, an added load is ignored', () {
      final a = _p(
        const SetData.timed(duration: Duration(seconds: 60)),
        id: 'a',
      );
      final b = _p(
        SetData.timed(
          duration: const Duration(seconds: 75),
          addedLoad: _kg(10),
        ),
        at: DateTime.utc(2026, 11, 2),
        id: 'b',
      );
      final c = _p(
        const SetData.timed(duration: Duration(seconds: 70)),
        at: DateTime.utc(2026, 11, 3),
        id: 'c',
      );
      expect(PersonalRecordRules.recordSetIds([a, b, c]), {'a', 'b'});
      expect(
        PersonalRecordRules.currentRecords([
          a,
          b,
          c,
        ])[const PrKey(PrMeasure.longestDuration)]!.value,
        75,
      );
    });

    test('distance: longest distance', () {
      final a = _p(const SetData.distance(metres: 400), id: 'a');
      final b = _p(
        const SetData.distance(metres: 800),
        at: DateTime.utc(2026, 11, 2),
        id: 'b',
      );
      final c = _p(
        const SetData.distance(metres: 800),
        at: DateTime.utc(2026, 11, 3),
        id: 'c',
      );
      expect(PersonalRecordRules.recordSetIds([a, b, c]), {'a', 'b'});
    });

    test(
      'bodyweight: most repetitions; added load is ignored (assumption)',
      () {
        final a = _p(const SetData.bodyweight(reps: 10), id: 'a');
        final b = _p(
          SetData.bodyweight(reps: 8, addedLoad: _kg(20)),
          at: DateTime.utc(2026, 11, 2),
          id: 'b',
        );
        final c = _p(
          const SetData.bodyweight(reps: 12),
          at: DateTime.utc(2026, 11, 3),
          id: 'c',
        );
        expect(PersonalRecordRules.recordSetIds([a, b, c]), {'a', 'c'});
      },
    );

    test('assisted and cardio have no PR definition (gap, not invented)', () {
      final assisted = _p(
        SetData.assisted(reps: 8, assistance: _kg(20)),
        id: 'assisted',
      );
      final cardio = _p(
        const SetData.cardio(duration: Duration(minutes: 30), metres: 5000),
        id: 'cardio',
      );
      expect(PersonalRecordRules.recordSetIds([assisted, cardio]), isEmpty);
      expect(PersonalRecordRules.currentRecords([assisted, cardio]), isEmpty);
      expect(PersonalRecordRules.slotOf(assisted.set), isNull);
    });
  });

  test('recordKeysOfSet is empty for an unknown set id', () {
    expect(
      PersonalRecordRules.recordKeysOfSet([_p(_w(80, 5))], 'nope'),
      isEmpty,
    );
  });
}
