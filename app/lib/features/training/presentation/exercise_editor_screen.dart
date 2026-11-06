import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/features/training/application/exercise_library_providers.dart';
import 'package:repforge/features/training/application/training_providers.dart';
import 'package:repforge/features/training/presentation/training_labels.dart';
import 'package:repforge/features/training/presentation/training_pickers.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Create or edit a custom exercise (TRN-012(1)). Pops with the saved
/// exercise. With [exerciseId] null a new exercise is created.
///
/// With [copyFromId] the editor opens on an unsaved draft copy of that
/// supplied exercise (TRN-008(2)): the fields are prefilled and nothing is
/// stored until Save, which creates the one custom copy. Leaving the editor
/// without saving creates nothing.
class ExerciseEditorScreen extends ConsumerStatefulWidget {
  const ExerciseEditorScreen({super.key, this.exerciseId, this.copyFromId});

  final String? exerciseId;
  final String? copyFromId;

  @override
  ConsumerState<ExerciseEditorScreen> createState() =>
      _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends ConsumerState<ExerciseEditorScreen> {
  final _name = TextEditingController();
  final _alias = TextEditingController();
  List<String> _aliases = [];
  ExerciseType? _type;
  ExerciseCategory? _category;
  MuscleGroup? _primary;
  Set<MuscleGroup> _secondary = {};
  Set<Equipment> _equipment = {};

  bool _seeded = false;
  bool _busy = false;
  String? _error;
  String? _errorField;

  bool get _isCopy => widget.copyFromId != null;
  bool get _isNew => widget.exerciseId == null && !_isCopy;

  @override
  void initState() {
    super.initState();
    if (_isNew) _seeded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _alias.dispose();
    super.dispose();
  }

  void _seed(Exercise e) {
    if (_seeded) return;
    _seeded = true;
    _name.text = e.name;
    _aliases = [...e.aliases];
    _type = e.type;
    _category = e.category;
    _primary = e.primaryMuscle;
    _secondary = {...e.secondaryMuscles};
    _equipment = {...e.equipment};
  }

  String? _errorFor(String field) => _errorField == field ? _error : null;

  void _clearError(String field) {
    if (_errorField == field) {
      _error = null;
      _errorField = null;
    }
  }

  void _addAlias() {
    final text = _alias.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _aliases = [..._aliases, text];
      _alias.clear();
      _clearError('aliases');
    });
  }

  Future<void> _pickPrimary() async {
    final picked = await showPickOneSheet<MuscleGroup>(
      context,
      title: 'Primary muscle group',
      options: MuscleGroup.values,
      labelOf: muscleGroupLabel,
      keyPrefix: 'primary',
      selected: _primary,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _primary = picked.value;
      _secondary.remove(picked.value);
      _clearError('primary');
      _clearError('secondaryMuscles');
    });
  }

  Future<void> _pickSecondary() async {
    final picked = await showPickManySheet<MuscleGroup>(
      context,
      title: 'Secondary muscle groups',
      options: [
        for (final m in MuscleGroup.values)
          if (m != _primary) m,
      ],
      labelOf: muscleGroupLabel,
      keyPrefix: 'secondary',
      selected: _secondary,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _secondary = picked;
      _clearError('secondaryMuscles');
    });
  }

  Future<void> _pickEquipment() async {
    final picked = await showPickManySheet<Equipment>(
      context,
      title: 'Equipment',
      helper: 'Select nothing for a bodyweight-only exercise.',
      options: Equipment.values,
      labelOf: equipmentLabel,
      keyPrefix: 'equip',
      selected: _equipment,
    );
    if (picked == null || !mounted) return;
    setState(() => _equipment = picked);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _errorField = null;
    });
    final secondary = [
      for (final m in MuscleGroup.values)
        if (_secondary.contains(m)) m,
    ];
    final equipment = [
      for (final q in Equipment.values)
        if (_equipment.contains(q)) q,
    ];
    final Result<Exercise> result;
    if (_isCopy) {
      // The copy use case keeps the original's value for a null; the editor
      // asks for all three required choices instead.
      result = _type == null
          ? const Err(ValidationError('Choose a type.', field: 'type'))
          : _category == null
          ? const Err(ValidationError('Choose a category.', field: 'category'))
          : _primary == null
          ? const Err(
              ValidationError(
                'Choose a primary muscle group.',
                field: 'primary',
              ),
            )
          : await ref.read(copySuppliedExerciseProvider)(
              sourceId: widget.copyFromId!,
              name: _name.text,
              type: _type,
              category: _category,
              primaryMuscle: _primary,
              secondaryMuscles: secondary,
              equipment: equipment,
              aliases: _aliases,
            );
    } else {
      result = await ref.read(saveCustomExerciseProvider)(
        id: widget.exerciseId,
        name: _name.text,
        type: _type,
        category: _category,
        primaryMuscle: _primary,
        secondaryMuscles: secondary,
        equipment: equipment,
        aliases: _aliases,
      );
    }
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final error):
        setState(() {
          _busy = false;
          _error = userMessageFor(error);
          _errorField = error is ValidationError ? error.field : '';
        });
    }
  }

  Widget _fieldError(String field) {
    final message = _errorFor(field);
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: RfSpace.s1),
      child: Text(
        message,
        key: Key('error-$field'),
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = _isNew ? 'New exercise' : 'Edit exercise';
    var typeLocked = false;
    if (!_isNew) {
      final async = ref.watch(
        exerciseByIdProvider(widget.copyFromId ?? widget.exerciseId!),
      );
      final e = async.value;
      if (e == null) {
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: async.hasError
              ? const RfErrorState(message: 'Could not load the exercise.')
              : async.isLoading
              ? const RfLoading()
              : const Padding(
                  padding: EdgeInsets.all(RfSpace.gutter),
                  child: RfEmptyState(
                    message: 'That exercise no longer exists.',
                  ),
                ),
        );
      }
      if (e.supplied != _isCopy) {
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: Padding(
            padding: const EdgeInsets.all(RfSpace.gutter),
            child: RfEmptyState(
              key: const Key('editor-supplied'),
              message: _isCopy
                  ? 'Only a supplied exercise is copied; edit your own '
                        'directly.'
                  : 'A supplied exercise cannot be edited. Open it and '
                        'choose Edit to make your own copy.',
            ),
          ),
        );
      }
      _seed(e);
      typeLocked =
          !_isCopy &&
          (ref.watch(exerciseHasHistoryProvider(e.id)).value ?? false);
    }
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const SizedBox(height: RfSpace.s3),
          RfTextField(
            key: const Key('exercise-name-field'),
            controller: _name,
            label: 'Name',
            errorText: _errorFor('name'),
            onChanged: (_) => setState(() => _clearError('name')),
          ),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Also known as'),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: RfTextField(
                  key: const Key('alias-input'),
                  controller: _alias,
                  label: 'Alias',
                  hint: 'e.g. RDL',
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addAlias(),
                ),
              ),
              const SizedBox(width: RfSpace.s2),
              IconButton(
                key: const Key('alias-add'),
                tooltip: 'Add alias',
                icon: const Icon(Icons.add),
                onPressed: _addAlias,
              ),
            ],
          ),
          if (_aliases.isNotEmpty)
            Wrap(
              spacing: RfSpace.s2,
              children: [
                for (var i = 0; i < _aliases.length; i++)
                  InputChip(
                    key: Key('alias-$i'),
                    label: Text(_aliases[i]),
                    deleteButtonTooltipMessage: 'Remove ${_aliases[i]}',
                    onDeleted: () => setState(() {
                      _aliases = [..._aliases]..removeAt(i);
                      _clearError('aliases');
                    }),
                  ),
              ],
            ),
          _fieldError('aliases'),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Type'),
          Wrap(
            spacing: RfSpace.s2,
            runSpacing: RfSpace.s1,
            children: [
              for (final t in ExerciseType.values)
                ChoiceChip(
                  key: Key('type-${t.name}'),
                  label: Text(exerciseTypeLabel(t)),
                  selected: _type == t,
                  onSelected: typeLocked
                      ? null
                      : (v) => setState(() {
                          _type = v ? t : null;
                          _clearError('type');
                        }),
                ),
            ],
          ),
          if (typeLocked)
            Padding(
              padding: const EdgeInsets.only(top: RfSpace.s1),
              child: Text(
                'The type is locked because sets have been recorded for this '
                'exercise.',
                key: const Key('type-locked'),
                style: theme.textTheme.bodySmall,
              ),
            )
          else if (_type != null)
            Padding(
              padding: const EdgeInsets.only(top: RfSpace.s1),
              child: Text(
                'Records: ${exerciseTypeHint(_type!)}',
                style: theme.textTheme.bodySmall,
              ),
            ),
          _fieldError('type'),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Category'),
          Wrap(
            spacing: RfSpace.s2,
            runSpacing: RfSpace.s1,
            children: [
              for (final c in ExerciseCategory.values)
                ChoiceChip(
                  key: Key('category-${c.name}'),
                  label: Text(exerciseCategoryLabel(c)),
                  selected: _category == c,
                  onSelected: (v) => setState(() {
                    _category = v ? c : null;
                    _clearError('category');
                  }),
                ),
            ],
          ),
          _fieldError('category'),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Muscles'),
          ListTile(
            key: const Key('primary-muscle'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Primary muscle group'),
            subtitle: Text(
              _primary == null ? 'Choose' : muscleGroupLabel(_primary!),
              key: const Key('primary-muscle-value'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickPrimary,
          ),
          _fieldError('primary'),
          ListTile(
            key: const Key('secondary-muscles'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Secondary muscle groups'),
            subtitle: Text(
              _secondary.isEmpty
                  ? 'None'
                  : [
                      for (final m in MuscleGroup.values)
                        if (_secondary.contains(m)) muscleGroupLabel(m),
                    ].join(', '),
              key: const Key('secondary-muscles-value'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickSecondary,
          ),
          _fieldError('secondaryMuscles'),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Equipment'),
          ListTile(
            key: const Key('equipment'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Equipment needed'),
            subtitle: Text(
              equipmentSummary([
                for (final q in Equipment.values)
                  if (_equipment.contains(q)) q,
              ]),
              key: const Key('equipment-value'),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: _pickEquipment,
          ),
          _fieldError('equipment'),
          if (_errorField == '' && _error != null) ...[
            const SizedBox(height: RfSpace.s2),
            Text(
              _error!,
              key: const Key('error-general'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ],
          const SizedBox(height: RfSpace.s4),
          RfButton(
            key: const Key('exercise-save'),
            label: 'Save',
            loading: _busy,
            onPressed: _save,
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }
}
