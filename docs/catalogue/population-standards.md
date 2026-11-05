# Catalogue population standards — proposed

- Status: **Proposed — for owner approval.** WP 8 stage 4 (documentation only). Population (stage 5) does not start until the owner approves this document, the coverage matrix (OQ-23) and the reference lists (OQ-22), and stage 3 delivers the catalogue format and reconciler.
- Requirements: LIB-001..LIB-007, LIB-011..LIB-013; owner decisions 2, 6 and 10.
- Related: `coverage-matrix.md`, `reference/coverage.json`, `editorial-guide.md`, `quality-and-duplicates.md`, `provenance-and-licensing.md`, `mapping-existing.md`.
- Revision 2 (review findings F01, F02, F04, F07, F08, F19, F23, F24): release 2 content is assigned for all 89 exercises; tranche acceptance is measured against the slot inventory; 5.1 is a pilot followed by a re-baselining step.

## 1. Tranche plan
One catalogue release per tranche. Each tranche is complete only when its coverage-matrix groups are met (all dimensions, not only the count), every entry meets the definition of done (section 3), and the integrity report has zero errors.

| Tranche | Scope (L2 groups) | Release | Canonical families to author first (examples) | Needs approved equipment |
|---|---|---|---|---|
| 5.1 Chest (**pilot**) | `chest` (pectoralis major heads, pectoralis minor, serratus anterior) | 3 | Bench press, incline press, decline press, fly, push-up, cable crossover, serratus push-up plus | suspensionTrainer (optional) |
| 5.2 Back | `upperBack`, `lats` | 4 | Pull-up, chin-up, pulldown, bent-over row, cable row, shrug, scapular retraction, straight-arm pulldown | suspensionTrainer; landmine (optional: T-bar and Meadows rows) |
| 5.3 Shoulders and neck | `shoulders` (3 heads), `rotatorCuff`, neck groups (if the owner includes neck, Q-S) | 5 | Overhead press, lateral raise, upright row, front raise, rear-delt fly, external rotation, neck flexion and extension | none required |
| 5.4 Arms | `upperArmAnterior`, `upperArmPosterior`, `forearms` | 6 | Barbell curl, hammer curl, preacher curl, triceps extension, pushdown, close-grip press, wrist curl, farmer's hold | preacherBench |
| 5.5 Hips and legs | `glutes`, `abductors`, `adductors`, `hipFlexors`, `hipExternalRotators`, `quadriceps`, `hamstrings`, `calves`, shin and outer lower-leg groups | 7 | Squat, lunge, leg press, hinge, hip thrust, leg curl, calf raise, hip abduction and adduction | plyoBox, stabilityBall |
| 5.6 Trunk | `abs`, `obliques`, `lowerBack` (and `pelvicFloor` if approved) | 8 | Crunch, leg raise, plank, rollout, woodchop, side bend, back extension, good morning | abWheel, hyperextensionBench, stabilityBall |
| 5.7 Conditioning and mobility | `fullBody`, categories `cardio`, `fullBody`, `mobility` | 9 | Run, row, bike, ski ergometer, stair climber, skip, sled, crawl, jump, throw, clean derivatives, stretches, spinal mobility | skiErg, stairClimber, sled, battleRopes, plyoBox (box jump), foamRoller (conditional) |

Order: 5.1 runs first as a **pilot**. The pilot is followed by an explicit **re-baselining step** (`coverage-matrix.md` section 1): the slot inventory in `coverage.json`, the thresholds (duplicate score, caps, primaries per exercise), the difficulty bands and the attribute proposal are re-derived from what the pilot showed, and the owner approves the revised files before 5.2 to 5.7 proceed. Tranches can run in parallel after that. Release numbers are indicative; the reconciler assigns the next free number.

Every tranche re-enriches the existing seed exercises that belong to it (section 4), in the same release.

## 2. Roles and review workflow
| Step | Who | Output | Gate |
|---|---|---|---|
| 1. Plan | Editor | List of canonical families and planned entries per slot (from the matrix) | Reviewed against the matrix |
| 2. Author | Author (editor) | Draft release file: all fields, content, relationships, provenance | Author runs the integrity tool locally |
| 3. Integrity check | Tool (CI) | Integrity report and coverage report | Zero errors; warnings dispositioned |
| 4. Independent review | A reviewer who is not the author | Review log: findings by entry, with severity | All findings fixed or accepted by the owner |
| 5. Owner content review | Owner | Sign-off on the tranche, plus accepted gaps | Written acceptance in the delivery record |
| 6. Release | Maintainer | Tagged release; report artefacts published | CI green on four workflows |

The independent review covers: naming and aliases, variation test (including the superficial-variant risk in shoulders, biceps, flys and rear delts), anatomical tagging and the primaries-per-exercise metric, difficulty, mechanics and laterality, relationship choice, equipment roles and attributes, instruction quality and safety wording, originality (no copying), and near-duplicate dispositions. It samples at least 20 % of new entries in depth (all entries for the pilot) and reads every entry flagged by the tool.

Records: review log and sign-off live in the WP 8 delivery record. The report artefacts are build outputs.

