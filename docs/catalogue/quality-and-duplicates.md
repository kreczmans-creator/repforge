# Catalogue quality and duplicate-detection specification — proposed

- Status: **Proposed — for owner approval.** WP 8 stage 4 (documentation only). The checks are implemented in stage 3a and 3c as pure domain code and a CI gate; this document is the specification.
- Requirements: LIB-007, LIB-012, LIB-013; ADR-0009 decisions 5 and 6; `docs/wp8-delivery-plan.md` sections 10, 17.5 and 18.
- Related: `editorial-guide.md`, `coverage-matrix.md`, `population-standards.md`.

## 1. Scope and structure
The checks run on three inputs: (1) a **catalogue release** (the bundled JSON, before it is applied), (2) the **reference data** (anatomy, patterns, equipment), and (3) the **database** (references from user data to exercises). Each check has a code, a severity and a rule.

Severities:
- **error**: fails the build for system content. The release is not applied.
- **warning**: reported. Must have a recorded disposition before a tranche is accepted. Does not fail the build.
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
| IC-110 | Every id in the previous release is present in this release or listed under `retirements` (prevents accidental retirement) | error |
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
| IC-207 | mechanics | Present for categories push, pull, legs, core, fullBody; for cardio and mobility see the owner decision | error / info |
| IC-208 | laterality | Present | error |
| IC-209 | difficulty | Present | error |
| IC-210 | content | The four sections present and non-empty (`setup`, `execution`, `breathing`, `commonMistakes`) | error once the exercise's tranche is complete; warning before |
| IC-211 | aliases | List present; empty list is a warning | warning |
| IC-212 | provenance | `providerId` registered; author recorded | error |

### IC-300 Reference validity
| Code | Rule | Severity |
|---|---|---|
| IC-301 | Each target node exists in the anatomy list | error |
| IC-302 | A node appears once per exercise | error |
| IC-303 | No exercise tags a node together with its ancestor or descendant | error |
| IC-304 | `fullBody` appears only as a primary target; never as secondary | error |
| IC-305 | A primary node is not repeated as secondary | error |
| IC-306 | Each pattern exists; a family id is not used as a pattern (only leaf patterns) | error |
| IC-307 | Each equipment id exists in the equipment list | error |
| IC-308 | Enum values valid (mechanics, laterality, difficulty, relationship kinds, content sections) | error |
| IC-309 | Target and pattern ordinals are contiguous from 0 | error |
| IC-310 | Primary targets above 3 or secondary targets above 6 | warning |
| IC-311 | Category and pattern family not in the compatibility table (`movement-patterns.md`, section 3) | warning |
| IC-312 | Logging type unusual for the pattern (for example `cardio` logging with a strength pattern) | warning |
| IC-313 | An active exercise references a retired exercise, node, pattern or equipment id | error |
| IC-314 | A target whose mapped node is non-anatomical used with a category other than cardio, fullBody or mobility | warning |

### IC-400 Relationship graph
| Code | Rule | Severity |
|---|---|---|
| IC-401 | No self-reference | error |
| IC-402 | Both ends exist and are active in the release | error |
| IC-403 | No duplicate (same from, to, kind) | error |
| IC-404 | No inverse duplicate: `progressionOf` and `regressionOf` do not describe the same pair both ways; symmetric kinds are stored once with ids in alphabetical order (`from` before `to`) | error |
| IC-405 | `variationOf`: at most one per exercise; the graph is a forest (no cycles); the target is a family root (has no `variationOf`) | error |
| IC-406 | `variationOf` depth above 2 | warning |
| IC-407 | `progressionOf` and `regressionOf` together form an acyclic graph (depth-first search over the union, direction normalised) | error |
| IC-408 | `unilateralCounterpartOf` joins one bilateral entry and one unilateral or alternating entry | error |
| IC-409 | `alternativeTo` between two members of one `variationOf` family | warning |
| IC-410 | `variationOf` pair has different primary patterns and disjoint primary targets (probably not the same movement) | warning |
| IC-411 | A unilateral entry with a bilateral twin by structural signature and no `unilateralCounterpartOf` | warning (error at tranche acceptance) |
| IC-412 | A derived entry by signature (differs only in equipment, grip, stance or angle) with no family link | warning |
| IC-413 | Relationship to a retired exercise from an active system exercise | error |
| IC-414 | An exercise is not progression of one entry and regression of the same entry through a chain longer than 6 steps | warning |

### IC-500 Names and aliases
Normalisation function `norm(text)`: Unicode NFKD; remove combining marks; lower-case; replace hyphens, dashes, slashes and underscores with a space; delete apostrophes; delete other punctuation; collapse spaces; trim. `squash(text)` is `norm(text)` with all spaces removed.

