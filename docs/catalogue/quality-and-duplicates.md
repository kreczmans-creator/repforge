# Catalogue quality and duplicate-detection specification — approved

- Status: **Approved by the owner 2026-11-05 (OQ-22 / OQ-23).** WP 8 stage 4 (documentation only). The checks are implemented in stage 3a and 3c as pure domain code and a CI gate; this document is the specification.
- Requirements: LIB-007, LIB-012, LIB-013; ADR-0009 decisions 5 and 6; `docs/wp8-delivery-plan.md` sections 10, 17.5 and 18.
- Related: `editorial-guide.md`, `coverage-matrix.md`, `population-standards.md`.
- Revision 2 (review findings F01, F08 to F11, F19, F24, F25): release 2 passes the errors (section 6); the near-duplicate signature is redefined and re-run on the seed; IC-900 enumerates every exercise-id column; the migration report lists skipped and rejected records; reference-data lifecycle, ledger and an accepted-gaps format are added.

## 1. Scope and structure
The checks run on three inputs: (1) a **catalogue release** (the bundled JSON, before it is applied), (2) the **reference data** (anatomy, patterns, equipment, `coverage.json`, `ledger.json`), and (3) the **database** (references from user data to exercises). Each check has a code, a severity and a rule.

Severities:
- **error**: fails the build for system content. The release is not applied.
- **warning**: reported. Must have a recorded disposition (section 5, accepted-gaps file) before a tranche is accepted. Does not fail the build.
- **info**: reported only.

## 2. Checks
### IC-100 Identity and revision
| Code | Rule | Severity |
|---|---|---|
| IC-101 | Exercise id matches `^lib-[a-z0-9]+(-[a-z0-9]+)*$`, at most 48 characters | error |
| IC-102 | Ids are unique within the release | error |
| IC-103 | `revision` is an integer of 1 or more | error |
| IC-104 | An id present in the previous release keeps or raises its revision; it never lowers | error |
| IC-105 | A system-owned field changed since the previous release requires a higher revision | error |
| IC-106 | Revision raised but content unchanged | warning |
| IC-110 | Every id in the previous release is present in this release or listed under `retirements`. **This refines ADR-0009**, which says an identifier absent from the release becomes retired: absence alone does not retire an id here; the tool refuses the release, so an accidental omission cannot retire an exercise. Recorded as a proposed ADR-0009 clarification (README section 6); the ADR is not edited | error |
| IC-111 | An id on the retirement ledger never reappears as an active exercise (ids are never reused) | error |
| IC-112 | A listed retirement names a reason; `replacedBy` (if any) exists and is active | error |

### IC-200 Completeness per exercise
| Code | Field | Rule | Severity |
|---|---|---|---|
| IC-201 | name `en-GB` | Present, 1 to 60 characters | error |
| IC-202 | loggingType | One of the six logging types | error |
| IC-203 | category | One of the seven categories | error |
| IC-204 | targets | At least one primary target | error |
| IC-205 | patterns | At least one; first is primary | error (warning before a tranche is marked in progress) |
| IC-206 | equipment | List present (may be empty) | error |
| IC-207 | mechanics | Present (`compound` or `isolation`) for categories push, pull, legs, core, fullBody. For cardio and mobility the field is **empty by owner decision** (2026-11-05) and unchecked (reported as info) | error / info |
| IC-208 | laterality | Present | error |
| IC-209 | difficulty | Present | error |
| IC-210 | content | The four sections present and non-empty (`setup`, `execution`, `breathing`, `commonMistakes`) | error once the exercise's tranche is complete; warning before |
| IC-211 | aliases | List present; empty list is a warning | warning |
| IC-212 | provenance | `providerId` registered; author recorded. The 89 seed exercises carry `repforge` and the author "RepForge editorial (WP 8 seed)" (`mapping-existing.json`, `seedProvenance`) | error |

