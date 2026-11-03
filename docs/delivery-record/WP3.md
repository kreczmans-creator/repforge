# Delivery record — WP 3: Domain models and local persistence

Date: 2026-11-03
Branch: `ccr-ac6db77c-jcnexo`
Status: **delivered for owner acceptance** (CI evidence appended when the runs for the final commit complete).

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
Filled in below for the final WP 3 commit.
