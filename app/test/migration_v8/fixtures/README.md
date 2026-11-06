# Frozen v8 migration evidence (WP 8 stage 3b-1)

Everything in this directory except `build_fixtures.dart` and this file is
**frozen evidence**. Owner decision 8 (2026-11-06): nobody rewrites historical
fixtures to match a new implementation.

- Never regenerate, edit, reformat or "fix" a `.sqlite`, `golden_*.json`,
  `expected_*.json` or `MANIFEST.sha256` file. `frozen_artefacts_test.dart`
  fails if any byte changes: it checks every file in the manifest (which also
  covers `drift_schemas/drift_schema_v1..7.json` and
  `test/data/generated_migrations/schema_v1..7.dart`) and pins the SHA-256 of
  `MANIFEST.sha256` itself. `/.gitattributes` marks these paths `-text`, so no
  checkout rewrites line endings.
- A new case means a **new file with a new name** (for example
  `fixture_v6_something.sqlite`) plus a new manifest entry. The generator
  refuses to overwrite an existing file.
- If the expected result of the migration has to change, add a new
  expectation file (for example `expected_v8_digests.json`); keep the old one.

Verify the manifest by hand from `app/`:

    sha256sum -c test/migration_v8/fixtures/MANIFEST.sha256

## Contents

| File | What it is |
|---|---|
| `fixture_v1.sqlite` .. `fixture_v7.sqlite` | **Clean** databases with `user_version` N, zero foreign-key violations and `integrity_check` ok, like a real database (the app ran with foreign keys on). |
| `fixture_v2_orphans.sqlite` .. `fixture_v7_orphans.sqlite` | The clean content plus foreign-key orphans and loose references: a damaged database. (v1 has no foreign keys.) |
| `golden_format1_v2/v3/v4/v5/v6/v7[_orphans].json` | Format 1 backups of each fixture as that era's exporter wrote them. v7 is the ebff8d0 era: format 1 written with `schemaVersion` 7, before commit 66a2a00 introduced format 2. |
| `golden_format2_v7[_orphans].json` | Format 2 backups written by the production `DriftBackupRepository.exportJson` on a copy of the v7 fixture opened at v7. |
| `golden_format1_settings_only.json`, `golden_format2_settings_only.json` | Valid backups whose only rows are settings (format 1 from a v6-era database, format 2 from production). |
| `expected_v7_digests.json` | `fixtures`: result of the production `AppDatabase` migration of each fixture to v7 (row digests, schema, foreign-key and integrity results). `restores`: result of restoring each golden with production `importJson`. |
| `MANIFEST.sha256` | `sha256sum` format, paths relative to `app/`. |

Fixture DDL is the **drift snapshot text** of `schema_vN.dart`. The snapshot
classes reformat DDL (unquoted column names in CHECKs, no spaces around some
operators); the apps of the era wrote the quoted, spaced form that production
`createAll` writes. This is an artefact of how the fixtures were built, not a
migration finding. Schemas are therefore compared through `normaliseSql`
(`migration_digest.dart`): identifier quotes removed, whitespace around
punctuation and operators removed. With it, every migrated fixture equals both a
fresh `schema_v7` snapshot database and a fresh production `createAll` database.
`legacy_quarantine` is `AUTOINCREMENT`; its counter (`sqlite_sequence`) is part
of the row digests.

## Hazards

All fixtures: soft-deleted rows, nulls in nullable columns, non-ASCII text
(accents, CJK, emoji), quote and backslash text, 4,000-character notes, and
valid boundary rows of the v6 CHECKs (reps 1/100, load 0/1000, assistance
0/1000, duration 1, metres 0.1, heart rate 30/250, rest 0/3600, target sets
1/20). Settings use the real keys of `DriftSettingsRepository`, each from the
era in which the key first appears in git history (`recipeFavouritesOnly` and
`availableEquipment` are approximated as v6; `recipeFavouritesOnly` first
appears at ae338e0, schema v5).

- v1: zero weight, same-instant rows, one `recorded_at` with a UTC offset
  (`+01:00`) instead of `Z`.
- v2..v5: `is_custom`, free-text muscles (case, spaces, synonyms such as
  `Quads`, `hams`), `Stretching` (a synonym of `mobility`), an unmapped type
  and category, unmapped primary (`rotator cuff`, `Neck`, empty) and
  secondary muscles, `fullBody` as secondary, secondary equal to the primary,
  a secondary repeated in one list, non-JSON lists; values outside the v6
  CHECKs in sets and plan exercises (reps 0/101, load -5/1500, heart rate
  20/300, rest -1/3601, exertion 11/-1, target sets 0/21, sort order -1).
  v2..v4 recipes carry the boolean freezer flag; v4 has nullable macros; v5
  has the new recipe shape, substitutes, plan items and prep batches.
