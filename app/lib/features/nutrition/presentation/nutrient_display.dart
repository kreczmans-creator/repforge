import 'package:repforge/domain/units/format.dart';

/// Text for a nutrient amount that may be unknown. Three states are kept
/// apart: a known value (including a known zero) prints its number, an
/// unknown value prints [unknownShort] ("n/a"), never 0. Absent targets are
/// handled by the callers ("no target"), not here.
const String unknownShort = 'n/a';

/// Long form for roomy layouts.
const String unknownLong = 'not available';

/// "12 g", or "n/a" when [value] is unknown.
String gramsOrNa(double? value, {int maxDecimals = 0, String unit = 'g'}) =>
    value == null
    ? unknownShort
    : '${formatNumber(value, maxDecimals: maxDecimals)} $unit';

/// Bare number, or "n/a" when [value] is unknown.
String numberOrNa(double? value, {int maxDecimals = 0}) => value == null
    ? unknownShort
    : formatNumber(value, maxDecimals: maxDecimals);

/// " · 2 unknown" when some inputs of a total lacked the value, else "".
String unknownMarker(int count) => count > 0 ? ' · $count unknown' : '';
