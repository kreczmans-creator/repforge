import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/settings/meal_labels.dart';

Map<MealSlot, String> _names({String snack = 'Snacks'}) => {
  MealSlot.breakfast: 'Breakfast',
  MealSlot.lunch: 'Lunch',
  MealSlot.dinner: 'Dinner',
  MealSlot.snack: snack,
};

String? _field(Result<MealLabels> r) => switch (r) {
  Err(:final error) => (error as ValidationError).field,
  Ok() => null,
};

void main() {
  group('MealLabels (NUT-011)', () {
    test('defaults are Breakfast, Lunch, Dinner, Snacks in that order', () {
      expect(MealLabels.defaults.order, MealSlot.values);
      expect(
        [
          for (final s in MealLabels.defaults.order)
            MealLabels.defaults.labelOf(s),
        ],
        ['Breakfast', 'Lunch', 'Dinner', 'Snacks'],
      );
    });

    test('labels are trimmed; 1 and 30 characters are accepted', () {
      final r = MealLabels.create(
        labels: _names(snack: '  ${'x' * 30}  '),
        order: MealSlot.values,
      );
      expect((r as Ok<MealLabels>).value.labelOf(MealSlot.snack), 'x' * 30);
      expect(
        MealLabels.create(
          labels: _names(snack: 'S'),
          order: MealSlot.values,
        ),
        isA<Ok<MealLabels>>(),
      );
    });

    test('blank or over-long labels are rejected', () {
      for (final bad in ['', '   ', 'x' * 31]) {
        expect(
          _field(
            MealLabels.create(
              labels: _names(snack: bad),
              order: MealSlot.values,
            ),
          ),
          'snack',
          reason: '"$bad"',
        );
      }
    });

    test('labels must be unique, ignoring case and spaces at the ends', () {
      expect(
        _field(
          MealLabels.create(
            labels: _names(snack: ' lunch '),
            order: MealSlot.values,
          ),
        ),
        'snack',
      );
    });

    test('every slot needs a label', () {
      final partial = _names()..remove(MealSlot.dinner);
      expect(
        _field(MealLabels.create(labels: partial, order: MealSlot.values)),
        'dinner',
      );
    });

    test('order must be a permutation of the four slots', () {
      for (final order in [
        <MealSlot>[],
        [MealSlot.breakfast, MealSlot.lunch, MealSlot.dinner],
        [
          MealSlot.breakfast,
          MealSlot.breakfast,
          MealSlot.lunch,
          MealSlot.dinner,
        ],
        [...MealSlot.values, MealSlot.snack],
      ]) {
        expect(
          _field(MealLabels.create(labels: _names(), order: order)),
          'order',
          reason: '$order',
        );
      }
      final reordered = MealLabels.create(
        labels: _names(),
        order: [
          MealSlot.snack,
          MealSlot.dinner,
          MealSlot.lunch,
          MealSlot.breakfast,
        ],
      );
      expect((reordered as Ok<MealLabels>).value.order.first, MealSlot.snack);
    });

    test('JSON round-trips and equal values compare equal', () {
      final a = (MealLabels.create(
        labels: _names(snack: 'Pre-workout'),
        order: MealSlot.values.reversed.toList(),
      ) as Ok<MealLabels>).value;
      final b = MealLabels.fromJson(a.toJson());
      expect(b, a);
      expect(b.hashCode, a.hashCode);
      expect(b, isNot(MealLabels.defaults));
      expect(MealLabels.fromJson(null), MealLabels.defaults);
      expect(a.toString(), contains('Pre-workout'));
    });
  });
}
