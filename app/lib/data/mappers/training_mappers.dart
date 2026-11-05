import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:repforge/data/db/app_database.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart' show DataProvenance;
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';

/// Row <-> domain mapping for the training tables. Mapping is lenient: a row
/// that fails validation maps to null and is skipped by the repositories.
abstract final class TrainingMappers {
  // ---- JSON helpers ------------------------------------------------------

  static String encodeList(List<Object> values) => jsonEncode(values);

  static List<T>? decodeList<T extends Object>(String json) {
    try {
      final decoded = jsonDecode(json);
      if (decoded is! List<dynamic>) return null;
      if (decoded.any((e) => e is! T)) return null;
      return decoded.cast<T>();
    } on FormatException {
      return null;
    }
  }

  static LoadKg? _load(double? raw) {
    if (raw == null) return null;
    return switch (LoadKg.of(raw)) {
      Ok(:final value) => value,
      Err() => null,
    };
  }

  static Duration? _seconds(int? s) => s == null ? null : Duration(seconds: s);

  // ---- Exercise ----------------------------------------------------------

  static List<T>? _enumList<T extends Enum>(String json, List<T> values) {
    final names = decodeList<String>(json);
    if (names == null) return null;
    final map = {for (final v in values) v.name: v};
    final out = <T>[];
    for (final n in names) {
      final v = map[n];
      if (v == null) return null;
      out.add(v);
    }
    return out;
  }

