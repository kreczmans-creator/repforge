/// The TRN-020 exertion rule (D04 TRN-020; plan section 21, safeguard C) as
/// a boolean SQL expression over the given column references.
///
/// The rule is per scale and invents no relationship between the scales:
/// - both columns NULL: no exertion recorded (exertion is optional);
/// - `rpe`: a value from 1 to 10 inclusive in steps of 0.5;
/// - `rir`: a whole number from 0 to 5 inclusive;
/// - anything else (another scale, a scale without a value, a value without
///   a scale, a non-numeric value) is refused.
///
/// The trailing `IS 1` makes the expression NULL-safe: it yields 1 or 0,
/// never NULL, so a CHECK built from it cannot pass by being NULL.
///
/// Ported unchanged in meaning from the 3b comparison trial
/// (`test/migration_trial/trial_db.dart`, `exertionRuleSql`); a test keeps
/// the two equal after whitespace normalisation. The schema v8 CHECK in
/// `tables_v8.dart` is this expression with the default column names
/// ([sessionSetsExertionCheck]); a test keeps them equal too.
String exertionRuleSql({
  String scale = 'exertion_scale',
  String value = 'exertion_value',
}) =>
    '(($scale IS NULL AND $value IS NULL) '
    "OR ($scale = 'rpe' AND $value BETWEEN 1 AND 10 "
    'AND $value * 2 = CAST($value * 2 AS INTEGER)) '
    "OR ($scale = 'rir' AND $value BETWEEN 0 AND 5 "
    'AND $value = CAST($value AS INTEGER))) IS 1';

/// The table constraint of `session_sets` in schema v8 that enforces
/// [exertionRuleSql]. It replaces the v7 clause
/// `CHECK (exertion_value IS NULL OR exertion_value BETWEEN 0 AND 10)`.
String get sessionSetsExertionCheck => 'CHECK (${exertionRuleSql()})';
