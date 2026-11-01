import 'package:flutter/material.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/tokens.dart';

/// Compact key-figure tile: label, large value, optional caption.
class RfStatTile extends StatelessWidget {
  const RfStatTile({
    required this.label,
    required this.value,
    super.key,
    this.caption,
  });

  final String label;
  final String value;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return RfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: theme.textTheme.labelSmall),
          const SizedBox(height: RfSpace.sm),
          Text(
            value,
            style: theme.textTheme.headlineMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (caption != null) ...[
            const SizedBox(height: RfSpace.xs),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
