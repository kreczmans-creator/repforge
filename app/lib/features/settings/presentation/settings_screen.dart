import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/settings/meal_labels.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/dashboard/application/dashboard_providers.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_states.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Settings: daily nutrition targets (persisted as goals) and app
/// preferences (persisted in the settings table).
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final Map<GoalKind, TextEditingController> _controllers = {
    for (final k in [
      GoalKind.calories,
      GoalKind.protein,
      GoalKind.carbs,
      GoalKind.fat,
      GoalKind.fibre,
    ])
      k: TextEditingController(),
  };
  bool _seeded = false;
  final _restController = TextEditingController();
  bool _restSeeded = false;
  String? _restError;
  final Map<MealSlot, TextEditingController> _mealControllers = {
    for (final m in MealSlot.values) m: TextEditingController(),
  };
  List<MealSlot> _mealOrder = List.of(MealSlot.values);
  bool _mealsSeeded = false;
  bool _savingMeals = false;
  String? _mealError;
  String? _mealErrorField;
  bool _savingTargets = false;
  String? _targetError;
  GoalKind? _targetErrorKind;

  @override
  void dispose() {
    _restController.dispose();
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final c in _mealControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _seed(DailyTargets t) {
    if (_seeded) return;
    _seeded = true;
    String s(double? v) => v == null ? '' : formatNumber(v);
    _controllers[GoalKind.calories]!.text = s(t.kcal);
    _controllers[GoalKind.protein]!.text = s(t.proteinG);
    _controllers[GoalKind.carbs]!.text = s(t.carbsG);
    _controllers[GoalKind.fat]!.text = s(t.fatG);
    _controllers[GoalKind.fibre]!.text = s(t.fibreG);
  }

  void _seedRest(AppSettings s) {
    if (_restSeeded) return;
    _restSeeded = true;
    _restController.text = '${s.defaultRestSeconds}';
  }

  Future<void> _saveRest() async {
    final seconds = int.tryParse(_restController.text.trim());
    if (seconds == null) {
      setState(() => _restError = 'Enter whole seconds, 0 to 3600.');
      return;
    }
    setState(() => _restError = null);
    final current = await ref.read(settingsRepositoryProvider).read();
    final result = await ref.read(saveSettingsProvider)(
      current.copyWith(defaultRestSeconds: seconds),
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Default rest saved')));
      case Err(:final error):
        setState(() => _restError = userMessageFor(error));
    }
  }

  void _seedMeals(MealLabels labels) {
    if (_mealsSeeded) return;
    _mealsSeeded = true;
    _mealOrder = List.of(labels.order);
    for (final m in MealSlot.values) {
      _mealControllers[m]!.text = labels.labelOf(m);
    }
  }

  void _moveMeal(int index, int delta) {
    final to = index + delta;
    if (to < 0 || to >= _mealOrder.length) return;
    setState(() {
      final item = _mealOrder.removeAt(index);
      _mealOrder.insert(to, item);
      _mealError = null;
      _mealErrorField = null;
    });
  }

  Future<void> _saveMeals() async {
    if (_savingMeals) return;
    setState(() {
      _savingMeals = true;
      _mealError = null;
      _mealErrorField = null;
    });
    final result = await ref.read(saveMealLabelsProvider)(
      labels: {for (final e in _mealControllers.entries) e.key: e.value.text},
      order: _mealOrder,
    );
    if (!mounted) return;
    setState(() => _savingMeals = false);
    switch (result) {
      case Ok():
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Meal names saved')));
      case Err(:final error):
        setState(() {
          _mealError = userMessageFor(error);
          _mealErrorField = error is ValidationError ? error.field : null;
        });
    }
  }

  Future<void> _saveTargets() async {
    if (_savingTargets) return;
    setState(() {
      _savingTargets = true;
      _targetError = null;
      _targetErrorKind = null;
    });
    final result = await ref.read(saveDailyTargetsProvider)(
      input: {for (final e in _controllers.entries) e.key: e.value.text},
    );
    if (!mounted) return;
    setState(() => _savingTargets = false);
    switch (result) {
      case Ok():
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Targets saved')));
      case Err(:final error):
        setState(() {
          _targetError = userMessageFor(error);
          _targetErrorKind = error is ValidationError
              ? GoalKind.values.asNameMap()[error.field ?? '']
              : null;
        });
    }
  }

  /// Applies [change] to the settings as currently stored (not to the
  /// snapshot this widget was built with) so rapid successive changes do
  /// not overwrite each other.
  Future<void> _saveSettings(AppSettings Function(AppSettings) change) async {
    final current = await ref.read(settingsRepositoryProvider).read();
    final result = await ref.read(saveSettingsProvider)(change(current));
    if (!mounted) return;
    if (result case Err(:final error)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targets = ref.watch(dailyTargetsProvider);
    final settings = ref.watch(settingsProvider);
    targets.whenData(_seed);
    settings.whenData(_seedRest);
    ref.watch(mealLabelsProvider).whenData(_seedMeals);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          const RfScreenTitle(
            title: 'Settings',
            caption: 'Targets, units and preferences',
          ),
          const RfSectionHeader(title: 'Daily targets'),
          targets.when(
            loading: () => const RfLoading(),
            error: (e, _) =>
                const RfErrorState(message: 'Could not load targets.'),
            data: (_) => RfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Leave a field blank to clear that target.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: RfSpace.s3),
                  _targetField(GoalKind.calories, 'Calories', 'kcal'),
                  const SizedBox(height: RfSpace.s3),
                  Row(
                    children: [
                      Expanded(
                        child: _targetField(GoalKind.protein, 'Protein', 'g'),
                      ),
                      rfFieldGap,
                      Expanded(
                        child: _targetField(GoalKind.carbs, 'Carbs', 'g'),
                      ),
                    ],
                  ),
                  const SizedBox(height: RfSpace.s3),
                  Row(
                    children: [
                      Expanded(child: _targetField(GoalKind.fat, 'Fat', 'g')),
                      rfFieldGap,
                      Expanded(
                        child: _targetField(GoalKind.fibre, 'Fibre', 'g'),
                      ),
                    ],
                  ),
                  if (_targetError != null && _targetErrorKind == null) ...[
                    const SizedBox(height: RfSpace.s2),
                    Text(
                      _targetError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.rf.alertText,
                      ),
                    ),
                  ],
                  const SizedBox(height: RfSpace.s4),
                  RfButton(
                    key: const Key('save-targets'),
                    label: 'Save targets',
                    loading: _savingTargets,
                    onPressed: _saveTargets,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Meals'),
          RfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Rename your meals and choose their order. Existing '
                  'entries follow the new names.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: RfSpace.s3),
                for (var i = 0; i < _mealOrder.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: RfSpace.s2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: RfTextField(
                            key: Key('meal-label-${_mealOrder[i].name}'),
                            controller: _mealControllers[_mealOrder[i]],
                            label: 'Meal ${i + 1}',
                            errorText: _mealErrorField == _mealOrder[i].name
                                ? _mealError
                                : null,
                            onChanged: (_) => setState(() {
                              _mealError = null;
                              _mealErrorField = null;
                            }),
                          ),
                        ),
                        IconButton(
                          key: Key('meal-up-${_mealOrder[i].name}'),
                          tooltip: 'Move up',
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: i == 0 ? null : () => _moveMeal(i, -1),
                        ),
                        IconButton(
                          key: Key('meal-down-${_mealOrder[i].name}'),
                          tooltip: 'Move down',
                          icon: const Icon(Icons.arrow_downward),
                          onPressed: i == _mealOrder.length - 1
                              ? null
                              : () => _moveMeal(i, 1),
                        ),
                      ],
                    ),
                  ),
                if (_mealError != null &&
                    !MealSlot.values.any((m) => m.name == _mealErrorField))
                  Text(
                    _mealError!,
                    key: const Key('meal-error'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.rf.alertText,
                    ),
                  ),
                const SizedBox(height: RfSpace.s2),
                RfButton(
                  key: const Key('save-meals'),
                  label: 'Save meal names',
                  loading: _savingMeals,
                  onPressed: _saveMeals,
                ),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Preferences'),
          settings.when(
            loading: () => const RfLoading(),
            error: (e, _) =>
                const RfErrorState(message: 'Could not load settings.'),
            data: (s) => RfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _choice<UnitSystem>(
                    key: const Key('units-choice'),
                    label: 'Units',
                    value: s.units,
                    options: const {
                      UnitSystem.metric: 'Metric',
                      UnitSystem.imperial: 'Imperial',
                    },
                    onChanged: (v) =>
                        _saveSettings((s) => s.copyWith(units: v)),
                    note:
                        'Stored in metric. Imperial changes how weights are '
                        'shown; entry stays in kg for now.',
                  ),
                  const SizedBox(height: RfSpace.s4),
                  _choice<ThemePreference>(
                    key: const Key('theme-choice'),
                    label: 'Theme',
                    value: s.theme,
                    options: const {
                      ThemePreference.dark: 'Dark',
                      ThemePreference.light: 'Light',
                      ThemePreference.system: 'System',
                    },
                    onChanged: (v) =>
                        _saveSettings((s) => s.copyWith(theme: v)),
                  ),
                  const SizedBox(height: RfSpace.s4),
                  _choice<ExertionScale>(
                    key: const Key('exertion-choice'),
                    label: 'Effort scale',
                    value: s.exertionScale,
                    options: const {
                      ExertionScale.rpe: 'RPE',
                      ExertionScale.rir: 'RIR',
                    },
                    onChanged: (v) =>
                        _saveSettings((s) => s.copyWith(exertionScale: v)),
                    note:
                        'RPE: rate of perceived exertion 1–10 in steps '
                        'of 0.5. RIR: reps in reserve 0–5, whole numbers.',
                  ),
                  const SizedBox(height: RfSpace.s4),
                  _choice<int>(
                    key: const Key('week-start-choice'),
                    label: 'Week starts on',
                    value: s.weekStartDay,
                    options: const {1: 'Monday', 7: 'Sunday'},
                    onChanged: (v) =>
                        _saveSettings((s) => s.copyWith(weekStartDay: v)),
                  ),
                  const SizedBox(height: RfSpace.s4),
                  Text('REST TIMER', style: context.rfText.kicker),
                  const SizedBox(height: RfSpace.s2),
                  RfTextField.integer(
                    key: const Key('default-rest'),
                    controller: _restController,
                    label: 'Default rest',
                    unit: 's',
                    helper:
                        'Used when a set has no planned rest (0 to 3600 s).',
                    errorText: _restError,
                    onChanged: (_) {
                      if (_restError != null) {
                        setState(() => _restError = null);
                      }
                    },
                  ),
                  const SizedBox(height: RfSpace.s2),
                  RfButton(
                    key: const Key('save-default-rest'),
                    label: 'Save default rest',
                    variant: RfButtonVariant.secondary,
                    onPressed: _saveRest,
                  ),
                  const SizedBox(height: RfSpace.s2),
                  SwitchListTile(
                    key: const Key('rest-notifications-switch'),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Rest timer notifications'),
                    subtitle: const Text(
                      'Saves your choice only. Alerts when the app is in the '
                      'background arrive in a later update; for now the timer '
                      'alerts while the app is open.',
                    ),
                    value: s.restTimerNotifications,
                    onChanged: (v) => _saveSettings(
                      (s) => s.copyWith(restTimerNotifications: v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Data'),
          RfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Local-first storage', style: theme.textTheme.titleMedium),
                const SizedBox(height: RfSpace.s1),
                Text(
                  'Everything is stored on this device only. The database is '
                  'protected by your device lock and is excluded from '
                  'automatic cloud backup. Export and restore arrive in a '
                  'later work package.',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }

  Widget _targetField(GoalKind kind, String label, String unit) =>
      RfTextField.number(
        key: Key('target-${kind.name}'),
        controller: _controllers[kind],
        label: label,
        unit: unit,
        decimals: 0,
        errorText: _targetErrorKind == kind ? _targetError : null,
        onChanged: (_) {
          if (_targetError != null) {
            setState(() {
              _targetError = null;
              _targetErrorKind = null;
            });
          }
        },
      );

  Widget _choice<T>({
    required Key key,
    required String label,
    required T value,
    required Map<T, String> options,
    required ValueChanged<T> onChanged,
    String? note,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: context.rfText.kicker),
        const SizedBox(height: RfSpace.s2),
        SegmentedButton<T>(
          key: key,
          showSelectedIcon: false,
          segments: [
            for (final e in options.entries)
              ButtonSegment<T>(value: e.key, label: Text(e.value)),
          ],
          selected: {value},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
        if (note != null) ...[
          const SizedBox(height: RfSpace.s1),
          Text(note, style: theme.textTheme.bodySmall),
        ],
      ],
    );
  }
}
