import 'package:flutter/material.dart';
import 'package:repforge/ui/tokens.dart';

/// Screen heading with a small uppercase kicker above the title.
class RfScreenTitle extends StatelessWidget {
  const RfScreenTitle({required this.kicker, required this.title, super.key});

  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: RfSpace.md, bottom: RfSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            kicker.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: RfSpace.xs),
          Text(title, style: theme.textTheme.headlineMedium),
        ],
      ),
    );
  }
}
