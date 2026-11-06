# ADR-0008: Exercise library domain model — Engineering Objects, hierarchical anatomy, classifications and relationships

- Status: **Accepted — architectural direction** (owner, 2026-11-05). Implementation gated: WP 8 stage 3 starts only after WP 9 delivery is accepted and the stage 3 plan is finally authorised (D04 §7).
- Date: 2026-11-05
- History: proposed on 2026-11-05 for the WP 16a proposal; re-scoped the same day to **WP 8 stage 3** by owner decision (WP 16 superseded; D04 §7). Number and content kept.
- Implements owner decisions of 2026-11-05 (D04 §7, "WP 8 library decisions"): Engineering Object definition, four-level anatomy, difficulty, relationship kinds, English (UK) first, preservation of identifiers.

## Context
WP 8 models an exercise with one primary muscle and a secondary list from a flat 19-value enum (`MuscleGroup`), a 7-value category, a 21-value equipment enum, aliases, a `supplied` flag and `copiedFromId`. The owner's library amendment (LIB-001..010) requires a hierarchical anatomy, multiple primary and secondary targets, movement pattern, mechanics, laterality and difficulty, explicit relationships, instructional content, media references, provenance and localisation readiness, without structural database changes for routine catalogue additions. The 19 muscle identifiers are mixed-level (for example `chest` is a group, `frontDelts` a head, `fullBody` is not anatomical) and are used by stored data and WP 9 rules.

## Options considered
1. **Keep closed Dart enums** and add more enums: compile-time safety, but every anatomy or equipment addition is a code change and labels cannot be localised as data.
2. **Reference data with stable string identifiers**, loaded from a versioned bundled asset into reference tables; code uses typed identifier wrappers; small owner-defined closed sets stay enums.
3. **Generic attribute store** (entity–attribute–value) for all classifications: maximally flexible, weak integrity and poor queryability.

## Decision
Option 2.
1. **Engineering Object** (owner definition) applies to: exercise, anatomy node, movement pattern, equipment item, exercise relationship, content section, media reference, content provider, catalogue release. Each has a stable identifier, a defined type and schema, source and provenance, validation rules and constraints, creation and modification times, defined relationships, lifecycle-appropriate versioning, and persistence with query, backup and restore. Exercises carry a revision number; reference data is versioned by catalogue release; user state is not versioned.
2. **Anatomy**: one hierarchy of nodes `L1 region › L2 muscle group › L3 anatomical muscle › L4 subdivision or head`, each node with a parent (none at L1), a level and a sort order. Exercises are tagged at the most meaningful defensible level. The 19 WP 8 identifiers are kept as node identifiers at their anatomically correct level (mapping in the WP 8 delivery plan (`docs/wp8-delivery-plan.md`)); `fullBody` becomes a non-anatomical target kind, not an anatomy node, because it names no muscle.
3. **Targets**: an exercise has one or more primary and zero or more secondary targets, stored as rows (exercise, node, role, order). A node appears at most once per exercise. Roles are qualitative (primary, secondary); no percentages or activation values are stored or shown.
4. **Classifications**: movement pattern (reference data, hierarchical, one or more per exercise, first is primary); equipment (reference data, existing 21 identifiers kept); mechanics `compound | isolation`, laterality `bilateral | unilateral | alternating`, difficulty `beginner | intermediate | advanced` (owner definitions: technical complexity, not load or fitness) as closed enums; logging type (`ExerciseType`, six types) and category (seven) unchanged.
5. **Relationships**: `variationOf`, `progressionOf`, `regressionOf`, `alternativeTo`, `unilateralCounterpartOf`. Directional kinds are stored in one direction and their inverse is derived for display (A `progressionOf` B is shown as B `regressionOf` A; storing both directions is refused as a duplicate). `variationOf` points from a variation to its canonical exercise and forms a forest (no cycles, one canonical root per family). `progressionOf` and `regressionOf` form an acyclic graph. `alternativeTo` and `unilateralCounterpartOf` are symmetric and stored once with ordered identifiers. Self-references are refused. Relationships do not schedule or prescribe training.
6. **Content**: instruction sections keyed by (exercise, locale, section kind, order) with provider and revision. Section kinds are a controlled list in the domain (`setup`, `execution`, `breathing`, `commonMistakes`; later kinds such as cues or safety) stored as text, so a new kind needs no schema change. Media are references (kind, locator, licence, attribution, provider); no binary data in the database; no display in WP 8 stage 3.
7. **Localisation**: identity is locale-independent. English (UK) `en-GB` is the only shipped locale. Labels for reference data and exercise content are keyed by locale; names in other locales go into a per-locale name table, never a second exercise record.
8. **User state** (favourite, hidden, last used) lives in its own table keyed by exercise, separate from catalogue fields.

