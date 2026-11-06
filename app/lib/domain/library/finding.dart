import 'package:meta/meta.dart';

/// Severity of an integrity finding (`quality-and-duplicates.md` section 1).
///
/// An [error] fails the build for system content; a [warning] is reported and
/// needs a recorded disposition before a tranche is accepted; an [info] is
/// reported only.
enum Severity { error, warning, info }

/// One result of an integrity check: a check code, the subject it concerns and
/// a plain-sentence message.
@immutable
final class Finding implements Comparable<Finding> {
  const Finding({
    required this.code,
    required this.severity,
    required this.message,
    this.subjectId,
    this.field,
    this.related = const [],
    this.disposition,
  });

  /// Check code, for example `IC-304`.
  final String code;
  final Severity severity;

  /// Id of the exercise, node, pattern, item or other subject, if one applies.
  final String? subjectId;

  /// The affected field, if one applies.
  final String? field;
  final String message;

  /// Ids of related subjects (the other exercise of a duplicate pair).
  final List<String> related;

  /// Recorded disposition (accepted-gaps file or a relationship), if any.
  final String? disposition;

  Finding withDisposition(String value) => Finding(
    code: code,
    severity: severity,
    message: message,
    subjectId: subjectId,
    field: field,
    related: related,
    disposition: value,
  );

  /// Deterministic order: code, subject, related ids, message.
  @override
  int compareTo(Finding other) {
    var c = code.compareTo(other.code);
    if (c != 0) return c;
    c = (subjectId ?? '').compareTo(other.subjectId ?? '');
    if (c != 0) return c;
    c = related.join(',').compareTo(other.related.join(','));
    if (c != 0) return c;
    return message.compareTo(other.message);
  }

  @override
  String toString() => '$code ${severity.name} ${subjectId ?? '-'}: $message';
}

/// Sorts [findings] into the deterministic report order.
List<Finding> sortedFindings(Iterable<Finding> findings) =>
    findings.toList()..sort();
