import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/analytics/analytics_period.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/goals/goals.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/features/analytics/application/analytics_providers.dart';
import 'package:repforge/features/analytics/application/goal_providers.dart';
import 'package:repforge/features/analytics/presentation/goal_labels.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Editor for one body weight, measurement or sessions-per-week goal
/// (GOL-003..005). One goal is active per kind, and per site for a
/// measurement goal; saving replaces it and the earlier target stays in the
/// target history.
class GoalEditorScreen extends ConsumerStatefulWidget {
  const GoalEditorScreen({required this.kind, super.key, this.site});

  final GoalKind kind;

  /// The body site of a measurement goal, when known.
  final MeasurementSite? site;

  @override
  ConsumerState<GoalEditorScreen> createState() => _GoalEditorScreenState();
}

class _GoalEditorScreenState extends ConsumerState<GoalEditorScreen> {
  final _target = TextEditingController();
  final _date = TextEditingController();
  MeasurementSite? _site;
  Goal? _existing;
  bool _loaded = false;
  bool _saving = false;
  String? _targetError;
  String? _dateError;
  String? _siteError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _site = widget.kind == GoalKind.measurement ? widget.site : null;
    unawaited(_loadExisting());
  }

  @override
  void dispose() {
    _target.dispose();
    _date.dispose();
    super.dispose();
  }

  bool get _needsSite => widget.kind == GoalKind.measurement;

  /// Reads the active goal of the kind (and chosen site) into the form.
  Future<void> _loadExisting() async {
    final site = _site;
    Goal? goal;
    if (!_needsSite || site != null) {
      final result = await ref
          .read(saveGoalProvider)
          .current(widget.kind, site: site);
      if (result case Ok(:final value)) goal = value;
    }
    if (!mounted || site != _site) return;
    setState(() {
      _existing = goal;
      _loaded = true;
      _target.text = goal == null ? '' : formatNumber(goal.target);
      _date.text = goal?.endDate == null ? '' : _dayOf(goal!.endDate!);
      _targetError = null;
      _dateError = null;
    });
  }

  static String _dayOf(DateTime d) => CalendarDate.fromInstant(d).iso;

  void _refreshAnalytics() {
    ref
      ..invalidate(goalProgressProvider)
      ..invalidate(targetHistoryProvider);
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _targetError = null;
      _dateError = null;
      _siteError = null;
      _error = null;
    });
    final result = await ref.read(saveGoalProvider)(
      kind: widget.kind,
      targetText: _target.text,
      site: _site,
      endDateText: _date.text,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        _refreshAnalytics();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Goal saved')));
        context.pop();
      case Err(:final error):
        setState(() {
          _saving = false;
          final field = error is ValidationError ? error.field : null;
          final text = userMessageFor(error);
          switch (field) {
            case 'target':
              _targetError = text;
            case 'endDate':
              _dateError = text;
            case 'site':
              _siteError = text;
            default:
              _error = text;
          }
        });
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        key: const Key('goal-clear-dialog'),
        title: const Text('Clear this goal?'),
        content: const Text(
          'The goal is removed from your progress. Its earlier targets stay '
          'in the target history.',
        ),
        actions: [
          TextButton(
            key: const Key('goal-clear-cancel'),
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            key: const Key('goal-clear-confirm'),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear goal'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final result = await ref
        .read(saveGoalProvider)
        .clear(widget.kind, site: _site);
    if (!mounted) return;
    switch (result) {
      case Ok():
        _refreshAnalytics();
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Goal cleared')));
        context.pop();
      case Err(:final error):
        setState(() {
          _saving = false;
          _error = userMessageFor(error);
        });
    }
  }

  String get _title => switch (widget.kind) {
    GoalKind.bodyWeight => 'Body weight goal',
    GoalKind.measurement => 'Measurement goal',
    _ => 'Sessions per week goal',
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unit = goalUnit(widget.kind, _site);
    return Scaffold(
      appBar: AppBar(title: Text(_title)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
        children: [
          RfScreenTitle(
            title: _title,
            caption: switch (widget.kind) {
              GoalKind.sessionsPerWeek =>
                'Completed workouts in a week, 0 to 14',
              GoalKind.measurement => 'A body measurement and its target',
              _ => 'Target weight, measured against the weight trend',
            },
          ),
          if (!_loaded)
            const Padding(
              padding: EdgeInsets.all(RfSpace.s6),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            RfCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_needsSite) ...[
                    DropdownButtonFormField<MeasurementSite>(
                      key: const Key('goal-site-choice'),
                      initialValue: _site,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: 'Body site',
                        errorText: _siteError,
                      ),
                      items: [
                        for (final s in MeasurementSite.values)
                          if (!s.isWeight)
                            DropdownMenuItem(
                              key: Key('goal-site-${s.name}'),
                              value: s,
                              child: Text(s.label),
                            ),
                      ],
                      onChanged: (s) {
                        setState(() {
                          _site = s;
                          _siteError = null;
                          _loaded = false;
                        });
                        unawaited(_loadExisting());
                      },
                    ),
                    const SizedBox(height: RfSpace.s3),
                  ],
                  _targetField(unit),
                  if (widget.kind == GoalKind.bodyWeight) ...[
                    const SizedBox(height: RfSpace.s2),
                    _DirectionNote(targetText: _target.text),
                  ],
                  if (widget.kind != GoalKind.sessionsPerWeek) ...[
                    const SizedBox(height: RfSpace.s3),
                    RfTextField(
                      key: const Key('goal-date-field'),
                      controller: _date,
                      label: 'Target date (optional)',
                      hint: 'YYYY-MM-DD',
                      helper: 'Leave blank for no date.',
                      keyboardType: TextInputType.datetime,
                      errorText: _dateError,
                      onChanged: (_) {
                        if (_dateError != null) {
                          setState(() => _dateError = null);
                        }
                      },
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: RfSpace.s3),
                    Text(
                      _error!,
                      key: const Key('goal-error'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: context.rf.alertText,
                      ),
                    ),
                  ],
                  const SizedBox(height: RfSpace.s4),
                  RfButton(
                    key: const Key('goal-save'),
                    label: _existing == null ? 'Save goal' : 'Replace goal',
                    loading: _saving,
                    onPressed: _save,
                  ),
                  if (_existing != null) ...[
                    const SizedBox(height: RfSpace.s2),
                    RfButton(
                      key: const Key('goal-clear'),
                      label: 'Clear goal',
                      variant: RfButtonVariant.danger,
                      onPressed: _saving ? null : _clear,
                    ),
                  ],
                ],
              ),
            ),
          const SizedBox(height: RfSpace.s8),
        ],
      ),
    );
  }

  Widget _targetField(String unit) {
    void changed(String _) => setState(() => _targetError = null);
    return switch (widget.kind) {
      GoalKind.sessionsPerWeek => RfTextField.integer(
        key: const Key('goal-target-field'),
        controller: _target,
        label: 'Sessions per week',
        unit: 'sessions',
        errorText: _targetError,
        onChanged: changed,
      ),
      _ => RfTextField.number(
        key: const Key('goal-target-field'),
        controller: _target,
        label: widget.kind == GoalKind.bodyWeight
            ? 'Target weight'
            : 'Target measurement',
        unit: unit,
        errorText: _targetError,
        onChanged: changed,
      ),
    };
  }
}

