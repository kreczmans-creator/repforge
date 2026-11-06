import 'package:flutter/material.dart';
import 'package:repforge/ui/components/rf_icon_tile.dart';
import 'package:repforge/ui/tokens.dart';

/// Activity row as in the brand mock-up: 36 px amber-tinted icon tile,
/// title, muted subtitle, trailing widget. At least 48 dp tall.
class RfListTile extends StatelessWidget {
  const RfListTile({
    required this.title,
    super.key,
    this.subtitle,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
  });

  final String title;
  final String? subtitle;

  /// Shown in an amber-tinted tile when [leading] is null.
  final IconData? icon;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lead = leading ?? (icon == null ? null : RfIconTile(icon: icon!));
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: rfMinTouchTarget),
      child: ListTile(
        onTap: onTap,
        leading: lead,
        trailing: trailing,
        contentPadding: EdgeInsets.zero,
        horizontalTitleGap: RfSpace.s3,
        title: Text(
          title,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: context.rfText.caption,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
    );
  }
}
