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
    return RfCard(
      child: Row(
        children: [
          Icon(
            icon ?? Icons.inbox_outlined,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: RfSpace.md),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
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
    padding: EdgeInsets.all(RfSpace.xl),
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
    return RfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: theme.colorScheme.error),
              const SizedBox(width: RfSpace.md),
              Expanded(child: Text(message)),
            ],
          ),
          if (onRetry != null) ...[
            const SizedBox(height: RfSpace.md),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ],
      ),
    );
  }
}
