# WP 8 — Revised delivery plan (expanded exercise library)

- Status: **Revision 3 (b63c4d9) APPROVED and stage 3 implementation AUTHORISED by the owner on 2026-11-06** (sub-stages 3a–3d and the combined stage 3 review; §21). Stage 3 acceptance remains the owner's decision; implementation completion is not acceptance. WP 8 is the active work package; no WP 16 implementation exists or is authorised.
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
| 3 | Architecture and reference data (§1–§14 below) — sub-stages 3a domain model, 3b schema v8 and migration, 3c catalogue format and reconciler, 3d adapt WP 8/9 code | WP 9 accepted 2026-11-06 (shared code); after explicit owner authorisation of this revised plan | tests, independent review per sub-stage, four workflows |
| 4 | Catalogue tooling and quality assurance: editorial guide (naming, variation rules, instruction style, anatomical tagging), licence register, integrity checks and coverage report in CI, **coverage matrix with regional minimums (OQ-23)**, **anatomy node and movement pattern lists (OQ-22)** | documents and lists now (no code overlap with WP 9); CI tooling after stage 3c | owner approval of matrix and lists before stage 5 |
| 5 | Anatomical catalogue population in tranches: 5.1 chest, 5.2 back, 5.3 shoulders, 5.4 arms, 5.5 hips and legs, 5.6 trunk, 5.7 conditioning and mobility | after stages 3 and 4 | per tranche: coverage minimums met, instructions for every exercise, zero integrity failures, gap report, owner content review |
| 6 | Search, discovery and exercise screens: filters by anatomy, equipment, pattern, mechanics, laterality, difficulty, logging type; sorting; favourites; relationship navigation; instructions; custom exercises with the new fields; **exercise history paging — 20 sessions first, more on scroll (TRN-025(2); allocated from WP 9 by owner decision M4 / OQ-25, 2026-11-05)** | after stage 3; parallel with stage 5 | widget and integration tests, accessibility, independent review |
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
| WP 9 (schema v7) | **accepted 2026-11-06** at 0c35ef1 | stage 3 may change the code WP 9 uses (sub-stage 3d) under full regression |
| WP 10 | **accepted 2026-11-05** at bb5f788; **no schema change** | schema **v8 is available** to WP 8 stage 3; no data dependency |
| ADR-0008, ADR-0009 | **direction accepted 2026-11-05** | implement as written |
| ADR-0010 (`fullBody`) | **accepted 2026-11-05** | rules in §4 and §11 |
| OQ-19 volume attribution | **approved 2026-11-05** | rule in §8 |
| OQ-21 definition of "imported" | **approved 2026-11-05** | ADR-0009 §1 |
| OQ-22 anatomy and movement-pattern lists | **approved 2026-11-05** | stage 3 loads the approved `docs/catalogue/reference/anatomy.json` (126 nodes), `movement-patterns.json` (79 entries) and `equipment.json` (33 items) — §4, §6, §7, §11 |
| OQ-23 coverage matrix | **approved 2026-11-05** | governs stage 5, not stage 3 |
| Legacy invalid values, TRN-020, screen ownership | **approved 2026-11-05** | §6, §11 |
| This plan | **revision 3 awaiting owner authorisation** | required before implementation |

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
Source of truth: the **approved** `docs/catalogue/reference/anatomy.json` (126 nodes: 10 L1, 26 L2, 63 L3, 27 L4; OQ-22, 2026-11-05). Each of the 19 identifiers is a node of that file at the level and parent below; stored values (`primary_muscle`, `secondary_muscles_json`) map one to one; no identifier changes.

