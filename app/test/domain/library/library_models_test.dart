import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/catalogue_records.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/value_equality.dart';
import 'package:repforge/domain/training/training.dart'
    show ExerciseCategory, ExerciseType;

import 'support/catalogue_fixtures.dart';

/// Equality through `Object`, to compare values of unrelated id types.
bool sameValue(Object a, Object b) => a == b;

void main() {
  late ApprovedReference ref;
  setUpAll(() => ref = ApprovedReference.load());

  group('typed identifiers', () {
    test('equal by value and type, ordered, printable', () {
      expect(const ExerciseId('a'), const ExerciseId('a'));
      expect(const ExerciseId('a').hashCode, const ExerciseId('a').hashCode);
      expect(const ExerciseId('a') == const ExerciseId('b'), isFalse);
      expect(
        const ExerciseId('a').compareTo(const ExerciseId('b')),
        lessThan(0),
      );
      expect('${const AnatomyNodeId('chest')}', 'chest');
      // Different id types with the same text are different values.
      expect(sameValue(const ExerciseId('x'), const AnatomyNodeId('x')), false);
      expect(
        sameValue(const MovementPatternId('x'), const EquipmentItemId('x')),
        false,
      );
      expect(sameValue(const ProviderId('x'), const ExerciseId('x')), false);
    });

    test('sets and maps use value equality', () {
      expect(
        <ExerciseId>{const ExerciseId('a')}.union({const ExerciseId('a')}),
        hasLength(1),
      );
      expect({const AnatomyNodeId('a'): 1}[const AnatomyNodeId('a')], 1);
      expect(
        const MovementPatternId('p').compareTo(const MovementPatternId('p')),
        0,
      );
      expect(
        const EquipmentItemId('e').compareTo(const EquipmentItemId('f')),
        lessThan(0),
      );
    });

    test('release id combines provider and number', () {
      const r2 = ReleaseId(ProviderId.repforge, 2);
      expect(r2, const ReleaseId(ProviderId.repforge, 2));
      expect(r2 == const ReleaseId(ProviderId.repforge, 3), isFalse);
      expect(
        r2.compareTo(const ReleaseId(ProviderId.repforge, 3)),
        lessThan(0),
      );
      expect(const ReleaseId(ProviderId('a'), 9).compareTo(r2), lessThan(0));
      expect(r2.toString(), 'repforge#2');
      expect(r2.hashCode, const ReleaseId(ProviderId.repforge, 2).hashCode);
    });
  });

  group('enums', () {
    test('closed owner-defined sets', () {
      expect(Mechanics.values.map((e) => e.name), ['compound', 'isolation']);
      expect(Laterality.values.map((e) => e.name), [
        'bilateral',
        'unilateral',
        'alternating',
      ]);
      expect(Difficulty.values.map((e) => e.name), [
        'beginner',
        'intermediate',
        'advanced',
      ]);
      expect(ExerciseSource.values.map((e) => e.name), [
        'system',
        'user',
        'imported',
      ]);
      expect(TargetRole.values.map((e) => e.name), ['primary', 'secondary']);
      expect(RelationshipKind.values.map((e) => e.name), [
        'variationOf',
        'progressionOf',
        'regressionOf',
        'alternativeTo',
        'unilateralCounterpartOf',
      ]);
    });

    test('relationship kind flags', () {
      expect(RelationshipKind.regressionOf.isStored, isFalse);
      expect(RelationshipKind.progressionOf.isStored, isTrue);
      expect(RelationshipKind.alternativeTo.isSymmetric, isTrue);
      expect(RelationshipKind.unilateralCounterpartOf.isSymmetric, isTrue);
      expect(RelationshipKind.variationOf.isSymmetric, isFalse);
    });

    test('enumByName', () {
      expect(enumByName(Mechanics.values, 'compound'), Mechanics.compound);
      expect(enumByName(Mechanics.values, 'nope'), isNull);
      expect(enumByName(Mechanics.values, 3), isNull);
    });

    test('content section kinds are a controlled list stored as text', () {
      expect(ContentSectionKinds.core, [
        'setup',
        'execution',
        'breathing',
        'commonMistakes',
      ]);
      expect(ContentSectionKinds.isControlled('setup'), isTrue);
      // Release format 2, specification revision 2: knowledge-system kinds
      // join the controlled list; IC-210 still requires the core four only.
      expect(ContentSectionKinds.isControlled('cues'), isTrue);
      expect(ContentSectionKinds.isControlled('safety'), isTrue);
      expect(ContentSectionKinds.isControlled('videoScript'), isFalse);
      expect(ContentSectionKinds.itemCounts['mistakeEffects'], (2, 4));
      expect(ContentSectionKinds.itemCounts['execution'], (3, 6));
      expect(canonicalLocale, 'en-GB');
    });
  });

  group('CatalogueExercise', () {
    test(
      'value equality and copyWith (including clearing nullable fields)',
      () {
        final a = exercise('lib-a');
        expect(a, exercise('lib-a'));
        expect(a.hashCode, exercise('lib-a').hashCode);
        expect(a == a.copyWith(revision: 2), isFalse);
        expect(a.copyWith(mechanics: null).mechanics, isNull);
        expect(a.copyWith().mechanics, Mechanics.compound);
        expect(a.copyWith(providerId: null).providerId, isNull);
        expect(a.copyWith(retiredAt: fixtureTime).isActive, isFalse);
        expect(
          a.copyWith(copiedFromId: xid('lib-z')).copiedFromId,
          xid('lib-z'),
        );
        expect(
          a
              .copyWith(laterality: null, difficulty: null, revision: null)
              .revision,
          isNull,
        );
      },
    );

    test('lists and maps are unmodifiable copies', () {
      final targets = [primary('chest', 0)];
      final e = CatalogueExercise(
        id: xid('lib-a'),
        names: ExerciseNames.english('A'),
        type: ExerciseType.weighted,
        category: ExerciseCategory.push,
        source: ExerciseSource.system,
        createdAt: fixtureTime,
        updatedAt: fixtureTime,
        targets: targets,
        attributes: const {ExerciseAttribute.angle: 'flat'},
      );
      targets.add(secondary('lats', 1));
      expect(e.targets, hasLength(1));
      expect(() => e.targets.add(secondary('lats', 1)), throwsUnsupportedError);
      expect(
        () => e.attributes[ExerciseAttribute.grip] = 'neutral',
        throwsUnsupportedError,
      );
      expect(
        () => e.names.byLocale['de-DE'] = const LocalizedName('x'),
        throwsUnsupportedError,
      );
    });

    test('derived views', () {
      final e = exercise(
        'lib-a',
        targets: [
          primary('chest', 0),
          primary('lats', 1),
          secondary('triceps', 2),
        ],
        patterns: const ['horizontalPush', 'antiExtension'],
      );
      expect(e.primaryTargets.map((t) => t.node.value), ['chest', 'lats']);
      expect(e.secondaryTargets.map((t) => t.node.value), ['triceps']);
      expect(e.primaryPattern!.value, 'horizontalPush');
      expect(exercise('lib-b', patterns: const []).primaryPattern, isNull);
      expect(e.isSystem, isTrue);
      expect(e.name, 'Test a');
      expect(e.aliases, ['Test alias']);
      expect(e.toString(), 'CatalogueExercise(lib-a)');
      expect(e.primaryTargets.first.isPrimary, isTrue);
      expect(e.primaryTargets.first.toString(), 'primary:chest@0');
    });

    test('names by locale: en-GB is canonical', () {
      final n = ExerciseNames(const {
        'en-GB': LocalizedName('Push-up', aliases: ['Press-up']),
        'de-DE': LocalizedName('Liegestütz'),
      });
      expect(n.name, 'Push-up');
      expect(n.aliases, ['Press-up']);
      expect(n.byLocale['de-DE']!.name, 'Liegestütz');
      expect(ExerciseNames(const {}).name, '');
    });

    test('equipment roles and the derived class', () {
      final items = ref.data.equipment;
      CatalogueExercise with_(List<ExerciseEquipment> eq) =>
          exercise('lib-a', equipment: eq);
      ExerciseEquipment use(String id, [EquipmentRole? role]) =>
          ExerciseEquipment(
            EquipmentItemId(id),
            roleOverride: role,
            overrideNote: role == null ? null : 'note',
          );
      EquipmentClass cls(List<ExerciseEquipment> eq) =>
          equipmentClassOf(with_(eq), items);

      expect(cls([]), EquipmentClass.bodyweight);
      expect(cls([use('bench'), use('squatRack')]), EquipmentClass.bodyweight);
      expect(cls([use('barbell'), use('bench')]), EquipmentClass.freeWeight);
      expect(cls([use('dumbbell'), use('bench')]), EquipmentClass.freeWeight);
      expect(cls([use('cable')]), EquipmentClass.cable);
      expect(cls([use('machine')]), EquipmentClass.machine);
      expect(cls([use('kettlebell')]), EquipmentClass.kettlebell);
      expect(cls([use('resistanceBand'), use('bench')]), EquipmentClass.band);
      expect(cls([use('treadmill')]), EquipmentClass.other);
      expect(cls([use('skippingRope')]), EquipmentClass.other);
      // Order: Smith machine, cable, machine, kettlebell, band, free weight,
      // other.
      expect(
        cls([use('smithMachine'), use('cable'), use('barbell')]),
        EquipmentClass.smithMachine,
      );
      expect(cls([use('cable'), use('machine')]), EquipmentClass.cable);
      expect(cls([use('machine'), use('kettlebell')]), EquipmentClass.machine);
      expect(
        cls([use('kettlebell'), use('resistanceBand')]),
        EquipmentClass.kettlebell,
      );
      expect(cls([use('resistanceBand'), use('barbell')]), EquipmentClass.band);
      expect(
        cls([use('barbell'), use('medicineBall')]),
        EquipmentClass.freeWeight,
      );
      // Per-exercise role override: a barbell used as support is bodyweight.
      expect(
        cls([use('barbell', EquipmentRole.support)]),
        EquipmentClass.bodyweight,
      );
      // ...and a bench used as load counts as its class (bodyweight class).
      expect(
        cls([use('bench', EquipmentRole.load), use('dumbbell')]),
        EquipmentClass.freeWeight,
      );
      // Unknown items are ignored.
      expect(cls([use('hoverboard')]), EquipmentClass.bodyweight);

      final e = with_([use('barbell'), use('bench'), use('treadmill')]);
      expect(e.loadItems(items), {
        const EquipmentItemId('barbell'),
        const EquipmentItemId('treadmill'),
      });
      expect(e.effectiveRole(use('bench'), items), EquipmentRole.support);
      expect(e.effectiveRole(use('treadmill'), items), EquipmentRole.load);
      expect(e.effectiveRole(use('skippingRope'), items), EquipmentRole.load);
    });
  });

  group('records', () {
    test('value equality of the Engineering Objects', () {
      expect(
        ContentSection(
          exerciseId: xid('a'),
          locale: 'en-GB',
          kind: 'setup',
          ordinal: 0,
          body: 'x',
        ),
        ContentSection(
          exerciseId: xid('a'),
          locale: 'en-GB',
          kind: 'setup',
          ordinal: 0,
          body: 'x',
        ),
      );
      expect(
        const ContentProvider(
          id: ProviderId.repforge,
          name: 'RepForge',
          licence: 'Original',
          attribution: 'RepForge',
        ),
        const ContentProvider(
          id: ProviderId.repforge,
          name: 'RepForge',
          licence: 'Original',
          attribution: 'RepForge',
        ),
      );
      expect(
        const CatalogueRelease(
          id: ReleaseId(ProviderId.repforge, 2),
          contentHash: 'sha256:x',
          inserted: 89,
          updated: 0,
          retired: 0,
        ),
        const CatalogueRelease(
          id: ReleaseId(ProviderId.repforge, 2),
          contentHash: 'sha256:x',
          inserted: 89,
          updated: 0,
          retired: 0,
        ),
      );
      expect(
        const CatalogueRelease(
              id: ReleaseId(ProviderId.repforge, 2),
              contentHash: 'sha256:x',
              inserted: 89,
              updated: 0,
              retired: 0,
            ) ==
            const CatalogueRelease(
              id: ReleaseId(ProviderId.repforge, 2),
              contentHash: 'sha256:y',
              inserted: 89,
              updated: 0,
              retired: 0,
            ),
        isFalse,
      );
      expect(
        MediaReference(
          id: 'm',
          exerciseId: xid('a'),
          kind: 'image',
          locator: 'l',
          licence: 'CC0-1.0',
          attribution: 'x',
        ),
        MediaReference(
          id: 'm',
          exerciseId: xid('a'),
          kind: 'image',
          locator: 'l',
          licence: 'CC0-1.0',
          attribution: 'x',
        ),
      );
    });

    test('user state is separate from catalogue fields', () {
      final s = UserExerciseState(
        exerciseId: xid('a'),
        favourite: true,
        lastUsedAt: fixtureTime,
      );
      expect(s.hidden, isFalse);
      expect(
        s,
        UserExerciseState(
          exerciseId: xid('a'),
          favourite: true,
          lastUsedAt: fixtureTime,
        ),
      );
      expect(
        s == const UserExerciseState(exerciseId: ExerciseId('a')),
        isFalse,
      );
    });

    test('deep equality helpers', () {
      expect(
        deepEquals(
          [
            1,
            {'a': 2},
          ],
          [
            1,
            {'a': 2},
          ],
        ),
        isTrue,
      );
      expect(deepEquals([1, 2], [1, 3]), isFalse);
      expect(deepEquals({1, 2}, {2, 1}), isTrue);
      expect(deepEquals({1: 'a'}, {1: 'b'}), isFalse);
      expect(deepEquals([1], [1, 2]), isFalse);
      expect(deepEquals({'a': 1}, {'b': 1}), isFalse);
      expect(
        deepHash([
          1,
          {'a': 2},
        ]),
        deepHash([
          1,
          {'a': 2},
        ]),
      );
      expect(deepHash({1, 2}), deepHash({2, 1}));
    });
  });
}
