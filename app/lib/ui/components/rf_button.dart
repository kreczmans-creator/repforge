import 'package:flutter/material.dart';
import 'package:repforge/ui/tokens.dart';

/// Visual weight of an [RfButton].
enum RfButtonVariant { primary, secondary, tertiary, danger }

/// The app's button. Always at least 48 dp tall; shows a spinner and ignores
/// taps while [loading].
class RfButton extends StatelessWidget {
  const RfButton({
    required this.label,
    required this.onPressed,
    super.key,
    this.variant = RfButtonVariant.primary,
    this.icon,
    this.loading = false,
    this.expand = true,
  });

  final String label;

  /// Null disables the button.
  final VoidCallback? onPressed;
  final RfButtonVariant variant;
  final IconData? icon;
  final bool loading;

  /// Fill the available width (default). False sizes to content.
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null && !loading;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox(
            width: RfIcon.sm,
            height: RfIcon.sm,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null)
          Icon(icon, size: RfIcon.sm),
        if (loading || icon != null) const SizedBox(width: RfSpace.sm),
        Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
      ],
    );
    final onTap = enabled ? onPressed : null;
    final button = switch (variant) {
      RfButtonVariant.primary => FilledButton(onPressed: onTap, child: child),
      RfButtonVariant.secondary => OutlinedButton(
        onPressed: onTap,
        child: child,
      ),
      RfButtonVariant.tertiary => TextButton(onPressed: onTap, child: child),
      RfButtonVariant.danger => FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.error,
          foregroundColor: scheme.onError,
        ),
        child: child,
      ),
    };
    // The Material button already exposes a single button node whose label
    // is the text child; an outer Semantics would nest a second button.
    return button;
  }
}
