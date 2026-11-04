# Delivery record — WP 7: Recipe management and meal planning

Date: 2026-11-04
Branch: `ccr-9fda2c32-wr163b`
Status: **in progress** (authorised by the owner 2026-11-04 while WP 6 device testing is pending; WP 7 depends on WP 5, which is accepted by owner decision. If D05 V-01 fails and WP 5 reopens, WP 7 work that builds on the affected code is re-checked.)

## Scope (D06 WP 7)
Recipe CRUD; ingredients with quantities linked to foods; per-portion nutrition computed from ingredients (not typed in); portion scaling; prep/cook/storage/freezing/reheating fields; favourites; substitutions; seed import of the 22 legacy recipes flagged `estimated`; log a portion to the diary; weekly meal plan and prep list (P2); NUT-011 meal rename/reorder (owner allocation 2026-11-04).
Acceptance (D06): computed per-portion nutrition matches hand-calculated fixtures; seed recipes visible with the `estimated` label; RCP P1 criteria pass. Verification: unit tests for recipe maths; widget tests.

## Prerequisite: NUT-017 calculation specification
The owner allocated NUT-017 to be done "before further nutrition calculation work". Delivered first as `docs/nutrition-calculation-spec.md` (draft for owner approval) with 37 worked examples executed as tests. Writing it exposed one defect, fixed in 2d735a7: recipe provenance ignored the approved `crowdsourced` label (verified + crowdsourced ingredients were reported as user-entered); a shared `weakestProvenance` rule now implements the approved order verified › crowdsourced › user-entered › estimated.

## Decisions (made under stated assumptions; owner confirmation requested at delivery)
1. **Carbohydrate convention (OQ-14)**: the specification records current behaviour (carbohydrate as stated by the source, fibre separate, never added or subtracted) and recommends the EU/UK convention. Owner decision required; WP 7 does not depend on the answer because recipes sum carbohydrate as stated.
2. **Schema v5** in one migration: recipe portions become a real number (RCP-008(2) derived portion counts may be fractional); separate preparation and cooking step lists (RCP-003; existing single-list steps migrate to the cooking list); freezing suitability yes/no/unknown, default unknown (RCP-005); total cooked weight and portion weight (RCP-008(2)); optional serving label and count on ingredients (RCP-002 "defined serving"); free-text ingredient notes for imported recipes; ingredient substitutions table (RCP-010); meal-plan items and prep batches tables (RCP-014, RCP-015). Idempotent and re-runnable like v1–v4.
3. **Legacy seed recipes**: the 22 recipes are extracted once from `legacy/android/.../MainActivity.kt` into a committed JSON asset and imported on first launch after the upgrade (fixed ids, so a deleted seed is not re-created). Their ingredient lists are free text that cannot be linked to foods reliably, so they are kept as **ingredient notes**; their nutrition is the **declared** legacy estimate, labelled **estimated**, with the original note. Their legacy "freezer friendly" flag is imported as **unknown**, not yes, because D04 RCP-005 forbids implying a safety claim (OQ-13); the original method text, which mentions freezing, is kept. The user can link ingredients later, which turns the recipe into a computed one.
4. **RCP-002 interpretation**: every ingredient the user adds references a food and a quantity in g, ml or a defined serving. Text-only ingredient notes exist only on imported recipes whose nutrition is declared; they are never used for calculation.
5. **NUT-011**: the four meal slots stay as storage keys; their labels and display order are user settings, so renaming changes the label on existing and new entries.
6. **P2 items** (substitutions, meal plan, prep) are in the roadmap scope and are delivered as the last stage, after all P1 criteria.

## Not owned by any open package (owner decision requested)
NUT-019's day-total provenance badge and NUT-022 imperial/kg/l entry were allocated to WP 5, which is now accepted. WP 7 implements the shared NUT-019 rule (needed by RCP-007) but not the day-total badge or NUT-022 entry. They need a new owner.