| Code | Rule | Severity |
|---|---|---|
| IC-501 | `norm(name)` is unique across exercises in the release | error |
| IC-502 | `squash(name)` is unique (catches "push up", "push-up" and "pushup") | error |
| IC-503 | No alias equals (after `norm` or `squash`) any other exercise's name or alias | error |
| IC-504 | No alias equals its own exercise's name | error |
| IC-505 | More than six aliases, or an alias longer than 60 characters | warning |
| IC-506 | Name or alias contains a blocked word (brand, "best", "ultimate", medical terms) from the blocklist | warning |
| IC-507 | Name not in sentence case, or contains US spellings from the UK/US list ("color", "center", "program", "gray") | warning |
| IC-508 | Names within Levenshtein distance 2 on `norm` | warning |
| IC-509 | A name matches a known UK/US synonym pair of another name (for example press-up and push-up; jump rope and skipping; elliptical and cross-trainer) | warning |

Cross-source collisions (user and imported exercises against system names) are reported in the app and never block a user.

### IC-600 Structural near-duplicates
**Signature:** (set of primary target nodes lifted to their L3 ancestor, primary pattern, set of equipment ids, laterality, mechanics).

**Score between two exercises:**
```
score = 0.35 * Jaccard(primary L3 nodes)
      + 0.25 * (same primary pattern ? 1 : 0)
      + 0.25 * Jaccard(equipment ids; two empty sets count as 1)
      + 0.075 * (same laterality ? 1 : 0)
      + 0.075 * (same mechanics ? 1 : 0)
```
| Code | Rule | Severity |
|---|---|---|
| IC-601 | Identical signature (score 1.00) between two exercises | warning: "probable duplicate" |
| IC-602 | Score from 0.90 up to but not including 1.00 | warning: "close match" |
| IC-603 | Score from 0.75 up to but not including 0.90, and the pair shares a primary pattern | info: "similar" |

A pair is **cleared** when (a) the two exercises are linked by any relationship kind, or (b) a disposition is recorded in the release file under `duplicateReview` (pair, decision `distinct` | `merge` | `relationship`, reason, reviewer). Uncleared IC-601 or IC-602 pairs are reported and must be cleared before the tranche is accepted. They do not fail the build (ADR-0009). The thresholds are proposals; the pilot tranche tunes them.

Known structural pairs in the current seed: `lib-treadmill-run` and `lib-outdoor-run`; `lib-leg-curl` and `lib-lying-leg-curl` (body position).

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
| IC-803 | Anatomy: `fullBody` is the only non-anatomical node and has no children | error |
| IC-804 | Anatomy: the 19 preserved ids are present at the planned levels and with the planned parents | error |
| IC-805 | Patterns: families have no parent; patterns have a family parent; no cycles | error |
| IC-806 | Equipment: the 21 existing ids are present and unchanged | error |
| IC-807 | Definitions, inclusion and exclusion text present for every anatomy node and pattern | error |
| IC-808 | An id from the previous release is removed, or its parent or level changed | error |
| IC-809 | Labels unique within a list and locale | warning |

### IC-900 References from user data and history (retired exercises)
This is the check that protects history. Sets and plan exercises reference exercises without a foreign key, so the database cannot enforce it.

| Code | Rule | Severity |
|---|---|---|
| IC-901 | Every `exercise_id` in the recorded sets resolves to a row in `exercises`, **including retired rows** | error (CI on fixtures and golden backups); reported, not repaired, in the app |
| IC-902 | Every `exercise_id` in plan exercises, schedules and favourites resolves to a row, **including retired rows** | as above |
| IC-903 | Every `copiedFromId` resolves | as above |
| IC-904 | No row in `exercises` with `source = system` is ever deleted (retired rows keep `retired_at`) | error |
| IC-905 | Relationships stored by users reference existing rows | as above |
| IC-906 | After applying a release, the count of rows is at least the count before (nothing deleted) | error |

The app runs IC-901 to IC-905 at startup and after restore. It reports unresolved references to the user in Settings › Data. It never deletes or rewrites them.

### IC-950 Coverage
Computed per `coverage-matrix.md`: totals, sub-targets, mechanics, laterality, patterns, equipment classes, difficulty, variation depth and diversity. These produce the gap report. They are `info` while a tranche is `planned` or `inProgress` and `error` when the tranche is `complete` (see section 5).

## 3. Integrity report format
One report per release, produced by the tool in two forms: JSON (for CI and the in-app data screen) and Markdown (for people). Deterministic: same input, same output.

