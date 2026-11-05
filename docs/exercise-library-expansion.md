# Exercise library expansion — gap analysis and work-package proposal

- Status: **Proposed for owner approval** (2026-11-05). Responds to the owner's "Exercise Library Scope Amendment" (recorded in D04 §7, 2026-11-05).
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

## 4. Proposed work packages
Keep WP 9 unchanged. Add **WP 16 — Exercise library expansion**, after WP 9 delivery, in sub-packages:

| Sub-package | Content | Acceptance (proposed) |
|---|---|---|
| 16a Architecture and reference data | ADR for the library model; hierarchical anatomy, movement pattern, mechanics, laterality, difficulty, equipment additions; variation relationships; content sections and media references; favourites; catalogue versioning with update/retire; schema v8 migration; domain rules and tests. Supersedes the flat lists in `docs/training-taxonomy.md` by extension (identifiers kept) | Model and migration tests; existing data and WP 9 flows unchanged; ADR approved |
| 16b Catalogue tooling and integrity | Catalogue source format (versioned, reviewable text), import with update/retire, integrity tests (duplicates, aliases, graph, completeness), coverage report generated from the catalogue, editorial guide (naming, variation rules, instruction style), licence register | Integrity tests run in CI; coverage report in the record |
| 16c Catalogue content, in tranches by region | Chest; back; shoulders; arms (biceps, triceps, forearms); hips and legs (quadriceps, hamstrings, glutes, adductors, abductors, calves); trunk (abdominals, obliques, lower back); conditioning and mobility. Each tranche: compound and isolation, unilateral and bilateral, free weight, machine, cable, Smith machine, band, kettlebell and bodyweight where legitimate; instructions for every exercise | Per tranche: coverage matrix meets agreed minimums; zero integrity failures; owner content review |
| 16d Discovery and detail UI | Extended filters and sorting, favourites, variations navigation, instruction sections, media placeholders, custom exercises with the new fields | Widget and integration tests; accessibility as WP 8/9 |
| 16e Media (deferred) | Images and video display, storage and licensing | Not scheduled; enabled by 16a |

Proposed order: WP 9 → 16a → 16b → 16c tranches and 16d in parallel → WP 10. Owner may reorder against WP 10–11.

## 5. Decisions needed from the owner
1. **"Engineering Objects"**: the term is not defined in RepForge documents. Proposed reading: first-class domain entities with a stable identifier, provenance (supplied/custom), versioning and validation rules. Please confirm or define.
2. **OQ-09 content source and licence** (open since WP 8): own authored content, an openly licensed dataset (licence and attribution obligations recorded), or a commercial licence. Content from Bodybuilding.com or any other proprietary app must not be copied; "comparable in breadth" is read as a scope benchmark only.
3. **Taxonomy depth**: anatomy levels (region › group › muscle/head) and the level at which exercises are tagged. This extends WP 8 decision 1 (taxonomy approval); WP 8's 19 identifiers would be kept as nodes.
4. **Difficulty**: scale (e.g. beginner/intermediate/advanced) and the criteria that place an exercise, so it is not arbitrary.
5. **Variation relation kinds**: confirm the kinds; confirm whether "progression/regression" links are wanted (they are relationships, not programmes).
6. **Coverage acceptance**: approve a coverage matrix (per muscle node × equipment class × mechanics/laterality minimums) instead of a raw count.
7. **Localisation**: which locales, and when.
8. **Numbering and sequencing**: WP 16 with sub-packages 16a–16e (alternative: WP 8A–8E); position relative to WP 10 and WP 11.
9. **WP 8 status**: WP 8 stays as delivered for its D06 scope and awaits acceptance; the amendment is delivered by WP 16 and does not reopen WP 8.
