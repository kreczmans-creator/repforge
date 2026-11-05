import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/training/rest_timer.dart';

void main() {
  final t0 = DateTime.utc(2026, 11, 5, 10);
  DateTime at(int seconds) => t0.add(Duration(seconds: seconds));

  RestTimer start({int? planned, int fallback = 90}) => RestTimer.start(
    t0,
    defaultRestSeconds: fallback,
    plannedRestSeconds: planned,
  );

  group('start (TRN-021(1))', () {
    test('uses the planned rest', () {
      final t = start(planned: 120);
      expect(t.status, RestTimerStatus.running);
      expect(t.endAt, at(120));
      expect(t.remaining(t0), const Duration(seconds: 120));
    });

    test('falls back to the default (90 s) when nothing is planned', () {
      expect(start().remaining(t0), const Duration(seconds: 90));
      expect(start(fallback: 45).remaining(t0), const Duration(seconds: 45));
    });

    test('an invalid planned rest falls back to the default', () {
      expect(start(planned: -5).remaining(t0), const Duration(seconds: 90));
      expect(start(planned: 4000).remaining(t0), const Duration(seconds: 90));
    });

    test('a planned rest of 0 is valid and done at once', () {
      final t = start(planned: 0);
      expect(t.isDone(t0), isTrue);
    });

    test('a default outside 0 to 3600 is clamped', () {
      expect(
        start(fallback: 9999).remaining(t0),
        const Duration(seconds: 3600),
      );
    });
  });

  group('running on wall-clock time', () {
    test('remaining counts down and is zero once past the end', () {
      final t = start(planned: 60);
      expect(t.remaining(at(20)), const Duration(seconds: 40));
      expect(t.remaining(at(60)), Duration.zero);
      expect(t.remaining(at(500)), Duration.zero);
    });

    test('isDone at the end moment, not before', () {
      final t = start(planned: 60);
      expect(t.isDone(at(59)), isFalse);
      expect(t.isDone(at(60)), isTrue);
      expect(t.isDone(at(600)), isTrue);
    });

    test(
      'a timer left running while the app was away is correct on return',
      () {
        // Same state object read much later: nothing depends on a ticker.
        final t = start(planned: 90);
        expect(t.remaining(at(30)), const Duration(seconds: 60));
        expect(t.isDone(at(95)), isTrue);
      },
    );
  });

  group('pause and resume (TRN-021(2))', () {
    test('pause keeps the remaining time; time passing does not change it', () {
      final paused = start(planned: 60).pause(at(20));
      expect(paused.status, RestTimerStatus.paused);
      expect(paused.endAt, isNull);
      expect(paused.remaining(at(20)), const Duration(seconds: 40));
      expect(paused.remaining(at(500)), const Duration(seconds: 40));
      expect(paused.isDone(at(500)), isFalse);
    });

    test('resume continues from the kept time', () {
      final resumed = start(planned: 60).pause(at(20)).resume(at(100));
      expect(resumed.status, RestTimerStatus.running);
      expect(resumed.endAt, at(140));
      expect(resumed.remaining(at(110)), const Duration(seconds: 30));
    });

    test('pause on a finished timer, resume when not paused: no effect', () {
      final running = start(planned: 60);
      expect(running.pause(at(70)), running);
      expect(running.resume(at(10)), running);
      expect(const RestTimer.idle().pause(t0), const RestTimer.idle());
      expect(const RestTimer.idle().resume(t0), const RestTimer.idle());
    });
  });

  group('extend in 15 s steps', () {
    test('adds 15 s to a running timer', () {
      final t = start(planned: 60).extend(at(10));
      expect(t.remaining(at(10)), const Duration(seconds: 65));
      expect(t.endAt, at(75));
    });

    test('several steps at once', () {
      final t = start(planned: 60).extend(t0, steps: 3);
      expect(t.remaining(t0), const Duration(seconds: 105));
    });

    test('adds to the kept time of a paused timer and stays paused', () {
      final t = start(planned: 60).pause(at(20)).extend(at(30));
      expect(t.status, RestTimerStatus.paused);
      expect(t.remaining(at(99)), const Duration(seconds: 55));
    });

    test('a timer that already reached zero restarts with 15 s from now', () {
      final t = start(planned: 30).extend(at(50));
      expect(t.isDone(at(50)), isFalse);
      expect(t.remaining(at(50)), const Duration(seconds: 15));
    });

    test('never exceeds 3600 s left', () {
      final t = start(planned: 3590).extend(t0);
      expect(t.remaining(t0), const Duration(seconds: 3600));
    });

    test('no effect on an idle timer or for a non-positive step count', () {
      expect(const RestTimer.idle().extend(t0), const RestTimer.idle());
      final t = start(planned: 60);
      expect(t.extend(t0, steps: 0), t);
    });
  });

  test('skip ends the rest: back to idle with nothing remaining', () {
    final skipped = start(planned: 60).skip();
    expect(skipped, const RestTimer.idle());
    expect(skipped.status, RestTimerStatus.idle);
    expect(skipped.remaining(t0), Duration.zero);
    expect(skipped.isDone(at(1000)), isFalse);
    expect(skipped.endAt, isNull);
  });

  test('state is immutable: operations return new values', () {
    final t = start(planned: 60);
    final paused = t.pause(at(10));
    expect(t.status, RestTimerStatus.running);
    expect(paused, isNot(t));
    expect(t.hashCode, start(planned: 60).hashCode);
    expect(t.toString(), contains('running'));
  });
}
