import 'package:repforge/domain/units/format.dart';
import 'package:repforge/domain/units/kilograms.dart';
import 'package:repforge/domain/units/units.dart';

/// Body weight for display in the user's unit system. Storage stays metric.
String formatBodyWeight(Kilograms kg, UnitSystem units) => switch (units) {
  UnitSystem.metric => '${kg.value.toStringAsFixed(1)} kg',
  UnitSystem.imperial => '${formatNumber(UnitConversion.kgToLb(kg.value))} lb',
};

/// Body-weight value and unit as separate strings (stat tiles).
({String value, String unit}) bodyWeightParts(Kilograms kg, UnitSystem units) =>
    switch (units) {
      UnitSystem.metric => (value: kg.value.toStringAsFixed(1), unit: 'kg'),
      UnitSystem.imperial => (
        value: formatNumber(UnitConversion.kgToLb(kg.value)),
        unit: 'lb',
      ),
    };
