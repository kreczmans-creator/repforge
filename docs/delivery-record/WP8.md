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
| **4. Remaining implementation work** | Stage 3 architecture and reference data (3a–3d), stage 4 catalogue tooling and quality assurance, stage 5 anatomical catalogue population (tranches 5.1–5.7), stage 6 search, discovery and exercise screens; media workstream deferred | `docs/wp8-delivery-plan.md` §0.1 |
| **5. Final WP 8 acceptance criteria** | Original criteria plus stage 3–6 criteria, coverage matrix, no WP 9 regressions, open decisions dispositioned, final independent review | `docs/wp8-delivery-plan.md` §15 |

Decided 2026-11-05 (D04 §7): ADR-0008 and ADR-0009 direction; 19 muscle ids and `fullBody`; conditional `exercises` rebuild; OQ-19 (set counts; kg-volume clarification pending); OQ-21; legacy invalid values (earlier decision 3, with a report of every affected record); TRN-020 RIR integer 0–5 at domain and persistence boundaries (earlier decision 4); screen ownership (earlier decision 5). **Stage 4 authorised** (documentation and reference data only). **Stage 3 gated** until WP 9 delivery is accepted. Still open: OQ-22, OQ-23 (stage 4 output), OQ-19 kg-volume clarification, final authorisation of stage 3.

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
