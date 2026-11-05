# Exercise catalogue — WP 8 stage 4 outputs

- Status: **Proposed — for owner approval.** Nothing in this folder is implemented or in force until the owner approves it.
- Scope: WP 8 stage 4, catalogue tooling and quality assurance, **documentation and reference data only** (authorised 2026-11-05, `docs/wp8-delivery-plan.md` section 18). No file under `app/` changes. No WP 9 file is touched.
- Date: 2026-11-05.
- Requirements: LIB-001..LIB-014, owner library decisions (D04 section 7; `docs/exercise-library-expansion.md` section 5), ADR-0008, ADR-0009.

## 1. Contents
| File | What it holds | Feeds |
|---|---|---|
| `reference/anatomy.json`, `anatomy.md` | Four-level anatomy hierarchy: ids, parents, definitions, inclusion and exclusion criteria, notes | Stage 3 (anatomy node table, hierarchy validation); stage 5 (tagging); stage 6 (filters) |
| `reference/movement-patterns.json`, `movement-patterns.md` | Family and pattern list with definitions, inclusion and exclusion criteria | Stage 3 (pattern table); stage 5; stage 6 |
| `reference/equipment.json`, `equipment.md` | The 21 existing equipment ids unchanged, ten proposed additions, equipment classes | Stage 3 (equipment table); stage 5; coverage tool |
| `mapping-existing.md`, `mapping-existing.json` | The 19 muscle ids, the 89 seed exercises (proposed targets and patterns, with flags) and the seven categories, mapped to the new lists | Stage 3c (release 2: the 89 exercises re-expressed); stage 5 enrichment |
| `editorial-guide.md` | Naming, variation rules, relationships, tagging, difficulty, mechanics and laterality, instruction style, worked example | Stage 5 authors and reviewers; stage 3c tool rules |
| `coverage-matrix.md` | Derivation of the minimums from the anatomy, the minimums, the baseline from the seed and the gap report format | Stage 5 acceptance; CI coverage report |
| `population-standards.md` | Tranche plan 5.1 to 5.7, definition of done, review workflow, keeping and enriching the 89, retirement | Stage 5 |
| `provenance-and-licensing.md` | Provider registry, original-authoring rules, admission criteria for open datasets, prohibited sources, licence register template | Stage 3 (provider table); stage 5 |
| `quality-and-duplicates.md` | Integrity checks, duplicate detection, report format, CI gating, legacy and migration report | Stage 3a and 3c (check code, CI gate) |

## 2. Open questions these outputs answer
| Id | Question | Where answered | Owner action |
|---|---|---|---|
| OQ-22 | Anatomy node list and movement pattern list | `anatomy.md`, `movement-patterns.md`, `mapping-existing.md` | Approve, change or reject before stage 5 |
| OQ-23 | Coverage matrix minimum targets per region | `coverage-matrix.md` | Approve, change or reject before stage 5 |

Both lists carry definitions, inclusion and exclusion criteria, so the reviewer can see where a muscle with two functions is filed.

## 3. How the outputs feed the stages
- **Stage 3 (architecture and reference data, gated):** loads `reference/*.json` into the reference tables; implements the checks in `quality-and-duplicates.md`; re-expresses the 89 exercises as release 2 using `mapping-existing.json`; builds the migration report specified there. The JSON files are the proposed content of catalogue release 2's reference data.
- **Stage 5 (population):** authors work from the editorial guide, tag against the reference lists, and are accepted against the coverage matrix. Population does not start until the owner approves OQ-22 and OQ-23.
- **Stage 6 (discovery):** filters use the same lists. Labels are display text and may be reworded.

## 4. Summary of the proposal
- Anatomy: 133 nodes (10 L1, 26 L2, 67 L3, 30 L4). All 19 existing ids are kept at the planned levels and with the planned parents.
- Movement patterns: 17 families, 61 patterns.
- Equipment: 21 existing ids unchanged, 10 proposed additions (one conditional).
- Coverage: minimums for 21 anatomical groups, derived from function slots, plus conditioning and mobility sets. The seed meets none of the group minimums.
- Rules that cut across all documents: original content only; qualitative anatomy; per-muscle figures are *attributed set counts*, not physiological measurements; retired exercises are never deleted and their ids are never reused; every historical reference must resolve.

## 5. Decisions requested from the owner
1. Approve the anatomy list (`anatomy.md`), including the debatable classifications in section 5 of that file.
2. Approve the movement pattern list and the borderline classifications.
3. Approve the equipment additions (ten, one conditional).
4. Approve the mapping of the 89 existing exercises and decide the primary-target questions flagged D and M (these change attributed set counts).
5. Approve the coverage minimums (OQ-23) and decide whether the pilot tranche runs first.
6. Approve the editorial guide, population standards, provenance rules and quality specification.
7. Answer the open questions listed at the end of `coverage-matrix.md`, `provenance-and-licensing.md` and `quality-and-duplicates.md`.

## 6. Not in scope
Catalogue content beyond the example in the editorial guide, code, schemas, assets, tests, screens, media and translation.