### IC-300 Reference validity
| Code | Rule | Severity |
|---|---|---|
| IC-301 | Each target node exists in the anatomy list | error |
| IC-302 | A node appears once per exercise | error |
| IC-303 | No exercise tags a node together with its ancestor or descendant | error |
| IC-304 | `fullBody` as a secondary target, or together with any anatomical primary (ADR-0010, approved 2026-11-05: `fullBody` may only be the single primary of a qualifying whole-body or conditioning exercise). **Error for system content.** For **user content** it is a warning plus a migration-report entry: the stored value is never silently discarded and the user exercise keeps working (section 4) | error (system) / warning (user) |
| IC-305 | A primary node is not repeated as secondary | error |
| IC-306 | Each pattern exists; a family id is not used as a pattern (only leaf patterns) | error |
| IC-307 | Each equipment id exists in the equipment list | error |
| IC-308 | Enum values valid (mechanics, laterality, difficulty, relationship kinds `variationOf`, `progressionOf`, `alternativeTo`, `unilateralCounterpartOf`, content sections, equipment role `load` or `support`, attribute names and values) | error |
| IC-309 | Target and pattern ordinals are contiguous from 0 | error |
| IC-310 | Primary targets above 3 or secondary targets above 6 | warning |
| IC-311 | Category and pattern family not in the compatibility table (`movement-patterns.md`, section 3) | warning |
| IC-312 | Logging type unusual for the pattern (for example `cardio` logging with a strength pattern) | warning |
| IC-313 | An active exercise references a retired exercise, node, pattern or equipment id (reference `lifecycle` retired) | error |
| IC-314 | A target whose mapped node is non-anatomical used with a category other than cardio, fullBody or mobility | warning |
| IC-315 | A role override (`equipmentRoles`) names an item not in the exercise equipment list, a role other than `load` or `support`, or has no note | error |
| IC-316 | A recorded attribute is not in the controlled list (attributes approved 2026-11-05) | error |

### IC-400 Relationship graph
Stored kinds: `variationOf`, `progressionOf`, `alternativeTo`, `unilateralCounterpartOf` (F19). `regressionOf` is a derived view and never appears in a release file; the editor tool normalises an input `regressionOf` to the inverse `progressionOf`.

| Code | Rule | Severity |
|---|---|---|
| IC-401 | No self-reference | error |
| IC-402 | Both ends exist and are active in the release | error |
| IC-403 | No duplicate (same from, to, kind) | error |
| IC-404 | No inverse duplicate: a `progressionOf` from A to B together with one from B to A; symmetric kinds are stored once with ids in alphabetical order (`from` before `to`); a stored `regressionOf` is refused | error |
| IC-405 | `variationOf`: at most one per exercise; the graph is a forest (no cycles); the target is a family root (has no `variationOf`) | error |
| IC-406 | **Withdrawn at revision 2.** It warned about `variationOf` depth above 2, which IC-405 already makes impossible (the target must be a root, so depth is always 1). The code is not reused | — |
| IC-407 | The `progressionOf` graph is acyclic (depth-first search) | error |
| IC-408 | `unilateralCounterpartOf` joins one bilateral entry and one unilateral or alternating entry | error |
| IC-409 | `alternativeTo` between two members of one `variationOf` family | warning |
| IC-410 | `variationOf` pair has different primary patterns and disjoint primary targets (probably not the same movement) | warning |
| IC-411 | A unilateral or alternating entry with a bilateral twin by structure (same primary-target lift, primary pattern, load items and mechanics) and no `unilateralCounterpartOf` | warning (error at tranche acceptance) |
| IC-412 | Two exercises with the same primary-target lift, primary pattern, laterality and mechanics, whose names share at least 40 % of their tokens, which are not in one family, and **either** whose load-item sets differ **or** whose recorded attributes differ: "probable variation without a family link". A recorded attribute difference does **not** clear this check (it shows the pair is a variation and so needs its `variationOf` link); it clears only IC-601 to IC-603. A difference in grip, stance, angle or arm position counts only when both exercises record the attribute; otherwise it is a review checklist item (editorial guide section 3, test 4) **Amended 2026-11-06 (owner, X2):** the name-token gate is skipped only when a recorded attribute differs and the load items are equal (narrow rule, 19 pairs). See `docs/delivery-record/WP8.md`; the full specification update is stage 3c. | warning |
| IC-413 | Relationship to a retired exercise from an active system exercise | error |
| IC-414 | The longest `progressionOf` chain in the catalogue exceeds 6 steps (a reviewer note is required that the chain is a real ladder) | warning |

