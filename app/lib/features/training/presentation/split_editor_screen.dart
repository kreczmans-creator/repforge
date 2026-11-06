import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/plan_providers.dart';
import 'package:repforge/features/training/application/training_providers.dart';
import 'package:repforge/features/training/presentation/unsaved_changes.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Longest cycle a split may have (TRN-014(2)).
const _maxCycleDays = 14;

/// A new split starts as one empty week.
const _defaultCycleDays = 7;

/// Split editor (TRN-014): a name and a repeating cycle of 1 to 14 days, each
/// day a workout or a rest day. Pops with the saved split. With [splitId]
/// null a new split is created.
class SplitEditorScreen extends ConsumerStatefulWidget {
  const SplitEditorScreen({super.key, this.splitId});

  final String? splitId;

  @override
  ConsumerState<SplitEditorScreen> createState() => _SplitEditorScreenState();
}

class _SplitEditorScreenState extends ConsumerState<SplitEditorScreen> {
  final _name = TextEditingController();
  List<String?> _days = List<String?>.filled(_defaultCycleDays, null);
  late String _baseline = _signature();
  bool _seeded = false;
  bool _busy = false;
  String? _nameError;
  String? _daysError;
  String? _generalError;

  bool get _isNew => widget.splitId == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) _seeded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  String _signature() => '${_name.text}|${_days.join(',')}';

  bool get _dirty => _signature() != _baseline;

  void _seed(TrainingSplit split) {
    if (_seeded) return;
    _seeded = true;
    _name.text = split.name;
    _days = [for (final d in split.days) d.planId];
    _baseline = _signature();
  }

  Future<void> _pickDay(int index, Map<String, WorkoutPlan> plans) async {
    final active = [
      for (final p in plans.values)
        if (!p.archived) p,
    ];
    final picked = await showModalBottomSheet<({String? planId})>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
        ),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
              child: Text(
                'Day ${index + 1}',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
            ),
            ListTile(
              key: const Key('split-option-rest'),
              title: const Text('Rest day'),
              selected: _days[index] == null,
              onTap: () => Navigator.of(ctx).pop((planId: null)),
            ),
            for (final p in active)
              ListTile(
                key: Key('split-option-${p.id}'),
                title: Text(p.name),
                selected: _days[index] == p.id,
                onTap: () => Navigator.of(ctx).pop((planId: p.id)),
              ),
            if (active.isEmpty)
              const Padding(
                padding: EdgeInsets.all(RfSpace.gutter),
                child: Text('Create a workout first to add it to the cycle.'),
              ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _days = [..._days]..[index] = picked.planId;
      _daysError = null;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _nameError = null;
      _daysError = null;
      _generalError = null;
    });
    final result = await ref.read(saveSplitProvider)(
      id: widget.splitId,
      name: _name.text,
      days: _days,
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final error):
        setState(() {
          _busy = false;
          final message = userMessageFor(error);
          final field = error is ValidationError ? error.field : null;
          if (field == 'name') {
            _nameError = message;
          } else if (field == 'days') {
            _daysError = message;
          } else {
            _generalError = message;
          }
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isNew ? 'New split' : 'Edit split';
    if (!_isNew && !_seeded) {
      final async = ref.watch(trainingSplitByIdProvider(widget.splitId!));
      final split = async.value;
      if (split == null) {
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: async.hasError
              ? const RfErrorState(message: 'Could not load the split.')
              : async.isLoading
              ? const RfLoading()
              : const Padding(
                  padding: EdgeInsets.all(RfSpace.gutter),
                  child: RfEmptyState(
                    key: Key('split-missing'),
                    message: 'That split no longer exists.',
                  ),
                ),
        );
      }
      _seed(split);
    }
    final theme = Theme.of(context);
    final plans = {
      for (final p
          in ref.watch(allWorkoutPlansProvider).value ?? const <WorkoutPlan>[])
        p.id: p,
    };
    return UnsavedChangesGuard(
      dirty: _dirty && !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
          children: [
            const SizedBox(height: RfSpace.s3),
            RfTextField(
              key: const Key('split-name-field'),
              controller: _name,
              label: 'Split name',
              hint: 'e.g. Upper/Lower',
              errorText: _nameError,
              onChanged: (_) => setState(() => _nameError = null),
            ),
            const SizedBox(height: RfSpace.s4),
            const RfSectionHeader(title: 'Cycle'),
            Text(
              '${_days.length}-day cycle, repeating. Choose a workout or a '
              'rest day for each day.',
              key: const Key('split-cycle-summary'),
              style: theme.textTheme.bodySmall,
            ),
            const SizedBox(height: RfSpace.s2),
            for (var i = 0; i < _days.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: RfSpace.s2),
                child: RfCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          key: Key('split-day-$i'),
                          onTap: () => _pickDay(i, plans),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: rfMinTouchTarget,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Day ${i + 1}',
                                  style: context.rfText.caption,
                                ),
                                Text(
                                  _dayLabel(_days[i], plans),
                                  key: Key('split-day-value-$i'),
                                  style: theme.textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        key: Key('split-remove-day-$i'),
                        tooltip: 'Remove day ${i + 1}',
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _days.length <= 1
                            ? null
                            : () => setState(() {
                                _days = [..._days]..removeAt(i);
                                _daysError = null;
                              }),
                      ),
                    ],
                  ),
                ),
              ),
            if (_daysError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: RfSpace.s2),
                child: Text(
                  _daysError!,
                  key: const Key('error-days'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            RfButton(
              key: const Key('split-add-day'),
              label: _days.length >= _maxCycleDays
                  ? 'Cycle is at most $_maxCycleDays days'
                  : 'Add day',
              icon: Icons.add,
              variant: RfButtonVariant.secondary,
              onPressed: _days.length >= _maxCycleDays
                  ? null
                  : () => setState(() => _days = [..._days, null]),
            ),
            if (_generalError != null) ...[
              const SizedBox(height: RfSpace.s2),
              Text(
                _generalError!,
                key: const Key('error-general'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: RfSpace.s4),
            RfButton(
              key: const Key('split-save'),
              label: 'Save split',
              loading: _busy,
              onPressed: _save,
            ),
            const SizedBox(height: RfSpace.s8),
          ],
        ),
      ),
    );
  }
}

String _dayLabel(String? planId, Map<String, WorkoutPlan> plans) {
  if (planId == null) return 'Rest day';
  final plan = plans[planId];
  if (plan == null) return 'Missing workout';
  return plan.archived ? '${plan.name} (archived)' : plan.name;
}
