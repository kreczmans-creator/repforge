import 'package:flutter/material.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/tokens.dart';

/// Shown when a list or panel has no data yet.
class RfEmptyState extends StatelessWidget {
  const RfEmptyState({required this.message, super.key, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rf = context.rf;
    return RfCard(
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: rf.accentSubtle,
              borderRadius: BorderRadius.circular(RfRadius.sm),
            ),
            child: Icon(
              icon ?? Icons.inbox_outlined,
              size: RfIcon.sm,
              color: rf.accent,
            ),
          ),
          const SizedBox(width: RfSpace.s3),
          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

/// Shown while data is loading.
class RfLoading extends StatelessWidget {
  const RfLoading({super.key});

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.all(RfSpace.s6),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// Shown when loading failed. [onRetry] is optional.
class RfErrorState extends StatelessWidget {
  const RfErrorState({required this.message, super.key, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rf = context.rf;
    return RfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: rf.alert, size: RfIcon.md),
              const SizedBox(width: RfSpace.s3),
              Expanded(child: Text(message, style: theme.textTheme.bodyMedium)),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: RfSpace.s2),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}

/// Placeholder for a feature that a later work package delivers. Always
/// visibly labelled so it is never mistaken for a finished feature.
class RfNotYetAvailable extends StatelessWidget {
  const RfNotYetAvailable({
    required this.feature,
    required this.workPackage,
    super.key,
  });

  final String feature;
  final String workPackage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rf = context.rf;
    return RfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Chip(
                label: const Text('NOT YET AVAILABLE'),
                labelStyle: context.rfText.kicker.copyWith(
                  color: rf.textSecondary,
                ),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: RfSpace.s2),
          Text(feature, style: theme.textTheme.titleMedium),
          const SizedBox(height: RfSpace.s1),
          Text(
            'Planned for $workPackage. Nothing here is implemented yet.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
