import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:repforge/app/providers.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/settings/settings.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/units/format.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/application/rest_timer_controller.dart';
import 'package:repforge/features/training/application/session_view.dart';
import 'package:repforge/features/training/application/training_providers.dart';
import 'package:repforge/features/training/presentation/set_defaults.dart';
import 'package:repforge/features/training/presentation/set_form.dart';
import 'package:repforge/features/training/presentation/set_format.dart';
import 'package:repforge/ui/components/rf_button.dart';
import 'package:repforge/ui/error_text.dart';
import 'package:repforge/ui/tokens.dart';

/// Where a use-case error is shown: under the named field, or as a general
/// message when no field matches.
({Map<String, String> fields, String? general}) splitError(
  AppError error,
  Set<String> known,
) {
  if (error is ValidationError && known.contains(error.field)) {
    return (fields: {error.field!: error.message}, general: null);
  }
  return (fields: const {}, general: userMessageFor(error));
}

const _fieldNames = {
  'loadKg',
  'reps',
  'duration',
  'metres',
  'averageHeartRate',
  'exertion',
  'restSeconds',
  'note',
};

const _extraFieldNames = {'exertion', 'restSeconds', 'note'};

/// The "PR" mark on a set that was a personal record (TRN-026).
class PrBadge extends StatelessWidget {
  const PrBadge({required this.setId, super.key});

  final String setId;

  @override
  Widget build(BuildContext context) {
    final rf = context.rf;
    return Semantics(
      label: 'Personal record',
      child: ExcludeSemantics(
        child: Container(
          key: Key('pr-badge-$setId'),
          padding: const EdgeInsets.symmetric(
            horizontal: RfSpace.s2,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: rf.accentSubtle,
            borderRadius: BorderRadius.circular(RfRadius.xs),
            border: Border.all(color: rf.accent),
          ),
          child: Text(
            'PR',
            style: context.rfText.meta.copyWith(color: rf.accentText),
          ),
        ),
      ),
    );
  }
}

/// A recorded set as a row with PR badge, edit and delete.
class LoggedSetRow extends StatelessWidget {
  const LoggedSetRow({
    required this.set,
    required this.number,
    required this.isRecord,
    required this.onEdit,
    required this.onDelete,
    super.key,
  });