## 3. Entry definition of done
An entry is done when all of these hold.
1. Id follows the editorial guide and is unique; revision set.
2. Name follows the naming convention; 60 characters or fewer; UK spelling.
3. Aliases (up to six) include common US names; none collide with another name or alias.
4. Logging type and category set and consistent with the pattern (warnings dispositioned).
5. At least one primary target; targets at the most defensible level; no node and ancestor both tagged; no `fullBody` as a secondary or beside anatomical primaries in new content (until Q-F is answered).
6. At least one movement pattern; the first is the primary pattern.
7. Equipment list complete, using approved ids only (empty if none).
8. Mechanics, laterality and difficulty set (mechanics may be empty only for cardio and mobility, proposed default, if the owner confirms Q-M). Optional attributes recorded where a coverage slot or the duplicate check uses them; equipment role overrides carry a note.
9. Relationships set: `variationOf` (if derived), `progressionOf` (if a ladder step; regression is derived), `unilateralCounterpartOf` (if a twin exists), `alternativeTo` (if a clear substitute exists).
10. The variation test passes (editorial guide, section 3), or a reason is recorded.
11. Four instruction sections present, with item counts and lengths inside the limits; active voice; safety wording; no medical claim; no numbers of repetitions or loads.
12. Provenance: provider `repforge` (or an admitted dataset) and author recorded; originality statement given for the tranche.
13. Near-duplicate flags dispositioned.
14. No media is required. Media references are optional and follow the licence rules.
15. Integrity tool shows no error for this entry.

## 4. Keeping and enriching the 89 existing exercises
1. **Ids are kept.** No existing id is changed, reused or removed.
2. **Release 2** (stage 3c) re-expresses the 89 exercises in the new format with targets, patterns, equipment, equipment roles, mechanics, laterality, difficulty and optional attributes from `mapping-existing.json`. **All 89 are assigned** so that release 2 passes the integrity checks (F01); the values are proposed content for owner review. Mechanics are empty by default for the 16 cardio and mobility exercises (Q-M). The three colliding aliases are removed and the provenance author is "RepForge editorial (WP 8 seed)". Instructions are not written yet (IC-210 stays a warning).
3. **Tranche releases** enrich the exercises that belong to the tranche: instructions, any remaining classification, relationships and attributes (the pairs listed under IC-412 in `quality-and-duplicates.md` section 6 are the worklist), alias clean-up (`mapping-existing.md` section 7) and equipment corrections. Each change that alters a system-owned field raises the revision by one in that release.
4. **Names.** A name may change only to correct an error or to follow the naming convention. The old name becomes an alias. The id stays.
5. **Meaning.** If a change would give an exercise a different meaning (a different movement), retire the old entry and add a new id. A change of tag on the same movement is an enrichment, not a new meaning.
6. **Primary-target changes** (flags M and D in `mapping-existing.md`, summarised as the single principle question Q-P) need owner decision, because they change attributed set counts in WP 9.
7. **User data.** Plans, sessions and sets that reference the 89 ids keep working. A custom copy of an exercise is never changed by a release; it receives a "source updated" marker.
8. **Known fixes:** `lib-ab-wheel`, `lib-sled-push`, `lib-preacher-curl`, `lib-step-up` and `lib-lat-pulldown` equipment and the role of the barbell in `lib-inverted-row`; `lib-hip-flexor-stretch` primary; `lib-thoracic-extension` primary (M, owner); `lib-skipping` keeps `calves` as its only primary, with its `fullBody` secondary preserved and reported (Q-F); consistent row primaries (Q-P); `lib-run-400m` and `lib-outdoor-run` as one family or a merge.

## 5. Retirement rules
1. Retire only for: a duplicate that cannot be merged by relationships, a factual error that edits cannot fix, a safety problem, or a withdrawn licence. Never retire to change a classification (edit instead).
2. The owner approves each retirement. The release file lists it in a `retirements` section with the id, the reason and, where one exists, the id that replaces it.
3. A retirement never deletes the row. The id is kept in the registry and is never reused.
4. A retired exercise stays readable in history, personal-record and set-count queries, is hidden from discovery and cannot be added to new plans. Starting a session from a plan with a retired exercise follows the WP 9 archived-exercise behaviour.
5. Active system exercises must not link to a retired exercise. Remove or move the links in the same release.
6. A custom copy of a retired exercise remains untouched.
7. Every set and plan reference must still resolve to an existing row, including retired rows. The integrity check (IC-900) enforces this.
8. Absence from a release does not retire an id by itself: the tool refuses a release that omits an id without listing it in `retirements` (IC-110; this refines ADR-0009, which treats absence as retirement), so that an accidental omission cannot retire an exercise.
9. Reference data (anatomy nodes, patterns, equipment) is retired the same way: set `lifecycle` to `retired` and record it in `reference/ledger.json` with the release, the reason and any replacement. A retired reference id is never removed, never reused and never used by an active exercise (IC-810, IC-313).

## 6. Tranche acceptance
A tranche is accepted when:
1. Its coverage groups fill every slot and meet every dimension of `coverage.json`, or the owner accepts each remaining gap in the accepted-gaps file (`quality-and-duplicates.md` section 5.1).
2. Zero integrity errors; warnings dispositioned.
3. Instructions exist for every system exercise in the tranche.
4. Independent review findings are fixed or accepted.
5. The owner signs off the content review.
6. The gap report is attached to the delivery record.
