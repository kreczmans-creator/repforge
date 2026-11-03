import 'package:flutter/material.dart';
import 'package:repforge/ui/tokens.dart';

/// RF monogram plus wordmark for the app bar. Picks the dark- or
/// light-surface master from the current theme. Minimum monogram height is
/// 20 px per the brand rules; the app bar uses 26.
class RfBrandMark extends StatelessWidget {
  const RfBrandMark({super.key, this.height = 26, this.showWordmark = true});

  final double height;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final suffix = dark ? 'dark' : 'light';
    return Semantics(
      label: 'RepForge',
      image: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/brand/logo/monogram-$suffix.png', height: height),
          if (showWordmark) ...[
            const SizedBox(width: RfSpace.s2),
            Image.asset(
              'assets/brand/logo/wordmark-$suffix.png',
              height: height * 0.72,
            ),
          ],
        ],
      ),
    );
  }
}
