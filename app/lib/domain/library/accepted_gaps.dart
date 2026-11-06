import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/coverage_evaluation.dart';
import 'package:repforge/domain/library/duplicate_detection.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/reference_parsers.dart';

/// Kind of an accepted-gaps entry (`quality-and-duplicates.md` section 5.1).
enum AcceptedGapKind { warning, duplicate, coverageGap }

/// One accepted disposition. It matches by exact subject and never silences an
/// error.
@immutable
final class AcceptedGap {
  const AcceptedGap({
    required this.id,
    required this.kind,
    required this.reason,
    required this.acceptedBy,
    this.code,
    this.exerciseId,
    this.pair,
    this.decision,
    this.group,
    this.dimension,
    this.item,
    this.untilRelease,
  });

  final String id;
  final AcceptedGapKind kind;
  final String reason;
  final String acceptedBy;

  /// Warning entries: the check code and the exercise id.
  final String? code;
  final ExerciseId? exerciseId;

  /// Duplicate entries: the two exercise ids and the decision
  /// (`distinct`, `merge` or `relationship`).
  final List<ExerciseId>? pair;
  final String? decision;

  /// Coverage gap entries: group, dimension and item.
  final String? group;
  final String? dimension;
  final String? item;

  /// When set, the entry expires after that release number.
  final int? untilRelease;
}

/// The accepted-gaps file (`repforge.acceptedGaps/1`).
@immutable
final class AcceptedGaps {
  const AcceptedGaps(this.entries);

  static const AcceptedGaps none = AcceptedGaps([]);

  final List<AcceptedGap> entries;

  /// Dispositions of duplicate pairs by `duplicatePairKey`.
  Map<String, String> duplicateDispositions({int? release}) => {
    for (final e in entries)
      if (e.kind == AcceptedGapKind.duplicate &&
          e.pair != null &&
          e.pair!.length == 2 &&
          !_expired(e, release))
        duplicatePairKey(e.pair![0], e.pair![1]):
            '${e.decision ?? 'accepted'} (${e.id})',
  };

  static bool _expired(AcceptedGap e, int? release) =>
      e.untilRelease != null && release != null && release > e.untilRelease!;

  static const Set<String> _pairCodes = {
    'IC-601',
    'IC-602',
    'IC-603',
    'IC-411',
    'IC-412',
  };

  /// Applies the entries to [findings] and the gap [rows].
  ///
  /// Matching is by exact subject (`quality-and-duplicates.md` 5.1):
  /// - a `duplicate` entry clears every pair finding of its pair (IC-601 to
  ///   IC-603, IC-411, IC-412);
  /// - a `warning` entry matches its code and either its exact `pair` (only
  ///   that pair) or, without a pair, its exercise id;
  /// - a `coverageGap` entry accepted by the owner turns the matching open
  ///   row into `accepted`.
  /// Errors are never silenced. An entry that matches nothing, or has
  /// expired, is reported as an ED-901 info (stale).
  ({List<Finding> findings, List<GapRow> rows}) apply(
    List<Finding> findings,
    List<GapRow> rows, {
    int? release,
  }) {
    final used = <String>{};
    final out = <Finding>[];
    for (final f in findings) {
      var result = f;
      if (f.severity != Severity.error) {
        final pairKey = f.subjectId != null && f.related.length == 1
            ? duplicatePairKey(
                ExerciseId(f.subjectId!),
                ExerciseId(f.related.single),
              )
            : null;
        for (final e in entries) {
          if (_expired(e, release)) continue;
          final entryPair = e.pair != null && e.pair!.length == 2
              ? duplicatePairKey(e.pair![0], e.pair![1])
              : null;
          final matches = switch (e.kind) {
            AcceptedGapKind.duplicate =>
              entryPair != null &&
                  pairKey == entryPair &&
                  _pairCodes.contains(f.code),
            AcceptedGapKind.warning =>
              e.code == f.code &&
                  (entryPair != null
                      ? pairKey == entryPair
                      : e.exerciseId?.value == f.subjectId),
            AcceptedGapKind.coverageGap => false,
          };
          if (matches) {
            used.add(e.id);
            if (result.disposition == null) {
              result = f.withDisposition(
                e.kind == AcceptedGapKind.duplicate
                    ? '${e.decision ?? 'accepted'} (${e.id})'
                    : 'accepted (${e.id})',
              );
            }
          }
        }
      }
      out.add(result);
    }
    final newRows = <GapRow>[];
    for (final r in rows) {
      var result = r;
      if (r.isOpen) {
        for (final e in entries) {
          if (_expired(e, release)) continue;
          if (e.kind == AcceptedGapKind.coverageGap &&
              e.acceptedBy == 'owner' &&
              e.group == r.group &&
              e.dimension == r.dimension.name &&
              e.item == r.item) {
            used.add(e.id);
            result = r.withStatus(
              GapStatus.accepted,
              'Accepted by the owner (${e.id}).',
            );
            break;
          }
        }
      }
      newRows.add(result);
    }
    for (final e in entries) {
      if (_expired(e, release)) {
        out.add(
          Finding(
            code: 'ED-901',
            severity: Severity.info,
            message: 'The accepted-gaps entry ${e.id} has expired.',
            subjectId: e.id,
          ),
        );
      } else if (!used.contains(e.id)) {
        out.add(
          Finding(
            code: 'ED-901',
            severity: Severity.info,
            message:
                'The accepted-gaps entry ${e.id} matches nothing (stale); '
                'remove it in the next release.',
            subjectId: e.id,
          ),
        );
      }
    }
    return (findings: out, rows: newRows);
  }
}

