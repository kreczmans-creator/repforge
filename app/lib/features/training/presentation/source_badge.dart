import 'package:flutter/material.dart';
import 'package:repforge/domain/training/training.dart';
import 'package:repforge/ui/tokens.dart';

/// "Supplied" (ships with the app, read-only) or "Custom" (the user's own,
/// including copies) marker for an exercise (TRN-008(1)(2)).
class ExerciseSourceBadge extends StatelessWidget {
  const ExerciseSourceBadge(this.exercise, {super.key});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final rf = context.rf;
    final supplied = exercise.supplied;
    final color = supplied ? rf.infoText : rf.accentText;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(RfRadius.sm),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: RfSpace.s2,
          vertical: 2,
        ),
        child: Text(
          supplied ? 'Supplied' : 'Custom',
          style: context.rfText.caption.copyWith(color: color),
        ),
      ),
    );
  }
}
