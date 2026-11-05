import 'package:flutter/material.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/domain/training/training_validation.dart';
import 'package:repforge/domain/units/units.dart';
import 'package:repforge/features/training/presentation/set_defaults.dart';
import 'package:repforge/ui/components/rf_text_field.dart';
import 'package:repforge/ui/tokens.dart';

/// Field state of one set being logged or edited. It only turns text into
/// typed values; every rule (reps range, exertion range, load steps beyond
/// [LoadKg.of], rest, note) is applied by the use cases, so an invalid value
/// is rejected there and nothing is stored.
class SetFormController extends ChangeNotifier {
  SetFormController({
    required this.type,
    SetDraft draft = const SetDraft(),
    SetKind kind = SetKind.working,
    String exertion = '',
    String rest = '',
    String note = '',
  }) : load = TextEditingController(text: draft.load),
       reps = TextEditingController(text: draft.reps),
       duration = TextEditingController(text: draft.duration),
       metres = TextEditingController(text: draft.metres),
       heartRate = TextEditingController(text: draft.heartRate),
       exertion = TextEditingController(text: exertion),
       rest = TextEditingController(text: rest),
       note = TextEditingController(text: note),
       // ignore: prefer_initializing_formals, the field is private
       _kind = kind;

  final ExerciseType type;
  final TextEditingController load;
  final TextEditingController reps;
  final TextEditingController duration;
  final TextEditingController metres;
  final TextEditingController heartRate;
  final TextEditingController exertion;
  final TextEditingController rest;
  final TextEditingController note;
  SetKind _kind;