### IC-500 Names and aliases
Normalisation function `norm(text)`: Unicode NFKD; remove combining marks; lower-case; replace hyphens, dashes, slashes and underscores with a space; delete apostrophes; delete other punctuation; collapse spaces; trim. `squash(text)` is `norm(text)` with all spaces removed.

| Code | Rule | Severity |
|---|---|---|
| IC-501 | `norm(name)` is unique across exercises in the release | error |
| IC-502 | `squash(name)` is unique (catches "push up", "push-up" and "pushup") and no alias of an exercise equals its name by `squash` (catches *Pullup* for *Pull-up*) | error |
| IC-503 | No alias equals (after `norm` or `squash`) any other exercise's name or alias, or another alias of the same exercise (catches *Farmers walk* beside *Farmer's walk*) | error |
| IC-504 | No alias equals its own exercise's name | error |
| IC-505 | More than six aliases, or an alias longer than 60 characters | warning |
| IC-506 | Name or alias contains a blocked word (brand, "best", "ultimate", medical terms) from the blocklist | warning |
| IC-507 | Name not in sentence case, or contains US spellings from the UK/US list ("color", "center", "program", "gray") | warning |
| IC-508 | Names within Levenshtein distance 2 on `norm` | warning |
| IC-509 | A name matches a known UK/US synonym pair of another name (for example press-up and push-up; jump rope and skipping; elliptical and cross-trainer) | warning |

Cross-source collisions (user and imported exercises against system names) are reported in the app and never block a user.

### IC-600 Structural near-duplicates
**Inputs per exercise** (F11): category; logging type; the set of primary target nodes **lifted** by the rule below; the primary pattern; the set of **load-role** equipment items (items whose effective role is `support` are ignored, so a bench, a rack or a pull-up bar never makes two exercises look different or alike); laterality; mechanics (empty equals empty); recorded attributes; the set of name tokens (norm of the name, split on spaces, stop words *the of a and with* removed, a trailing *s* removed from words longer than three letters).

**Ancestor lift for target nodes.** A primary node is replaced by its **L2 ancestor** (muscle group). A node already at L2 or L1 (`chest`, `lats`, `abs`, `fullBody`) stays as it is. L3 and L4 nodes (`pectoralisMajor`, `frontDelts`, `trapeziusUpper`) therefore compare equal to a tag at their group (`chest` equals `pectoralisMajor`; `shoulders` equals `frontDelts`). The primary pattern separates the heads of one group (lateral raise from front raise).

**Score between two exercises:**
```
score = 0.25 * Jaccard(lifted primary nodes)
      + 0.20 * (same primary pattern ? 1 : 0)
      + 0.20 * Jaccard(load-role equipment ids; two empty sets count as 1)
      + 0.05 * (same laterality ? 1 : 0)
      + 0.05 * (same mechanics ? 1 : 0)
      + 0.05 * (same logging type ? 1 : 0)
      + 0.05 * (same category ? 1 : 0)
      + 0.15 * Jaccard(name tokens)
```
**Attribute clearing (IC-601 to IC-603 only).** If both exercises record an attribute and the values differ (angle, arm position, grip, grip width, body position, knee position, stance), the pair is **distinguished** and is not flagged by IC-601 to IC-603. It is still reported by IC-412 when the rest of the signature matches, because it needs a family link. An unrecorded attribute never clears a pair.

| Code | Rule | Severity |
|---|---|---|
| IC-601 | Score of 0.95 or more, pair not distinguished | warning: "probable duplicate" |
| IC-602 | Score from 0.85 up to but not including 0.95, pair not distinguished | warning: "close match" |
| IC-603 | Score from 0.75 up to but not including 0.85, pair not distinguished, same primary pattern | info: "similar" |

