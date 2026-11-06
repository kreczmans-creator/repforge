import 'package:meta/meta.dart';
import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/value_equality.dart';

/// A relationship between two exercises (ADR-0008 decision 5).
///
/// `source` is required on both this constructor and [normalised]: a
/// relationship's owner must always be stated, because system relationships
/// get stricter checks (IC-402 retired ends, the IC-105/106 fingerprint) and
/// user relationships are checked by IC-905. Review finding N1 (stage 3a).
///
/// Directional kinds are stored in one direction: `variationOf` points from a
/// variation to its canonical exercise; `progressionOf` from the harder entry
/// to the easier one. `regressionOf` is a derived view: input is normalised to
/// the inverse `progressionOf` by [ExerciseRelationship.normalised]. The
/// symmetric kinds are stored once with the ids in order (`from` before `to`).
@immutable
final class ExerciseRelationship extends ValueObject
    implements Comparable<ExerciseRelationship> {
  const ExerciseRelationship({
    required this.from,
    required this.to,
    required this.kind,
    required this.source,
    this.createdAt,
  });

  /// Builds the stored form of an input relationship: a `regressionOf` is
  /// turned into the inverse `progressionOf`, and a symmetric pair is put in
  /// id order. A self-reference is refused.
  static Result<ExerciseRelationship> normalised({
    required ExerciseId from,
    required ExerciseId to,
    required RelationshipKind kind,
    required ExerciseSource source,
    DateTime? createdAt,
  }) {
    if (from == to) {
      return const Result.err(
        ValidationError(
          'An exercise cannot be related to itself.',
          field: 'to',
        ),
      );
    }
    var a = from;
    var b = to;
    var k = kind;
    if (kind == RelationshipKind.regressionOf) {
      // "A is a regression of B" is stored as "B is a progression of A".
      a = to;
      b = from;
      k = RelationshipKind.progressionOf;
    } else if (kind.isSymmetric && b.compareTo(a) < 0) {
      a = to;
      b = from;
    }
    return Result.ok(
      ExerciseRelationship(
        from: a,
        to: b,
        kind: k,
        source: source,
        createdAt: createdAt,
      ),
    );
  }

  final ExerciseId from;
  final ExerciseId to;
  final RelationshipKind kind;
  final ExerciseSource source;
  final DateTime? createdAt;

  /// True when the stored form is canonical: not a `regressionOf`, not a
  /// self-reference, and symmetric ids in order.
  bool get isNormalised =>
      kind.isStored &&
      from != to &&
      (!kind.isSymmetric || from.compareTo(to) < 0);

  /// The derived regression view of a stored `progressionOf`: "`to` is a
  /// regression of `from`". Null for any other kind.
  ({ExerciseId easier, ExerciseId harder})? get derivedRegression =>
      kind == RelationshipKind.progressionOf
      ? (easier: to, harder: from)
      : null;

  @override
  int compareTo(ExerciseRelationship other) {
    var c = kind.index.compareTo(other.kind.index);
    if (c != 0) return c;
    c = from.compareTo(other.from);
    return c != 0 ? c : to.compareTo(other.to);
  }

  @override
  List<Object?> get props => [from, to, kind, source, createdAt];

  @override
  String toString() => '$from ${kind.name} $to';
}

/// The derived regression views ("`easier` is a regression of `harder`") of
/// the stored progressions in [relationships].
List<({ExerciseId easier, ExerciseId harder})> derivedRegressions(
  Iterable<ExerciseRelationship> relationships,
) => [
  for (final r in relationships)
    if (r.derivedRegression != null) r.derivedRegression!,
];