- v6, v7: the TRN-020 exertion cases (RPE 0, 0.5, 7.3, 9.75; RIR 2.5, 6;
  `borg`; `RPE`; value without scale; scale without value), the same muscle
  hazards in canonical spelling, an unmapped type/category row (the
  `Stretching` synonym row is pre-v6 only: a v6 app had already mapped it),
  and a realistic library: 12 `lib-*` rows from
  `assets/seed/exercise_library.json` with `supplied = 1` and
  `seedExercisesVersion = 1`, user copies with `copied_from_id` pointing at a
  `lib-*` row, plan exercises and sessions referencing `lib-*`, and two
  pre-existing `legacy_quarantine` rows. One row cannot come from the app:
  `ex-quote` has `copied_from_id` = `ex-bench`, a custom exercise. The app
  copies only supplied exercises (TRN-008(2)). Treat it as a robustness hazard.
- v7: session exercises (the same exercise twice, 4,000-character note),
  scheduled workouts.
- `_orphans` additions: a serving, ingredient, substitute, saved-meal item,
  prep batch, plan exercise, set, session exercise and split day whose parent
  is missing; loose references to missing foods, recipes, exercises, plans and
  sessions; in v7 a set without an entry and a set whose entry is missing.

## Expected restore outcomes (production `importJson`)

Tested in `frozen_artefacts_test.dart` and recorded under `restores` in
`expected_v7_digests.json`. Every restore goes into a fresh v7 database that
first holds one sentinel measurement.

| Backup | Outcome |
|---|---|
| every clean golden (format 1 v2..v7, format 2 v7) | restores; no foreign-key violation, `integrity_check` ok |
| settings-only goldens (format 1, format 2) | restore |
| every `_orphans` golden | rejected as a whole (`StorageError`, SQLite error 787, foreign key); the sentinel and every other row are unchanged (atomic) |

## Observed production behaviour

On the `_orphans` fixtures: the v6 -> v7 step `backfillSessionExercises` gives
every set without an entry a new `session_exercises` row, including a set
whose `session_id` points at a missing session. The migration therefore adds
one more foreign-key violation (v2..v6 orphans fixtures: 4->5, 5->6, 5->6,
7->8, 8->9). It mirrors damage that already existed and no migration step runs
`foreign_key_check`, so nothing reports it. Severity Low. Not changed.
The clean fixtures stay clean through every upgrade path.

## How they were built

`build_fixtures.dart` is the generator (it is not a `*_test.dart` file, so a
normal `flutter test` never runs it). From `app/`:

    flutter test --concurrency=1 test/migration_v8/fixtures/build_fixtures.dart

It (1) creates each fixture with the generated `DatabaseAtVN` class and fills
it with strict raw `INSERT`s (foreign keys off), then checks `user_version`,
the schema against a fresh `schema_vN` database, `integrity_check`, and that
clean fixtures have no and `_orphans` fixtures have foreign-key violations;
(2) writes the goldens; (3) migrates a temporary copy of every fixture with the
production `AppDatabase`, restores every golden with production `importJson`,
and stores the results; (4) writes the manifest.

Format 1 goldens: format 1 was written by `DriftBackupRepository.exportJson`
from the first commit (75b6e18) until format 2 (66a2a00). The method body is
identical in every commit in between (`git show <commit>:...`, md5 of the
method after replacing the clock expression): the only difference is the
clock, `DateTime.now()` in 75b6e18 and `_clock.now()` in all later commits.
It runs `SELECT * FROM "<table>"` for each table of `allTables`, in the order
of the `@DriftDatabase` list of that era, and encodes
`{app, formatVersion: 1, schemaVersion, exportedAt, tables}` with a two-space
indent. `migration_digest.dart` (`exportFormat1`, `eraTableOrder`) repeats that
logic over the fixture; the table lists come from commits eeab56e (v2),
9ed0e7d (v3), 864065f (v4), 77540ae (v5), b1ab45a (v6) and ebff8d0 (v7) and
are checked against the snapshot classes. Assumptions: the old code was not
executed (it needs its own `AppDatabase`); `exportedAt` is the fixed
`2026-11-06T12:00:00.000Z` instead of the wall clock.

Normalisation in `expected_v7_digests.json`: only
`legacy_quarantine.quarantined_at` that is an ISO-8601 UTC text
(`YYYY-MM-DDTHH:MM:SS[.fff]Z`) and does not start with `2026-02-01T10:` (the
fixtures' own stamp) is replaced by `<migration-time>`. Any other value, for
example an integer epoch, is kept and so detected.

## Hand-over to v8

The migration and restore tests (`production migration to v7`, `production
restore`, and the format 2 / settings-only checks) are guarded: they fail with
an explicit message if `AppDatabase.schemaVersion` is not 7. When stage 3b is
accepted and production moves to schema 8, do not edit this directory. Add
`expected_v8_digests.json` (new migration result and restore outcomes, produced
by a new generator step that writes only new files), add it to the manifest in
a new manifest file, and move the v7-gate groups of `frozen_artefacts_test.dart`
to run against a v7-only snapshot of the old migration or retire them in an
owner-approved change. The fixture, golden, schema-snapshot and manifest
checks stay valid and keep running.
