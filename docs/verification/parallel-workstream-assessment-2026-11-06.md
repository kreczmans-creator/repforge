# Parallel workstream — baseline assessment and implementation plan

Status: Assessment (repository-grounded), 2026-11-06
Workstream: Fuel recipe library, workout library and free-workout capability
Branch: `claude/repforge-parallel-implementation-flyjqw`
Baseline commit: **0d912c2** (tip of the primary session's branch `ccr-9fda2c32-wr163b` at 17:48 UTC, 2026-11-06)

This document is the first deliverable of the secondary implementation session. Every statement below was checked against the repository at the baseline commit, not against conversational summaries. Nothing in this document changes any acceptance status.

## 1. Branch and commit

| Item | Value |
|---|---|
| Own branch | `claude/repforge-parallel-implementation-flyjqw` (name fixed by the session harness; the brief's suggested `feature/fuel-recipes-workout-library` is not used) |
| Baseline | `0d912c2` = `origin/ccr-9fda2c32-wr163b` |
| `origin/main` | `30e51b0` (WP 0 and WP 1 only; 157 commits behind the primary branch). Main is **not** the latest work. |
| Other remote branches | `ccr-ac6db77c-jcnexo` (WP 2–5 era, fully contained in the primary branch), `ccr-a85afdba-q0n0zq` (design-system artwork, 2026-11-02, superseded), `claude/ai-coordination-infrastructure-pcf8bb` (coordination docs, 2026-11-05, merged the primary branch at that date). None carries unmerged implementation of recipes, plans or sessions. |
| Working tree at branch creation | clean |

## 2. Primary session conflict assessment

The primary session is `ccr-9fda2c32-wr163b`. Its last 30 commits (2026-11-06) are all WP 8 stage 3b: isolated schema v8, historical migration steps, migration report, process-kill and timing harnesses, CI recovery job.

Files it touches repeatedly (since 2026-11-05): `docs/wp0/D04`, `docs/wp0/D05`, `docs/wp0/D06`, `docs/delivery-record/WP8.md`, `docs/wp8-delivery-plan.md`, `docs/schema-v8.md`, `docs/device-timing.md`, `.github/workflows/ci.yml`, `app/dart_test.yaml`, `app/lib/domain/library/**`, `app/lib/data/db/**` (including `v8/` and `migration/`), `app/test/domain/library/**`, `app/test/migration_v8/**`, `app/test/architecture/**`, `app/drift_schemas/**`.

Rules this workstream applies:

- **No schema change.** `tables.dart` is shared by live v7 and isolated v8; CI byte-compares a fresh v8 dump against `drift_schema_v8.json`. Any table or column change here breaks the primary session's gate. Schema v8 belongs to WP 8; a v9 is not feasible until v8 is connected and accepted.
- **No edits** to `app/lib/data/db/**`, `drift_backup_repository.dart`, `app/drift_schemas/`, `test/data/generated_migrations/`, `ci.yml`, `dart_test.yaml`, `app/lib/domain/library/**`.
- **Registers (D04 §7, D05, D06, WP8.md)**: not edited on this branch. Required register entries are listed in §14 and will be applied at the integration gate, where the owner's decisions are recorded in one place.
- Own files live in `docs/verification/`, `docs/delivery-record/WP15.md`, `app/lib/domain/units/`, `app/lib/features/nutrition/**`, `app/lib/features/recipes/**` and their tests, none of which the primary session has touched since 2026-11-05.

Conclusion: independent work is safe for non-schema changes in the nutrition, recipe and training feature layers. Anything needing a table or column waits for the v8 switch and an owner decision (§14).

## 3. Programme baseline

| WP | Status at baseline | Commit |
|---|---|---|
| WP 0–6 | accepted (WP 6 conditionally; device checklist and V-01 open) | — |
| WP 7 Recipes and meal planning | **accepted and closed** 2026-11-05 | 7c62e9c |
| WP 8 Exercise library (expanded) | **active**; stages 1–2 built, not accepted; stage 3a built; stage 3b in progress (3b-1 accepted as foundation, 3b-2 and 3b-3 committed, 3b-4 to 3b-10 outstanding); stages 3c, 3d, 5, 6 not started | 0d912c2 |
| WP 9 Workout planning and execution | **accepted and closed** 2026-11-06 | 0c35ef1 |
| WP 10 Body composition | accepted and closed 2026-11-05 | bb5f788 |
| WP 11–14 | not started (WP 14 continuous) | — |
| WP 15 Nutrition entry units | **allocated 2026-11-04, not started**; no delivery record, no code | — |
| WP 16 | superseded; no replacement is created | — |

Live schema: v7. Backup format: 2. Tests at WP 9 closure: 1186, coverage 91.5 %.

## 4. WP 7 — implementation and acceptance status

Closed. Requirements RCP-001 to RCP-015 are all met and accepted. What exists, mapped to the brief (§4.1, §4.2):

| Brief item | State | Where |
|---|---|---|
| Recipe lives inside Fuel, no separate tab | **met** | `/fuel/recipes…` routes; Fuel screen buttons Log food, Saved meals, Recipes, Meal plan |
| Manual add food, search database | met (WP 5) | `food_search_screen.dart`, `custom_food_screen.dart` |
| "Pick from library" entry and recent/saved recipes inside the food-search flow | **gap** | recipes are reached from the Fuel screen, not from the search screen; recent/frequent foods (NUT-014) never allocated |
| Create recipe | met | `recipe_editor_screen.dart`, `SaveRecipe` |
| Name, description, ingredients with food references, g/ml quantities, prep and cook steps, prep and cook minutes, yield | met | `domain/recipes/recipes.dart` |
| Categories and tags | **partial**: one free-text `category`; no tags, no category filter | schema change for tags |
| Optional image | **gap**; D04 OQ-04 open (owner question) | schema and storage design |
| Calculated nutrition from ingredients, NUT-017 | met (spec rev 1.3, 41 executed examples) | `Recipe.perPortion` |
| Yield X portions; 0.5 / 1 / 1.25 / 2 portion scaling of every nutrient; missing values preserved | **met** | `nutritionForPortions`, `Quantity` 0.01 portion step |
| Log recipe: portions (fractional), meal, date; entry keeps recipe id, quantity, nutrient snapshot, provenance; history immune to recipe edits (RCP-013) | **met**, tested at unit, widget and emulator level | `LogRecipe`, `recipe_log_sheet.dart`, `FoodLogEntry.recipeId` |
| Create, edit, delete, favourite | met | editor, `DeleteRecipe`, `ToggleFavourite` |
| Duplicate | **partial**: only "save as new" from the scaled view | no stand-alone action |
| Search and filtering | partial: text search and favourites filter; no category filter | `recipe_list_screen.dart` |
| Provenance labels | met | `estimated` on seed recipes; weakest-provenance rule |

## 5. Original 22-recipe catalogue — location and integrity

**Located and intact.** `app/assets/seed/legacy_recipes.json`: 22 recipes, `formatVersion` 1, `source` = `legacy/android/.../MainActivity.kt defaultStarterRecipes()` at aac5f15, extracted by `app/tool/extract_legacy_recipes.dart` (commit 266d4a2). Each recipe carries a fixed id `starter-…`, name, category, description, portions, per-portion kcal/protein/carbs/fat, ingredient lines, method steps, legacy freezer flag and a nutrition note. No fibre values exist in the source; none are invented.

Seeding: `ImportLegacyRecipes` runs once at startup (gate `settings.seedRecipesVersion` = 1), skips any id that exists (including soft-deleted rows), rejects the whole file on one invalid entry, and never overwrites user content. Imported recipes are ordinary rows: offline, searchable, backed up, with `estimated` provenance and freezing `unknown` (owner decision 2026-11-04).

Brief items not met: **protection against modifying the canonical seed recipes** does not exist. The accepted WP 7 behaviour is the opposite by design: the owner decided the seed recipes stay `estimated` until the user replaces every ingredient note with a linked ingredient, which requires editing them. This is an owner decision (§14, D-3). "Full recipe details with ingredient quantities" is limited by the source: the legacy data has free-text ingredient lines, not food-linked quantities.

## 6. WP 8 — implementation and stage status

Stages 1–2 (schema v6, 89-exercise seed `exercise_library.json`, Train-tab library, detail with history, custom exercise editor) built and reviewed, **not accepted**. Stage 3a (pure library domain) built; stage 3b in progress on the primary branch (see §2 and `docs/delivery-record/WP8.md`). The canonical exercise entity is `Exercise` with string ids such as `lib-back-squat`; sessions and plans reference `exerciseId`. This workstream creates no second exercise catalogue and does not touch exercise ids, taxonomy or the library domain.

Stage 3d will adapt WP 8/WP 9 training code to typed ids. Training-feature changes made by this workstream before 3d land must be small, confined to `features/training/**`, and re-based against 3d at the integration gate.

## 7. WP 9 — implementation and stage status

Closed at 0c35ef1. Mapped to the brief:

| Brief item | State |
|---|---|
| Templates (brief §4.4, §4.5) | `WorkoutPlan` + `PlanExercise` **is** the template model (standards §2: *plan* = template). Create, edit, reorder (drag and move buttons), archive/restore, start from plan, pre-fill from last performance: **met**. Prescribed values live only on `PlanExercise`; sessions store performed values only, so editing a plan never changes history: **met**. |
| Template duplicate, delete UI, "save session as plan" | **gap** (repository `delete` exists, no use case or UI) |
| Template metadata: description, category, target muscles, difficulty, equipment, estimated duration, RPE/RIR targets, per-exercise instructions | **gap — needs columns** (schema) |
| Prebuilt workout catalogue (30) and a searchable, filterable library | **gap**; no workout seed exists; needs the metadata columns above and a seed importer |
| Free workout (brief §4.6) | **met**: `StartEmptySession`, searchable `exercise_picker`, `AddSessionExercise`, `RemoveSessionExercise`, `ReplaceSessionExercise`, `ReorderSessionExercises`, independent sets with kind, RPE/RIR, rest, note; rest timer (pause, +15 s, skip, notification); `RecordSet` persists every set at once; `FindUnfinishedSession` and the "continue" card recover an interrupted session; `FinishSession`. A user completes a valid workout without touching plans. |
| Free workout gaps | elapsed-time display (duration is derived from start/end only), drag reorder in the session screen (buttons only), rest-timer state lost on process death |
| History (brief §4.7) | **met**: date, start/end, duration, ordered exercises, sets, kind, exertion with scale, notes; previous performance; exercise history (capped at 20 sessions — paging allocated to WP 8 stage 6); PRs derived per type; per-entry and per-session volume; soft delete with undo |
| History gaps | per-muscle and per-week volume screens (WP 11), progression charts TRN-028 (unallocated), assisted/cardio PR definitions (requirements gap) |

## 8. WP 15 — implementation and status

Roadmap entry only (D06). Scope NUT-022: kg, l and mg entry converted exactly to canonical g/ml (spec §2.3), applied to food logging, portion sheets and recipe ingredients; validation and display; decision on imperial input units (OQ-02, owner); no mass↔volume conversion without a stated density (NUT-022(2)).

Code today: `Quantity` stores g, ml or portions; `UnitConversion` has display-only imperial constants; **no kg, l or mg entry path, no density field, no imperial entry**. Spec §2.3 says these rules "have no code and no executed example; they bind the first package that adds such entry."

Brief §5 items beyond NUT-022: named servings exist on custom foods only (`ServingSize`, NUT-009 partial); ingredient servings are display-only; density-aware conversion needs a `density` field (schema) and an owner decision. The brief's "do not create competing conversion frameworks" is honoured by extending `domain/units/units.dart` and `Quantity`.

## 9. Schema and migration implications

Live v7; v8 isolated and owned by WP 8 (not connected; connecting it needs separate owner authorisation after 3b acceptance). Adding a version requires: bump `schemaVersion`, an `onUpgrade` step, a schema dump, generated migration classes, a migration test (ADR-0004) and, since 3b-1, respect for the frozen fixtures and digests. The next version number belongs to WP 8.

Items from the brief that need schema and are therefore **deferred to after the v8 switch**: recipe tags, recipe image, plan metadata (description, category, difficulty, equipment, estimated duration, RPE/RIR targets, per-exercise instructions), prebuilt-plan provenance flag, food density, named servings on foods from the database. The brief's "strict separation of definitions from history" already holds in v7 (loose references from history to exercises and plans; cascades only within a definition or within a session).

## 10. Backup and restore implications

Format 2 exports every table in `_db.allTables`, so new rows in existing tables (user recipes, plans, sessions, sets) are already backed up; seeded recipes and exercises are plain rows and are included; `seed*Version` settings restore with them so seeds do not re-run. Restore wipes and re-inserts in one transaction, refuses newer formats, and maps older rows. A hardcoded table list in `drift_backup_repository_test.dart` pins the table set. Format 3 (reference tables not wiped, device wins, foreign-key check) is WP 8 3b-7 and in flight. This workstream changes **no** backup semantics. CSV export exists for measurements only; nutrition or training CSV would be new scope (owner decision).

## 11. Requirements gap analysis (brief vs repository)

Already delivered and accepted (no work): recipe yield and fractional-portion logging with snapshots; recipe CRUD inside Fuel; 22-recipe seed with idempotent import; free workout end to end; template create/edit/reorder/start; history, PRs, volume; definition/history separation.

Gaps, by whether they need schema:

| # | Gap | Schema? | Host WP today | Priority (brief) |
|---|---|---|---|---|
| G1 | kg / l / mg entry (NUT-022) in portion sheet, ingredient sheet, custom food | no | **WP 15 (open)** | P2 |
| G2 | Imperial entry units decision and entry (OQ-02) | no | WP 15, owner decision | P3 |
| G3 | Recipe "Pick from library" and recents inside the Fuel add flow | no | none (WP 7 closed) | P2 |
| G4 | Recipe duplicate action; category filter | no | none (WP 7 closed) | P3 |
| G5 | Plan duplicate, plan delete UI, save session as plan | no | none (WP 9 closed) | P3 |
| G6 | Session elapsed-time display; drag reorder in session; rest-timer survives process death | no | none (WP 9 closed) | P2–P3 |
| G7 | Plan metadata columns; prebuilt-plan marker | **yes** | none | P2 |
| G8 | 30-workout catalogue (content) referencing `lib-…` ids; importer; library UI with search and filters | after G7 | none | P2 |
| G9 | Recipe tags, optional image (OQ-04) | **yes** | none | P3 |
| G10 | Named servings for database foods; density-aware conversion | **yes** + owner decision | WP 15 extension | P3 |
| G11 | Protect canonical seed recipes from edit | conflicts with WP 7 decision | owner decision | — |
| G12 | Nutrition and training CSV export | no (new scope) | WP 14 / owner | P4 |

## 12. Proposed isolated implementation sequence

Each stage has its own tests, a delivery-record section and an independent review before the next starts. Stages marked ⏸ need an owner decision first (§14).

| Stage | Content | Conflicts with primary | Gate |
|---|---|---|---|
| S0 | This assessment; branch and baseline reported | none | owner reads |
| S1 | **WP 15 stage 1** — `EntryUnit` (g, kg, mg, ml, l) with exact conversion to canonical `Quantity`; spec §2.3 examples as executed tests; `docs/delivery-record/WP15.md` opened | none | unit tests; review |
| S2 | **WP 15 stage 2** — unit selector in `portion_sheet.dart`, `ingredient_sheet.dart`, `custom_food_screen.dart`; display stays canonical; widget tests | none | widget tests; review |
| S3 ⏸ | G3 + G4: Fuel add flow gains "Pick from library" (recipes, saved meals) and recent items; recipe duplicate and category filter | none (features/recipes, features/nutrition) | owner allocation (D-1) |
| S4 ⏸ | G5 + G6: plan duplicate/delete, save session as plan, elapsed timer, drag reorder, rest-timer persistence | low (features/training only; re-base after 3d) | owner allocation (D-1) |
| S5 ⏸ | G8 content: 30-workout catalogue drafted as a seed asset validated against the 89 exercise ids (pure test, no import) | none | owner content review (D-4) |
| S6 ⏸ | G7 + G8 + G9 schema: plan metadata, prebuilt marker, recipe tags/image, importer and library UI | **high** — waits for v8 switch; coordinated version number | owner (D-2, D-5) |
| S7 | Integration gate: re-base on primary, full regression, register entries (§14), independent review | — | owner acceptance |

S1 starts now. S2 follows S1 review. S3–S6 wait for the decisions in §14.

## 13. Estimated effort

Given in stages of the established cycle, not days: S1 small (1 stage), S2 small (1), S3 medium (1–2), S4 medium (2), S5 content-heavy medium (1 plus owner review), S6 large (3, after v8), S7 medium (1). Total: 10–12 stages, of which 2 can start now without any decision.

## 14. Risks and owner decisions required

Decisions:

- **D-1 Host work package for non-schema additions to closed WP 7 and WP 9** (G3–G6). Options: (a) a new WP 17 "Fuel and Train workflow completion" with a D04 §7 allocation and D06 entry; (b) fold into WP 15 (recipes side) and WP 11 (training side) by allocation. Recommendation: (a), one package with two stages, because WP 11 is analytics and WP 15 is units.
- **D-2 Schema sequencing** for plan metadata, prebuilt marker, recipe tags and image (G7, G9). Options: add to v8 before 3b acceptance (touches the primary session's schema and frozen dumps — not recommended), or a v9 after v8 is connected and accepted. Recommendation: v9, owned by the package from D-1.
- **D-3 Canonical seed recipes**: keep editable (WP 7 decision, estimated-until-linked) or make read-only with "copy to edit" like supplied exercises. The brief asks for protection; the accepted behaviour disagrees.
- **D-4 Workout catalogue content**: 30 plans across 10 categories are a content target. Confirm that the 89 current exercises are the only allowed references (stage 5 of WP 8 will add more), and who reviews the content.
- **D-5 Imperial entry (OQ-02)** and **density** (NUT-022(2)): which imperial units, if any; whether a food may carry a density.
- **D-6 Recipe image (OQ-04)**: device-only storage and backup size.
- **D-7 CSV export of nutrition and training** (brief §7): new scope or not.

Risks:

- R-A WP 8 stage 3d refactors training code; any S4 change must be re-based and re-tested after 3d. Mitigation: S4 waits for D-1 and stays in `features/training/**`.
- R-B Register files (D04, D05, D06) are edited daily by the primary session; parallel edits would conflict. Mitigation: register entries applied at S7 only.
- R-C `flutter` is not installed in this container; a pinned 3.47.9 SDK was installed locally to run the suite. CI remains the evidence of record.
- R-D The brief's expectations for recipe "ingredient quantities" on the 22 seed recipes cannot be met from the source data without inventing quantities, which is forbidden.

## 15. Stop conditions checked

- Primary session modifying the same files: avoided by §2 rules.
- Active branch established: yes (`ccr-9fda2c32-wr163b`).
- Requirement conflicts: D-3 (seed protection) — reported, not improvised.
- Closed WP reopening: not done; D-1 raised.
- Original catalogue located: yes.
- Exercise identifiers: untouched.
- Backup behaviour: unchanged.
- Data-integrity issue: none found in this scope (TD-44 is WP 8's, already handled).