/// Parses an accepted-gaps document. A coverage gap entry must be accepted by
/// the owner.
Result<AcceptedGaps> parseAcceptedGaps(Object? json) {
  final r = JsonReader();
  final root = r.map(json, r'$');
  if (root == null) return r.finish('accepted-gaps file', null);
  if (root['schema'] != 'repforge.acceptedGaps/1') {
    r.fail('schema', 'Expected repforge.acceptedGaps/1.');
  }
  final raw = r.list(root['accepted'], 'accepted');
  final entries = <AcceptedGap>[];
  if (raw != null) {
    for (var i = 0; i < raw.length; i++) {
      final p = 'accepted[$i]';
      final m = r.map(raw[i], p);
      if (m == null) continue;
      final id = r.string(m, 'id', p);
      final kindName = r.string(m, 'kind', p);
      final kind = AcceptedGapKind.values
          .where((k) => k.name == kindName)
          .firstOrNull;
      if (kindName != null && kind == null) {
        r.fail('$p.kind', 'Expected warning, duplicate or coverageGap.');
      }
      final reason = r.string(m, 'reason', p);
      final by = r.string(m, 'acceptedBy', p);
      if (kind == AcceptedGapKind.coverageGap && by != null && by != 'owner') {
        r.fail(
          '$p.acceptedBy',
          'A coverage gap must be accepted by the owner.',
        );
      }
      final pairRaw = m['pair'];
      List<ExerciseId>? pair;
      if (pairRaw != null) {
        if (pairRaw is List<Object?> &&
            pairRaw.length == 2 &&
            pairRaw.every((x) => x is String)) {
          pair = [for (final x in pairRaw) ExerciseId(x! as String)];
        } else {
          r.fail('$p.pair', 'Expected two exercise ids.');
        }
      }
      final until = m['untilRelease'];
      if (until != null && until is! int) {
        r.fail('$p.untilRelease', 'Expected an integer or null.');
      }
      if (id == null || kind == null || reason == null || by == null) continue;
      final exercise = r.optionalString(m, 'exerciseId', p);
      entries.add(
        AcceptedGap(
          id: id,
          kind: kind,
          reason: reason,
          acceptedBy: by,
          code: r.optionalString(m, 'code', p),
          exerciseId: exercise == null ? null : ExerciseId(exercise),
          pair: pair,
          decision: r.optionalString(m, 'decision', p),
          group: r.optionalString(m, 'group', p),
          dimension: r.optionalString(m, 'dimension', p),
          item: r.optionalString(m, 'item', p),
          untilRelease: until is int ? until : null,
        ),
      );
    }
  }
  return r.finish(
    'accepted-gaps file',
    AcceptedGaps(List.unmodifiable(entries)),
  );
}
