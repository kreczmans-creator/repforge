# Exercise catalogue — WP 8 stage 4 outputs (revision 2)

- Status: **Proposed — for owner approval.** Nothing in this folder is implemented or in force until the owner approves it.
- Scope: WP 8 stage 4, catalogue tooling and quality assurance, **documentation and reference data only** (authorised 2026-11-05, `docs/wp8-delivery-plan.md` section 18). No file under `app/` changes. No WP 9 file is touched.
- Date: 2026-11-05. Revision 2 follows an independent review (findings F01 to F25, section 6).
- Requirements: LIB-001..LIB-014, owner library decisions (D04 section 7; `docs/exercise-library-expansion.md` section 5), ADR-0008, ADR-0009, ADR-0010 (proposed).

## 1. Contents
| File | What it holds | Feeds |
|---|---|---|
| `reference/anatomy.json`, `anatomy.md` | Four-level anatomy hierarchy: ids, parents, definitions, inclusion and exclusion criteria, notes, lifecycle | Stage 3 (anatomy node table, hierarchy validation); stage 5 (tagging); stage 6 (filters) |
| `reference/movement-patterns.json`, `movement-patterns.md` | Family and pattern list with definitions, inclusion and exclusion criteria; decision rules R1 to R8 for borderline movements | Stage 3 (pattern table); stage 5; stage 6 |
| `reference/equipment.json`, `equipment.md` | The 21 existing equipment ids unchanged, twelve proposed additions (one conditional), default roles, classes, the per-exercise role rule | Stage 3 (equipment table); stage 5; coverage tool |
| `reference/coverage.json` | **Machine-readable slot inventory**: per group, slots with patterns, discriminator, minimum and the enumerated intended entries; conditioning and mobility sets; proposed exercise attributes; metrics | Coverage tool (CI); source of every number in `coverage-matrix.md` |
| `reference/ledger.json` | Ledger of every reference id (anatomy, pattern, equipment) with lifecycle, introduction and retirement | Stage 3 (reference tables); IC-810 |
| `mapping-existing.json`, `mapping-existing.md` | JSON: `muscleIds` (the 19 ids with seed usage counts), `categories` (the seven categories with counts), `seedProvenance`, and `exercises` (the 89 seed exercises with proposed targets, patterns, equipment, equipment roles, class, mechanics, laterality, difficulty, attributes, alias and secondary clean-up, flags). Markdown: principles, the three tables, clean-up list, open questions | Stage 3c (release 2: the 89 exercises re-expressed); stage 5 enrichment |
| `editorial-guide.md` | Naming, variation rules, relationships (`progressionOf` only), tagging, difficulty, mechanics, laterality, equipment roles, instruction style, worked example | Stage 5 authors and reviewers; stage 3c tool rules |
| `coverage-matrix.md` | Derivation of the minimums from the slot inventory, counting rules, attributes, caps and metrics, recomputed baseline, gap report format | Stage 5 acceptance; CI coverage report |
| `population-standards.md` | Tranche plan 5.1 (pilot) to 5.7, definition of done, review workflow, keeping and enriching the 89, retirement | Stage 5 |
| `provenance-and-licensing.md` | Provider registry, original-authoring rules, admission criteria for open datasets, prohibited sources, licence register template | Stage 3 (provider table); stage 5 |
| `quality-and-duplicates.md` | Integrity checks, near-duplicate signature, report format, migration report, CI gating, accepted-gaps format, results on the seed | Stage 3a and 3c (check code, CI gate) |

## 2. Open questions these outputs answer
| Id | Question | Where answered | Owner action |
|---|---|---|---|
| OQ-22 | Anatomy node list and movement pattern list | `anatomy.md`, `movement-patterns.md`, `mapping-existing.md` | Approve, change or reject before stage 5 |
| OQ-23 | Coverage matrix minimum targets per region | `coverage-matrix.md`, `reference/coverage.json` | Approve, change or reject before stage 5 |

Both lists carry definitions, inclusion and exclusion criteria, so the reviewer can see where a muscle with two functions is filed.