```json
{
  "schema": "repforge.integrityReport/1",
  "catalogue": { "provider": "repforge", "release": 3, "contentHash": "sha256:...", "exercises": 0, "retired": 0 },
  "referenceData": { "anatomyNodes": 133, "patterns": 61, "equipment": 31 },
  "summary": { "errors": 0, "warnings": 0, "infos": 0, "tranches": { "5.1": "inProgress" } },
  "checks": [ { "code": "IC-501", "severity": "error", "status": "passed", "count": 0 } ],
  "findings": [
    { "code": "IC-602", "severity": "warning", "exerciseId": "lib-...", "field": "signature",
      "message": "Close match with lib-... (score 0.93)", "related": ["lib-..."], "disposition": null }
  ],
  "duplicates": { "pairs": [ { "a": "lib-...", "b": "lib-...", "score": 0.93, "cleared": false } ] },
  "relationships": { "families": 0, "maxDepth": 0, "cycles": 0 },
  "retirements": [ { "id": "lib-...", "reason": "...", "replacedBy": null } ],
  "coverage": { "report": "coverage-report.json" }
}
```
The Markdown form lists: header; summary table; errors; warnings by code with exercise ids; duplicate pairs; retirements; link to the coverage report.

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

### 4.2 Content: one row per affected record, never a sample or a total only
| Field | Meaning |
|---|---|
| `reportId`, `generatedAt`, `appVersion` | Identifies the run |
| `trigger` | `migration` (with from and to schema versions), `restore`, `integrityCheck`, or `catalogueUpdate` |
| `table`, `recordId` | The affected record |
| `exerciseId` | If one applies |
| `field` | The affected column or attribute |
| `originalValue` | Value as stored before (text) |
| `action` | `quarantined`, `cleared`, `retained`, `mapped`, `markerAdded`, `none` |
| `resultingValue` | Value now used operationally (may be empty) |
| `rule` | The decision or code that applied (for example `WP8-D3`, `TRN-020`, `IC-901`) |
| `reason` | One plain sentence |
| `quarantineId` | Link to the quarantined original, if any |

Totals by action and by rule head the report. The list is never truncated.

### 4.3 Where it appears
- **Settings › Data**: a paged, searchable list; each row opens the record where possible.
- **Backup**: included in the backup file and restored with it.
- **Export**: copyable as CSV or JSON.
- The report persists until the user acknowledges each row; acknowledgement does not delete the original.

### 4.4 Tests
Table-driven migration tests (v1 to v7 to v8) assert: the number of report rows equals the number of affected records found independently in the fixture; every quarantined original is present in the report; nothing is dropped; a crash and re-run produce no duplicate rows; the backup round trip preserves the report.

## 5. CI gating rules
1. **Run:** on every pull request and on main, integrity and coverage over every shipped catalogue release, in addition to the unit tests of the check code (hierarchy, targets, relationships, duplicates, report).
2. **Fail the build** on any error (IC codes marked error). Warnings do not fail the build.
3. **Warning budget:** a file in the repository records accepted warnings by code and exercise id with the reason. A new, unlisted warning is shown in the pull request summary. The tranche cannot be marked `complete` while any warning of types IC-411, IC-412, IC-601 and IC-602 is uncleared.
4. **Tranche status:** each tranche in the release metadata is `planned`, `inProgress` or `complete`. For a `complete` tranche the coverage dimensions and IC-210 are errors. For `planned` and `inProgress` they are info.
5. **Reproducibility:** the report is deterministic and contains the content hash. The same release gives the same report.
6. **Artefacts:** the JSON and Markdown reports and the coverage report are published as build artefacts and attached to the delivery record at each release.
7. **Retirement guard:** IC-110 fails the build when a release omits an id that is not listed under `retirements`.
8. **Reference data guard:** IC-801 to IC-808 fail the build on any reference-data change that removes or moves an id.
9. **Order of checks:** schema and enums first, then references, then graph, then names, then duplicates, then content, then coverage. The report lists every finding even after the first error.
10. **No network, no randomness, no clock** in the checks. The report timestamp is the only variable value and is excluded from the hash.

## 6. Open questions for the owner
1. Confirm the duplicate score thresholds (0.90 and 0.75) as a starting point to tune in the pilot tranche.
2. Confirm that signature flags stay non-blocking (ADR-0009) but must be cleared at tranche acceptance.
3. Confirm mechanics rules for cardio and mobility (IC-207).
4. Confirm the blocked words and phrases list (a short list is held with the tool and reviewed by the owner).
