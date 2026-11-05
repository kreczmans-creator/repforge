# WP 8 — Revised delivery plan (expanded exercise library)

- Status: **Structure, scope and architectural direction approved (2026-11-05). Stage 4 authorised (documentation and reference data only). Stage 3 implementation gated** (§18). WP 8 is the active work package; no WP 16 implementation exists or is authorised.
- History: drafted as the WP 16a plan (2026-11-05), re-scoped the same day into WP 8 by owner decision (D04 §7); technical design unchanged; revised with OQ-19/OQ-21 decisions and the owner's technical qualifications (§17).
- Date: 2026-11-05
- Governance: owner decision of 2026-11-05 — the expanded exercise library is delivered **within WP 8**, which stays the active work package. WP 8 is not created as a delivery package. WP 9 is unchanged.
- Requirements: D04 TRN-001..012 (original), LIB-001..LIB-014 and the owner's library decisions (D04 §7; `docs/exercise-library-expansion.md`).
- ADRs: ADR-0008 (domain model), ADR-0009 (catalogue provenance and updates) — direction accepted 2026-11-05; implementation gated.

## 0. WP 8 at a glance
| Category | Content |
|---|---|
| **Implemented and verified** | Stage 1 (6d401e6): taxonomy enums, exercise aliases, supplied flag, copy, set types incl. timed load and cardio energy, rep ranges, splits, validation rules, `RecordSet`, library and history queries, schema v6 with CHECK constraints and legacy quarantine, 89-exercise seed import. Stage 2 (058d433): Train tab library, search, filters, detail with history, custom exercise editor, copy-on-edit. Review fixes (b1ab45a): strict loads, set writes via `RecordSet`, TRN-020 exertion, legacy taxonomy mapping, bodyweight-only filter and others. Four workflows green on each commit; independent review and re-verification recorded in the WP 8 record |
| **Original acceptance criteria (D06)** | A set of each type stored and read back with correct fields; invalid combinations rejected at use-case level; unit tests; schema migration test — **met with evidence** (WP 8 record), not yet accepted |
| **Newly approved expanded requirements** | LIB-001..LIB-014 and decisions 1–10 (D04 §7, 2026-11-05) |
| **Remaining implementation work** | Stages 3–6 below; media workstream deferred |
| **Final WP 8 acceptance criteria** | §15 |

The 89-exercise implementation is the foundation. It does **not** satisfy the expanded requirements (gap analysis: `docs/exercise-library-expansion.md` §2).

## 0.1 Remaining stages
| Stage | Content (workstream) | Can start | Gate |
|---|---|---|---|
| 3 | Architecture and reference data (§1–§14 below) — sub-stages 3a domain model, 3b schema v8 and migration, 3c catalogue format and reconciler, 3d adapt WP 8/9 code | after WP 9 delivery (shared code) and owner authorisation | tests, independent review per sub-stage, four workflows |
| 4 | Catalogue tooling and quality assurance: editorial guide (naming, variation rules, instruction style, anatomical tagging), licence register, integrity checks and coverage report in CI, **coverage matrix with regional minimums (OQ-23)**, **anatomy node and movement pattern lists (OQ-22)** | documents and lists now (no code overlap with WP 9); CI tooling after stage 3c | owner approval of matrix and lists before stage 5 |
| 5 | Anatomical catalogue population in tranches: 5.1 chest, 5.2 back, 5.3 shoulders, 5.4 arms, 5.5 hips and legs, 5.6 trunk, 5.7 conditioning and mobility | after stages 3 and 4 | per tranche: coverage minimums met, instructions for every exercise, zero integrity failures, gap report, owner content review |
| 6 | Search, discovery and exercise screens: filters by anatomy, equipment, pattern, mechanics, laterality, difficulty, logging type; sorting; favourites; relationship navigation; instructions; custom exercises with the new fields | after stage 3; parallel with stage 5 | widget and integration tests, accessibility, independent review |
| Media | Exercise media: data references only in stage 3; display, storage and licensing **deferred** and outside final WP 8 acceptance | — | — |
| Final | Combined independent review, remediation, full regression incl. WP 9, four workflows, delivery record | after stages 3–6 | owner acceptance |

Sections 1–14 detail **stage 3**.