## Rationale
Reference data keeps the controlled vocabulary maintainable and localisable without a schema change for each addition, while typed identifiers and validation keep integrity. Qualitative roles honour the owner's instruction not to present anatomy as precise biomechanics. Single-direction storage with derived inverses makes contradictory relationship pairs impossible.

## Consequences
- WP 8 and WP 9 code that uses the `MuscleGroup` and `Equipment` enums moves to identifier types; stored values do not change.
- D04 TRN-010(1) ("exactly one primary group") is superseded by the owner's decision (one or more primary targets); TRN-027 volume attribution with several primary targets: OQ-19 approved 2026-11-05 — each primary target receives the full recorded set volume; each primary muscle target receives the full recorded exercise-set count; secondary muscles reported separately and excluded from primary totals; set counts, not physiological volume measurements (kg-volume attribution under TRN-027(3): clarification pending, D04 §7).
- Reference data is approved as content (anatomy node list, movement pattern list) before WP 8 stage 5 population.
- Schema v8 (additive) introduces the tables; see the WP 8 delivery plan (`docs/wp8-delivery-plan.md`).

## Clarification (approved by the owner 2026-11-06): exercise attributes and equipment roles in schema v8

- Status: **Approved** by the owner on 2026-11-06, with the decisions in section E. Section E overrides any proposal or question in sections A to D. Decisions 1–8 above stand unchanged.
- Trigger: D04 §7, entry of 2026-11-06 "WP 8 stage 3b plan approved", bullet "Attributes and equipment roles". Sub-stage 3b-2 waits for this text (`docs/delivery-record/WP8.md`, stage 3b table).
- Scope: the seven approved exercise attributes and the per-exercise equipment role in schema v8. Steps marked **Proposal** are the architect's own; each names the open question that decides it.
- Approved sources:
  - `docs/catalogue/reference/coverage.json`: `countingRules.discriminatorKinds.attribute` (line 15), `exerciseAttributesProposed` (lines 29–121: `status`, `ifDeclined`, `attributes`, `usedBySlots`), `attributeFallback` (line 122, not used).
  - `docs/catalogue/coverage-matrix.md` §2 rule 5, §3 (table, "ADR-0008 implication", "Pattern-level fallback") and §13 item 3.
  - `docs/catalogue/equipment.md` §1 rules 2 and 4–8, §3, §5 and §6 item 4; `docs/catalogue/reference/equipment.json` (`description`, `nodes[].role`).
  - `docs/catalogue/editorial-guide.md` §7 "Equipment roles (F21)"; `docs/catalogue/mapping-existing.json`; `docs/catalogue/population-standards.md` §1, §3 item 8 and §4 item 2.
  - `docs/catalogue/quality-and-duplicates.md` IC-307, IC-308, IC-313, IC-315, IC-316, IC-412, IC-600, IC-811 and §4.
  - D04 §7, 2026-11-05: "WP 8 decisions approved; stage 4 authorised; stage 3 gated", item 7.
  - D04 §7, 2026-11-05: "WP 8 stage 4 approved". D04 §7: all 2026-11-06 entries.
  - ADR-0009 decisions 3–5; `docs/wp8-delivery-plan.md` §5–§9, §17.2 and §21.
  - 3a domain code in `app/lib/domain/library/`: `exercise_attributes.dart`, `catalogue_exercise.dart`, `library_enums.dart`, `reference_data.dart`, `exercise_rules.dart`, `set_attribution.dart`. `catalogue_records.dart` holds no attribute or equipment type.
  - v7 data code: `app/lib/data/db/tables.dart`, `legacy_training_rows.dart`, `app/lib/data/mappers/training_mappers.dart`, `app/lib/data/repositories/drift_backup_repository.dart`.

