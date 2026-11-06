import 'package:flutter/material.dart';
import 'package:repforge/domain/delivery/owner_blocker.dart';
import 'package:repforge/ui/tokens.dart';

/// Small outlined label used for priority, status, category and assignee.
class BlockerPill extends StatelessWidget {
  const BlockerPill({
    required this.label,
    required this.color,
    super.key,
    this.icon,
  });

  final String label;
  final Color color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.labelSmall
        ?.copyWith(color: color, fontWeight: FontWeight.w600);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(RfRadius.pill),
        border: Border.all(color: color.withValues(alpha: 0.6)),
        color: color.withValues(alpha: 0.12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RfSpace.s2,
          vertical: RfSpace.s1,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 12, color: color),
              const SizedBox(width: RfSpace.s1),
            ],
            Flexible(child: Text(label, style: style)),
          ],
        ),
      ),
    );
  }
}

/// Priority: high is an alert, medium the brand accent, low is muted.
Color priorityColor(BuildContext context, BlockerPriority p) {
  final rf = context.rf;
  return switch (p) {
    BlockerPriority.high => rf.alertText,
    BlockerPriority.medium => rf.accentText,
    BlockerPriority.low => rf.textMuted,
  };
}

/// Status: resolved is success, awaiting states draw the eye, the rest are
/// neutral.
Color statusColor(BuildContext context, BlockerStatus s) {
  final rf = context.rf;
  return switch (s) {
    BlockerStatus.resolved => rf.successText,
    BlockerStatus.awaitingOwner => rf.accentText,
    BlockerStatus.awaitingExternalVerification => rf.infoText,
    BlockerStatus.inProgress => rf.infoText,
    BlockerStatus.open => rf.textSecondary,
  };
}

class PriorityPill extends StatelessWidget {
  const PriorityPill(this.priority, {super.key});
  final BlockerPriority priority;

  @override
  Widget build(BuildContext context) => BlockerPill(
    label: priority.label,
    color: priorityColor(context, priority),
  );
}

class StatusPill extends StatelessWidget {
  const StatusPill(this.status, {super.key});
  final BlockerStatus status;

  @override
  Widget build(BuildContext context) =>
      BlockerPill(label: status.label, color: statusColor(context, status));
}

/// Distinguishes work the owner must do from work the agents own.
class AssigneePill extends StatelessWidget {
  const AssigneePill(this.assignee, {super.key});
  final BlockerAssignee assignee;

  @override
  Widget build(BuildContext context) {
    final rf = context.rf;
    final owner = assignee == BlockerAssignee.owner;
    return BlockerPill(
      label: assignee.label,
      color: owner ? rf.accentText : rf.textSecondary,
      icon: owner ? Icons.person_outline : Icons.smart_toy_outlined,
    );
  }
}