A pair is **cleared** when (a) the two exercises are linked by any relationship kind, or (b) a disposition is recorded in the accepted-gaps file (section 5) or in the release file under `duplicateReview` (pair, decision `distinct` | `merge` | `relationship`, reason, reviewer). Uncleared IC-601 or IC-602 pairs are reported and must be cleared before the tranche is accepted. They do not fail the build (ADR-0009). The thresholds are proposals; the pilot tranche tunes them. Results on the seed: section 6.

### IC-700 Content
| Code | Rule | Severity |
|---|---|---|
| IC-701 | Each item is 10 to 200 characters | error |
| IC-702 | Item counts: setup 2 to 5, execution 3 to 6, breathing 1 to 2, commonMistakes 2 to 4 | error |
| IC-703 | Sentence of more than 20 words | warning |
| IC-704 | Blocked phrases: medical or outcome claims ("cure", "treat", "heal", "rehabilitate", "prevent injury", "reduce pain", "burn fat", "guarantee") | error |
| IC-705 | Digits followed by reps, sets, kg, lb, %, or "x" patterns (a prescription) | warning |
| IC-706 | US spelling or non-metric units from the UK/US list | warning |
| IC-707 | Possible passive voice (heuristic: "is/are/was/were/be/been + past participle") | warning |
| IC-708 | Identical or near-identical item text (similarity above 0.9) across two exercises | warning |
| IC-709 | Sections in a locale without an `en-GB` counterpart | error |
| IC-710 | Mistake item lacks a fix sentence (single sentence only) | warning |

Originality cannot be checked automatically. It is covered by the originality statement and independent review (`provenance-and-licensing.md`).

### IC-800 Reference data
| Code | Rule | Severity |
|---|---|---|
| IC-801 | Anatomy: ids unique; parent exists; level equals parent level plus one; L1 has no parent; levels 1 to 4; no cycles | error |
| IC-802 | Anatomy: sibling sort values unique within a parent | error |
| IC-803 | Anatomy: `fullBody` is the only non-anatomical node, is an L1 node and has no children (ADR-0010, approved) | error |
| IC-804 | Anatomy: the 19 preserved ids are present at the planned levels and with the planned parents | error |
| IC-805 | Patterns: families have no parent; patterns have a family parent; no cycles | error |
| IC-806 | Equipment: the 21 existing ids are present and unchanged | error |
| IC-807 | Definitions, inclusion and exclusion text present for every anatomy node and pattern | error |
| IC-808 | An id from the previous release is removed from a list (retire it instead), or its parent or level changed | error |
| IC-809 | Labels unique within a list and locale | warning |
| IC-810 | Every node has `lifecycle` `active` or `retired`; every reference id appears exactly once in `reference/ledger.json`; a retired id has `retiredIn` and a reason; an id never returns to `active` | error |
| IC-811 | `coverage.json` references resolve: group nodes, slot patterns, discriminator nodes (level 2 or 3 only), attributes and classes; every slot minimum equals its counted entries; no active slot depends on a retired id | error |

### IC-900 References from user data and history (retired exercises)
This is the check that protects history. Exercise references in user data have no foreign key to `exercises`, so the database cannot enforce them. IC-900 covers **every column that holds an exercise id** (F09). The list below is from `app/lib/data/db/tables.dart` (schema 7) plus the user tables stage 3 adds:

| Table and column | Holds | Check |
|---|---|---|
| `session_sets.exercise_id` | Recorded sets | IC-901 |
| `session_exercises.exercise_id` | An exercise within a session (WP 9, schema v7) | IC-901 |
| `plan_exercises.exercise_id` | Planned exercises | IC-902 |
| `exercises.copied_from_id` | Source of a custom copy | IC-903 |
| user exercise relationships (stage 3 table, both ends) | Relationships stored by users | IC-905 |
| user exercise state (stage 3 table: favourites and per-exercise state) | Favourites and similar | IC-902 |
| `legacy_quarantine.original_json` | Exercise ids inside quarantined rows | IC-907 (information only) |

Not exercise-id holders today: `scheduled_workouts` (holds `plan_id` and `session_id`) and `split_days` (holds `plan_id`); they reach exercises through plans and sessions, which IC-902 and IC-901 cover. `tables.dart` has no exercise favourite column (`favourite` is on recipes), so exercise favourites arrive with the stage 3 user-state table.