### A. The seven attributes: one typed column each on `exercises`

**Single-valued (evidence).**
- `coverage-matrix.md` §3 defines "seven optional, single-valued, controlled attributes".
- `coverage.json` line 15 matches a slot when the recorded attribute "equals one of values".
- The 3a domain holds one value per attribute: `Map<ExerciseAttribute, String>` in `CatalogueExercise`.
- All 26 recorded values in `mapping-existing.json` are single strings.
- `grip` records two differently oriented hands as one value, `mixed`. The contract chose one value here, not a list.

**Stable (evidence and counter-evidence).**
- The owner approved the controlled vocabulary and its boundary rules on 2026-11-05 (D04 §7; `coverage-matrix.md` §13 item 3).
- The owner closed X1 on 2026-11-06. The `coverage.json` boundary texts now equal `AttributeVocabulary`.
- Precedent: plan §5 stores mechanics, laterality and difficulty as nullable CHECK columns on `exercises`.
- Precedent: ADR-0008 option 2 keeps "small owner-defined closed sets" as enums.
- Counter-evidence: the 5.1 pilot re-baselining re-derives "the attribute proposal" (`population-standards.md` §1).
- Counter-evidence: plan §6 step 2 and §21 B say release 2 loads the seven attributes, like reference data.
- Counter-evidence: the ADR-0008 rationale and decision 6 avoid a schema change for each vocabulary addition.

**Conclusion (conditional on Q1 and Q2).** No attribute is multi-valued, so none needs a separate model for that reason. Each attribute becomes one nullable `TEXT` column with a `CHECK` list. If the owner answers Q1 or Q2 otherwise, this section returns for revision.

| Attribute (`coverage.json`) | Column and type | Permitted values (exact, in `coverage.json` order) | Null | Validation | Used by (`coverage-matrix.md` §3) |
|---|---|---|---|---|---|
| `angle` | `angle TEXT CHECK (angle IS NULL OR angle IN ('flat','incline','decline'))` | `flat`, `incline`, `decline` | allowed | CHECK; IC-316; IC-308. Boundary texts: `coverage.json` lines 33–40. Classifier: `AttributeBoundaries.angle`. Steeper than 45° up, or beyond 90° down, gets no value. | `chest.flatPress`, `chest.inclinePress`, `chest.declinePress`; IC-600 |
| `armPosition` | `arm_position TEXT CHECK (arm_position IS NULL OR arm_position IN ('besideBody','behindBody','supportedInFront','overhead','flexed90','abducted90'))` | `besideBody`, `behindBody`, `supportedInFront`, `overhead`, `flexed90`, `abducted90` | allowed | CHECK; IC-316; IC-308. Boundary texts: lines 41–51, with two precedence rules. `supportedInFront` wins over all; `behindBody` wins over `overhead`. Classifier: `AttributeBoundaries.armPosition`. | `biceps.armBesideBody`, `biceps.armBehindBody`, `biceps.armSupported`, `rotatorCuff.externalRotationArmAtSide`, `rotatorCuff.externalRotationArmAbducted`, `triceps.overhead`, `triceps.pushdown`; IC-600 |
| `bodyPosition` | `body_position TEXT CHECK (body_position IS NULL OR body_position IN ('standing','seated','lying','prone','bentOver','kneeling','halfKneeling','inclined'))` | `standing`, `seated`, `lying`, `prone`, `bentOver`, `kneeling`, `halfKneeling`, `inclined` | allowed | CHECK; IC-316; IC-308. Boundary texts: lines 52–64. No numeric classifier. | `glutes.thrustLoaded`, `glutes.bridgeBodyweight`, `glutes.kickback`, `glutes.reverseHyper`, `triceps.lying`, `triceps.kickback`; IC-600 |
| `grip` | `grip TEXT CHECK (grip IS NULL OR grip IN ('pronated','supinated','neutral','mixed'))` | `pronated`, `supinated`, `neutral`, `mixed` | allowed | CHECK; IC-316; IC-308. Boundary texts: lines 65–73. | `biceps.neutralGrip`, `forearms.brachioradialis`; IC-600 |
| `gripWidth` | `grip_width TEXT CHECK (grip_width IS NULL OR grip_width IN ('close','standard','wide'))` | `close`, `standard`, `wide` | allowed | CHECK; IC-316; IC-308. Boundary texts: lines 74–81. | duplicate check only (IC-600, IC-412) |
| `kneePosition` | `knee_position TEXT CHECK (knee_position IS NULL OR knee_position IN ('straight','bent'))` | `straight`, `bent` | allowed | CHECK; IC-316; IC-308. Boundary texts: lines 82–88. Classifier: `AttributeBoundaries.kneePosition`. | `calves.straightKnee`, `calves.bentKnee`; IC-600 |
| `stance` | `stance TEXT CHECK (stance IS NULL OR stance IN ('narrow','standard','wide','split'))` | `narrow`, `standard`, `wide`, `split` | allowed | CHECK; IC-316; IC-308. Boundary texts: lines 89–97. | duplicate check only (IC-600, IC-412) |

