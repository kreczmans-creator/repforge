# Exercise catalogue — WP 8 stage 4 outputs (approved)

- Status: **Approved by the owner 2026-11-05 (OQ-22 / OQ-23).** The reference data, mapping, rules and specifications in this folder are approved as the controlled content for WP 8 stage 3 and stage 5. Nothing here is implemented in the app yet. **Stage 5: authorised in principle; bulk population only after WP 8 stage 3 reference-data, integrity and migration tooling is implemented and verified, and after the 5.1 pilot gate.**
- Scope: WP 8 stage 4, catalogue tooling and quality assurance, **documentation and reference data only** (authorised 2026-11-05, `docs/wp8-delivery-plan.md` section 18). No file under `app/` changes. No WP 9 file is touched.
- Date: 2026-11-05. History: revision 2 followed an independent review (F01 to F25, section 6); revision 3 a re-verification (N1 to N10, section 6a); the owner approved stage 4 on 2026-11-05 (section 7).
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

## 2. Questions these outputs answered
| Id | Question | Where answered | Owner action |
|---|---|---|---|
| OQ-22 | Anatomy node list and movement pattern list | `anatomy.md`, `movement-patterns.md`, `mapping-existing.md` | Approved 2026-11-05 |
| OQ-23 | Coverage matrix minimum targets per region | `coverage-matrix.md`, `reference/coverage.json` | Approved 2026-11-05 |

Both lists carry definitions, inclusion and exclusion criteria, so the reviewer can see where a muscle with two functions is filed.

## 3. How the outputs feed the stages
- **Stage 3 (architecture and reference data, gated):** loads `reference/*.json` into the reference tables; implements the checks in `quality-and-duplicates.md`; re-expresses the 89 exercises as release 2 using `mapping-existing.json` (which passes the error checks, `quality-and-duplicates.md` section 6); builds the migration report specified there. The JSON files are the proposed content of catalogue release 2's reference data.
- **Stage 5 (population):** authors work from the editorial guide, tag against the reference lists, and are accepted against the slot inventory. Stage 5 is authorised in principle; bulk population starts only after stage 3 tooling is implemented and verified and after the 5.1 pilot gate (mandatory re-baselining, explicit owner approval before 5.2 to 5.7).
- **Stage 6 (discovery):** filters use the same lists. Labels are display text and may be reworded.

## 4. Summary of the approved content
- Anatomy: 126 nodes (10 L1, 26 L2, 63 L3, 27 L4). All 19 existing ids are kept at the planned levels and with the planned parents. `fullBody` is a flagged, childless L1 node (ADR-0010, proposed).
- Movement patterns: 17 families, 62 patterns (neck rotation added), decision rules R1 to R8.
- Equipment: 21 existing ids unchanged, 12 proposed additions (one conditional); ski ergometer and stair climber added at revision 2.
- Coverage: 21 anatomical groups with 325 slot minimums, every one derived from enumerated intended entries; 70 conditioning, power and mobility entries (kept separate from the anatomical groups). Tranche 5.1 is a pilot. The seed fills 67 of the 325 slots and covers 20 of the 70 conditioning, power and mobility entries (recomputed, section 6).
- Release 2: all 89 seed exercises have mechanics (or the empty default for cardio and mobility), laterality and difficulty as **proposed content**; the integrity checks give zero errors.
- Rules that cut across all documents: original content only; qualitative anatomy; per-muscle figures are *attributed set counts*, not physiological measurements of muscle stimulus; retired exercises and retired reference ids are never deleted and their ids are never reused; every historical reference must resolve.

## 5. Review status
Reviewed and approved by the owner on 2026-11-05, with the decisions in section 7:
1. The anatomy list (126 nodes, the 19 existing ids, the proposed placements) and the movement pattern list (17 families, 62 patterns, 79 entries including families, rules R1 to R8): OQ-22.
2. The equipment additions (12) and the per-exercise role rule.
3. The mapping of the 89 existing exercises, including the release-2 classifications.
4. The coverage inventory: 325 slot minimums in 21 groups and 70 conditioning, power and mobility entries: OQ-23.
5. The editorial guide, population standards, provenance rules and quality specification.

## 6. Revision 2 (review findings F01–F25) — history
Each finding and what changed. "Open" means the owner decides; nothing was decided on the owner's behalf.

