import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:repforge/domain/measurements/weight_entry.dart';
import 'package:repforge/features/measurements/presentation/weight_providers.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Body-weight logging screen: a form and the history list.
class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  final _weight = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _weight.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    await ref
        .read(weightFormControllerProvider.notifier)
        .submit(weightText: _weight.text, note: _note.text);
    if (!mounted) return;
    final state = ref.read(weightFormControllerProvider);
    if (state is WeightFormSaved) {
      _weight.clear();
      _note.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Saved ${state.entry.weight.label}')),
      );
      ref.read(weightFormControllerProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(weightEntriesProvider);
    final form = ref.watch(weightFormControllerProvider);
    final theme = Theme.of(context);
    final errorText = form is WeightFormFailed
        ? userMessageFor(form.error)
        : null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: RfSpace.lg),
          children: [
            const RfScreenTitle(
              kicker: 'Measure what matters',
              title: 'Body weight',
            ),
            RfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log weight', style: theme.textTheme.labelSmall),
                  const SizedBox(height: RfSpace.md),
                  TextField(
                    key: const Key('weight-input'),
                    controller: _weight,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: 'Weight (kg)',
                      hintText: 'e.g. 82.4',
                      errorText: errorText,
                    ),
                    onChanged: (_) {
                      if (form is WeightFormFailed) {
                        ref.read(weightFormControllerProvider.notifier).reset();
                      }
                    },
                  ),
                  const SizedBox(height: RfSpace.md),
                  TextField(
                    key: const Key('note-input'),
                    controller: _note,
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Note (optional)',
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  const SizedBox(height: RfSpace.lg),
                  FilledButton(
                    key: const Key('save-weight'),
                    onPressed: form is WeightFormSubmitting ? null : _submit,
                    child: Text(
                      form is WeightFormSubmitting ? 'Saving…' : 'Save weight',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: RfSpace.lg),
            Text('History', style: theme.textTheme.titleMedium),
            const SizedBox(height: RfSpace.sm),
            entries.when(
              loading: () => const RfLoading(),
              error: (e, _) => RfErrorState(
                message: 'Could not load your weight history.',
                onRetry: () => ref.invalidate(weightEntriesProvider),
              ),
              data: (list) => list.isEmpty
                  ? const RfEmptyState(
                      key: Key('weight-empty'),
                      icon: Icons.monitor_weight_outlined,
                      message:
                          'No weight logged yet. Add your first entry above.',
                    )
                  : _History(entries: list),
            ),
            const SizedBox(height: RfSpace.xxl),
          ],
        ),
      ),
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.entries});

  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd().add_Hm();
    return RfCard(
      padding: const EdgeInsets.symmetric(vertical: RfSpace.xs),
      child: Column(
        children: [
          for (final e in entries)
            ListTile(
              key: Key('weight-entry-${e.id}'),
              title: Text(e.weight.label, style: theme.textTheme.titleMedium),
              subtitle: Text(
                [
                  dateFormat.format(e.recordedAt.toLocal()),
                  if (e.note != null) e.note!,
                ].join(' · '),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              trailing: IconButton(
                tooltip: 'Delete entry',
                icon: const Icon(Icons.delete_outline),
                onPressed: () => ref
                    .read(weightFormControllerProvider.notifier)
                    .delete(e.id),
              ),
            ),
        ],
      ),
    );
  }
}
