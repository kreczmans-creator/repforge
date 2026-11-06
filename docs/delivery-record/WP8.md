# Delivery record — WP 8: Exercise library and training architecture

Date: 2026-11-05
Branch: `ccr-9fda2c32-wr163b`
Status: **Active — scope expanded 2026-11-05** (owner decision: the comprehensive exercise library is delivered within WP 8; no WP 16). Not accepted. Stages 1–2 and the review fixes are implemented and verified; stages 3–6 remain (`docs/wp8-delivery-plan.md`, proposed, not authorised). WP 6 device verification and D05 V-01 remain open and owner-owned; they do not block WP 8.

## WP 8 overview (revised 2026-11-05)
| Category | Status | Where |
|---|---|---|
| **1. Implemented and verified** | Stage 1 (6d401e6), stage 2 (058d433), review fixes (b1ab45a); four workflows green on each; independent review and re-verification complete | "What was built", "Independent review", "Tests, CI" below |
| **2. Original WP 8 acceptance criteria (D06)** | Met with evidence; not accepted | "Acceptance criteria (D06 WP 8) and evidence" below |
| **3. Newly approved expanded requirements** | LIB-001..014 and the owner's library decisions (D04 §7, 2026-11-05); TRN-010(1) amended to one or more primary targets. The 89-exercise implementation is a foundation and does **not** satisfy them (gap analysis: `docs/exercise-library-expansion.md` §2) | `docs/exercise-library-expansion.md` |
| **4. Remaining implementation work** | Stage 3 architecture and reference data (3a–3d), stage 4 catalogue tooling and quality assurance (documentation approved 2026-11-05), stage 5 anatomical catalogue population (tranches 5.1–5.7), stage 6 search, discovery and exercise screens **including exercise history paging (TRN-025(2), allocated from WP 9 M4, 2026-11-05)**; media workstream deferred | `docs/wp8-delivery-plan.md` §0.1 |
| **5. Final WP 8 acceptance criteria** | Original criteria plus stage 3–6 criteria, coverage matrix, no WP 9 regressions, open decisions dispositioned, final independent review | `docs/wp8-delivery-plan.md` §15 |

Decided 2026-11-05 (D04 §7): ADR-0008 and ADR-0009 direction; 19 muscle ids and `fullBody`; conditional `exercises` rebuild; OQ-19 (set counts; kg-volume clarification pending); OQ-21; legacy invalid values (earlier decision 3, with a report of every affected record); TRN-020 RIR integer 0–5 at domain and persistence boundaries (earlier decision 4); screen ownership (earlier decision 5). **Stage 4 authorised** (documentation and reference data only). **Stage 3 gated** until WP 9 delivery is accepted. Confirmed 2026-11-05: OQ-19 terminology (attributed set counts, not physiological measurements); retired-exercise integrity check. **Stage 4 approved 2026-11-05**: OQ-22 and OQ-23 approved, ADR-0010 accepted, primary-muscle principle and related decisions recorded (D04 §7); outputs in `docs/catalogue/` (commits e9e00f1, 2a384c3, 45ec71c, 9ef7f07 and the approval update), three independent reviews. Stage 5 authorised in principle behind the stage 3 tooling and 5.1 pilot gates. Still open: rebuild evidence (before sub-stage 3b is finalised); final authorisation of stage 3 after WP 9 acceptance.

**Architecture records for WP 8 stage 3:** ADR-0008 (exercise library domain model) and ADR-0009 (catalogue provenance and updates), direction accepted 2026-11-05; implementation gated. They were first drafted for the WP 16 proposal and keep their numbers and history; the WP 16 proposal is superseded by the WP 8 scope decision and no WP 16 implementation is authorised. Earlier decision 1 (taxonomy) is folded into the anatomy decision and OQ-22 (current lists stay in force until stage 3); earlier decision 2 (OQ-09) is answered.

## Scope (D06 WP 8)
Exercise library (seeded, editable), categories, muscle groups, equipment, exercise type with type-specific set fields, workout plan and split models, history queries.
Acceptance (D06): a set of each exercise type can be stored and read back with correct fields; invalid combinations rejected at use-case level. Verification: unit tests; schema migration test.
Requirements: D04 TRN-001..012 (P1), TRN-013 (P1, model and reorder; the plan-builder screen is WP 9), TRN-014 (P2, split model), TRN-007 (P2, cardio energy).
Debt owned here: TD-23 (exercise archive guard), TD-25 (database CHECK constraints with the next schema version).

## Gap analysis against the WP 3 training model
| Requirement | WP 3 state | WP 8 change |
|---|---|---|
| TRN-005 timed set with optional added load; mm:ss entry | duration only | add optional added load; `parseDuration('mm:ss')` domain rule |
| TRN-006 km display at ≥ 1000 m | none | display rule, stored metres unchanged |
| TRN-007 cardio energy expended, labelled, not in nutrition balance | missing | optional energy with provenance; never read by nutrition |
| TRN-008 supplied vs custom, custom copy on edit, search by name and aliases ignoring case/diacritics | `isCustom` only | aliases, search key, copy-on-edit use case |
| TRN-009/010/011 controlled lists, filters | free text | enums per `docs/training-taxonomy.md`; filter queries (muscle: primary first; equipment: subset of available) |
| TRN-012 custom exercises, archive hides from pickers, kept in history | archive exists; TD-23 guard missing | validation use case; TD-23 guard |
| TRN-013 rep **range**, duration or distance targets, rest, reorder | single target reps | reps min–max, duration, distance targets; reorder rule |
| TRN-014 split: named workouts over a 1–14-day cycle with rest days | free-text `split` | split model and table |
| D06: invalid set/exercise combinations rejected at use-case level | no set-writing use case | `RecordSet` use case validating type match, reps 1–100, exertion, load/assistance steps, positive durations and distances (this also makes the WP 3 deferral of `validReps`/`validExertion` enforceable on the first exposed set-writing path) |
| History queries | sets for an exercise | per-exercise history by session, last performance |
| TD-25 | no CHECK constraints | CHECK constraints on training tables in schema v6 |

## Decisions (owner confirmation requested at delivery)
1. **Controlled lists**: `docs/training-taxonomy.md` (7 categories, 19 muscle groups, 21 equipment items), proposed for approval.
2. **OQ-09 exercise library source**: assumed RepForge's own content (names, aliases, classifications; no media). Owner decision required; replacing the seed asset is self-contained.
3. **UI scope**: WP 8 delivers the Train tab's exercise library (browse, search, filter, detail, custom exercise create/edit/archive). The plan builder, scheduling and session screens are WP 9.

## What was built
| Stage | Commit | Content |
|---|---|---|
| Seed content | df326db | 89-exercise library (own content), asset test |
| 1 — domain, schema v6, use cases | 6d401e6 | taxonomy enums; exercise aliases/supplied/copy; timed added load; cardio energy; rep ranges; splits; validation rules; `RecordSet`; library and history queries; schema v6 with CHECK constraints and legacy quarantine; library import. CI 41981492310, Android 41981492309, iOS 41981492295, integration 41981492328 — all success (the on-device test opened a real database file at schema v6; a fresh install, so it exercised creation, not the v5→v6 upgrade — corrected at delivery). |
| 2 — Train tab library | 058d433 | library with search, category/muscle/equipment filters, persisted equipment selection, supplied/custom badges, archived toggle; exercise detail with per-type history formatting; custom exercise editor; copy-on-edit for supplied exercises. CI 41987520072, Android 41987519880, iOS 41987519687, integration 41987519799 — all success. |
| Review fixes | b1ab45a | M1–M4, L1–L6 below; architecture guards; D05 TD-23, TD-25, TD-41, TD-42 |

### Stage 1 — training domain, schema v6, use cases (no UI)
- **Domain** (`app/lib/domain/training/`): enums `ExerciseCategory`, `MuscleGroup`, `Equipment` exactly per the taxonomy; `Exercise` with aliases, `supplied` (the one provenance concept; `isCustom` is derived) and `copiedFromId`; timed sets with optional added load; cardio energy with a `userEntered`/`estimated` label (never read by nutrition); plan exercises with reps range, duration, distance, load, rest, order; `TrainingSplit`/`SplitDay`. Pure rules in `training_validation.dart` (`parseDuration`, `formatDistance`, `normaliseExerciseSearch`, `validateExercise`, `validateSetForExercise`, `validatePlanExercise`, `validateSplit`, `reorder`) and `exercise_query.dart` (`ExerciseQuery`, `filterExercises`). `normaliseSearchKey` moved to `domain/core/search_key.dart` (still exported from the nutrition mappers). `LoadKg.strict` refused a value that is not a 0.25 kg step (superseded in the review fixes: `LoadKg.of` itself is now strict, M1).
- **Queries**: `watchLibrary`/`search` (text, category, muscle with primary first, equipment subset, archived hidden); `sessionsForExercise` (completed sets per session, newest first, paged), `lastPerformance`, `hasHistory`; `exists`, `delete`, and `archive` guarded by `deleted_at IS NULL` (TD-23, returns whether a row changed).
- **Schema v6** with CHECK constraints (TD-25) and the `legacy_quarantine` decision: see `docs/data-model.md` (Migrations 5 → 6).
- **Use cases** (`app/lib/features/training/application/`): `SaveCustomExercise`, `CopySuppliedExercise`, `ArchiveExercise`, `RecordSet`, `SavePlan`, `SaveSplit`, `ImportExerciseLibrary` (started from `main.dart` after the first frame, like the recipe import) and providers.

## Independent review (fresh reviewer, range 64599f3..058d433)
No high-severity defects; D06 acceptance holds in substance. Findings (verified by probe):

| ID | Finding | Severity | Resolution |
|---|---|---|---|
| M1 | Off-step loads (80.1 kg) and small negatives are rounded, not rejected, so TRN-002(2) is not enforced at use-case level; the strict constructor had no caller | Medium | Fixed: `LoadKg.of` is the single strict input constructor (rejects off-step and negative, 1e-9 tolerance, -0.0 is 0); `fromStored`/`tryFromStored` for database reads; dead `_loadError` and `LoadKg.strict` removed |
| M2 | `WorkoutSessionRepository.upsert` re-inserts sets without validation (no caller today; WP 9 risk) | Medium | Fixed: `upsert` writes the session row only; sets go through `addSet` (used by `RecordSet`) |
| M3 | Exertion rule allowed RIR 0–10 in half steps; D04 TRN-020 says RIR 0–5 whole numbers (RPE 1–10 in 0.5 steps). Inherited from WP 3, never an owner decision | Medium | Fixed: RPE 1–10 in 0.5 steps, RIR 0–5 whole; the looser v6 CHECK stays (domain stricter) |
| M4 | A migrated exercise with unrecognised category/muscle/equipment text becomes unreadable with no record; taxonomy labels were not recognised | Medium | Fixed in the mapping helper (not the v6 tables): identifiers, labels and a short synonym table matched; unmatched optional values dropped and the original quarantined; unmatched required values quarantined and the row kept. Applies to the migration and the pre-v6 backup restore. Note: the migration is already in a debug build, so the changed mapping only affects devices that have not yet migrated; a device already on v6 keeps what the earlier mapping wrote. Debt: an exercise kept with an unmatched required value exists but is unreadable (the library and history skip it); it is recorded in `legacy_quarantine` only, with no in-app surface yet |
| L1 | Copy-on-edit created the copy before the editor opened; cancelling left an orphan | Low | Fixed: the editor opens on an unsaved draft (route `/train/exercises/:id/copy`); `CopySuppliedExercise` runs on Save only |
| L2 | Bodyweight-only filter not selectable (TRN-011(2)) | Low | Fixed: explicit `equipment-bodyweight-only` choice passing an empty available set, persisted (new settings key), exclusive with an equipment selection |
| L3 | Archived exercises accepted in plans | Low | Fixed: `SavePlan` rejects them with a ValidationError naming the exercise |
| L4 | Type change allowed when the exercise is used in a plan | Low | Fixed: `WorkoutPlanRepository.usesExercise`; `SaveCustomExercise` refuses |
| L5 | One use case catches `Exception` only | Low | Fixed: `SetAvailableEquipment` catches `Object` |
| L6 | No test guards TRN-007(2) | Low | Fixed: `test/architecture/cardio_energy_isolation_test.dart` — `energyKcal`/`energyProvenance` may appear only in `lib/domain/training`, `lib/features/training` and `lib/data` (allowlist, so the dashboard and planning are covered) |
| L7 | TD-23 and TD-25 not updated in D05 | Low | Fixed: TD-23 resolved; TD-25 constraints resolved, logging of skipped rows still open (with TD-32) |

TRN criteria the reviewer found not fully met: TRN-002(2), TRN-011(2); and TRN-020 contradicted by the enforced rule (WP 9 scope, fixed here).

### Re-verification of the fixes (same reviewer, uncommitted tree on 2208b94, code read)
All ten fixes confirmed (M1–M3, L1–L5 resolved; M4 resolved for the agreed scope; L6 partly). Residuals and new findings:

| ID | Item | Severity | Disposition |
|---|---|---|---|
| R1 | `LoadKg.fromStored` is public and snaps silently; nothing stops a future form from calling it | Low | Fixed: architecture test — `LoadKg.fromStored`/`tryFromStored` allowed only in `lib/data` (and its definition) |
| R2 | L6 guard scanned only the nutrition folders | Low | Fixed: allowlist guard (row L6) |
| R3 | M4: an exercise with an unmatched required value is unreadable, recorded only in quarantine | Low | Debt TD-41 |
| N1 | `SavePlan` refuses to re-save a plan whose exercise was archived later (rename, reorder) | Low | Debt TD-42, WP 9 plan builder |
| N2 | v5→v6 mapping does not map a legacy set's own `type` text (no pre-v6 code wrote sets) | Low | Recorded in TD-41 |
| N3 | Equipment selection and bodyweight-only are two settings writes, not one transaction; a failed second write leaves bodyweight-only shown | Low | Accepted: harmless state, user can reselect |

Both guards were shown to fail on a planted probe file under `lib/features/dashboard` (probe removed). The fixer showed each new regression test failing on the pre-fix `lib/` (assertion or compile failure; L6 by probe).