| WP 8 id | Level | Ancestors (approved) | Children (approved) |
|---|---|---|---|
| `chest` | L2 | `regionChest` | `pectoralisMajor`, `pectoralisMinor`, `serratusAnterior` |
| `frontDelts` | L4 | `deltoid` › `shoulders` › `regionShoulder` | — |
| `sideDelts` | L4 | `deltoid` › `shoulders` › `regionShoulder` | — |
| `rearDelts` | L4 | `deltoid` › `shoulders` › `regionShoulder` | — |
| `triceps` | L3 | `upperArmPosterior` › `regionArm` | `tricepsLongHead`, `tricepsLateralHead`, `tricepsMedialHead` |
| `biceps` | L3 | `upperArmAnterior` › `regionArm` | `bicepsLongHead`, `bicepsShortHead` |
| `forearms` | L2 | `regionArm` | `wristFlexors`, `wristExtensors`, `brachioradialis`, `forearmPronators`, `forearmSupinators` |
| `upperBack` | L2 | `regionBack` | `trapezius`, `rhomboids`, `levatorScapulae` |
| `lats` | L2 | `regionBack` | `latissimusDorsi`, `teresMajor` |
| `lowerBack` | L2 | `regionBack` | `erectorSpinae`, `quadratusLumborum`, `multifidus` |
| `abs` | L2 | `regionTrunk` | `rectusAbdominis`, `transversusAbdominis` |
| `obliques` | L2 | `regionTrunk` | `externalOblique`, `internalOblique` |
| `glutes` | L2 | `regionHip` | `gluteusMaximus`, `gluteusMedius`, `gluteusMinimus` |
| `abductors` | L2 | `regionHip` | `tensorFasciaeLatae` (gluteus medius and minimus stay under `glutes`: one parent per node) |
| `adductors` | L2 | `regionHip` | `adductorMagnus`, `adductorLongus`, `adductorBrevis`, `gracilis`, `pectineus` |
| `quadriceps` | L2 | `regionThigh` | `rectusFemoris`, `vastusLateralis`, `vastusMedialis`, `vastusIntermedius` |
| `hamstrings` | L2 | `regionThigh` | `bicepsFemoris`, `semitendinosus`, `semimembranosus` |
| `calves` | L2 | `regionLowerLeg` | `gastrocnemius`, `soleus` |
| `fullBody` | L1, non-anatomical | — | none (ADR-0010: only the single primary of qualifying whole-body or conditioning exercises; never secondary; never with anatomical primaries; excluded from anatomical roll-ups, coverage and attributed set counts) |

The 19 identifiers and their 12 ancestors (`regionShoulder`, `regionChest`, `regionBack`, `regionArm`, `regionTrunk`, `regionHip`, `regionThigh`, `regionLowerLeg`, `shoulders`, `deltoid`, `upperArmAnterior`, `upperArmPosterior`) are the **31 nodes** the migration needs for integrity (§6). The other approved L1/L2 nodes include `regionNeck` (neck flexors, extensors, lateral flexors), `rotatorCuff`, `hipFlexors`, `hipExternalRotators`, `anteriorLowerLeg`, `lateralLowerLeg`, `deepPosteriorLowerLeg` and `pelvicFloor` (content excluded by owner decision; identifier kept). Filtering by any node includes its descendants; primary matches rank first (TRN-010(2) behaviour kept).

