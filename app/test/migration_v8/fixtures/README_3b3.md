# Frozen 3b-3 evidence and erratum to the 3b-1 schema digests

WP 8 stage 3b-3 adds new frozen files here. It changes no 3b-1 file: not
`README.md`, `MANIFEST.sha256`, `expected_v7_digests.json`,
`migration_digest.dart`, `build_fixtures.dart` or `frozen_artefacts_test.dart`.

## Erratum: `normaliseSql` loses operators and brackets

`normaliseSql` (`migration_digest.dart`) calls `replaceAll` with the
replacement `r'$1'`. Dart inserts that text literally; it is not a group
reference. Every `(`, `)`, `,`, `=`, `<`, `>` and `!`, with the whitespace
around it, becomes the two characters `$1`.

Scope in `expected_v7_digests.json`:
- `create_sql`, `checks` and `index_sql` cannot tell `<` from `>`, `=` from
  `<` or `<=` from `>=`. 12 of the 35 CHECK clauses of v7 hold such an
  operator (10 with `<` or `>`, 2 with `=`).
- Brackets, commas and `=` all look the same.
- `table_info`, `index_list`, `foreign_key_list` and row digests are not
  affected.

The 3b-1 claim "every migrated fixture equals a fresh v7 schema" holds only up
to this loss. The 3b-1 files stay as they are (frozen evidence). This note and
`v7_strict_schema_3b3.json` correct the record.

## New files

| File | What it is |
|---|---|
| `v7_strict_schema_3b3.json` | Schema of production `AppDatabase` at v7: a fresh database (`createAll`) and every fixture migrated by production. Per entity: raw SQL, strict SQL and strict CHECK clauses. |
| `MANIFEST_3b3.sha256` | SHA-256 of `v7_strict_schema_3b3.json`, `lib/data/db/migration/schema_versions.g.dart` and `lib/data/db/migration/legacy_training_rows_v6.dart`. |
| `build_3b3_evidence.dart` | The generator. It refuses to overwrite an existing file. |
| `README_3b3.md` | This note. |

Strict SQL removes double quotes and collapses whitespace. It removes the
whitespace around `( ) , = < > !` but keeps the characters. Known limit
(review L5, accepted): it also does this inside string literals, so a `"` or
a run of spaces inside a quoted SQL string is not compared exactly. The record
also keeps the raw `sql` of every entity, which covers literals.
`historical_steps_test.dart` proves the record refines the 3b-1 digests:
`normaliseSql` of each strict entry gives the stored `create_sql`, `checks`
and `index_sql`.

The file is not named `expected_*`: the 3b-1 manifest test requires every
`expected_*` file in this directory to be in `MANIFEST.sha256`.

`frozen_3b3_artefacts_test.dart` pins the SHA-256 of `MANIFEST_3b3.sha256`:
`61ab326cdcbb782ae2e5ffc85ed66bdc962f1e21264482f6bca16864a58e5e9d`.

## How they were built

From `app/`, with production at schema v7:

    flutter test --concurrency=1 test/migration_v8/fixtures/build_3b3_evidence.dart

The first step writes the strict schema from live production. The second step
writes the manifest after the pinned code files were final.

## Rules

- Never regenerate or edit a file listed in `MANIFEST_3b3.sha256`.
- `schema_versions.g.dart` is generated from `drift_schema_v1.json` ..
  `drift_schema_v7.json` only. Those seven files are frozen (pinned in the
  3b-1 `MANIFEST.sha256`); the rest of `drift_schemas/` is not. CI copies the
  seven into a temporary folder, regenerates the file from it and fails on
  any difference. Version 8 shapes go into a separate generated file (3b-2):

      tmp="$(mktemp -d)"
      cp drift_schemas/drift_schema_v[1-7].json "$tmp"/
      dart run drift_dev schema steps "$tmp" lib/data/db/migration/schema_versions.g.dart
- `legacy_training_rows_v6.dart` is the frozen v6 data logic of the historical
  chain. Production restore keeps using `LegacyTrainingRows`.