## 1. Stage 3 objective and scope
Put the exercise library on an architecture that can carry a comprehensive catalogue, without adding catalogue content or new discovery screens.

In scope: Engineering Object model for exercises and reference data; four-level anatomy; multiple primary and secondary targets; movement pattern, mechanics, laterality, difficulty; five relationship kinds; instruction sections and media references (data only); providers and catalogue releases with an idempotent reconciler; source separation (system, user, imported); user state including favourites (data and use cases); duplicate detection and integrity report; schema v8 and migration; backup format; adapting WP 8 and WP 9 code to the new model with unchanged behaviour.

Out of scope: catalogue population beyond re-expressing the existing 89 exercises (WP 8 stage 5); new filters, sorting, favourites and variation screens (WP 8 stage 6); media display (the deferred media workstream); translation; exercise metrics, tempo, range of motion, execution guidance and recommendations (accommodated by the content model, not delivered); training programmes.

## 2. Preconditions and dependencies
| Item | Status | Effect |
|---|---|---|
| WP 9 delivered (schema v7) | in progress | WP 8 stage 3 starts after WP 9 delivery so the two do not change the same code |
| ADR-0008, ADR-0009 approved | proposed | required before implementation |
| This plan authorised | proposed | required before implementation |
| OQ-19 volume attribution with several primary targets | **approved 2026-11-05** | rule in §8 |
| OQ-21 definition of "imported" source | **approved 2026-11-05** | ADR-0009 §1 |
| OQ-22 anatomy node list and movement pattern list | open | WP 8 stage 3 ships the structure and a proposed list; owner approves the lists before WP 8 stage 5 |
| WP 8 decisions 1 (taxonomy) and acceptance | open | WP 8 stage 3 extends the 19 identifiers; it does not decide WP 8 acceptance |
| Schema numbering with WP 10 | coordination | WP 8 stage 3 takes v8 if it lands first; otherwise the next free version. No data dependency |

## 3. Domain model (Engineering Objects)
| Object | Identity | Source / provenance | Versioning | Key rules |
|---|---|---|---|---|
| Exercise | stable string id (existing ids kept; new system ids `lib-…`, user ids UUID) | `system` (provider id), `user`, `imported`; `copiedFromId` for custom copies | `revision` (system); `updatedAt` for all | name required; ≥ 1 primary target; logging type and category required; system exercises fully classified (integrity check) |
| Anatomy node | stable id | provider (`repforge`) | catalogue release | one parent except L1; level = parent level + 1; L1–L4; no cycles; `fullBody` is a non-anatomical L1 node (see §4) |
| Movement pattern | stable id | provider | release | hierarchical (family › pattern); no cycles |
| Equipment item | stable id (21 kept) | provider | release | — |
| Exercise target | (exercise, node) | follows exercise | with exercise | role primary/secondary; node once per exercise; ordered |
| Relationship | (from, to, kind) | system or user | with source | kinds per ADR-0008; directional stored once; symmetric normalised; no self; `variationOf` forest; progression/regression acyclic |
| Content section | (exercise, locale, kind, order) | provider | revision | locale `en-GB`; text length limits |
| Media reference | id | provider | revision | kind, locator, licence, attribution required |
| Provider | id | — | — | licence and attribution recorded |
| Catalogue release | (provider, release) | provider | immutable record | content hash; counts |
| User exercise state | exercise id | user | none | favourite, hidden, last used; never written by the reconciler |

Closed enums (owner-defined): mechanics `compound | isolation`; laterality `bilateral | unilateral | alternating`; difficulty `beginner | intermediate | advanced` (technical complexity, not load or fitness); relationship kinds; source kinds; content section kinds (domain list, stored as text); logging type and category unchanged.

## 4. Identifier preservation — the 19 WP 8 muscle identifiers
Each identifier becomes an anatomy node at its anatomically correct level. Stored values (`primary_muscle`, `secondary_muscles_json`) map one to one. New nodes are added around them (proposed list approved under OQ-22).