| Finding | Change |
|---|---|
| F01 Release 2 must pass the checks | `mapping-existing.json` now assigns mechanics, laterality and difficulty to all 89 (proposed content, `mapping-existing.md` sections 4 and 6). Empty mechanics for the 16 cardio and mobility exercises is the stated default, with IC-207 made consistent (open: Q-M). Seed provenance author defined: "RepForge editorial (WP 8 seed)". Colliding aliases *Pullup*, *Chinup* and *Farmers walk* removed (`mapping-existing.md` section 7.1). A scratchpad run gives 0 errors, 94 warnings (IC-210 for 89 exercises, IC-311 2, IC-508 2, IC-304 1) and 16 infos |
| F02 Slot inventory | New `reference/coverage.json`: per group, slot id, patterns, discriminator (sub-target at L2/L3, laterality, equipment class, mechanics, or an optional exercise attribute), minimum and enumerated entries. `coverage-matrix.md` is generated from it. Optional attributes proposed (seven after revision 3) with the ADR-0008 implication (open: Q-A) |
| F03 No L4 primary minimums | All L4 sub-target minimums removed; the needs are carried by slot discriminators (`coverage-matrix.md` section 4). L4 tagging stays optional (editorial guide 5.6) |
| F04 Roles and primaries | Functional double tags are one primary and one secondary (editorial 5.7); an exercise fills at most one slot per group; new per-tranche metric: mean primaries per exercise at most 1.25 and at most 20 % with two or more. The row question (lats versus upperBack) and the other multi-primary candidates are one principle question (open: Q-P) |
| F05 Count by primary pattern | A group counts only exercises whose primary pattern is a slot pattern; cardio and mobility never count toward groups; baseline recomputed by script (section 4 here and `coverage-matrix.md` section 11) |
| F06 Diversity cap | Revision 2 chose max(30 %, 4); **superseded in revision 3 (N1): the family cap is dropped.** The class cap max(55 %, 4) stays; bodyweight exempt in abs, obliques, lower back |
| F07 Class minimums and forced entries | Class minimums re-derived from the inventory; rare implements are optional entries, not minimums; removed forced entries (deep hip rotators cable, rotator cuff machine, quadriceps cable, neck machine, biceps bodyweight, lower back quadratus lumborum slot); superficial variants trimmed in shoulders, biceps, flys and rear delts (curls 28 to 17); elbow versus knee flexion asymmetry explained. 5.1 is a pilot followed by an explicit re-baselining step |
| F08 fullBody alignment | `anatomy.md` 1.3, editorial 5.8, IC-304 and the mapping follow ADR-0010: flagged childless L1 node; secondary or beside anatomical primaries is open (Q-F). The proposal to promote `fullBody` to primary for `lib-skipping` is dropped: `calves` stays the only primary and the stored `fullBody` secondary is preserved and listed in the migration report. IC-304 applies to system content only; a migration-report rule covers user exercises with a `fullBody` secondary |
| F09 IC-900 columns | IC-900 enumerates `session_sets`, `session_exercises` (v7), `plan_exercises`, `exercises.copied_from_id`, user relationships, user exercise state and `legacy_quarantine` (information only). `tables.dart` checked: `scheduled_workouts` and `split_days` hold only plan and session ids; no exercise favourite column exists today |
| F10 Migration report | Also lists skipped duplicate secondaries and records rejected by the new rules (actions `skipped`, `rejected`) |
| F11 Near-duplicate signature | Equipment term ignores support items; logging type, category and name-token similarity added; ancestor lift defined (to L2); known pairs corrected; IC-412 relies on recorded attributes (otherwise a review checklist item). Re-run on the seed: 0 probable duplicates, 4 close matches, 7 similar; IC-412 family-link candidates 12 at revision 2 and 16 after revision 3 (`quality-and-duplicates.md` section 6) |
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

