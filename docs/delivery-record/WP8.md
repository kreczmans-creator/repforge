# Delivery record — WP 8: Exercise library and training architecture

Date: 2026-11-05
Branch: `ccr-9fda2c32-wr163b`
Status: **in progress** (next defined package after WP 7's acceptance on 2026-11-05; depends on WP 4, accepted. WP 6 device verification and D05 V-01 remain open and owner-owned; they do not block WP 8.)

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
| 1 — domain, schema v6, use cases | 6d401e6 | taxonomy enums; exercise aliases/supplied/copy; timed added load; cardio energy; rep ranges; splits; validation rules; `RecordSet`; library and history queries; schema v6 with CHECK constraints and legacy quarantine; library import. CI 41981492310, Android 41981492309, iOS 41981492295, integration 41981492328 — all success (the on-device test ran the v6 migration). |
| 2 — Train tab library | (this commit) | library with search, category/muscle/equipment filters, persisted equipment selection, supplied/custom badges, archived toggle; exercise detail with per-type history formatting; custom exercise editor; copy-on-edit for supplied exercises |

### Stage 1 — training domain, schema v6, use cases (no UI)
- **Domain** (`app/lib/domain/training/`): enums `ExerciseCategory`, `MuscleGroup`, `Equipment` exactly per the taxonomy; `Exercise` with aliases, `supplied` (the one provenance concept; `isCustom` is derived) and `copiedFromId`; timed sets with optional added load; cardio energy with a `userEntered`/`estimated` label (never read by nutrition); plan exercises with reps range, duration, distance, load, rest, order; `TrainingSplit`/`SplitDay`. Pure rules in `training_validation.dart` (`parseDuration`, `formatDistance`, `normaliseExerciseSearch`, `validateExercise`, `validateSetForExercise`, `validatePlanExercise`, `validateSplit`, `reorder`) and `exercise_query.dart` (`ExerciseQuery`, `filterExercises`). `normaliseSearchKey` moved to `domain/core/search_key.dart` (still exported from the nutrition mappers). `LoadKg.strict` refuses a value that is not a 0.25 kg step instead of rounding it.
- **Queries**: `watchLibrary`/`search` (text, category, muscle with primary first, equipment subset, archived hidden); `sessionsForExercise` (completed sets per session, newest first, paged), `lastPerformance`, `hasHistory`; `exists`, `delete`, and `archive` guarded by `deleted_at IS NULL` (TD-23, returns whether a row changed).
- **Schema v6** with CHECK constraints (TD-25) and the `legacy_quarantine` decision: see `docs/data-model.md` (Migrations 5 → 6).
- **Use cases** (`app/lib/features/training/application/`): `SaveCustomExercise`, `CopySuppliedExercise`, `ArchiveExercise`, `RecordSet`, `SavePlan`, `SaveSplit`, `ImportExerciseLibrary` (started from `main.dart` after the first frame, like the recipe import) and providers.

## Independent review (fresh reviewer, range 64599f3..058d433)
No high-severity defects; D06 acceptance holds in substance. Findings (verified by probe):

| ID | Finding | Severity | Resolution |
|---|---|---|---|
| M1 | Off-step loads (80.1 kg) and small negatives are rounded, not rejected, so TRN-002(2) is not enforced at use-case level; the strict constructor had no caller | Medium | Fix in progress: one strict input constructor; lenient only for database reads |
| M2 | `WorkoutSessionRepository.upsert` re-inserts sets without validation (no caller today; WP 9 risk) | Medium | Fix in progress: upsert writes the session only |
| M3 | Exertion rule allowed RIR 0–10 in half steps; D04 TRN-020 says RIR 0–5 whole numbers (RPE 1–10 in 0.5 steps). Inherited from WP 3, never an owner decision | Medium | Fix in progress: rule aligned to D04; the looser v6 CHECK stays (domain stricter) |
| M4 | A migrated exercise with unrecognised category/muscle/equipment text becomes unreadable with no record; taxonomy labels were not recognised | Medium | Fix in progress: identifiers and labels matched; unmatched optional values dropped with a quarantine record; unmatched required values quarantined |
| L1 | Copy-on-edit created the copy before the editor opened; cancelling left an orphan | Low | Fix in progress: copy persisted only on save |
| L2 | Bodyweight-only filter not selectable (TRN-011(2)) | Low | Fix in progress |
| L3 | Archived exercises accepted in plans | Low | Fix in progress |
| L4 | Type change allowed when the exercise is used in a plan | Low | Fix in progress |
| L5 | One use case catches `Exception` only | Low | Fix in progress |
| L6 | No test guards TRN-007(2) | Low | Fix in progress |
| L7 | TD-23 and TD-25 not updated in D05 | Low | At delivery |

TRN criteria the reviewer found not fully met: TRN-002(2), TRN-011(2); and TRN-020 contradicted by the enforced rule (WP 9 scope, fixed here).

## Tests, CI
Appended at delivery.