## 3. How the outputs feed the stages
- **Stage 3 (architecture and reference data, gated):** loads `reference/*.json` into the reference tables; implements the checks in `quality-and-duplicates.md`; re-expresses the 89 exercises as release 2 using `mapping-existing.json` (which passes the error checks, `quality-and-duplicates.md` section 6); builds the migration report specified there. The JSON files are the proposed content of catalogue release 2's reference data.
- **Stage 5 (population):** authors work from the editorial guide, tag against the reference lists, and are accepted against the slot inventory. Population does not start until the owner approves OQ-22 and OQ-23. Tranche 5.1 is a pilot followed by an explicit re-baselining step.
- **Stage 6 (discovery):** filters use the same lists. Labels are display text and may be reworded.

## 4. Summary of the proposal
- Anatomy: 126 nodes (10 L1, 26 L2, 63 L3, 27 L4). All 19 existing ids are kept at the planned levels and with the planned parents. `fullBody` is a flagged, childless L1 node (ADR-0010, proposed).
- Movement patterns: 17 families, 62 patterns (neck rotation added), decision rules R1 to R8.
- Equipment: 21 existing ids unchanged, 12 proposed additions (one conditional); ski ergometer and stair climber added at revision 2.
- Coverage: 21 anatomical groups with 333 slot minimums, every one derived from enumerated intended entries; conditioning and mobility sets with 73 minimums. Tranche 5.1 is a pilot. The seed fills 69 of the 333 slots and covers 19 of the 73 conditioning and mobility entries (recomputed, section 6).
- Release 2: all 89 seed exercises have mechanics (or the empty default for cardio and mobility), laterality and difficulty as **proposed content**; the integrity checks give zero errors.
- Rules that cut across all documents: original content only; qualitative anatomy; per-muscle figures are *attributed set counts*, not physiological measurements of muscle stimulus; retired exercises and retired reference ids are never deleted and their ids are never reused; every historical reference must resolve.

## 5. Decisions requested from the owner
1. Approve the anatomy list (`anatomy.md`), including the debatable classifications in section 5 of that file.
2. Approve the movement pattern list, the decision rules R1 to R8 and the borderline classifications.
3. Approve the equipment additions (twelve, one conditional) and the per-exercise role rule.
4. Approve the mapping of the 89 existing exercises, including the assigned mechanics, laterality, difficulty, attributes and alias clean-up (proposed content), and answer the primary-target principle (Q-P).
5. Approve the coverage inventory (OQ-23) and the pilot-then-re-baseline approach.
6. Approve the editorial guide, population standards, provenance rules and quality specification.
7. Answer the owner questions in section 7.

## 6. Revision 2 (review findings F01–F25)
Each finding and what changed. "Open" means the owner decides; nothing was decided on the owner's behalf.