/// States the direction of a weight goal, derived from the trend value and
/// the typed target (plan decision 2a). Descriptive only.
class _DirectionNote extends ConsumerWidget {
  const _DirectionNote({required this.targetText});

  final String targetText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = CalendarDate.fromInstant(ref.watch(clockProvider).now());
    final summary = ref.watch(
      weightSummaryProvider(AnalyticsPeriod.custom(today.addDays(-29), today)),
    );
    final target = double.tryParse(targetText.trim().replaceAll(',', '.'));
    final style = context.rfText.caption;
    final String text;
    if (summary.isLoading) {
      text = 'Reading the weight trend…';
    } else if (summary.hasError) {
      text = 'The weight trend could not be read.';
    } else {
      final trend = summary.value?.latestTrend?.average;
      if (trend == null) {
        text =
            'Direction: not enough data. A weight trend value needs '
            'several readings.';
      } else if (target == null) {
        text = 'Current trend value ${trend.toStringAsFixed(1)} kg.';
      } else if ((target - trend).abs() < 0.05) {
        text =
            'The target ${target.toStringAsFixed(1)} kg equals the trend '
            'value ${trend.toStringAsFixed(1)} kg.';
      } else {
        final verb = target < trend ? 'decrease' : 'increase';
        text =
            'Direction: $verb, toward ${target.toStringAsFixed(1)} kg from '
            'the trend value ${trend.toStringAsFixed(1)} kg.';
      }
    }
    return Text(text, key: const Key('goal-direction'), style: style);
  }
}
