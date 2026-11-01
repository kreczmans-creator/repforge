import 'package:flutter/material.dart';
import 'package:repforge/ui/tokens.dart';

/// Panel container used for every grouped block of content.
class RfCard extends StatelessWidget {
  const RfCard({required this.child, super.key, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: padding ?? const EdgeInsets.all(RfSpace.lg),
      child: child,
    ),
  );
}
