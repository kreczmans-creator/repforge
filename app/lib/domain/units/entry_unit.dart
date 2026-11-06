import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/units/plain_decimal.dart';
import 'package:repforge/domain/units/units.dart';

/// A unit the user may type a food quantity in (NUT-022, WP 15). Storage
/// stays canonical: every entry unit converts exactly to its reference
/// basis, grams or millilitres (calculation specification §2.3,
/// GEN-004): 1 kg = 1000 g, 1 mg = 0.001 g, 1 l = 1000 ml.
///
/// Mass units never convert to volume units and vice versa: a food measured
/// per 100 ml offers only [millilitres] and [litres]. There is no density
/// anywhere in the model, so no mass↔volume conversion exists (NUT-022(2)).
///
/// Imperial units are not entry units (D04 OQ-02 open); `UnitConversion`
/// keeps them for display only.
enum EntryUnit {
  grams('g', ReferenceUnit.grams, 1, 1),
  kilograms('kg', ReferenceUnit.grams, 1000, 4),
  milligrams('mg', ReferenceUnit.grams, 0.001, 0),
  millilitres('ml', ReferenceUnit.millilitres, 1, 1),
  litres('l', ReferenceUnit.millilitres, 1000, 4);

  EntryUnit(this.symbol, this.base, this.factor, this.decimals);

  final String symbol;

  /// The canonical unit this entry unit converts to.
  final ReferenceUnit base;

  /// Exact number of [base] units in one of this unit.
  final double factor;

  /// Decimal places accepted at entry (spec §2.1: input is limited to the
  /// stored precision). 0.1 g is 0.0001 kg, so kg and l accept four
  /// decimals; mg are whole numbers and, being finer than the 0.1 g store,
  /// round to the stored step on conversion (§2.1 rule; 250 mg → 0.3 g).
  final int decimals;

  /// True for [grams] and [millilitres]: the stored unit itself.
  bool get isCanonical => factor == 1;

  /// The entry unit that is a [ReferenceUnit] itself; `portions` has none.
  static EntryUnit? canonicalFor(ReferenceUnit base) => switch (base) {
    ReferenceUnit.grams => grams,
    ReferenceUnit.millilitres => millilitres,
    ReferenceUnit.portions => null,
  };

  /// Entry units offered for a food whose reference basis is [base], the
  /// canonical unit first. Includes [milligrams] only when [withMilligrams]
  /// is set, because the 0.1 g store makes mg entry coarse.
  static List<EntryUnit> forBase(
    ReferenceUnit base, {
    bool withMilligrams = false,
  }) => [
    for (final u in values)
      if (u.base == base && (withMilligrams || u != milligrams)) u,
  ];

  /// Converts [amount] in this unit to a stored [Quantity] in [base]:
  /// multiply by [factor], then apply the §2.1 rounding of `Quantity.of`
  /// (0.1 g or 0.1 ml). Validation (non-negative, finite, upper bound) is
  /// the same as for a directly entered canonical quantity.
  Result<Quantity> toCanonical(double amount) {
    if (amount.isNaN || amount.isInfinite || amount < 0) {
      return const Err(
        ValidationError('Quantity must be zero or more.', field: 'quantity'),
      );
    }
    return Quantity.of(amount * factor, base);
  }

  /// Parses typed text (`0.25`, `0,25`) in this unit; plain decimals only.
  Result<Quantity> parse(String text) {
    final parsed = parsePlainDecimal(text);
    if (parsed == null) {
      return const Err(ValidationError('Enter a number.', field: 'quantity'));
    }
    return toCanonical(parsed);
  }

  /// The stored [quantity] expressed in this unit, for display or to pre-fill
  /// a field: 250 g → 0.25 kg. Exact division; the caller formats. Throws
  /// when [quantity] is not in [base], because that would be a mass↔volume
  /// conversion.
  double fromCanonical(Quantity quantity) {
    if (quantity.unit != base) {
      throw ArgumentError.value(
        quantity,
        'quantity',
        'Cannot express ${quantity.unit.symbol} in $symbol.',
      );
    }
    return quantity.amount / factor;
  }
}
