# Delivery record — WP 7: Recipe management and meal planning

Date: 2026-11-04
Branch: `ccr-9fda2c32-wr163b`
Status: **conditionally accepted by the owner (2026-11-04); closure condition met at 7c62e9c — presented for final acceptance.** Not formally closed until the owner records it. No merge to `main`. (Authorised by the owner 2026-11-04 while WP 6 device testing is pending; WP 7 depends on WP 5, which is accepted by owner decision. If D05 V-01 fails and WP 5 reopens, WP 7 work that builds on the affected code is re-checked.)

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
At 110b8bb: **709 tests pass**, analyzer and formatter clean, hand-written coverage **89.1 %** (gate 80 %). WP 7 added about 230 tests: the 38 NUT-017 worked examples (E31/E32 enabled, E38 added); recipe rules and validation; schema v5 migration incl. crash re-run and pre-v5 backup restore; recipe repository, use cases, logging (portions, weight, prep batch), starter import (incl. missing asset); meal labels; planning window, plan totals equal to the log, mark-eaten atomicity and concurrency; prep batches never below 0; widget tests for the list, detail, scaling, substitutions, log sheet, editor (incl. step delete, notes), meal labels, plan and prep screens, the phone-size scroll regression; one emulator integration test (RCP-013).

## Acceptance criteria (D06 WP 7) against evidence
| Criterion | Status | Evidence |
|---|---|---|
| Computed per-portion nutrition matches hand-calculated fixtures | Met | spec examples E26–E32, E37, E38; `recipe_stage1_test`; editor test (170 kcal, 8.5 g P, 17 g C, 6.4 g F) |
| Seed recipes visible with the `estimated` label | Met | list widget test imports the real asset; import tests |
| RCP P1 criteria pass | Met (final review: none unmet) | RCP-001/002/004 validation tests; 003 add/edit/reorder/delete both sections; 006/008/009 domain and widget tests; 007 incomplete nutrients and H1 rule; 011 favourites filter across restart; 012 by portions/weight; 013 snapshot unchanged after edit (unit, widget, emulator) and diary entry opens its recipe |
| P2: RCP-005, 010, 014, 015 | Met | freezing tri-state; substitution view with kcal difference; plan window, totals, mark eaten; prep batches |
| NUT-011 rename/reorder | Met | `save_meal_labels_test`, `meal_labels_screen_test` |
| Verification: unit tests for recipe maths; widget tests | Met | above |

## Deviations and decisions for the owner
1. **NUT-017 specification** is a draft for approval; §4 carbohydrate convention (OQ-14) needs a decision (recommendation: EU/UK available carbohydrate, fibre separate).
2. **Seed recipes**: freezing imported as "unknown" (not the legacy flag) under RCP-005/OQ-13; ingredient lists kept as notes; nutrition stays the legacy estimate until every note is replaced by a linked ingredient (H1 rule).
3. **RCP-002 interpretation**: text-only ingredient notes exist only on imported recipes with declared nutrition.
4. **Portion counts** are stored in 0.1 steps (spec §2.1 rev 1.2); 1.25 portions becomes 1.3; inputs offer one decimal.
5. **Unowned requirements**: NUT-019's day-total provenance badge and NUT-022 imperial/kg/l entry were allocated to WP 5 (now accepted) and have no package.
6. **Debt opened**: TD-37 (diary edits do not update plan/prep), TD-38 (plan day-start fallback before settings load), TD-39 (entry sheet reads the recipe repository directly).

## Recommendation
**Accept, subject to the owner's decisions 1 and 5.** Implementation, review, local and CI evidence are complete at 110b8bb. Physical-device verification is not a WP 7 acceptance criterion (D06), but the recipe and plan screens have only been exercised on the emulator and in widget tests.

## Independent review (fresh reviewer, range aac5f15..ee97c17)
Probes run in throwaway tests; 467 existing tests re-run. Findings:

