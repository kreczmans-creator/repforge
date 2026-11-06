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

## Stage 3a — domain model (committed; see commit below)
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
- **X1 contiguous boundaries (resolved in code).** The approved texts leave gaps (angle 10 to 15 degrees, arm 20 to 90 degrees, knee 10 to 90 degrees). `AttributeVocabulary` carries contiguous boundary texts and `AttributeBoundaries` implements them as classifiers: angle (decline below -10, flat -10 to 10, incline above 10 up to 45, steeper has no value), knee (straight up to 10, bent above 10), arm (beside the body up to 20 degrees from the trunk, then flexed90 or abducted90 up to 135, overhead above 135, behindBody for a rear elbow, supportedInFront on a support). Tests sweep every degree and show exactly one value. **The numeric cut points are the architect's proposal for owner confirmation**; the approved `coverage.json` and `coverage-matrix.md` text is not edited.
- **X2 IC-412 token gate (resolved in code).** `DuplicateOptions.tokenGate` (`TokenGateRule`; default `whenAnyAttributeDiffers`, the literal reading — owner decision pending) skips the name-token gate when a recorded attribute differs. With it off the documented 16 pairs are reproduced exactly; with the literal rule (skip the gate when any recorded attribute differs, the current default) the worklist is **30 pairs**: the 16 plus 14, of which only 3 differ by attributes alone (chin-up/pull-up, db-curl/hammer-curl, deadlift/sumo deadlift) and 11 also differ in load items. The narrow rule (skip the gate only when attributes differ and load items are equal) gives **19 pairs** (the 16 plus those 3), confirmed by a test. The rule is the named option `DuplicateOptions.tokenGate` (`TokenGateRule`); the owner decides. The assisted dip stays hidden under every reading: no attribute is recorded for it and its token share with the dip is 0.33. The correction to the section 6 claim (attribute difference does not clear IC-412, only IC-601 to IC-603) is implemented and tested.
- **X3 `trunkExtension` "when the spine moves" (no code change).** Rule R5 is a technique decision an automated check cannot read; there is no domain rule to add. The wording gap is in the approved `movement-patterns.json` and `.md` ("machine back extensions" without the condition). Those files are approved and read only here. **Proposed wording for the owner:** "machine back extensions in which the spine itself moves".

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
| IC-412 | 16 | **16 with X2 off** (same pairs and scores); **30 literal X2 (default); 19 narrow X2** |
| IC-809 | not in the table | 1 warning: two anatomy nodes are labelled "Chest" (`regionChest` and `chest`) |
| IC-312, IC-506, IC-507, IC-509, ED-501 | not listed | 0 |
| Totals | 93 warnings, 16 infos (IC-200 to IC-500) | 93 warnings in IC-210, IC-311, IC-508 plus 4 (IC-602), 30 (IC-412) and 1 (IC-809) = 128 warnings; 16 + 7 (IC-603) = 23 infos |

Coverage baseline from `mapping-existing.json`: **67 of 325** slot fills and **20 of 70** conditioning, power and mobility entries, as accepted by the owner. All 21 per-group fills equal the table of `coverage-matrix.md` section 11 (for example chest 8, upper back 5, lats 6, shoulders 5, biceps 5, triceps 5, forearms 2, glutes 4, abductors 1, adductors 1, quadriceps 12, hamstrings 4, calves 1, abs 6, obliques 2; rotator cuff, neck, hip flexors, deep hip rotators, shin and lower back 0), the equipment-class baseline of 15 groups equals the table, and each conditioning set lists the documented seed exercises. IC-811 passes on the approved `coverage.json` (every slot minimum equals its counted entries; derived minimums, references and vocabulary resolve).

Reference data: parsers read 126 anatomy nodes (10, 26, 63, 27 by level), 79 patterns (17 families, 62 patterns), 33 equipment items (21 existing, 12 approved), 238 ledger entries, 21 groups with 325 slot minimums and 16 sets with 70 entries. Every validator (IC-801 to IC-807, IC-810) passes on the approved files; IC-809 reports the one duplicate label above. The 19 preserved ids at their planned levels and parents equal `anatomy.json`; the 21 existing equipment ids equal the `Equipment` enum; `bootstrapNodeIds` gives **31 nodes** (19 plus the 12 ancestors).

