import 'package:repforge/domain/core/result.dart';
import 'package:repforge/domain/library/catalogue_exercise.dart';
import 'package:repforge/domain/library/exercise_attributes.dart';
import 'package:repforge/domain/library/finding.dart';
import 'package:repforge/domain/library/library_enums.dart';
import 'package:repforge/domain/library/library_ids.dart';
import 'package:repforge/domain/library/preserved_ids.dart';
import 'package:repforge/domain/library/reference_data.dart';
import 'package:repforge/domain/training/training.dart'
    show ExerciseCategory, ExerciseType;

/// Pattern families a `cardio` logging type normally goes with (IC-312).
const Set<String> cardioPatternFamilies = {'conditioning', 'power'};

/// Maximum counts before IC-310 warns.
const int maxPrimaryTargets = 3;
const int maxSecondaryTargets = 6;

/// A pair of nodes for the functional double tag rule (editorial guide 5.7):
/// a muscle that sits under one group but acts through the function of
/// another is tagged as **one primary and one secondary**, never two
/// primaries.
typedef FunctionalPair = ({AnatomyNodeId muscle, AnatomyNodeId function});

AnatomyNodeId _n(String v) => AnatomyNodeId(v);

/// The functional double tag pairs of `anatomy.md` section 4 and editorial
/// guide 5.7 (gluteus medius and minimus with the abductors, rectus femoris
/// with the hip flexors, the upper trapezius with the neck extensors and
/// lateral flexors). A node or any descendant counts as the node.
final List<FunctionalPair> functionalDoubleTagPairs = List.unmodifiable([
  (muscle: _n('gluteusMedius'), function: _n('abductors')),
  (muscle: _n('gluteusMinimus'), function: _n('abductors')),
  (muscle: _n('rectusFemoris'), function: _n('hipFlexors')),
  (muscle: _n('trapeziusUpper'), function: _n('neckExtensors')),
  (muscle: _n('trapeziusUpper'), function: _n('neckLateralFlexors')),
]);

typedef _Make = Finding Function(
  String code,
  Severity severity,
  String message, {
  String? field,
  List<String> related,
});

/// Inputs of the per-exercise rules.
final class ExerciseRuleContext {
  const ExerciseRuleContext({
    required this.reference,
    this.providers,
    this.patternsMissingIsError = true,
  });

  final ReferenceData reference;

  /// Registered provider ids; null skips the registration check.
  final Set<ProviderId>? providers;

  /// IC-205 is an error, or a warning before a tranche is in progress.
  final bool patternsMissingIsError;
}

final RegExp _systemId = RegExp(r'^lib-[a-z0-9]+(-[a-z0-9]+)*$');