## 6a. Revision 3 (N1–N10) — history
| Item | Change |
|---|---|
| N1 Family cap | Chosen: **drop the family cap**. It contradicted the variation rules (a bench press family can hold 18 variations against a cap of 10.8; the 17 curls of biceps and the 9 calf raises are each one family). Slots already enforce diversity, so no root-naming is needed. The minimum number of families and the class cap (checked against the inventory by the validation script) remain |
| N2 Attributes | Seven optional attributes (angle, armPosition, grip, gripWidth, bodyPosition, kneePosition, stance), each with a definition and a boundary rule per value, in `coverage.json` and `coverage-matrix.md` section 3. Values added: armPosition `flexed90`; bodyPosition `prone`, `kneeling`, `halfKneeling`, `inclined`; grip `mixed`; gripWidth `close`, `standard`, `wide`; stance `narrow`, `split`. If Q-A is declined, the fallback is a **CI-measurable pattern-level minimum**: for each (group, pattern) pair with an attribute-discriminated slot, the sum of that pair's slot minimums (`attributeFallback`, 7 pairs), not informational |
| N3 IC-412 | Attributes clear IC-601 to IC-603 only. IC-412 now also fires when a recorded attribute differs and the rest of the signature matches, because the pair still needs a family link. The §9 claim is corrected. IC-412 worklist: **16 pairs** (was 12) |
| N4 Entries rejected by the variation test | Now optional (not counted): interval run, interval cycling, interval rowing, 400 m run (pending the duplicate decision), weighted plank, weighted side plank, weighted back extension, weighted crunch, plate-loaded pulldown machine |
| N5 Back extension rule R5 | Anatomical rule adopted: classified by the joint that moves, set by technique. A moving spine is `trunkExtension` with lowerBack primary; a neutral spine with the hips as the hinge, and reverse hyperextension, are `hipExtension` with glutes or hamstrings primary (as Q-P settles) and lowerBack secondary. The lower-back slots were re-derived honestly: minimum 8 to 5 (good mornings are optional and depend on Q-P; hip-driven back extension is an optional glutes entry) |
| N6 Category rule | Chosen: only categories push, pull, legs and core count toward anatomical groups; fullBody, cardio and mobility are measured in the 5.7 sets. The thruster no longer fills `quadriceps.squatFreeWeight`; the kettlebell swing moved to a new set `conditioning.ballisticHinge` (category fullBody) |
| N7 Seed clean-up | Added to the list: aliases Hanging knee raise, Figure-four stretch, Sit-up crunch, Triceps dip, Single-arm row, Prowler push, Calf raise, Rowing; wall sit calves secondary as doubtful |
| N8 Glute slots, Pallof, difficulty | Hip thrust and bridge are now `isolation` (consistent with reverse hyperextension and kickbacks); the glute hip-extension slots are separated by recorded body position (inclined or lying, kneeling or standing, prone) plus class and laterality, not mechanics. Pallof press is bilateral. The difficulty driver reads "two independent loads in a multi-joint press or hinge" |
| N9 Wording | R6: high pulls do not catch; anatomy rule 7 (L3 sets with FCR, FCU and finger flexors as L4 members; iliopsoas); regional principle (hamstrings act at hip and knee); sideDelts excludes ("helps start abduction") and the editorial example |
| N10 ADR-0010 | Not touched. Its "excluded or shown separately" wording is folded into Q-F |

New totals: 325 slot minimums (Chest 36, Upper back 25, Lats 20, Shoulders 35, Rotator cuff 10, Neck 10, Biceps and brachialis 17, Triceps 24, Forearms 19, Glutes 25, Abductors 3, Adductors 4, Hip flexors 4, Deep hip rotators 3, Quadriceps 28, Hamstrings 13, Calves 9, Shin and outer lower leg 4, Abs 18, Obliques 13, Lower back 5). Seed fill 67 of 325. Conditioning, power and mobility entries: 70.

**ADR clarifications to record (the ADRs are not edited here):**
- **ADR-0009:** IC-110 refines decision 3. An identifier absent from a release is not retired by absence alone; the tool refuses a release that omits an id without listing it under `retirements`, so an accidental omission cannot retire an exercise.
- **ADR-0008:** (a) store `progressionOf` only; `regressionOf` is a derived view (decision 5); (b) optional controlled exercise attributes (approved by the owner 2026-11-05); (c) the `fullBody` change is ADR-0010 (approved).

