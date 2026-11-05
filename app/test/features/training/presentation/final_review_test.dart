import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/settings/application/save_settings.dart';
import 'package:repforge/features/settings/presentation/settings_screen.dart';
import 'package:repforge/features/training/application/session_view.dart';
import 'package:repforge/ui/theme.dart';

import '../../../helpers/pump.dart';
import '../../../helpers/session_harness.dart';

WorkoutPlan _plan(DateTime at) => WorkoutPlan(
  id: 'plan',
  name: 'Leg day plan',
  createdAt: at.toUtc(),
  updatedAt: at.toUtc(),
  exercises: [
    PlanExercise(
      id: 'pe0',
      exerciseId: 'squat',
      sortOrder: 0,
      targetSets: 3,
      repsMin: 8,
      repsMax: 10,
      targetLoad: kg(60),
      restSeconds: 60,
    ),
  ],
);

/// Regression tests for the WP 9 final review (M2, M3, L4, L10, L12, L7).
void main() {
  late SessionHarness h;
  setUp(() async {
    h = SessionHarness();
    await h.seedExercises();
  });
  tearDown(() => h.db.close());

  Future<String> startFromPlan(WidgetTester tester) async {
    await h.plans.upsert(_plan(h.now));
    await h.open(tester, location: RfRoutes.trainPlans);
    await h.tap(tester, 'plan-start-plan');
    return (await h.latest()).exercises.single.id;
  }

  bool chipSelected(WidgetTester tester, String key) =>
      tester.widget<ChoiceChip>(find.byKey(Key(key))).selected;

  group('M3: warm-ups are matched with warm-ups', () {
    testWidgets('previous [warm-up 40x10, 100x5, 100x5]: first row is the '
        'warm-up, then working 100x5', (tester) async {
      final past = pastSession(
        'past',
        started: DateTime(2026, 11, 3, 9),
        sets: [
          (exerciseId: 'squat', kg: 40, reps: 10),
          (exerciseId: 'squat', kg: 100, reps: 5),
          (exerciseId: 'squat', kg: 100, reps: 5),
        ],
      );
      await h.seed(
        past.copyWith(
          sets: [
            for (final s in past.sets)
              s.copyWith(
                kind: s.setOrder == 0 ? SetKind.warmUp : SetKind.working,
              ),
          ],
        ),
      );
      final id = await startFromPlan(tester);
      expect(h.fieldText(tester, 'newset-$id-load'), '40');
      expect(h.fieldText(tester, 'newset-$id-reps'), '10');
      expect(h.textOf(tester, 'prev-hint-$id'), 'Last: 40 kg × 10 (warm-up)');
      await h.tap(tester, 'newset-details-$id');
      expect(chipSelected(tester, 'newset-$id-kind-warmUp'), isTrue);

      await h.tap(tester, 'newset-log-$id');
      final logged = (await h.latest()).sets.single;
      expect(logged.kind, SetKind.warmUp);

      // The next row is working 100 x 5, not the warm-up again.
      expect(h.fieldText(tester, 'newset-$id-load'), '100');
      expect(h.fieldText(tester, 'newset-$id-reps'), '5');
      expect(h.textOf(tester, 'prev-hint-$id'), 'Last: 100 kg × 5');
      await h.tap(tester, 'newset-details-$id');
      expect(chipSelected(tester, 'newset-$id-kind-working'), isTrue);
      await unmount(tester);
    });
  });

  group('N1: a warm-up row is visible and yields to typed values', () {
    Future<String> seedWarmUpPrevious(WidgetTester tester) async {
      final past = pastSession(
        'past',
        started: DateTime(2026, 11, 3, 9),
        sets: [
          (exerciseId: 'squat', kg: 40, reps: 10),
          (exerciseId: 'squat', kg: 100, reps: 5),
        ],
      );
      await h.seed(
        past.copyWith(
          sets: [
            for (final s in past.sets)
              s.copyWith(
                kind: s.setOrder == 0 ? SetKind.warmUp : SetKind.working,
              ),
          ],
        ),
      );
      return await startFromPlan(tester);
    }

    String buttonLabel(WidgetTester tester, String id) => tester
        .widget<Text>(
          find.descendant(
            of: find.byKey(Key('newset-log-$id')),
            matching: find.byType(Text),
          ),
        )
        .data!;

    testWidgets('the collapsed row shows the kind and the hint says '
        'warm-up', (tester) async {
      final id = await seedWarmUpPrevious(tester);
      expect(find.byKey(Key('newset-kind-label-$id')), findsOneWidget);
      expect(find.text('Warm-up'), findsOneWidget);
      expect(buttonLabel(tester, id), 'Log warm-up');
      expect(h.textOf(tester, 'prev-hint-$id'), 'Last: 40 kg × 10 (warm-up)');
      // Untouched, it logs a warm-up.
      await h.tap(tester, 'newset-log-$id');
      expect((await h.latest()).sets.single.kind, SetKind.warmUp);
      // The next row is a plain working row: no label.
      expect(find.byKey(Key('newset-kind-label-$id')), findsNothing);
      expect(buttonLabel(tester, id), 'Log set');
      await unmount(tester);
    });

    testWidgets('typing over a warm-up row switches it to working and logs '
        'a working set', (tester) async {
      final id = await seedWarmUpPrevious(tester);
      await h.enter(tester, 'newset-$id-load', '100');
      await h.enter(tester, 'newset-$id-reps', '5');
      await tester.pump();
      expect(find.byKey(Key('newset-kind-label-$id')), findsNothing);
      expect(buttonLabel(tester, id), 'Log set');
      await h.tap(tester, 'newset-log-$id');
      final stored = (await h.latest()).sets.single;
      expect((stored.kind, stored.data), (SetKind.working, weighted(100, 5)));
      await unmount(tester);
    });

    testWidgets('an explicit warm-up choice still logs a warm-up after '
        'typing', (tester) async {
      final id = await seedWarmUpPrevious(tester);
      await h.enter(tester, 'newset-$id-load', '60');
      await h.tap(tester, 'newset-details-$id');
      await h.tap(tester, 'newset-$id-kind-working');
      await h.tap(tester, 'newset-$id-kind-warmUp');
      expect(buttonLabel(tester, id), 'Log warm-up');
      await h.enter(tester, 'newset-$id-reps', '8');
      await tester.pump();
      expect(buttonLabel(tester, id), 'Log warm-up');
      await h.tap(tester, 'newset-log-$id');
      final stored = (await h.latest()).sets.single;
      expect((stored.kind, stored.data), (SetKind.warmUp, weighted(60, 8)));
      await unmount(tester);
    });
  });

  group('M2: the rest-over cue', () {
    testWidgets('the panel emphasises "Rest over", is a live region and '
        'announces it once', (tester) async {
      final announced = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (
            message,
          ) async {
            final map = message as Map<Object?, Object?>;
            if (map['type'] == 'announce') {
              announced.add(
                (map['data']! as Map<Object?, Object?>)['message']! as String,
              );
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockDecodedMessageHandler<dynamic>(
              SystemChannels.accessibility,
              null,
            ),
      );
      final semantics = tester.ensureSemantics();
      final id = await startFromPlan(tester);
      await h.tap(tester, 'newset-log-$id');
      expect(find.byKey(const Key('rest-over-icon')), findsNothing);
      expect(announced, isEmpty);

      h.clock.advance(const Duration(seconds: 61));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(h.textOf(tester, 'rest-remaining'), 'Rest over');
      expect(find.byKey(const Key('rest-over-icon')), findsOneWidget);
      expect(announced, ['Rest over']);
      expect(
        tester
            .getSemantics(find.byKey(const Key('rest-timer-panel')))
            .getSemanticsData()
            .flagsCollection
            .isLiveRegion,
        isTrue,
      );
      await tester.pump(const Duration(seconds: 6));
      expect(announced, hasLength(1));
      semantics.dispose();
      await unmount(tester);
    });

    testWidgets('"ended ... ago" keeps ticking while the rest is over (L4)', (
      tester,
    ) async {
      final id = await startFromPlan(tester);
      await h.tap(tester, 'newset-log-$id');
      h.clock.advance(const Duration(seconds: 62));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      final first = h.textOf(tester, 'rest-over-for');
      expect(first, startsWith('ended 0:0'));
      h.clock.advance(const Duration(seconds: 20));
      await tester.pump(const Duration(seconds: 5));
      final later = h.textOf(tester, 'rest-over-for');
      expect(later, isNot(first));
      expect(later, matches(RegExp(r'ended 0:2\d ago')));
      await unmount(tester);
    });
  });

  group('L10: starting a workout', () {
    testWidgets('a double tap starts one session', (tester) async {
      await h.plans.upsert(_plan(h.now));
      await h.open(tester, location: RfRoutes.trainPlans);
      final start = find.byKey(const Key('plan-start-plan'));
      await tester.tap(start);
      await tester.tap(start, warnIfMissed: false);
      await h.settle(tester);
      expect(await h.sessions.watchAll().first, hasLength(1));
      await unmount(tester);
    });

    testWidgets('an unfinished workout: continue opens it', (tester) async {
      await h.plans.upsert(_plan(h.now));
      await h.sessions.upsert(
        WorkoutSession(
          id: 'open',
          name: 'Open one',
          startedAt: h.now.toUtc(),
          createdAt: h.now.toUtc(),
          updatedAt: h.now.toUtc(),
        ),
      );
      await h.open(tester, location: RfRoutes.trainPlans);
      await h.tap(tester, 'plan-start-plan');
      expect(find.byKey(const Key('unfinished-dialog')), findsOneWidget);
      expect(find.textContaining('Continue current workout'), findsOneWidget);
      await h.tap(tester, 'unfinished-continue');
      expect(await h.sessions.watchAll().first, hasLength(1));
      expect(find.byKey(const Key('finish-session')), findsOneWidget);
      await unmount(tester);
    });

    testWidgets('an unfinished workout: start new creates a second', (
      tester,
    ) async {
      await h.plans.upsert(_plan(h.now));
      await h.sessions.upsert(
        WorkoutSession(
          id: 'open',
          name: 'Open one',
          startedAt: h.now.toUtc(),
          createdAt: h.now.toUtc(),
          updatedAt: h.now.toUtc(),
        ),
      );
      await h.open(tester, location: RfRoutes.trainPlans);
      await h.tap(tester, 'plan-start-plan');
      await h.tap(tester, 'unfinished-new');
      expect(await h.sessions.watchAll().first, hasLength(2));
      await unmount(tester);
    });

    testWidgets('correcting a finished session starts no rest timer', (
      tester,
    ) async {
      await h.setSettings(
        (await h.settings.read()).copyWith(restTimerNotifications: true),
      );
      final id = await startFromPlan(tester);
      await h.enter(tester, 'newset-$id-load', '80');
      await h.tap(tester, 'newset-log-$id');
      await h.tap(tester, 'finish-session');
      await h.tap(tester, 'detail-edit-sets');
      expect(find.byKey(const Key('rest-timer-panel')), findsNothing);
      await h.enter(tester, 'newset-$id-load', '82.5');
      await h.tap(tester, 'newset-log-$id');
      expect((await h.latest()).sets, hasLength(2));
      expect(find.byKey(const Key('rest-timer-panel')), findsNothing);
      expect(h.scheduler.of('schedule'), isEmpty);
      await unmount(tester);
    });
  });

  testWidgets('N2: the unfinished-workout lookup goes through its use case', (
    tester,
  ) async {
    // The use case reads another database that holds an unfinished session;
    // the screen's own database has none.
    final other = AppDatabase.inMemory();
    addTearDown(other.close);
    final otherSessions = DriftWorkoutSessionRepository(
      other,
      clock: FixedClock(h.now),
    );
    await otherSessions.upsert(
      WorkoutSession(
        id: 'open',
        name: 'Open one',
        startedAt: h.now.toUtc(),
        createdAt: h.now.toUtc(),
        updatedAt: h.now.toUtc(),
      ),
    );
    await h.plans.upsert(_plan(h.now));
    h.extraOverrides = [
      findUnfinishedSessionProvider.overrideWithValue(
        FindUnfinishedSession(sessions: otherSessions),
      ),
    ];
    await h.open(tester, location: RfRoutes.trainPlans);
    await h.tap(tester, 'plan-start-plan');
    expect(find.byKey(const Key('unfinished-dialog')), findsOneWidget);
    await unmount(tester);
  });

  test('L12: correcting an old session hints with what came before it, '
      'however many newer sessions exist', () async {
    final sessions = h.sessions;
    for (var i = 0; i < 6; i++) {
      await h.seed(
        pastSession(
          's$i',
          started: DateTime(2026, 11, 1 + i, 9),
          sets: [(exerciseId: 'squat', kg: 70 + i * 5, reps: 5)],
        ),
      );
    }
    await sessions.addExercise(
      const SessionExercise(
        id: 'entry-s1',
        sessionId: 's1',
        exerciseId: 'squat',
        position: 0,
      ),
    );
    final view = await LoadSessionView(
      sessions: sessions,
      exercises: h.exercises,
      plans: h.plans,
    )('s1');
    final prefill = (view as Ok<SessionView?>).value!.prefill['entry-s1']!;
    expect(prefill.previous.map((s) => s.sessionId).toSet(), {'s0'});
  });

  testWidgets('L7: the settings screen saves through the use case, not the '
      'repository', (tester) async {
    final other = AppDatabase.inMemory();
    addTearDown(other.close);
    final viaUseCase = DriftSettingsRepository(other, clock: FixedClock(h.now));
    tester.view.physicalSize = const Size(600, 3600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(h.db),
          clockProvider.overrideWithValue(FixedClock(h.now)),
          updateSettingsProvider.overrideWithValue(
            UpdateSettings(repository: viaUseCase),
          ),
        ],
        child: MaterialApp(
          theme: rfTheme(Brightness.dark),
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('units-choice')));
    await tester.tap(
      find.descendant(
        of: find.byKey(const Key('units-choice')),
        matching: find.text('Imperial'),
      ),
    );
    await tester.pumpAndSettle();
    expect((await viaUseCase.read()).units.name, 'imperial');
    await unmount(tester);
  });
}