All seven attributes are single-valued. Their stability as schema-level lists depends on Q1 and Q2.

**Rules common to all seven columns.**
1. Column names are the `coverage.json` names in snake case. Stored values are the exact camelCase identifiers.
2. NULL means "not recorded". Every attribute is optional (`coverage-matrix.md` §3; D04 §7, 2026-11-05). Q5 asks for confirmation.
3. No column has a default. The CHECK refuses an empty string, because no list contains it.
4. The CHECK uses SQLite's default `BINARY` collation, so case must match exactly.
5. The CHECK applies to system, user and imported exercises alike. `exercise_rules.dart` reports IC-316 as an error for every source.
6. The database stores the value only, never a measured angle. The X1 boundary rules govern editorial tagging and `AttributeBoundaries`.
7. A measurement outside an attribute's range gets no value, so the column stays NULL (D04 §7, "X1 closed").
8. An unrecorded attribute never matches a slot (`coverage.json` line 15). It never clears a duplicate pair (IC-600).
9. The contract defines no relevance rule between an attribute and a pattern or category. This clarification adds none (Q4).
10. The domain checks IC-316 and IC-308 stay the authority. Release validation runs them before any write (plan §7; ADR-0009 decision 3).
11. The v7 `exercises` table holds no attribute data (`tables.dart`, schema 7). After migration all seven columns are NULL.
12. The migration infers no attribute from names, aliases or equipment. Release 2 sets system values from `mapping-existing.json` (`population-standards.md` §4 item 2).

### B. Equipment: association table `exercise_equipment` with a role

**What the contract defines.**
- Each item has a default role: `load`, `support`, `cardio` or `implement` (`equipment.md` §1 rule 4; `equipment.json` `description` and `nodes[].role`).
- The domain holds it as `EquipmentItem.defaultRole` (`reference_data.dart`).
- An exercise may override the default with `equipmentRoles`. It maps an item id to `load` or `support` (`equipment.md` §1 rule 5).
- The release file needs a note field for each override (`delivery-record/WP8.md`, "Open points for 3b and 3c", 3c).
- An override is "allowed only between `load` and `support`" and "needs a note" (`equipment.md` §1 rule 5; IC-315).
- The effective role is the override, else the default. Support items never change the class (`equipment.md` §1 rules 5–6, §5).
- The domain counts every non-support default as `load`, including `cardio` and `implement` (`catalogue_exercise.dart`, `effectiveRole`, lines 193–203).
- The owner approved this load/support rule on 2026-11-05 (D04 §7; `equipment.md` §6 item 4).
- The 3a domain matches: `ExerciseEquipment(item, roleOverride, overrideNote)`, `EquipmentRole { load, support }`, `EquipmentDefaultRole { load, support, cardio, implement }`.

**Proposed table.**

| Column | Type | Null | Constraint | Source |
|---|---|---|---|---|
| `exercise_id` | TEXT | NOT NULL | FK → `exercises(id)` `ON DELETE CASCADE` | same pattern as `exercise_targets` (plan §5) |
| `equipment_id` | TEXT | NOT NULL | FK → `equipment_items(id)`, no delete action | `equipment.md` §1 rule 8 (items retire, never disappear); IC-307 |
| `ordinal` | INTEGER | NOT NULL | `CHECK (ordinal >= 0)`; `UNIQUE (exercise_id, ordinal)` | **Proposal (Q9).** Keeps the stored order for value equality (plan §17.2); domain `List<ExerciseEquipment>` |
| `role_override` | TEXT | NULL | `CHECK (role_override IS NULL OR role_override IN ('load','support'))` | `equipment.md` §1 rule 5; IC-308; IC-315 |
| `override_note` | TEXT | NULL | `CHECK (role_override IS NULL OR (override_note IS NOT NULL AND length(trim(override_note, ' ' \|\| char(9,10,13))) > 0))` | IC-315 ("has no note") |

