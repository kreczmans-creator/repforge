# WP 16a — Architecture and reference data: implementation plan

- Status: **Proposed — for owner review. Implementation not authorised.**
- Date: 2026-11-05
- Parent: WP 16 Exercise library expansion (`docs/exercise-library-expansion.md`); owner decisions D04 §7 (2026-11-05, WP 16 decisions).
- ADRs: ADR-0008 (domain model), ADR-0009 (catalogue provenance and updates) — both Proposed.

## 1. Objective and scope
Put the exercise library on an architecture that can carry a comprehensive catalogue, without adding catalogue content or new discovery screens.

In scope: Engineering Object model for exercises and reference data; four-level anatomy; multiple primary and secondary targets; movement pattern, mechanics, laterality, difficulty; five relationship kinds; instruction sections and media references (data only); providers and catalogue releases with an idempotent reconciler; source separation (system, user, imported); user state including favourites (data and use cases); duplicate detection and integrity report; schema v8 and migration; backup format; adapting WP 8 and WP 9 code to the new model with unchanged behaviour.

Out of scope: catalogue population beyond re-expressing the existing 89 exercises (WP 16c); new filters, sorting, favourites and variation screens (WP 16d); media display (WP 16e); translation; exercise metrics, tempo, range of motion, execution guidance and recommendations (accommodated by the content model, not delivered); training programmes.

## 2. Preconditions and dependencies
| Item | Status | Effect |
|---|---|---|
| WP 9 delivered (schema v7) | in progress | WP 16a starts after WP 9 delivery so the two do not change the same code |
| ADR-0008, ADR-0009 approved | proposed | required before implementation |
| This plan authorised | proposed | required before implementation |
| OQ-19 volume attribution with several primary targets | open | needed for the WP 9 volume rule change; proposal in §8 |
| OQ-21 definition of "imported" source | open | proposal in ADR-0009 |
| OQ-22 anatomy node list and movement pattern list | open | WP 16a ships the structure and a proposed list; owner approves the lists before WP 16c |
| WP 8 decisions 1 (taxonomy) and acceptance | open | WP 16a extends the 19 identifiers; it does not decide WP 8 acceptance |
| Schema numbering with WP 10 | coordination | WP 16a takes v8 if it lands first; otherwise the next free version. No data dependency |

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
Per ADR-0009: bundled JSON per provider and release, holding reference data, exercises (`id`, `revision`, names, aliases, logging type, category, targets with roles, patterns, equipment, mechanics, laterality, difficulty, relationships, content sections by locale, media references) and provider metadata. Validation is all-or-nothing. The reconciler inserts, updates system-owned fields when the revision is higher, retires missing ids, and never writes user-owned data. Re-running a release is a no-op. WP 16a ships release 2 = the 89 existing exercises re-expressed in the new format with targets and patterns; mechanics, laterality and difficulty are filled where defensible, instructions are not written yet (WP 16c).

## 8. Changes to WP 8 and WP 9 code (behaviour preserved)
- `Exercise`: `primaryMuscle`/`secondaryMuscles` → `targets`; `supplied` → `source`; new classification fields. Library queries filter by node with descendants; equipment filter unchanged; search unchanged.
- WP 8 screens: show primary targets where they showed the primary muscle; editor requires at least one primary target. No new discovery features (WP 16d).
- WP 9 volume per muscle group (TRN-027(3)): **proposal for OQ-19** — each primary target counts the set's volume in full at its L2 group (or at the node itself above L2); secondary targets are reported separately and never added; a set is counted once per distinct L2 group. Session and exercise volume are unchanged.
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

## 11. Acceptance criteria (WP 16a)
1. ADR-0008 and ADR-0009 approved; implementation matches them.
2. Schema v8 migration from every earlier version preserves all exercise identifiers, the 19 muscle identifiers (as nodes) and all training data; tests prove value equality.
3. Exercises, anatomy nodes, patterns, equipment, relationships, content, media references, providers and releases meet the Engineering Object definition (identity, type, provenance, validation, timestamps, relationships, versioning, persistence, query, backup, restore).
4. Four-level anatomy with validation; exercises carry one or more primary and zero or more secondary targets.
5. Movement pattern, mechanics, laterality and difficulty (owner definitions) stored and validated.
6. Five relationship kinds validated: direction, no self-reference, no duplicates or inverse duplicates, no cycles where directional.
7. Content sections and media references stored per locale (`en-GB`), extensible without schema change.
8. Source separation system/user/imported; provider registry with licence; catalogue releases applied idempotently; user-owned data never overwritten (tests).
9. Duplicate detection and an integrity report generated in CI; zero integrity failures for release 2.
10. Favourites and other user state persisted and backed up (UI in WP 16d).
11. WP 8 and WP 9 behaviour unchanged except where an owner decision changes it (TRN-010(1), OQ-19); full suite, coverage gate and four workflows green.
12. Delivery record with tests, CI runs, independent review findings and resolutions, deviations and open items.

## 12. Delivery stages and gates
| Stage | Content | Gate |
|---|---|---|
| 16a-1 | Domain model, reference data structure, validation rules, duplicate detection, integrity report (pure code, no schema) | tests; independent review |
| 16a-2 | Schema v8, migration, repositories, backup v3 | migration and backup tests; independent review |
| 16a-3 | Catalogue format 2, reconciler, release 1→2 of the 89 exercises, CI integrity gate | reconciler tests; integrity report |
| 16a-4 | Adapt WP 8/9 code and screens; OQ-19 rule | full regression, four workflows, emulator |
| Final | combined independent review, remediation, delivery record | owner review |

## 13. Risks
| Risk | Mitigation |
|---|---|
| Table rebuild of `exercises` loses data | v6-proven pattern; before/after equality tests; crash re-run test |
| Anatomy over-precision | qualitative roles only; tag at the most defensible level; editorial guide (WP 16b) |
| Refactor of WP 8/9 code introduces regressions | stage 16a-4 alone; full regression and emulator run |
| Reference list churn | lists approved (OQ-22) before WP 16c; identifiers never reused |
| Licence contamination | provider registry; no proprietary content; review in WP 16b |
| Schema version clash with WP 10 | coordinate numbering at start |

## 14. Decisions requested to authorise WP 16a
1. Approve ADR-0008 and ADR-0009.
2. Approve the identifier mapping in §4 and the `fullBody` treatment.
3. Approve the `exercises` table rebuild in v8 (§5) instead of keeping unread columns.
4. Decide OQ-19 (volume attribution) — proposal in §8.
5. Confirm the "imported" definition (OQ-21).
6. Confirm sequencing: after WP 9 delivery; in parallel with WP 10 if wanted; before the training-volume parts of WP 11.
7. Authorise implementation of WP 16a.
