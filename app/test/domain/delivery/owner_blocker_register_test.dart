import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/delivery/owner_blocker.dart';
import 'package:repforge/domain/delivery/owner_blocker_register.dart';

void main() {
  group('owner blocker register (canonical data source)', () {
    test('ids are unique, follow OB-<WP>-<nn> and match the work package', () {
      final ids = ownerBlockerRegister.map((b) => b.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate id');
      final pattern = RegExp(r'^OB-(WP8|WP15|WP17|PROG)-\d{2}$');
      for (final b in ownerBlockerRegister) {
        expect(pattern.hasMatch(b.id), isTrue, reason: b.id);
        final prefix = switch (b.workPackage) {
          BlockerWorkPackage.wp8 => 'OB-WP8-',
          BlockerWorkPackage.wp15 => 'OB-WP15-',
          BlockerWorkPackage.wp17 => 'OB-WP17-',
          BlockerWorkPackage.programme => 'OB-PROG-',
        };
        expect(b.id.startsWith(prefix), isTrue, reason: b.id);
      }
    });

    test('every record carries every required field', () {
      for (final b in ownerBlockerRegister) {
        for (final (name, value) in [
          ('stage', b.stage),
          ('reference', b.reference),
          ('title', b.title),
          ('description', b.description),
          ('whyBlocked', b.whyBlocked),
          ('actionRequired', b.actionRequired),
          ('recommendation', b.recommendation),
          ('consequences', b.consequences),
          ('deliveryRecord', b.deliveryRecord),
        ]) {
          expect(value.trim(), isNotEmpty, reason: '${b.id} $name');
        }
        expect(b.evidence, isNotEmpty, reason: '${b.id} evidence');
        for (final e in b.evidence) {
          expect(e.label.trim(), isNotEmpty, reason: b.id);
        }
        expect(
          b.deliveryRecord,
          startsWith('docs/delivery-record/WP'),
          reason: b.id,
        );
      }
    });

    test('no owner-assigned entry starts resolved: only the owner closes an '
        'owner item, in the app or in the record', () {
      for (final b in ownerBlockerRegister) {
        if (b.isOwnerAction) {
          expect(
            b.initialStatus,
            isNot(BlockerStatus.resolved),
            reason: '${b.id}: an agent may not record owner acceptance',
          );
        }
      }
    });

    test('no placeholder text survives', () {
      for (final b in ownerBlockerRegister) {
        for (final text in [
          b.description,
          b.whyBlocked,
          b.actionRequired,
          b.recommendation,
          b.consequences,
        ]) {
          expect(text.toLowerCase(), isNot(contains('placeholder')));
          expect(text.toLowerCase(), isNot(contains('todo')));
        }
      }
    });

    test('dependencies that name a blocker id point at a registered id', () {
      final ids = ownerBlockerRegister.map((b) => b.id).toSet();
      final idRef = RegExp(r'OB-WP\d+-\d{2}');
      for (final b in ownerBlockerRegister) {
        for (final d in b.dependencies) {
          for (final m in idRef.allMatches(d)) {
            expect(ids, contains(m.group(0)), reason: '${b.id} -> $d');
            expect(m.group(0), isNot(b.id), reason: 'self-dependency');
          }
        }
      }
    });

    test('owner actions and agent-owned items are both distinguishable and '
        'every agent-owned item is a genuine blocker, not implementation '
        'work', () {
      for (final b in ownerBlockerRegister) {
        if (b.assignee == BlockerAssignee.agent) {
          expect(
            b.category,
            isIn([
              BlockerCategory.independentVerification,
              BlockerCategory.technicalBlocker,
              BlockerCategory.externalInfrastructure,
            ]),
            reason: '${b.id}: agent-owned items must be real blockers',
          );
        } else {
          expect(
            b.category,
            isNot(BlockerCategory.technicalBlocker),
            reason: '${b.id}: a technical blocker is agent-owned',
          );
        }
      }
      expect(ownerBlockerRegister.where((b) => b.isOwnerAction), isNotEmpty);
    });

    test('the register covers the three active work packages', () {
      final wps = ownerBlockerRegister.map((b) => b.workPackage).toSet();
      expect(
        wps,
        containsAll([
          BlockerWorkPackage.wp8,
          BlockerWorkPackage.wp15,
          BlockerWorkPackage.wp17,
        ]),
      );
    });
  });

  group('BlockerState codec', () {
    final a = BlockerState(
      status: BlockerStatus.resolved,
      updatedAt: DateTime.utc(2026, 11, 7, 6, 30),
      note: 'Accepted at the morning review.',
    );
    final b = BlockerState(
      status: BlockerStatus.inProgress,
      updatedAt: DateTime.utc(2026, 11, 7, 7),
    );

    test('round-trips a map of states', () {
      final raw = BlockerStateCodec.encode({'OB-WP15-01': a, 'OB-WP8-01': b});
      expect(BlockerStateCodec.decode(raw), {'OB-WP15-01': a, 'OB-WP8-01': b});
    });

    test('an empty note is not stored and reads back as null', () {
      final s = BlockerState(
        status: b.status,
        updatedAt: b.updatedAt,
        note: '',
      );
      final back = BlockerStateCodec.decode(BlockerStateCodec.encode({'x': s}));
      expect(back['x']!.note, isNull);
    });

    test('malformed input decodes to empty; bad entries are dropped '
        'individually', () {
      expect(BlockerStateCodec.decode(null), isEmpty);
      expect(BlockerStateCodec.decode(''), isEmpty);
      expect(BlockerStateCodec.decode('not json'), isEmpty);
      expect(BlockerStateCodec.decode('[1,2]'), isEmpty);
      final mixed = BlockerStateCodec.decode(
        '{"ok":{"status":"open","updatedAt":"2026-11-07T06:00:00.000Z"},'
        '"badStatus":{"status":"done","updatedAt":"2026-11-07T06:00:00.000Z"},'
        '"badDate":{"status":"open","updatedAt":"yesterday"},'
        '"notMap":5}',
      );
      expect(mixed.keys, ['ok']);
      expect(mixed['ok']!.status, BlockerStatus.open);
      expect(mixed['ok']!.updatedAt.isUtc, isTrue);
    });

    test('non-string fields never throw: the entry is dropped, others '
        'kept', () {
      final mixed = BlockerStateCodec.decode(
        '{"ok":{"status":"open","updatedAt":"2026-11-07T06:00:00.000Z"},'
        '"numDate":{"status":"open","updatedAt":5},'
        '"mapNote":{"status":"open","updatedAt":"2026-11-07T06:00:00.000Z",'
        '"note":{"x":1}},'
        '"badHistory":{"status":"open","updatedAt":"2026-11-07T06:00:00.000Z",'
        '"history":"nope"}}',
      );
      expect(mixed.keys, unorderedEquals(['ok', 'mapNote', 'badHistory']));
      expect(mixed['mapNote']!.note, isNull);
      expect(mixed['badHistory']!.history, isEmpty);
    });

    test('history round-trips oldest first and a bad item is dropped', () {
      final first = BlockerChange(
        status: BlockerStatus.inProgress,
        at: DateTime.utc(2026, 11, 7, 5),
        note: 'started',
      );
      final s = BlockerState.after(
        BlockerState.after(null, first),
        BlockerChange(
          status: BlockerStatus.resolved,
          at: DateTime.utc(2026, 11, 7, 6),
          note: 'done',
        ),
      );
      expect(s.history, [first]);
      expect(s.allChanges.map((c) => c.status), [
        BlockerStatus.inProgress,
        BlockerStatus.resolved,
      ]);
      final back = BlockerStateCodec.decode(BlockerStateCodec.encode({'x': s}));
      expect(back['x'], s);
      final partlyBad = BlockerStateCodec.decode(
        '{"x":{"status":"resolved","updatedAt":"2026-11-07T06:00:00.000Z",'
        '"history":[{"status":"inProgress",'
        '"at":"2026-11-07T05:00:00.000Z"},'
        '{"status":"what","at":"2026-11-07T05:30:00.000Z"}]}}',
      );
      expect(partlyBad['x']!.history, hasLength(1));
    });

    test('merge keeps unknown entries and refuses a non-object value', () {
      final s = BlockerState(
        status: BlockerStatus.open,
        updatedAt: DateTime.utc(2026, 11, 7),
      );
      final merged = BlockerStateCodec.merge(
        '{"foreign":{"status":"deferred","updatedAt":"x"},"extra":1}',
        'OB-WP8-01',
        s,
      );
      expect(
        merged,
        contains('"foreign":{"status":"deferred","updatedAt":"x"}'),
      );
      expect(merged, contains('"extra":1'));
      expect(BlockerStateCodec.decode(merged)['OB-WP8-01'], s);
      expect(BlockerStateCodec.merge(null, 'a', s), isNotEmpty);
      expect(BlockerStateCodec.merge('  ', 'a', s), isNotEmpty);
      expect(
        () => BlockerStateCodec.merge('[1]', 'a', s),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => BlockerStateCodec.merge('{bad', 'a', s),
        throwsA(isA<FormatException>()),
      );
    });

    test('a local time is stored and read back as UTC', () {
      final local = BlockerState(
        status: BlockerStatus.open,
        updatedAt: DateTime(2026, 11, 7, 8),
      );
      final back = BlockerStateCodec.decode(
        BlockerStateCodec.encode({'x': local}),
      )['x']!;
      expect(back.updatedAt.isUtc, isTrue);
      expect(back.updatedAt, local.updatedAt.toUtc());
    });
  });

  group('BlockerView ordering', () {
    OwnerBlocker make(String id, BlockerPriority p, BlockerStatus s) =>
        OwnerBlocker(
          id: id,
          workPackage: BlockerWorkPackage.wp8,
          stage: 's',
          reference: 'r',
          title: 't',
          description: 'd',
          category: BlockerCategory.ownerDecision,
          priority: p,
          initialStatus: s,
          assignee: BlockerAssignee.owner,
          whyBlocked: 'w',
          actionRequired: 'a',
          recommendation: 'r',
          consequences: 'c',
          evidence: const [BlockerEvidence('e')],
          deliveryRecord: 'docs/delivery-record/WP8.md',
        );

    test('high before low, open before resolved, then id; the persisted '
        'state decides openness', () {
      final views = [
        BlockerView(
          blocker: make('OB-WP8-03', BlockerPriority.low, BlockerStatus.open),
        ),
        BlockerView(
          blocker: make('OB-WP8-02', BlockerPriority.high, BlockerStatus.open),
          state: BlockerState(
            status: BlockerStatus.resolved,
            updatedAt: DateTime.utc(2026),
          ),
        ),
        BlockerView(
          blocker: make(
            'OB-WP8-01',
            BlockerPriority.high,
            BlockerStatus.awaitingOwner,
          ),
        ),
      ]..sort(compareBlockerViews);
      expect(views.map((v) => v.blocker.id), [
        'OB-WP8-01',
        'OB-WP8-02',
        'OB-WP8-03',
      ]);
      expect(views[1].isOpen, isFalse);
      expect(views[1].status, BlockerStatus.resolved);
    });
  });
}