## Tests, CI
- Review-fix commit, local: `dart format` clean, `flutter analyze --fatal-infos` clean, 875 tests pass (`--concurrency=2`), hand-written coverage 8160/9033 = 90.3 % (gate 80 %), `build_runner` leaves generated files unchanged.
- CI on b1ab45a (final implementation commit): CI 41990885185, Android 41990885178, iOS 41990885187, integration (API 34 emulator) 41990885357 — all success, first attempt.
- Earlier stages: see "What was built" (all four workflows green on 6d401e6 and 058d433).

## Acceptance criteria (D06 WP 8) and evidence
| Criterion | Evidence | Result |
|---|---|---|
| A set of each exercise type is stored and read back with correct fields | `record_set_test.dart` group "a set of each type is stored and read back…" (weighted, bodyweight, assisted, timed, distance, cardio, through `RecordSet`); `drift_workout_session_repository_test.dart` "round-trips one set of each variant with all fields"; `drift_training_queries_test.dart` "a set of each type round-trips…" | Met |
| Invalid combinations rejected at use-case level | `record_set_test.dart` group "invalid combinations are rejected and nothing is stored" (type mismatch, reps 0/101, off-step and negative load, zero duration/distance, heart rate, energy label, exertion per TRN-020, rest range, archived exercise); `training_use_cases_test.dart` (plans, splits, custom exercises) | Met |
| Verification: unit tests | 875 tests, coverage 90.3 % | Met |
| Verification: schema migration test | `migration_v6_test.dart` (v5→v6 with a set of every type, CHECK enforcement, no clamping with quarantine, crash re-run, taxonomy mapping); v1–v5 upgrade tests; pre-v6 backup restore test; the emulator integration run opens a real on-device file at v6 through the production open path (fresh install: creation, not upgrade; the upgrade itself is proven by the migration tests only) | Met |

## Deviations
- UI scope: the plan builder, scheduling and session screens are WP 9 (decision 3). TRN-013 (model, validation, reorder) and TRN-014 (split model) are delivered without screens.
- Exertion rule changed to D04 TRN-020 (RIR 0–5 whole numbers). The WP 3 rule (RIR 0–10, half steps) was never an owner decision. No stored data was written through a set-writing use case before WP 8.
- The v6 CHECK constraints are looser than the domain rules (for example RIR 0–10). Tightening them needs schema v7; the domain enforces the stricter rule on every write path.
- M4 mapping change reaches only devices that have not yet run the v6 migration (debug builds only so far).

## Open debt owned by or raised in WP 8
TD-25 (logging of skipped rows, with TD-32), TD-41 (unreadable legacy exercises, quarantine only), TD-42 (plan re-save with a later-archived exercise, WP 9). TD-23 resolved.

## Owner decisions requested (at the first delivery, 2026-11-05)
Disposition: 1 folded into the anatomy decision and OQ-22; 2 answered (OQ-09 decided); 3, 4 and 5 approved 2026-11-05 (D04 §7).
1. Approve `docs/training-taxonomy.md` (7 categories, 19 muscle groups, 21 equipment items) as normative.
2. OQ-09: approve RepForge's own library content (89 exercises, names and classifications only), or name another source.
3. Approve the legacy-data rule: no clamping; invalid values set to NULL or the row kept, with the original in `legacy_quarantine` (TD-41 for visibility).
4. Approve the TRN-020 exertion correction (RIR 0–5 whole numbers, RPE 1–10 in 0.5 steps).
5. Approve UI scope: library only in WP 8; plan builder and sessions in WP 9.

## Owner disposition (2026-11-05)
The owner deferred acceptance and decisions 1–5. WP 8 stays **Delivered — awaiting owner acceptance**; it is not accepted or closed, and silence is not approval. TD-41 and TD-42 stay tracked. The owner authorised WP 9 to proceed on top of the WP 8 implementation, without resolving decisions 1–5 (see WP9.md "Constraints from WP 8").

## Exercise library scope amendment (owner, 2026-11-05)
The owner amended the library scope (D04 §7, LIB-001..010). WP 8 was reviewed against it and does **not** satisfy it (gap analysis: `docs/exercise-library-expansion.md` §2). The amendment was first proposed as WP 16. **Superseded the same day**: the owner incorporated it into WP 8, which is the active work package again (D04 §7, "Library expansion incorporated into WP 8"). Completed work, identifiers, migrations and tests are preserved; nothing accepted is reopened.
On 2026-11-05 the owner decided OQ-09 (WP 8 decision 2): original RepForge-authored content, which the existing seed is. This answers decision 2 only.

## Recommendation (first delivery, 2026-11-05 — superseded by the scope expansion)
Accept WP 8 at b1ab45a, subject to decisions 1–5. All D06 criteria are met with code-level evidence, four workflows are green on the final commit, and the independent re-verification found no open medium or high findings.

Current position: WP 8 is not ready for acceptance; it completes after stages 3–6 against the final criteria in `docs/wp8-delivery-plan.md` §15.

## Stage 3a — domain model (f2f9e9e)
Status: **implemented, not committed, awaiting independent review** (plan section 12, sub-stage 3a). Pure Dart under `app/lib/domain/library/`. No schema, migration, repository, screen or existing model changed; `Exercise`, `MuscleGroup`, `Equipment` and all WP 8, WP 9 and WP 10 code are untouched. Based on HEAD 42fe1a3.

### What was built (23 files, about 8 500 lines; 280 new tests)
| Area | Files | Content |
|---|---|---|
| Identifiers, enums, values | `library_ids.dart`, `library_enums.dart`, `value_equality.dart`, `finding.dart` | Typed ids `ExerciseId`, `AnatomyNodeId`, `MovementPatternId`, `EquipmentItemId`, `ProviderId`, `ReleaseId` (final classes with value equality, so ids of different types never compare equal). Closed enums (source, role, mechanics, laterality, difficulty, relationship kinds, equipment role and class, lifecycle). Content section kinds as a controlled list stored as text. `Finding` and `Severity` |
| Engineering Objects | `catalogue_exercise.dart`, `exercise_relationship.dart`, `catalogue_records.dart` | `CatalogueExercise`, `ExerciseTarget`, `ExerciseEquipment` (per-exercise load or support override with note), `ExerciseNames` (en-GB canonical), `ExerciseProvenance`, `ExerciseRelationship` (normalised: `regressionOf` stored as the inverse `progressionOf`, symmetric pairs in id order, self-reference refused, derived regression view), `ContentSection`, `MediaReference`, `ContentProvider`, `CatalogueRelease`, `UserExerciseState`. `equipmentClassOf` (Smith, cable, machine, kettlebell, band, free weight, other, bodyweight) |
| Reference data | `reference_data.dart`, `reference_parsers.dart`, `reference_validation.dart`, `preserved_ids.dart` | `AnatomyNode`, `MovementPattern`, `EquipmentItem`; `AnatomyTree` (ancestors, descendants, level lift, safe on invalid data), `PatternTree`, `EquipmentCatalogue`. Pure parsers of `anatomy.json`, `movement-patterns.json`, `equipment.json`, `ledger.json`, `coverage.json`. Validators IC-801 to IC-810; the 19 preserved ids and 21 existing equipment ids as constants; `bootstrapNodeIds` (the 31-node derivation) |
| Exercise rules | `exercise_rules.dart`, `relationship_rules.dart`, `exercise_attributes.dart` | `validateExercise` (IC-101, 103, 201 to 212, 301 to 316, ED-501), `requireValidExercise` returning `Result`; relationship graph (IC-401 to IC-410, 413, 414); the seven attributes with vocabulary, boundary texts and numeric classifiers (X1) |
| Names, duplicates, content | `text_normalisation.dart`, `name_rules.dart`, `duplicate_detection.dart`, `content_rules.dart` | `norm`, `squash`, name tokens, bounded Levenshtein; IC-501 to IC-509; the structural signature and score with the approved weights and thresholds, IC-601 to IC-603, IC-411, IC-412 with X2; IC-210 and IC-701 to IC-710 |
| Report and coverage | `integrity_report.dart`, `accepted_gaps.dart`, `coverage_spec.dart`, `coverage_evaluation.dart` | `runIntegrityChecks` returning a structured report (JSON and Markdown forms per `quality-and-duplicates.md` section 3); a registry of all checks; accepted-gaps parser and application; coverage specification model, IC-811, evaluation by maximum matching, gap report rows |
| OQ-19 | `set_attribution.dart` | `attributeSetCounts`: each primary target receives the full recorded set count (and the kg volume of those sets); secondary targets reported separately and excluded from primary totals; `fullBody` kept in separate non-anatomical maps; optional roll-up to a level, once per distinct ancestor per exercise. The notice `attributedSetCountsNotice` states that these are **attributed set counts, not physiological measurements of muscle stimulus** |

### Design choices
1. **Rules are separate from the value types.** `CatalogueExercise` does not refuse invalid data, so user, imported and legacy records can be represented and reported on (ADR-0010 rule 5: never silently discarded). `validateExercise` returns findings; `requireValidExercise` turns error findings into a `ValidationError` with one field error per code.
2. **Severity follows the source.** System content: IC-304 and IC-313 are errors, completeness (IC-205, 207 to 209, 211, 212) applies. User and imported content: IC-304, IC-313 and ED-501 are warnings, completeness is not required, name collisions with user content are warnings and never block. Structural errors (no primary target, unknown node, duplicate node, ancestor with descendant) apply to every source.
3. **Typed ids as classes, models as plain immutable classes.** No `freezed` or code generation in the new domain; value equality through one small `ValueObject` base.
4. **Per-exercise equipment roles** live on the equipment use (`ExerciseEquipment`). IC-315 therefore reduces to "an override needs a note" (an override for an item not in the list, or a role other than load or support, cannot be expressed).
5. **IC-311 reads the primary pattern's family** against the `relatedCategories` of the approved pattern file. **IC-312** (the specification gives only an example) is defined as: `cardio` logging with a primary pattern whose family is not `conditioning` or `power`. Both give the documented results on the seed.
6. **Near-duplicate scoring only compares exercises with the same primary pattern.** This is exact for the approved weights (a pair with different patterns scores at most 0.80, below every threshold, and IC-411 and IC-412 require the same pattern) and keeps the work near linear (2 225 exercises with 25 copies of the seed, full report, 2.2 s).
7. **Coverage counting** follows `coverage-matrix.md` section 2 exactly: active system exercises of category push, pull, legs, core; primary targets only (descendants included; `fullBody` never); first pattern a slot pattern; every discriminator holds (unrecorded attribute or mechanics never matches); deterministic maximum bipartite matching with each slot taking up to its minimum; static stretches by matching one exercise per group. Gap rows cover slot, total, mechanics, laterality, equipment class, variation families, difficulty (group rules and tranche bands), diversity (class cap `max(55 %, 4)`, bodyweight exempt where marked), primaries per exercise, and classification completeness. The "involved as secondary only (info)" column of the baseline table is not computed.
8. **Name normalisation.** The specification says Unicode NFKD. Dart's core has no NFKD and no package may be added without an ADR, so `norm` folds Latin-1 and Latin Extended-A letters through a table and removes combining marks (U+0300 to U+036F). **It is not equal to NFKD** (corrected after review L1): see the probe cases and options below.
9. **The content hash is passed in**, not computed (no `crypto` dependency; the release hash is 3c).

### Deferred items X1 to X3
- **X1 contiguous boundaries (resolved in code).** The approved texts leave gaps (angle 10 to 15 degrees, arm 20 to 90 degrees, knee 10 to 90 degrees). `AttributeVocabulary` carries contiguous boundary texts and `AttributeBoundaries` implements them as classifiers: angle (decline below -10, flat -10 to 10, incline above 10 up to 45, steeper has no value), knee (straight up to 10, bent above 10), arm (beside the body up to 20 degrees from the trunk, then flexed90 or abducted90 up to 135, overhead above 135, behindBody for a rear elbow, supportedInFront on a support). Tests sweep every degree and show exactly one value. **The numeric cut points are the architect's proposal for owner confirmation**; the approved `coverage.json` and `coverage-matrix.md` text is not edited. *Update 2026-11-06: the owner approved the cut points in principle (bench 10 degrees, arm 20 and 135 degrees, knee 10 degrees; 5 degrees head-down is flat). X1 stays open until the owner confirms the exact boundary wording below.* *Closed 2026-11-06: see "X1 closed" below.*
- **X2 IC-412 token gate (resolved in code).** `DuplicateOptions.tokenGate` (`TokenGateRule`; default at delivery `whenAnyAttributeDiffers`, the literal reading) skips the name-token gate when a recorded attribute differs. With it off the documented 16 pairs are reproduced exactly; with the literal rule (skip the gate when any recorded attribute differs, the default at delivery) the worklist is **30 pairs**: the 16 plus 14, of which only 3 differ by attributes alone (chin-up/pull-up, db-curl/hammer-curl, deadlift/sumo deadlift) and 11 also differ in load items. The narrow rule (skip the gate only when attributes differ and load items are equal) gives **19 pairs** (the 16 plus those 3), confirmed by a test. The rule is the named option `DuplicateOptions.tokenGate` (`TokenGateRule`); the owner decides. The assisted dip stays hidden under every reading: no attribute is recorded for it and its token share with the dip is 0.33. The correction to the section 6 claim (attribute difference does not clear IC-412, only IC-601 to IC-603) is implemented and tested. *Superseded 2026-11-06: the owner chose the narrow rule (19 pairs) as the default; see "Stage 3a owner decisions — implementation".*
- **X3 `trunkExtension` "when the spine moves" (no code change).** Rule R5 is a technique decision an automated check cannot read; there is no domain rule to add. The wording gap is in the approved `movement-patterns.json` and `.md` ("machine back extensions" without the condition). Those files are approved and read only here. **Proposed wording for the owner:** "machine back extensions in which the spine itself moves". *Approved 2026-11-06 and applied to the reference files.*

