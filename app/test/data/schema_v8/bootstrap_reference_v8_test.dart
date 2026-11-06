import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/data/db/migration/bootstrap_reference_v8.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/preserved_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/library/reference_parsers.dart';

import 'v8_support.dart';

/// WP 8 stage 3b-2: the reference bootstrap (plan section 6 step 2,
/// safeguard B) equals the approved files and loads idempotently.
void main() {
  final anatomy = referenceJson('anatomy.json');
  final equipment = referenceJson('equipment.json');
  final nodesById = {
    for (final n in (anatomy['nodes']! as List).cast<Map<String, Object?>>())
      n['id']! as String: n,
  };
  final itemsInFile = (equipment['nodes']! as List)
      .cast<Map<String, Object?>>();

  group('constants equal the approved files', () {
    test('31 anatomy nodes: the 19 preserved ids and their ancestors', () {
      final ids = [for (final n in BootstrapReferenceV8.anatomyNodes) n.id];
      expect(ids.length, 31);
      expect(ids.toSet().length, 31);

      final parsed = switch (parseAnatomyReference(anatomy)) {
        Ok(:final value) => value,
        Err(:final error) => throw StateError(error.message),
      };
      final derived = bootstrapNodeIds(AnatomyTree(parsed.nodes));
      expect(ids.toSet(), {for (final id in derived) id.value});
      expect(
        ids.toSet(),
        containsAll([for (final p in preservedMuscleNodes) p.id.value]),
      );
      expect((anatomy['preservedWp8Ids']! as List).toSet(), {
        for (final p in preservedMuscleNodes) p.id.value,
      });
    });

    test('parent, level, non-anatomical flag and sort equal anatomy.json', () {
      for (final n in BootstrapReferenceV8.anatomyNodes) {
        final f = nodesById[n.id]!;
        expect(n.parent, f['parent'], reason: n.id);
        expect(n.level, f['level'], reason: n.id);
        expect(n.nonAnatomical, f['nonAnatomical'], reason: n.id);
        expect(n.sort, f['sort'], reason: n.id);
        expect(f['lifecycle'], 'active', reason: n.id);
      }
      expect(anatomy['provider'], BootstrapReferenceV8.providerId);
    });

    test('parents come before children', () {
      final seen = <String>{};
      for (final n in BootstrapReferenceV8.anatomyNodes) {
        if (n.parent case final p?) expect(seen, contains(p), reason: n.id);
        seen.add(n.id);
      }
    });

    test('21 equipment items: the existing ids, sort and default role of '
        'equipment.json', () {
      final existing = [
        for (final i in itemsInFile)
          if (i['status'] == 'existing') i,
      ];
      expect(
        [for (final e in BootstrapReferenceV8.equipmentItems) e.id],
        [for (final i in existing) i['id']],
      );
      expect(
        [for (final e in BootstrapReferenceV8.equipmentItems) e.id],
        [for (final id in existingEquipmentIds) id.value],
      );
      for (final (e, f) in zip2(
        BootstrapReferenceV8.equipmentItems,
        existing,
      )) {
        expect(e.sort, f['sort'], reason: e.id);
        expect(e.defaultRole, f['role'], reason: e.id);
      }
      expect(equipment['provider'], BootstrapReferenceV8.providerId);
    });

    test('the bootstrap is not the catalogue (safeguard B)', () {
      expect(nodesById.length, 126);
      expect(itemsInFile.length, 33);
      expect(BootstrapReferenceV8.anatomyNodes.length, lessThan(126));
      expect(BootstrapReferenceV8.equipmentItems.length, lessThan(33));
    });
  });

  group('loading', () {
    late FreshV8 v8;
    setUp(() async => v8 = await FreshV8.open());
    tearDown(() => v8.close());

    test('a fresh v8 database holds exactly the bootstrap rows', () {
      const provider =
          '{"id":"repforge","name":"RepForge",'
          '"licence":"proprietary (RepForge)","attribution":null,"url":null}';
      expect(v8.dump('content_providers'), [provider]);
      expect(BootstrapReferenceV8.provider.attribution, isNull);
      final nodes = v8.raw.select(
        'SELECT id, parent_id, level, non_anatomical, sort_order, provider_id '
        'FROM anatomy_nodes ORDER BY rowid',
      );
      expect([
        for (final r in nodes)
          (
            id: r['id'],
            parent: r['parent_id'],
            level: r['level'],
            nonAnatomical: r['non_anatomical'] == 1,
            sort: r['sort_order'],
          ),
      ], BootstrapReferenceV8.anatomyNodes);
      expect(nodes.every((r) => r['provider_id'] == 'repforge'), isTrue);
      final items = v8.raw.select(
        'SELECT id, sort_order, default_role, provider_id FROM equipment_items '
        'ORDER BY rowid',
      );
      expect([
        for (final r in items)
          (id: r['id'], sort: r['sort_order'], defaultRole: r['default_role']),
      ], BootstrapReferenceV8.equipmentItems);
      for (final t in [
        'movement_patterns',
        'reference_labels',
        'catalogue_releases',
        'exercises',
      ]) {
        expect(v8.dump(t), isEmpty, reason: t);
      }
    });

    test('loading twice gives identical tables', () async {
      final before = {
        for (final t in [
          'content_providers',
          'anatomy_nodes',
          'equipment_items',
        ])
          t: v8.dump(t),
      };
      await BootstrapReferenceV8.insert(v8.db);
      await BootstrapReferenceV8.insert(v8.db);
      for (final e in before.entries) {
        expect(v8.dump(e.key), e.value, reason: e.key);
      }
    });

    test('an existing row is never overwritten (owner R-23), in every '
        'bootstrap table', () async {
      v8
        ..run("UPDATE anatomy_nodes SET sort_order = 999 WHERE id = 'chest'")
        ..run("UPDATE equipment_items SET sort_order = 998 WHERE id = 'bench'")
        ..run(
          "UPDATE content_providers SET licence = 'device value' "
          "WHERE id = 'repforge'",
        );
      final before = {
        for (final t in [
          'content_providers',
          'anatomy_nodes',
          'equipment_items',
        ])
          t: v8.dump(t),
      };
      await BootstrapReferenceV8.insert(v8.db);
      for (final e in before.entries) {
        expect(v8.dump(e.key), e.value, reason: e.key);
      }
      expect(before['anatomy_nodes']!.join(), contains('999'));
      expect(before['equipment_items']!.join(), contains('998'));
      expect(before['content_providers']!.join(), contains('device value'));
    });

    test('statements ignore key conflicts only (never INSERT OR IGNORE)', () {
      for (final sql in [
        BootstrapReferenceV8.providerInsertSql,
        BootstrapReferenceV8.anatomyNodeInsertSql,
        BootstrapReferenceV8.equipmentItemInsertSql,
      ]) {
        expect(sql, endsWith('ON CONFLICT (id) DO NOTHING'));
        expect(sql.toUpperCase(), isNot(contains('OR IGNORE')));
        expect(sql.toUpperCase(), isNot(contains('OR REPLACE')));
      }
    });

    test(
      'an invalid injected row fails the load instead of being skipped',
      () async {
        const goodNode = (
          id: 'fresh',
          parent: null,
          level: 1,
          nonAnatomical: false,
          sort: 1,
        );
        const goodItem = (id: 'freshItem', sort: 1, defaultRole: 'load');
        final cases = <String, Future<void> Function()>{
          'node level 9': () => BootstrapReferenceV8.insertRows(
            v8.db,
            providers: const [],
            nodes: const [
              (
                id: 'bad',
                parent: null,
                level: 9,
                nonAnatomical: false,
                sort: 1,
              ),
            ],
            items: const [],
          ),
          'node with an unknown parent': () => BootstrapReferenceV8.insertRows(
            v8.db,
            providers: const [],
            nodes: const [
              (
                id: 'bad',
                parent: 'nowhere',
                level: 2,
                nonAnatomical: false,
                sort: 1,
              ),
            ],
            items: const [],
          ),
          'item role other': () => BootstrapReferenceV8.insertRows(
            v8.db,
            providers: const [],
            nodes: const [],
            items: const [(id: 'bad', sort: 1, defaultRole: 'other')],
          ),
          'provider without a licence': () =>
              BootstrapReferenceV8.insertRows(
                v8.db,
                providers: const [],
                nodes: const [],
                items: const [],
              ).then(
                (_) => v8.db.customStatement(
                  BootstrapReferenceV8.providerInsertSql,
                  ['bad', 'Bad', null, null, null],
                ),
              ),
        };
        for (final MapEntry(key: name, value: load) in cases.entries) {
          await expectLater(load(), throwsA(anything), reason: name);
        }
        // The same statements accept valid rows, so the failures above come
        // from the constraints, not from the statements.
        await BootstrapReferenceV8.insertRows(
          v8.db,
          providers: const [],
          nodes: const [goodNode],
          items: const [goodItem],
        );
        expect(v8.dump('anatomy_nodes').join(), contains('"fresh"'));
        expect(v8.dump('equipment_items').join(), contains('"freshItem"'));
        expect(v8.dump('anatomy_nodes').join(), isNot(contains('"bad"')));
        expect(v8.dump('equipment_items').join(), isNot(contains('"bad"')));
      },
    );

    test('loading into empty tables with foreign keys on reaches the same '
        'rows', () async {
      final before = {
        for (final t in [
          'content_providers',
          'anatomy_nodes',
          'equipment_items',
        ])
          t: v8.dump(t),
      };
      v8
        ..run('DELETE FROM equipment_items')
        ..run('DELETE FROM anatomy_nodes WHERE level = 4')
        ..run('DELETE FROM anatomy_nodes WHERE level = 3')
        ..run('DELETE FROM anatomy_nodes WHERE level = 2')
        ..run('DELETE FROM anatomy_nodes')
        ..run('DELETE FROM content_providers');
      expect(v8.raw.select('PRAGMA foreign_keys').first.values.first, 1);
      await BootstrapReferenceV8.insert(v8.db);
      for (final e in before.entries) {
        expect(v8.dump(e.key), e.value, reason: e.key);
      }
    });
  });
}

/// Pairs of two equally long lists.
Iterable<(A, B)> zip2<A, B>(List<A> a, List<B> b) sync* {
  expect(a.length, b.length);
  for (var i = 0; i < a.length; i++) {
    yield (a[i], b[i]);
  }
}
