import 'package:repforge/data/repositories/v8/drift_library_repository_v8.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/training/exercise_query.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_repository.dart';

/// The read side of the WP 9 [ExerciseRepository] port over the v8 library
/// (WP 8 sub-stage 3b-8). It lets the unchanged WP 9 use cases (start from
/// a plan or a past session, add or replace a session exercise, record a
/// set, save a plan, copy a supplied exercise) read v8 exercises, so a
/// blocked exercise never enters new work through them.
///
/// **Not connected to the app** (isolated zone; `schema_v8_isolation_test`).
/// The 3d integration reuses this tested mapping; the production switch is
/// a separate, owner-authorised change.
///
/// Presentation through the unchanged port (register C-2 and R-C8 in
/// `docs/v8-library-use-cases.md`):
/// - **blocked** → [byId] returns null. The WP 9 port knows only "missing"
///   and "archived" (`StartSkipReason`); null is what v7 returns for these
///   exercises today (its mapper cannot read them), so WP 9 behaves as
///   before: start skips them as missing, add, replace, record and copy
///   refuse them with "no longer exists". A `blocked` signal in WP 9 would
///   change accepted behaviour (owner decision C-2).
/// - **deleted**, **unreadable** (blocked by the migration since the
///   unreadable-data decision; null also without a block row) or **not
///   representable** in the
///   WP 9 taxonomy (not exactly one primary target, a target outside the
///   19 muscle ids or an item outside the 21 equipment ids) → null, as the
///   v7 mapper does for what it cannot read.
/// - **archived** → `archived: true`: WP 9 skips it at start, refuses it for
///   new entries and lets a saved plan keep it (TD-42), exactly as before.
/// - **retired** → `archived: false`: retirement hides the exercise from
///   discovery ([search], [watchLibrary], [watchAll] use
///   `DriftLibraryRepositoryV8.selectable`, which excludes it) but does not
///   refuse it in existing plans or when starting sessions (ADR-0009
///   decision 4: "hidden from discovery, readable in history"; retirement
///   protects plans). Owner decision R-C8 (2026-11-06): retired exercises
///   stay usable in new work and are excluded from discovery.
///
/// The write side ([upsert], [archive], [delete]) is not part of 3b and
/// throws [UnsupportedError]; the streams emit one snapshot (live watching
/// is 3d work).
final class V8ExerciseReadPort implements ExerciseRepository {
  V8ExerciseReadPort(this.library);

  final DriftLibraryRepositoryV8 library;

  @override
  Future<Exercise?> byId(String id) async {
    final stored = await library.byId(id);
    if (stored == null) return null;
    final a = stored.availability;
    if (a.isDeleted || a.isBlocked) return null;
    final e = stored.exercise;
    return e == null ? null : toWp9(e, archived: a.archived);
  }

  /// The WP 9 view of a v8 exercise; null when a target or item is outside
  /// the WP 9 taxonomy (which has exactly one primary muscle). The 19
  /// muscle ids and the 21 equipment ids keep
  /// their names in v8 (plan section 4; IC-804, IC-806), so the mapping is
  /// by name. The first primary target is the primary muscle; secondary
  /// targets follow in ordinal order.
  static Exercise? toWp9(CatalogueExercise e, {required bool archived}) {
    final muscles = MuscleGroup.values.asNameMap();
    final items = Equipment.values.asNameMap();
    final primaries = e.primaryTargets;
    if (primaries.length != 1) return null;
    final primary = muscles[primaries.single.node.value];
    final secondary = [
      for (final t in e.secondaryTargets) muscles[t.node.value],
    ];
    final equipment = [for (final x in e.equipment) items[x.item.value]];
    if (primary == null ||
        secondary.contains(null) ||
        equipment.contains(null)) {
      return null;
    }
    return Exercise(
      id: e.id.value,
      name: e.name,
      type: e.type,
      category: e.category,
      primaryMuscle: primary,
      secondaryMuscles: [for (final m in secondary) m!],
      equipment: [for (final x in equipment) x!],
      aliases: e.aliases,
      supplied: e.isSystem,
      copiedFromId: e.copiedFromId?.value,
      archived: archived,
      createdAt: e.createdAt,
      updatedAt: e.updatedAt,
    );
  }

  @override
  Future<List<Exercise>> search(ExerciseQuery query) async {
    final discoverable = await library.selectable(
      LibrarySelectionQuery(includeArchived: query.includeArchived),
    );
    final archived = {
      if (query.includeArchived)
        for (final e in discoverable)
          if ((await library.availability(e.id.value))!.archived) e.id.value,
    };
    return filterExercises([
      for (final e in discoverable)
        ?toWp9(e, archived: archived.contains(e.id.value)),
    ], query);
  }

  @override
  Stream<List<Exercise>> watchLibrary(ExerciseQuery query) =>
      Stream.fromFuture(search(query));

  @override
  Stream<List<Exercise>> watchAll({bool includeArchived = false}) =>
      Stream.fromFuture(
        search(ExerciseQuery(includeArchived: includeArchived)),
      );

  @override
  Future<bool> exists(String id) async => await library.byId(id) != null;

  @override
  Future<void> upsert(Exercise exercise) =>
      throw UnsupportedError('The v8 port is read-only in stage 3b.');

  @override
  Future<bool> archive(String id, {required bool archived}) =>
      throw UnsupportedError('The v8 port is read-only in stage 3b.');

  @override
  Future<bool> delete(String id) =>
      throw UnsupportedError('The v8 port is read-only in stage 3b.');
}
