# Catalogue release format 2 — specification

- Version stamp: **release format 2, specification revision 1** (`formatVersion: 2`). Date: 2026-11-07.
- Status: **stage 3c specification; loading into v8 waits for stage 3b acceptance (OB-WP8-04).** This document defines a file format and the pure rules around it. Nothing in it connects schema v8, writes a database, or decides a schema location.
- Implements: ADR-0009 decisions 3 and 4; `docs/wp8-delivery-plan.md` section 7; `docs/wp8-stage-3c-3d-5-6-preparation.md` section 3.3 items 1 to 4 (the planner only), 6 and 8; register rules R-10, R-19, R-20, R-26, R-29 (`docs/schema-v8.md`).
- Code: `app/lib/domain/library/release/` (model, parser, validator, hash, reconciliation planner). Data: `app/assets/catalogue/releases/repforge-release-2.json`.
- Not decided here: where the deferred 3c schema goes (D-3c-1), the register choices R-13, R-16, R-17, R-18 and R-21 (D-3c-2), and label kinds for R-27 (D-3c-5). The format carries the data those tables will need and says nothing about their columns.

## 1. One file per provider and release

**Bundling.** The release and reference files are data artefacts in the repository. They are validated in CI by `tool/catalogue_gate.dart` and a byte-equality test against `docs/catalogue/reference/`. They are not registered as Flutter assets: bundling them into the app binary waits for D-3c-3.

A release is one UTF-8 JSON file, kept as a data artefact under `app/assets/catalogue/releases/`, named `<provider>-release-<n>.json`. It holds provider metadata, references to the approved reference files, the exercises of the release and the retirements. It is validated whole and applied whole (all or nothing). Applying the same file again changes nothing.

Release 1 of provider `repforge` is the existing seed (`app/assets/seed/exercise_library.json`, format 1 of the seed importer) and is not a format-2 file. Release 2 is the first format-2 file.

## 2. Top-level object

| Key | Type | Required | Meaning |
|---|---|---|---|
| `formatVersion` | integer | yes | Must be the integer `2` (`2.0` is refused). Any other value is refused (RF-003). |
| `provider` | object | yes | Provider metadata (section 3). |
| `release` | integer >= 1 | yes | Release number of this provider. |
| `releasedOn` | string `YYYY-MM-DD` | yes | Release date, carried in the file. Whether it becomes the creation and update time of reference rows is pending D-3c-2 (R-21); the domain model stamps the exercises of a parsed release with it. No clock is read. |
| `reference` | object | yes | The reference sections (section 4). |
| `tranches` | object | no | Tranche status for the coverage checks: `{ "5.1": "inProgress" }`. Values `planned`, `inProgress`, `complete` (`quality-and-duplicates.md` section 5, rule 4). Absent = none declared. |
| `exercises` | array | yes | The exercises of the release (section 5). May be empty only when `retirements` is not. |
| `retirements` | array | yes | Retirements (section 6). `[]` when none. |

Unknown keys are refused at every level (RF-006). A change of the format is a new `formatVersion`.

## 3. Provider metadata

| Key | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | Stable provider id (`repforge`). |
| `name` | string | yes | Display name. |
| `licence` | string | yes | SPDX identifier or licence name (`provenance-and-licensing.md` section 2). |
| `attribution` | string | yes | Exact attribution text; the empty string when none is required. |
| `url` | string or null | no | Source or licence URL. |

Whether provider attribution is the empty string or NULL, and whether and how the provider row is written (the v8 bootstrap holds attribution NULL), are open (D-3c-1, D-3c-2); the file only carries the string. These are the fields of the existing `ContentProvider` record (ADR-0009 decision 2). The wider registry fields of `provenance-and-licensing.md` section 2 (`kind`, `licenceUrl`, `sourceVersion` and so on) are not part of format 2; a dataset provider that needs them needs a later specification revision. The licence is always recorded.

## 4. Reference sections

`reference` points at the approved reference files by path and hash. The reference data is not copied into the release file, so there is one source for each list (`docs/catalogue/reference/`, bundled byte-for-byte under `app/assets/catalogue/reference/`).

```json
"reference": {
  "anatomy":          { "path": "reference/anatomy.json",           "sha256": "<64 lowercase hex>" },
  "movementPatterns": { "path": "reference/movement-patterns.json", "sha256": "..." },
  "equipment":        { "path": "reference/equipment.json",         "sha256": "..." },
  "ledger":           { "path": "reference/ledger.json",            "sha256": "..." },
  "coverage":         { "path": "reference/coverage.json",          "sha256": "..." }
}
```

