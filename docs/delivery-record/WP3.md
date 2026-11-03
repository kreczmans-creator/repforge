# Delivery record — WP 3: Domain models and local persistence

Date: 2026-11-03
Branch: `ccr-ac6db77c-jcnexo`
Status: **delivered for owner acceptance**; acceptance audit completed 2026-11-03 (see “Acceptance audit” below). Not accepted until the owner records a decision.

## What was built
- **Domain** (`app/lib/domain`): value objects with validation (`Quantity`, `Kilograms`, `Centimetres`, `LoadKg`, display conversions); nutrition (`NutrientAmounts`, `NutrientProfile` with provenance, `Food`, `ServingSize`, `FoodLogEntry` snapshot, `dayKey`); recipes (`RecipeIngredient`, `Recipe` with computed-vs-declared per-portion nutrition and provenance); training (`Exercise`, sealed `SetData` for the six exercise types, `SessionSet`, `WorkoutSession`, `PlanExercise`, `WorkoutPlan`, `Exertion`; rules for volume, Epley e1RM, max load, personal records, validation); measurements (`MeasurementSite` ×13 with left/right separate, `MeasurementValue`, `Measurement`); goals; settings; backup interface. Repository interfaces for each aggregate.
- **Persistence** (`app/lib/data`): drift schema v2 with 13 tables, 10 indexes and sync-ready columns; migration 1→2 (atomic, moves `weight_entries` into `measurements`); repositories for every aggregate (lenient mapping, idempotent soft delete, clock-stamped updates, shared child hydration); JSON backup export/restore with raw SQL rows and transactional replace; key/value settings. Documentation: `docs/data-model.md`.
- **Privacy**: ADR-0005 (platform encryption, no app-level encryption yet, Android auto-backup disabled, user-initiated JSON backup). Debt item TD-21 (iOS iCloud exclusion) opened.
- The WP 1/2 body-weight feature now runs on the measurements table through an adapter; its screens and tests are unchanged.

## Tests
236 tests pass locally (`flutter test`), analyzer clean with `--fatal-infos`. New in WP 3: 134 tests across domain rules (nutrition, recipes, training, units), every repository (round-trips, search, soft delete, lenient skips, ordering), schema migration (structure via `SchemaVerifier`, data copy row by row) and backup (envelope, round-trip into a fresh database, replace semantics, rejection of invalid/newer/malformed payloads with rollback).

## Review
Two independent passes. The first (ten findings) was applied in full: atomic migration, indexes on hot columns, backup restore via raw SQL with all failures returned as `StorageError`, SQL range filter restored for measurements with `limit(1)`, completed-only sets for PR history, bodyweight PRs by added load then reps, ingredient snapshots stored only when units match, bad ingredient lines skipped instead of hiding the recipe, one shared `groupByParent` hydration helper, clock injected into backup, update guarded against tombstoned rows. The test-writing pass found that the original restore threw a `TypeError` on every row (typed insertables); the raw-SQL rewrite fixed it and the round-trip tests now pass.

## Implementation notes from delegated work (reported, decided)
- `validReps` / `validExertion` are not yet enforced on write; WP 9's logging use case enforces them (recorded in `docs/data-model.md`).
- Stored loads round to 0.25 kg and quantities to 0.1 on read; writes are validated, so only externally written rows are affected.
- Upserting a soft-deleted id keeps it deleted; restore is explicit.

## Outstanding
- No UI for backup/export yet (WP 10 delivers the screen; the repository and tests exist).
- Seed data (22 legacy recipes, exercise library) is loaded in WP 7 and WP 8, not here.
- Coverage of hand-written code is above 77 %; the threshold gate in CI is still to be added (WP 14).

## CI evidence
Commit eeab56e: CI 41708808851 (`No issues found!`, `+236: All tests passed!`), Android build 41708808979, Debug release 41708809043, Integration tests 41708808869 (`+1: All tests passed!`) all success; iOS build 41708808930 cancelled by the next push's concurrency group. Correction (audit): the iOS runs for the next two commits (961ea50, 7e892e1) were also cancelled by concurrency; the first iOS success after WP 3 is 41711905223 on 9ed0e7d. The WP 3 code itself passed the iOS build on 75b6e18 (41706813244).

## Acceptance audit (2026-11-03, branch `ccr-9fda2c32-wr163b`)
Conducted after owner acceptance of WP 2, before WP 4 and WP 5 are presented. Independent of the two review passes above.

### Independent verification
- Local run of the WP 3 commit eeab56e (Flutter 3.47.9, Linux): `flutter analyze --fatal-infos` clean; `flutter test --coverage` → 236 passed; line coverage 44.2 % overall (3776/8552 including generated code), **84.6 % of hand-written code** (1839/2175). Matches the record's claims.
- Independent code review of `lib/domain`, `lib/data`, `drift_schemas`, tests and manifest against the D06 acceptance criteria. Findings and resolution:

| ID | Finding | Severity | Resolution |
|---|---|---|---|
| A1 | Migration 1→2 was not re-runnable. drift writes `user_version` only after `onUpgrade` returns; a kill in that window re-enters the step on next launch, where `CREATE INDEX` (no `IF NOT EXISTS`) and then `SELECT … FROM weight_entries` (already dropped) throw, and every later open fails. The doc comment claimed the step "can be retried". | Medium (data access loss on the first real device migration) | **Fixed in this audit**: tables created with `IF NOT EXISTS`, indexes and the legacy copy guarded on `sqlite_master`; new test "v1 upgrade can run again after a crash before user_version is recorded" reproduces the failure on the old code and passes on the new. |
| A2 | `Recipe.provenance` reported `userEntered` when every ingredient snapshot was `estimated` (the test enshrined it). Estimated data was mislabelled as user-entered. | Medium (provenance labelling is a D04 requirement) | **Fixed in this audit**: any estimated ingredient → `estimated`; all verified → `verified`; otherwise `userEntered`. Test corrected and a new case added. |
| A3 | Backup import checks `formatVersion` but not `schemaVersion`; unknown tables and columns are dropped silently, so a file from a newer schema restores with silent loss and returns `Ok`. Also, restore inserts tables in file order with foreign keys on, so a reordered file fails whole. | Low (self-produced files on the same build are unaffected) | Opened as D05 TD-22 for the backup UI package (WP 10). |
| A4 | `ExerciseRepository.archive` is not guarded by `deleted_at IS NULL`, unlike every other update. | Low | Opened as D05 TD-23. |
| A5 | Coverage threshold not set or enforced in CI (D06 verification line; engineering standards §7 say "set in WP 1"). Deferred to WP 14 without an ADR. | Medium (process) | Opened as D05 TD-24; owner decision requested below. |
| A6 | Standards gaps: no `CHECK`/unique constraints in `tables.dart` (§6); lenient mappers skip corrupt rows without logging (§5); no `CHANGELOG.md` (§8); test paths do not mirror `lib/` (§7). | Low | Opened as D05 TD-25 and TD-26. |
| A7 | Test gaps: `gToOz`/`mlToFlOz` conversions and the bodyweight added-load PR branch are untested; backup round-trip seeds 7 of 13 tables. | Low | Recorded here; to be closed when the owning feature packages (WP 7–10) exercise them. |

Verified true in code: restore runs in one transaction and rolls back on malformed input; PR ties are not records; Epley is capped at 12 reps for the estimate; `allowBackup="false"` is set; the domain layer imports nothing from Flutter.

### Acceptance criteria (D06 WP 3) against evidence
| Criterion | Status | Evidence |
|---|---|---|
| Every calculation rule has example-based tests (portion scaling, unit conversion, volume, PR detection) | Met, with the A7 gaps | `test/domain/nutrition_rules_test.dart`, `recipe_rules_test.dart`, `training_rules_test.dart`, `units_test.dart` |
| Export → wipe → import yields identical data | Met | `test/data/drift_backup_repository_test.dart`: "export then import into a fresh database round-trips" (re-export compared table by table), "import replaces existing rows" |
| Schema snapshot committed | Met | `app/drift_schemas/drift_schema_v1.json`, `v2.json` (`v3.json` added by WP 5); generated helpers under `test/data/generated_migrations/` |
| Unit tests on Linux CI | Met | `ci.yml` "Unit and widget tests"; runs 41706813198 and 41708808851 |
| Coverage threshold set and enforced | **Not met** | CI uploads `lcov.info` only (A5) |
| `docs/data-model.md` with ER diagram | Met | Mermaid `erDiagram` in `docs/data-model.md` |
| Encryption-at-rest assessment and ADR (owner direction) | Met | ADR-0005 accepted; `allowBackup="false"`; TD-21 for iOS |

### CI evidence (complete table)
| Commit | CI | Android build | iOS build | Debug release | Integration tests |
|---|---|---|---|---|---|
| 75b6e18 | 41706813198 success | 41706813209 success | 41706813244 success | 41706813174 success | 41706813338 success |
| eeab56e | 41708808851 success (`+236`) | 41708808979 success | 41708808930 cancelled (concurrency) | 41708809043 success | 41708808869 success |

Audit commit: 300 tests pass locally (`flutter test`), analyzer and formatter clean; CI run IDs for the audit commit are appended below when they complete.

### Deviations from the approved requirements
1. Coverage threshold not enforced (A5). Hand-written coverage is 84.6 %, above the 80 % proposed in WP 1, so enforcing it now would pass.
2. `validReps`/`validExertion` are rules, not yet enforced on write (recorded above; WP 9 boundary).
3. Stored dates: `DateTime` values are stored as ISO-8601 text with offset, not normalised to UTC as `docs/data-model.md` states (reads back correctly; sync ordering in WP 12 should normalise).

### Recommendation
**Conditionally accept** WP 3, with these conditions:
- C1. A1 and A2 fixes (this audit) are reviewed by the owner as part of the acceptance; they are the only implementation changes made.
- C2. Owner decides on the coverage gate: enforce 80 % on hand-written code now (one CI step) or record the deferral to WP 14 in an ADR, since engineering standards §7 require a threshold from WP 1.
- C3. TD-22 to TD-26 remain tracked and are not blockers.