  SetKind get kind => _kind;
  set kind(SetKind value) {
    if (value == _kind) return;
    _kind = value;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final c in [
      load,
      reps,
      duration,
      metres,
      heartRate,
      exertion,
      rest,
      note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  static double? _number(String text) =>
      double.tryParse(text.trim().replaceAll(',', '.'));

  static ValidationError _bad(String message, String field) =>
      ValidationError(message, field: field);

  Result<LoadKg?> _load({required bool required}) {
    final text = load.text.trim();
    if (text.isEmpty) {
      return required
          ? Err(_bad('Enter a load in kg.', 'loadKg'))
          : const Ok(null);
    }
    final v = _number(text);
    if (v == null) return Err(_bad('Enter a number.', 'loadKg'));
    return switch (LoadKg.of(v)) {
      Ok(:final value) => Ok(value),
      Err(:final error) => Err(error),
    };
  }

  Result<int> _reps() {
    final v = int.tryParse(reps.text.trim());
    return v == null ? Err(_bad('Enter the repetitions.', 'reps')) : Ok(v);
  }

  Result<Duration?> _duration({required bool required}) {
    if (!required && duration.text.trim().isEmpty) return const Ok(null);
    return switch (parseDuration(duration.text)) {
      Ok(:final value) => Ok(value),
      Err(:final error) => Err(error),
    };
  }

  Result<double> _metres() {
    final v = _number(metres.text);
    return v == null
        ? Err(_bad('Enter a distance in metres.', 'metres'))
        : Ok(v);
  }

  /// The set data typed so far, or the first problem found.
  Result<SetData> parseData() {
    switch (type) {
      case ExerciseType.weighted:
        final l = _load(required: true);
        if (l case Err(:final error)) return Err(error);
        final r = _reps();
        if (r case Err(:final error)) return Err(error);
        return Ok(
          SetData.weighted(
            load: (l as Ok<LoadKg?>).value!,
            reps: (r as Ok<int>).value,
          ),
        );
      case ExerciseType.bodyweight:
        final r = _reps();
        if (r case Err(:final error)) return Err(error);
        final l = _load(required: false);
        if (l case Err(:final error)) return Err(error);
        return Ok(
          SetData.bodyweight(
            reps: (r as Ok<int>).value,
            addedLoad: (l as Ok<LoadKg?>).value,
          ),
        );
      case ExerciseType.assisted:
        final r = _reps();
        if (r case Err(:final error)) return Err(error);
        final l = _load(required: true);
        if (l case Err(:final error)) return Err(error);
        return Ok(
          SetData.assisted(
            reps: (r as Ok<int>).value,
            assistance: (l as Ok<LoadKg?>).value!,
          ),
        );
      case ExerciseType.timed:
        final d = _duration(required: true);
        if (d case Err(:final error)) return Err(error);
        final l = _load(required: false);
        if (l case Err(:final error)) return Err(error);
        return Ok(
          SetData.timed(
            duration: (d as Ok<Duration?>).value!,
            addedLoad: (l as Ok<LoadKg?>).value,
          ),
        );
      case ExerciseType.distance:
        final m = _metres();
        if (m case Err(:final error)) return Err(error);
        final d = _duration(required: false);
        if (d case Err(:final error)) return Err(error);
        return Ok(
          SetData.distance(
            metres: (m as Ok<double>).value,
            duration: (d as Ok<Duration?>).value,
          ),
        );
      case ExerciseType.cardio:
        final d = _duration(required: true);
        if (d case Err(:final error)) return Err(error);
        final metresText = metres.text.trim();
        double? m;
        if (metresText.isNotEmpty) {
          m = _number(metresText);
          if (m == null) {
            return Err(_bad('Enter a distance in metres.', 'metres'));
          }
        }
        final hrText = heartRate.text.trim();
        int? hr;
        if (hrText.isNotEmpty) {
          hr = int.tryParse(hrText);
          if (hr == null) {
            return Err(_bad('Enter a whole number.', 'averageHeartRate'));
          }
        }
        return Ok(
          SetData.cardio(
            duration: (d as Ok<Duration?>).value!,
            metres: m,
            averageHeartRate: hr,
          ),
        );
    }
  }

  /// The typed exertion on [scale], null when empty; an unreadable value is a
  /// problem. Its range is checked by the use case.
  Result<Exertion?> parseExertion(ExertionScale scale) {
    final text = exertion.text.trim();
    if (text.isEmpty) return const Ok(null);
    final v = _number(text);
    if (v == null) return Err(_bad('Enter a number.', 'exertion'));
    return Ok(Exertion(scale: scale, value: v));
  }

  /// The typed rest in seconds, null when empty.
  Result<int?> parseRest() {
    final text = rest.text.trim();
    if (text.isEmpty) return const Ok(null);
    final v = int.tryParse(text);
    return v == null ? Err(_bad('Enter whole seconds.', 'restSeconds')) : Ok(v);
  }
}

/// Short label of a set kind.
String setKindLabel(SetKind k) => switch (k) {
  SetKind.warmUp => 'Warm-up',
  SetKind.working => 'Working',
  SetKind.failure => 'Failure',
};

/// Label of the exertion scale for the entry field.
String exertionFieldLabel(ExertionScale s) =>
    s == ExertionScale.rpe ? 'RPE (1–10)' : 'RIR (0–5)';

/// The data fields of a set for its exercise type. [keyPrefix] makes the keys
/// (`<prefix>load`, `<prefix>reps`, `<prefix>duration`, `<prefix>metres`,
/// `<prefix>hr`) unique per place; [errors] maps a use-case field name to the
/// message under the field. With [autofocusFirst] the first field takes focus
/// as soon as it is shown, which opens the numeric keyboard (TRN-018(2)).
class SetFormFields extends StatelessWidget {
  const SetFormFields({
    required this.controller,
    required this.keyPrefix,
    this.errors = const {},
    this.autofocusFirst = false,
    this.onChanged,
    super.key,
  });

  final SetFormController controller;
  final String keyPrefix;
  final Map<String, String> errors;
  final bool autofocusFirst;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    Widget load(String label, {bool first = false}) => RfTextField.number(
      key: Key('${keyPrefix}load'),
      controller: controller.load,
      label: label,
      unit: 'kg',
      decimals: 2,
      autofocus: first && autofocusFirst,
      errorText: errors['loadKg'],
      onChanged: (_) => onChanged?.call(),
    );
    Widget reps({bool first = false}) => RfTextField.integer(
      key: Key('${keyPrefix}reps'),
      controller: controller.reps,
      label: 'Reps',
      autofocus: first && autofocusFirst,
      errorText: errors['reps'],
      onChanged: (_) => onChanged?.call(),
    );
    Widget duration(String label, {bool first = false}) => RfTextField(
      key: Key('${keyPrefix}duration'),
      controller: controller.duration,
      label: label,
      hint: 'mm:ss',
      keyboardType: TextInputType.datetime,
      autofocus: first && autofocusFirst,
      errorText: errors['duration'],
      onChanged: (_) => onChanged?.call(),
    );
    Widget metres({bool first = false}) => RfTextField.number(
      key: Key('${keyPrefix}metres'),
      controller: controller.metres,
      label: 'Distance',
      unit: 'm',
      autofocus: first && autofocusFirst,
      errorText: errors['metres'],
      onChanged: (_) => onChanged?.call(),
    );
    Widget row(Widget a, [Widget? b]) => Padding(
      padding: const EdgeInsets.only(bottom: RfSpace.s2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: a),
          if (b != null) ...[
            const SizedBox(width: RfSpace.s2),
            Expanded(child: b),
          ],
        ],
      ),
    );
    return switch (controller.type) {
      ExerciseType.weighted => row(load('Weight', first: true), reps()),
      ExerciseType.bodyweight => row(reps(first: true), load('Added load')),
      ExerciseType.assisted => row(reps(first: true), load('Assistance')),
      ExerciseType.timed => row(
        duration('Time', first: true),
        load('Added load'),
      ),
      ExerciseType.distance => row(
        metres(first: true),
        duration('Time (optional)'),
      ),
      ExerciseType.cardio => Column(
        children: [
          row(duration('Time', first: true), metres()),
          row(
            RfTextField.integer(
              key: Key('${keyPrefix}hr'),
              controller: controller.heartRate,
              label: 'Heart rate',
              unit: 'bpm',
              errorText: errors['averageHeartRate'],
              onChanged: (_) => onChanged?.call(),
            ),
          ),
        ],
      ),
    };
  }
}

