import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_validation.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/exercise_library_providers.dart';
import 'package:repforge/features/training/application/plan_providers.dart';
import 'package:repforge/features/training/application/training_providers.dart';
import 'package:repforge/features/training/presentation/exercise_picker.dart';
import 'package:repforge/features/training/presentation/set_format.dart';
import 'package:repforge/features/training/presentation/training_labels.dart';
import 'package:repforge/features/training/presentation/unsaved_changes.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

const Set<ExerciseType> _repTypes = {
  ExerciseType.weighted,
  ExerciseType.bodyweight,
  ExerciseType.assisted,
};
const Set<ExerciseType> _durationTypes = {
  ExerciseType.timed,
  ExerciseType.distance,
  ExerciseType.cardio,
};
const Set<ExerciseType> _distanceTypes = {
  ExerciseType.distance,
  ExerciseType.cardio,
};
const Set<ExerciseType> _loadTypes = {
  ExerciseType.weighted,
  ExerciseType.bodyweight,
  ExerciseType.assisted,
  ExerciseType.timed,
};

/// Field names the use case reports, mapped to the row field that shows them.
const _fieldAlias = {
  'targetDuration': 'duration',
  'targetMetres': 'metres',
  'loadKg': 'load',
};

/// One exercise of the plan being edited: its inputs and any errors.
class _PlanRow {
  _PlanRow(this.token, this.exerciseId, {this.id = '', String sets = '3'})
    : sets = TextEditingController(text: sets);

  /// Stable identity for the list (reordering moves the row, not its index).
  final int token;
  final String id;
  final String exerciseId;
  final TextEditingController sets;
  final repsMin = TextEditingController();
  final repsMax = TextEditingController();
  final duration = TextEditingController();
  final distance = TextEditingController();
  final load = TextEditingController();
  final rest = TextEditingController();
  final Map<String, String> errors = {};

  String get signature => [
    exerciseId,
    sets.text,
    repsMin.text,
    repsMax.text,
    duration.text,
    distance.text,
    load.text,
    rest.text,
  ].join('~');

  void dispose() {
    for (final c in [sets, repsMin, repsMax, duration, distance, load, rest]) {
      c.dispose();
    }
  }
}

/// Plan builder (TRN-013): a name and an ordered list of library exercises,
/// each with target sets, a rep range, a duration or a distance (by exercise
/// type), an optional target load and a rest period. Reorder by the drag
/// handle or by the move-up and move-down buttons. Pops with the saved plan.
/// With [planId] null a new plan is created.
class PlanEditorScreen extends ConsumerStatefulWidget {
  const PlanEditorScreen({super.key, this.planId});

  final String? planId;