| ID | Finding (verified by probe) | Severity | Resolution |
|---|---|---|---|
| H1 | Linking one ingredient to a starter recipe replaced its declared estimate with that one ingredient's nutrition and labelled it verified (3 notes + 100 g oats → 95 kcal per portion, verified); NUT-021/RCP-007. | High | **Fixed**: `Recipe.isComputed` requires no ingredient notes; spec rev 1.2 §8.3, example E38; editor note deletion; detail screen's substitute difference uses the same rule (auditor fix, regression test). Re-verified by probe. |
| M1 | Planning an Open Food Facts food always fails; picked online foods are not cached locally. | Medium | **Fixed**: picker caches non-user foods through `CacheFood`. Re-verified. |
| M2 | Marking a future-day item eaten logs into the future diary. | Medium | **Fixed**: typed refusal; action hidden for future days. Re-verified. |
| M3 | Plan "today" ignores the day-start setting, so plan and diary disagree after midnight. | Medium | **Fixed**: shared `diaryDayKey` in diary, plan screen and both use cases. Re-verified. |
| M4 | A prep batch loses a portion when recording the eaten link fails. | Medium | **Fixed**: one `Transactor` transaction; batch unchanged on failure. Re-verified. |
| M5 | Two concurrent mark-eaten calls log twice. | Medium | **Fixed**: concurrent calls give one Ok, one refusal, one entry. Re-verified. |
| M6 | A missing seed asset makes the importer throw (uncaught async error at startup). | Medium | **Fixed**: any failure becomes a typed error; `main.dart` guarded. Re-verified. |
| L | Portion rounding undocumented; editor ignores the §9.3 default weight; scaling rounds quantities so per-portion values drift (§9.4); custom foods accept the portions unit; `eatenEntryId` docs; favourites setter not returning Result; E06/E07 compute in the test. | Low | **Fixed** (portion rounding documented in spec §2.1 rather than changed; inputs limited to one decimal). |
| L | Deleting/editing a mark-eaten or batch-drawn diary entry does not update the plan item or batch. | Low | TD-37. |

RCP P1 criteria the reviewer found not fully met: **RCP-003** (step delete untested), **RCP-007** (H1), **RCP-013(2)** (no navigation from a diary entry to its recipe). All three are in the fix set.

### Emulator failure and the scroll helper (owner gate: reproduce, then verify)
- Emulator runs 41874764486 and 41880049338 failed the RCP-013 integration test at `scrollTo(recipe-save)` with "Bad state: No element" (diagnostic record 5e18144).
- **Reproduced locally** with a phone-size (412×915) widget test of the recipe editor: `find.byType(Scrollable).last` is a single-line text field's horizontal scroller.
- **The first fix was insufficient**: "last vertical scrollable" failed the same reproduction with the same error, because a multi-line text field (the description) owns a vertical scroller.
- **Fix**: shared helper `app/test/helpers/scrolling.dart` `lastPageScrollable()` — the last vertical scrollable not inside an `EditableText`, used by the integration test and by the regression test "on a phone-sized screen the editor Save button is reached by scrolling the form, not a text field", which also asserts both traps.
- Final review N1: the edit step tapped `ingredient-0` without scrolling; now scrolled first. Reviewer replayed the whole RCP-013 flow at 411×731 and 360×640: every tap hit-testable, assertions pass. Limit: widget replays, not the emulator; the four workflows on the verification commit are the evidence.

### Final review of the combined fix diff (same reviewer)
All original findings re-probed and **resolved**; no RCP P1 criterion unmet. New findings: N1 (above, fixed), **N2** a saved scaled recipe stored exact amounts but read back rounded — **fixed**: `SaveRecipe` stores quantities in 0.1 steps (regression test failed on old code with 533.333 vs 533.3; reviewer confirmed save-as-new and overwrite, substitutes, and a typed error for a quantity that rounds to 0); **N3** day-start fallback before settings load → TD-38; **N4** entry sheet reads the recipe repository directly → TD-39.

Local evidence on the verification commit's tree: 709 tests pass, analyzer and formatter clean, hand-written coverage 89.1 %.