/// Kind, exertion, rest and note of a set (TRN-019, TRN-020, TRN-021).
class SetExtraFields extends StatelessWidget {
  const SetExtraFields({
    required this.controller,
    required this.keyPrefix,
    required this.scale,
    this.errors = const {},
    super.key,
  });

  final SetFormController controller;
  final String keyPrefix;

  /// Scale of the exertion field: the settings scale for a new entry, the
  /// stored scale for a set that has an exertion (TRN-020).
  final ExertionScale scale;
  final Map<String, String> errors;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          label: 'Set type',
          child: Wrap(
            spacing: RfSpace.s2,
            runSpacing: RfSpace.s1,
            children: [
              for (final k in SetKind.values)
                ChoiceChip(
                  key: Key('${keyPrefix}kind-${k.name}'),
                  label: Text(setKindLabel(k)),
                  selected: controller.kind == k,
                  onSelected: (_) => controller.kind = k,
                ),
            ],
          ),
        ),
        const SizedBox(height: RfSpace.s2),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: RfTextField.number(
                key: Key('${keyPrefix}exertion'),
                controller: controller.exertion,
                label: exertionFieldLabel(scale),
                errorText: errors['exertion'],
              ),
            ),
            const SizedBox(width: RfSpace.s2),
            Expanded(
              child: RfTextField.integer(
                key: Key('${keyPrefix}rest'),
                controller: controller.rest,
                label: 'Rest',
                unit: 's',
                errorText: errors['restSeconds'],
              ),
            ),
          ],
        ),
        const SizedBox(height: RfSpace.s2),
        RfTextField(
          key: Key('${keyPrefix}note'),
          controller: controller.note,
          label: 'Set note',
          maxLines: 2,
          errorText: errors['note'],
        ),
      ],
    ),
  );
}