  @override
  ConsumerState<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends ConsumerState<PlanEditorScreen> {
  final _name = TextEditingController();
  final _rows = <_PlanRow>[];
  var _nextToken = 0;
  WorkoutPlan? _existing;
  Set<String> _originalExerciseIds = {};
  late String _baseline = _signature();
  bool _seeded = false;
  bool _busy = false;
  String? _nameError;
  String? _generalError;

  bool get _isNew => widget.planId == null;

  @override
  void initState() {
    super.initState();
    if (_isNew) _seeded = true;
  }

  @override
  void dispose() {
    _name.dispose();
    for (final r in _rows) {
      r.dispose();
    }
    super.dispose();
  }

  String _signature() =>
      '${_name.text}|${[for (final r in _rows) r.signature].join('|')}';

  bool get _dirty => _signature() != _baseline;

  void _seed(WorkoutPlan plan) {
    if (_seeded) return;
    _seeded = true;
    _existing = plan;
    _originalExerciseIds = {for (final e in plan.exercises) e.exerciseId};
    _name.text = plan.name;
    for (final e in plan.exercises) {
      final row = _PlanRow(
        _nextToken++,
        e.exerciseId,
        id: e.id,
        sets: '${e.targetSets}',
      );
      row.repsMin.text = e.repsMin?.toString() ?? '';
      row.repsMax.text = e.repsMax?.toString() ?? '';
      row.duration.text = e.targetDuration == null
          ? ''
          : formatClock(e.targetDuration!);
      row.distance.text = e.targetMetres == null
          ? ''
          : formatNumber(e.targetMetres!);
      row.load.text = e.targetLoad == null
          ? ''
          : formatNumber(e.targetLoad!.value, maxDecimals: 2);
      row.rest.text = e.restSeconds?.toString() ?? '';
      _rows.add(row);
    }
    _baseline = _signature();
  }

  Future<void> _add() async {
    final picked = await pickExercise(context);
    if (picked == null || !mounted) return;
    setState(() {
      _rows.add(_PlanRow(_nextToken++, picked.id));
      _generalError = null;
    });
  }

  void _move(int from, int to) {
    if (reorder(_rows, from, to) case Ok(:final value)) {
      setState(() {
        _rows
          ..clear()
          ..addAll(value);
      });
    }
  }

  void _remove(int index) {
    setState(() {
      _rows.removeAt(index).dispose();
    });
  }

  /// Parses the typed inputs of [row]; row errors are recorded on the row.
  PlanExercise? _build(_PlanRow row, int index, ExerciseType type) {
    int? whole(TextEditingController c, String field, String message) {
      final t = c.text.trim();
      if (t.isEmpty) return null;
      final n = int.tryParse(t);
      if (n == null) row.errors[field] = message;
      return n;
    }

    double? number(TextEditingController c, String field) {
      final t = c.text.trim().replaceAll(',', '.');
      if (t.isEmpty) return null;
      final n = double.tryParse(t);
      if (n == null) row.errors[field] = 'Enter a number.';
      return n;
    }

    final sets = whole(row.sets, 'targetSets', 'Enter the number of sets.');
    if (sets == null && !row.errors.containsKey('targetSets')) {
      row.errors['targetSets'] = 'Enter the number of sets.';
    }
    int? repsMin;
    int? repsMax;
    if (_repTypes.contains(type)) {
      const msg = 'Enter whole numbers for the rep range.';
      repsMin = whole(row.repsMin, 'reps', msg);
      repsMax = whole(row.repsMax, 'reps', msg);
    }
    Duration? duration;
    if (_durationTypes.contains(type) && row.duration.text.trim().isNotEmpty) {
      switch (parseDuration(row.duration.text)) {
        case Ok(:final value):
          duration = value;
        case Err(:final error):
          row.errors['duration'] = error.message;
      }
    }
    double? metres;
    if (_distanceTypes.contains(type)) {
      metres = number(row.distance, 'metres');
    }
    LoadKg? load;
    if (_loadTypes.contains(type)) {
      final raw = number(row.load, 'load');
      if (raw != null) {
        switch (LoadKg.of(raw)) {
          case Ok(:final value):
            load = value;
          case Err(:final error):
            row.errors['load'] = error.message;
        }
      }
    }
    final rest = whole(row.rest, 'restSeconds', 'Enter whole seconds.');
    if (row.errors.isNotEmpty) return null;
    return PlanExercise(
      id: row.id,
      exerciseId: row.exerciseId,
      sortOrder: index,
      targetSets: sets!,
      repsMin: repsMin,
      repsMax: repsMax,
      targetDuration: duration,
      targetMetres: metres,
      targetLoad: load,
      restSeconds: rest,
    );
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _nameError = null;
      _generalError = null;
      for (final r in _rows) {
        r.errors.clear();
      }
    });
    if (_rows.isEmpty) {
      setState(() => _generalError = 'Add at least one exercise.');
      return;
    }
    final built = <PlanExercise>[];
    final types = <ExerciseType>[];
    var failed = false;
    for (var i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final exercise = ref.read(exerciseByIdProvider(row.exerciseId)).value;
      if (exercise == null) {
        row.errors['exerciseId'] = 'This exercise could not be loaded.';
        failed = true;
        continue;
      }
      final pe = _build(row, i, exercise.type);
      if (pe == null) {
        failed = true;
      } else {
        built.add(pe);
        types.add(exercise.type);
      }
    }
    if (failed) {
      setState(() {});
      return;
    }
    setState(() => _busy = true);
    final result = await ref.read(savePlanProvider)(
      id: widget.planId,
      name: _name.text,
      planExercises: built,
      // The builder does not edit these; keep what the plan already has.
      split: _existing?.split,
      scheduledWeekdays: _existing?.scheduledWeekdays ?? const [],
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        Navigator.of(context).pop(value);
      case Err(:final error):
        setState(() {
          _busy = false;
          _showSaveError(error, built, types);
        });
    }
  }

  /// Puts a use-case error next to the field (and row) it belongs to.
  void _showSaveError(
    AppError error,
    List<PlanExercise> built,
    List<ExerciseType> types,
  ) {
    final message = userMessageFor(error);
    if (error is! ValidationError) {
      _generalError = message;
      return;
    }
    final field = _fieldAlias[error.field] ?? error.field;
    if (field == 'name') {
      _nameError = message;
      return;
    }
    if (field == 'exerciseId') {
      for (final r in _rows) {
        final ex = ref.read(exerciseByIdProvider(r.exerciseId)).value;
        if (ex != null &&
            ex.archived &&
            !_originalExerciseIds.contains(r.exerciseId)) {
          r.errors['exerciseId'] = message;
          return;
        }
      }
    } else if (field != null) {
      for (var i = 0; i < built.length; i++) {
        if (validatePlanExercise(built[i], type: types[i]) is Err) {
          _rows[i].errors[field] = message;
          return;
        }
      }
    }
    _generalError = message;
  }

  @override
  Widget build(BuildContext context) {
    final title = _isNew ? 'New workout' : 'Edit workout';
    if (!_isNew && !_seeded) {
      final async = ref.watch(workoutPlanByIdProvider(widget.planId!));
      final plan = async.value;
      if (plan == null) {
        return Scaffold(
          appBar: AppBar(title: Text(title)),
          body: async.hasError
              ? const RfErrorState(message: 'Could not load the workout.')
              : async.isLoading
              ? const RfLoading()
              : const Padding(
                  padding: EdgeInsets.all(RfSpace.gutter),
                  child: RfEmptyState(
                    key: Key('plan-missing'),
                    message: 'That workout no longer exists.',
                  ),
                ),
        );
      }
      _seed(plan);
    }
    final theme = Theme.of(context);
    return UnsavedChangesGuard(
      dirty: _dirty && !_busy,
      child: Scaffold(
        appBar: AppBar(title: Text(title)),
        body: ReorderableListView(
          padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
          buildDefaultDragHandles: false,
          onReorderItem: _move,
          header: Padding(
            padding: const EdgeInsets.only(top: RfSpace.s3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RfTextField(
                  key: const Key('plan-name-field'),
                  controller: _name,
                  label: 'Workout name',
                  errorText: _nameError,
                  onChanged: (_) => setState(() => _nameError = null),
                ),
                const SizedBox(height: RfSpace.s4),
                const RfSectionHeader(title: 'Exercises'),
                if (_rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RfSpace.s2),
                    child: Text(
                      'No exercises yet. Add the first one below.',
                      key: const Key('plan-empty'),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
          footer: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: RfSpace.s2),
              RfButton(
                key: const Key('plan-add-exercise'),
                label: 'Add exercise',
                icon: Icons.add,
                variant: RfButtonVariant.secondary,
                onPressed: _add,
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
                key: const Key('plan-save'),
                label: 'Save workout',
                loading: _busy,
                onPressed: _save,
              ),
              const SizedBox(height: RfSpace.s8),
            ],
          ),
          children: [
            for (var i = 0; i < _rows.length; i++)
              Padding(
                key: ValueKey(_rows[i].token),
                padding: const EdgeInsets.only(bottom: RfSpace.s2),
                child: _PlanRowCard(
                  row: _rows[i],
                  index: i,
                  count: _rows.length,
                  onChanged: (field) => setState(() {
                    _rows[i].errors.remove(field);
                    _generalError = null;
                  }),
                  onMove: (to) => _move(i, to),
                  onRemove: () => _remove(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanRowCard extends ConsumerWidget {
  const _PlanRowCard({
    required this.row,
    required this.index,
    required this.count,
    required this.onChanged,
    required this.onMove,
    required this.onRemove,
  });

  final _PlanRow row;
  final int index;
  final int count;
  final ValueChanged<String> onChanged;
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseByIdProvider(row.exerciseId)).value;
    final name = exercise?.name ?? 'Exercise';
    final type = exercise?.type;
    final theme = Theme.of(context);

    Widget field(
      String key,
      String label,
      TextEditingController controller,
      String errorField, {
      bool decimal = false,
      String? unit,
      String? hint,
      bool text = false,
      bool showError = true,
    }) {
      void onChange(String _) => onChanged(errorField);
      final error = showError ? row.errors[errorField] : null;
      final fieldKey = Key('plan-$key-$index');
      if (text) {
        return RfTextField(
          key: fieldKey,
          controller: controller,
          label: label,
          hint: hint,
          unit: unit,
          errorText: error,
          keyboardType: TextInputType.datetime,
          onChanged: onChange,
        );
      }
      return decimal
          ? RfTextField.number(
              key: fieldKey,
              controller: controller,
              label: label,
              hint: hint,
              unit: unit,
              decimals: 2,
              errorText: error,
              onChanged: onChange,
            )
          : RfTextField.integer(
              key: fieldKey,
              controller: controller,
              label: label,
              hint: hint,
              unit: unit,
              errorText: error,
              onChanged: onChange,
            );
    }

    final fields = <Widget>[
      field('sets', 'Sets', row.sets, 'targetSets'),
      if (type != null && _repTypes.contains(type)) ...[
        field('reps-min', 'Reps from', row.repsMin, 'reps', showError: false),
        field('reps-max', 'Reps to', row.repsMax, 'reps'),
      ],
      if (type != null && _durationTypes.contains(type))
        field(
          'duration',
          'Duration',
          row.duration,
          'duration',
          text: true,
          hint: 'mm:ss',
        ),
      if (type != null && _distanceTypes.contains(type))
        field(
          'distance',
          'Distance',
          row.distance,
          'metres',
          decimal: true,
          unit: 'm',
        ),
      if (type != null && _loadTypes.contains(type))
        field(
          'load',
          type == ExerciseType.assisted
              ? 'Assistance'
              : type == ExerciseType.weighted
              ? 'Target load'
              : 'Added load',
          row.load,
          'load',
          decimal: true,
          unit: 'kg',
        ),
      field(
        'rest',
        'Rest',
        row.rest,
        'restSeconds',
        unit: 's',
        hint: 'Default',
      ),
    ];

    return RfCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                label: 'Drag to reorder $name',
                child: ReorderableDragStartListener(
                  key: Key('plan-drag-$index'),
                  index: index,
                  child: const SizedBox(
                    width: rfMinTouchTarget,
                    height: rfMinTouchTarget,
                    child: Icon(Icons.drag_handle),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: RfSpace.s3),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${index + 1}. $name',
                        key: Key('plan-exercise-name-$index'),
                        style: theme.textTheme.titleMedium,
                      ),
                      if (type != null)
                        Text(
                          [
                            exerciseTypeLabel(type),
                            if (exercise!.archived) 'Archived',
                          ].join(' · '),
                          style: context.rfText.caption,
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          Wrap(
            children: [
              IconButton(
                key: Key('plan-move-up-$index'),
                tooltip: 'Move $name up',
                icon: const Icon(Icons.arrow_upward),
                onPressed: index == 0 ? null : () => onMove(index - 1),
              ),
              IconButton(
                key: Key('plan-move-down-$index'),
                tooltip: 'Move $name down',
                icon: const Icon(Icons.arrow_downward),
                onPressed: index == count - 1 ? null : () => onMove(index + 1),
              ),
              IconButton(
                key: Key('plan-remove-$index'),
                tooltip: 'Remove $name',
                icon: const Icon(Icons.delete_outline),
                onPressed: onRemove,
              ),
            ],
          ),
          const SizedBox(height: RfSpace.s2),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = (constraints.maxWidth - RfSpace.s2) / 2;
              return Wrap(
                spacing: RfSpace.s2,
                runSpacing: RfSpace.s2,
                children: [
                  for (final f in fields) SizedBox(width: width, child: f),
                ],
              );
            },
          ),
          if (row.errors['exerciseId'] != null)
            Padding(
              padding: const EdgeInsets.only(top: RfSpace.s2),
              child: Text(
                row.errors['exerciseId']!,
                key: Key('plan-row-error-$index'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ),
        ],
      ),
    );
  }
}