## 5. Schema v8 (proposed)
New tables:
- `anatomy_nodes(id PK, parent_id → anatomy_nodes, level 1–4, non_anatomical bool, sort_order, provider_id, release)`
- `movement_patterns(id PK, parent_id, sort_order, provider_id, release)`
- `equipment_items(id PK, sort_order, provider_id, release)` (21 existing ids kept; 33 in the approved list incl. 12 additions)
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
2. Create reference tables; insert only the reference rows needed for integrity, from constants in the migration code that are **identical to the approved `anatomy.json`** (a test compares them): the **31 nodes** of §4 with their approved parents and levels, the 21 existing equipment items, provider `repforge`. The full approved lists (anatomy 126 nodes, movement patterns 79 entries, equipment 33 items, seven attributes) are loaded by catalogue release 2 at startup (§7).
3. Backfill `exercise_targets` from `primary_muscle` (primary, ordinal 0) and `secondary_muscles_json` (secondary, in order); backfill `source` from `supplied` (`system` with provider `repforge`, else `user`); `revision` = 1 for system rows. A secondary equal to the primary is not duplicated and is **listed in the migration report**; a `fullBody` secondary (ADR-0010) is kept historically and **listed in the migration report**.
4. Rebuild `exercises` without the three columns — **only after the §17.1 comparison trial and the §17.2 value-equality evidence are recorded**; verify row count and every retained column equal before and after (test).
5. Values that cannot be mapped (an unknown muscle text left by the v6 legacy mapping, TD-41) keep their exercise row; the original goes to `legacy_quarantine` with a reason; **nothing is invented or silently corrected**.
6. **TRN-020 in the database**: `session_sets` exertion is constrained to RPE 1–10 in steps of 0.5 and RIR integers 0–5 (CHECK via table rebuild, or validation triggers — chosen by the §17.1 evidence method). Stored values outside the rule are copied to `legacy_quarantine`, the operational value is cleared (exertion is optional), and each is **listed in the migration report**; the set row and its relationships are kept.
7. **Migration report**: every affected record — quarantined, cleared, not duplicated or kept historically, in v6 and v8 — is listed with table, id, field, original value, action and reason; shown in Settings › Data and included in the backup. Never a sample.
8. No stored set, plan, session, schedule or exercise identifier changes.
9. Release 1 of provider `repforge` is recorded as the existing seed; `seedExercisesVersion` is read once to decide whether release 1 was applied, then retired.

## 7. Catalogue release format 2 and reconciler
Per ADR-0009: bundled JSON per provider and release, holding reference data, exercises (`id`, `revision`, names, aliases, logging type, category, targets with roles, patterns, equipment, mechanics, laterality, difficulty, relationships, content sections by locale, media references) and provider metadata. Validation is all-or-nothing. The reconciler inserts, updates system-owned fields when the revision is higher, retires missing ids, and never writes user-owned data. Re-running a release is a no-op. WP 8 stage 3 ships release 2 = the approved reference data (`docs/catalogue/reference/`) and the 89 existing exercises re-expressed with the **approved release-2 classifications** (`mapping-existing.json`: targets, patterns, mechanics, laterality, difficulty, alias clean-up); instructions are not written yet (WP 8 stage 5). **Reference-data loading is deterministic and repeatable**: the same release produces byte-identical reference tables on every device and every run (content hash recorded; re-applying writes nothing), and is validated against the stage 4 integrity checks (`docs/catalogue/quality-and-duplicates.md`) before any write.

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
- Backup tests: v1, v2, v3 restore; v3 round-trip of all new data incl. the migration report.
- Migration report tests: every affected record listed (quarantined, cleared, not duplicated, kept historically); nothing silently corrected.
- TRN-020 persistence tests: the database rejects RIR outside 0–5 and non-integers, and RPE outside 1–10 or off 0.5 steps; legacy out-of-range values quarantined, cleared and reported.
- Reference-data tests: migration constants equal the approved `anatomy.json` for the 31 nodes; loading release 2 twice gives identical tables (hashes); integrity checks of `quality-and-duplicates.md` (incl. IC-304 `fullBody` rules and IC-900 reference resolution incl. retired exercises) pass for release 2.
- Regression: all WP 8 and WP 9 tests pass with the adapted model; WP 9 volume tests updated only for OQ-19.
- Architecture tests: domain has no Flutter imports; only the reconciler writes system catalogue fields; reference ids used through typed wrappers.
- CI: integrity report over the shipped catalogue as a gate; four workflows green; coverage ≥ 80 % hand-written.
- Independent review of each stage and of the final diff, with probe tests, as for WP 8 and WP 9.

