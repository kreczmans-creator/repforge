import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/planning/meal_plan.dart';
import 'package:repforge/domain/planning/prep_batch.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/planning/application/planning_providers.dart';
import 'package:repforge/features/planning/presentation/plan_format.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Sheet to mark a planned item as eaten (RCP-014(3)): the amount is
/// prefilled with the planned quantity and can be changed before confirming.
/// For a recipe the user may draw the portions from an active prepared batch
/// of that recipe. Returns the created diary entries; refusals (already
/// eaten, deleted reference, not enough prepared portions) are shown in the
/// sheet and nothing is logged.
Future<List<FoodLogEntry>?> showMarkEatenSheet(
  BuildContext context,
  MealPlanItem item,
) => showModalBottomSheet<List<FoodLogEntry>>(
  context: context,
  isScrollControlled: true,
  builder: (_) => _MarkEatenSheet(item: item),
);

class _MarkEatenSheet extends ConsumerStatefulWidget {
  const _MarkEatenSheet({required this.item});

  final MealPlanItem item;

  @override
  ConsumerState<_MarkEatenSheet> createState() => _MarkEatenSheetState();
}

class _MarkEatenSheetState extends ConsumerState<_MarkEatenSheet> {
  late final TextEditingController _amount = TextEditingController(
    text: formatNumber(
      widget.item.quantity,
      maxDecimals: widget.item.kind == PlannedKind.savedMeal ? 2 : 1,
    ),
  );
  String? _batchId;
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  double? get _value =>
      double.tryParse(_amount.text.trim().replaceAll(',', '.'));

  Future<void> _confirm() async {
    if (_busy) return;
    final v = _value;
    if (v == null || v <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final result = await ref.read(markPlannedEatenProvider)(
      widget.item.id,
      overrideQuantity: v == widget.item.quantity ? null : v,
      prepBatchId: _batchId,
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final error):
        setState(() {
          _busy = false;
          _error = error is NotFoundError
              ? 'What was planned no longer exists, so it cannot be logged.'
              : userMessageFor(error);
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final item = widget.item;
    final isRecipe = item.kind == PlannedKind.recipe;
    final batches = isRecipe
        ? [
            for (final b
                in ref.watch(prepBatchesForRecipeProvider(item.refId)).value ??
                    const <PrepBatch>[])
              if (!b.isEmpty) b,
          ]
        : const <PrepBatch>[];
    return Padding(
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
            Text(item.name, style: theme.textTheme.headlineSmall),
            const SizedBox(height: RfSpace.s1),
            Text(
              'Planned: ${plannedQuantityLabel(item)}',
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: RfSpace.s4),
            RfTextField.number(
              key: const Key('eaten-quantity'),
              controller: _amount,
              label: switch (item.kind) {
                PlannedKind.recipe => 'Portions eaten',
                PlannedKind.food => 'Amount eaten',
                PlannedKind.savedMeal => 'Times eaten (multiplier)',
              },
              unit: item.kind == PlannedKind.food ? item.unit.symbol : null,
              decimals: item.kind == PlannedKind.savedMeal ? 2 : 1,
              errorText: _error,
              onChanged: (_) => setState(() => _error = null),
            ),
            if (batches.isNotEmpty) ...[
              const SizedBox(height: RfSpace.s3),
              Text('FROM PREPARED BATCH', style: context.rfText.kicker),
              const SizedBox(height: RfSpace.s2),
              Wrap(
                spacing: RfSpace.s2,
                children: [
                  ChoiceChip(
                    key: const Key('eaten-batch-none'),
                    label: const Text('None'),
                    selected: _batchId == null,
                    onSelected: (_) => setState(() => _batchId = null),
                  ),
                  for (final b in batches)
                    ChoiceChip(
                      key: Key('eaten-batch-${b.id}'),
                      label: Text(
                        '${portionsLeftLabel(b.portionsRemaining)} · '
                        '${DateFormat('d MMM').format(b.preparedAt.toLocal())}',
                      ),
                      selected: _batchId == b.id,
                      onSelected: (_) => setState(() {
                        _batchId = b.id;
                        _error = null;
                      }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: RfSpace.s4),
            RfButton(
              key: const Key('eaten-confirm'),
              label: 'Confirm',
              loading: _busy,
              onPressed: _confirm,
            ),
          ],
        ),
      ),
    );
  }
}
