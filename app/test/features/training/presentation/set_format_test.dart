import 'package:flutter_test/flutter_test.dart';
import 'package:repforge/domain/nutrition/nutrition.dart' show DataProvenance;
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/presentation/set_format.dart';

LoadKg _kg(double v) => LoadKg.fromStored(v);

void main() {
  test('loads follow the unit system; quarter kilograms are kept', () {
    expect(formatLoad(_kg(82.25), UnitSystem.metric), '82.25 kg');
    expect(formatLoad(_kg(100), UnitSystem.imperial), '220.5 lb');
    expect(
      formatSetData(
        SetData.weighted(load: _kg(100), reps: 3),
        UnitSystem.imperial,
      ),
      '220.5 lb × 3',
    );
  });

  test('bodyweight and timed sets omit a zero added load', () {
    expect(
      formatSetData(
        SetData.bodyweight(reps: 1, addedLoad: _kg(0)),
        UnitSystem.metric,
      ),
      '1 rep',
    );
    expect(
      formatSetData(
        const SetData.timed(duration: Duration(minutes: 65)),
        UnitSystem.metric,
      ),
      '1:05:00',
    );
  });

  test('distance with a duration and cardio energy labels', () {
    expect(
      formatSetData(
        const SetData.distance(metres: 5000, duration: Duration(minutes: 25)),
        UnitSystem.metric,
      ),
      '5 km in 25:00',
    );
    expect(
      formatSetData(
        const SetData.cardio(
          duration: Duration(minutes: 30),
          energyKcal: 250,
          energyProvenance: DataProvenance.userEntered,
        ),
        UnitSystem.metric,
      ),
      '30:00, 250 kcal (user-entered)',
    );
    expect(
      formatExertion(const Exertion(scale: ExertionScale.rir, value: 2)),
      'RIR 2',
    );
  });
}