| WP 8 id | Level | Parent (proposed id) | Note |
|---|---|---|---|
| `chest` | L2 group | `regionChest` (L1) | L3 pectoralis major (L4 clavicular, sternocostal), pectoralis minor, serratus anterior |
| `frontDelts` | L4 head | `deltoid` (L3) › `shoulders` (L2) › `regionShoulder` (L1) | anterior deltoid |
| `sideDelts` | L4 head | `deltoid` | lateral deltoid |
| `rearDelts` | L4 head | `deltoid` | posterior deltoid |
| `triceps` | L3 muscle | `upperArmPosterior` (L2) › `regionArm` | L4 long, lateral, medial heads |
| `biceps` | L3 muscle | `upperArmAnterior` (L2) | L4 long, short heads; brachialis sibling |
| `forearms` | L2 group | `regionArm` | L3 wrist flexors, wrist extensors, brachioradialis |
| `upperBack` | L2 group | `regionBack` | L3 trapezius (L4 upper, middle, lower), rhomboids |
| `lats` | L2 group | `regionBack` | L3 latissimus dorsi, teres major |
| `lowerBack` | L2 group | `regionBack` | L3 erector spinae, quadratus lumborum |
| `abs` | L2 group | `regionTrunk` | L3 rectus abdominis, transversus abdominis |
| `obliques` | L2 group | `regionTrunk` | L3 external, internal oblique |
| `glutes` | L2 group | `regionHip` | L3 gluteus maximus, medius, minimus |
| `abductors` | L2 group | `regionHip` | L3 tensor fasciae latae (gluteus medius and minimus stay under `glutes`: one parent per node; functional groupings are not modelled — recorded limitation) |
| `adductors` | L2 group | `regionHip` | L3 adductor magnus, longus, brevis, gracilis, pectineus |
| `quadriceps` | L2 group | `regionThigh` | L3 rectus femoris, vastus lateralis, medialis, intermedius |
| `hamstrings` | L2 group | `regionThigh` | L3 biceps femoris (L4 long, short head), semitendinosus, semimembranosus |
| `calves` | L2 group | `regionLowerLeg` | L3 gastrocnemius (L4 medial, lateral head), soleus |
| `fullBody` | L1, non-anatomical | — | kept as an identifier for conditioning and whole-body work; flagged non-anatomical, has no children, excluded from anatomical coverage |

Further proposed nodes: rotator cuff (L2, shoulders), hip flexors (L2, hip), tibialis anterior (L2, lower leg), neck (L1). Filtering by any node includes its descendants; primary matches rank first (TRN-010(2) behaviour kept).

## 5. Schema v8 (proposed)
New tables:
- `anatomy_nodes(id PK, parent_id → anatomy_nodes, level 1–4, non_anatomical bool, sort_order, provider_id, release)`
- `movement_patterns(id PK, parent_id, sort_order, provider_id, release)`
- `equipment_items(id PK, sort_order, provider_id, release)` (21 existing ids)
- `reference_labels(kind, id, locale, label, PK(kind, id, locale))` — `en-GB` only
- `exercise_targets(exercise_id → exercises CASCADE, node_id → anatomy_nodes, role CHECK primary|secondary, ordinal, PK(exercise_id, node_id))`
- `exercise_patterns(exercise_id, pattern_id, ordinal, PK(exercise_id, pattern_id))`
- `exercise_relationships(from_id, to_id, kind CHECK in five kinds, source, created_at, PK(from_id, to_id, kind), CHECK from_id <> to_id)`
- `exercise_content(exercise_id, locale, section, ordinal, body CHECK length, provider_id, revision, PK(exercise_id, locale, section, ordinal))`
- `exercise_media(id PK, exercise_id, kind, locator, licence, attribution, provider_id, revision)`
- `exercise_names(exercise_id, locale, name, aliases_json, PK(exercise_id, locale))` — other locales only; `en-GB` stays on `exercises`
- `exercise_user_state(exercise_id PK, favourite bool, hidden bool, last_used_at)`
- `content_providers(id PK, name, licence, attribution, url)`
- `catalogue_releases(provider_id, release, applied_at, content_hash, inserted, updated, retired, PK(provider_id, release))`

`exercises` changes: add `source` (CHECK system|user|imported), `provider_id`, `revision`, `mechanics`, `laterality`, `difficulty` (nullable; CHECK values), `retired_at`. Remove `primary_muscle`, `secondary_muscles_json`, `supplied` after their values are copied (targets; `source`).