All five sections are required. `path` is relative to the folder that holds the release's `reference` folder. `sha256` is the SHA-256 of the exact bytes of that file, lowercase hex. The validator refuses the release when the hash of the supplied reference bytes differs (RF-008), when a section is missing, or when the reference file's provider differs from the release provider (RF-009).

Reference data is bound to a release by path and hash, and transitively through the hash of the release file itself: changing a reference file changes its hash, which changes the release file, which changes the release hash. The reference-data release and version fields (L9, R-13) are not part of format 2 and stay open with D-3c-2. `path` is a plain relative path (no `..`, no leading slash, no backslash, no empty segment).

The reference data is validated by the 3a checks (IC-801 to IC-811) as part of every release validation. Loading the reference lists into tables is a separate deliverable (3c-2) and is not part of this specification.

## 5. Exercises

Each element of `exercises`:

| Key | Type | Required | Meaning |
|---|---|---|---|
| `id` | string | yes | Stable exercise id (`lib-...`, IC-101). Never reused (IC-111). |
| `revision` | integer >= 1 | yes | Catalogue revision (IC-103). Rises when any system-owned field changes (IC-105). |
| `names` | object | yes | Locale to `{ "name": string, "aliases": [string] }`. `en-GB` is required. |
| `loggingType` | string | yes | One of the six existing `ExerciseType` values. |
| `category` | string | yes | One of the seven existing `ExerciseCategory` values. |
| `targets` | array | yes | `{ "node": anatomy id, "role": "primary" or "secondary" }`. The array position is the ordinal (contiguous from 0, IC-309). |
| `patterns` | array of pattern ids | yes | Ordered; the first is the primary pattern (IC-205). |
| `equipment` | array | yes | `{ "item": equipment id, "role": "load" or "support" (optional), "roleNote": string (required with `role`) }`. An override only on an item whose default role is load or support (R-19, IC-315). |
| `mechanics` | string or null | no | `compound` or `isolation`; null for cardio and mobility (owner decision 2026-11-05). |
| `laterality` | string or null | no | `bilateral`, `unilateral` or `alternating`. |
| `difficulty` | string or null | no | `beginner`, `intermediate` or `advanced`. |
| `attributes` | object | no | Attribute name to controlled value (seven attributes, `coverage-matrix.md` section 3). |
| `provenance` | object | no | `authoredBy`, `reviewedBy`, `sourceRef` (each string or null; IC-212). |
| `relationships` | array | no | `{ "kind": "variationOf" or "progressionOf" or "alternativeTo" or "unilateralCounterpartOf", "to": exercise id }`; the exercise is the "from" end. `regressionOf` is derived and is never written: ADR-0008 decision 5 and IC-308 name four stored kinds, and the editorial guide stores `progressionOf` only (`docs/catalogue/README.md` F19). A written `regressionOf` is refused. (The R-16 choice itself is D-3c-2.) |
| `content` | object | no | Locale to section kind to array of item strings (`setup`, `execution`, `breathing`, `commonMistakes`). Absent or `{}` means no instructions yet. |
| `media` | array | no | `{ "id", "kind", "locator", "licence", "attribution" }`. Data references only. |

Rules:
- Source is always `system` and provider is the release provider. A release cannot describe a user or imported exercise. Source is never updated (R-26): there is no key that could carry it.
- An enum value outside its vocabulary is reported with the 3a code, not a shape code: `loggingType` IC-202, `category` IC-203, and `mechanics`, `laterality`, `difficulty`, target `role`, equipment `role` and relationship `kind` IC-308. All problems of the file are reported together; the catalogue checks that need a typed document run once the file parses.
- Mechanics, laterality and difficulty are optional for the parser. Whether they are required for the exercise is an integrity rule (IC-2xx), so the full list of problems is reported together.
- Content items take the `revision` of their exercise and the release provider.
- All other rules are the 3a integrity checks (`quality-and-duplicates.md`), run by the validator over the whole release.

## 6. Retirements

```json
"retirements": [
  { "id": "lib-example", "reason": "Merged into lib-other.", "replacedBy": "lib-other" }
]
```

`id` and `reason` are required; `replacedBy` is optional and must name an active exercise (IC-112). Absence from a release does not retire an id (IC-110; `population-standards.md` section 5 item 8): a release that omits a known id without listing it is refused. A retired exercise is kept, hidden from discovery and readable in history; its id is never reused (IC-111).

