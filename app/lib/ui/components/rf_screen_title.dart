import 'package:flutter/material.dart';
import 'package:repforge/ui/tokens.dart';

/// Screen heading (H1, Sora) with a muted caption line beneath, as in the
/// brand dashboard ("Good morning" / date line).
class RfScreenTitle extends StatelessWidget {
  const RfScreenTitle({required this.title, super.key, this.caption});

  final String title;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: RfSpace.s2, bottom: RfSpace.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: theme.textTheme.headlineLarge),
          if (caption != null) ...[
            const SizedBox(height: RfSpace.s1),
            Text(caption!, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}
