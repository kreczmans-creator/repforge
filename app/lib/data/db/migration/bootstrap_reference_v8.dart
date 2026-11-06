import 'package:drift/drift.dart';
import 'package:meta/meta.dart';

/// The reference rows schema v8 needs for integrity before any catalogue
/// release is applied (plan section 6 step 2; safeguard B of section 21).
///
/// This is a **bootstrap only**: the 31 anatomy nodes the stored muscle
/// values need (the 19 preserved WP 8 ids and their 12 ancestors), the 21
/// equipment items that predate the catalogue, and the provider `repforge`.
/// The complete approved catalogue (126 anatomy nodes, 79 movement-pattern
/// entries, 33 equipment items, labels) is loaded by catalogue release 2 in
/// stage 3c, never by this file.
///
/// The constants are plain values, independent of the live domain model, so
/// the migration that uses them stays frozen. Tests compare them with the
/// approved `docs/catalogue/reference/anatomy.json` and `equipment.json` and
/// with the domain derivation `bootstrapNodeIds`.
///
/// Shared by a fresh v8 database (`AppDatabaseV8` `onCreate`) and, from
/// sub-stage 3b-4, by the v7 → v8 migration, so both reach the same rows.
abstract final class BootstrapReferenceV8 {
  /// Provider id of RepForge's own content.
  static const String providerId = 'repforge';

  /// The provider row (owner decision R-09): the licence-register template
  /// of `provenance-and-licensing.md` section 6 (RepForge, proprietary
  /// original content, no attribution required, no source URL).
  /// `attribution` stays NULL until stage 3c, whose release 2 provider
  /// registry owns the full record.
  static const ({
    String id,
    String name,
    String licence,
    String? attribution,
    String? url,
  })
  provider = (
    id: providerId,
    name: 'RepForge',
    licence: 'proprietary (RepForge)',
    attribution: null,
    url: null,
  );

  /// The 31 bootstrap anatomy nodes, parents before children (level, then
  /// file order). Values as in the approved `anatomy.json`: `parent`,
  /// `level`, `nonAnatomical`, `sort`.
  static const List<
    ({String id, String? parent, int level, bool nonAnatomical, int sort})
  >
  anatomyNodes = [
    (
      id: 'regionShoulder',
      parent: null,
      level: 1,
      nonAnatomical: false,
      sort: 20,
    ),
    (id: 'regionChest', parent: null, level: 1, nonAnatomical: false, sort: 30),
    (id: 'regionBack', parent: null, level: 1, nonAnatomical: false, sort: 40),
    (id: 'regionArm', parent: null, level: 1, nonAnatomical: false, sort: 50),
    (id: 'regionTrunk', parent: null, level: 1, nonAnatomical: false, sort: 60),
    (id: 'regionHip', parent: null, level: 1, nonAnatomical: false, sort: 70),
    (id: 'regionThigh', parent: null, level: 1, nonAnatomical: false, sort: 80),
    (
      id: 'regionLowerLeg',
      parent: null,
      level: 1,
      nonAnatomical: false,
      sort: 90,
    ),
    (id: 'fullBody', parent: null, level: 1, nonAnatomical: true, sort: 100),
    (
      id: 'shoulders',
      parent: 'regionShoulder',
      level: 2,
      nonAnatomical: false,
      sort: 10,
    ),
    (
      id: 'chest',
      parent: 'regionChest',
      level: 2,
      nonAnatomical: false,
      sort: 10,
    ),
    (
      id: 'upperBack',
      parent: 'regionBack',
      level: 2,
      nonAnatomical: false,
      sort: 10,
    ),
    (
      id: 'lats',
      parent: 'regionBack',
      level: 2,
      nonAnatomical: false,
      sort: 20,
    ),
    (
      id: 'lowerBack',
      parent: 'regionBack',
      level: 2,
      nonAnatomical: false,
      sort: 30,
    ),
    (
      id: 'upperArmAnterior',
      parent: 'regionArm',
      level: 2,
      nonAnatomical: false,
      sort: 10,
    ),
    (
      id: 'upperArmPosterior',
      parent: 'regionArm',
      level: 2,
      nonAnatomical: false,
      sort: 20,
    ),
    (
      id: 'forearms',
      parent: 'regionArm',
      level: 2,
      nonAnatomical: false,
      sort: 30,
    ),
    (
      id: 'abs',
      parent: 'regionTrunk',
      level: 2,
      nonAnatomical: false,
      sort: 10,
    ),
    (
      id: 'obliques',
      parent: 'regionTrunk',
      level: 2,
      nonAnatomical: false,
      sort: 20,
    ),
    (
      id: 'glutes',
      parent: 'regionHip',
      level: 2,
      nonAnatomical: false,
      sort: 10,
    ),
    (
      id: 'abductors',
      parent: 'regionHip',
      level: 2,
      nonAnatomical: false,
      sort: 20,
    ),
    (
      id: 'adductors',
      parent: 'regionHip',
      level: 2,
      nonAnatomical: false,
      sort: 30,
    ),
    (
      id: 'quadriceps',
      parent: 'regionThigh',
      level: 2,
      nonAnatomical: false,
      sort: 10,
    ),
    (
      id: 'hamstrings',
      parent: 'regionThigh',
      level: 2,
      nonAnatomical: false,
      sort: 20,
    ),
    (
      id: 'calves',
      parent: 'regionLowerLeg',
      level: 2,
      nonAnatomical: false,
      sort: 10,
    ),
    (
      id: 'deltoid',
      parent: 'shoulders',
      level: 3,
      nonAnatomical: false,
      sort: 10,
    ),
    (
      id: 'biceps',
      parent: 'upperArmAnterior',
      level: 3,
      nonAnatomical: false,
      sort: 10,
    ),
    (
      id: 'triceps',
      parent: 'upperArmPosterior',
      level: 3,
      nonAnatomical: false,
      sort: 10,
    ),
    (
      id: 'frontDelts',
      parent: 'deltoid',
      level: 4,
      nonAnatomical: false,
      sort: 10,
    ),
    (
      id: 'sideDelts',
      parent: 'deltoid',
      level: 4,
      nonAnatomical: false,
      sort: 20,
    ),
    (
      id: 'rearDelts',
      parent: 'deltoid',
      level: 4,
      nonAnatomical: false,
      sort: 30,
    ),
  ];

