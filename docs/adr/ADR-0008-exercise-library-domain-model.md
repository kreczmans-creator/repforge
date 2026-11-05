# ADR-0008: Exercise library domain model — Engineering Objects, hierarchical anatomy, classifications and relationships

- Status: **Proposed** (WP 16a; owner approval required before implementation)
- Date: 2026-11-05
- Implements owner decisions of 2026-11-05 (D04 §7, "WP 16 decisions"): Engineering Object definition, four-level anatomy, difficulty, relationship kinds, English (UK) first, preservation of identifiers.

## Context
WP 8 models an exercise with one primary muscle and a secondary list from a flat 19-value enum (`MuscleGroup`), a 7-value category, a 21-value equipment enum, aliases, a `supplied` flag and `copiedFromId`. The owner's library amendment (LIB-001..010) requires a hierarchical anatomy, multiple primary and secondary targets, movement pattern, mechanics, laterality and difficulty, explicit relationships, instructional content, media references, provenance and localisation readiness, without structural database changes for routine catalogue additions. The 19 muscle identifiers are mixed-level (for example `chest` is a group, `frontDelts` a head, `fullBody` is not anatomical) and are used by stored data and WP 9 rules.

## Options considered
1. **Keep closed Dart enums** and add more enums: compile-time safety, but every anatomy or equipment addition is a code change and labels cannot be localised as data.
2. **Reference data with stable string identifiers**, loaded from a versioned bundled asset into reference tables; code uses typed identifier wrappers; small owner-defined closed sets stay enums.
3. **Generic attribute store** (entity–attribute–value) for all classifications: maximally flexible, weak integrity and poor queryability.

## Decision (proposed)
Option 2.
1. **Engineering Object** (owner definition) applies to: exercise, anatomy node, movement pattern, equipment item, exercise relationship, content section, media reference, content provider, catalogue release. Each has a stable identifier, a defined type and schema, source and provenance, validation rules and constraints, creation and modification times, defined relationships, lifecycle-appropriate versioning, and persistence with query, backup and restore. Exercises carry a revision number; reference data is versioned by catalogue release; user state is not versioned.
2. **Anatomy**: one hierarchy of nodes `L1 region › L2 muscle group › L3 anatomical muscle › L4 subdivision or head`, each node with a parent (none at L1), a level and a sort order. Exercises are tagged at the most meaningful defensible level. The 19 WP 8 identifiers are kept as node identifiers at their anatomically correct level (mapping in the WP 16a plan); `fullBody` becomes a non-anatomical target kind, not an anatomy node, because it names no muscle.
3. **Targets**: an exercise has one or more primary and zero or more secondary targets, stored as rows (exercise, node, role, order). A node appears at most once per exercise. Roles are qualitative (primary, secondary); no percentages or activation values are stored or shown.
4. **Classifications**: movement pattern (reference data, hierarchical, one or more per exercise, first is primary); equipment (reference data, existing 21 identifiers kept); mechanics `compound | isolation`, laterality `bilateral | unilateral | alternating`, difficulty `beginner | intermediate | advanced` (owner definitions: technical complexity, not load or fitness) as closed enums; logging type (`ExerciseType`, six types) and category (seven) unchanged.
5. **Relationships**: `variationOf`, `progressionOf`, `regressionOf`, `alternativeTo`, `unilateralCounterpartOf`. Directional kinds are stored in one direction and their inverse is derived for display (A `progressionOf` B is shown as B `regressionOf` A; storing both directions is refused as a duplicate). `variationOf` points from a variation to its canonical exercise and forms a forest (no cycles, one canonical root per family). `progressionOf` and `regressionOf` form an acyclic graph. `alternativeTo` and `unilateralCounterpartOf` are symmetric and stored once with ordered identifiers. Self-references are refused. Relationships do not schedule or prescribe training.
6. **Content**: instruction sections keyed by (exercise, locale, section kind, order) with provider and revision. Section kinds are a controlled list in the domain (`setup`, `execution`, `breathing`, `commonMistakes`; later kinds such as cues or safety) stored as text, so a new kind needs no schema change. Media are references (kind, locator, licence, attribution, provider); no binary data in the database; no display in WP 16a.
7. **Localisation**: identity is locale-independent. English (UK) `en-GB` is the only shipped locale. Labels for reference data and exercise content are keyed by locale; names in other locales go into a per-locale name table, never a second exercise record.
8. **User state** (favourite, hidden, last used) lives in its own table keyed by exercise, separate from catalogue fields.

## Rationale
Reference data keeps the controlled vocabulary maintainable and localisable without a schema change for each addition, while typed identifiers and validation keep integrity. Qualitative roles honour the owner's instruction not to present anatomy as precise biomechanics. Single-direction storage with derived inverses makes contradictory relationship pairs impossible.

## Consequences
- WP 8 and WP 9 code that uses the `MuscleGroup` and `Equipment` enums moves to identifier types; stored values do not change.
- D04 TRN-010(1) ("exactly one primary group") is superseded by the owner's decision (one or more primary targets); TRN-027 volume attribution with several primary targets needs a rule (OQ-19).
- Reference data is approved as content (anatomy node list, movement pattern list) before WP 16c population.
- Schema v8 (additive) introduces the tables; see the WP 16a plan.