## 11. Stage 3 acceptance criteria
1. ADR-0008, ADR-0009 and ADR-0010 implemented as written.
2. Schema v8 migration from every earlier version (v1–v7) preserves all exercise identifiers, the 19 muscle identifiers (as nodes) and all training data; tests prove value equality (§17.2); the `exercises` rebuild is justified by the recorded comparison trial (§17.1).
3. Exercises, anatomy nodes, patterns, equipment, relationships, content, media references, providers and releases meet the Engineering Object definition (identity, type, provenance, validation, timestamps, relationships, versioning, persistence, query, backup, restore).
4. Four-level anatomy with validation; exercises carry one or more primary and zero or more secondary targets; `fullBody` rules per ADR-0010 enforced.
5. Movement pattern, mechanics, laterality and difficulty (owner definitions) and the seven approved optional attributes stored and validated.
6. Five relationship kinds validated: direction, no self-reference, no duplicates or inverse duplicates, no cycles where directional.
7. Content sections and media references stored per locale (`en-GB`), extensible without schema change.
8. Source separation system/user/imported; provider registry with licence; catalogue releases atomic, repeatable and auditable (§17.6); **user-owned data never overwritten** by any release (§17.4, row-hash test).
9. **Approved stage 4 reference data loaded and validated**: anatomy 126 nodes, movement patterns 79 entries, equipment 33 items and the seven attributes from `docs/catalogue/reference/`; loading deterministic and repeatable; duplicate detection and the integrity report run in CI with zero integrity failures for release 2.
10. **Migration report**: every affected legacy record listed (v6 quarantine and v8 findings), shown in Settings › Data and included in the backup; **no invalid value silently corrected** (resolves TD-41's visibility gap).
11. **TRN-020 enforced in the database**: RIR integers 0–5 and RPE 1–10 in 0.5 steps rejected at persistence as well as in the domain; stored out-of-range values quarantined, cleared and reported.
12. **Retired exercises remain available to historical records**: never deleted, identifiers never reused; the reference-integrity check (IC-900) proves every set, session-exercise and plan reference resolves, retired exercises included (§17.5).
13. Favourites and other user state persisted and backed up (UI in WP 8 stage 6).
14. Backup format 3 with restore of formats 1, 2 and 3 (§17.3).
15. WP 8 and WP 9 behaviour unchanged except where an owner decision changes it (TRN-010(1), OQ-19, TRN-020 persistence); full suite, coverage gate (≥ 80 %), four workflows and the emulator run green.
16. Delivery record with tests, CI runs, the §17.1 trial evidence, independent review findings and resolutions, deviations and open items.

## 12. Stage 3 sub-stages and gates
| Stage | Content | Gate |
|---|---|---|
| 3a | Domain model, reference data structure, validation rules, duplicate detection, integrity report (pure code, no schema); deferred stage 4 items X1–X3 | tests; independent review |
| 3b | §17.1 comparison trial first; then schema v8, migration (incl. migration report and TRN-020 persistence), repositories, backup v3 | trial evidence recorded before finalising; migration, equality and backup tests; independent review |
| 3c | Catalogue format 2, reconciler, deterministic loading of the approved reference data, release 1→2 of the 89 exercises, CI integrity gate | reconciler and reference-data tests; integrity report with zero failures |
| 3d | Adapt WP 8/9 code and screens; OQ-19 rule | full regression, four workflows, emulator |
| Stage 3 close | combined independent review of stage 3, remediation, record update | owner review of stage 3 |

## 13. Risks
| Risk | Mitigation |
|---|---|
| Table rebuild of `exercises` loses data | v6-proven pattern; before/after equality tests; crash re-run test |
| Anatomy over-precision | qualitative roles only; tag at the most defensible level; editorial guide (WP 8 stage 4) |
| Refactor of WP 8/9 code introduces regressions | sub-stage 3d alone; full regression and emulator run |
| Reference list churn | lists approved (OQ-22, 2026-11-05); identifiers never reused; reference-data lifecycle (active/retired) per the catalogue ledger |
| Licence contamination | provider registry; no proprietary content; review in WP 8 stage 4 |
| Schema version clash with WP 10 | resolved: WP 10 accepted with no schema change; v8 is available |

## 14. Decisions to authorise stage 3
1. ~~Approve ADR-0008 and ADR-0009~~ — direction accepted 2026-11-05.
2. ~~Approve the identifier mapping in §4 and the `fullBody` treatment~~ — approved 2026-11-05 (ADR-0010 accepted; §4 now from the approved `anatomy.json`).
3. ~~Approve the `exercises` table rebuild~~ — conditionally approved 2026-11-05, subject to the §17.1 trial and §17.2–§17.5 evidence before sub-stage 3b is finalised.
4. ~~OQ-19~~ approved 2026-11-05 (§8).
5. ~~OQ-21~~ approved 2026-11-05 (ADR-0009).
6. ~~OQ-22, OQ-23~~ approved 2026-11-05 (§2).
7. ~~Confirm sequencing~~ — confirmed 2026-11-05 (§16).
8. **Pending: authorise implementation of stage 3 against this revised plan.**

## 15. Final WP 8 acceptance criteria
WP 8 is accepted when all of the following hold:
1. **Original D06 criteria** remain met (each set type stored and read back; invalid combinations rejected at use-case level; unit and migration tests) and TRN-001..TRN-012 hold, with TRN-010(1) as amended (one or more primary targets).
2. **Stage 3** criteria (§11) met: Engineering Object model, four-level anatomy, targets, classifications, relationships, content and media references, providers and releases, source separation, idempotent updates that never overwrite user data, duplicate detection and integrity report, schema v8 preserving all identifiers and data.
3. **Stage 4**: editorial guide, licence register, CI integrity and coverage reporting; coverage matrix minimums and reference lists approved by the owner.
4. **Stage 5** (starts only after OQ-22 lists and OQ-23 minimums are approved): every region's tranche meets the approved coverage matrix (anatomy, diversity, compound/isolation, unilateral/bilateral, patterns, equipment incl. free weights, machines, cables, Smith machine, bands, kettlebells and bodyweight, difficulty distribution, variation depth); instructions (setup, execution, breathing, common mistakes) for every system exercise; zero integrity failures; explicit gap report; owner content review per tranche. Raw count is not evidence.
5. **Stage 6**: search, filters, sorting, favourites, relationship navigation, instruction display, exercise history paging (TRN-025(2), from WP 9 M4) and custom exercise creation (LIB-008, LIB-009) with widget and integration tests and accessibility as WP 8/9.
6. **Media**: data references only (LIB-010 readiness); display and storage deferred, outside acceptance.
6a. **Integrity**: an automated check proves every historical set and plan reference resolves to an existing exercise, retired exercises included; no exercise deleted, no identifier reused.
6b. **OQ-19 terminology** visible wherever per-muscle figures are reported.
7. **No regressions**: all WP 9 behaviour and tests pass; full suite, coverage gate (≥ 80 %), four workflows and the emulator run green on the final commit.
8. **Open WP 8 decisions** dispositioned by the owner: legacy-data policy and TRN-020 correction (WP 8 record), OQ-19, OQ-21, OQ-22, OQ-23.
9. Independent review of the final combined diff with findings resolved or accepted as debt; delivery record complete with exact commits and CI runs.

## 16. Dependencies and sequencing
- **WP 9**: accepted 2026-11-06 at 0c35ef1. Stage 3d adapts code WP 9 uses; WP 9 behaviour is protected by the full regression suite and the emulator run.
- **WP 10**: accepted 2026-11-05 at bb5f788 with no schema change; **schema v8 is available** to stage 3.
- **WP 11**: depends on WP 8's expanded anatomy and exercise taxonomy (stage 3) for its training analytics, such as volume per muscle (D06).
- **Stage 4**: outputs approved 2026-11-05; its CI integrity and coverage tooling is built in stage 3c.
- **Stage 5**: no bulk population before stage 3 tooling is implemented and verified, the 5.1 pilot is reviewed and the coverage matrix is applied.
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
| Stage 3 | gated | WP 9 accepted 2026-11-06; implementation starts only after explicit owner authorisation of this revised plan (revision 3) |

## 19. Stage 4 approval (2026-11-05) and the stage 5 gate
- OQ-22 and OQ-23 approved; ADR-0010 accepted; primary-muscle principle, equipment, attributes, mechanics and content-policy decisions approved (D04 §7). `docs/catalogue/` is the approved reference specification.
- Stage 3 must load the approved reference data (anatomy 126 nodes, patterns 79 entries, equipment 33 with the 12 additions, seven attributes) and implement the integrity checks, the `fullBody` rules (ADR-0010) and the migration report.
- **Stage 5 gate**: authorised in principle; no bulk population before stage 3 tooling is implemented and verified; 5.1 chest pilot first; mandatory re-baselining and explicit owner approval before 5.2–5.7.

## 20. Revision 3 (2026-11-06) — corrections for owner review
Documentation and acceptance-criteria corrections only; no approved decision or architecture changed:
1. §2 and §14 show ADR-0008, ADR-0009, ADR-0010, OQ-22 and OQ-23 as approved and WP 9 as accepted.
2. §2, §13 and §16 confirm schema v8 is available (WP 10 accepted with no schema change).
3. §4 uses the approved `anatomy.json` (126 nodes) with its actual parents and children; §6 names the 31 nodes the migration needs and requires the constants to equal the approved file.
4. §11 adds the migration report, database-enforced TRN-020, loading and validation of the approved stage 4 reference data, and explicit criteria for retired-exercise references and user data; §6, §7, §10 and §12 aligned with §11, §17 and §19.
Retained requirements: every affected legacy record reported; invalid values never silently corrected; RIR 0–5 enforced in the database; deterministic, repeatable reference-data loading with validation; retired exercises available to historical records; no user data overwritten by catalogue releases; the conditional table-rebuild approval with the comparison trial and migration evidence.

## 21. Stage 3 authorisation (2026-11-06) and binding safeguards
Revision 3 approved; stage 3 authorised in the sequence 3a → 3b → 3c → 3d → combined review → owner acceptance, each sub-stage returned for independent review before the next gate. The approved reference data and architectural decisions are the binding specification.
- **A. SQLite foreign keys and atomicity.** `PRAGMA foreign_keys` cannot change inside an active transaction. Sub-stage 3b must establish and document how the migration tooling actually runs (whether drift's `onUpgrade` already runs with foreign keys off and outside or inside a transaction), then: disable enforcement before the transaction if required; run the rebuild and migration atomically; run `PRAGMA foreign_key_check` before commit; commit; restore enforcement and verify it is on. Tests demonstrate each step, including a failure that rolls back.
- **B. Bootstrap versus catalogue.** The 31 anatomy nodes inserted by the migration are a bootstrap only. The complete approved catalogue (126 anatomy nodes, 79 movement-pattern entries, 33 equipment items, seven attributes) is loaded by release 2 deterministically, repeatedly and without duplicates; a test fails if the catalogue after startup equals the bootstrap or differs from the approved files.
- **C. TRN-020 database constraints.** Authoritative rule (D04 TRN-020): RPE 1 to 10 in steps of 0.5, or RIR 0 to 5 in whole numbers; the scale is stored with the value; existing entries keep the scale they were recorded in. D04 defines **no conversion or numeric relationship between RPE and RIR**; none is invented. The constraint is per scale: `scale = 'rpe'` → value in 1–10 and a multiple of 0.5; `scale = 'rir'` → integer 0–5; no other scale. Any further rule needs an owner decision.
- Controls retained: independent review after every sub-stage; no sub-stage accepted because tests pass; migration equality from every supported starting schema; backup formats 1–3; no ID lost or reassigned; no user data overwritten by catalogue updates; retired exercises resolvable in history; full WP 8 and WP 9 regression; four-workflow CI; coverage ≥ 80 %; explicit migration and catalogue integrity reports. Stage 5 waits for stage 3 acceptance, the reviewed 5.1 pilot and the applied coverage matrix.

