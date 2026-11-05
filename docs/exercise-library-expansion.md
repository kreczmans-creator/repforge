# Exercise library expansion — gap analysis and work-package proposal

- Status: **Scope incorporated into WP 8 (owner decision, 2026-11-05).** WP 8 is the active work package; WP 16 is not created as a delivery package; **the WP 16 proposal in this document's history is superseded by the WP 8 scope decision**; no WP 16 implementation is authorised. Remaining work and final acceptance criteria: `docs/wp8-delivery-plan.md`. Stage 3 implementation awaits owner authorisation.
- Scope of this document: review of the WP 8 implementation against the amended requirement, architectural gaps, proposed work packages and the decisions needed. Nothing here is implemented. WP 9 stays focused on planning and execution.
- Evidence: code and seed asset at commit fb0a8d4 (WP 8 implementation b1ab45a plus WP 9 stages to date).

## 1. Requirement identifiers (proposed)
The owner's ten capabilities are recorded as LIB-001..LIB-010 so tests and records can cite them. Identifiers are proposed; wording is the owner's.

| ID | Capability (owner text, condensed) |
|---|---|
| LIB-001 | Comprehensive catalogue covering all major and minor muscle groups |
| LIB-002 | Multiple legitimate variations per muscle group and movement pattern |
| LIB-003 | Free weights, machines, cables, bodyweight, bands, kettlebells, Smith machine and other equipment |
| LIB-004 | Detailed anatomical classification; primary and secondary involvement represented independently |
| LIB-005 | Classification by movement pattern, equipment, difficulty and exercise type |
| LIB-006 | Instructions: setup, execution, breathing, common mistakes |
| LIB-007 | Explicit relationships between canonical exercises and their variations |
| LIB-008 | Search, filtering, sorting, favourites and discovery |
| LIB-009 | Custom exercise creation |
| LIB-010 | Architecture ready for images, video and further instructional content |

Architectural requirements (owner): canonical domain objects; explicit variation relationships; hierarchical anatomical taxonomy; controlled reference data for equipment and movement; aliases; routine catalogue additions without structural database changes; no duplicates or superficial variations; localisation and further metadata later. No built-in programmes or programme generation.

