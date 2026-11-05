import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/data/repositories/drift_exercise_repository.dart';
import 'package:repforge/data/repositories/drift_scheduled_workout_repository.dart';
import 'package:repforge/data/repositories/drift_settings_repository.dart';
import 'package:repforge/data/repositories/drift_workout_plan_repository.dart';
import 'package:repforge/data/repositories/drift_workout_session_repository.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/rest_alert.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/rest_timer_controller.dart';

import 'scrolling.dart';
import 'seed_session.dart';

/// A clock the test moves by hand (the rest timer derives from it).
class MutableClock implements Clock {
  MutableClock(this.current);
  DateTime current;

  @override
  DateTime now() => current;

  void advance(Duration d) => current = current.add(d);
}

/// Counts the alerts instead of vibrating.
class FakeRestAlert implements RestAlert {
  int fired = 0;

  @override
  Future<void> fire() async => fired++;
}

LoadKg kg(double v) => LoadKg.fromStored(v);
SetData weighted(double load, int reps) =>
    SetData.weighted(load: kg(load), reps: reps);

Exercise exercise(
  String id,
  String name, {
  required DateTime at,
  ExerciseType type = ExerciseType.weighted,
  bool archived = false,
}) => Exercise(
  id: id,
  name: name,
  type: type,
  category: ExerciseCategory.legs,
  primaryMuscle: MuscleGroup.quadriceps,
  archived: archived,
  createdAt: at.toUtc(),
  updatedAt: at.toUtc(),
);

/// A finished session with the given sets, for the history.
WorkoutSession pastSession(
  String id, {
  required DateTime started,
  String name = 'Leg day',
  String? planId,
  String notes = '',
  List<({String exerciseId, double kg, int reps})> sets = const [],
}) => WorkoutSession(
  id: id,
  name: name,
  planId: planId,
  startedAt: started.toUtc(),
  endedAt: started.add(const Duration(minutes: 50)).toUtc(),
  createdAt: started.toUtc(),
  updatedAt: started.toUtc(),
  notes: notes,
  sets: [
    for (var i = 0; i < sets.length; i++)
      SessionSet(
        id: '$id-s$i',
        sessionId: id,
        exerciseId: sets[i].exerciseId,
        exerciseOrder: 0,
        setOrder: i,
        data: weighted(sets[i].kg, sets[i].reps),
        completed: true,
      ),
  ],
);

/// Database, repositories, injected clock and fakes for the session widget
/// tests. [tap] counts the taps a flow takes.
class SessionHarness {
  SessionHarness({DateTime? now}) : now = now ?? DateTime(2026, 11, 5, 9) {
    db = AppDatabase.inMemory();
    clock = MutableClock(this.now);
    final fixed = FixedClock(this.now);
    exercises = DriftExerciseRepository(db, clock: fixed);
    plans = DriftWorkoutPlanRepository(db, clock: fixed);
    sessions = DriftWorkoutSessionRepository(db, clock: fixed);
    scheduled = DriftScheduledWorkoutRepository(db);
    settings = DriftSettingsRepository(db, clock: fixed);
  }

  final DateTime now;
  late final AppDatabase db;
  late final MutableClock clock;
  late final DriftExerciseRepository exercises;
  late final DriftWorkoutPlanRepository plans;
  late final DriftWorkoutSessionRepository sessions;
  late final DriftScheduledWorkoutRepository scheduled;
  late final DriftSettingsRepository settings;
  final alert = FakeRestAlert();
  int gen = 0;
  int taps = 0;

  Future<void> seedExercises() async {
    await exercises.upsert(exercise('squat', 'Back squat', at: now));
    await exercises.upsert(exercise('bench', 'Bench press', at: now));
    await exercises.upsert(
      exercise('plank', 'Plank', type: ExerciseType.timed, at: now),
    );
    await exercises.upsert(
      exercise('old', 'Old press', archived: true, at: now),
    );
  }

  Future<void> seed(WorkoutSession s) => seedSession(sessions, s);

  Future<void> setSettings(AppSettings s) => settings.save(s);

  Future<WorkoutSession> latest() async =>
      (await sessions.watchAll().first).first;

  Future<void> open(
    WidgetTester tester, {
    String location = RfRoutes.train,
    Size size = const Size(390, 12000),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          clockProvider.overrideWithValue(clock),
          idGeneratorProvider.overrideWithValue(() => 'gen-${gen++}'),
          restAlertProvider.overrideWithValue(alert),
        ],
        child: RepForgeApp(router: createRouter(initialLocation: location)),
      ),
    );
    await settle(tester);
  }

  /// Pumps for a bounded time. `pumpAndSettle` cannot be used while the rest
  /// timer runs: its one-second tick keeps scheduling frames.
  Future<void> settle(WidgetTester tester, {int frames = 8}) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// One counted tap.
  Future<void> tap(WidgetTester tester, String key) async {
    final f = find.byKey(Key(key));
    if (f.evaluate().isEmpty) {
      // Off-screen items of a long list are not built yet.
      await tester.scrollUntilVisible(f, 300, scrollable: lastPageScrollable());
    }
    expect(f, findsOneWidget, reason: key);
    await tester.ensureVisible(f);
    await tester.pump();
    taps++;
    await tester.tap(f);
    await settle(tester);
  }

  Future<void> enter(WidgetTester tester, String key, String text) async {
    final f = find.byKey(Key(key));
    expect(f, findsOneWidget, reason: key);
    await tester.ensureVisible(f);
    await tester.enterText(
      find.descendant(of: f, matching: find.byType(EditableText)),
      text,
    );
    await tester.pump();
  }

  String fieldText(WidgetTester tester, String key) => tester
      .widget<EditableText>(
        find.descendant(
          of: find.byKey(Key(key)),
          matching: find.byType(EditableText),
        ),
      )
      .controller
      .text;

  String textOf(WidgetTester tester, String key) =>
      tester.widget<Text>(find.byKey(Key(key))).data!;
}
