/// Parses typed text as a plain non-negative decimal: digits with an optional
/// fractional part, `.` or `,` as the separator (`82.4`, ` 82,4 `, `80`).
///
/// Returns null for anything else: empty text, signs (`+80`, `-80`), an
/// exponent (`1e2`), `NaN`/`Infinity`, hex, a missing digit (`80.`, `.5`),
/// grouping or letters. Range and step checks stay with the caller.
double? parsePlainDecimal(String text) {
  final cleaned = text.trim();
  if (!RegExp(r'^\d+([.,]\d+)?$').hasMatch(cleaned)) return null;
  return double.tryParse(cleaned.replaceAll(',', '.'));
}