| Code | Rule | Severity |
|---|---|---|
| IC-901 | Every `exercise_id` in `session_sets` and `session_exercises` resolves to a row in `exercises`, **including retired rows** | error (CI on fixtures and golden backups); reported, not repaired, in the app |
| IC-902 | Every `exercise_id` in `plan_exercises` and in user exercise state resolves to a row, **including retired rows** | as above |
| IC-903 | Every `copied_from_id` resolves | as above |
| IC-904 | No row in `exercises` with `source = system` is ever deleted (retired rows keep `retired_at`) | error |
| IC-905 | Relationships stored by users reference existing rows (both ends) | as above |
| IC-906 | After applying a release, the count of rows is at least the count before (nothing deleted) | error |
| IC-907 | Exercise ids found inside `legacy_quarantine.original_json` that do not resolve | info (reported in the migration report, never repaired) |

The app runs IC-901 to IC-905 at startup and after restore. It reports unresolved references to the user in Settings › Data. It never deletes or rewrites them.

### IC-950 Coverage
Computed per `coverage-matrix.md` from `reference/coverage.json`: slots, totals, mechanics, laterality, equipment classes, variation families, difficulty, diversity caps and primaries per exercise. These produce the gap report. They are `info` while a tranche is `planned` or `inProgress` and `error` when the tranche is `complete` (see section 5).

## 3. Integrity report format
One report per release, produced by the tool in two forms: JSON (for CI and the in-app data screen) and Markdown (for people). Deterministic: same input, same output.

```json
{
  "schema": "repforge.integrityReport/1",
  "catalogue": { "provider": "repforge", "release": 3, "contentHash": "sha256:...", "exercises": 0, "retired": 0 },
  "referenceData": { "anatomyNodes": 126, "patterns": 79, "equipment": 33 },
  "summary": { "errors": 0, "warnings": 0, "infos": 0, "tranches": { "5.1": "inProgress" } },
  "checks": [ { "code": "IC-501", "severity": "error", "status": "passed", "count": 0 } ],
  "findings": [
    { "code": "IC-602", "severity": "warning", "exerciseId": "lib-...", "field": "signature",
      "message": "Close match with lib-... (score 0.93)", "related": ["lib-..."], "disposition": null }
  ],
  "duplicates": { "pairs": [ { "a": "lib-...", "b": "lib-...", "score": 0.93, "cleared": false } ] },
  "relationships": { "families": 0, "maxDepth": 0, "longestProgression": 0, "cycles": 0 },
  "retirements": [ { "id": "lib-...", "reason": "...", "replacedBy": null } ],
  "coverage": { "report": "coverage-report.json" }
}
```
The Markdown form lists: header; summary table; errors; warnings by code with exercise ids; duplicate pairs; retirements; link to the coverage report. `referenceData` counts the anatomy nodes (126), the movement patterns including families (79) and the equipment ids (33) of this proposal.

## 4. Migration and legacy report
Owner decision 7 of 2026-11-05: legacy invalid values are never silently corrected. The original is preserved, the operational value is cleared or kept according to field meaning, records and relationships are preserved, and **a report identifies every affected record**. Stage 3 builds the report; this is its specification.

### 4.1 What it covers
- Rows moved to `legacy_quarantine` by the v6 migration (TD-41).
- Muscle values that cannot map to an anatomy node in the v8 migration.
- Out-of-range exertion values (TRN-020: integer 0 to 5) found in `session_sets`.
- Any value the v8 migration, a backup restore or an integrity check cannot map or accept.
- References that do not resolve (IC-901 to IC-905).
- Custom copies whose system source was revised (marker "source updated").
- Plans that reference exercises retired by a release.
- **Skipped duplicate secondaries (F10).** A user exercise whose secondary muscle list repeats a muscle, or repeats its primary, keeps one entry (IC-302 and IC-305 hold for stored data); each skipped entry is a row with action `skipped`.
- **Records rejected by the new rules (F10).** Any record the v8 schema or a check refuses (for example an empty primary muscle, an unknown muscle id, an over-long name) is a row with action `rejected` or `quarantined` and the rule that applied; the record itself is preserved.
- **User exercises with `fullBody` as a secondary muscle (F08).** The stored value is **preserved** (IC-304 is a warning for user content, an error only for system content), the exercise keeps working, and one row per exercise is listed with action `retained` and rule `ADR-0010`. Because the owner decided that `fullBody` may not be a secondary (ADR-0010), the migration offers the same rows to the user as a worklist; nothing is changed without the user.
- The same rule lists the system exercise `lib-skipping`: its stored `fullBody` secondary is preserved historically and reported, and the release-2 system record no longer carries it as an active tag.

