import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/calendar_date.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/measurements/measurement_rules.dart';
import 'package:repforge/domain/measurements/measurement_site_help.dart';
import 'package:repforge/domain/measurements/measurements.dart';
import 'package:repforge/features/measurements/presentation/measurement_widgets.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/components/rf_card.dart';
import 'package:repforge/ui/components/rf_screen_title.dart';
import 'package:repforge/ui/components/rf_section_header.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Entry form for any subset of the 13 measurement types (BCM-001..004).
///
/// A blank field means "not measured": nothing is stored for it. Every field
/// error returned by the use case is shown next to its field. Values are typed
/// with up to two decimals so an off-step value such as 80.05 is rejected with
/// a message instead of a silently ignored key press.
class MeasurementEntryScreen extends ConsumerStatefulWidget {
  const MeasurementEntryScreen({super.key, this.focusSite});

  /// A site to show first (its field gets the focus); optional.
  final MeasurementSite? focusSite;

  @override
  ConsumerState<MeasurementEntryScreen> createState() =>
      _MeasurementEntryScreenState();
}

/// Left/right limb groups, in display order.
const List<(String, MeasurementSite, MeasurementSite)> _limbGroups = [
  ('Thigh', MeasurementSite.thighLeft, MeasurementSite.thighRight),
  ('Calf', MeasurementSite.calfLeft, MeasurementSite.calfRight),
  ('Biceps', MeasurementSite.bicepsLeft, MeasurementSite.bicepsRight),
  ('Forearm', MeasurementSite.forearmLeft, MeasurementSite.forearmRight),
];

const List<MeasurementSite> _coreSites = [
  MeasurementSite.neck,
  MeasurementSite.chest,
  MeasurementSite.waist,
  MeasurementSite.hips,
];