/// Checks one exercise against the catalogue rules and returns every finding
/// (IC-101, 103, 201 to 212, 301 to 316 and the editorial rule ED-501).
///
/// Rules that govern system content only (identity, revision, completeness,
/// provenance) are skipped for `user` and `imported` exercises, which may be
/// partly classified. IC-304 and IC-313 are errors for system content and
/// warnings for user and imported content: the stored value is never
/// discarded and the exercise keeps working (ADR-0010 rule 5).
List<Finding> validateExercise(CatalogueExercise e, ExerciseRuleContext ctx) {
  final out = <Finding>[];
  final id = e.id.value;
  final system = e.isSystem;
  final tree = ctx.reference.anatomy;
  final patterns = ctx.reference.patterns;
  final equipment = ctx.reference.equipment;

  Finding f(
    String code,
    Severity severity,
    String message, {
    String? field,
    List<String> related = const [],
  }) => Finding(
    code: code,
    severity: severity,
    message: message,
    subjectId: id,
    field: field,
    related: related,
  );

  // Identity and revision (system content).
  if (system) {
    if (id.length > 48 || !_systemId.hasMatch(id)) {
      out.add(
        f(
          'IC-101',
          Severity.error,
          'The id $id must match lib-words-with-hyphens and be at most '
              '48 characters.',
          field: 'id',
        ),
      );
    }
    final revision = e.revision;
    if (revision == null || revision < 1) {
      out.add(
        f(
          'IC-103',
          Severity.error,
          'A system exercise needs a revision of 1 or more.',
          field: 'revision',
        ),
      );
    }
  }

  // Completeness.
  final name = e.names.name.trim();
  if (name.isEmpty || name.runes.length > 60) {
    out.add(
      f(
        'IC-201',
        Severity.error,
        'The en-GB name must be 1 to 60 characters.',
        field: 'name',
      ),
    );
  }
  final primaries = e.primaryTargets;
  if (primaries.isEmpty) {
    out.add(
      f(
        'IC-204',
        Severity.error,
        'An exercise needs at least one primary target.',
        field: 'targets',
      ),
    );
  }
  if (system) {
    if (e.patterns.isEmpty) {
      out.add(
        f(
          'IC-205',
          ctx.patternsMissingIsError ? Severity.error : Severity.warning,
          'A system exercise needs at least one movement pattern.',
          field: 'patterns',
        ),
      );
    }
    _mechanics(e, out, f);
    if (e.laterality == null) {
      out.add(
        f(
          'IC-208',
          Severity.error,
          'A system exercise needs a laterality.',
          field: 'laterality',
        ),
      );
    }
    if (e.difficulty == null) {
      out.add(
        f(
          'IC-209',
          Severity.error,
          'A system exercise needs a difficulty.',
          field: 'difficulty',
        ),
      );
    }
    if (e.names.aliases.isEmpty) {
      out.add(
        f(
          'IC-211',
          Severity.warning,
          'The exercise has no aliases.',
          field: 'aliases',
        ),
      );
    }
    final provider = e.providerId;
    final registered = ctx.providers;
    if (provider == null ||
        (registered != null && !registered.contains(provider))) {
      out.add(
        f(
          'IC-212',
          Severity.error,
          'A system exercise needs a registered provider id.',
          field: 'providerId',
        ),
      );
    }
    if ((e.provenance.authoredBy ?? '').trim().isEmpty) {
      out.add(
        f(
          'IC-212',
          Severity.error,
          'A system exercise needs a recorded author.',
          field: 'provenance',
        ),
      );
    }
  }

  // Reference validity: targets.
  final seen = <AnatomyNodeId, TargetRole>{};
  for (final t in e.targets) {
    if (!tree.contains(t.node)) {
      out.add(
        f(
          'IC-301',
          Severity.error,
          'Target node ${t.node} does not exist in the anatomy list.',
          field: 'targets',
        ),
      );
    } else if (!(tree.node(t.node)?.isActive ?? true) && e.isActive) {
      out.add(
        f(
          'IC-313',
          system ? Severity.error : Severity.warning,
          'An active exercise targets the retired node ${t.node}.',
          field: 'targets',
        ),
      );
    }
    final earlier = seen[t.node];
    if (earlier != null) {
      if (earlier != t.role) {
        out.add(
          f(
            'IC-305',
            Severity.error,
            'The primary node ${t.node} is repeated as a secondary.',
            field: 'targets',
          ),
        );
      } else {
        out.add(
          f(
            'IC-302',
            Severity.error,
            'The node ${t.node} appears more than once.',
            field: 'targets',
          ),
        );
      }
    } else {
      seen[t.node] = t.role;
    }
  }
  final distinct = seen.keys.toList();
  for (var i = 0; i < distinct.length; i++) {
    for (var j = i + 1; j < distinct.length; j++) {
      if (tree.contains(distinct[i]) &&
          tree.contains(distinct[j]) &&
          tree.areRelated(distinct[i], distinct[j])) {
        out.add(
          f(
            'IC-303',
            Severity.error,
            'The nodes ${distinct[i]} and ${distinct[j]} are tagged '
                'together but one contains the other.',
            field: 'targets',
            related: [distinct[i].value, distinct[j].value],
          ),
        );
      }
    }
  }
  _fullBody(e, tree, system: system, out: out, f: f);
  final ordinals = [for (final t in e.targets) t.ordinal]..sort();
  for (var i = 0; i < ordinals.length; i++) {
    if (ordinals[i] != i) {
      out.add(
        f(
          'IC-309',
          Severity.error,
          'Target ordinals must be contiguous from 0.',
          field: 'targets',
        ),
      );
      break;
    }
  }
  if (primaries.length > maxPrimaryTargets ||
      e.secondaryTargets.length > maxSecondaryTargets) {
    out.add(
      f(
        'IC-310',
        Severity.warning,
        'The exercise has ${primaries.length} primary and '
            '${e.secondaryTargets.length} secondary targets; the usual maximum '
            'is $maxPrimaryTargets and $maxSecondaryTargets.',
        field: 'targets',
      ),
    );
  }
  _functionalDoubleTags(e, tree, out, f);

  // Patterns.
  for (final p in e.patterns) {
    final pattern = patterns.pattern(p);
    if (pattern == null) {
      out.add(
        f(
          'IC-306',
          Severity.error,
          'The pattern $p does not exist.',
          field: 'patterns',
        ),
      );
    } else if (pattern.isFamily) {
      out.add(
        f(
          'IC-306',
          Severity.error,
          'The family $p is used as a pattern; use a leaf pattern.',
          field: 'patterns',
        ),
      );
    } else if (!pattern.isActive && e.isActive) {
      out.add(
        f(
          'IC-313',
          system ? Severity.error : Severity.warning,
          'An active exercise uses the retired pattern $p.',
          field: 'patterns',
        ),
      );
    }
  }
  final primaryPattern = e.primaryPattern;
  final family = primaryPattern == null
      ? null
      : patterns.familyOf(primaryPattern);
  if (family != null && !patterns.pattern(primaryPattern!)!.isFamily) {
    if (family.relatedCategories.isNotEmpty &&
        !family.relatedCategories.contains(e.category.name)) {
      out.add(
        f(
          'IC-311',
          Severity.warning,
          'The category ${e.category.name} does not usually go with the '
              'pattern family ${family.id}.',
          field: 'patterns',
        ),
      );
    }
    if (e.type == ExerciseType.cardio &&
        !cardioPatternFamilies.contains(family.id.value)) {
      out.add(
        f(
          'IC-312',
          Severity.warning,
          'Cardio logging is unusual with the pattern family ${family.id}.',
          field: 'type',
        ),
      );
    }
  }

  // Equipment.
  final usedItems = <EquipmentItemId>{};
  for (final use in e.equipment) {
    final item = equipment.item(use.item);
    if (item == null) {
      out.add(
        f(
          'IC-307',
          Severity.error,
          'The equipment item ${use.item} does not exist.',
          field: 'equipment',
        ),
      );
    } else if (!item.isActive && e.isActive) {
      out.add(
        f(
          'IC-313',
          system ? Severity.error : Severity.warning,
          'An active exercise uses the retired equipment ${use.item}.',
          field: 'equipment',
        ),
      );
    }
    if (!usedItems.add(use.item)) {
      out.add(
        f(
          'IC-307',
          Severity.error,
          'The equipment item ${use.item} is listed twice.',
          field: 'equipment',
        ),
      );
    }
    if (use.roleOverride != null && (use.overrideNote ?? '').trim().isEmpty) {
      out.add(
        f(
          'IC-315',
          Severity.error,
          'The role override of ${use.item} needs a note.',
          field: 'equipment',
        ),
      );
    }
  }

  // Attributes.
  for (final MapEntry(key: attribute, :value) in e.attributes.entries) {
    if (!AttributeVocabulary.isValid(attribute, value)) {
      out.add(
        f(
          'IC-316',
          Severity.error,
          'The value "$value" is not in the controlled list of '
              '${attribute.name}.',
          field: 'attributes',
        ),
      );
    }
  }
  return out;
}