### Evidence
Release 2 = approved reference data plus the 89 seed exercises with the approved classifications (`mapping-existing.json`, aliases cleaned), integrity report with the ledger and coverage specification supplied:

| Check | Documented (`quality-and-duplicates.md` 6) | Result |
|---|---|---|
| Errors | 0 | **0** |
| IC-210 (instructions not written yet) | 89 warnings | 89 warnings |
| IC-207 (cardio and mobility mechanics empty) | 16 infos | 16 infos |
| IC-311 (kettlebell swing, thruster) | 2 warnings | 2 warnings |
| IC-508 (hip abduction and adduction; push-up and pull-up) | 2 warnings | 2 warnings |
| IC-304 | 0 | 0 |
| IC-601 / IC-602 / IC-603 | 0 / 4 / 7 | **0 / 4 / 7**, same pairs and scores to three decimals |
| IC-411 | 0 | 0 |
| IC-412 | 16 | **16 with X2 off** (same pairs and scores); **30 literal X2 (default at delivery); 19 narrow X2**. *Superseded 2026-11-06: the default is the narrow rule, IC-412 19.* |
| IC-809 | not in the table | 1 warning: two anatomy nodes are labelled "Chest" (`regionChest` and `chest`). *Superseded 2026-11-06: 0 after the relabel to "Chest region".* |
| IC-312, IC-506, IC-507, IC-509, ED-501 | not listed | 0 |
| Totals | 93 warnings, 16 infos (IC-200 to IC-500) | 93 warnings in IC-210, IC-311, IC-508 plus 4 (IC-602), 30 (IC-412) and 1 (IC-809) = 128 warnings; 16 + 7 (IC-603) = 23 infos. *Superseded 2026-11-06: 116 warnings (IC-412 19, IC-809 0), 23 infos.* |

Coverage baseline from `mapping-existing.json`: **67 of 325** slot fills and **20 of 70** conditioning, power and mobility entries, as accepted by the owner. All 21 per-group fills equal the table of `coverage-matrix.md` section 11 (for example chest 8, upper back 5, lats 6, shoulders 5, biceps 5, triceps 5, forearms 2, glutes 4, abductors 1, adductors 1, quadriceps 12, hamstrings 4, calves 1, abs 6, obliques 2; rotator cuff, neck, hip flexors, deep hip rotators, shin and lower back 0), the equipment-class baseline of 15 groups equals the table, and each conditioning set lists the documented seed exercises. IC-811 passes on the approved `coverage.json` (every slot minimum equals its counted entries; derived minimums, references and vocabulary resolve).

Reference data: parsers read 126 anatomy nodes (10, 26, 63, 27 by level), 79 patterns (17 families, 62 patterns), 33 equipment items (21 existing, 12 approved), 238 ledger entries, 21 groups with 325 slot minimums and 16 sets with 70 entries. Every validator (IC-801 to IC-807, IC-810) passes on the approved files; IC-809 reports the one duplicate label above. The 19 preserved ids at their planned levels and parents equal `anatomy.json`; the 21 existing equipment ids equal the `Equipment` enum; `bootstrapNodeIds` gives **31 nodes** (19 plus the 12 ancestors).

Tests: 280 new tests in `test/domain/library/` and `test/architecture/library_domain_isolation_test.dart` (parsers and validators against the approved files, malformed-input cases, each exercise rule with pass and fail cases, ADR-0010 severities for system and user content, functional double tags, relationship graph, names, near-duplicates, content, integrity report including previous-release checks, IC-900 references, accepted gaps, tranche status, coverage rules, OQ-19, X1 sweeps). Architecture test: `lib/domain/library` imports only `dart:convert`, `meta`, `domain/core/result.dart` and `domain/training/training.dart` (for `ExerciseType` and `ExerciseCategory`, reused unchanged); no Flutter, drift, plugin or higher-layer import.

Gate (from `app/`): `dart format .` no change; `flutter analyze --fatal-infos` no issues; `flutter test --coverage --concurrency=2` all tests pass; `dart run tool/coverage_gate.dart coverage/lcov.info --min 80` passes. Results: 1 750 tests pass (1 470 before 3a plus the 280 new); coverage of hand-written code 93.0 % (16 505 of 17 747 lines; minimum 80 %); coverage of `lib/domain/library` 97.9 % (2 985 of 3 049 lines). The gate was run on the uncommitted working tree; the four CI workflows have not run (nothing is committed).

### Deviations from the plan and specification (none silent)
1. *Superseded 2026-11-06: the default is now the narrow rule (19 pairs).* **IC-412 default is the literal X2 behaviour** (30 pairs), not the documented 16; the documented figure is reproduced by `TokenGateRule.always` and the narrow reading (19) by `whenAttributesDifferAndLoadsEqual`. X2 was assigned to 3a, so the difference is intended; the owner chooses the rule.
2. **IC-809 raises one warning on the approved data** (the label "Chest" on two nodes). Labels may change without a migration; the owner can accept the warning in the accepted-gaps file or relabel `regionChest`. *Decided 2026-11-06: relabelled "Chest region"; IC-809 now raises no warning.*
3. **Codes outside the IC list:** ED-501 (functional double tag rule, editorial guide 5.7), ED-701 (content stored for an unknown exercise), ED-702 (incomplete media reference: kind, locator, licence and attribution required by plan section 3), ED-901 (stale accepted-gaps entry, specified as an info without a code).
4. **`CatalogueExercise` carries `provenance`** (author, reviewer, source reference), which plan section 3 does not list, because IC-212 checks the author.
5. **X1 numeric cut points and the X3 wording** are proposals awaiting the owner (above). *Update 2026-11-06: cut points approved in principle; X3 wording approved; X1 wording stays open until the owner confirms it.* *Closed 2026-11-06: see "X1 closed" below.*
6. *Superseded 2026-11-06: normalisation is now table-driven NFKD.* **Name normalisation approximates NFKD** (above). **IC-506, IC-507 and IC-509 use lists and heuristics** (blocked words, US spellings, proper nouns, synonym pairs) that the specification says are held with the tool and reviewed by the owner; they are starting lists and give no finding on the seed.
7. **The mapping loader is test support**, not production code: converting `mapping-existing.json` into release 2 exercises belongs to the release format of 3c.

### Open points for 3b and 3c
- **3b:** the 31 bootstrap constants must equal `bootstrapNodeIds` on the approved file (a test compares them). Storing the seven attributes needs the ADR-0008 clarification (one column each or `exercise_attributes (exercise_id, attribute, value)`). IC-901 to IC-907 on the real tables, IC-904 and IC-906 around the reconciler, and the migration report (`quality-and-duplicates.md` section 4) are 3b; the pure checks take id sets and are ready. `legacy` `fullBody` secondaries and duplicate secondaries must be listed by the migration (the domain reports them, it does not decide).
- **3c:** tranche gating (IC-411 becomes an error at tranche acceptance; `quality-and-duplicates.md` section 5 rule 3 blocks `complete` while IC-411, IC-412, IC-601 or IC-602 are uncleared) and the reference-data release and version fields in the release file; release format 2 parser (raw-string forms of IC-202, 203, 206, 308); `sha256` content hash; the `equipmentRoles` override needs a note field in the release file (`mapping-existing.json` has none, the 3a test loader uses the flag text); tranche status metadata; loading `docs/catalogue/accepted-gaps.json`; the CI gate that runs `runIntegrityChecks` over the shipped release and publishes the JSON and Markdown report; IC-110 retirement refinement is implemented as specified.
- **3d:** wire `attributeSetCounts` into WP 9 volume; every per-muscle figure shows `attributedSetCountsNotice`; adapt `Exercise`, `MuscleGroup`, `Equipment` users to the typed ids.
- **Owner:** confirm the X1 cut points, the X3 wording and the handling of the IC-809 warning; confirm the X2 default. *Update 2026-11-06: cut points, X3 wording, IC-809 label and X2 default decided; X1 wording pending.* *Closed 2026-11-06: see "X1 closed" below.*

### Independent review of 3a and resolutions
Review result: no High finding; the release-2 reproduction is exact. Findings M1 to M3 and L1 to L9, fixed in the same uncommitted tree (pure domain; no schema, screen or commit):

