import 'package:flutter/material.dart';
import 'package:repforge/ui/tokens.dart';

/// Labelled progress bar for an amount against a target, e.g. protein.
class RfMacroBar extends StatelessWidget {
  const RfMacroBar({
    required this.label,
    required this.amount,
    required this.target,
    super.key,
    this.unit = 'g',
    this.color,
  });

  final String label;
  final double amount;
  final double target;
  final String unit;

  /// Defaults to the theme primary colour.
  final Color? color;

  double get _fraction => target > 0 ? (amount / target).clamp(0.0, 1.0) : 0.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rf = context.rf;
    final fill = color ?? rf.accent;
    final percent = (_fraction * 100).round();
    final valueText =
        '${amount.toStringAsFixed(0)} / ${target.toStringAsFixed(0)} $unit';
    return Semantics(
      label: label,
      value: '$valueText, $percent percent',
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
                Text(valueText, style: context.rfText.dataS),
              ],
            ),
            const SizedBox(height: RfSpace.xs),
            ClipRRect(
              borderRadius: BorderRadius.circular(RfRadius.pill),
              child: LinearProgressIndicator(
                value: _fraction,
                minHeight: 6,
                color: fill,
                backgroundColor: rf.track,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
