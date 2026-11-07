import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';
import 'package:repforge/ui/components/rf_card.dart';

import '../../../helpers/pump.dart';
import 'analytics_harness.dart';

/// GOL-011: the analytics screens describe; they never tell the user what to
/// do. Every visible text of every screen (rich text and semantics labels
/// included) is checked against a list of advice words. "Try again" is the
/// retry control of the shared error state, not advice, and is exempt.
final _advice = RegExp(
  '(?<![a-z])(should|consider|recommend[a-z]*|suggest[a-z]*|aim|you need|'
  'you could|need|must|keep|lose|gain|on track|behind|too high|too low|'
  'try(?! again)|improve|eat more|eat less|cut|bulk|reduce your|'
  'increase your)(?![a-z])',
  caseSensitive: false,
);

/// Every text a screen shows: Text and RichText content, and the labels,
/// values, hints and tooltips of the semantics tree.
List<String> _visibleTexts(WidgetTester tester, {Finder? within}) {
  final out = <String>[];
  Finder inside(Finder f) =>
      within == null ? f : find.descendant(of: within, matching: f);
  for (final e in inside(find.byType(RichText)).evaluate()) {
    out.add((e.widget as RichText).text.toPlainText());
  }
  for (final e in inside(find.byType(Text)).evaluate()) {
    final t = e.widget as Text;
    out.add(t.data ?? t.textSpan?.toPlainText() ?? '');
  }
  void walk(SemanticsNode node) {
    out
      ..add(node.label)
      ..add(node.value)
      ..add(node.hint)
      ..add(node.tooltip);
    node.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  final root = within != null
      ? tester.getSemantics(within.first)
      : tester.binding.rootPipelineOwner.semanticsOwner?.rootSemanticsNode;
  if (root != null) walk(root);
  return [
    for (final t in out)
      if (t.trim().isNotEmpty) t,
  ];
}

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.inMemory());
  tearDown(() => db.close());

  final locations = {
    'goals home': RfRoutes.goals,
    'bodyweight editor': RfRoutes.goalsEdit(GoalKind.bodyWeight),
    'measurement editor': RfRoutes.goalsEdit(
      GoalKind.measurement,
      MeasurementSite.waist,
    ),
    'sessions editor': RfRoutes.goalsEdit(GoalKind.sessionsPerWeek),
    'target history': RfRoutes.goalsHistory,
    'weekly summary': RfRoutes.goalsWeekly,
    'comparison': RfRoutes.goalsCompare,
    'training': RfRoutes.goalsTraining,
    'exercise progress': RfRoutes.goalsExercise('bench'),
    'recomposition': RfRoutes.goalsRecomposition,
    'fuel day total': RfRoutes.fuel,
    'nutrition week': RfRoutes.fuelWeek,
    'settings': RfRoutes.settings,
  };

  Future<void> seedData(WidgetTester tester, ProviderContainer c) =>
      tester.runAsync(() async {
        await seedExercise(c, 'bench', 'Bench Press');
        await seedWorkout(c, DateTime(2026, 10, 28, 9), [(70, 5)]);
        await seedWorkout(c, DateTime(2026, 11, 3, 9), [(80, 5), (80, 4)]);
        await c.read(foodLogRepositoryProvider).insertAll([
          foodAt('2026-11-03', 2000),
          foodAt('2026-11-07', 2400, provenance: DataProvenance.estimated),
        ]);
        await c.read(measurementRepositoryProvider).insertAll([
          for (var d = 1; d <= 6; d++)
            readingAt(MeasurementSite.weight, 85, DateTime(2026, 11, d, 8)),
          readingAt(MeasurementSite.waist, 86, DateTime(2026, 10, 2, 8)),
          readingAt(MeasurementSite.waist, 84, DateTime(2026, 11, 5, 8)),
        ]);
        final goals = c.read(goalRepositoryProvider);
        await goals.upsert(goalOf(GoalKind.bodyWeight, 80));
        await goals.upsert(goalOf(GoalKind.sessionsPerWeek, 3));
        await goals.upsert(
          goalOf(GoalKind.measurement, 80, site: MeasurementSite.waist),
        );
        await goals.upsert(goalOf(GoalKind.calories, 2000));
      });

  Future<void> check(
    WidgetTester tester,
    String name,
    String location,
    ProviderContainer c,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpAnalytics(tester, c, location: location);
    if (location == RfRoutes.settings) {
      // Macro targets that imply far more than the calorie target, so the
      // GOL-002 note is on screen.
      for (final e in {
        'calories': '2000',
        'protein': '300',
        'carbs': '300',
        'fat': '100',
      }.entries) {
        await tester.enterText(find.byKey(Key('target-${e.key}')), e.value);
      }
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('implied-energy-warning')), findsOneWidget);
    }
    // Settings holds unrelated cards (backup, units); the daily targets card
    // is the part this work package owns.
    final texts = _visibleTexts(
      tester,
      within: location == RfRoutes.settings
          ? find.ancestor(
              of: find.byKey(const Key('target-calories')),
              matching: find.byType(RfCard),
            )
          : null,
    );
    expect(texts, isNotEmpty, reason: name);
    for (final t in texts) {
      expect(
        _advice.hasMatch(t),
        isFalse,
        reason: '$name: "${_advice.firstMatch(t)?.group(0)}" in "$t"',
      );
    }
    handle.dispose();
    await unmount(tester);
  }

  for (final entry in locations.entries) {
    testWidgets('${entry.key}, empty, has no advice text', (tester) async {
      await check(tester, entry.key, entry.value, analyticsContainer(db));
    });

    testWidgets('${entry.key}, with data, has no advice text', (tester) async {
      final c = analyticsContainer(db);
      await seedData(tester, c);
      await check(tester, entry.key, entry.value, c);
    });

    testWidgets('${entry.key}, failed load, has no advice text', (
      tester,
    ) async {
      Never fail() => throw const AnalyticsLoadException(StorageError('x'));
      final c = analyticsContainer(
        db,
        overrides: [
          goalProgressProvider.overrideWith((ref) async => fail()),
          targetHistoryProvider.overrideWith((ref) async => fail()),
          weeklyReportProvider.overrideWith((ref, p) async => fail()),
          periodComparisonProvider.overrideWith((ref, p) async => fail()),
          weekTrainingProvider.overrideWith((ref, p) async => fail()),
          weekTrainingTotalsProvider.overrideWith((ref, p) async => fail()),
          exerciseProgressProvider.overrideWith((ref, p) async => fail()),
          recompositionSeriesProvider.overrideWith((ref, p) async => fail()),
        ],
      );
      await check(tester, entry.key, entry.value, c);
    });
  }

  test('the pattern catches advice and spares descriptions', () {
    for (final bad in [
      'You should eat more',
      'You need to lose weight',
      'Keep going',
      'You are behind',
      'Too high',
      'on track',
      'Try harder',
    ]) {
      expect(_advice.hasMatch(bad), isTrue, reason: bad);
    }
    for (final ok in [
      'Try again',
      'Top set weight: increased',
      '5.0 kg to go',
      'At target',
    ]) {
      expect(_advice.hasMatch(ok), isFalse, reason: ok);
    }
  });
}
