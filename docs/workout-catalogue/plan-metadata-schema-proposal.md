# Schema proposal (on paper) — plan metadata, prebuilt plans, recipe tags and image

Status: **Proposal, not implemented. No schema change exists on this branch.**
Date: 2026-11-06
Owner decisions required first: D-1 (host work package) and D-2 (schema sequencing) in `docs/verification/parallel-workstream-assessment-2026-11-06.md`.

## Why on paper
Schema v7 is live; v8 is WP 8's isolated version and is byte-compared in CI against a fresh dump of the shared `tables.dart`. Any column added here before v8 is connected breaks WP 8's gate. This note fixes the data contract now so that the user interface, the importer and the catalogue content (`workout-templates-draft.json`) can be built against it, and the migration is written once the version number is free.

## Target version
The first free version after v8 is connected and WP 8 stage 3b is accepted (expected v9). The columns below are additive, nullable or defaulted, so the step is a plain `ALTER TABLE … ADD COLUMN` set with no table rebuild and no data transformation; backup format needs no change because the exporter writes every table and every column.

## `workout_plans` (template definition)
| Column | Type | Rule | Brief item |
|---|---|---|---|
| `description` | TEXT NOT NULL DEFAULT '' | free text | §4.4 name and description |
| `category` | TEXT NULL | CHECK in the ten catalogue codes (`chestTriceps`, `backBiceps`, `legs`, `upperBody`, `lowerBody`, `push`, `pull`, `fullBody`, `arms`, `shouldersCore`) or NULL for a user plan without one | §4.4 category |
| `difficulty` | TEXT NULL | CHECK `beginner`/`intermediate`/`advanced` | §4.4 difficulty |
| `emphasis` | TEXT NULL | CHECK `strength`/`hypertrophy`/`endurance` | variation |
| `estimated_minutes` | INTEGER NULL | CHECK 1–600 | §4.4 estimated duration |
| `source` | TEXT NOT NULL DEFAULT 'user' | CHECK `user`/`system`; same vocabulary as v8 exercises (`system` = supplied content) | prebuilt marker |
| `catalogue_id` | TEXT NULL | the `tpl-…` id of the seed entry; UNIQUE where not null; NULL for user plans | idempotent seeding, protection |
| `catalogue_revision` | INTEGER NULL | CHECK ≥ 1; CHECK `source <> 'system' OR (catalogue_id IS NOT NULL AND catalogue_revision IS NOT NULL)` | catalogue updates |

Target muscles and equipment are **derived** from the referenced exercises at read time (primary muscles and equipment of the plan's exercises), not stored, so they can never disagree with the exercise library and need no migration when WP 8 stage 3d changes the taxonomy.

Behaviour rules (domain, no schema): a `system` plan is read-only; "edit" creates a user copy (`source = 'user'`, `catalogue_id` NULL), as supplied exercises already do. A catalogue release never overwrites a user plan. Seeding is gated by a `seedPlansVersion` setting and skips every existing `catalogue_id`, including archived ones, like the recipe and exercise importers.

## `plan_exercises` (template prescription)
| Column | Type | Rule | Brief item |
|---|---|---|---|
| `exertion_scale` | TEXT NULL | CHECK `rpe`/`rir`; `(exertion_scale IS NULL) = (exertion_value IS NULL)` | §4.4 RPE/RIR targets |
| `exertion_value` | REAL NULL | TRN-020 per-scale CHECK: rpe 1–10 in 0.5 steps, rir integer 0–5 (same constraint text as WP 8 safeguard C for `session_sets`) | |
| `instructions` | TEXT NULL | free text, ≤ 2000 chars | §4.4 exercise-specific instructions |

Prescribed values stay on `plan_exercises` only; `session_sets` remain performed values. No change to any session table.

## `recipes`
| Column | Type | Rule | Brief item |
|---|---|---|---|
| `tags_json` | TEXT NOT NULL DEFAULT '[]' | JSON array of trimmed, lower-cased, unique strings; `category` stays as the single primary label | §4.2 categories and tags |
| `image_path` | TEXT NULL | relative path inside the app's documents directory; the file is not in the JSON backup unless the owner decides otherwise (OQ-04, D-6) | §4.2 optional image |
| `source` | TEXT NOT NULL DEFAULT 'user' | CHECK `user`/`system`; the 22 seed recipes would be back-filled to `system` by id prefix `starter-` **only if D-3 chooses read-only seed recipes**; otherwise this column is not added | §4.1 protection (D-3) |

## Out of this proposal
Food density and named servings for database foods (D-5): a different domain (foods) and a different decision; not designed here.

## Migration and test obligations when implemented
Per ADR-0004 and the WP 8 3b conventions: bump `schemaVersion`; `onUpgrade` step; `drift_dev schema dump` to `drift_schema_v<n>.json`; regenerate `test/data/generated_migrations/`; a migration test from every earlier version; the backup table list in `drift_backup_repository_test.dart` is unchanged (no new table) but a round-trip test must cover the new columns; frozen WP 8 fixtures are not touched.
