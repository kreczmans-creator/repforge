import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';

import '../../../helpers/pump.dart';
import 'analytics_harness.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  Future<void> open(WidgetTester tester, String buttonKey) async {
    await tester.tap(find.byKey(Key(buttonKey)));
    await tester.pumpAndSettle();
  }

  testWidgets('loading state while the current goal is read', (tester) async {
    final pending = Completer<List<Goal>>();
    final c = analyticsContainer(
      db,
      overrides: [
        goalRepositoryProvider.overrideWithValue(_SaveFails(pending.future)),
      ],
    );
    await pumpAnalytics(
      tester,
      c,
      location: '/goals/edit/sessionsPerWeek',
      settle: false,
    );
    await tester.pump();
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byKey(const Key('goal-save')), findsNothing);
    pending.complete(const []);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-save')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('saves a sessions goal and shows it on the Goals tab', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await pumpAnalytics(tester, c);
    await open(tester, 'goal-set-sessionsPerWeek');
    expect(find.byKey(const Key('goal-clear')), findsNothing);
    await tester.enterText(find.byKey(const Key('goal-target-field')), '3');
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();

    expect(find.text('Goal saved'), findsOneWidget);
    expect(find.byKey(const Key('goal-card-sessionsPerWeek')), findsOneWidget);
    expect(find.text('0 of 3 sessions'), findsOneWidget);
    final active = await tester.runAsync(
      () => c.read(goalRepositoryProvider).active(),
    );
    expect(active!.single.kind, GoalKind.sessionsPerWeek);
    expect(active.single.target, 3);
    await unmount(tester);
  });

  testWidgets('validates the target and the date and keeps the form', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await pumpAnalytics(tester, c);
    await open(tester, 'goal-set-bodyWeight');

    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    expect(find.text('Enter a number.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('goal-target-field')), '10');
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    expect(find.text('Must be between 20 and 500.'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('goal-target-field')), '80');
    await tester.enterText(find.byKey(const Key('goal-date-field')), 'soon');
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    expect(find.text('Use the form YYYY-MM-DD.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('goal-date-field')),
      '2026-11-06',
    );
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    expect(find.text('The date cannot be in the past.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('goal-date-field')),
      '2026-12-31',
    );
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    expect(find.text('Goal saved'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a whole-number field for sessions, limited to 0-14', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await pumpAnalytics(tester, c);
    await open(tester, 'goal-set-sessionsPerWeek');
    await tester.enterText(find.byKey(const Key('goal-target-field')), '2.5');
    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('goal-target-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, '25');
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    expect(find.text('Must be between 0 and 14.'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('replaces the active goal and keeps the old target', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await tester.runAsync(
      () => c
          .read(goalRepositoryProvider)
          .upsert(goalOf(GoalKind.bodyWeight, 80)),
    );
    await pumpAnalytics(tester, c);
    await open(tester, 'goal-edit-bodyWeight');

    final field = tester.widget<TextField>(
      find.descendant(
        of: find.byKey(const Key('goal-target-field')),
        matching: find.byType(TextField),
      ),
    );
    expect(field.controller!.text, '80');
    expect(find.text('Replace goal'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('goal-target-field')), '78');
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();

    final repo = c.read(goalRepositoryProvider);
    final active = await tester.runAsync(repo.active);
    expect(active, hasLength(1));
    expect(active!.single.target, 78);
    final history = await tester.runAsync(repo.history);
    expect(history, hasLength(2));
    expect(find.text('78 kg'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('measurement goal: site choice incl. left and right sites', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await tester.runAsync(
      () => c
          .read(goalRepositoryProvider)
          .upsert(
            goalOf(GoalKind.measurement, 61, site: MeasurementSite.thighRight),
          ),
    );
    await pumpAnalytics(tester, c);
    await open(tester, 'goal-set-measurement');

    // Saving without a site is refused.
    await tester.enterText(find.byKey(const Key('goal-target-field')), '60');
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    expect(find.text('Choose a body site.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('goal-site-choice')));
    await tester.pumpAndSettle();
    expect(find.text('Left thigh'), findsWidgets);
    expect(find.text('Right thigh'), findsWidgets);
    expect(find.text('Weight'), findsNothing);
    await tester.tap(find.byKey(const Key('goal-site-thighLeft')).last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('goal-target-field')), '60');
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();

    final active = await tester.runAsync(
      () => c.read(goalRepositoryProvider).active(),
    );
    expect(active, hasLength(2));
    expect(
      active!.firstWhere((g) => g.site == MeasurementSite.thighLeft).target,
      60,
    );
    expect(
      active.firstWhere((g) => g.site == MeasurementSite.thighRight).target,
      61,
    );
    await unmount(tester);
  });

  testWidgets('shows the derived direction of a weight goal', (tester) async {
    final c = analyticsContainer(db);
    await tester.runAsync(
      () => c.read(measurementRepositoryProvider).insertAll([
        for (final d in [4, 5, 6])
          readingAt(MeasurementSite.weight, 85, DateTime(2026, 11, d, 8)),
      ]),
    );
    await pumpAnalytics(tester, c);
    await open(tester, 'goal-set-bodyWeight');
    await tester.enterText(find.byKey(const Key('goal-target-field')), '80');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Direction: decrease, toward 80.0 kg from the trend value 85.0 kg.',
      ),
      findsOneWidget,
    );
    await tester.enterText(find.byKey(const Key('goal-target-field')), '90');
    await tester.pumpAndSettle();
    expect(
      find.text(
        'Direction: increase, toward 90.0 kg from the trend value 85.0 kg.',
      ),
      findsOneWidget,
    );
    await unmount(tester);
  });

  testWidgets('without a trend the direction says not enough data', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await pumpAnalytics(tester, c);
    await open(tester, 'goal-set-bodyWeight');
    await tester.enterText(find.byKey(const Key('goal-target-field')), '80');
    await tester.pumpAndSettle();
    expect(find.textContaining('not enough data'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('clearing asks for confirmation and keeps the history', (
    tester,
  ) async {
    final c = analyticsContainer(db);
    await tester.runAsync(
      () => c
          .read(goalRepositoryProvider)
          .upsert(goalOf(GoalKind.sessionsPerWeek, 3)),
    );
    await pumpAnalytics(tester, c);
    await open(tester, 'goal-edit-sessionsPerWeek');

    await tester.tap(find.byKey(const Key('goal-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-clear-cancel')));
    await tester.pumpAndSettle();
    var active = await tester.runAsync(
      () => c.read(goalRepositoryProvider).active(),
    );
    expect(active, hasLength(1));

    await tester.tap(find.byKey(const Key('goal-clear')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('goal-clear-confirm')));
    await tester.pumpAndSettle();
    active = await tester.runAsync(
      () => c.read(goalRepositoryProvider).active(),
    );
    expect(active, isEmpty);
    final history = await tester.runAsync(
      () => c.read(goalRepositoryProvider).history(),
    );
    expect(history, hasLength(1));
    expect(find.byKey(const Key('goals-empty')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a storage failure shows the error and keeps the form', (
    tester,
  ) async {
    final c = analyticsContainer(
      db,
      overrides: [goalRepositoryProvider.overrideWithValue(_SaveFails())],
    );
    await pumpAnalytics(tester, c);
    await open(tester, 'goal-set-sessionsPerWeek');
    await tester.enterText(find.byKey(const Key('goal-target-field')), '3');
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('goal-error')), findsOneWidget);
    expect(find.byKey(const Key('goal-save')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('a failed read of the current goal is shown', (tester) async {
    final c = analyticsContainer(
      db,
      overrides: [goalRepositoryProvider.overrideWithValue(_ReadFails())],
    );
    await pumpAnalytics(tester, c, location: '/goals/edit/sessionsPerWeek');
    expect(find.byKey(const Key('goal-error')), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('an unknown goal type is labelled, not a crash', (tester) async {
    final c = analyticsContainer(db);
    await pumpAnalytics(tester, c, location: '/goals/edit/calories');
    expect(find.byKey(const Key('goal-unknown')), findsOneWidget);
    await unmount(tester);
  });
}

final class _SaveFails implements GoalRepository {
  _SaveFails([this._active]);

  final Future<List<Goal>>? _active;

  @override
  Future<List<Goal>> active() => _active ?? Future.value(<Goal>[]);
  @override
  Future<List<Goal>> history() async => [];
  @override
  Stream<List<Goal>> watchActive() => Stream.value(const []);
  @override
  Stream<List<Goal>> watchHistory() => Stream.value(const []);
  @override
  Future<void> upsert(Goal goal) => Future.error(StateError('db gone'));
  @override
  Future<void> replaceActive(
    GoalKind kind,
    Goal? next, {
    MeasurementSite? site,
  }) => Future.error(StateError('db gone'));
  @override
  Future<void> replaceActiveAll(Map<GoalKind, Goal?> changes) =>
      Future.error(StateError('db gone'));
  @override
  Future<void> delete(String id) => Future.error(StateError('db gone'));
}

final class _ReadFails extends _SaveFails {
  @override
  Future<List<Goal>> active() => Future.error(StateError('db gone'));
}