**Proposed approach for the removed columns (architecture review point):** rebuild `exercises` once in v8 with drift `TableMigration` (foreign keys off, as v6 did), so there is one source of truth for targets. Alternative: keep the columns as frozen, unread values — rejected because two stores of the same fact drift apart.

## 6. Migration strategy (v7 → v8)
1. One transaction; foreign keys off during the rebuild, on afterwards; each step guarded so a crash and re-run complete without duplicates (v6/v7 discipline).
2. Create reference tables; insert the minimum reference rows needed for integrity from constants in the migration code: the 19 nodes (with `regionX` parents per §4), the 21 equipment items, provider `repforge`. The full proposed lists arrive with catalogue release 2 at startup.
3. Backfill `exercise_targets` from `primary_muscle` (primary, ordinal 0) and `secondary_muscles_json` (secondary, in order), skipping a secondary equal to the primary; backfill `source` from `supplied` (`system` with provider `repforge`, else `user`); `revision` = 1 for system rows.
4. Rebuild `exercises` without the three columns; verify row count and every retained column equal before and after (test).
5. Rows that cannot be mapped (an unknown muscle text left by the v6 legacy mapping, TD-41) keep their exercise row; the unmapped value goes to `legacy_quarantine` with a reason; no value is invented.
6. No stored set, plan, session, schedule or exercise identifier changes.
7. Release 1 of provider `repforge` is recorded as the existing seed; `seedExercisesVersion` is read once to decide whether release 1 was applied, then retired.

## 7. Catalogue release format 2 and reconciler
Per ADR-0009: bundled JSON per provider and release, holding reference data, exercises (`id`, `revision`, names, aliases, logging type, category, targets with roles, patterns, equipment, mechanics, laterality, difficulty, relationships, content sections by locale, media references) and provider metadata. Validation is all-or-nothing. The reconciler inserts, updates system-owned fields when the revision is higher, retires missing ids, and never writes user-owned data. Re-running a release is a no-op. WP 8 stage 3 ships release 2 = the 89 existing exercises re-expressed in the new format with targets and patterns; mechanics, laterality and difficulty are filled where defensible, instructions are not written yet (WP 8 stage 5).

## 8. Changes to WP 8 and WP 9 code (behaviour preserved)
- `Exercise`: `primaryMuscle`/`secondaryMuscles` → `targets`; `supplied` → `source`; new classification fields. Library queries filter by node with descendants; equipment filter unchanged; search unchanged.
- WP 8 screens: show primary targets where they showed the primary muscle; editor requires at least one primary target. No new discovery features (WP 8 stage 6).
- WP 9 volume per muscle group (TRN-027(3)), **OQ-19 approved 2026-11-05**: each primary muscle target receives the full recorded exercise-set count; secondary muscles are reported separately and excluded from primary totals; a set is attributed once per distinct primary target. These are **attributed set counts, not physiological measurements of muscle stimulus**; reports and documentation show the distinction (confirmed 2026-11-05). Where kg volume per muscle (TRN-027(3)) is shown, it is the kg volume of the attributed sets, labelled the same way. Session and exercise volume are unchanged.
- Custom copies: copy targets, patterns and content; source `user`.
- `TRN-010(1)` amended by owner decision (one or more primary targets); TRN-010(2) behaviour kept.

## 9. Backup
Backup `formatVersion` 3 with the new tables. Restore accepts 1, 2 and 3; files before 3 are mapped through the same backfill as the migration. Older apps refuse version 3 (the version check exists since WP 3).

## 10. Test strategy
- Domain unit tests: hierarchy validation (parent, level, cycles, L1 roots), target rules (≥ 1 primary, no node twice), relationship rules (self, duplicate, inverse duplicate, `variationOf` forest, progression/regression acyclicity, symmetric normalisation), enums, duplicate detection (normalised names, alias collisions, structural signature), integrity report.
- Repository tests for every new table, including descendant filtering and favourites.
- Migration tests: `SchemaVerifier` v1–v7 → v8; every v7 exercise, set, plan, session and schedule value compared before and after; crash re-run; quarantine of unmapped values; foreign-key check after migration.
- Reconciler tests: insert, update by revision, retire, idempotent re-run, all-or-nothing on an invalid release, user state and custom copies untouched, "source updated" marker, provider licence recorded.
- Backup tests: v1, v2, v3 restore; v3 round-trip of all new data.
- Regression: all WP 8 and WP 9 tests pass with the adapted model; WP 9 volume tests updated only for OQ-19.
- Architecture tests: domain has no Flutter imports; only the reconciler writes system catalogue fields; reference ids used through typed wrappers.
- CI: integrity report over the shipped catalogue as a gate; four workflows green; coverage ≥ 80 % hand-written.
- Independent review of each stage and of the final diff, with probe tests, as for WP 8 and WP 9.