## 7. Content hash (R-10)

The release content hash is the **SHA-256 of the exact bytes of the bundled file, lowercase hex** (64 characters). Algorithm name `sha256`, encoding name `hex-lower`. Nothing hashes a re-serialised form: a file whose keys are reordered or whose whitespace changed is a different release file with a different hash. The hash is not stored inside the file. It is recorded in the release log by the reconciler and is an input to the integrity report. Code: `sha256Hex` over the bytes (`app/lib/domain/library/sha256_hex.dart`).

## 8. Validation (all or nothing)

1. Validation takes the bytes: the content hash is always the hash of the bytes that were parsed. The bytes decode as UTF-8 and parse as JSON; every malformed input becomes a finding, never an exception (RF-001 to RF-006).
2. The reference sections match the supplied approved reference bytes (RF-008, RF-009).
3. The whole release is checked by `runIntegrityChecks` (identity, completeness, references, relationship graph, names, near-duplicates, content, reference data, coverage), reusing the approved reference data.
4. A release is valid when no finding is an error. The result carries the full list of findings in both cases. Warnings and infos do not fail the release (`quality-and-duplicates.md` section 5, rule 2).

| Code | Meaning |
|---|---|
| RF-001 | Bytes are not UTF-8 or not JSON. |
| RF-002 | A value is missing, of the wrong type or not an allowed value (the finding names the path). |
| RF-003 | `formatVersion` is not 2. |
| RF-006 | Unknown key. |
| RF-007 | Duplicate relationship declaration, or an id retired twice. |
| RF-008 | A reference file's hash differs from the supplied file, or the file was not supplied. (A missing or malformed section in the release is RF-002.) |
| RF-012 | A tranche id the coverage specification does not know. |
| RF-013 | The seed file cannot be read as release 1 (gate only). |
| RF-009 | Provider mismatch between the release and a reference file. |
| RF-010 | The content hash differs from the expected hash supplied by the caller. |
| RF-011 | An approved reference file is not valid UTF-8 JSON or does not parse as its reference type. |

## 9. Reconciliation (planner rules)

The reconciliation planner is a pure function. It takes a validated release and an immutable snapshot of the current catalogue state (ids, source, provider, revision, retired flag, copied-from id, default roles of the known equipment items, latest applied release per provider and the content hash recorded for each applied release) and returns a plan. It reads no database and writes nothing.

| Situation | Plan |
|---|---|
| New id | Insert as `system`. |
| Known system id, release revision higher | Update the system-owned fields (names, aliases, classifications, targets, patterns, equipment, attributes, relationships between system exercises, content, media references). Child rows are replaced by delete and insert in the transaction (R-29). |
| Known system id, equal revision | No-op. A re-run of an applied release plans no write. |
| Known system id, lower revision | Refused. |
| Id listed in `retirements`, system and active | Retire. Already retired or not known: no-op. |
| System id in the snapshot, absent from the release and not retired by it | Refused (IC-110). |
| Retired id present in the release | Refused (IC-111). |
| Id exists as a user or imported exercise, or a custom copy | Refused. The planner never plans a write to those rows (ADR-0009 decision 4). |
| Release provider differs from the snapshot provider of that id | Refused. |
| Equipment item whose default role differs from the snapshot | Refused (R-20, default-role immutability). |
| Release number lower than the latest applied of the provider | Refused. |
| Same release number as one already applied, with a different content hash | Refused (RP-012). With no recorded hash for that number (equal to the latest applied) the file cannot be shown to be the same release: refused (RP-013). Equal hashes plan a no-op. |

Refusal codes: RP-001 id owned by a user or imported exercise or custom copy; RP-002 id owned by another provider; RP-003 lower revision; RP-004 retired id in the release; RP-005 known id omitted without a retirement (IC-110); RP-006 retirement of a non-system id; RP-007 default role changed (R-20); RP-008 older release number; RP-009 relationship ending on a non-system exercise; RP-010 id both listed and retired; RP-011 stored system exercise without a revision; RP-012 same release number, different content hash; RP-013 applied release number without a recorded hash.

Any refusal refuses the plan: it then holds no operation (all or nothing). The plan never contains an operation on user and imported exercises, custom copies, user state, user relationships, plans, sessions or history. The plan has no field for `source`, so "source is never updated" (R-26) holds by construction and is tested. For information only, the plan lists the custom copies whose source exercise is updated; this writes nothing and does not decide how the "source updated" marker is stored (R-25 stays open).