### 4.2 Content: one row per affected record, never a sample or a total only
| Field | Meaning |
|---|---|
| `reportId`, `generatedAt`, `appVersion` | Identifies the run |
| `trigger` | `migration` (with from and to schema versions), `restore`, `integrityCheck`, or `catalogueUpdate` |
| `table`, `recordId` | The affected record |
| `exerciseId` | If one applies |
| `field` | The affected column or attribute |
| `originalValue` | Value as stored before (text) |
| `action` | `quarantined`, `cleared`, `retained`, `mapped`, `markerAdded`, `skipped`, `rejected`, `none` |
| `resultingValue` | Value now used operationally (may be empty) |
| `rule` | The decision or code that applied (for example `WP8-D3`, `TRN-020`, `IC-901`, `ADR-0010`) |
| `reason` | One plain sentence |
| `quarantineId` | Link to the quarantined original, if any |

Totals by action and by rule head the report. The list is never truncated.

### 4.3 Where it appears
- **Settings › Data**: a paged, searchable list; each row opens the record where possible.
- **Backup**: included in the backup file and restored with it.
- **Export**: copyable as CSV or JSON.
- The report persists until the user acknowledges each row; acknowledgement does not delete the original.

### 4.4 Tests
Table-driven migration tests (v1 to v7 to v8) assert: the number of report rows equals the number of affected records found independently in the fixture; every quarantined original is present in the report; every skipped duplicate and every `fullBody` secondary is listed; nothing is dropped; a crash and re-run produce no duplicate rows; the backup round trip preserves the report.

## 5. CI gating rules
1. **Run:** on every pull request and on main, integrity and coverage over every shipped catalogue release, in addition to the unit tests of the check code (hierarchy, targets, relationships, duplicates, report).
2. **Fail the build** on any error (IC codes marked error). Warnings do not fail the build.
3. **Warning budget:** the accepted-gaps file (below) records accepted warnings and coverage gaps. A new, unlisted warning is shown in the pull request summary. The tranche cannot be marked `complete` while any warning of types IC-411, IC-412, IC-601 and IC-602 is uncleared.
4. **Tranche status:** each tranche in the release metadata is `planned`, `inProgress` or `complete`. For a `complete` tranche the coverage dimensions and IC-210 are errors. For `planned` and `inProgress` they are info.
5. **Reproducibility:** the report is deterministic and contains the content hash. The same release gives the same report.
6. **Artefacts:** the JSON and Markdown reports and the coverage report are published as build artefacts and attached to the delivery record at each release.
7. **Retirement guard:** IC-110 fails the build when a release omits an id that is not listed under `retirements`.
8. **Reference data guard:** IC-801 to IC-811 fail the build on any reference-data change that removes or moves an id or breaks the ledger.
9. **Order of checks:** schema and enums first, then references, then graph, then names, then duplicates, then content, then coverage. The report lists every finding even after the first error.
10. **No network, no randomness, no clock** in the checks. The report timestamp is the only variable value and is excluded from the hash.

### 5.1 Accepted-gaps file format (F24)
One file in the repository, `docs/catalogue/accepted-gaps.json` once stage 3 creates it (this document is the format; no file is created now). It records warnings with a disposition and coverage gaps accepted by the owner. It never silences an error.