## 7. Owner decisions (2026-11-05)
Each decision replaces the open question of the same name in the history above.
1. **OQ-22 approved.** The 126-node anatomy, 17 families and 62 patterns (79 entries including families), decision rules R1 to R8, the 19 existing ids and the proposed placements.
2. **Scope.** The neck is **included** (conventional gym exercises). Pelvic floor content is **excluded**: its node and id stay in the reference data, marked "content excluded by owner decision", with no entries. Soft tissue release is **deferred**: the `foamRoller` item is approved among the 12 additions, but the `softTissueRelease` pattern stays optional and its count is 0.
3. **Primary-muscle principle (resolves Q-P and Q-T).** *Primary targets are the muscles an exercise is designed and normally selected to train. Other muscles making significant contributions are secondary targets.* Individual disputed assignments are resolved in the tranche content reviews, and no primary is added merely because a muscle contributes significantly. Thoracic extension follows the principle at tranche review.
4. **`fullBody` (resolves Q-F; ADR-0010 approved).** A flagged, childless, non-anatomical L1 node. It may only be the single primary of a qualifying whole-body or conditioning exercise; never a secondary; never alongside anatomical primaries. It is excluded from anatomical roll-ups, coverage and attributed muscle set counts, and shown separately in reports, labelled non-anatomical. Existing stored secondary references are preserved and listed in the migration report. `lib-skipping` keeps `calves` as its primary; its stored `fullBody` secondary is preserved historically and reported, and release-2 system content removes it from the active tags. IC-304 is an error for system content; for user content a warning plus a migration-report entry, never silently discarded.
5. **OQ-23 approved.** 325 slot minimums in 21 groups; a separate set of 70 conditioning, power and mobility entries; the counting rules; one slot per exercise per group; primary targets determine coverage; no L4 minimums; superficial variations optional; the class cap; the release-2 classifications; the duplicate thresholds. Tranche 5.1 (chest) is the pilot, followed by a mandatory re-baselining and the owner's explicit approval before 5.2 to 5.7. The seed baseline of 67 of 325 and 20 of 70 is accepted. **The coverage framework is an acceptance mechanism, not a demand to populate exercises to satisfy numbers; quality and meaningful variation take precedence.**
6. **Equipment.** All 12 additions approved (including `skiErg` and `stairClimber`). One generic `machine` id is retained; a later split is a reference-data enhancement. The load/support role rule is approved.
7. **Attributes (resolves Q-A).** All seven optional attributes with their vocabulary and boundary rules are approved. The attribute fallback is **not required** and is marked not used in `coverage.json`.
8. **Mechanics (resolves Q-M).** Empty for cardio and mobility.
9. **Content policy.** AI drafting assistance is permitted and recorded in provenance; a named human editor is the accountable author. Share-alike datasets are excluded entirely. Attribution is shown on a credits screen. A legal review is required before the first public release. Original RepForge content remains the default; third-party datasets only with demonstrably compatible provenance and licensing.
10. **Stage 5.** Authorised in principle. Bulk population only after WP 8 stage 3 reference-data, integrity and migration tooling is implemented and verified, and after the 5.1 pilot gate.
11. **Deferred (unchanged):** X1 to X4 stay deferred.

## 8. Not in scope
Catalogue content beyond the example in the editorial guide, code, schemas, assets, tests, screens, media and translation.

## Independent review status (2026-11-05)
- Review of e9e00f1: findings F01–F25 (3 High). Revision 2 (2a384c3) re-verified: 21 resolved, 4 partial; new N1–N10. Revision 3 (45ec71c) spot re-check: N1, N2, N4–N9 resolved; N3 and N10 partial (non-blocking).
- **Verdict: OQ-22 and OQ-23 were ready for owner review; the owner approved them on 2026-11-05 (section 7).** Reviewer recomputed independently: 126 anatomy nodes, 79 patterns, 33 equipment entries; 325 slot minimums in 21 groups, 70 conditioning, power and mobility set entries; seed fill 67/325 and 20/70; IC-412 worklist 16 pairs; class cap holds.
- Deferred to stage 3a or the 5.1 pilot (not owner decisions): **X1** make attribute boundaries contiguous (angle 10–15°, arm 20–90°, knee angles); **X2** IC-412 token gate hides attribute-only variations with different names (sumo deadlift, chin-up, hammer curl, assisted dip) — skip the gate when a recorded attribute differs, and correct the §6 claim; **X3** `trunkExtension` includes machine back extensions only "when the spine moves"; **X4** thruster and trap bar deadlift count toward no group; 400 m run seed fill relies on an optional entry — note in the gap report.