Out of scope here and not implemented: any database write, the transaction itself, the reference-data loader, clearing of block rows for system exercises (R-C9), the deferred tables and the R-30 implementation.

## 10. Example

A shortened valid document (reference hashes are those of the approved files; two exercises shown):

```json
{
  "formatVersion": 2,
  "provider": {
    "id": "repforge",
    "name": "RepForge",
    "licence": "proprietary (RepForge)",
    "attribution": "",
    "url": null
  },
  "release": 2,
  "releasedOn": "2026-11-07",
  "reference": {
    "anatomy": { "path": "reference/anatomy.json", "sha256": "207b151fd9d5be164494a4e852ffe52781d1e9b3ea8c29c8277a160330e334d6" },
    "movementPatterns": { "path": "reference/movement-patterns.json", "sha256": "1a2c28239fb8ee9c3f288d83a90309a4a8cfa2cb3bf44ea0cfba07523df67655" },
    "equipment": { "path": "reference/equipment.json", "sha256": "7595bab7c19bdad044b60257959eae7c6adc3dd630b4ab7714d88bfb9c7058bf" },
    "ledger": { "path": "reference/ledger.json", "sha256": "f1b3aae2cd298916657bbe548dedaf71e8de62140c925968f1bfa98b019bef4e" },
    "coverage": { "path": "reference/coverage.json", "sha256": "06f9d72aecc32a16d69fb94a374340b68fbeb68d9fd4e5749e3f9fd2734494c4" }
  },
  "exercises": [
    {
      "id": "lib-back-squat",
      "revision": 2,
      "names": { "en-GB": { "name": "Barbell back squat", "aliases": ["Back squat", "Squat"] } },
      "loggingType": "weighted",
      "category": "legs",
      "targets": [
        { "node": "quadriceps", "role": "primary" },
        { "node": "glutes", "role": "secondary" },
        { "node": "adductors", "role": "secondary" },
        { "node": "lowerBack", "role": "secondary" }
      ],
      "patterns": ["squat"],
      "equipment": [{ "item": "barbell" }, { "item": "squatRack" }],
      "mechanics": "compound",
      "laterality": "bilateral",
      "difficulty": "intermediate",
      "provenance": { "authoredBy": "RepForge editorial (WP 8 seed)", "reviewedBy": null, "sourceRef": null }
    },
    {
      "id": "lib-inverted-row",
      "revision": 2,
      "names": { "en-GB": { "name": "Inverted row", "aliases": ["Bodyweight row", "Australian pull-up"] } },
      "loggingType": "bodyweight",
      "category": "pull",
      "targets": [
        { "node": "upperBack", "role": "primary" },
        { "node": "lats", "role": "secondary" }
      ],
      "patterns": ["horizontalPull"],
      "equipment": [
        { "item": "barbell", "role": "support", "roleNote": "The barbell is a fixed bar here." },
        { "item": "squatRack" }
      ],
      "mechanics": "compound",
      "laterality": "bilateral",
      "difficulty": "beginner"
    }
  ],
  "retirements": []
}
```

(The example is illustrative and shortened; the shipped file is complete.)

## 11. Release 2 of provider `repforge`

`app/assets/catalogue/releases/repforge-release-2.json` holds the 89 seed exercises with the approved release-2 classifications of `docs/catalogue/mapping-existing.json`: all 89 ids kept, revision 2, targets, patterns, equipment with roles, mechanics, laterality, difficulty, attributes and cleaned aliases. **Why revision 2.** A device migrated from v7 holds the 89 seed exercises as `system`, provider `repforge`, revision 1, with no patterns, mechanics, laterality, difficulty, attributes or role overrides (`legacy_v8_mapping.dart`). The reconciler updates an exercise only on a higher revision, so release 2 ships revision 2 for every exercise whose system-owned fields differ from that migrated form, which is all 89; at revision 1 the planner would plan 89 no-ops and record release 2 as applied without any classification reaching the device. The gate checks release 2 against that migrated form (the seed through the 3a mapping) with IC-104, IC-105 and IC-110. Instructions are not written (WP 8 stage 5): no `content` key is present. The file is generated by `app/tool/build_release_2.dart` and a test regenerates it and compares bytes, so it cannot drift from the mapping file.