```json
{
  "schema": "repforge.acceptedGaps/1",
  "provider": "repforge",
  "accepted": [
    { "id": "AG-0001", "kind": "warning", "code": "IC-311", "exerciseId": "lib-thruster",
      "reason": "Category fullBody with a lower-body compound pattern, accepted as the pattern guide says.",
      "acceptedBy": "owner", "acceptedOn": "2026-11-05", "reference": "D04 section 7", "untilRelease": null },
    { "id": "AG-0002", "kind": "duplicate", "pair": ["lib-hack-squat", "lib-leg-press"], "decision": "distinct",
      "reason": "Different machines and load paths.", "acceptedBy": "reviewer-initials", "acceptedOn": "2026-11-05", "reference": "review log 5.5" },
    { "id": "AG-0003", "kind": "coverageGap", "group": "neck", "dimension": "slot", "item": "neck.rotation",
      "acceptedMinimum": 0, "reason": "Example only: a future owner-accepted gap.", "acceptedBy": "owner", "acceptedOn": "2026-11-05", "reference": "delivery record" }
  ]
}
```
Rules: `kind` is `warning`, `duplicate` or `coverageGap`; a `coverageGap` entry needs the owner as `acceptedBy`; entries match by exact subject (code and exercise id, pair, or group, dimension and item); an entry that no longer matches anything is reported as info ("stale") and removed in the next release; `untilRelease` is optional and, when set, makes the entry expire.

## 6. Results on the release-2 seed (scratchpad run, approved classifications)
A throwaway script applied the checks of IC-200 to IC-500 and IC-600 to the approved mapping (`mapping-existing.json`: 89 exercises, with the three alias removals and the alias additions). Results:

**Errors: 0. Release 2 passes the error checks.** Warnings: 93. Infos: 16.

| Code | Severity | Count | Disposition proposed |
|---|---|---|---|
| IC-210 | warning | 89 | Instructions are written in the tranches; release 2 is not a complete tranche |
| IC-207 | info | 16 | Cardio and mobility mechanics are empty (approved) |
| IC-311 | warning | 2 | `lib-kettlebell-swing` and `lib-thruster` (category fullBody, pattern family lower-body compound): accepted, as the pattern guide says |
| IC-508 | warning | 2 | Machine hip abduction and adduction; Push-up and Pull-up: distinct exercises |
| IC-304 | error | 0 | None: `lib-skipping` no longer carries `fullBody` as an active tag; the stored value is in the migration report |

Before the fix, the three alias collisions (*Pullup*, *Chinup*, *Farmers walk*) would have raised IC-502 and IC-503 errors; they are removed in the proposal (`mapping-existing.md` section 7). No other collision exists after `norm` and `squash`.

### 6.1 Near-duplicate pairs after the signature fix (IC-600)
Seed-wide: 89 exercises, 3,916 pairs. Flagged: IC-601 0; IC-602 4; IC-603 7; IC-411 0; IC-412 16. *Amended 2026-11-06 (owner, X2): the default rule gives IC-412 19 pairs, 16 plus 3 attribute-only pairs; see `docs/delivery-record/WP8.md`. Full update in stage 3c.*

**IC-601 probable duplicates:** none.

**IC-602 close matches:**
| Exercise A | Exercise B | Score | Disposition |
|---|---|---|---|
| `lib-back-squat` (Barbell back squat) | `lib-front-squat` (Barbell front squat) | 0.925 | Relationship: `lib-front-squat` is a `variationOf` the back squat (bar position). Cleared by a relationship at the first enrichment. |
| `lib-run-400m` (400 m run) | `lib-outdoor-run` (Outdoor run) | 0.888 | Probable merge or relationship: same structure, distance logging, no equipment. Owner decides: keep `lib-run-400m` as a distinct distance entry (`variationOf` the outdoor run) or merge. |
| `lib-hack-squat` (Hack squat) | `lib-leg-press` (Leg press) | 0.850 | Distinct: different machines and load paths. Disposition `distinct`. |
| `lib-bulgarian-split-squat` (Bulgarian split squat) | `lib-step-up` (Dumbbell step-up) | 0.850 | Distinct: rear-foot-elevated split squat versus step. Disposition `distinct` (the equipment support items are ignored, so the equipment terms match). |