- **Proposal (Q10):** primary key `(exercise_id, equipment_id)`. It backs the "listed twice" error in `exercise_rules.dart` (IC-307).
- **Proposal (deferred to 3b-2):** an index on `exercise_equipment(equipment_id)` serves the equipment filter. 3b-2 fixes all indexes under structural identity.
- The note CHECK strips space, tab, line feed and carriage return. Dart `trim` strips all Unicode whitespace.
- The domain IC-315 check is the authority. The CHECK is a backstop.
- NULL `role_override` means that the item's default role applies.
- The table stores the override, not the effective role. The contract stores an override (`equipment.md` §1 rule 5).
- An effective-role column would copy the default and could drift from reference data. Plan §5 rejects two stores of one fact.
- `equipment_items` needs the default role to derive the effective role. Plan §5 lists no such column.
- Proposal: add `default_role TEXT NOT NULL CHECK (default_role IN ('load','support','cardio','implement'))` to `equipment_items`.
- This section adds only `default_role`, because the role model cannot work without it. `equipment_class` and `lifecycle` stay in Q11.
- The migration bootstrap takes the default roles of the 21 existing items from the approved `equipment.json`. A test compares them (plan §6 step 2, §21 B).
- The IC-315 case "override names an item not in the equipment list" becomes unrepresentable here.
- IC-313 (an active exercise uses a retired item) stays an integrity check, not a constraint.
- Roles do not change the equipment filter. An exercise shows when every listed item is available, support items included (`equipment.md` §1 rule 2).
- Equipment stays optional. An exercise that needs no item has no rows (`equipment.md` §1 rule 2).

**Proposed migration.**
1. v7 stores equipment in `exercises.equipment_json`, a JSON array of `Equipment` enum names (`tables.dart`, class `Exercises`).
2. The v6 step canonicalised these names (`legacy_training_rows.dart`). Normally, v7 values are therefore canonical.
3. Restore does not guarantee this. It inserts rows from v6 and v7 backups raw (`drift_backup_repository.dart`, `_fromOlderSchema`, `_insertRaw`).
4. Restore first passes pre-v6 rows through the v6 synonym and label mapping (`LegacyTrainingRows.exercise`).
5. The v8 step therefore checks every element. It matches the 21 ids exactly.
6. The v8 step applies no synonym, label, case-folding or "none" matching. This rule applies to the v8 step only.
7. **Proposal (Q9):** each matching element becomes one row. `ordinal` counts the kept elements from 0, in stored order.
8. `role_override` and `override_note` stay NULL. v7 holds no role data.
9. **Proposal (Q10):** a repeated id keeps its first occurrence. Each skipped repeat gets a report row with action `skipped`.
10. The migration never invents an item. It quarantines and reports each value it cannot map:
    - an element that is not one of the 21 ids;
    - an element that is not a string;
    - text that is not a JSON array.
11. In each such case, `legacy_quarantine` receives the original `equipment_json` with a reason.
12. Each case gets its own report row (D04 §7, 2026-11-06, "Report detail"; `quality-and-duplicates.md` §4.2).
13. The row gives stable id, field `equipment`, original value, reason and disposition.
14. **Proposal (Q12):** an unknown id cites rule IC-307. A non-string element or a non-array text cites `WP8-D3`.
15. The exercise row and its references stay intact. Its availability after migration is open (Q12).
16. **Proposal (Q13):** the `exercises` rebuild drops `equipment_json` after the copy.
17. Value-equality evidence: per exercise, the ordered `equipment_id` list equals the kept elements of `equipment_json`.
18. Blocked no-primary exercises migrate their equipment and attributes the same way as other exercises.
19. `lib-inverted-row` migrates with the barbell at its default role, `load`. Release 2 sets the `support` override (`mapping-existing.json`).
20. A fresh v8 database and a migrated one define these columns and this table identically (D04 §7, "Structural identity").

