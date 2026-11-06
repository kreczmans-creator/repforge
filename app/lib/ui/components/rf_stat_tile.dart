import 'package:flutter/material.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/tokens.dart';

/// Stat card: kicker label, large Plex Mono value with unit, optional
/// progress bar and mono sub-line.
class RfStatTile extends StatelessWidget {
  const RfStatTile({
    required this.label,
    required this.value,
    super.key,
    this.unit,
    this.caption,
    this.progress,
  });

  final String label;
  final String value;
  final String? unit;
  final String? caption;

  /// 0..1 fills an amber progress bar under the value.
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final rfText = context.rfText;
    final rf = context.rf;
    return RfCard(
      padding: const EdgeInsets.symmetric(horizontal: RfSpace.s4, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: rfText.kicker),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  style: rfText.dataL,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 5),
                Text(unit!, style: rfText.caption),
              ],
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(RfRadius.pill),
              child: LinearProgressIndicator(
                value: progress!.clamp(0, 1),
                minHeight: 6,
                color: rf.accent,
                backgroundColor: rf.track,
              ),
            ),
          ],
          if (caption != null) ...[
            const SizedBox(height: RfSpace.s2),
            Text(caption!, style: rfText.meta),
          ],
        ],
      ),
    );
  }
}