Tests: 280 new tests in `test/domain/library/` and `test/architecture/library_domain_isolation_test.dart` (parsers and validators against the approved files, malformed-input cases, each exercise rule with pass and fail cases, ADR-0010 severities for system and user content, functional double tags, relationship graph, names, near-duplicates, content, integrity report including previous-release checks, IC-900 references, accepted gaps, tranche status, coverage rules, OQ-19, X1 sweeps). Architecture test: `lib/domain/library` imports only `dart:convert`, `meta`, `domain/core/result.dart` and `domain/training/training.dart` (for `ExerciseType` and `ExerciseCategory`, reused unchanged); no Flutter, drift, plugin or higher-layer import.

Gate (from `app/`): `dart format .` no change; `flutter analyze --fatal-infos` no issues; `flutter test --coverage --concurrency=2` all tests pass; `dart run tool/coverage_gate.dart coverage/lcov.info --min 80` passes. Results: 1 750 tests pass (1 470 before 3a plus the 280 new); coverage of hand-written code 93.0 % (16 505 of 17 747 lines; minimum 80 %); coverage of `lib/domain/library` 97.9 % (2 985 of 3 049 lines). The gate was run on the uncommitted working tree; the four CI workflows have not run (nothing is committed).

### Deviations from the plan and specification (none silent)
1. **IC-412 default is the literal X2 behaviour** (30 pairs), not the documented 16; the documented figure is reproduced by `TokenGateRule.always` and the narrow reading (19) by `whenAttributesDifferAndLoadsEqual`. X2 was assigned to 3a, so the difference is intended; the owner chooses the rule.
2. **IC-809 raises one warning on the approved data** (the label "Chest" on two nodes). Labels may change without a migration; the owner can accept the warning in the accepted-gaps file or relabel `regionChest`.
3. **Codes outside the IC list:** ED-501 (functional double tag rule, editorial guide 5.7), ED-701 (content stored for an unknown exercise), ED-702 (incomplete media reference: kind, locator, licence and attribution required by plan section 3), ED-901 (stale accepted-gaps entry, specified as an info without a code).
4. **`CatalogueExercise` carries `provenance`** (author, reviewer, source reference), which plan section 3 does not list, because IC-212 checks the author.
5. **X1 numeric cut points and the X3 wording** are proposals awaiting the owner (above).
6. **Name normalisation approximates NFKD** (above). **IC-506, IC-507 and IC-509 use lists and heuristics** (blocked words, US spellings, proper nouns, synonym pairs) that the specification says are held with the tool and reviewed by the owner; they are starting lists and give no finding on the seed.
7. **The mapping loader is test support**, not production code: converting `mapping-existing.json` into release 2 exercises belongs to the release format of 3c.