### C. Open questions for the owner (answered 2026-11-06; see section E)
The sources leave these points undefined. This clarification fills none of them by assumption.
- **Q1 Vocabulary change after the pilot.** The 5.1 re-baselining may revise "the attribute proposal" (`population-standards.md` §1). With CHECK columns, any value change needs a new schema version and an `exercises` rebuild. Does the owner accept this cost?
- **Q2 Vocabulary as reference data.** Plan §6 step 2 and §21 B say release 2 loads the seven attributes. The ADR-0008 rationale and decision 6 avoid schema changes for vocabulary additions. CHECK columns put the vocabulary in the schema. Should release 2 carry it for validation only, or should it become reference data?
- **Q3 Display labels.** `coverage.json` gives definitions and boundary texts, but no display labels. Decision 7 keys reference labels by locale. Where do attribute labels live, and who approves them?
- **Q4 Relevance rules.** The definitions name a scope, for example "in a press or fly". Should any scope become an integrity check?
- **Q5 Meaning of NULL (confirmation).** The contract defines NULL as "not recorded". The vocabulary has no "not applicable" value. Please confirm that NULL also covers "not applicable".
- **Q6 Overrides on cardio or implement items.** Overrides are allowed "only between `load` and `support`" (`equipment.md` §1 rule 5). `editorial-guide.md` §7 names only load and support defaults. Does that forbid overriding a `cardio` or `implement` default? The 3a domain does not check this.
- **Q7 Override note.** `population-standards.md` §3 item 8 requires a note on every override. `mapping-existing.json` has none for `lib-inverted-row`. Who writes it? May a note exist without an override? Is the note user-facing, and so locale-keyed under decision 7?
- **Q8 Default role changes.** May a later release change an item's default role? Every exercise without an override would change class. Is `default_role` immutable content under the restore conflict rule?
- **Q9 Equipment order.** The contract gives order no meaning. The proposal keeps `ordinal` for value equality only. Keep it, or treat equipment as a set?
- **Q10 Repeated ids.** F10 covers duplicate secondaries only (`quality-and-duplicates.md` §4.1). Should a repeated equipment id keep its first occurrence and be reported `skipped`? Or should the whole list be quarantined?
- **Q11 Equipment reference columns.** Plan §5 lists no `equipment_class` or `lifecycle` on `equipment_items`. IC-313 and coverage need both. Do they belong in v8 or in 3c?
- **Q12 Exercise with an unmappable item.** v7 hides the whole exercise: `TrainingMappers.exerciseToEntity` returns null for any unknown equipment name. Dropping the element in v8 would make the exercise visible, a behaviour change. Option (a): keep it unavailable, blocked like the no-primary case. Option (b): make it available without the item. Please also confirm the rule codes in migration step 14.
- **Q13 `equipment_json` removal.** Plan §5 removes three columns, not `equipment_json`. Does the owner confirm its removal in the same rebuild?
- **Q14 User and imported content.** The contract does not say whether users may set attributes or role overrides. The schema allows both under the same checks. Is that intended?
- **Q15 Restore conflicts.** D04 "device wins" names reference data only (D04 §7, 2026-11-06, "Restore conflicts"). Which side wins for catalogue-exercise attributes and equipment rows when a v3 backup meets a newer device release? Should a v3 file with invalid attribute or role values fail atomically, or be quarantined?
- **Q16 Custom copies.** Plan §8 copies targets, patterns and content into a custom copy. Does the copy also take equipment rows, attributes and role overrides?

**For the 5.1 pilot (does not block 3b-2).** `armPosition` applies "at the start of the movement". `grip` has no such anchor. Which value does a grip that rotates within a repetition record?