| Finding | Change |
|---|---|
| F01 Release 2 must pass the checks | `mapping-existing.json` now assigns mechanics, laterality and difficulty to all 89 (proposed content, `mapping-existing.md` sections 4 and 6). Empty mechanics for the 16 cardio and mobility exercises is the stated default, with IC-207 made consistent (open: Q-M). Seed provenance author defined: "RepForge editorial (WP 8 seed)". Colliding aliases *Pullup*, *Chinup* and *Farmers walk* removed (`mapping-existing.md` section 7.1). A scratchpad run gives 0 errors, 94 warnings (IC-210 for 89 exercises, IC-311 2, IC-508 2, IC-304 1) and 16 infos |
| F02 Slot inventory | New `reference/coverage.json`: per group, slot id, patterns, discriminator (sub-target at L2/L3, laterality, equipment class, mechanics, or an optional exercise attribute), minimum and enumerated entries. `coverage-matrix.md` is generated from it. Six optional attributes proposed with the ADR-0008 implication (open: Q-A) |
| F03 No L4 primary minimums | All L4 sub-target minimums removed; the needs are carried by slot discriminators (`coverage-matrix.md` section 4). L4 tagging stays optional (editorial guide 5.6) |
| F04 Roles and primaries | Functional double tags are one primary and one secondary (editorial 5.7); an exercise fills at most one slot per group; new per-tranche metric: mean primaries per exercise at most 1.25 and at most 20 % with two or more. The row question (lats versus upperBack) and the other multi-primary candidates are one principle question (open: Q-P) |
| F05 Count by primary pattern | A group counts only exercises whose primary pattern is a slot pattern; cardio and mobility never count toward groups; baseline recomputed by script (section 4 here and `coverage-matrix.md` section 11) |
| F06 Diversity cap | One rule chosen: at most max(30 %, 4 exercises) of the group total in one family; the class cap uses max(55 %, 4); bodyweight exempt in abs, obliques, lower back |
| F07 Class minimums and forced entries | Class minimums re-derived from the inventory; rare implements are optional entries, not minimums; removed forced entries (deep hip rotators cable, rotator cuff machine, quadriceps cable, neck machine, biceps bodyweight, lower back quadratus lumborum slot); superficial variants trimmed in shoulders, biceps, flys and rear delts (curls 28 to 17); elbow versus knee flexion asymmetry explained. 5.1 is a pilot followed by an explicit re-baselining step |
| F08 fullBody alignment | `anatomy.md` 1.3, editorial 5.8, IC-304 and the mapping follow ADR-0010: flagged childless L1 node; secondary or beside anatomical primaries is open (Q-F). The proposal to promote `fullBody` to primary for `lib-skipping` is dropped: `calves` stays the only primary and the stored `fullBody` secondary is preserved and listed in the migration report. IC-304 applies to system content only; a migration-report rule covers user exercises with a `fullBody` secondary |
| F09 IC-900 columns | IC-900 enumerates `session_sets`, `session_exercises` (v7), `plan_exercises`, `exercises.copied_from_id`, user relationships, user exercise state and `legacy_quarantine` (information only). `tables.dart` checked: `scheduled_workouts` and `split_days` hold only plan and session ids; no exercise favourite column exists today |
| F10 Migration report | Also lists skipped duplicate secondaries and records rejected by the new rules (actions `skipped`, `rejected`) |
| F11 Near-duplicate signature | Equipment term ignores support items; logging type, category and name-token similarity added; ancestor lift defined (to L2); known pairs corrected; IC-412 relies on recorded attributes (otherwise a review checklist item). Re-run on the seed: 0 probable duplicates, 4 close matches, 7 similar, 12 family-link candidates (`quality-and-duplicates.md` section 6) |
| F12 Decision rules | Rules R1 to R8 in `movement-patterns.md` section 4: push press, thruster, back extension versus reverse hyperextension versus superman, upright row (home: `verticalPull`) and others |
| F13 Difficulty | "Free implement" removed as a driver; ballistic is intermediate unless combined with complex timing; dumbbell examples added; assigned difficulties re-checked (55 beginner, 34 intermediate, none advanced in the seed) |
| F14 L3/L4 convention | Documented in `anatomy.md` section 1 rule 7: L3 may be a named functional muscle set; L4 is a head, part or named member; debatable-list item 18 |
| F15 Mapping rows | Row 86 thoracic extension flagged M for the owner; row 63 hanging leg raise gains `hipFlexors` as a secondary (flag S) |
| F16 Definitions | Fixed: vastus medialis "last degrees" myth, biceps short head (coracoid process), teres minor (lateral border), trapezius (to T12), scalenes (first and second ribs), supraspinatus wording |
| F17 Splits | Erector spinae L4 split dropped; deep hip rotators keep the L2 group plus piriformis (others described in the group definition); neck rotation pattern `neckRotation` added |
| F18 Adductors | Adductors-under-Hip added to the debatable list (item 16); regional principle stated (`anatomy.md` section 1 rule 5) |
| F19 Relationships | `progressionOf` stored only; `regressionOf` is a derived view and is normalised on input; IC-406 withdrawn as redundant; IC-414 rewritten (longest `progressionOf` chain over 6 steps) |
| F20 Equipment items | `skiErg` and `stairClimber` added as proposed items (owner may instead remove both names from `ergometer`); slider curls removed (sliders listed as not proposed); `abWheel` and `stabilityBall` aligned to class bodyweight, role support |
| F21 Equipment roles | Per-exercise rule: an item is load if the resistance or assistance comes from it, otherwise support; `equipmentRoles` override; inverted row classifies as bodyweight |
| F22 Flags and JSON | Flag meanings re-checked (push-up R to N; step-up gains E; leg curls and hip abduction secondary refinements are R; hanging leg raise is S); `proposedEquipment` field added; this README now states exactly what the JSON holds |
| F23 Seed clean-up | Alias collisions, ambiguous, mis-spelt and meaning-changing aliases, and doubtful secondaries listed in `mapping-existing.md` section 7 and the JSON fields `aliasesRemove`, `aliasesAdd`, `cleanup`, `doubtfulSecondaries` |
| F24 Governance | Reference `lifecycle` (active, retired) and `reference/ledger.json`; accepted-gaps file format (`quality-and-duplicates.md` section 5.1); IC-110 recorded as a refinement of ADR-0009 (below) |
| F25 Alignment | `neckMotion` related categories (pull); `softTissueRelease` excludes field; face pull mechanics isolation, editorial guide aligned; hip and wrist-grip related categories aligned with the category table |
| OQ-19 wording | "Attributed set counts" used consistently (anatomy 1.9, editorial 5.10, README, ADR-0010 reference) |