## What was built
| Stage | Commit | Content |
|---|---|---|
| 0 — NUT-017 | 2d735a7, 07d9caa, aac5f15 | Calculation specification (draft), shared weakest-provenance rule, 37 worked examples as tests |
| 1 — domain, schema v5, use cases | 77540ae | Recipe model (real portions, prep/cook steps, freezing tri-state, weights, servings, substitutes, notes), scaling and logging functions, `validateRecipe`, schema v5 migration (idempotent), `SaveRecipe`/`DeleteRecipe`/`ToggleFavourite`/`LogRecipe`, `MealLabels`, `ImportLegacyRecipes` |
| 1b — seed asset | 266d4a2 | 22 legacy recipes as JSON |
| 2 — recipe screens | ae338e0 | List, detail (incomplete nutrients, scaling, substitutions), log sheet, editor, Settings → Meals; every meal label reads the user's labels |
| 3 — plan and prep domain | 2474b56 | Meal plan (28-day window, plan-day totals with the log calculations, mark eaten via the log use cases), prep batches (never below 0), `LogRecipe` with a prep batch in one transaction |
| 4 — plan and prep screens | (this commit) | `/fuel/plan`: 28-day navigator, meals in the user's order, planned items with planned kcal, day summary with the diary's semantics and unresolved-item note, add recipe/food/saved meal, mark eaten (editable quantity, optional prep batch); recipe detail: record batch, batches with portions left; log sheet: from prepared batch |

- **Seed asset** (266d4a2): `app/assets/seed/legacy_recipes.json`, 22 recipes extracted by `app/tool/extract_legacy_recipes.dart`, cross-checked by an independent parser (0 mismatches) and spot-checked by the auditor. Correction to the commit message: the legacy freezer flags are **9 true and 13 false** (the message says 10/12, copied from the extraction agent's summary); the asset itself matches the source for all 22 recipes, verified flag by flag. Under decision 3 every seed imports as freezing **unknown** regardless.

## Tests
Appended at delivery.

## Independent review (fresh reviewer, range aac5f15..ee97c17)
Probes run in throwaway tests; 467 existing tests re-run. Findings:

| ID | Finding (verified by probe) | Severity | Resolution |
|---|---|---|---|
| H1 | Linking one ingredient to a starter recipe replaced its declared estimate with that one ingredient's nutrition and labelled it verified (3 notes + 100 g oats → 95 kcal per portion, verified); NUT-021/RCP-007. | High | Fix in progress: a recipe with ingredient notes stays declared/estimated until the notes are removed; spec rev 1.2 §8.3 and example E38; editor text and note deletion. |
| M1 | Planning an Open Food Facts food always fails; picked online foods are not cached locally. | Medium | Fix in progress: picker caches the food (`CacheFood`). |
| M2 | Marking a future-day item eaten logs into the future diary. | Medium | Fix in progress: refused with a typed error; action hidden in the UI. |
| M3 | Plan "today" ignores the day-start setting, so plan and diary disagree after midnight. | Medium | Fix in progress: one shared `diaryDayKey` rule. |
| M4 | A prep batch loses a portion when recording the eaten link fails. | Medium | Fix in progress: mark-eaten runs in one transaction. |
| M5 | Two concurrent mark-eaten calls log twice. | Medium | Fix in progress: eaten check inside the same transaction. |
| M6 | A missing seed asset makes the importer throw (uncaught async error at startup). | Medium | Fix in progress: all failures become a typed error. |
| L | Portion rounding undocumented; editor ignores the §9.3 default weight; scaling rounds quantities so per-portion values drift (§9.4); custom foods accept the portions unit; `eatenEntryId` docs; favourites setter not returning Result; E06/E07 compute in the test. | Low | Fix in progress. |
| L | Deleting/editing a mark-eaten or batch-drawn diary entry does not update the plan item or batch. | Low | TD-37. |

RCP P1 criteria the reviewer found not fully met: **RCP-003** (step delete untested), **RCP-007** (H1), **RCP-013(2)** (no navigation from a diary entry to its recipe). All three are in the fix set.

## CI evidence
Appended at delivery.