void _mechanics(CatalogueExercise e, List<Finding> out, _Make f) {
  final noMechanics =
      e.category == ExerciseCategory.cardio ||
      e.category == ExerciseCategory.mobility;
  if (e.mechanics == null) {
    out.add(
      noMechanics
          ? f(
              'IC-207',
              Severity.info,
              'Mechanics is empty for ${e.category.name} by owner decision '
                  '(2026-11-05).',
              field: 'mechanics',
            )
          : f(
              'IC-207',
              Severity.error,
              'A ${e.category.name} exercise needs mechanics.',
              field: 'mechanics',
            ),
    );
  }
}

void _fullBody(
  CatalogueExercise e,
  AnatomyTree tree, {
  required bool system,
  required List<Finding> out,
  required _Make f,
}) {
  final severity = system ? Severity.error : Severity.warning;
  _nonAnatomicalCategory(e, tree, out, f);
  if (!e.targets.any((t) => t.node == fullBodyNodeId)) return;
  final hasSecondary = e.targets.any(
    (t) => t.node == fullBodyNodeId && !t.isPrimary,
  );
  final anatomicalPrimary = e.targets.any(
    (t) => t.isPrimary && t.node != fullBodyNodeId,
  );
  final fullBodyPrimaryCount = e.targets
      .where((t) => t.node == fullBodyNodeId && t.isPrimary)
      .length;
  if (hasSecondary) {
    out.add(
      f(
        'IC-304',
        severity,
        'fullBody is used as a secondary target; it may only be the single '
            'primary of a whole-body or conditioning exercise (ADR-0010).',
        field: 'targets',
      ),
    );
  }
  if (fullBodyPrimaryCount > 0 && anatomicalPrimary) {
    out.add(
      f(
        'IC-304',
        severity,
        'fullBody is a primary target together with an anatomical primary '
            '(ADR-0010).',
        field: 'targets',
      ),
    );
  }
}