### Open points for 3b and 3c
- **3b:** the 31 bootstrap constants must equal `bootstrapNodeIds` on the approved file (a test compares them). Storing the seven attributes needs the ADR-0008 clarification (one column each or `exercise_attributes (exercise_id, attribute, value)`). IC-901 to IC-907 on the real tables, IC-904 and IC-906 around the reconciler, and the migration report (`quality-and-duplicates.md` section 4) are 3b; the pure checks take id sets and are ready. `legacy` `fullBody` secondaries and duplicate secondaries must be listed by the migration (the domain reports them, it does not decide).
- **3c:** tranche gating (IC-411 becomes an error at tranche acceptance; `quality-and-duplicates.md` section 5 rule 3 blocks `complete` while IC-411, IC-412, IC-601 or IC-602 are uncleared) and the reference-data release and version fields in the release file; release format 2 parser (raw-string forms of IC-202, 203, 206, 308); `sha256` content hash; the `equipmentRoles` override needs a note field in the release file (`mapping-existing.json` has none, the 3a test loader uses the flag text); tranche status metadata; loading `docs/catalogue/accepted-gaps.json`; the CI gate that runs `runIntegrityChecks` over the shipped release and publishes the JSON and Markdown report; IC-110 retirement refinement is implemented as specified.
- **3d:** wire `attributeSetCounts` into WP 9 volume; every per-muscle figure shows `attributedSetCountsNotice`; adapt `Exercise`, `MuscleGroup`, `Equipment` users to the typed ids.
- **Owner:** confirm the X1 cut points, the X3 wording and the handling of the IC-809 warning; confirm the X2 default.

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
1. **IC-412 token gate (X2):** literal rule (30 pairs, default) or narrow rule (19 pairs). Assisted dip is not found under either (no recorded attribute; token share 0.33).
2. **L1 name normalisation.** `norm` keeps characters that NFKD would decompose or map. Probe cases and current output: Vietnamese precomposed `đ`, `ạ` (kept, `dạ`; NFKD gives `a` for `ạ`, `đ` has no decomposition); Greek accents (`Άλφα` kept accented); Latin Extended-B (`ǆ`, `Ǆ` give `ǆ`; NFKD gives `dž`); fullwidth (`ＡＢＣ１` kept; NFKD gives `ABC1`); superscripts and fractions (`m²` becomes `m`, `½` becomes empty; NFKD gives `m2` and `1⁄2`); U+02BC (kept as a letter, `aʼb`; it is not deleted as an apostrophe); the ligature `ﬃ` (kept); `Ơ` (becomes `ơ`, NFKD gives `o`). Options: **(1) accept** (exercise names are English with a few Latin-1 letters; the table covers those), or **(2) generate an NFKD table** for Latin, Greek and fullwidth from the Unicode data files, with no new dependency, and keep it as a checked-in constant.
3. **L5 OQ-19 roll-up.** With `rollUpToLevel`, one exercise whose primary and secondary targets share an ancestor credits that ancestor in both the primary and the secondary map (each map once per exercise). Options: **(1) keep both** (current; the maps stay independent and secondary is never part of primary totals), or **(2) drop the secondary credit where the ancestor already has primary credit from the same exercise.**
4. **X1 boundary texts.** Approved text in `coverage.json` against the code text: angle flat "within about 10 degrees of horizontal" against "from 10 degrees head-down to 10 degrees head-up inclusive"; angle incline "about 15 to 45 degrees" against "more than 10 and up to 45 degrees"; angle decline "head below the hips" against "head more than 10 degrees below the hips" (so a bench 5 degrees head-down now counts as flat, where the approved text read as decline); armPosition besideBody "within about 20 degrees of the trunk line" against "up to 20 degrees from the trunk line"; behindBody "more than about 20 degrees" against "more than 20 degrees"; flexed90 and abducted90 "about 90 degrees" against "more than 20 and up to 135 degrees"; overhead "elbow at or above ear height" against "more than 135 degrees from the trunk line, elbow at or above ear height"; kneePosition straight "within about 10 degrees of straight" against "from fully straight to 10 degrees of flexion inclusive"; bent "bent to about 90 degrees" against "bent more than 10 degrees (typically about 90)". The cut points (10, 20, 135) are the architect's proposal.
5. **ED-501** (two primaries of a functional pair) is an error for system content and a warning for user content; confirm.
6. Carried over: X3 wording, the IC-809 "Chest" label, and the 3b and 3c items above.

### Stage 3a re-check (2026-11-06)
Independent re-check of the fixes: M1, M2, M3, L2–L4, L6–L8 resolved; reproduction unchanged under all three token-gate rules (`always` 16, `whenAttributesDifferAndLoadsEqual` 19, `whenAnyAttributeDiffers` 30 IC-412 pairs; 0 errors; IC-601/602/603 0/4/7; coverage 67/325 and 20/70). New Low findings: **N1** relationship `source` defaulted to `user`, so a forgotten argument would weaken system checks (IC-402, IC-105/106) — **resolved: `source` is now a required parameter** on both constructors; test call sites state it explicitly; **N2** stale option name in this record — corrected; **N3** IC-414 reported alongside IC-407 on a long cycle — harmless, recorded.

