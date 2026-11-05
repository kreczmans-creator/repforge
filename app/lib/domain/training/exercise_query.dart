import 'package:meta/meta.dart';
import 'package:repforge/domain/core/search_key.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_validation.dart';

/// Filter for the exercise library (TRN-008..012). Every field is optional;
/// an unset field does not filter.
@immutable
final class ExerciseQuery {
  const ExerciseQuery({
    this.text = '',
    this.category,
    this.muscle,
    this.availableEquipment,
    this.includeArchived = false,
  });

  /// Free text matched against name and aliases, ignoring case and
  /// diacritics (TRN-008(3)). Every word must be found.
  final String text;

  /// Only this category (TRN-009(2)).
  final ExerciseCategory? category;

  /// Only exercises where this is the primary or a secondary muscle group,
  /// primary matches listed first (TRN-010(2)).
  final MuscleGroup? muscle;

  /// Equipment the user has (TRN-011(2)). Null means no equipment filter. A
  /// set filters to exercises whose required equipment is a subset of it;
  /// exercises with no equipment (bodyweight) always pass, so an empty set
  /// shows bodyweight exercises only.
  final Set<Equipment>? availableEquipment;

  /// Archived exercises are hidden from pickers (TRN-012(2)); history views
  /// set this to see them.
  final bool includeArchived;

  @override
  bool operator ==(Object other) =>
      other is ExerciseQuery &&
      other.text == text &&
      other.category == category &&
      other.muscle == muscle &&
      other.includeArchived == includeArchived &&
      _sameSet(other.availableEquipment, availableEquipment);

  static bool _sameSet(Set<Equipment>? a, Set<Equipment>? b) =>
      a == null || b == null
      ? a == b
      : a.length == b.length && a.containsAll(b);

  @override
  int get hashCode => Object.hash(
    text,
    category,
    muscle,
    includeArchived,
    availableEquipment == null
        ? null
        : Object.hashAllUnordered(availableEquipment!),
  );
}

/// True when [exercise] passes every filter of [query].
bool matchesExerciseQuery(Exercise exercise, ExerciseQuery query) {
  if (exercise.archived && !query.includeArchived) return false;
  if (query.category != null && exercise.category != query.category) {
    return false;
  }
  final muscle = query.muscle;
  if (muscle != null &&
      exercise.primaryMuscle != muscle &&
      !exercise.secondaryMuscles.contains(muscle)) {
    return false;
  }
  final available = query.availableEquipment;
  if (available != null && !available.containsAll(exercise.equipment)) {
    return false;
  }
  final tokens = normaliseExerciseSearch(query.text);
  if (tokens.isNotEmpty) {
    final key = exercise.searchKey;
    for (final token in tokens.split(' ')) {
      if (!key.contains(token)) return false;
    }
  }
  return true;
}

/// Applies [query] to [exercises] and orders the result: when a muscle is
/// chosen, exercises with it as primary come first; within each group (and
/// without a muscle filter) the order is by name, ignoring case and
/// diacritics, then by id for stability.
List<Exercise> filterExercises(
  Iterable<Exercise> exercises,
  ExerciseQuery query,
) {
  final muscle = query.muscle;
  final out = [
    for (final e in exercises)
      if (matchesExerciseQuery(e, query)) e,
  ];
  int rank(Exercise e) => muscle != null && e.primaryMuscle == muscle ? 0 : 1;
  out.sort((a, b) {
    final r = rank(a).compareTo(rank(b));
    if (r != 0) return r;
    final n = normaliseSearchKey(a.name).compareTo(normaliseSearchKey(b.name));
    return n != 0 ? n : a.id.compareTo(b.id);
  });
  return out;
}