void _functionalDoubleTags(
  CatalogueExercise e,
  AnatomyTree tree,
  List<Finding> out,
  _Make f,
) {
  final primaryNodes = [for (final t in e.primaryTargets) t.node];
  for (final pair in functionalDoubleTagPairs) {
    final muscle = primaryNodes.any(
      (n) => tree.isSelfOrDescendantOf(n, pair.muscle),
    );
    final function = primaryNodes.any(
      (n) => tree.isSelfOrDescendantOf(n, pair.function),
    );
    if (muscle && function) {
      out.add(
        f(
          'ED-501',
          e.isSystem ? Severity.error : Severity.warning,
          'The functional pair ${pair.muscle} and ${pair.function} is tagged '
              'as two primaries; tag one primary and one secondary (editorial '
              'guide 5.7).',
          field: 'targets',
          related: [pair.muscle.value, pair.function.value],
        ),
      );
    }
  }
}

/// Returns the exercise when it has no error-severity finding, otherwise a
/// [ValidationError] whose `fieldErrors` list each error by code and field.
Result<CatalogueExercise> requireValidExercise(
  CatalogueExercise e,
  ExerciseRuleContext ctx,
) {
  final errors = [
    for (final f in validateExercise(e, ctx))
      if (f.severity == Severity.error) f,
  ];
  if (errors.isEmpty) return Result.ok(e);
  final fieldErrors = <String, String>{};
  for (final x in errors) {
    fieldErrors.update(
      '${x.code}:${x.field ?? ''}',
      (m) => '$m ${x.message}',
      ifAbsent: () => x.message,
    );
  }
  return Result.err(
    ValidationError(
      errors.first.message,
      field: errors.first.field,
      fieldErrors: fieldErrors,
    ),
  );
}

/// IC-314: a target whose node is flagged non-anatomical (read from the
/// reference data, not a fixed id) used with a category other than cardio,
/// fullBody or mobility.
void _nonAnatomicalCategory(
  CatalogueExercise e,
  AnatomyTree tree,
  List<Finding> out,
  _Make f,
) {
  const allowed = {
    ExerciseCategory.cardio,
    ExerciseCategory.fullBody,
    ExerciseCategory.mobility,
  };
  if (allowed.contains(e.category)) return;
  for (final t in e.targets) {
    if (tree.contains(t.node) && !tree.isAnatomical(t.node)) {
      out.add(
        f(
          'IC-314',
          Severity.warning,
          'The non-anatomical node ${t.node} is used with the category '
              '${e.category.name}.',
          field: 'targets',
        ),
      );
      return;
    }
  }
}
