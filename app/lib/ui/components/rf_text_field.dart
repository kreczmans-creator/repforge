import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:repforge/ui/tokens.dart';

/// The app's text input. Use the named constructors for numbers so keyboard,
/// formatting and the unit suffix are consistent everywhere.
class RfTextField extends StatelessWidget {
  const RfTextField({
    required this.label,
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.helper,
    this.errorText,
    this.unit,
    this.keyboardType,
    this.inputFormatters,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.autofocus = false,
    this.enabled = true,
    this.maxLines = 1,
  });

  /// Decimal number such as a weight or a quantity. Accepts `.` or `,` as the
  /// decimal separator and at most [decimals] decimal places.
  RfTextField.number({
    required this.label,
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.helper,
    this.errorText,
    this.unit,
    int decimals = 1,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.autofocus = false,
    this.enabled = true,
  }) : keyboardType = TextInputType.numberWithOptions(decimal: decimals > 0),
       inputFormatters = [rfDecimalFormatter(decimals: decimals)],
       maxLines = 1;

  /// Whole number such as repetitions.
  RfTextField.integer({
    required this.label,
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.helper,
    this.errorText,
    this.unit,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.autofocus = false,
    this.enabled = true,
  }) : keyboardType = TextInputType.number,
       inputFormatters = [FilteringTextInputFormatter.digitsOnly],
       maxLines = 1;

  final String label;
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? helper;
  final String? errorText;

  /// Unit shown as a suffix, e.g. `kg`.
  final String? unit;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Replaces the default handling of the keyboard action (for `next`: the
  /// platform's focus traversal), for forms that choose the next field
  /// themselves.
  final VoidCallback? onEditingComplete;
  final bool autofocus;
  final bool enabled;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      onEditingComplete: onEditingComplete,
      autofocus: autofocus,
      enabled: enabled,
      maxLines: maxLines,
      style: theme.textTheme.bodyMedium,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        errorText: errorText,
        errorMaxLines: 3,
        suffixText: unit,
        suffixStyle: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Allows digits plus one `.` or `,` and up to [decimals] digits after it.
TextInputFormatter rfDecimalFormatter({int decimals = 1}) {
  final pattern = decimals > 0
      ? RegExp('^\\d*([.,]\\d{0,$decimals})?\$')
      : RegExp(r'^\d*$');
  return TextInputFormatter.withFunction(
    (oldValue, newValue) =>
        pattern.hasMatch(newValue.text) ? newValue : oldValue,
  );
}

/// Horizontal spacing between fields placed in a [Row].
const rfFieldGap = SizedBox(width: RfSpace.sm);
