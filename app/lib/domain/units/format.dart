/// Formats a number with up to [maxDecimals] decimals, trimming trailing
/// zeros: 82.0 → "82", 82.40 → "82.4", 0.75 → "0.75" (with 2 decimals).
/// One definition for labels, validation messages, charts and forms.
String formatNumber(double v, {int maxDecimals = 1}) {
  if (v.isNaN || v.isInfinite) return '—';
  if (v == v.roundToDouble()) return v.toStringAsFixed(0);
  final s = v.toStringAsFixed(maxDecimals);
  return s.contains('.')
      ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')
      : s;
}

/// Whole-number form used in dense diary rows: 82.4 → "82".
String whole(double v) => formatNumber(v, maxDecimals: 0);
