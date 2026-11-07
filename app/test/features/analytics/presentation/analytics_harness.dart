import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/app/app.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/clock.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';

import '../../../helpers/seed_session.dart';

/// Saturday 2026-11-07, 12:00 local. The week starting Monday is
/// 2026-11-02 to 2026-11-08; the week before is 2026-10-26 to 2026-11-01.
final DateTime analyticsNow = DateTime(2026, 11, 7, 12);

var _seq = 0;

/// A container over [db] with a fixed clock (default [analyticsNow]).
ProviderContainer analyticsContainer(
  AppDatabase db, {
  DateTime? now,
  List<Override> overrides = const [],
}) {
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      clockProvider.overrideWithValue(FixedClock(now ?? analyticsNow)),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Pumps the real app at [location] over [container]. [light] selects the
/// light theme through the stored setting.
Future<void> pumpAnalytics(
  WidgetTester tester,
  ProviderContainer container, {
  String location = RfRoutes.goals,
  Size size = const Size(390, 3000),
  double textScale = 1,
  bool settle = true,
  bool light = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  if (light) {
    await tester.runAsync(
      () => container
          .read(settingsRepositoryProvider)
          .save(const AppSettings(theme: ThemePreference.light)),
    );
  }
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: RepForgeApp(router: createRouter(initialLocation: location)),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
}

Goal goalOf(
  GoalKind kind,
  double target, {
  MeasurementSite? site,
  DateTime? start,
  DateTime? end,
  DateTime? updated,
  bool active = true,
  String? id,
}) {
  final at = (start ?? DateTime(2026, 10)).toUtc();
  return Goal(
    id: id ?? 'g${_seq++}',
    kind: kind,
    site: site,
    target: target,
    startDate: at,
    endDate: end?.toUtc(),
    active: active,
    createdAt: at,
    updatedAt: (updated ?? start ?? DateTime(2026, 10)).toUtc(),
  );
}

Measurement readingAt(MeasurementSite site, double v, DateTime local) {
  final at = local.toUtc();
  return Measurement(
    id: 'rd${_seq++}',
    site: site,
    value: site.isWeight
        ? MeasurementValue.kg(Kilograms.fromStored(v))
        : MeasurementValue.cm(Centimetres.fromStored(v)),
    recordedAt: at,
    createdAt: at,
    updatedAt: at,
  );
}

FoodLogEntry foodAt(
  String day,
  double kcal, {
  double? protein = 100,
  DataProvenance provenance = DataProvenance.verified,
}) {
  final t = DateTime.utc(2026, 11);
  return FoodLogEntry(
    id: 'fe${_seq++}',
    day: day,
    meal: MealSlot.lunch,
    name: 'item',
    quantity: Quantity.fromStored(100, ReferenceUnit.grams),
    nutrients: NutrientAmounts(
      kcal: kcal,
      proteinG: protein,
      carbsG: 20,
      fatG: 5,
      fibreG: 2,
    ),
    provenance: provenance,
    loggedAt: t,
    createdAt: t,
    updatedAt: t,
  );
}

/// A completed session of [exercise] at local [start] with the given
/// (kg, reps) sets, stored through the repository.
Future<void> seedWorkout(
  ProviderContainer c,
  DateTime start,
  List<(double, int)> sets, {
  String exercise = 'bench',
  bool ended = true,
}) async {
  final id = 'ws${_seq++}';
  final session = WorkoutSession(
    id: id,
    name: 'Session',
    startedAt: start.toUtc(),
    endedAt: ended ? start.add(const Duration(hours: 1)).toUtc() : null,
    createdAt: start.toUtc(),
    updatedAt: start.toUtc(),
    sets: [
      for (var i = 0; i < sets.length; i++)
        SessionSet(
          id: 'st${_seq++}',
          sessionId: id,
          exerciseId: exercise,
          exerciseOrder: 0,
          setOrder: i,
          data: SetData.weighted(
            load: LoadKg.fromStored(sets[i].$1),
            reps: sets[i].$2,
          ),
          completed: true,
        ),
    ],
  );
  await seedSession(c.read(workoutSessionRepositoryProvider), session);
}

/// An exercise row, so names resolve.
Future<void> seedExercise(ProviderContainer c, String id, String name) => c
    .read(exerciseRepositoryProvider)
    .upsert(
      Exercise(
        id: id,
        name: name,
        type: ExerciseType.weighted,
        category: ExerciseCategory.push,
        primaryMuscle: MuscleGroup.chest,
        createdAt: DateTime.utc(2026, 11),
        updatedAt: DateTime.utc(2026, 11),
      ),
    );