class _MeasurementEntryScreenState
    extends ConsumerState<MeasurementEntryScreen> {
  final Map<MeasurementSite, TextEditingController> _controllers = {
    for (final s in MeasurementSite.values) s: TextEditingController(),
  };
  final Map<MeasurementSite, FocusNode> _focus = <MeasurementSite, FocusNode>{
    for (final s in MeasurementSite.values) s: FocusNode(),
  };
  final _note = TextEditingController();
  final GlobalKey _whenKey = GlobalKey();
  String? _summary;
  final _helpShown = <MeasurementSite>{};

  late CalendarDate _date;
  late TimeOfDay _time;
  bool _timeTouched = false;
  bool _saving = false;
  Map<String, String> _errors = const {};
  String? _generalError;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider).now();
    _date = CalendarDate.fromInstant(now);
    final at = defaultRecordedAt(_date, now);
    _time = TimeOfDay(hour: at.hour, minute: at.minute);
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    for (final f in _focus.values) {
      f.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  void _pickDate(CalendarDate d) {
    setState(() {
      _date = d;
      _errors = {..._errors}..remove('recordedAt');
      if (!_timeTouched) {
        final at = defaultRecordedAt(d, ref.read(clockProvider).now());
        _time = TimeOfDay(hour: at.hour, minute: at.minute);
      }
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _errors = const {};
      _generalError = null;
      _summary = null;
    });
    final recordedAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    final result = await ref.read(recordMeasurementEntryProvider)(
      values: {for (final e in _controllers.entries) e.key: e.value.text},
      recordedAt: recordedAt,
      note: _note.text,
    );
    if (!mounted) return;
    switch (result) {
      case Ok(:final value):
        final n = value.length;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saved $n ${n == 1 ? 'measurement' : 'measurements'}',
            ),
          ),
        );
        if (context.canPop()) {
          context.pop(true);
        } else {
          setState(() {
            _saving = false;
            for (final c in _controllers.values) {
              c.clear();
            }
            _note.clear();
          });
        }
      case Err(:final error):
        setState(() {
          _saving = false;
          if (error case ValidationError(:final fieldErrors)
              when fieldErrors.isNotEmpty) {
            _errors = fieldErrors;
          } else if (error case ValidationError(:final field?)) {
            _errors = {field: error.message};
          } else {
            _generalError = userMessageFor(error);
          }
          if (_errors.containsKey('values')) {
            _generalError = _errors['values'];
          }
        });
        _reportErrors();
    }
  }

  /// Display order of the fields, top to bottom.
  static const List<MeasurementSite> _order = [
    MeasurementSite.weight,
    ..._coreSites,
    MeasurementSite.thighLeft,
    MeasurementSite.thighRight,
    MeasurementSite.calfLeft,
    MeasurementSite.calfRight,
    MeasurementSite.bicepsLeft,
    MeasurementSite.bicepsRight,
    MeasurementSite.forearmLeft,
    MeasurementSite.forearmRight,
  ];

  /// After a failed save: a summary next to Save, an announcement for screen
  /// readers, and the first field with an error scrolled into view and
  /// focused (errors can be off screen on a phone).
  void _reportErrors() {
    final names = <String>[
      if (_errors.containsKey('recordedAt')) 'Date and time',
      for (final s in _order)
        if (_errors.containsKey(s.name)) s.label,
    ];
    if (names.isEmpty) return;
    final n = names.length;
    final summary =
        '$n ${n == 1 ? 'field needs' : 'fields need'} attention: '
        '${names.join(', ')}';
    setState(() => _summary = summary);
    unawaited(
      SemanticsService.sendAnnouncement(
        View.of(context),
        summary,
        Directionality.of(context),
        assertiveness: Assertiveness.assertive,
      ),
    );
    if (_errors.containsKey('recordedAt')) {
      final ctx = _whenKey.currentContext;
      if (ctx != null) Scrollable.ensureVisible(ctx);
      return;
    }
    for (final s in _order) {
      if (_errors.containsKey(s.name)) {
        final ctx = _focus[s]!.context;
        if (ctx != null) {
          Scrollable.ensureVisible(ctx, alignment: 0.3);
        }
        _focus[s]!.requestFocus();
        return;
      }
    }
  }

  Widget _field(MeasurementSite site) {
    final shown = _helpShown.contains(site);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RfTextField.number(
                key: Key('field-${site.name}'),
                controller: _controllers[site],
                focusNode: _focus[site],
                label: site.label,
                unit: site.unit,
                decimals: 2,
                autofocus: widget.focusSite == site,
                errorText: _errors[site.name],
                // Opened for quick weight logging: the keyboard's done key
                // saves.
                textInputAction: widget.focusSite == site
                    ? TextInputAction.done
                    : TextInputAction.next,
                onSubmitted: widget.focusSite == site ? (_) => _save() : null,
                onChanged: (_) {
                  if (_errors.containsKey(site.name)) {
                    setState(() {
                      _errors = {..._errors}..remove(site.name);
                      if (_errors.isEmpty) _summary = null;
                    });
                  }
                },
              ),
            ),
            IconButton(
              key: Key('info-${site.name}'),
              tooltip: 'How to measure: ${site.label}',
              icon: Icon(shown ? Icons.info : Icons.info_outline),
              constraints: const BoxConstraints(
                minWidth: rfMinTouchTarget,
                minHeight: rfMinTouchTarget,
              ),
              onPressed: () => setState(
                () => shown ? _helpShown.remove(site) : _helpShown.add(site),
              ),
            ),
          ],
        ),
        if (shown)
          Padding(
            key: Key('help-${site.name}'),
            padding: const EdgeInsets.only(bottom: RfSpace.sm),
            child: Text(
              site.helpText,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        const SizedBox(height: RfSpace.sm),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.watch(clockProvider).now();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Add measurements')),
      // Save sits in the body, below the scrolling form, so it rises above
      // the keyboard with the body (UXD-008(3)); a bottomNavigationBar would
      // stay under the keyboard.
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: RfSpace.gutter),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const RfScreenTitle(
                    title: 'Add measurements',
                    caption: 'Fill in what you measured. Leave the rest blank.',
                  ),
                  RfCard(
                    key: _whenKey,
                    child: WhenFields(
                      date: _date,
                      time: _time,
                      now: now,
                      errorText: _errors['recordedAt'],
                      onDate: _pickDate,
                      onTime: (t) => setState(() {
                        _time = t;
                        _timeTouched = true;
                        _errors = {..._errors}..remove('recordedAt');
                      }),
                    ),
                  ),
                  const SizedBox(height: RfSpace.s4),
                  const RfSectionHeader(title: 'Body weight'),
                  RfCard(child: _field(MeasurementSite.weight)),
                  const SizedBox(height: RfSpace.s4),
                  const RfSectionHeader(title: 'Core'),
                  RfCard(
                    child: Column(
                      children: [for (final s in _coreSites) _field(s)],
                    ),
                  ),
                  const SizedBox(height: RfSpace.s4),
                  const RfSectionHeader(title: 'Limbs, left and right'),
                  for (final (name, left, right) in _limbGroups) ...[
                    RfCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name.toUpperCase(),
                            style: context.rfText.kicker,
                          ),
                          const SizedBox(height: RfSpace.s2),
                          _field(left),
                          _field(right),
                        ],
                      ),
                    ),
                    const SizedBox(height: RfSpace.s3),
                  ],
                  const SizedBox(height: RfSpace.s1),
                  RfTextField(
                    key: const Key('note-input'),
                    controller: _note,
                    label: 'Note (optional)',
                    textInputAction: TextInputAction.done,
                  ),
                  const SizedBox(height: RfSpace.s6),
                ],
              ),
            ),
          ),
          Material(
            color: theme.scaffoldBackgroundColor,
            elevation: 8,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(RfSpace.s3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_summary != null || _generalError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: RfSpace.sm),
                        child: Text(
                          _summary ?? _generalError!,
                          key: const Key('entry-error'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    RfButton(
                      key: const Key('save-measurements'),
                      label: _saving ? 'Saving' : 'Save measurements',
                      loading: _saving,
                      onPressed: _save,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
