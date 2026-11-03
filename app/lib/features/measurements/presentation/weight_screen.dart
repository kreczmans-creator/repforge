import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/weight_entry.dart';
import 'package:repforge/domain/units/display.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/measurements/presentation/weight_providers.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_list_tile.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
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

  UnitSystem get _units =>
      ref.read(settingsProvider).value?.units ?? UnitSystem.metric;

  Future<void> _submit() async {
    if (ref.read(weightFormControllerProvider) is WeightFormSubmitting) {
      return;
    }
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
        SnackBar(
          content: Text(
            'Saved ${formatBodyWeight(state.entry.weight, _units)}',
          ),
        ),
      );
      ref.read(weightFormControllerProvider.notifier).reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(weightEntriesProvider);
    final form = ref.watch(weightFormControllerProvider);
    final errorText = form is WeightFormFailed
        ? userMessageFor(form.error)
        : null;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
      children: [
        const RfScreenTitle(
          title: 'Track',
          caption: 'Body weight · more measurements arrive in WP 10',
        ),
        RfCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('LOG WEIGHT', style: context.rfText.kicker),
              const SizedBox(height: RfSpace.s3),
              RfTextField.number(
                key: const Key('weight-input'),
                controller: _weight,
                label: 'Weight',
                unit: 'kg',
                hint: 'e.g. 82.4',
                errorText: errorText,
                textInputAction: TextInputAction.next,
                onChanged: (_) {
                  if (form is WeightFormFailed) {
                    ref.read(weightFormControllerProvider.notifier).reset();
                  }
                },
              ),
              const SizedBox(height: RfSpace.s3),
              RfTextField(
                key: const Key('note-input'),
                controller: _note,
                label: 'Note (optional)',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: RfSpace.s4),
              RfButton(
                key: const Key('save-weight'),
                label: form is WeightFormSubmitting ? 'Saving' : 'Save weight',
                loading: form is WeightFormSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
        const SizedBox(height: RfSpace.s4),
        const RfSectionHeader(title: 'History'),
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
                  message: 'No weight logged yet. Add your first entry above.',
                )
              : _History(entries: list),
        ),
        const SizedBox(height: RfSpace.s8),
      ],
    );
  }
}

class _History extends ConsumerWidget {
  const _History({required this.entries});

  final List<WeightEntry> entries;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dateFormat = DateFormat.yMMMd().add_Hm();
    final units =
        ref.watch(settingsProvider.select((s) => s.value?.units)) ??
        UnitSystem.metric;
    return RfCard(
      padding: const EdgeInsets.symmetric(
        horizontal: RfSpace.s4,
        vertical: RfSpace.s1,
      ),
      child: Column(
        children: [
          for (final e in entries)
            RfListTile(
              key: Key('weight-entry-${e.id}'),
              icon: Icons.monitor_weight_outlined,
              title: formatBodyWeight(e.weight, units),
              subtitle: [
                dateFormat.format(e.recordedAt.toLocal()),
                if (e.note != null) e.note!,
              ].join(' · '),
              trailing: IconButton(
                tooltip: 'Delete entry',
                icon: const Icon(Icons.delete_outline),
                onPressed: () async {
                  final result = await ref
                      .read(weightFormControllerProvider.notifier)
                      .delete(e.id);
                  if (!context.mounted) return;
                  if (result case Err(:final error)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(userMessageFor(error))),
                    );
                  }
                },
              ),
            ),
        ],
      ),
    );
  }
}