## 11. Stage 3 acceptance criteria
1. ADR-0008 and ADR-0009 approved; implementation matches them.
2. Schema v8 migration from every earlier version preserves all exercise identifiers, the 19 muscle identifiers (as nodes) and all training data; tests prove value equality.
3. Exercises, anatomy nodes, patterns, equipment, relationships, content, media references, providers and releases meet the Engineering Object definition (identity, type, provenance, validation, timestamps, relationships, versioning, persistence, query, backup, restore).
4. Four-level anatomy with validation; exercises carry one or more primary and zero or more secondary targets.
5. Movement pattern, mechanics, laterality and difficulty (owner definitions) stored and validated.
6. Five relationship kinds validated: direction, no self-reference, no duplicates or inverse duplicates, no cycles where directional.
7. Content sections and media references stored per locale (`en-GB`), extensible without schema change.
8. Source separation system/user/imported; provider registry with licence; catalogue releases applied idempotently; user-owned data never overwritten (tests).
9. Duplicate detection and an integrity report generated in CI; zero integrity failures for release 2.
10. Favourites and other user state persisted and backed up (UI in WP 8 stage 6).
11. WP 8 and WP 9 behaviour unchanged except where an owner decision changes it (TRN-010(1), OQ-19); full suite, coverage gate and four workflows green.
12. Delivery record with tests, CI runs, independent review findings and resolutions, deviations and open items.

## 12. Stage 3 sub-stages and gates
| Stage | Content | Gate |
|---|---|---|
| 3a | Domain model, reference data structure, validation rules, duplicate detection, integrity report (pure code, no schema) | tests; independent review |
| 3b | Schema v8, migration, repositories, backup v3 | migration and backup tests; independent review |
| 3c | Catalogue format 2, reconciler, release 1→2 of the 89 exercises, CI integrity gate | reconciler tests; integrity report |
| 3d | Adapt WP 8/9 code and screens; OQ-19 rule | full regression, four workflows, emulator |
| Stage 3 close | combined independent review of stage 3, remediation, record update | owner review of stage 3 |

## 13. Risks
| Risk | Mitigation |
|---|---|
| Table rebuild of `exercises` loses data | v6-proven pattern; before/after equality tests; crash re-run test |
| Anatomy over-precision | qualitative roles only; tag at the most defensible level; editorial guide (WP 8 stage 4) |
| Refactor of WP 8/9 code introduces regressions | sub-stage 3d alone; full regression and emulator run |
| Reference list churn | lists approved (OQ-22) before WP 8 stage 5; identifiers never reused |
| Licence contamination | provider registry; no proprietary content; review in WP 8 stage 4 |
| Schema version clash with WP 10 | coordinate numbering at start |

## 14. Decisions requested to authorise stage 3
1. Approve ADR-0008 and ADR-0009.
2. Approve the identifier mapping in §4 and the `fullBody` treatment.
3. Approve the `exercises` table rebuild in v8 (§5), on the evidence plan in §17.1.
4. ~~OQ-19~~ approved 2026-11-05 (§8).
5. ~~OQ-21~~ approved 2026-11-05 (ADR-0009).
6. Confirm sequencing (§16).
7. Authorise implementation of stage 3.