  final SessionSet set;
  final int number;
  final bool isRecord;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final s = set;
    final details = [
      if (s.kind != SetKind.working) setKindLabel(s.kind),
      if (s.exertion != null) formatExertion(s.exertion!),
      if (s.restSeconds != null) 'rest ${s.restSeconds} s',
    ];
    return Semantics(
      container: true,
      label:
          'Set $number, ${formatSetData(s.data, UnitSystem.metric)}'
          '${isRecord ? ', personal record' : ''}',
      child: Row(
        key: Key('set-${s.id}'),
        children: [
          SizedBox(
            width: 52,
            child: ExcludeSemantics(
              child: Text('Set $number', style: context.rfText.caption),
            ),
          ),
          Expanded(
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    formatSetData(s.data, UnitSystem.metric),
                    key: Key('set-text-${s.id}'),
                  ),
                  if (details.isNotEmpty)
                    Text(
                      details.join(' · '),
                      key: Key('set-details-${s.id}'),
                      style: context.rfText.caption,
                    ),
                  if (s.note != null)
                    Text(
                      s.note!,
                      key: Key('set-note-${s.id}'),
                      style: context.rfText.caption,
                    ),
                ],
              ),
            ),
          ),
          if (isRecord) PrBadge(setId: s.id),
          IconButton(
            key: Key('set-edit-${s.id}'),
            tooltip: 'Edit set $number',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          IconButton(
            key: Key('set-delete-${s.id}'),
            tooltip: 'Delete set $number',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}

/// The row for the next set of an exercise entry. It starts with the values
/// of the previous set, the previous session or the plan (TRN-016(1)), so a
/// correct set is confirmed with one tap on [Log set] (TRN-018(1), UXD-008).
class NewSetRow extends ConsumerStatefulWidget {
  const NewSetRow({
    required this.sessionId,
    required this.entry,
    required this.exercise,
    required this.entrySets,
    required this.prefill,
    super.key,
  });

  final String sessionId;
  final SessionExercise entry;
  final Exercise exercise;
  final List<SessionSet> entrySets;
  final EntryPrefill? prefill;

  @override
  ConsumerState<NewSetRow> createState() => _NewSetRowState();
}

class _NewSetRowState extends ConsumerState<NewSetRow> {
  late final SetFormController _form = SetFormController(
    type: widget.exercise.type,
    draft: nextSetDraft(
      type: widget.exercise.type,
      entrySets: widget.entrySets,
      prefill: widget.prefill,
    ),
  );
  bool _details = false;
  bool _busy = false;
  Map<String, String> _errors = const {};
  String? _general;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _fail(AppError error) {
    final e = splitError(error, _fieldNames);
    setState(() {
      _errors = e.fields;
      _general = e.general;
      if (e.fields.keys.any(_extraFieldNames.contains)) _details = true;
    });
  }

  Future<void> _log() async {
    if (_busy) return;
    final settings = ref.read(settingsProvider).value ?? const AppSettings();
    final data = _form.parseData();
    final exertion = _form.parseExertion(settings.exertionScale);
    final rest = _form.parseRest();
    for (final r in [data, exertion, rest]) {
      if (r case Err(:final error)) {
        _fail(error);
        return;
      }
    }
    final restSeconds = (rest as Ok<int?>).value;
    final note = _form.note.text;
    setState(() {
      _busy = true;
      _errors = const {};
      _general = null;
    });
    final result = await ref.read(recordSetProvider)(
      sessionId: widget.sessionId,
      sessionExerciseId: widget.entry.id,
      data: (data as Ok<SetData>).value,
      kind: _form.kind,
      exertion: (exertion as Ok<Exertion?>).value,
      restSeconds: restSeconds,
      note: note.trim().isEmpty ? null : note,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        // Confirming a set starts the rest timer (TRN-021(1)).
        ref
            .read(restTimerProvider.notifier)
            .start(
              plannedRestSeconds:
                  restSeconds ?? widget.prefill?.target?.restSeconds,
              defaultRestSeconds: settings.defaultRestSeconds,
            );
        ref.invalidate(sessionViewProvider(widget.sessionId));
      case Err(:final error):
        setState(() => _busy = false);
        _fail(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final id = widget.entry.id;
    final scale =
        ref.watch(settingsProvider.select((s) => s.value?.exertionScale)) ??
        ExertionScale.rpe;
    return Column(
      key: Key('newset-$id'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SetFormFields(
          controller: _form,
          keyPrefix: 'newset-$id-',
          errors: _errors,
        ),
        if (_details) ...[
          SetExtraFields(
            controller: _form,
            keyPrefix: 'newset-$id-',
            scale: scale,
            errors: _errors,
          ),
          const SizedBox(height: RfSpace.s2),
        ],
        if (_general != null)
          Padding(
            padding: const EdgeInsets.only(bottom: RfSpace.s2),
            child: Text(
              _general!,
              key: Key('newset-error-$id'),
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: context.rf.alertText),
            ),
          ),
        Wrap(
          spacing: RfSpace.s2,
          runSpacing: RfSpace.s2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            RfButton(
              key: Key('newset-log-$id'),
              label: 'Log set',
              icon: Icons.check,
              expand: false,
              loading: _busy,
              onPressed: _log,
            ),
            RfButton(
              key: Key('newset-details-$id'),
              label: _details ? 'Hide details' : 'Type, effort, rest',
              variant: RfButtonVariant.tertiary,
              expand: false,
              onPressed: () => setState(() => _details = !_details),
            ),
          ],
        ),
      ],
    );
  }
}

/// Bottom sheet that edits one recorded set (TRN-024). The first field takes
/// focus on open, so the numeric keyboard is up (TRN-018(2)).
class EditSetSheet extends ConsumerStatefulWidget {
  const EditSetSheet({
    required this.sessionId,
    required this.set,
    required this.number,
    required this.exerciseName,
    super.key,
  });

  final String sessionId;
  final SessionSet set;
  final int number;
  final String exerciseName;

  @override
  ConsumerState<EditSetSheet> createState() => _EditSetSheetState();
}

class _EditSetSheetState extends ConsumerState<EditSetSheet> {
  late final SetFormController _form = SetFormController(
    type: widget.set.data.type,
    draft: SetDraft.fromData(widget.set.data),
    kind: widget.set.kind,
    exertion: widget.set.exertion == null
        ? ''
        : formatNumber(widget.set.exertion!.value),
    rest: widget.set.restSeconds == null ? '' : '${widget.set.restSeconds}',
    note: widget.set.note ?? '',
  );
  bool _busy = false;
  Map<String, String> _errors = const {};
  String? _general;

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  void _fail(AppError error) {
    final e = splitError(error, _fieldNames);
    setState(() {
      _busy = false;
      _errors = e.fields;
      _general = e.general;
    });
  }

  Future<void> _save() async {
    if (_busy) return;
    final s = widget.set;
    // A set keeps the scale it was recorded in (TRN-020(2)).
    final scale =
        s.exertion?.scale ??
        ref.read(settingsProvider).value?.exertionScale ??
        ExertionScale.rpe;
    final data = _form.parseData();
    final exertion = _form.parseExertion(scale);
    final rest = _form.parseRest();
    for (final r in [data, exertion, rest]) {
      if (r case Err(:final error)) {
        _fail(error);
        return;
      }
    }
    final ex = (exertion as Ok<Exertion?>).value;
    final restSeconds = (rest as Ok<int?>).value;
    final note = _form.note.text.trim();
    setState(() => _busy = true);
    final result = await ref.read(editSetProvider)(
      sessionId: widget.sessionId,
      setId: s.id,
      data: (data as Ok<SetData>).value,
      kind: _form.kind,
      exertion: ex,
      clearExertion: ex == null && s.exertion != null,
      restSeconds: restSeconds,
      clearRest: restSeconds == null && s.restSeconds != null,
      note: note.isEmpty ? null : note,
      clearNote: note.isEmpty && s.note != null,
    );
    if (!mounted) return;
    switch (result) {
      case Ok():
        Navigator.of(context).pop(true);
      case Err(:final error):
        _fail(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scale =
        widget.set.exertion?.scale ??
        ref.watch(settingsProvider.select((s) => s.value?.exertionScale)) ??
        ExertionScale.rpe;
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
            Semantics(
              header: true,
              child: Text(
                'Edit set ${widget.number} · ${widget.exerciseName}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: RfSpace.s3),
            SetFormFields(
              controller: _form,
              keyPrefix: 'editset-',
              errors: _errors,
              autofocusFirst: true,
            ),
            SetExtraFields(
              controller: _form,
              keyPrefix: 'editset-',
              scale: scale,
              errors: _errors,
            ),
            if (_general != null)
              Padding(
                padding: const EdgeInsets.only(top: RfSpace.s2),
                child: Text(
                  _general!,
                  key: const Key('editset-error'),
                  style: Theme.of(context).textTheme.bodySmall
                      ?.copyWith(color: context.rf.alertText),
                ),
              ),
            const SizedBox(height: RfSpace.s3),
            Wrap(
              spacing: RfSpace.s2,
              runSpacing: RfSpace.s2,
              children: [
                RfButton(
                  key: const Key('editset-save'),
                  label: 'Save set',
                  expand: false,
                  loading: _busy,
                  onPressed: _save,
                ),
                RfButton(
                  key: const Key('editset-cancel'),
                  label: 'Cancel',
                  variant: RfButtonVariant.secondary,
                  expand: false,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