  /// Maps a row; null when a stored identifier is not in the taxonomy (the
  /// repositories then skip the row rather than guess).
  static Exercise? exerciseToEntity(ExerciseRow row) {
    final type = ExerciseType.values.asNameMap()[row.type];
    final category = ExerciseCategory.values.asNameMap()[row.category];
    final primary = MuscleGroup.values.asNameMap()[row.primaryMuscle];
    final secondary = _enumList(row.secondaryMusclesJson, MuscleGroup.values);
    final equipment = _enumList(row.equipmentJson, Equipment.values);
    final aliases = decodeList<String>(row.aliasesJson);
    if (type == null ||
        category == null ||
        primary == null ||
        secondary == null ||
        equipment == null ||
        aliases == null) {
      return null;
    }
    return Exercise(
      id: row.id,
      name: row.name,
      type: type,
      category: category,
      primaryMuscle: primary,
      secondaryMuscles: secondary,
      equipment: equipment,
      aliases: aliases,
      supplied: row.supplied,
      copiedFromId: row.copiedFromId,
      archived: row.archived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static ExercisesCompanion exerciseToRow(Exercise e) =>
      ExercisesCompanion.insert(
        id: e.id,
        name: e.name,
        type: e.type.name,
        category: e.category.name,
        primaryMuscle: e.primaryMuscle.name,
        secondaryMusclesJson: encodeList([
          for (final m in e.secondaryMuscles) m.name,
        ]),
        equipmentJson: encodeList([for (final q in e.equipment) q.name]),
        aliasesJson: Value(encodeList(e.aliases)),
        searchKey: Value(e.searchKey),
        supplied: Value(e.supplied),
        copiedFromId: Value(e.copiedFromId),
        archived: Value(e.archived),
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  // ---- Plans -------------------------------------------------------------

  static PlanExercise? planExerciseToEntity(PlanExerciseRow row) {
    LoadKg? load;
    if (row.targetLoadKg != null) {
      load = _load(row.targetLoadKg);
      if (load == null) return null;
    }
    return PlanExercise(
      id: row.id,
      exerciseId: row.exerciseId,
      sortOrder: row.sortOrder,
      targetSets: row.targetSets,
      repsMin: row.repsMin,
      repsMax: row.repsMax,
      targetLoad: load,
      targetDuration: _seconds(row.targetDurationSec),
      targetMetres: row.targetMetres,
      restSeconds: row.restSeconds,
    );
  }

  static PlanExercisesCompanion planExerciseToRow(
    String planId,
    PlanExercise e,
  ) => PlanExercisesCompanion.insert(
    id: e.id,
    planId: planId,
    exerciseId: e.exerciseId,
    sortOrder: e.sortOrder,
    targetSets: e.targetSets,
    repsMin: Value(e.repsMin),
    repsMax: Value(e.repsMax),
    targetLoadKg: Value(e.targetLoad?.value),
    targetDurationSec: Value(e.targetDuration?.inSeconds),
    targetMetres: Value(e.targetMetres),
    restSeconds: Value(e.restSeconds),
  );

  static WorkoutPlan? planToEntity(
    WorkoutPlanRow row,
    List<PlanExerciseRow> children,
  ) {
    final days = decodeList<int>(row.scheduledWeekdaysJson);
    if (days == null) return null;
    final sorted = [...children]
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return WorkoutPlan(
      id: row.id,
      name: row.name,
      split: row.split,
      scheduledWeekdays: days,
      exercises: [for (final c in sorted) ?planExerciseToEntity(c)],
      archived: row.archived,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static WorkoutPlansCompanion planToRow(WorkoutPlan p) =>
      WorkoutPlansCompanion.insert(
        id: p.id,
        name: p.name,
        split: Value(p.split),
        scheduledWeekdaysJson: encodeList(p.scheduledWeekdays),
        archived: Value(p.archived),
        createdAt: p.createdAt,
        updatedAt: p.updatedAt,
      );

  // ---- Sessions ----------------------------------------------------------

  static SetData? setDataToEntity(SessionSetRow r) {
    final type = ExerciseType.values.asNameMap()[r.type];
    if (type == null) return null;
    final reps = r.reps;
    final dur = _seconds(r.durationSec);
    switch (type) {
      case ExerciseType.weighted:
        final load = _load(r.loadKg);
        if (load == null || reps == null) return null;
        return SetData.weighted(load: load, reps: reps);
      case ExerciseType.bodyweight:
        if (reps == null) return null;
        final added = _load(r.loadKg);
        if (r.loadKg != null && added == null) return null;
        return SetData.bodyweight(reps: reps, addedLoad: added);
      case ExerciseType.assisted:
        final assistance = _load(r.assistanceKg);
        if (assistance == null || reps == null) return null;
        return SetData.assisted(reps: reps, assistance: assistance);
      case ExerciseType.timed:
        if (dur == null) return null;
        final added = _load(r.loadKg);
        if (r.loadKg != null && added == null) return null;
        return SetData.timed(duration: dur, addedLoad: added);
      case ExerciseType.distance:
        final metres = r.metres;
        if (metres == null) return null;
        return SetData.distance(metres: metres, duration: dur);
      case ExerciseType.cardio:
        if (dur == null) return null;
        final kcal = r.energyKcal;
        final provenance = DataProvenance.values
            .asNameMap()[r.energyProvenance];
        // Energy needs its label; one without (or the reverse) is corrupt.
        if ((kcal == null) != (provenance == null)) return null;
        return SetData.cardio(
          duration: dur,
          metres: r.metres,
          averageHeartRate: r.averageHeartRate,
          energyKcal: kcal,
          energyProvenance: provenance,
        );
    }
  }

  static SessionSet? sessionSetToEntity(SessionSetRow r) {
    final data = setDataToEntity(r);
    if (data == null) return null;
    final scale = ExertionScale.values.asNameMap()[r.exertionScale];
    final value = r.exertionValue;
    return SessionSet(
      id: r.id,
      sessionId: r.sessionId,
      exerciseId: r.exerciseId,
      exerciseOrder: r.exerciseOrder,
      setOrder: r.setOrder,
      data: data,
      completed: r.completed,
      exertion: scale != null && value != null
          ? Exertion(scale: scale, value: value)
          : null,
      restSeconds: r.restSeconds,
      note: r.note,
    );
  }

  static SessionSetsCompanion sessionSetToRow(String sessionId, SessionSet s) {
    final d = s.data;
    return SessionSetsCompanion.insert(
      id: s.id,
      sessionId: sessionId,
      exerciseId: s.exerciseId,
      exerciseOrder: s.exerciseOrder,
      setOrder: s.setOrder,
      type: d.type.name,
      loadKg: Value(switch (d) {
        WeightedSet(:final load) => load.value,
        BodyweightSet(:final addedLoad) => addedLoad?.value,
        TimedSet(:final addedLoad) => addedLoad?.value,
        _ => null,
      }),
      reps: Value(switch (d) {
        WeightedSet(:final reps) => reps,
        BodyweightSet(:final reps) => reps,
        AssistedSet(:final reps) => reps,
        _ => null,
      }),
      assistanceKg: Value(switch (d) {
        AssistedSet(:final assistance) => assistance.value,
        _ => null,
      }),
      durationSec: Value(switch (d) {
        TimedSet(:final duration) => duration.inSeconds,
        DistanceSet(:final duration) => duration?.inSeconds,
        CardioSet(:final duration) => duration.inSeconds,
        _ => null,
      }),
      metres: Value(switch (d) {
        DistanceSet(:final metres) => metres,
        CardioSet(:final metres) => metres,
        _ => null,
      }),
      averageHeartRate: Value(switch (d) {
        CardioSet(:final averageHeartRate) => averageHeartRate,
        _ => null,
      }),
      energyKcal: Value(switch (d) {
        CardioSet(:final energyKcal) => energyKcal,
        _ => null,
      }),
      energyProvenance: Value(switch (d) {
        CardioSet(:final energyProvenance) => energyProvenance?.name,
        _ => null,
      }),
      completed: Value(s.completed),
      exertionScale: Value(s.exertion?.scale.name),
      exertionValue: Value(s.exertion?.value),
      restSeconds: Value(s.restSeconds),
      note: Value(s.note),
    );
  }

  static WorkoutSession sessionToEntity(
    WorkoutSessionRow row,
    List<SessionSetRow> setRows,
  ) {
    final sorted = [...setRows]
      ..sort((a, b) {
        final c = a.exerciseOrder.compareTo(b.exerciseOrder);
        return c != 0 ? c : a.setOrder.compareTo(b.setOrder);
      });
    return WorkoutSession(
      id: row.id,
      name: row.name,
      planId: row.planId,
      startedAt: row.startedAt,
      endedAt: row.endedAt,
      notes: row.notes,
      sets: [for (final r in sorted) ?sessionSetToEntity(r)],
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static WorkoutSessionsCompanion sessionToRow(WorkoutSession s) =>
      WorkoutSessionsCompanion.insert(
        id: s.id,
        name: s.name,
        planId: Value(s.planId),
        startedAt: s.startedAt,
        endedAt: Value(s.endedAt),
        notes: Value(s.notes),
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
      );

  // ---- Splits ------------------------------------------------------------

  static TrainingSplit splitToEntity(
    TrainingSplitRow row,
    List<SplitDayRow> days,
  ) {
    final sorted = [...days]..sort((a, b) => a.dayIndex.compareTo(b.dayIndex));
    return TrainingSplit(
      id: row.id,
      name: row.name,
      sortOrder: row.sortOrder,
      days: [for (final d in sorted) SplitDay(planId: d.planId)],
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  static TrainingSplitsCompanion splitToRow(TrainingSplit s) =>
      TrainingSplitsCompanion.insert(
        id: s.id,
        name: s.name,
        cycleDays: s.cycleDays,
        sortOrder: Value(s.sortOrder),
        createdAt: s.createdAt,
        updatedAt: s.updatedAt,
      );

  static List<SplitDaysCompanion> splitDaysToRows(TrainingSplit s) => [
    for (var i = 0; i < s.days.length; i++)
      SplitDaysCompanion.insert(
        id: '${s.id}:$i',
        splitId: s.id,
        dayIndex: i,
        planId: Value(s.days[i].planId),
      ),
  ];
}