## CI evidence
| Commit | CI (gate) | Android build | iOS build | Integration tests |
|---|---|---|---|---|
| 77540ae (stage 1) | 41865491318 success | 41865491359 | 41865491400 | 41865491278 |
| ae338e0 (stage 2) | 41874764235 success | 41874764297 success | 41874764245 success | 41874764486 **failure** |
| ee97c17 (stage 4) | 41880049018 success | 41880049553 success | 41880049296 success | 41880049338 **failure** |
| c009b2c (verification commit: review fixes) | 41894402169 success | 41894402183 success | 41894402174 success | 41894402215 **failure** — scroll steps now pass; the final assertion matched both the diary row and the still-visible "Logged 1.5 portions" snackbar (device real time). Assertion fixed to wait for the snackbar and match the exact diary row; reviewed before commit. |
| **110b8bb** (delivery commit) | **41896530147 success** | **41896530145 success** | **41896530323 success** (attempt 2; attempt 1 was cancelled after 15 min in the macOS runner queue with no step run) | **41896530253 success** (all four integration tests incl. RCP-013 and the scan test) |

The emulator failure on ae338e0 and ee97c17 is the new RCP-013 integration test: the shared `scrollTo` helper picked the last `Scrollable` on screen, which in the recipe editor is a text field's horizontal scroller, so it never reached the Save button. Being fixed with the review fixes; the delivery commit must show all four green.

## Owner decisions (2026-11-04)
| Item | Decision |
|---|---|
| CI evidence at 110b8bb | Independently verified by the owner against the full SHA; iOS attempt 2 is the relevant result |
| NUT-017 §4 carbohydrate convention (OQ-14) | **Approved**: UK/EU available carbohydrate, fibre separate, energy as stated; US-label limitation accepted |
| NUT-017 §2.1 portion rounding | **Not approved as written**: portion counts must be stored to at least 0.01 (1.25 stays 1.25); revision 1.3 required |
| Seed recipes: freezing unknown; estimate kept until all notes replaced | **Approved** |
| NUT-019 day-total badge | → WP 11 |
| NUT-022 kg/l/imperial entry | → new WP 15 (Nutrition entry units) |
| WP 7 | **Conditionally accepted**, pending the portion-precision condition |
| Physical-device testing of recipe screens | Noted; not an acceptance gate (D06 does not specify one) |

### Closure condition — portion precision
1. NUT-017 revision 1.3 (§2.1; examples E39–E41).
2. Implementation: portion counts stored and calculated at 0.01 everywhere (logging, plan, prep batches, saved-meal multipliers, diary edit); portion inputs accept two decimals; g/ml stay at 0.1.
3. Regression tests: fractional portions, nutrient calculations, diary snapshots; E39–E41 executed.
4. Fresh independent review; four workflows green on the final commit; this record and D06 updated with the commit and runs.

### Closure condition — evidence
- **Implementation** (closure commit, see CI table): `ReferenceUnit.decimals` (portions 2, g/ml 1); `Quantity.of` rounds portions to 0.01 and g/ml to 0.1; prep batches computed in integer hundredths; saved-meal multipliers to 0.01; every portion input accepts two decimals; labels show "1.25 portions".
- **Tests**: E39–E41 executed against production code; regression tests re-read stored rows and snapshots after log, diary edit, plan, mark-eaten and batch operations; three existing tests updated where they encoded the 0.1 rule (judged legitimate by the reviewer). Proven to fail on the old code.
- **Local**: 730 tests pass, analyzer and formatter clean, hand-written coverage 89.1 %.
- **Fresh independent review** (new reviewer): **condition met**; probes: 1.25 portions → 500 kcal stored 1.25; edit to 1.75 → 700 kcal; plan 1.25 and mark eaten; batch 2 − 0.75 − 1.25 → exactly 0; saved meal ×1.25; g/ml still 0.1; old 0.1-step stored values unaffected. Low findings: spec §2.1 tie wording (corrected to the binary-value rule), TD-40 (saved-meal snapshot vs rounded quantity; unreachable repository edge).

### Closure commit CI (7c62e9c)
| Workflow | Run | Result |
|---|---|---|
| CI (format, analyze, tests, coverage gate) | 41916959323 | success |
| Android build | 41916959074 | success |
| iOS build | 41916959377 | success (attempt 1) |
| Integration tests (Android emulator) | 41916959075 | success |

All closure steps done: spec rev 1.3, implementation and regression tests, fresh independent review (condition met), four workflows green on 7c62e9c, this record and D06 updated.
