import 'package:flutter/material.dart';
import 'package:repforge/ui/tokens.dart';

/// Labelled progress bar for an amount against a target, e.g. protein.
///
/// Three states are kept visually and textually distinct:
/// * known [amount] (including a known 0) with a [target]: "30 / 50 g" and a
///   progress bar;
/// * known [amount] without a usable [target] (null or not above zero):
///   "30 g · no target" and no bar;
/// * unknown [amount] (null): "n/a", never 0, and no bar; a [target] is
///   still named ("n/a · target 50 g").
///
/// [unknownCount] > 0 appends "· N unknown" to a known amount that was summed
/// from inputs that partly lacked the value.
class RfMacroBar extends StatelessWidget {
  const RfMacroBar({
    required this.label,
    required this.amount,
    required this.target,
    super.key,
    this.unit = 'g',
    this.color,
    this.unknownCount = 0,
  });

  final String label;

  /// The known amount, or null when it is unknown.
  final double? amount;

  /// The configured target, or null when none is set.
  final double? target;
  final String unit;

  /// Defaults to the theme primary colour.
  final Color? color;

  /// How many inputs of [amount] were unknown (0 hides the marker).
  final int unknownCount;

  bool get _hasTarget => target != null && target! > 0;

  /// Progress 0..1, or null when there is nothing to measure.
  double? get _fraction => (amount == null || !_hasTarget)
      ? null
      : (amount! / target!).clamp(0.0, 1.0);

  String get _valueText {
    final a = amount;
    final t = target;
    final unknown = unknownCount > 0 && a != null
        ? ' · $unknownCount unknown'
        : '';
    if (a == null) {
      return _hasTarget ? 'n/a · target ${_n(t!)} $unit' : 'n/a · no target';
    }
    return _hasTarget
        ? '${_n(a)} / ${_n(t!)} $unit$unknown'
        : '${_n(a)} $unit · no target$unknown';
  }

  static String _n(double v) => v.toStringAsFixed(0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rf = context.rf;
    final fill = color ?? rf.accent;
    final fraction = _fraction;
    final valueText = _valueText;
    final semanticsValue = fraction == null
        ? valueText
        : '$valueText, ${(fraction * 100).round()} percent';
    return Semantics(
      label: label,
      value: semanticsValue,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: RfSpace.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                const SizedBox(width: RfSpace.s2),
                Flexible(
                  child: Text(
                    valueText,
                    style: context.rfText.dataS,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
            if (fraction != null) ...[
              const SizedBox(height: RfSpace.xs),
              ClipRRect(
                borderRadius: BorderRadius.circular(RfRadius.pill),
                child: LinearProgressIndicator(
                  value: fraction,
                  minHeight: 6,
                  color: fill,
                  backgroundColor: rf.track,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