## 15. Final WP 8 acceptance criteria
WP 8 is accepted when all of the following hold:
1. **Original D06 criteria** remain met (each set type stored and read back; invalid combinations rejected at use-case level; unit and migration tests) and TRN-001..TRN-012 hold, with TRN-010(1) as amended (one or more primary targets).
2. **Stage 3** criteria (§11) met: Engineering Object model, four-level anatomy, targets, classifications, relationships, content and media references, providers and releases, source separation, idempotent updates that never overwrite user data, duplicate detection and integrity report, schema v8 preserving all identifiers and data.
3. **Stage 4**: editorial guide, licence register, CI integrity and coverage reporting; coverage matrix minimums and reference lists approved by the owner.
4. **Stage 5** (starts only after OQ-22 lists and OQ-23 minimums are approved): every region's tranche meets the approved coverage matrix (anatomy, diversity, compound/isolation, unilateral/bilateral, patterns, equipment incl. free weights, machines, cables, Smith machine, bands, kettlebells and bodyweight, difficulty distribution, variation depth); instructions (setup, execution, breathing, common mistakes) for every system exercise; zero integrity failures; explicit gap report; owner content review per tranche. Raw count is not evidence.
5. **Stage 6**: search, filters, sorting, favourites, relationship navigation, instruction display and custom exercise creation (LIB-008, LIB-009) with widget and integration tests and accessibility as WP 8/9.
6. **Media**: data references only (LIB-010 readiness); display and storage deferred, outside acceptance.
6a. **Integrity**: an automated check proves every historical set and plan reference resolves to an existing exercise, retired exercises included; no exercise deleted, no identifier reused.
6b. **OQ-19 terminology** visible wherever per-muscle figures are reported.
7. **No regressions**: all WP 9 behaviour and tests pass; full suite, coverage gate (≥ 80 %), four workflows and the emulator run green on the final commit.
8. **Open WP 8 decisions** dispositioned by the owner: legacy-data policy and TRN-020 correction (WP 8 record), OQ-19, OQ-21, OQ-22, OQ-23.
9. Independent review of the final combined diff with findings resolved or accepted as debt; delivery record complete with exact commits and CI runs.

## 16. Dependencies and sequencing
- **WP 9** (unchanged scope, in progress): built on the WP 8 foundation (stages 1–2 and review fixes). WP 8 stage 3 code starts after WP 9 delivery, because stage 3d adapts code WP 9 uses; stage 4 documents and lists can proceed now.
- **WP 10**: depends on WP 3 and WP 4 only; not blocked; schema version numbers coordinated (v8 to whichever lands first).
- **WP 11**: depends on WP 5, WP 9, WP 10 as before; its training-volume-per-muscle reporting follows WP 8 stage 3 (soft dependency).
- Established roadmap order otherwise unchanged.

## 17. Owner technical qualifications (2026-11-05) and how the plan meets them
### 17.1 Table rebuild versus incremental migration
| Option | How | Integrity | Risk | Verdict |
|---|---|---|---|---|
| A. Rebuild `exercises` (drift `TableMigration`) | copy rows into the new shape inside one transaction; foreign keys off during the copy, as v6 did on the same table | one source of truth for targets and source; CHECKs on new columns apply to every row | proven on this table in v6; verified by `SchemaVerifier` | **proposed** |
| B1. Add columns, keep old ones and write both | `ALTER TABLE ADD COLUMN`; repository writes old and new | two stores of one fact; drift between them is possible | permanent dual-write code | rejected |
| B2. Add columns, keep old ones unread | as B1, old columns frozen | `primary_muscle` is NOT NULL, so new rows need a meaningless placeholder | misleading data in backups and exports | rejected |
| B3. `ALTER TABLE DROP COLUMN` | SQLite drops the three columns in place | as A | not modelled by drift's migration tooling; refused if a column is in an index or constraint; SQLite rewrites the table anyway | fallback only |
Supporting facts (verified in code): `session_sets.exercise_id` and `plan_exercises.exercise_id` have no foreign key to `exercises`, so a rebuild cannot cascade or break them; identifiers are copied unchanged. **Evidence before commitment:** sub-stage 3b starts with a spike that runs option A and option B3 on the same v7 fixture (including a large fixture, for example 5 000 exercises and 100 000 sets). It compares value equality, constraint enforcement, crash re-run and duration, and records the result in the WP 8 record before the migration is finalised.

### 17.2 Value equality across supported schema versions
For each supported starting version v1–v7 (generated schemas in `test/data/generated_migrations`), a table-driven harness seeds representative data, migrates to v8 and asserts: every retained column of every row is equal; old muscle and supplied values equal their mapped targets and source; row counts per table are equal; foreign-key check passes; nothing is invented (unmapped values go to `legacy_quarantine`). The same harness covers a crash before `user_version` is written (re-run completes without duplicates).