**Clarifications to propose (the ADRs are not edited here):**
- **ADR-0009:** IC-110 refines decision 3. An identifier absent from a release is not retired by absence alone; the tool refuses a release that omits an id without listing it under `retirements`, so an accidental omission cannot retire an exercise.
- **ADR-0008:** (a) store `progressionOf` only; `regressionOf` is a derived view (decision 5); (b) optional controlled exercise attributes, if the owner approves Q-A; (c) the `fullBody` change is ADR-0010 (proposed).

## 7. Owner questions (deduplicated)
1. **Q-F, `fullBody` role.** May `fullBody` be a secondary target, and may it be a primary beside anatomical primaries? Affects `lib-skipping`, the migration report, IC-304 and the user exercises that already store it. (ADR-0010)
2. **Q-P, primary-target principle (one question).** When a compound movement is shared by several muscles, are the primaries only the muscle or muscles it is designed to load (the seed's practice), or every muscle doing main work through the main range? Lead example: rows (`lats` versus `upperBack`). The same answer decides deadlifts and Romanian deadlifts, dips, chin-up, hip abduction, hanging leg raise, clean and press and thoracic extension. It changes attributed set counts.
3. **Q-T, thoracic extension.** Primary `upperBack` with a stretched meaning, or `erectorSpinae` (flag M).
4. **Q-S, scope.** Include neck, pelvic floor and soft tissue release content at all? (Neck has 10 inventory entries; pelvic floor none; soft tissue release entries are optional and need `foamRoller`.)
5. **Equipment.** Approve the twelve additions, including `skiErg` and `stairClimber` (or remove both names from `ergometer`); keep or split the single generic `machine` id; confirm the per-exercise role rule and the aligned classes of `abWheel` and `stabilityBall`; confirm that sliders are not proposed.
6. **Q-C, coverage.** Approve the inventory, and approve that 5.1 is a pilot followed by an explicit re-baselining before 5.2 to 5.7; confirm the family cap (30 % or 4), class cap (55 % or 4) and the primaries-per-exercise thresholds.
7. **Q-A, attributes.** Approve six optional controlled exercise attributes (an ADR-0008 clarification), or decline and accept informational minimums for the slots that use them.
8. **Q-M, mechanics for cardio and mobility.** Empty by default (proposed), or force a value.
9. **Release-2 content.** Approve the proposed mechanics, laterality, difficulty, attributes, alias additions and removals and the seed author name.
10. **Anatomy placement.** Adductors under Hip, the L3 convention, deep hip rotators reduced to one L3 child, erector spinae unsplit (`anatomy.md` section 5).
11. **Duplicate checks.** Score thresholds (0.95, 0.85, 0.75), non-blocking flags cleared at tranche acceptance, IC-304 as a warning until Q-F.
12. **Content policy** (`provenance-and-licensing.md` section 8): is drafting assistance acceptable and must it be declared; are share-alike datasets out of scope; where attributions appear; is a legal review wanted before the first release with stage 5 content.

## 8. Not in scope
Catalogue content beyond the example in the editorial guide, code, schemas, assets, tests, screens, media and translation.