  /// The 21 equipment items that predate the catalogue, in file order, with
  /// `sort` and the default `role` of the approved `equipment.json`.
  static const List<({String id, int sort, String defaultRole})>
  equipmentItems = [
    (id: 'barbell', sort: 10, defaultRole: 'load'),
    (id: 'ezBar', sort: 20, defaultRole: 'load'),
    (id: 'trapBar', sort: 30, defaultRole: 'load'),
    (id: 'dumbbell', sort: 40, defaultRole: 'load'),
    (id: 'kettlebell', sort: 50, defaultRole: 'load'),
    (id: 'cable', sort: 60, defaultRole: 'load'),
    (id: 'machine', sort: 70, defaultRole: 'load'),
    (id: 'smithMachine', sort: 80, defaultRole: 'load'),
    (id: 'bench', sort: 90, defaultRole: 'support'),
    (id: 'squatRack', sort: 100, defaultRole: 'support'),
    (id: 'pullUpBar', sort: 110, defaultRole: 'support'),
    (id: 'dipBars', sort: 120, defaultRole: 'support'),
    (id: 'resistanceBand', sort: 130, defaultRole: 'load'),
    (id: 'plate', sort: 140, defaultRole: 'load'),
    (id: 'medicineBall', sort: 150, defaultRole: 'load'),
    (id: 'rings', sort: 160, defaultRole: 'support'),
    (id: 'treadmill', sort: 170, defaultRole: 'cardio'),
    (id: 'bike', sort: 180, defaultRole: 'cardio'),
    (id: 'rower', sort: 190, defaultRole: 'cardio'),
    (id: 'elliptical', sort: 200, defaultRole: 'cardio'),
    (id: 'skippingRope', sort: 210, defaultRole: 'implement'),
  ];

  /// Inserts a provider row unless its id exists. Only a key conflict is
  /// ignored (`ON CONFLICT (id) DO NOTHING`, never `INSERT OR IGNORE`, which
  /// would also skip a row that breaks a CHECK or NOT NULL constraint).
  static const String providerInsertSql =
      'INSERT INTO content_providers (id, name, licence, attribution, url) '
      'VALUES (?, ?, ?, ?, ?) ON CONFLICT (id) DO NOTHING';

  /// Inserts an anatomy node unless its id exists (see [providerInsertSql]).
  static const String anatomyNodeInsertSql =
      'INSERT INTO anatomy_nodes (id, parent_id, level, non_anatomical, '
      'sort_order, provider_id) VALUES (?, ?, ?, ?, ?, ?) '
      'ON CONFLICT (id) DO NOTHING';

  /// Inserts an equipment item unless its id exists (see
  /// [providerInsertSql]).
  static const String equipmentItemInsertSql =
      'INSERT INTO equipment_items (id, sort_order, default_role, '
      'provider_id) VALUES (?, ?, ?, ?) ON CONFLICT (id) DO NOTHING';

  /// Inserts the bootstrap rows that are missing. Existing rows with the
  /// same key are left exactly as they are (owner decision R-23: the device
  /// row wins silently during the v8 migration), so running it twice, or
  /// after a catalogue release, writes nothing. Conflicts on the key are the
  /// only ones ignored: a row that breaks a CHECK, NOT NULL or foreign-key
  /// constraint still fails the statement.
  ///
  /// Runs inside the caller's transaction, if any. Parents come before
  /// children and the provider before everything, so it also succeeds with
  /// foreign keys on.
  static Future<void> insert(GeneratedDatabase db) => insertRows(
    db,
    providers: [provider],
    nodes: anatomyNodes,
    items: equipmentItems,
  );

  /// [insert] with the rows given; tests pass invalid rows to prove that
  /// only key conflicts are ignored.
  @visibleForTesting
  static Future<void> insertRows(
    GeneratedDatabase db, {
    required List<
      ({
        String id,
        String name,
        String licence,
        String? attribution,
        String? url,
      })
    >
    providers,
    required List<
      ({String id, String? parent, int level, bool nonAnatomical, int sort})
    >
    nodes,
    required List<({String id, int sort, String defaultRole})> items,
  }) async {
    for (final p in providers) {
      await db.customStatement(providerInsertSql, [
        p.id,
        p.name,
        p.licence,
        p.attribution,
        p.url,
      ]);
    }
    for (final n in nodes) {
      await db.customStatement(anatomyNodeInsertSql, [
        n.id,
        n.parent,
        n.level,
        if (n.nonAnatomical) 1 else 0,
        n.sort,
        providerId,
      ]);
    }
    for (final e in items) {
      await db.customStatement(equipmentItemInsertSql, [
        e.id,
        e.sort,
        e.defaultRole,
        providerId,
      ]);
    }
  }
}