### 17.3 Backup and restore compatibility
Golden backup files of format 1 (v1–v5 era), format 2 (v7) and format 3 (v8) restore into v8 with the same backfill as the migration; format 3 round-trips every new table, the release log and user state; older apps refuse format 3 (version check present since WP 3, verified at b1ab45a).

### 17.4 User customisations never overwritten
The reconciler writes only system-owned fields of `system` exercises and system relationships, content, media and reference data. Test: snapshot (row hashes) of all user-owned data — user and imported exercises, custom copies, user relationships, user state, plans, sessions, sets, schedules — before and after applying, re-applying, updating and retiring releases; snapshots must be equal. An architecture test confirms only the reconciler writes system catalogue fields.

### 17.5 Retired exercises keep historical references
Retiring sets `retired_at`; system exercises are never deleted and identifiers never reused. Because sets and plan exercises reference exercises without a foreign key, an integrity check (CI and in-app at startup, reported not repaired) asserts that every referenced exercise id exists. History, PR and volume queries include retired exercises; discovery hides them; starting a session from a plan with a retired exercise follows the WP 9 archived-exercise behaviour (skipped with a warning). Tests for each.

### 17.6 Atomic, repeatable and auditable releases
Atomic: validation of the whole release before any write; one transaction per release; a failure leaves no partial state (test with a fault injected mid-release). Repeatable: applying the same release again performs no writes (row hashes and `updated_at` unchanged). Auditable: `catalogue_releases` records provider, release, content hash, counts inserted/updated/retired, app version and time; every system exercise records provider and revision; the log is included in backups; CI publishes the integrity and coverage report for each release.

## 18. Decisions of 2026-11-05 and their effect on this plan
| Item | Decision | Effect |
|---|---|---|
| ADR-0008, ADR-0009 | direction approved | implement as written in stage 3 |
| 19 muscle ids, `fullBody` | approved (§4) | mapping as §4 |
| `exercises` rebuild | approved, conditional | §17.1 trial comparison, §17.2 value equality, §17.3 backup compatibility and §17.5 reference preservation are recorded as evidence before sub-stage 3b is finalised; the comparison may not be skipped |
| OQ-19 | attributed set counts, confirmed | §8; terminology shown in reports |
| OQ-21 | approved | ADR-0009 §1 |
| Legacy invalid values | approved rule incl. **report of every affected record** | stage 3 adds a migration report (in-app Settings › Data and in the backup), resolving TD-41's visibility gap; applies to v6 quarantine rows and any v8 findings |
| TRN-020 | RIR integer 0–5 at domain **and persistence** boundaries | stage 3b adds persistence enforcement for `session_sets` exertion (CHECK via table rebuild, or validation triggers — chosen by the same evidence method as §17.1); stored out-of-range values quarantined, cleared (exertion is optional) and reported |
| Screen ownership | WP 8: library, taxonomy, discovery, detail, favourites; WP 9: planning, execution, sessions, sets, rest timers | stage 6 scope; exercise detail history stays a WP 8 screen reading WP 9 data |
| Stage 4 | authorised; **outputs approved 2026-11-05** (OQ-22, OQ-23, ADR-0010) | `docs/catalogue/` is the approved specification for stages 3c and 5; X1–X4 deferred to stage 3a or the 5.1 pilot |
| Stage 3 | gated | starts after: WP 9 stage 3b CI green; Android/iOS builds reviewed (desugaring); emulator full-session test passed; independent WP 9 review complete; WP 9 accepted; then final authorisation of this stage |

## 19. Stage 4 approval (2026-11-05) and the stage 5 gate
- OQ-22 and OQ-23 approved; ADR-0010 accepted; primary-muscle principle, equipment, attributes, mechanics and content-policy decisions approved (D04 §7). `docs/catalogue/` is the approved reference specification.
- Stage 3 must load the approved reference data (anatomy 126 nodes, patterns 79 entries, equipment 33 with the 12 additions, seven attributes) and implement the integrity checks, the `fullBody` rules (ADR-0010) and the migration report.
- **Stage 5 gate**: authorised in principle; no bulk population before stage 3 tooling is implemented and verified; 5.1 chest pilot first; mandatory re-baselining and explicit owner approval before 5.2–5.7.