**IC-603 similar (info):**
| Exercise A | Exercise B | Score | Note |
|---|---|---|---|
| `lib-back-squat` (Barbell back squat) | `lib-thruster` (Barbell thruster) | 0.838 | Distinct (info). |
| `lib-front-squat` (Barbell front squat) | `lib-thruster` (Barbell thruster) | 0.838 | Distinct (info). |
| `lib-walking-lunge` (Dumbbell walking lunge) | `lib-step-up` (Dumbbell step-up) | 0.830 | Distinct (info). |
| `lib-walking-lunge` (Dumbbell walking lunge) | `lib-bulgarian-split-squat` (Bulgarian split squat) | 0.800 | Distinct (info). |
| `lib-bodyweight-squat` (Bodyweight squat) | `lib-wall-sit` (Wall sit) | 0.800 | Distinct: dynamic versus isometric (info). |
| `lib-plank` (Plank) | `lib-ab-wheel` (Ab wheel rollout) | 0.800 | Distinct (info). |
| `lib-romanian-deadlift` (Romanian deadlift) | `lib-dumbbell-rdl` (Dumbbell Romanian deadlift) | 0.750 | Relationship: `lib-dumbbell-rdl` is a `variationOf` the Romanian deadlift (also listed under IC-412). |

**Pairs distinguished by recorded attributes** (cleared from IC-601 to IC-603, which they would otherwise have triggered; where the rest of the signature matches they appear below under IC-412 instead): `lib-leg-curl` and `lib-lying-leg-curl` (body position seated and lying); `lib-bench-press` and `lib-incline-bench-press`, `lib-db-bench-press` and `lib-incline-db-press` (angle); `lib-deadlift` and `lib-sumo-deadlift` (stance); `lib-db-curl` and `lib-hammer-curl` (grip); `lib-pull-up` and `lib-chin-up` (grip). Corrected from the first draft: `lib-treadmill-run` and `lib-outdoor-run` are not a close pair any more (they differ in equipment, logging type and name); the real structural pair is `lib-run-400m` and `lib-outdoor-run`.

**IC-412 probable variations without a family link (16 pairs).** This is the family-link worklist for the tranche releases, not a defect of release 2 (the seed has no relationships). Pairs separated only by recorded attributes are included:

*Amended 2026-11-06 (owner, X2): the narrow rule flags 19 pairs, the 16 below plus 3 attribute-only pairs listed in `docs/delivery-record/WP8.md`. Full specification update in stage 3c.*
- `lib-bench-press` and `lib-incline-bench-press` (0.963)
- `lib-leg-curl` and `lib-lying-leg-curl` (0.925)
- `lib-db-bench-press` and `lib-incline-db-press` (0.925)
- `lib-romanian-deadlift` and `lib-dumbbell-rdl` (0.750)
- `lib-assisted-pull-up` and `lib-band-assisted-pull-up` (0.740)
- `lib-bench-press` and `lib-db-bench-press` (0.725)
- `lib-cable-fly` and `lib-db-fly` (0.725)
- `lib-barbell-curl` and `lib-db-curl` (0.725)
- `lib-barbell-curl` and `lib-cable-curl` (0.725)
- `lib-db-curl` and `lib-cable-curl` (0.725)
- `lib-plank` and `lib-weighted-plank` (0.725)
- `lib-db-bench-press` and `lib-incline-bench-press` (0.710)
- `lib-incline-bench-press` and `lib-incline-db-press` (0.710)
- `lib-pull-up` and `lib-assisted-pull-up` (0.675)
- `lib-pull-up` and `lib-band-assisted-pull-up` (0.675)
- `lib-cable-crunch` and `lib-crunch` (0.675)

**IC-411:** no unilateral entry in the seed has a bilateral twin by structure.

## 7. Owner decisions (2026-11-05)
1. Duplicate score thresholds (0.95, 0.85, informational from 0.75) and weights are approved as the starting point; the pilot tunes them. Signature flags stay non-blocking (ADR-0009) but must be cleared at tranche acceptance.
2. Mechanics for cardio and mobility are empty; IC-207 does not check them.
3. IC-304 is an error for system content; a warning with a migration-report entry for user content.
4. The seven optional attributes are approved; the pattern-level fallback is not used.
5. The blocked words and phrases list is held with the tool and reviewed by the owner.
