import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/planning/prep_batch.dart';
import 'package:repforge/domain/recipes/recipes.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/planning/application/planning_providers.dart';
import 'package:repforge/features/planning/presentation/plan_format.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Sheet to record a batch of [recipe] as prepared (RCP-015(1)): portions
/// made, greater than zero (default: the recipe's portions). Returns the
/// batch.
Future<PrepBatch?> showRecordBatchSheet(BuildContext context, Recipe recipe) =>
    showModalBottomSheet<PrepBatch>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RecordBatchSheet(recipe: recipe),
    );

class _RecordBatchSheet extends ConsumerStatefulWidget {
  const _RecordBatchSheet({required this.recipe});

  final Recipe recipe;

  @override
  ConsumerState<_RecordBatchSheet> createState() => _RecordBatchSheetState();
}

class _RecordBatchSheetState extends ConsumerState<_RecordBatchSheet> {
  late final TextEditingController _portions = TextEditingController(
    text: formatNumber(widget.recipe.portions, maxDecimals: 2),
  );
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _portions.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    final v = double.tryParse(_portions.text.trim().replaceAll(',', '.'));
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter the number of portions made.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(recordPrepBatchProvider)(
      recipeId: widget.recipe.id,
      portionsMade: v,
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final error):
        setState(() {
          _busy = false;
          _error = userMessageFor(error);
        });
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: RfSpace.gutter,
      right: RfSpace.gutter,
      top: RfSpace.s4,
      bottom: MediaQuery.viewInsetsOf(context).bottom + RfSpace.s4,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Record batch',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: RfSpace.s1),
          Text(
            widget.recipe.name,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: RfSpace.s4),
          RfTextField.number(
            key: const Key('batch-portions'),
            controller: _portions,
            label: 'Portions made',
            decimals: 2,
            errorText: _error,
            autofocus: true,
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: RfSpace.s4),
          RfButton(
            key: const Key('batch-submit'),
            label: 'Record batch',
            loading: _busy,
            onPressed: _save,
          ),
        ],
      ),
    ),
  );
}

String _date(DateTime d) => DateFormat('d MMM').format(d.toLocal());

/// The batches prepared from [recipeId] with portions left (or used up) and
/// a delete action (RCP-015).
class PrepBatchesSection extends ConsumerWidget {
  const PrepBatchesSection({required this.recipeId, super.key});

  final String recipeId;

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    PrepBatch batch,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete batch?'),
        content: const Text(
          'The batch is removed. Diary entries already logged from it stay.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('batch-delete-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final result = await ref.read(deletePrepBatchProvider)(batch.id);
    if (!context.mounted) return;
    if (result case Err(:final error)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(prepBatchesForRecipeProvider(recipeId)).value;
    if (batches == null || batches.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RfSectionHeader(title: 'Prepared batches'),
        RfCard(
          key: const Key('prep-batches'),
          child: Column(
            children: [
              for (final b in batches)
                Row(
                  key: Key('batch-${b.id}'),
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            b.isEmpty
                                ? 'used up'
                                : portionsLeftLabel(b.portionsRemaining),
                            key: Key('batch-left-${b.id}'),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Made '
                            '${formatNumber(b.portionsMade, maxDecimals: 2)}'
                            ' on ${_date(b.preparedAt)}',
                            style: context.rfText.caption,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      key: Key('batch-delete-${b.id}'),
                      tooltip: 'Delete batch',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => _delete(context, ref, b),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
