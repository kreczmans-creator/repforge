import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/app/router.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/daily_targets.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/nutrition/nutrition.dart';
import 'package:repforge/domain/settings/meal_labels.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/rest_alert_scheduler.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_rules.dart';
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

/// Help text under the exertion scale choice, from the rule's constants.
final _exertionNote =
    'RPE: rate of perceived exertion '
    '${TrainingRules.exertionRange(ExertionScale.rpe)} in steps of '
    '${TrainingRules.rpeStep}. RIR: reps in reserve '
    '${TrainingRules.exertionRange(ExertionScale.rir)}, whole numbers.';

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

  // Rest alert system state, re-read on start and on every resume (the user
  // can change it in system settings). Null until first read.
  AppLifecycleListener? _lifecycle;
  NotificationPermission? _permission;
  ExactTiming? _exact;
  int _statusGeneration = 0;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onResume: _refreshAlertState);
    unawaited(_refreshAlertState());
  }

  /// Reads notification permission and exact timing from the platform. A
  /// failing platform reads as blocked and not precise: nothing is claimed
  /// without proof.
  Future<void> _refreshAlertState() async {
    final generation = ++_statusGeneration;
    final scheduler = ref.read(restAlertSchedulerProvider);
    var permission = NotificationPermission.denied;
    var exact = ExactTiming.unavailable;
    try {
      permission = await scheduler.status();
    } on Object {
      // Counts as not allowed.
    }
    try {
      exact = await scheduler.exactTimingStatus();
    } on Object {
      // Counts as not precise.
    }
    if (!mounted || generation != _statusGeneration) return;
    setState(() {
      _permission = permission;
      _exact = exact;
    });
  }

  @override
  void dispose() {
    _lifecycle?.dispose();
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
    final result = await ref.read(updateSettingsProvider)(
      (s) => s.copyWith(defaultRestSeconds: seconds),
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

  /// Opens the backup screen. A restore replaces targets, meal names and
  /// preferences, so the fields are filled again from the stored values when
  /// the user comes back.
  Future<void> _openBackup() async {
    await context.push<void>(RfRoutes.settingsBackup);
    if (!mounted) return;
    setState(() {
      _seeded = false;
      _restSeeded = false;
      _mealsSeeded = false;
    });
  }

  /// Applies [change] to the settings as currently stored (not to the
  /// snapshot this widget was built with) so rapid successive changes do
  /// not overwrite each other.
  Future<void> _saveSettings(AppSettings Function(AppSettings) change) async {
    final result = await ref.read(updateSettingsProvider)(change);
    if (!mounted) return;
    if (result case Err(:final error)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(userMessageFor(error))));
    }
  }

  /// PLT-007: turning the switch on asks for permission and stays off when it
  /// is refused; turning it off cancels every scheduled rest alert.
  Future<void> _setRestNotifications(bool on) async {
    final scheduler = ref.read(restAlertSchedulerProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (on) {
      var permission = NotificationPermission.denied;
      try {
        permission = await scheduler.request();
      } on Object {
        // A failing platform counts as not allowed.
      }
      if (permission != NotificationPermission.granted) {
        if (!mounted) return;
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              key: const Key('rest-notifications-denied'),
              content: const Text(
                'Notifications are not allowed, so the switch stays off. '
                'Allow them for RepForge in system settings to get rest '
                'alerts in the background.',
              ),
              action: SnackBarAction(
                label: 'Open settings',
                onPressed: () {
                  unawaited(scheduler.openSettings().catchError((_) => false));
                },
              ),
            ),
          );
        return;
      }
      await _saveSettings((s) => s.copyWith(restTimerNotifications: true));
      await _refreshAlertState();
      if (!mounted || _exact != ExactTiming.unavailable) return;
      await _offerExactTiming(scheduler);
      return;
    }
    await _saveSettings((s) => s.copyWith(restTimerNotifications: false));
    try {
      await scheduler.cancelAll();
    } on Object {
      // Nothing may block turning the setting off.
    }
    await _refreshAlertState();
  }

  /// OQ-24: explains why exact-alarm access helps and offers the system
  /// route. Declining keeps the notifications on, delivered inexactly.
  Future<void> _offerExactTiming(RestAlertScheduler scheduler) async {
    final allow = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('exact-timing-dialog'),
        title: const Text('Allow precise timing?'),
        content: const Text(
          'Letting RepForge set exact alarms makes Android deliver the rest '
          'notification more reliably when the rest ends. Without it the '
          'notification still arrives, but Android may delay it. Notifications '
          'stay on either way, and logging sets and the timer never depend '
          'on this.',
        ),
        actions: [
          TextButton(
            key: const Key('exact-timing-not-now'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Not now'),
          ),
          FilledButton(
            key: const Key('exact-timing-allow'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Allow precise timing'),
          ),
        ],
      ),
    );
    if (allow ?? false) await _openExactTimingRoute(scheduler);
  }

  /// Opens the system exact-alarm screen, then reads the result from the
  /// platform (the call itself is not trusted).
  Future<void> _openExactTimingRoute(RestAlertScheduler scheduler) async {
    try {
      await scheduler.requestExactTiming();
    } on Object {
      // A failure leaves the inexact fallback.
    }
    await _refreshAlertState();
  }

  /// The effective rest alert state as text, from the stored preference and
  /// what the system allows right now. Precise timing is claimed only when
  /// the platform says so at this moment.
  String? _alertStatusText(bool preferenceOn) {
    final permission = _permission;
    if (permission == null) return null;
    if (!preferenceOn) return 'Off';
    if (permission != NotificationPermission.granted) {
      return 'Blocked: notifications are off for RepForge in system '
          'settings, so no rest alerts arrive until you allow them.';
    }
    return switch (_exact) {
      ExactTiming.available =>
        'On, with precise timing: Android can deliver the notification when '
            'the rest ends.',
      ExactTiming.unavailable =>
        'On, but timing may be delayed by Android. Allow precise timing for '
            'more reliable delivery.',
      _ => 'On',
    };
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
                    note: _exertionNote,
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
                      'Shows a notification when a rest ends while the app is '
                      'in the background. Off until you allow notifications. '
                      'The timer always alerts while the app is open, and its '
                      'time is right even if no notification arrives.',
                    ),
                    value: s.restTimerNotifications,
                    onChanged: _setRestNotifications,
                  ),
                  ..._alertStatus(s.restTimerNotifications),
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
                  'automatic cloud backup. Use a backup file to keep a copy '
                  'or to move to another device.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: RfSpace.s3),
                RfButton(
                  key: const Key('open-backup'),
                  label: 'Backup and restore',
                  variant: RfButtonVariant.secondary,
                  icon: Icons.backup_outlined,
                  onPressed: _openBackup,
                ),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s4),
          const RfSectionHeader(title: 'Delivery'),
          RfCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Decisions, approvals and checks the delivery needs from '
                  'you, and anything that blocks it, in one place.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: RfSpace.s3),
                RfButton(
                  key: const Key('open-owner-actions'),
                  label: 'Owner Actions & Delivery Blockers',
                  variant: RfButtonVariant.secondary,
                  icon: Icons.checklist_outlined,
                  onPressed: () =>
                      context.push<void>(RfRoutes.settingsOwnerActions),
                ),
              ],
            ),
          ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }

  /// Status line of the rest alerts and the action that fixes it.
  List<Widget> _alertStatus(bool preferenceOn) {
    final text = _alertStatusText(preferenceOn);
    if (text == null) return const [];
    final scheduler = ref.read(restAlertSchedulerProvider);
    final blocked =
        preferenceOn && _permission != NotificationPermission.granted;
    final delayed =
        preferenceOn && !blocked && _exact == ExactTiming.unavailable;
    return [
      Text(
        text,
        key: const Key('rest-alerts-status'),
        style: Theme.of(context).textTheme.bodySmall
            ?.copyWith(color: blocked ? context.rf.alertText : null),
      ),
      if (blocked)
        TextButton(
          key: const Key('rest-alerts-open-settings'),
          onPressed: () {
            unawaited(scheduler.openSettings().catchError((_) => false));
          },
          child: const Text('Open settings'),
        ),
      if (delayed)
        TextButton(
          key: const Key('rest-alerts-allow-exact'),
          onPressed: () => unawaited(_openExactTimingRoute(scheduler)),
          child: const Text('Allow precise timing'),
        ),
    ];
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