## 2. WP 8 against the amended requirement (verified in code)
| Requirement | WP 8 state (evidence) | Verdict |
|---|---|---|
| LIB-001 coverage | 89 supplied exercises (`assets/seed/exercise_library.json`). Primary-muscle counts: quadriceps 17, chest 9, glutes 8, lats 7, upper back 6, abs 6, hamstrings 5, triceps 5, biceps 5, front delts 3, calves 2 (one is skipping), rear delts 2, obliques 2, forearms 2, side delts 1, abductors 1, adductors 1, lower back 1 | **Not met** |
| LIB-002 variations | Few per group (e.g. one side-delt exercise, one standing calf raise) | **Not met** |
| LIB-003 equipment | Controlled list has 21 items incl. `smithMachine`, `rings`, `medicineBall`, but the seed uses `smithMachine` 0, `rings` 0, `medicineBall` 0, `kettlebell` 1, `resistanceBand` 1 | List **met**; content **not met** |
| LIB-004 anatomy | Flat enum of 19 groups (`MuscleGroup`), one primary plus a secondary list stored separately (`primary_muscle`, `secondary_muscles_json`). No hierarchy (region › group › muscle/head), no involvement levels beyond primary/secondary | **Partly met** (independent primary/secondary yes; hierarchy no) |
| LIB-005 classification | `ExerciseType` (6 logging types) and `ExerciseCategory` (7: push, pull, legs, core, fullBody, cardio, mobility). No movement pattern (squat, hinge, lunge, horizontal/vertical push/pull, carry, rotation…), no mechanics (compound/isolation), no laterality (unilateral/bilateral), no difficulty | **Not met** |
| LIB-006 instructions | No instruction fields anywhere in model, table or seed | **Not met** |
| LIB-007 variations | Only `copiedFromId` (a user's custom copy of a supplied exercise). No canonical/variation relationship | **Not met** |
| LIB-008 discovery | Search by name and aliases ignoring case and diacritics; filters by category, muscle (primary first), equipment subset and bodyweight-only; archived toggle. Sorting: name only. No favourites, no "related/variations" navigation | **Partly met** |
| LIB-009 custom exercises | Create, edit, archive; editing a supplied exercise creates a custom copy | **Met** (will need the new fields) |
| LIB-010 media readiness | No media references or content extension points | **Not met** |
| Aliases | `aliases_json`, searchable; 87 of 89 seed entries have aliases | **Met** |
| Routine additions without structural DB change | New exercises: seed data only, no schema change — met. But the importer runs **once per seed version and never updates an existing supplied exercise** (`import_exercise_library.dart`: existing ids are skipped), so corrections and enrichment of supplied exercises cannot ship. Taxonomy values are Dart enums: a new value needs a code change (acceptable for controlled lists that ship with the app; not runtime-extensible) | **Partly met** |
| No duplicates | Seed validation checks unique ids only; no check of duplicate names, alias collisions or near-duplicates | **Not met** |
| Localisation | Names and aliases are single-language strings; taxonomy labels are English in `training_labels.dart` | **Not met** (no blocker) |

Conclusion: WP 8 delivers a sound logging-oriented exercise model and a starter library. It does **not** satisfy the amended scope. The gaps are both architectural (model, taxonomy, relationships, content, catalogue updates) and content (coverage).

## 3. Architectural gaps and proposed direction
1. **Hierarchical anatomical taxonomy** (LIB-004): reference data with stable identifiers and a parent link — region (e.g. shoulders) › muscle group (e.g. deltoids) › muscle or head (anterior, lateral, posterior). Exercises tag primary and secondary involvement at the most specific level known; filters work at any level. The 19 WP 8 identifiers are kept as nodes in the tree, so stored data and WP 9 volume-by-muscle keep working.
2. **Controlled classification reference data** (LIB-005): movement pattern, mechanics (compound/isolation), laterality (bilateral/unilateral/alternating), difficulty (definition needed), force direction if wanted. Equipment list extended as needed (existing 21 identifiers kept).
3. **Canonical exercises and variations** (LIB-007): explicit relationship rows (variation of, with a relation kind such as equipment, grip, stance, angle, unilateral), validated as acyclic, one canonical root per family. Rules against superficial variations (a variation must change equipment, grip, stance, angle, range or laterality).
4. **Instructional content** (LIB-006, LIB-010): content stored in sections (setup, execution, breathing, common mistakes; later cues, safety) keyed by exercise, section kind and locale, so new section kinds and languages need no schema change. Media as references (kind, locator, licence, attribution), no binary in the database; display later.
5. **Catalogue lifecycle**: a versioned catalogue that can add, update and retire supplied exercises (supplied rows are read-only to users, who edit custom copies, so updates are safe). Retired exercises stay readable in history. Stable identifiers never reused.
6. **Catalogue integrity checks** as tests: unique normalised names, alias collisions, variation graph valid, every exercise fully classified, coverage matrix per region, muscle, equipment and pattern.
7. **Discovery** (LIB-008): filters by pattern, mechanics, laterality, difficulty and equipment; sort by name, muscle, recently used and favourites; favourites per user; "variations of this exercise" navigation; instruction display.
8. **Localisation readiness**: names, aliases and content keyed by locale; English as the only shipped locale until decided.

Schema impact: one schema version (v8) adds reference and relationship tables and columns; additive, following the v6/v7 migration discipline. Existing exercise ids, stored set data and WP 9 contracts are preserved.

## 4. Work packages (structure approved 2026-11-05)
Governance revised 2026-11-05: the workstreams below are **WP 8 stages 3–6 and a deferred media workstream**, not a separate package. WP 9 unchanged. (Earlier labels 16a–16e shown for traceability.)

| Sub-package | Content | Acceptance (proposed) |
|---|---|---|
| Stage 3 (was 16a) Architecture and Reference Data | ADR for the library model; hierarchical anatomy, movement pattern, mechanics, laterality, difficulty, equipment additions; variation relationships; content sections and media references; favourites; catalogue versioning with update/retire; schema v8 migration; domain rules and tests. Supersedes the flat lists in `docs/training-taxonomy.md` by extension (identifiers kept) | Model and migration tests; existing data and WP 9 flows unchanged; ADR approved |
| Stage 4 (was 16b) Catalogue Tooling and Quality Assurance | Catalogue source format (versioned, reviewable text), import with update/retire, integrity tests (duplicates, aliases, graph, completeness), coverage report generated from the catalogue, editorial guide (naming, variation rules, instruction style), licence register | Integrity tests run in CI; coverage report in the record |
| Stage 5 (was 16c) Anatomical Catalogue Population (tranches by region) | Chest; back; shoulders; arms (biceps, triceps, forearms); hips and legs (quadriceps, hamstrings, glutes, adductors, abductors, calves); trunk (abdominals, obliques, lower back); conditioning and mobility. Each tranche: compound and isolation, unilateral and bilateral, free weight, machine, cable, Smith machine, band, kettlebell and bodyweight where legitimate; instructions for every exercise | Per tranche: coverage matrix meets agreed minimums; zero integrity failures; owner content review |
| Stage 6 (was 16d) Search, Discovery and Exercise Screens | Extended filters and sorting, favourites, variations navigation, instruction sections, media placeholders, custom exercises with the new fields | Widget and integration tests; accessibility as WP 8/9 |
| Media workstream (was 16e, deferred) | Images and video display, storage and licensing | Outside final WP 8 acceptance; enabled by stage 3 references |


## 5. Owner decisions (2026-11-05) — recorded in D04 §7
| # | Question | Decision |
|---|---|---|
| 1 | Engineering Objects | First-class persistent domain entity: stable identity; defined type and schema; explicit source and provenance; validation and integrity constraints; creation and modification metadata; defined relationships; lifecycle-appropriate versioning; persistence, query, backup and restore. Not every object needs its own version history or table. Exercises are persistent entities, not disposable entries |
| 2 | Content source (OQ-09) | Original RepForge-authored content; compatible openly licensed datasets allowed with recorded provenance; no Bodybuilding.com content (benchmark only); multiple providers supported; commercial licensing deferred |
| 3 | Anatomy | Four levels: L1 region, L2 muscle group, L3 anatomical muscle, L4 subdivision or head; tag at the most meaningful defensible level; multiple primary and secondary targets; existing exercise ids and the 19 muscle-group ids preserved; no qualitative classification presented as precise biomechanics |
| 4 | Difficulty | Beginner (simple movement, stable setup, straightforward execution); Intermediate (moderate coordination, technique or control); Advanced (high technical demand, stability or complex execution). Describes technical complexity, not load or fitness |
| 5 | Relationships | Variation of; progression of; regression of; alternative to; unilateral counterpart. Validated, directional where appropriate, protected against circular or invalid references. Not programme functionality |
| 6 | Coverage acceptance | Structured coverage matrix is the formal acceptance mechanism for catalogue population (now WP 8 stage 5): anatomy, diversity, compound/isolation, unilateral/bilateral, movement patterns, equipment, difficulty distribution, variation depth; minimum targets per region defined before population; explicit gap report; raw count insufficient |
| 7 | Languages | English (UK) first; localisation without duplicating identities or records; translation deferred |
| 8 | Governance | ~~WP 16 separate; WP 8 not reopened or renumbered~~ **superseded 2026-11-05**: scope incorporated into WP 8, which stays active; no WP 16. Still valid: WP 9 scope unchanged; WP 10/11 inspected; unrelated work not blocked; no WP 8A–8E renumbering |
| 9 | Structure | 16a–16e approved, **re-organised 2026-11-05 as WP 8 stages 3–6 and a deferred media workstream**; schema v8 approved as target subject to architectural review; ids preserved |
| 10 | Additional | Separate system-supplied, user-created and imported exercises; catalogue updates never silently overwrite user customisations; idempotent import/update; provenance, validation, duplicate detection, integrity reporting; discovery by anatomy, equipment, pattern, classification and difficulty; accommodate future metrics, tempo, range of motion, execution guidance and recommendations outside current acceptance |

## 6. Expanded WP 8 requirements and stage acceptance criteria
Requirements: LIB-001..LIB-010 (§1) and decisions 1–10 (§5). Additional derived requirements:
- LIB-011 Source separation (system, user, imported) and provider provenance with licence.
- LIB-012 Idempotent, versioned catalogue import and update; retire instead of delete; user-owned data never overwritten.
- LIB-013 Duplicate detection and integrity reporting in CI.
- LIB-014 Localisation-ready identity and content (`en-GB` first).

| Sub-package | Acceptance criteria |
|---|---|
| Stage 3 | As `docs/wp8-delivery-plan.md` §11 (model, schema v8 migration preserving ids and data, reference data structure, targets, classifications, relationships, content and media references, providers and releases, user state, integrity report, unchanged WP 8/9 behaviour, CI green) |
| Stage 4 | Catalogue source format and editorial guide (naming, variation rules against superficial variants, instruction style for setup, execution, breathing, common mistakes; anatomical tagging guidance); licence register; integrity checks and coverage report generated in CI; **coverage matrix with measurable minimum targets per region, approved by the owner before stage 5 starts** |
| Stage 5 | Per regional tranche: coverage matrix minimums met (anatomy, diversity, compound/isolation, unilateral/bilateral, patterns, equipment incl. free weights, machines, cables, Smith machine, bands, kettlebells, bodyweight, difficulty distribution, variation depth); instructions for every exercise; zero integrity failures; explicit gap report; owner content review |
| Stage 6 | Search by name and aliases; filters by anatomy node (with descendants), equipment, movement pattern, mechanics, laterality, difficulty, logging type; sorting; favourites; variations and relationship navigation; instruction sections; custom exercise creation with the new fields; accessibility as WP 8/9; widget and integration tests |
| Media | Deferred: display, storage and licensing; outside final WP 8 acceptance; stage 3 provides references. Final WP 8 acceptance criteria: `docs/wp8-delivery-plan.md` §15 |

## 7. Sequencing (WP 10 and WP 11 inspected)
- WP 10 (body composition) depends on WP 3 and WP 4 only and shares no data with the library work: **not blocked**; it can run before, after or alongside WP 8's remaining stages. Only schema version numbers need coordination.
- WP 11 (analytics) depends on WP 5, WP 9, WP 10 and reports training volume, including per muscle group (TRN-027 reporting proposed for WP 11). Per-muscle reporting should follow WP 8 stage 3 so it is built once on the new anatomy: **soft dependency WP 8 stage 3 → WP 11 (training-volume parts only)**.
- WP 13 (health integrations): no dependency.
- WP 11 depends on WP 8's expanded anatomy and exercise taxonomy for training analytics (owner, 2026-11-05).
- Order: WP 9 delivery (in progress) → WP 8 stage 3 → stage 5 tranches with stage 6 → WP 8 final acceptance → WP 11. WP 8 stage 4 documents and lists can proceed now; WP 10 may run in parallel. Media deferred.

## 8. Open questions and dependencies
| ID | Item | Status |
|---|---|---|
| OQ-19 | Volume attribution when an exercise has several primary targets (TRN-027) | **Approved 2026-11-05**: full recorded exercise-set count to each primary target; secondary separate and excluded; set counts, not physiological measurements |
| OQ-20 | TRN-010(1) wording ("exactly one primary group") versus decision 3 (multiple primary targets) | Amended by decision 3; wording update recorded in D04 §7 |
| OQ-21 | Definition of "imported" exercises | **Approved 2026-11-05**: brought in by a user from an external file, application or user-controlled source; open datasets in the catalogue are system content |
| OQ-22 | Anatomy node list and movement pattern list | Open; proposed in WP 8 stage 4, approved before stage 5 |
| OQ-23 | Coverage matrix minimum targets per region | Open; defined in WP 8 stage 4, approved before stage 5 |
| — | Earlier WP 8 decisions | 1 taxonomy: folded into decision 3 and OQ-22; 2 OQ-09: answered; 3 legacy values, 4 TRN-020 and 5 screen ownership: **approved 2026-11-05** (D04 §7) |
| — | OQ-19 kg-volume attribution under TRN-027(3) | Clarification requested (D04 §7) |
| — | Schema version coordination with WP 10 | Coordination at WP 8 stage 3 start |
