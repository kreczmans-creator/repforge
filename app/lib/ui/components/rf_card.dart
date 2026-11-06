import 'package:flutter/material.dart';
import 'package:repforge/ui/tokens.dart';

/// Panel container: Surface 1, 1 px border, 18 px radius, soft shadow.
class RfCard extends StatelessWidget {
  const RfCard({
    required this.child,
    super.key,
    this.padding,
    this.accentEdge = false,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Draws the 2 px amber inset on the leading edge used by the "this week"
  /// highlight card in the brand mock-up.
  final bool accentEdge;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final rf = context.rf;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final body = Padding(
      padding: padding ?? const EdgeInsets.all(RfSpace.s4),
      child: child,
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: rf.surface1,
        borderRadius: BorderRadius.circular(RfRadius.lg),
        border: Border.all(color: rf.border),
        boxShadow: [
          if (dark)
            const BoxShadow(
              color: Color(0x47000000),
              blurRadius: 24,
              offset: Offset(0, 8),
            )
          else ...[
            const BoxShadow(
              color: Color(0x0F1F2A3A),
              blurRadius: 2,
              offset: Offset(0, 1),
            ),
            const BoxShadow(
              color: Color(0x141F2A3A),
              blurRadius: 20,
              offset: Offset(0, 6),
            ),
          ],
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(RfRadius.lg),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: accentEdge
                ? DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(color: rf.accent, width: 2),
                      ),
                    ),
                    child: body,
                  )
                : body,
          ),
        ),
      ),
    );
  }
}