| Id | Finding | Resolution |
|---|---|---|
| M1 | IC-402 did not raise for a retired end of a system relationship | Raises for any retired end of a `system` relationship; user relationships stay with IC-905. Test: `variationOf` between retired exercises gives IC-402 (failed before the fix) |
| M2 | Accepted gaps: pair dispositions did not reach IC-411 and IC-412; a warning entry could not name a pair; a pair entry could look used without clearing anything | (a) `duplicate` entries clear IC-601 to IC-603, IC-411 and IC-412 findings of the pair; (b) `warning` entries may carry a `pair` and then clear only that pair (the reviewer's `lib-barbell-curl` example clears one pair of four); (c) an entry counts as used only when it matched and applied, otherwise ED-901 (stale). Tests with the reviewer's examples (`lib-overhead-triceps-extension` / `lib-triceps-pushdown`) failed before the fix |
| M3 | Record and test title called all 14 added IC-412 pairs attribute-only | Corrected above: 3 are attribute-only, 11 also differ in load items. Both readings stated; named option `TokenGateRule`; literal reading is the default; assisted dip disclosed |
| L1 | Name normalisation is not NFKD | Claim corrected; code unchanged; owner decision below |
| L2 | A secondary before a primary on one node gave IC-302 | Gives IC-305 in either order |
| L3 | Two identical aliases on one exercise were not flagged | IC-503 flags them (one finding) |
| L4 | IC-414 was suppressed by an unrelated progression cycle | Evaluated per chain; test with a cycle and a 7-step chain |
| L5 | OQ-19 roll-up can credit one ancestor as primary and secondary | Recorded below; code unchanged |
| L6 | IC-201 counted UTF-16 units; `requireValidExercise` overwrote repeated keys | Counts runes; messages for repeated `code:field` keys are aggregated |
| L7 | Architecture test did not follow transitive imports; "existing model untouched" check was weak | Follows the import closure of `lib/domain/library` (no Flutter, drift or plugin); asserts that no existing file imports `lib/domain/library` |
| L8 | IC-314 used the fixed id; default relationship source differed | IC-314 reads the `nonAnatomical` flag. Both `ExerciseRelationship()` and `.normalised()` default to `user` (least privilege: a relationship is system-owned, and so reconciler-owned, only when the caller says so) |
| L9 | 3c deferral list incomplete | Tranche gating and reference-data release and version fields added to the 3c list |

The failing-before-fix run was recorded: 10 of the new tests failed (M1, M2a, M2b, L2, L3, L4, L6 x2, L8 x2) before the code changes; all 280 pass after. Gate after the fixes: format no change, analyze clean, 1 750 tests pass, coverage 93.0 % (library 97.9 %).

### Owner decisions and notes from the review
1. *Decided 2026-11-06: narrow rule.* **IC-412 token gate (X2):** literal rule (30 pairs, default) or narrow rule (19 pairs). Assisted dip is not found under either (no recorded attribute; token share 0.33).
2. *Decided 2026-11-06: option 2, generated NFKD table.* **L1 name normalisation.** `norm` keeps characters that NFKD would decompose or map. Probe cases and current output: Vietnamese precomposed `đ`, `ạ` (kept, `dạ`; NFKD gives `a` for `ạ`, `đ` has no decomposition); Greek accents (`Άλφα` kept accented); Latin Extended-B (`ǆ`, `Ǆ` give `ǆ`; NFKD gives `dž`); fullwidth (`ＡＢＣ１` kept; NFKD gives `ABC1`); superscripts and fractions (`m²` becomes `m`, `½` becomes empty; NFKD gives `m2` and `1⁄2`); U+02BC (kept as a letter, `aʼb`; it is not deleted as an apostrophe); the ligature `ﬃ` (kept); `Ơ` (becomes `ơ`, NFKD gives `o`). Options: **(1) accept** (exercise names are English with a few Latin-1 letters; the table covers those), or **(2) generate an NFKD table** for Latin, Greek and fullwidth from the Unicode data files, with no new dependency, and keep it as a checked-in constant.
3. *Decided 2026-11-06: option 2, drop the duplicate secondary credit.* **L5 OQ-19 roll-up.** With `rollUpToLevel`, one exercise whose primary and secondary targets share an ancestor credits that ancestor in both the primary and the secondary map (each map once per exercise). Options: **(1) keep both** (current; the maps stay independent and secondary is never part of primary totals), or **(2) drop the secondary credit where the ancestor already has primary credit from the same exercise.**
4. **X1 boundary texts.** Approved text in `coverage.json` against the code text: angle flat "within about 10 degrees of horizontal" against "from 10 degrees head-down to 10 degrees head-up inclusive"; angle incline "about 15 to 45 degrees" against "more than 10 and up to 45 degrees"; angle decline "head below the hips" against "head more than 10 degrees below the hips" (so a bench 5 degrees head-down now counts as flat, where the approved text read as decline); armPosition besideBody "within about 20 degrees of the trunk line" against "up to 20 degrees from the trunk line"; behindBody "more than about 20 degrees" against "more than 20 degrees"; flexed90 and abducted90 "about 90 degrees" against "more than 20 and up to 135 degrees"; overhead "elbow at or above ear height" against "more than 135 degrees from the trunk line, elbow at or above ear height"; kneePosition straight "within about 10 degrees of straight" against "from fully straight to 10 degrees of flexion inclusive"; bent "bent to about 90 degrees" against "bent more than 10 degrees (typically about 90)". The cut points (10, 20, 135) are the architect's proposal. *Update 2026-11-06: cut points approved in principle; the exact wording is recorded below and awaits confirmation.* *Closed 2026-11-06: see "X1 closed" below.*
5. *Decided 2026-11-06: error for system content, never downgraded.* **ED-501** (two primaries of a functional pair) is an error for system content and a warning for user content; confirm.
6. Carried over: X3 wording, the IC-809 "Chest" label, and the 3b and 3c items above. *Decided 2026-11-06: X3 wording approved; IC-809 label "Chest region".*

### Stage 3a re-check (2026-11-06)
Independent re-check of the fixes: M1, M2, M3, L2–L4, L6–L8 resolved; reproduction unchanged under all three token-gate rules (`always` 16, `whenAttributesDifferAndLoadsEqual` 19, `whenAnyAttributeDiffers` 30 IC-412 pairs; 0 errors; IC-601/602/603 0/4/7; coverage 67/325 and 20/70). New Low findings: **N1** relationship `source` defaulted to `user`, so a forgotten argument would weaken system checks (IC-402, IC-105/106) — **resolved: `source` is now a required parameter** on both constructors; test call sites state it explicitly; **N2** stale option name in this record — corrected; **N3** IC-414 reported alongside IC-407 on a long cycle — harmless, recorded.

### Stage 3a commit and CI
Implementation commit **f2f9e9e**. CI on f2f9e9e, all success, first attempt: CI 42195609690; Android 42195609701 (debug and release with R8); iOS 42195609780; integration (API 34 emulator) 42195609716. Local: 1750 tests, analyzer clean, 93.0 %. Stage 3a is returned to the owner for review; it is not accepted by this record. Owner decisions pending: X2 token-gate rule, X1 cut points, X3 wording, IC-809 label, ED-501 severity, name normalisation (L1), OQ-19 roll-up (L5), reference-data release/version fields (L9, planned for 3c). *Decided 2026-11-06, except X1 wording and the release/version fields (3c): see "Stage 3a owner decisions — implementation".*

### Stage 3a owner decisions — implementation
This section implements the D04 section 7 entry of 2026-11-06 (stage 3a decisions). Nothing is committed; the owner reviews first. The changes touch only the pure domain, its tests and the catalogue documents. No schema, migration or `lib/data` file changes.

| Item | Decision | Files changed | Tests added or changed |
|---|---|---|---|
| X2 | Default `TokenGateRule.whenAttributesDifferAndLoadsEqual` (19 pairs); the other rules stay as named options | `lib/domain/library/duplicate_detection.dart` | `duplicate_detection_test.dart`: default rule, exact 19 pairs with scores, positive pairs, negative pairs, a unit case with equal loads. `integrity_report_test.dart`: IC-412 19, 116 warnings, Markdown totals, M2a pair |
| IC-809 | `regionChest` labelled "Chest region"; id, level and parent unchanged | `reference/anatomy.json`, `anatomy.md` (status note, heading, label, node-count row); amendment field in the JSON | `approved_reference_data_test.dart`: no label finding, label and hierarchy, amendment field tolerated by the parsers |
| X3 | "Machine back extensions in which the spine itself moves." in the `trunkExtension` includes text | `reference/movement-patterns.json`, `movement-patterns.md`, amendment field in the JSON | `approved_reference_data_test.dart`: wording present |
| ED-501 | Error for system content in every pair, never downgraded. The code already did this | none | `exercise_rules_test.dart`: every pair is an error, the user case is a warning, `requireValidExercise` refuses. `integrity_report_test.dart`: an accepted-gaps entry cannot silence it |
| Name normalisation | Full NFKD from a generated table, all non-spacing marks removed, case folded | `text_normalisation.dart`, `text_normalisation_table.g.dart` (generated), `tool/gen_text_normalisation_table.py` | New `text_normalisation_test.dart` |
| OQ-19 | Same-parent secondary credit suppressed at the roll-up level only | `set_attribution.dart` | `set_attribution_test.dart`: same parent, other exercise, different parents, leaf level, levels 1 and 2, shallower primary, two secondaries |
| X1 | Thresholds and classifiers unchanged; vocabulary texts now match the classifiers | `exercise_attributes.dart` (texts only) | `attribute_boundaries_test.dart`: interval-table sweep, text checks |
| Specification notes | IC-412 narrow rule noted | `quality-and-duplicates.md` (three notes) | none |

#### X2: the 19 pairs
The pairs come from release 2 (the approved reference data plus the 89 seed exercises) at the new default. They are the 16 pairs of the pre-X2 worklist plus three attribute-only pairs, marked with an asterisk.

| Pair | Score |
|---|---|
| lib-assisted-pull-up / lib-band-assisted-pull-up | 0.740 |
| lib-assisted-pull-up / lib-pull-up | 0.675 |
| lib-band-assisted-pull-up / lib-pull-up | 0.675 |
| lib-barbell-curl / lib-cable-curl | 0.725 |
| lib-barbell-curl / lib-db-curl | 0.725 |
| lib-bench-press / lib-db-bench-press | 0.725 |
| lib-bench-press / lib-incline-bench-press | 0.963 |
| lib-cable-crunch / lib-crunch | 0.675 |
| lib-cable-curl / lib-db-curl | 0.725 |
| lib-cable-fly / lib-db-fly | 0.725 |
| lib-chin-up / lib-pull-up * | 0.900 |
| lib-db-bench-press / lib-incline-bench-press | 0.710 |
| lib-db-bench-press / lib-incline-db-press | 0.925 |
| lib-db-curl / lib-hammer-curl * | 0.888 |
| lib-deadlift / lib-sumo-deadlift * | 0.900 |
| lib-dumbbell-rdl / lib-romanian-deadlift | 0.750 |
| lib-incline-bench-press / lib-incline-db-press | 0.710 |
| lib-leg-curl / lib-lying-leg-curl | 0.925 |
| lib-plank / lib-weighted-plank | 0.725 |

The literal rule flags 11 more pairs. Each differs in attributes and in load items, so the narrow rule keeps the token gate and skips them.
- barbell-curl / hammer-curl, barbell-curl / preacher-curl
- bench-press / incline-db-press, cable-curl / hammer-curl
- cable-curl / preacher-curl, db-curl / preacher-curl
- glute-bridge / hip-thrust, hammer-curl / preacher-curl
- incline-bench-press / machine-chest-press, incline-db-press / machine-chest-press
- overhead-triceps-extension / triceps-pushdown

The assisted dip stays hidden under every rule. Release 2 now reports IC-412 19, IC-809 0, 116 warnings (93 + IC-602 4 + IC-412 19) and 23 infos.

#### Name normalisation (full NFKD)
- The key is NFKD, then mark removal, then case folding. The existing punctuation, separator and whitespace rules follow. Display names never change.
- **Mark removal covers combining diacritics only:** Mn marks inside U+0300–036F, U+1AB0–1AFF, U+1DC0–1DFF, U+20D0–20FF and U+FE20–FE2F. Marks of other scripts stay (Devanagari virama, Thai, Hebrew, Arabic points), so they never merge words.
- **Case folding uses a generated map:** the code applies Python's single-code-point `str.lower()` per code point, not the platform `toLowerCase`. It adds `ß` to `ss` and `ς` to `σ`.
- The generated table lists every code point of every plane whose NFKD form differs from itself. It has **5,857 entries** from Unicode 15.1.0 in a 164,209-byte file. It also holds 8 diacritic mark ranges (binary search) and 1,432 lower-case entries.
- Hangul syllables (U+AC00 to U+D7A3) use the standard algorithm in `text_normalisation.dart`. They are not in the table.
- The generator records the Unicode and Python versions in the file header. Regenerate with `python3 -I tool/gen_text_normalisation_table.py` from `app/`, then `dart format`. No package was added.
- Fraction slash U+2044 and division slash U+2215 now separate words, so "½ squat" and "1/2 squat" share one key.
- The apostrophe set now includes U+02BC, U+1FFD and U+1FEF, so "Farmerʼs" equals "Farmer's".
- Spacing accents such as `¨` decompose to a space and break words. The acute accent `´` is deleted like an apostrophe.
- The analyzer and the coverage gate already exclude `*.g.dart`.
- *Decided 2026-11-06 (owner):* the comparison key folds five letters with no NFKD decomposition.
  - `ø` to `o`, `đ` to `d`, `ł` to `l`, `æ` to `ae`, `œ` to `oe`. Upper-case forms fold the same way.
  - "Søren" and "Soren" share one key. "Søren" and "Soeren" do not.
  - Other such letters (`ħ`, `ŧ`, `ı`, `ð`, `þ`) stay distinct. The fold is not a general transliteration.
  - Display names and stored content never change.
  - Tests cover matching, non-matching and case variants, and IC-501 duplicate keys.

#### Open questions for the owner
1. *Decided 2026-11-06:* fold `ø`, `đ`, `ł`, `æ`, `œ` (see above).
2. Confirm the X1 wording in the table below. *2026-11-06: The owner approved the two precedence rules. The owner removed elbow and floor as mandatory conditions; "typically" fits where they are descriptive. The exact thresholds and inclusive or exclusive wording must be visible in this record. The precedence rules must be unambiguous at boundary cases. X1 stays open until the owner signs off the table and boundary cases below.* *Closed 2026-11-06: see "X1 closed" below.*

### Stage 3a owner decisions — implementation (X1 boundary texts, signed off 2026-11-06)
The owner approved the cut points in principle on 2026-11-06. They are: bench 10 degrees, arm 20 and 135 degrees, knee 10 degrees. A bench tilted 5 degrees head-down is flat. The thresholds and classifiers stay unchanged. **X1 CLOSED 2026-11-06: the owner signed off this table and the boundary cases below.**

The Text column quotes `AttributeVocabulary` verbatim. The Interval column describes `AttributeBoundaries`. A test checks each range in 0.5 degree steps and at every cut point, plus and minus 0.000001. It uses an interval table written separately from the code. Each value lies in exactly one band.

| Attribute | Value | Interval (degrees) | Text in code |
|---|---|---|---|
| angle (head above hips is positive) | decline | −90 ≤ angle < −10 | Bench lowered with the head more than 10 and up to 90 degrees below the hips. |
| | flat | −10 ≤ angle ≤ +10 | Bench or body from 10 degrees head-down to 10 degrees head-up inclusive. |
| | incline | +10 < angle ≤ +45 | Bench raised more than 10 and up to 45 degrees (steeper is a vertical push, rule R2). |
| | no value | angle < −90 or angle > +45 | Not a text in the code. Derived: no value is assigned. |
| kneePosition (flexion, 0 is straight) | straight | 0 ≤ flexion ≤ 10 | Knee from fully straight (0 degrees) to 10 degrees of flexion inclusive. |
| | bent | 10 < flexion ≤ 180 | Knee bent more than 10 and up to 180 degrees of flexion (typically about 90). |
| | no value | flexion < 0 or flexion > 180 | Not a text in the code. Derived: no value is assigned. |
| armPosition (angle between upper arm and trunk line) | besideBody | 0 ≤ angle ≤ 20, any direction | Upper arm hangs by the side, from 0 to 20 degrees inclusive from the trunk line, in any direction. |
| | flexed90 | 20 < angle ≤ 135, forward | Upper arm raised forward more than 20 and up to 135 degrees from the trunk line (typically about 90 degrees). |
| | abducted90 | 20 < angle ≤ 135, lateral | Upper arm raised to the side more than 20 and up to 135 degrees from the trunk line (typically 90/90 with the elbow bent). |
| | overhead | 135 < angle ≤ 180, forward or lateral | Upper arm raised forward or to the side more than 135 and up to 180 degrees from the trunk line (typically with the elbow at or above ear height). Not used for an arm behind the trunk. |
| | behindBody | 20 < angle ≤ 180, behind | Elbow behind the trunk line by more than 20 and up to 180 degrees (for example an incline curl). Takes precedence over overhead. |
| | supportedInFront | 0 ≤ angle ≤ 180, arm on a support | Upper arm rests on a pad, bench or thigh in front of the trunk, at any angle from 0 to 180 degrees from the trunk line. Takes precedence over every other arm value. |
| | no value | angle < 0 or angle > 180 | Not a text in the code. Derived: no value is assigned. |

**Result of the check.**
- Angle and knee: no gap and no overlap.
- Arm position: the numeric bands leave no gap. Direction and support are inputs, so two texts could overlap. The precedence sentences now settle both cases. A supported arm wins at every angle. A behind arm wins over overhead.
- With the precedence sentences, each text matches its classifier, and each input maps to exactly one value.
- Outside the stated ranges, no value is assigned. Those rows are derived, not texts.

**Boundary cases.** The code checks arm position in this order:
1. Outside 0 to 180: no value.
2. On a support: supportedInFront.
3. 20 or less: besideBody.
4. Behind: behindBody.
5. More than 135: overhead.
6. Otherwise forward gives flexed90, and lateral gives abducted90.

| Input | Value |
|---|---|
| Bench −90 or −10.000001 | decline |
| Bench −90.000001 | no value |
| Bench −10, −5, 0 or +10 | flat |
| Bench +10.000001 or +45 | incline |
| Bench +45.000001 | no value |
| Knee 0 or 10 | straight |
| Knee 10.000001 or 180 | bent |
| Knee −0.000001 or 180.000001 | no value |
| Arm on a support, any angle 0 to 180, any direction | supportedInFront |
| Arm on a support, −0.000001 or 180.000001 | no value |
| Arm unsupported, −0.000001 or 180.000001 | no value |
| Arm 0 or 20, unsupported, any direction (behind included) | besideBody |
| Arm 20.000001 or 135, forward | flexed90 |
| Arm 20.000001 or 135, lateral | abducted90 |
| Arm 20.000001, 135, 135.000001 or 180, behind | behindBody |
| Arm 135.000001 or 180, forward or lateral | overhead |

**Approved reference texts aligned (2026-11-06).** After the sign-off, `coverage.json` and `coverage-matrix.md` carry the code texts above. The superseded "about" wording and elbow conditions are gone. A test checks that every attribute text in `coverage.json` equals `AttributeVocabulary`. Thresholds and classifiers stay unchanged.

**Review.** An independent review (opus) ran three rounds: M1–M4 and L1–L12, then M1, M2 and L1–L4, then L1 and L2. All findings are fixed. M1 limited mark removal to the combining-diacritic blocks. M2 added a generated lower-case map. The final verdict was "ready to commit".

**Local gate** (from `app/`): `dart format` 0 changed; `flutter analyze --fatal-infos` no issues; `flutter test --coverage` 1,813 passed, 2 skipped; coverage gate 93.1 % (minimum 80 %). The run also held the uncommitted trial files, which the default run skips.

## Stage 3b — table-rebuild comparison trial (results for owner decision)

Status: trial only. The real v8 migration is not implemented. `schemaVersion` stays 7 and no production code changed. The owner asked for these results before choosing the final approach. **Host results do not prove device timing.** Treat durations as relative, not absolute. The trial files are frozen evidence for this decision. They are valid only while `schemaVersion` is 7.

### Method and environment
- Host: Linux 6.18.44 (virtual machine), 4 vCPU, 16 GB RAM, Dart 3.13.7, Flutter 3.47.9, drift 2.35.3.
- SQLite: `select sqlite_version()` returns **3.54.1**. Journal mode `delete`. The database is a file on disk.
- Device binary (reviewer-verified): the app bundles SQLite 3.54.1 on Android and iOS through the `sqlite3` 3.8.0 build hook. The asset hashes match `asset_hashes.dart` and the source id equals the host's. The build sets no `SQLITE_DEFAULT_FOREIGN_KEYS`. The system SQLite is not used.
- Connection: the trial opens `NativeDatabase(File)`. `drift_flutter` uses the same engine in its background connection.
- Harness: `app/test/migration_trial/`, tag `trial`, skipped by default through `app/dart_test.yaml`. CI skips it, so the coverage gate is unaffected.
- Run: `flutter test --concurrency=1 --run-skipped --tags trial test/migration_trial/`. `--tags trial` alone cannot work, because a tag-level skip (and `exclude_tags`) also blocks the selected tests.
- Option A uses drift's `Migrator.alterTable(TableMigration)` into a hand-written v8 `exercises` table. Option B3 uses `ALTER TABLE ADD COLUMN`, `UPDATE`, then `DROP COLUMN`. Both run through the real drift `onUpgrade` path from a v7 file.
- Both options run the same steps around the change: a bootstrap `anatomy_nodes` table, an `exercise_targets` backfill with a cascading foreign key, quarantine of unmapped values, and the `source`, `provider_id` and `revision` backfill. All of it runs in one transaction with the foreign-key check before commit (safeguard A).
- v8 shape assumptions: new columns follow the B3 add order. `anatomy_nodes` holds only `id` (19 muscle ids stand in for the 31 nodes). The `source` default `user` and `revision >= 1` are assumed. The value lists for `mechanics`, `laterality` and `difficulty` follow ADR-0008. None of this is final.
- The first timing table below comes from the verification runs (5 runs each, fixed order). The interleaved table adds a warm-up round and rotates the order.

### Fixture (deterministic, seed 20261106, 23.6 MB)
The figures below are measured by the harness, not assumed.
- Rows: 5,000 exercises (89 supplied), 100,000 sets, 4,535 sessions, 25,052 session exercises, 40 plans, 400 plan exercises, 300 scheduled workouts, 5 splits (35 days), 300 measurements, 200 foods, 400 servings, 10 goals, 12 settings, 25 quarantine rows. Recipe, food-log, saved-meal, meal-plan and prep tables are empty.
- The fixture schema equals `AppDatabase` `createAll` (41 `sqlite_master` entities, compared after whitespace normalisation, no difference).
- Values: load 0 to 1000, reps 1 to 100, heart rate up to 250, rest 60 to 3,600 (no rest of 0). 501 session-exercise notes have 4,000 characters. Exercise names reach 2,010 characters. Text includes quotes and non-ASCII characters. Some rows are soft-deleted.
- Nulls: 41 nullable columns hold nulls. Two nullable columns never do: `foods.fat_g` and `session_sets.session_exercise_id` (v7 gives every set an entry).
- Loose references: 78 sets in 18 entries reference exercises that do not exist.
- Muscles: unmapped primaries (`rotator cuff`, `Neck`, empty) and one unmapped secondary text (`traps`). 752 secondaries equal the primary. 557 are `fullBody`. 31 exercises list a muscle twice in one secondary list.
- Exertion: RPE 1 to 10 in halves, RIR 0 to 5, and 2,088 sets (2.1 %) with legacy values that break the TRN-020 rule (RPE 0, 0.5, 7.3, 9.75; RIR 2.5, 6, 7.5; scale `borg`; value without scale; scale without value).

### Results: `exercises` change (the §17.1 comparison)
Verification runs, 5 each, fixed order, no warm-up.

| Item | A: `TableMigration` rebuild | B3: `ADD`/`DROP COLUMN` |
|---|---|---|
| Duration median / min / max (ms) | **113** / 108 / 140 | **134** / 125 / 160 |
| Raw runs (ms) | 135, 113, 140, 113, 108 | 125, 160, 134, 132, 148 |
| Keys off at open (app default), median of 3 (ms) | 99 | 135 |
| Step split, median (ms): backfill / change / fk check / commit | 30 / 13 / 40 / 28 | 21 / 52 / 37 / 25 |
| Value equality (row hashes) | Equal: retained columns of 5,000 rows and all other tables, 100,000 sets included | Equal, same checks |
| `exercise_targets` from the old muscle columns | 11,908 rows equal the independent expectation | 11,908, equal |
| `source`, provider, revision from `supplied` | 0 wrong of 5,000 | 0 wrong |
| New `legacy_quarantine` rows (350) | each row's id, reason and original equal the independent expectation | same |
| Exercises left with no primary target | 303 (see owner decision 4) | 303 |
| `PRAGMA foreign_key_check` | empty | empty |
| `PRAGMA integrity_check` | ok | ok |
| Foreign keys after open | on | on |
| Constraint enforcement | 12 of 12 violating statements rejected | 12 of 12 |
| Cascade delete reaches `exercise_targets` | yes | yes |
| Column shape equals a fresh v8 table | yes | yes |
| Stored `CREATE TABLE` text equals a fresh v8 table | **yes** | **no** |

Interleaved timing: one warm-up round, then 7 rounds with the order rotated each round. Medians in ms, with min and max.

| Configuration | Median | Min / max | Raw runs |
|---|---|---|---|
| A: exercises rebuild | **105** | 99 / 112 | 103, 105, 110, 112, 99, 101, 105 |
| B3: exercises ALTER ADD/DROP COLUMN | **138** | 126 / 173 | 148, 130, 126, 138, 173, 135, 162 |
| T-A: session_sets rebuild | **526** | 482 / 559 | 526, 517, 536, 532, 559, 486, 482 |
| T-B: session_sets triggers | **184** | 167 / 211 | 184, 192, 181, 211, 167, 200, 183 |
| T-C: session_sets ADD CONSTRAINT | **215** | 182 / 231 | 231, 182, 194, 224, 200, 215, 217 |

How to read the timing. A and B3 differ by about 30 ms. That is small and not decisive. The fixed-order runs overlap (A 108 to 140, B3 125 to 160). Earlier sessions gave A 107 to 131 and B3 138 to 150. The reviewer's run gave A 123 and B3 138. The page cache is warm on every run. The journal differs: about 38 KB for A against about 1 MB for B3 in the crash test. The host is shared with other work. The preference for A therefore rests on non-timing evidence (see the recommendation). T-A costs about 0.3 s more than T-B and T-C.

### Crash recovery and version write
Crash rows ran on the combined migrations (A + T-A, B3 + T-B, B3 + T-C). All three behaved the same.

| Scenario | Result |
|---|---|
| Throw inside the transaction after the change | Fully v7, all 23 tables equal. Re-run gives v8, values equal. |
| Throw inside the TRN-020 step (values cleared, constraint not yet added) | Fully v7. Re-run gives v8. |
| Crash after commit, before drift writes `user_version` | v8 shape at version 7. Guarded re-run changes nothing, no duplicates, version 8. |
| Hot journal copied mid-transaction (16-page cache) | The snapshot differs from the fixture before recovery. SQLite recovers it to fully v7. Re-run gives v8. |
| `PRAGMA user_version = 8` as the last statement in the transaction, crash right after it | Version rolls back to 7 with the data. Fully v7. |
| Same, crash after commit | Version 8 and v8 shape together. Re-open runs no migration. Values equal. |
| Injected foreign-key violation (A + T-A, B3 + T-B) | `foreign_key_check` finds it, the migration throws, everything rolls back to fully v7. Re-run without it gives v8. |

The hot-journal test models a process kill with a file copy. It is not a real kill.

### Results: TRN-020 on `session_sets` (plan §6 step 6, safeguard C)
Offending values are copied to `legacy_quarantine` (2,088 rows, each equal to the independent expectation) and the exertion pair is cleared first.

| Option | Median (ms, verification runs) | Violations rejected | Valid values accepted | Equality |
|---|---|---|---|---|
| T-A: rebuild `session_sets` with table CHECK | **503** | 9 of 9 | 6 of 6 | equal to the expected cleared rows |
| T-B: validation triggers | **194** | 9 of 9 | 6 of 6 | equal |
| T-C: `ALTER TABLE ADD CONSTRAINT CHECK` | **206** | 9 of 9 | 6 of 6 | equal |
| No TRN-020 change (v7 CHECK 0 to 10 only) | n/a | 2 of 9 | 6 of 6 | n/a |

All variants: `integrity_check` ok, `foreign_key_check` empty, version 8. T-A leaves the file larger (34.8 MB against 23.9 MB); `VACUUM` was not tested. Whole migrations, medians in ms: A + T-A **544**; B3 + T-B **316**; B3 + T-C **289**.

### Safeguard A: what drift's `onUpgrade` does
These findings are now regression guards in the normal test run: `test/data/drift_upgrade_behaviour_test.dart` (untagged, about 1 s). Reviewer-verified for drift 2.35.3: migrations are not wrapped in a transaction, and `user_version` is written after `beforeOpen`. `alterTable` toggles the pragma and uses `legacy_alter_table`. `user_version` is transactional.
1. `onUpgrade` runs **outside any transaction**.
2. On the app's default connection, `PRAGMA foreign_keys` is **off** at the start of `onUpgrade`. The app turns it on in `beforeOpen`, after `onUpgrade`.
3. `PRAGMA foreign_keys = OFF` **inside a transaction has no effect**. Outside a transaction it works.
4. To set it before `onUpgrade`: the connection `setup` callback (`NativeDatabase(setup:)`, or `DriftNativeOptions.setup` in `drift_flutter`). Inside `onUpgrade`: `exclusively()`, with the pragma set before the transaction opens. `beforeOpen` is too late.
5. A rebuild inside a transaction with keys on **deleted both `exercise_targets` rows** through the cascade. With keys off first, both survived.
6. A failure rolls back only the work inside `transaction()`. Statements run directly in `onUpgrade` stay applied while `user_version` stays 7.
7. drift writes `user_version` after `onUpgrade` and `beforeOpen`. A failure in between leaves the new shape at the old version. Every step needs a guard.
8. `alterTable` does not run `foreign_key_check`. The trial runs it before commit and verifies keys are on afterwards.

### Foreign-key check: orphan policy and lockout risk
A whole-database `foreign_key_check` aborts the migration on any existing orphan, even in an untouched table. The test planted one orphan session exercise.
- Whole-database check: the migration failed and the database stayed at v7. Every launch would fail again. The user cannot open the app. This is a lockout.
- Check scoped to the rebuilt and new tables (`PRAGMA foreign_key_check(<table>)`): the migration succeeded at version 8. The orphan stayed in the database. The scope still covers `session_sets`, so an orphan set with a missing session would still block the migration. Scoping reduces the lockout risk; it does not remove it.

Owner decision 3 covers the policy.

### B3 limitations (what `ALTER TABLE` cannot express)
Measured on SQLite 3.54.1.
- A column used by an index, by a CHECK on another column, or by the primary key cannot be dropped. The v7 `exercises` table has none, so the three drops succeed today. A future index on the muscle columns would block them. A column's own CHECK (`supplied`) does not block it.
- A trigger body that names the column blocks the drop. A trigger whose `UPDATE OF` list names the column does not: the drop succeeds and leaves a stale trigger.
- `ADD COLUMN ... NOT NULL` needs a constant default. A new column's CHECK is tested against existing rows.
- The unnamed v7 CHECKs cannot be dropped by name. After B3 with T-C, `session_sets` carries the old 0 to 10 CHECK and the new rule. A fresh v8 install need not.
- B3 cannot change a retained column's type or default, and cannot reorder columns. The plan changes none of these for `exercises`.
- B3 leaves a stored table definition that differs from a fresh v8 table (measured; Option A is equal). Whether drift's schema verifier accepts the difference was not tested.
- SQLite 3.54.1 accepts `ADD CONSTRAINT CHECK` and `ALTER COLUMN SET NOT NULL`, so T-C needs no rebuild. The reviewer verified that 3.45.1 rejects `ADD CONSTRAINT CHECK` and that 3.53.1 and 3.54.1 accept it. The exact minimum version is unverified. The app bundles 3.54.1. If T-C is chosen, add a runtime `sqlite_version()` guard.
- Both add-constraint forms fail while a row violates them. The migration clears the offending values first.
- Validation triggers (T-B) are outside drift's schema model. They add work to every set write.

### Versions v1 to v6 are not tested
The trial starts only from v7. **Paths from v1 to v6 to v8 are not tested.** The hazard is real. The v5 to v6 step rebuilds `exercises` and `session_sets` with `alterTable` into the current table classes, then runs `UPDATE exercises SET ... primary_muscle ...` (`_normaliseExercisesV6`).
- With v8 classes, that step would drop the muscle columns before the v8 backfill, and the UPDATE would fail.
- It would copy `session_sets` into the TRN-020 CHECK shape before the offending values are cleared. A value such as RPE 7.3 would then fail the copy.

Required for the implementation: versioned snapshot classes (drift step-by-step migrations with the generated `schema_vN`) and fixtures from v2 to v6, each migrated to v8 with the equality harness (§17.2). This is documented only; the trial does not demonstrate it.

### Backup compatibility (format 2, current `DriftBackupRepository`)
The test exports a v7 backup with the production repository from the fixture. It applies each migration, then replays the repository's restore algorithm on the migrated file: delete every table, then insert each row with the columns that still exist. It does not call the production `importJson`. Format 1 backups are untested.

| Migrated shape | Restore outcome |
|---|---|
| A (exercises only) | Succeeds. `exercise_targets` ends with 0 rows, `source = 'system'` on 0 of 89 supplied exercises, `anatomy_nodes` falls from 19 to 0. |
| B3 (exercises only) | Identical to A. |
| A + T-A | Fails and rolls back: the CHECK rejects the 2,088 legacy exertion rows. The database is unchanged. |
| B3 + T-B | Fails and rolls back: the trigger rejects them. |
| B3 + T-C | Fails and rolls back: the constraint rejects them. |

Production deletes **all** current tables (`drift_backup_repository.dart:93`). In v8 that would wipe the reference and catalogue tables. The old muscle and `supplied` columns are dropped silently.

**Backup v3 must:**
- Export `exercise_targets`, the new `exercises` columns, the migration report, `catalogue_releases` and user state.
- On a format 1 or 2 restore, run the migration backfill: targets, and `source`, `provider_id` and `revision`. Quarantine and report unmapped muscles. Quarantine, clear and report TRN-020 exertion values.
- Not wipe the reference and catalogue tables, or reload release 2 afterwards.
- Run `foreign_key_check` before commit.

### Neutral recommendation (owner decides)
- **`exercises`:** the evidence favours A, on non-timing grounds. Both options pass every equality, integrity, constraint and crash check. A uses drift's own tooling. It leaves a stored definition equal to a fresh install. B3 would be blocked by a future index on the dropped columns. The timing difference is small and not decisive.
- **TRN-020:** all three variants enforce the rule. T-A shares one mechanism with A and matches a fresh install. It costs about 0.3 s more. T-C is smaller but needs a SQLite version guard and keeps the old CHECK. T-B is not recommended: triggers sit outside the schema model.
- **Version write:** write `PRAGMA user_version = 8` as the last statement inside the transaction, and keep the guards. The tests show it rolls back with the data and removes the commit-to-version window.
- **Safeguard A:** disable keys through `setup` or before the transaction. Run in one transaction. Run `foreign_key_check` before commit. Then restore and verify keys.
- **Device timing:** measure the chosen option on a mid-range Android phone and an iPhone before acceptance.

### Owner decisions needed
*Decided 2026-11-06: see "Stage 3b owner decisions" below. Items 5 and 10 are partly open: the owner set the minimum report structure but not the labels. Implementation settles the item 10 technical details, subject to review.*
1. **`exercises` change:** option A or B3 (recommendation: A).
2. **TRN-020 mechanism:** T-A rebuild, T-C `ADD CONSTRAINT` with a version guard, or T-B triggers (recommendation: T-A).
3. **Foreign-key check scope:** check the whole database, check only rebuilt and new tables, or quarantine and report existing orphans. A whole-database check can lock a user out. A scoped check reduces that risk but does not remove it.
4. **Unmapped primary muscles:** 303 fixture exercises (6 %) with unmapped primaries end with zero primary targets. That conflicts with amended TRN-010 (at least one primary). Decide the handling: a placeholder primary (this conflicts with plan §6 step 5, "nothing is invented"), a report-and-block rule, or an exception to TRN-010 for legacy rows.
5. **Migration report categories:** confirm the listed categories, including secondaries equal to the primary (752) and secondaries repeated within one list (31).
6. **Version write inside the transaction:** confirm the recommendation.
7. **Backup v3 requirements:** confirm the list above, including that a restore must not wipe reference tables.
8. **Version coverage:** confirm that versioned snapshot classes and v2 to v6 fixtures are required before the v8 migration is accepted.
9. **Device measurement:** confirm it as an acceptance condition.
10. **v8 constraint assumptions:** the trial assumed `source` default `user`, `revision >= 1`, the 31-node bootstrap (19 ids stand in), and that drift's schema verifier may need to accept an ALTER-built table. The owner decides these, or the stage 3b implementation settles them with review.

### Review and local gate
- An independent review (opus) ran twice. Round 1 raised H1, H2, M1–M5 and L1–L9. Round 2 raised six Low items. All are fixed or recorded as owner decisions.
- The round 2 verdict: fit to commit as frozen evidence and return to the owner.
- Local gate (from `app/`): `dart format` 0 changed; `flutter analyze --fatal-infos` no issues; `flutter test --coverage` 1,819 passed, 1 skipped; coverage gate 93.0 % (minimum 80 %).
- The default run skips the tagged trial. The trial run (`--run-skipped --tags trial`, concurrency 1) passed 32 of 32.
- No migration is implemented. `schemaVersion` stays 7. The owner chooses the approach before stage 3b implementation starts.

## Stage 3b owner decisions (2026-11-06)
The owner accepted the comparison trial as evidence for the approach. It is not acceptance of the migration. Passing trial tests show only that the trial behaves as tested. They do not show that a production migration is safe for every historical database and backup format.

1. **`exercises`:** option A, table rebuild, is the canonical path. The owner rejects B3 if it leaves a table definition different from a fresh install.
2. **TRN-020:** rebuild `session_sets`. The table definition enforces the approved RPE and RIR rules.
   - The migration keeps every existing valid value.
   - It reports and quarantines invalid legacy values. It never silently rounds or corrects them.
3. **Foreign-key checks:**
   - The migration checks the affected tables and every relationship the rebuild could change, including exercise and set references.
   - The migration test campaign also runs a full `PRAGMA foreign_key_check` and `PRAGMA integrity_check`.
   - A whole-database check is not the only startup gate where unrelated existing damage could block access unnecessarily.
   - The report shows any broader failure separately and never ignores it silently.
4. **Exercises with no primary target:** block and report.
   - No placeholder target and no blanket legacy exception.
   - The report lists every affected exercise id and its current data.
   - The owner accepts the migration only after an explicit, reviewed disposition for every affected record (303 in the trial fixture).
5. **Migration report, minimum structure:**
   - Categories: migrated successfully; preserved unchanged; quarantined or unresolved; rejected or blocked; warnings requiring review.
   - Each affected record shows its stable id, original value, affected field, reason and disposition.
   - Counts reconcile to the records examined.
   - The owner has not approved detailed labels. This is the minimum structure.
6. **Schema version:** the migration writes version 8 inside its own transaction. Version 8 becomes visible only after all work and required checks succeed. A rollback leaves version 7.
7. **Backup v3:** a complete, self-consistent backup contract.
   - It holds the user data and the reference and catalogue data required to restore the database.
   - It keeps stable ids and relationships, and states its format and schema version.
   - Restore validates the backup before it changes anything. Restore is atomic and never erases reference tables.
   - Restore supports formats 1, 2 and 3. A version 7 backup must never fail part-way.
   - A backup with settings but no user records stays valid. A structurally empty backup stays invalid.
8. **Versions 2 to 6:** frozen historical schemas and representative fixtures are required migration evidence, not optional fixtures.
   - They prove each supported upgrade path, including the known version 5 to 6 incompatibility.
   - Nobody rewrites historical fixtures to match the new implementation.
9. **Device timing:** an acceptance condition.
   - Run the migration on representative Android and iOS devices with the bundled SQLite and realistic data.
   - Record device, OS, database size, elapsed time and outcome.
   - Host timing is comparison evidence only.
10. **Version 8 constraint assumptions:** the implementation team may choose the SQL and migration mechanics, subject to independent review.
    - It may not invent or weaken domain rules, or change accepted TRN-020 semantics.
    - It may not silently transform legacy values.
    - It documents every backup and restore assumption for owner approval.

**Gates.** Stage 3b acceptance needs:
- evidence for upgrades from versions 1 to 6;
- evidence for backup formats 1 to 3;
- recovery after a real process kill;
- restore that keeps the reference tables;
- device timing;
- independent review.

The migration stays unimplemented until the project resolves the remaining evidence and the disposition of all 303 records.

**Review and gate for this record and the letter folds.** An independent review (opus) ran twice. It raised D1–D15, C1–C3, then R1–R9; all are fixed. Local gate: `dart format` 0 changed; analyzer no issues; 1,819 tests passed, 1 skipped; coverage 93.0 %.

### Stage 3b implementation authorisation and no-primary disposition (owner, 2026-11-06)
- The owner authorised implementation and testing of the v8 migration on the branch. Schema version 8 appears only in isolated tests and fixtures.
- Production stays at schema version 7 until the owner accepts stage 3b. The migration does not ship active.
- Each exercise with no primary target is blocked individually, never the whole migration (decision 4 refined). D04 lists the conditions.
- Stage 3b acceptance verifies that blocked exercises cannot enter new workouts. Their history stays readable and consistent.

### X1 closed (owner, 2026-11-06)
- The owner signed off the X1 table and boundary cases above.
- Implementation evidence: the intervals are exclusive and exhaustive within the valid ranges. Classification is deterministic.
- Bench −10 and +10 are flat; incline starts above +10. A bench 5 degrees head-down is flat.
- Knee 10 is straight; bent starts above 10.
- An arm at exactly 20 is besideBody, behind included. `behindBody` starts above 20.
- `supportedInFront` wins over every other valid arm value; invalid angles stay invalid. `behindBody` is checked before overhead.
- Values outside the ranges get no value. The classifiers never clamp them into a band.
- Follow-up done: `coverage.json` and `coverage-matrix.md` now carry the approved texts. A new test keeps `coverage.json` equal to the code.
- The stale X1 comments in `exercise_attributes.dart` and `attribute_boundaries_test.dart` now say closed. No code changed.
- Only the release and version fields (stage 3c) remain from the stage 3a decisions. This is not stage 3b acceptance.

## Stage 3b — implementation (plan approved 2026-11-06)
D04 §7 (2026-11-06 entries) holds the owner decisions. Production stays at schema version 7.

| Sub-stage | Content | Status |
|---|---|---|
| 3b-1 | Frozen fixtures v1–v7, golden backups, today's v7 digests | committed 6c05f24; accepted by the owner as the test foundation |
| 3b-2 | Version 8 schema, not connected; attributes and equipment roles | implemented with the owner's register decisions; Review A fixes applied; awaiting re-check (`docs/schema-v8.md`) |
| 3b-3 | Historical steps v1→v7 on frozen schemas; differential proof | complete at 31f7652 (owner, 2026-11-06); review and two re-checks recorded below |
| 3b-4 | v7→v8 migration: safeguard A, report, quarantine, blocks | implemented; Review B conditionally sound (no High), fixes applied, awaiting re-check (WS2 of 3B-ACC-01; not committed by WS2); R-30 open |
| 3b-5 | All paths v1..v7 → v8 | mandatory evidence |
| 3b-6 | Real process kill | mandatory evidence |
| 3b-7 | Backup format 3; restore formats 1–3 | mandatory evidence |
| 3b-8 | Blocking and correction at domain and use-case level | mandatory evidence |
| 3b-9 | Device timing | mandatory evidence |
| 3b-10 | Record, independent review, CI, owner acceptance | — |

### Process incident: analyzer info committed (ede7808)
- ede7808 added a doc comment line over 80 characters. The local gate grepped the analyzer output and ignored its exit code, so the commit went through.
- cb841cb fixed one line but missed a second; the same gap let it through.
- b22224e fixed the comment. `flutter analyze --fatal-infos` exited 0.
- Correction: every gate now checks the analyzer exit code before a commit. History stays unchanged.

### Technical debt found in 3b-1 (production v7, unchanged)
- The v6→v7 step `backfillSessionExercises` creates a `session_exercises` row for a set whose session is missing. Each damaged database gains one foreign-key violation. Severity is low: it mirrors existing damage and loses no data. The v8 foreign-key report must tolerate it.

### 3b-1 — frozen historical evidence
- Location: `app/test/migration_v8/` (fixtures, goldens, expected v7 digests, generator, test, README). No production code changed.
- Fixtures: clean `fixture_v1..v7.sqlite` (zero foreign-key violations) and `fixture_v2..v7_orphans.sqlite` with orphans and loose references. Total 2.9 MB.
- Goldens: format 1 from the v2 to v7 eras, format 2 from v7 (production `exportJson`), and settings-only goldens for formats 1 and 2.
- `expected_v7_digests.json` holds today's production v1..v7 → v7 result per fixture: schema, row digests, foreign-key counts and restore outcomes.
- Restore with production `importJson`: every clean and settings-only golden restores. Every orphan golden is rejected as a whole; the database stays unchanged.
- Frozen-evidence rule: nobody regenerates or rewrites these files. A new case means a new file. The generator refuses to overwrite.
- **MANIFEST.sha256 SHA-256:** `70ecff92a46dece32493f526482915b56fdd3bf1797f696a4b750d4100805a10`. The test pins it.
- Accepted approximations (README): `recipeFavouritesOnly` sits in v6 settings, though it first appears at schema v5. `ex-quote` copies a custom exercise, which the app cannot produce; it stays as a robustness hazard.
- Review: an independent review (opus) found H1 (orphans in every fixture blocked any clean restore), M1–M4 and L1–L11. All are fixed. The re-review ran 11 mutation probes; all were detected, except a quoting-only CHECK change, which is ignored by design. Verdict: ready for the first commit.
- Test: 64 tests in the normal suite, about 4 s.

### 3b-3 — historical steps
- Location: `app/lib/data/db/migration/` (four files) and `app/test/migration_v8/`. Nothing in the app uses the new code.
- `AppDatabase`, its schema version 7, providers, repositories, screens and every 3b-1 file stay unchanged.

**What was built**
- `schema_versions.g.dart`: `dart run drift_dev schema steps drift_schemas/ lib/data/db/migration/schema_versions.g.dart` generates it (from `app/`).
  - It holds the frozen shapes `Schema2`..`Schema7`. A second run writes a byte-identical file.
  - CI now regenerates it before `git diff --exit-code -- lib`. The `.g.dart` name keeps it out of the analyzer and the coverage figure.
  - CI copies only `drift_schema_v1..v7.json` into a temporary folder and generates from there. A later `drift_schema_v8.json` cannot change the file.
  - Version 8 shapes go into a separate generated file in 3b-2. Only the v1..v7 snapshot files are frozen, not the whole folder.
- `historical_steps.dart`: `from1To2`..`from6To7`, written against `Schema2`..`Schema7`, never against `tables.dart`.
  - v1→v2 creates the v2 shape. Later steps add what each version added.
  - v5→v6 rebuilds `exercises`, `plan_exercises` and `session_sets` into the `Schema6` shapes. This removes the v5→v6 hazard.
  - Each step repeats the production statements in the same order. The production guards stay, so a crash-window database still completes.
- `legacy_training_rows_v6.dart`: a frozen copy of `LegacyTrainingRows` for the v5→v6 step.
  - It freezes the enum identifiers, labels, synonyms, ranges, reason texts and the search key with its diacritic table.
  - Production restore keeps using `LegacyTrainingRows`. A test proves both agree today.
- `repforge_migration.dart`: the strategy builder for the test harness now and for v8 later.
  - It switches foreign keys off before any transaction and verifies them off.
  - Each step runs in its own transaction. `PRAGMA user_version = N` is the last statement inside it.
  - It switches foreign keys on afterwards and verifies them on.
  - After a failure it restores the keys and rethrows the original error. A failing restore never hides it.
  - An injected clock stamps `quarantined_at`. A probe (`@visibleForTesting`, null by default) sees four checkpoints per step.
  - `steps` and `onCreate` stay public API: v8 passes its own steps through them.
- `test/migration_v8/harness_v7_db.dart`: a test-only database on the frozen v7 snapshot classes that runs the new chain.

**New frozen evidence** (new files only; `fixtures/README_3b3.md` describes them)
- `v7_strict_schema_3b3.json`: production v7 schema with raw SQL, strict SQL and CHECK clauses. It covers a fresh database and all 13 migrated fixtures.
- `build_3b3_evidence.dart` wrote it from live production v7. The generator refuses to overwrite.
- `MANIFEST_3b3.sha256` pins that file, `schema_versions.g.dart` and `legacy_training_rows_v6.dart`.
- **MANIFEST_3b3.sha256 SHA-256:** `61ab326cdcbb782ae2e5ffc85ed66bdc962f1e21264482f6bca16864a58e5e9d`. `frozen_3b3_artefacts_test.dart` pins it.
- `/.gitattributes` marks the two pinned code files `-text`.

**Erratum to 3b-1** (also in `fixtures/README_3b3.md`; the 3b-1 README stays unchanged)
- `normaliseSql` replaces every bracket, comma and operator with a literal `$1`. Dart does not expand `$1` in `replaceAll`.
- Scope: `create_sql`, `checks` and `index_sql` in `expected_v7_digests.json`. They cannot tell `<` from `>`, or `=` from `<`.
- 12 of the 35 v7 CHECK clauses hold such an operator. `table_info`, index lists, foreign keys and row digests are unaffected.
- The strict record corrects this. A test shows `normaliseSql` of it gives every stored `create_sql`, check and `index_sql`.

**Evidence** (`historical_steps_test.dart`, 173 tests, about 12 s, normal suite)
- (a) All 13 fixtures (v1..v7, v2..v7 orphans) migrate to exactly `expected_v7_digests.json`: rows, schema, foreign keys, integrity.
- (b) The schema equals a fresh v7 snapshot and the frozen strict production record. It also equals live production while v7 exists.
- (c) 48 injected failures (before work, after work, after the version write) leave the previous version and digest. A re-run reaches (a).
- (d) Negative control: a v5→v6 rebuild into the v7 shape fails with `no such column: set_kind` and changes nothing.
- (e) `user_version` is N after step N. Foreign keys are off during the chain and on afterwards.
  - With keys switched on at connection setup, the chain still sees them off and reaches (a). 11 cases.
  - After an injected failure the keys are on again, and the original error propagates.
  - A direct `upgrade()` leaves the keys on without drift's `beforeOpen`.
- (f) 50 crash-window cases complete to the (a) result:
  - 11 with all production work committed and the old `user_version`;
  - 18 with production work up to v6 committed, v6→v7 missing, `user_version` 2 to 5, orphans included;
  - 21 with one chain step committed and its version reset.
- The generated shapes `Schema2`..`Schema7` create exactly the frozen `schema_v2`..`schema_v7` snapshot schemas.
- `LegacyTrainingRowsV6`: golden tests for every label, synonym and range boundary and a Unicode sample. Equivalence tests against production.
- `frozen_3b3_artefacts_test.dart`: 5 tests on the 3b-3 manifest and files.
- `test/architecture/migration_isolation_test.dart`: no file outside `lib/data/db/migration/` imports it; `AppDatabase.schemaVersion` is 7.
  - The chain imports no live mapping, enum or table class.
- Mutation probes: the review ran 17; 3b-3 added two for the key restore. Each one failed tests.
- Local gate: `dart format` exit 0; `flutter analyze --fatal-infos` exit 0; targeted suites pass at concurrency 1.
- Full suite with coverage (concurrency 2): 2,068 passed, 1 skipped. Coverage gate: 93.3 % of hand-written lines (minimum 80 %).
- `build_runner` leaves `lib` unchanged. Both manifests verify.

**Difference between the new chain and production:** none found.

**Deviations from the plan and the review**
- `backfillSessionExercises` is an `AppDatabase` method, so the chain holds a frozen copy (`backfillSessionExercisesV7`).
  - Restore also calls the production method, so v8 may change it. The copy must not change.
  - Test (a) proves both produce the same rows on every fixture.
- The private quarantine helpers are copied as well; the clock replaces `DateTime.now()`.
- The harness accepts a target version below 7. Only the failure tests use it, for reference states.
- The strict record is named `v7_strict_schema_3b3.json`, not `expected_v7_strict_schema.json`.
  - The 3b-1 manifest test claims every `expected_*` file in `fixtures/`. That test is frozen.
- `MANIFEST_3b3` does not pin `text_normalisation_table.g.dart`. The frozen v6 copy does not use it.
  - Production `exerciseSearchKey` uses `search_key.dart` and Dart's `toLowerCase`, not the NFKD table.
  - Pinning it would freeze unrelated live library code. A Unicode golden test pins the lower-casing instead.
- `@visibleForTesting` marks only the probe. `steps` and `onCreate` are v8 API.

**Open issues**
- The frozen copy lower-cases with Dart's `String.toLowerCase`, like production. A Dart SDK Unicode update could change it; the golden test would fail.
- Review item L5 is accepted: `strictNormaliseSql` is not SQL-aware. It collapses whitespace and removes `"` inside string literals.
  - The frozen record also keeps the raw `sql`, which covers literals. The helper comment and `README_3b3.md` record it.
- Production characteristic, reproduced on purpose: a quarantined exercise's `original_json` holds the rebuilt v6 row, not the v5 row.
  - Nothing is lost: `is_custom` is NOT `supplied`, and the free text survives, because the UPDATE runs after the quarantine insert.
  - Flagged for 3b-4: the quarantine design decides whether v8 keeps this form.

### 3b-2 — schema v8
- Status: **implemented with the owner's register decisions and the Review A fixes; awaiting re-check.** Not committed. Not connected: production stays at schema version 7; `AppDatabase`, providers, repositories and screens are unchanged. Specification, DDL, report contract and assumption register: `docs/schema-v8.md`.
- Rules applied (D04 §7, 2026-11-06): "3b-2 rules"; "3b-2 register R-01 to R-11 approved"; "register R-12, R-14, R-15, R-19 to R-24 decided; 3c deferrals".

**What was built**
- `lib/data/db/v8/`: `tables_v8.dart`, `app_database_v8.dart` (`AppDatabaseV8`, `schemaVersion` 8; `onUpgrade` refuses until 3b-4), `exertion_rule_sql.dart` (TRN-020 expression ported from the trial).
- `exercises`: muscle, `supplied` and `equipment_json` columns removed; `source` (no default), `provider_id` (key), `revision`, R-14 CHECK, `mechanics`, `laterality`, `difficulty`, `retired_at` and the seven ADR-0008 A attribute columns (text compared with the ADR by a test).
- `session_sets`: the v7 0–10 clause replaced by the per-scale TRN-020 CHECK; everything else byte-identical to v7.
- New tables: `content_providers`, `catalogue_releases` (SHA-256, lowercase hex, stated, R-10), `anatomy_nodes`, `movement_patterns`, `equipment_items` (`default_role` only; class and lifecycle wait for 3c, Q11), `reference_labels`, `exercise_targets`, `exercise_patterns`, `exercise_equipment` (ADR-0008 B), `exercise_names`, `exercise_user_state` (no key, IC-902), `exercise_blocks` (one row per exercise and reason, three reasons), `migration_runs` (structured provenance), `migration_report_counts` (by category and by disposition), `migration_report_entries` (deterministic unique event id, JSON value contract, five category codes, §4.2 actions + `blocked`, WS4 `element` and `block_reason`, set exactly for blocked entries).
- Keys (R-12): catalogue links keyed with no delete action; exercise-owned children cascade; user state unkeyed.
- Deferred to 3c by the owner: `exercise_relationships`, `exercise_content`, `exercise_media`, the reference `release` columns, reference lifecycle and times (R-13, R-16 to R-18, R-21).
- `lib/data/db/migration/bootstrap_reference_v8.dart`: 31 nodes, 21 items, provider `repforge` (attribution empty until 3c); statements exposed and tested; device rows win (R-23).
- Domain: IC-315 also refuses an override on a `cardio` or `implement` item, for every source (Q6). **Text divergence (Review A, L6):** the approved `quality-and-duplicates.md` IC-315 text does not name this case; ADR-0008 E Q6 extends it. The approved document is not edited; the owner may update it.
- Generated: `drift_schemas/drift_schema_v8.json`; `lib/data/db/migration/schema_v8_shapes.g.dart` (`Schema8`, `from7To8`, from v7 + v8 only); `test/data/generated_migrations/schema_v8.dart` and `schema.dart` (v1–v7 regenerate byte-identical). CI re-dumps v8 and regenerates the v8 shapes; the v1–v7 step is unchanged.
- The unchanged v8 tables are the live v7 classes; the CI dump comparison guards them; they are to be frozen when v8 is accepted (Review A, L5).
- Frozen evidence untouched: both manifests verify; `schema_versions.g.dart` keeps its pinned hash.

**Review A (pass with findings, no High) and resolutions**
| Id | Finding | Resolution |
|---|---|---|
| M1 | Report must also state blocked, quarantined and rejected counts | `migration_report_counts` has a `disposition` dimension beside `category`; disposition counts equal the entries per action; recorded as implementing both owner statements |
| L1 | Isolation test let v8 import any chain file | Only `bootstrap_reference_v8.dart` and `schema_v8_shapes.g.dart` allowed |
| L2 | Bootstrap insert not testable against `INSERT OR IGNORE` | Statements exposed and asserted; injected invalid rows must fail; overwrite probes on all three tables |
| L3 | Implications missing for R-19, R-22–R-24 | Filled (R-19: 3b-7 restore and 3c release validation run IC-315) |
| L4 | Further open items | Registered: R-25 source-updated marker, R-26 source immutability, R-27 label constraints, R-21 extended to provider times, R-28 TRN-020 pair handling for 3b-4, R-29 reordering under UNIQUE ordinals |
| L5 | Doc said reused tables were frozen | Corrected: live v7 classes, CI dump guard, freeze on acceptance |
| L6 | IC-315 text divergence | Recorded here and in `docs/schema-v8.md`; approved document unchanged |
| L7 | 3b-4 structural comparison and key handling | Notes in `docs/schema-v8.md` §4 |
| L8 | `.claude/` in the tree | No action here; excluded from commits by the coordinator |

**Evidence** (from `app/`, uncommitted tree on 79a131b, after the Review A re-check fixes N-M1 and N-L1 to N-L4)
- CI generated-code sequence run locally: `build_runner`, the v1–v7 steps (hash unchanged), the v8 dump (reproducible, `cmp` equal), the v8 shapes and the test snapshots (v1–v7 byte-identical).
- `dart format --set-exit-if-changed .` exit 0; `flutter analyze --fatal-infos` exit 0.
- Targeted, concurrency 1: `test/data/schema_v8/`, `test/architecture/`, `test/domain/library/`, `test/migration_v8/` 794 passed.
- Full suite with coverage, concurrency 2: 2,262 passed, 1 skipped; coverage gate 92.4 % (17,620 of 19,067; minimum 80 %). These are the figures measured on this tree, which includes the WS4 commits up to 79a131b. The Review A re-check measured 2,146 tests and 92.3 % before the WS4 commits joined the branch; the WS4 tests explain the difference.
- Not evidence of acceptance: CI has not run on these changes (not committed).

**Open for 3b-4 from this register:** R-28 approach to confirm; the exact event-id formula (R-07) and provenance source values (R-08) are 3b-4 implementation details within the decided contracts.

### 3b-4 — v7 → v8 migration (WS2 of 3B-ACC-01)
- Status: **implemented; Review B conditionally sound (no High); its findings are fixed below; awaiting re-check.** Not connected: production stays at schema version 7; `AppDatabase`, providers, repositories and screens are unchanged. Contract, order of work, fixed details and register additions: `docs/schema-v8.md` section 6.
- Rules applied: D04 §7, every 2026-11-06 entry (3b decisions 1–10, per-exercise blocking, report detail, `quick_check` stop, structural identity, the 3B-ACC-01 scenario table, R-01 to R-24); ADR-0008 A–E; ADR-0009; ADR-0010; plan §6, §17, §21.

**What was built**
- `lib/data/db/migration/v7_to_v8.dart`: the v7 → v8 step on the generated `Schema8` shapes, the `quick_check` preflight through the WS4 decision, typed errors, the run-id ledger (R-07), `V8MigrationConfig` (clock, app version, install label, seed-byte loader, ledger, run-id generator, the OPEN H1/L9 switch).
- `repforge_migration.dart`: an optional `preflight` hook, run before the keys are switched off and before any transaction. The v1–v7 behaviour is unchanged (3b-3 tests pass).
- `AppDatabaseV8`: with a `V8MigrationConfig`, `onUpgrade` runs the preflight, the frozen historical steps v1 → v7 and the v7 → v8 step through `RepforgeMigration`; without one it still refuses.
- The WS4 contract is used, not duplicated: `mapLegacyExercise`, `classifyLegacyExertion`, `MigrationReportBuilder`, `reconcileReport` (with `affectedByTable` from the mapping's own lists, WS4 N2), `evaluateIntegrityPreflight`, `sha256Hex`, `encodeStoredValue`/`encodeStoredRow`.
- Architecture gates updated: v8 may import the strategy builder, the historical steps and the v7 → v8 step; only `v7_to_v8.dart` imports the library domain. `dart_test.yaml` declares the tag `heavy` (skipped by default, like `trial`).

**Evidence** (from `app/`, uncommitted tree on 2ba3997)
- `test/migration_v8/v8_all_paths_test.dart` (182 tests): all 13 frozen fixtures (v1..v7, v2..v7 orphans) → v8. Schema equal to a fresh `AppDatabaseV8` (strict normaliser; `table_info`, `index_list`, `foreign_key_list`, CHECK clauses, triggers and views; drift `validateDatabaseSchema`). Every retained column of every row equal to the v7 state; unchanged tables equal row for row. Targets, equipment links, blocks, quarantine rows, entries and counts of both runs, run rows and the release record equal expectations computed from the v7 state with the WS4 functions and the test's own SQL (`v8_migration_support.dart`), not from the migration code. Reference tables equal the bootstrap. A full `foreign_key_check` finds exactly the v7 findings, keyed by primary key; `integrity_check` ok. The stored report reconciles (outcomes = examined, disposition counts = entries, event ids re-derived). Blocked exercises keep their row, sets, session entries and plan entries.
- `test/migration_v8/v7_to_v8_test.dart` (62 tests after the Review B re-check; the ledger, M2, L4 and L6 tests are listed in the Review B table), the owner's scenario table: clean v7 migrates (keys off in every phase even when switched on at connection setup, on after open); failed `quick_check` stays at v7 with the file byte-identical and no ledger write (injected rows, injected pragma error, a real overwritten b-tree page, and the same page on a background-isolate connection); no-primary and unknown-equipment exercises blocked individually with one row per reason (R-01), resolving one keeps the block; a repeated equipment id keeps the first occurrence and reports each repeat with position and id; invalid TRN-020 values quarantined with the original pair and reported, valid values unchanged, the CHECK refuses a new invalid value; unknown reference data never invented; a failure at each of the 4 chain checkpoints and 15 step phases leaves exactly v7 (rows and strict schema) or, after commit, exactly v8, and the re-run with a new ledger object on the same file equals an uninterrupted run with the same run id (R-07); a cleared ledger gives a new run id; a repeated open changes no byte; a v8 file reset to version 7 runs the step and writes nothing; same input and run id give identical entries, another run id other event ids; a new violation in a new table, an unresolved exercise reference, a violation outside the targeted tables and three self-check failures each abort and roll back; v7 and v6 orphan fixtures (TD-44 included) are reported in the integrity run and do not block; release 1 hashes the exact seed bytes (not a re-serialised form) and is absent when the seed was never applied; pre-v8 quarantine rows are listed; the H1/L9 switch defaults off and, on, refuses before any write.
- `test/migration_v8/v8_large_profile_test.dart` (tag `heavy`): the deterministic 3b trial fixture (5,000 exercises, 100,000 sets) migrates; values of untouched tables, findings, counts, report reconciliation and the strict schema checked. Host: about 2.5 s (Linux VM; comparison only, not device evidence).
- Mutation probes (manual, restored): skipping the exercise quarantine, always taking a new run id, ignoring new targeted violations, shifting equipment ordinals, changing a report value were each detected; disabling the broader whole-database comparison was not detected until the test "a new violation outside the targeted tables" was added, which now detects it.
- Local gate after the Review B re-check fixes (uncommitted tree on 0d912c2): `dart format --set-exit-if-changed` exit 0; `flutter analyze --fatal-infos` exit 0; targeted, concurrency 1 (`test/migration_v8`, `test/data/schema_v8`, `test/architecture`, `drift_upgrade_behaviour_test.dart`): 622 passed, 4 skipped (kill and heavy); `v7_to_v8_test.dart` 62 tests; v7to8 part of the kill suite (`--run-skipped --tags "kill || heavy" --concurrency=1 --plain-name v7to8 test/migration_v8/kill/`): 51 passed, exit 0: 30 deterministic kills, of which the 15 past the ledger write (`7:workDone`, `7:versionWritten`, `7:committed`) ended with the killed process's run id and 15 (`7:stepStarted` and the v5 → v6, v6 → v7 checkpoints) with the re-run's; 20 random kills, all real, 19 inside the transaction, all recovered to v7, 19 resumed with the killed process's run id; full suite with coverage, concurrency 2: 2,537 passed, 5 skipped; coverage gate 92.6 % (18,248 of 19,716 hand-written lines; minimum 80 %), `v7_to_v8.dart` 608 of 629 lines. Both frozen manifests verify. Not evidence of acceptance: CI has not run on these changes (not committed).

**Review B (conditionally sound, no High) and resolutions** (uncommitted tree on 0d912c2, WS5 merged)
| Id | Finding | Resolution |
|---|---|---|
| M1 | Run ledger not bound to a database: a shared ledger gave database B the run id of A's failed attempt (probe P1); a stale entry after a kill between commit and clear was reused by another database with the old time (P2) | Entries keyed by upgrade and canonical path, bound to the file fingerprint at the step's start (header SHA-256, length, FNV-1a of every byte; restored exactly by a rollback) and the app version; reuse only on a match, else a new run id that overwrites the entry; every open of a v8 database clears an entry whose run id is in `migration_runs`. Tests P1, P2, same path with other content, other app version. R-32 rewritten; the semantics go to the owner |
| M2 | Pre-existing findings: no test with a new violation in a column that already has baseline damage, nor with two findings in one column; dropping the record id from the finding key survived | Both tests added (orphan v7: a new IC-901 in `session_sets.exercise_id` aborts; two pre-existing IC-901 sets are both reported); the mutation now fails |
| M3, L7, L11 | Release 1 content (R-30) | Behaviour unchanged, still provisional; the reviewer's alternative is described as option (b) in `docs/schema-v8.md` R-30 (pinned v7-era seed hash `839d9ca2…`, nullable counts by schema change, explicit `applied_at` provenance), not applied. Owner decision pending |
| L1 | Corrupt or foreign ledger; temporary file name; directory fsync | `MigrationRunLedgerFailure` with a recovery route (move the ledger aside; the database is unchanged), tested for three bad contents and the route; unique temporary name per write; ledger deleted when empty. Directory fsync is not possible in `dart:io`; recorded as a limitation (the worst outcome is a new run id, never a wrong reuse) |
| L2 | A failing ledger clear after the commit failed the open | Swallowed; cleared at the next open; tested |
| L3 | Resume with another clock untested (mutation `at` from the clock survived) | Test: a resumed run with a later clock keeps the first `generated_at` and stamps; the mutation now fails |
| L4 | `affectedByTable` self-check never fired (mutation dropping it survived) | Test-only mapper seam; mappings whose quarantine or block list disagree with their events fail the self-check and roll back; the mutation now fails |
| L5 | Only entry counts of the stored report were compared | The self-check compares every stored entry column and every count row of both runs with the built report |
| L6 | v8 tables or indexes already in a v7 database were silently accepted | `V8MigrationFailure(unexpectedState)` before any write; tested for a table and an index |
| L10 | `quickCheck` seam on the production constructor | Moved, with the mapper seam, to `V8MigrationConfig.forTesting` (`@visibleForTesting`) |

**WS5 integration (3b-6 and 3b-9 harnesses).**
- `recovery/migration_registry.dart`: `v7to8` registered (`AppDatabaseV8`, input version 7, not a stand-in; deterministic: harness clock, run id `run-1`, a run ledger next to the database file). A target below 8 runs the historical chain.
- `kill/kill_test.dart`: the deterministic and random kills run for both migrations. v7to8: fixtures v7, v7 orphans and v5 (through the historical steps); completed reference = the in-process run of the same migration.
- `timing/timing_harness.dart`: host reference digests for v7to8 (start `v7 602dbcd0601b46b7`, the WS5 v7 profile digest; end `v8 2f23e80e81fd7057`, the same from the calling isolate and the app engine). `timing/host_timing_test.dart` times both migrations. The device harness (`integration_test/migration_v8_timing_test.dart`) still runs the historical stand-in; switching it to v7to8 is left to the 3b-9 device campaign (it would need the seed asset only for a database whose seed was applied, which the D04 profile is not).
- Kill run (first round, `flutter test --run-skipped --tags "kill || heavy" --concurrency=1 test/migration_v8/`, child built with `dart build cli`): 213 passed in 14 min 40 s; exit 0. Deterministic kills 162 in all (54 distinct checkpoint and mode pairs). For v7to8, real SIGKILLs at the **4 chain checkpoints** of the v7 → v8 step (`7:stepStarted`, `7:workDone` app and spill, `7:versionWritten` app and spill, `7:committed`) on v7, v7 orphans and v5, and at the v5 → v6 and v6 → v7 checkpoints of the v5 start: 30 kills. Each exited −9; with `--spill` the journal was hot (77,328 bytes) and the reopen played it back; the recovered state equalled exactly one reference (v7 before the commit, v8 after it); a new process completed; one more run wrote nothing; the run ledger next to the file was gone afterwards. The **15 internal phases** of the step are covered by in-process failure injection (`v7_to_v8_test.dart`) and by the random kills, which land inside the step's transaction: 20 of 20 real kills on the D04 v7 profile, 18 inside the transaction; recovered 19 × v7 and 1 × v8; every re-run reached the v8 reference (calibration 4,353 ms in the AOT child).
- **Re-check (N1 to N7)**: N1 a v8 open resolves only the canonical path, returns at once when the ledger has no entry, and never fingerprints the file (test with a counting fingerprint seam: one read in the step, none at the v8 opens, the stale entry cleared); N2 an in-memory database never reuses a run id and never touches the ledger (test); the R-32 "never a wrong reuse" wording is qualified (a byte-identical file put back at the same path in the commit-to-clear window reuses the id; harmless for merges); N3 the kill child names a new run `run-<pid>`: after a kill past the ledger write the final run id is the killed process's (reuse proven across a real SIGKILL), otherwise the re-run's, and after a kill at the commit the stale entry is cleared by the re-run's open; the v8 references are computed per run id; N4 the rollback-journal assumption is documented and `<file>-wal` joins the fingerprint when present; N5 the v8-only entities are derived from `Schema8` minus the frozen `Schema7`, pinned by a test; N6 the kill wording above; N7 stale ledger temporary files are removed on the next write (test). Results: see the local gate line.
- Host timing on the D04 v7 profile (3 runs and a recovery/retry; host only, not device evidence): app engine median 7,175 ms (worst 7,863), retry 7,232 ms after a failure injected at `7:versionWritten`; calling isolate median 2,409 ms (worst 2,547), retry 2,448 ms; every run and the retry ended in the pinned end digest. The 3b-4 heavy test on the trial profile: 3,317 ms.

**Open (owner) and outstanding**
- **R-30 release 1 record content: OPEN, blocks 3b-4 acceptance.** Provisional implementation only (recorded when `seedExercisesVersion` ≥ 1; `applied_at` from the setting; counts 0; `app_version` NULL; the setting kept).
- Confirmation requested: R-28 (TRN-020 pair handling, implemented as stated), R-31 (integrity run for pre-existing damage; rule code `foreign_key_check`), R-32 (run-id ledger bound to the database and app version; the meaning of resumed and new, rewritten after Review B M1), R-33 (pre-v8 quarantine rows in the report); the block rule codes of WS4 N3.
- OPEN, unchanged: the WS4 H1 and L9 visibility switch stays off.
- Not in 3b-4: IC-907 (exercise ids inside quarantined originals); production wiring of the seed-byte loader, install label and ledger file; 3b-6 acceptance (the v8 kill evidence is above; the gate stays separate); backup format 3 (3b-7); use-case blocking (3b-8); device timing (3b-9). The all-paths evidence above covers the frozen fixtures only; 3b-5 stays mandatory evidence.

### Register R-01 to R-11: owner decisions (2026-11-06)
The owner approved all eleven recommendations, with constraints (D04 §7, same date). Category codes (R-05), persistent identifiers: `migrated`, `preserved`, `quarantinedOrUnresolved`, `rejectedOrBlocked`, `warningForReview`. 3b-4 implements R-01 to R-11.

### Register R-12 to R-24: owner decisions (2026-11-06)
R-12 (mixed foreign keys), R-20 (application enforcement of default roles), R-14, R-15, R-22, R-23 and R-24 are approved as recommended (D04 §7, same date). R-19 was already resolved. R-13, R-16, R-17, R-18 and R-21 are deferred to stage 3c as recorded requirements. TD-44 (D05) records the v6→v7 backfill orphan.

**Stage 3b status (2026-11-06):** 3b-1 accepted as foundation; 3b-3 complete; 3b-2 implemented with the register decisions, Review A re-check fixes applied, awaiting commit; 3b-4 to 3b-10 outstanding. Stage 3b as a whole is not accepted.


## Effort-point reporting requirement (owner direction, 2026-11-06)

WP 8 has an approved programme baseline allocation of **18 effort points**. This is a relative effort allocation, not a time budget. WP 8 remains active and not accepted; this reporting requirement does not alter its scope, stage gates or acceptance criteria.

The WP 8 lead must add a stage/deliverable breakdown totalling exactly 18 points to the active delivery plan and report allocated, earned and remaining points at every progress update. Earned points must be supported by completed deliverables and evidence; planned, assigned, started or unreviewed work does not earn credit by itself. Report confidence, blockers, dependencies, estimate variance and acceptance status alongside the percentage. Follow `docs/governance/effort-points-and-progress-reporting.md` and the repository-level `AGENTS.md`.

The existing 35% programme snapshot is a provisional estimate (6.30 earned points of 18), not a stage-level earned-progress ledger. It must not be treated as a verified current percentage until the stage breakdown and evidence reconciliation are completed.