### D. Effect on other contracts
- **Release format 2:** exercise records gain the seven attributes and `equipmentRoles` with notes (`coverage-matrix.md` §3; `delivery-record/WP8.md` 3c open points). Plan §7 lists neither yet.
- **Reconciler:** attributes and role overrides are system-owned classifications, updated only with a higher revision (ADR-0009 decision 4).
- **Backup v3:** backup exports raw rows of every table (`drift_backup_repository.dart`), so v3 carries the columns and the new table.
- **Restore formats 1–2:** restore maps `equipment_json` through the same v8 step (plan §9). Attributes stay NULL. Conflicts and invalid v3 values: Q15.
- **Duplicate signature:** IC-600 reads load-role items through effective roles and attributes from the columns (`quality-and-duplicates.md` IC-600).
- **IC-412:** the X2 narrow rule (D04 §7, 2026-11-06) reads the same columns. An attribute difference counts only when both exercises record the attribute.
- **Integrity checks:** CHECKs back IC-308, IC-315 and IC-316; keys back IC-307. IC-313, IC-811 and IC-950 stay tool checks.
- **OQ-19:** attributes and equipment roles do not affect attributed set counts (`set_attribution.dart`).

### E. Owner decisions (2026-11-06)
The owner approved this clarification and answered Q1 to Q16 as follows.

| # | Decision |
|---|---|
| Q1 Attribute value changes | The approved value lists are schema contracts. A change after the 5.1 pilot needs a new schema version. |
| Q2 Release 2 attributes | Release 2 includes the values for validation and catalogue consistency. The database schema stays authoritative. |
| Q3 Display labels | Locale-keyed reference labels; owner approval in stage 3c. Display labels are never stored domain values. |
| Q4 Attribute scope | No integrity enforcement yet. Scope texts stay editorial guidance. Reassess after the 5.1 pilot. |
| Q5 NULL | NULL means no recorded or applicable value. It does not distinguish "not applicable" from "not recorded". The migration never infers a value. |
| Q6 Overrides | Allowed only to `load` or `support`. Never on an item whose default role is `cardio` or `implement`. |
| Q7 Override note | The catalogue editor writes it. It is required when an override exists. It is internal only: not translated, not shown to users. |
| Q8 Default role | Immutable. A later release cannot change an item's default role. A conflicting restore fails atomically. |
| Q9 Equipment order | No meaning. The stored order is kept, but no domain logic, validation or UI behaviour depends on it. |
| Q10 Repeated ids | The first occurrence is kept. The report lists every later occurrence as skipped, with its position and id. |
| Q11 Class and lifecycle | Deferred to stage 3c. Neither column joins the version 8 schema in this work. |
| Q12 Unknown equipment | The affected exercise is blocked individually. Its id, history and original data stay. The report names the unknown equipment. It never becomes newly visible or selectable. |
| Q13 `equipment_json` | The version 8 rebuild drops it after a successful copy. Quarantine keeps the original wherever conversion is incomplete or a value is unknown. |
| Q14 User exercises | Users may set attributes and overrides under the same value, role and note constraints. |
| Q15 Version 3 backup conflicts | The device wins for existing catalogue attributes and equipment. Restore inserts missing reference data only. An invalid backup value rejects the whole restore; the database stays unchanged. |
| Q16 Custom copies | A copy takes the equipment links, attributes and overrides. It copies values, never shared mutable associations. |

**Implementation clarifications (owner, 2026-11-06).** Tests must cover each one.
1. **NULL semantics.** One database state covers both "not recorded" and "not applicable", by design. Nothing may later read NULL as evidence that an attribute does not apply. Distinguishing the two states would be a domain and schema change.
2. **Default role immutability.** A role change is not an ordinary catalogue update. If an item's meaning truly changes, the catalogue uses a new stable equipment id. It never changes the existing item's role silently.
3. **Legacy equipment quarantine.** A fully migrated equipment list is not copied into quarantine. Quarantine keeps the original `equipment_json` when an item is unknown, invalid or cannot migrate faithfully. The report names every affected exercise and its disposition.

**Consequences for sections B and C.**
- The proposals for Q9 (ordinal), Q10 (first occurrence kept) and Q13 (drop `equipment_json`) are approved as written.
- Migration step 15 changes: an exercise with an unknown, invalid or unmappable equipment value is blocked, like a no-primary exercise. Its block reason names the equipment.
- The `role_override` CHECK stays `load` or `support`. In addition, an override on an item whose default role is `cardio` or `implement` is invalid. The domain check and a test enforce it.
- `equipment_items` gains `default_role` only. `equipment_class` and `lifecycle` wait for stage 3c.
