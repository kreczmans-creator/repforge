# Delivery record — WP 5: Nutrition and food database

Date: 2026-11-03
Branch: `ccr-ac6db77c-jcnexo`
Status: **delivered for owner acceptance**; acceptance audit completed 2026-11-04 (see “Acceptance audit” below). Not accepted until the owner records a decision.

## What was built
- **Food lookup**: `FoodLookupService` interface with an Open Food Facts client (dio) behind it. Search uses the search-a-licious endpoint (the legacy `search.pl` and `api/v2/search` endpoints were returning an HTML "temporarily unavailable" page on the day of implementation); barcode lookup uses `api/v2/product`. Typed failures (offline, rate-limited, unavailable, not found); the client never throws. Community data is labelled `crowdsourced`.
- **Schema v3**: `saved_meals` and `saved_meal_items` (migration 2→3 additive; the v1 path creates the full current schema). Migration tests cover v1→v3 and v2→v3.
- **Use cases**: `LogFood` (portion → nutrient snapshot; online foods cached locally on first log so repeat lookups work offline), `UpdateFoodLogEntry` (rescales the snapshot), `DeleteFoodLogEntry`, `CreateCustomFood` (validated per-100 values, optional servings, brand, barcode), `SaveMealFromEntries`, `LogSavedMeal`, `WeeklySummary` (averages over logged days only).
- **Screens**: Fuel tab (day navigator with previous/next/today, totals vs targets, macro and fibre bars, four meal sections with per-entry provenance badges, "Save as meal"), food search (local results as you type, online results after a 400 ms debounce, explicit offline/busy/unavailable states, local results never hidden), portion sheet (named servings or custom g/ml, meal defaulted by time of day, live nutrient preview), entry edit sheet (amount, meal, delete), new food screen, saved meals screen, last-7-days summary.
- Fuel is no longer a placeholder tab.

## Tests
291 tests pass locally before the Fuel widget tests (see §CI for the final count); analyzer clean. New in WP 5: Open Food Facts mapping and client (15, fixtures captured from the live API), saved-meal repository (7), migration v2→v3 and v1→v3, use cases (log/update/delete/custom food/saved meals), weekly summary rules, and Fuel flow widget tests with a fake online service (search → portion → log → diary; offline keeps local results; day navigation).

## Acceptance criteria (D06 WP 5)
- NUT P1 criteria: NUT-001..005, 006, 007, 010, 013, 020, 021 exercised by tests; provenance labels shown on every result and entry.
- "Logging a searched food takes ≤ 4 taps after selection": tap result → (amount prefilled) → tap Log = 2 taps; changing meal adds 1.
- Offline logging: local search and logging need no network; the online section reports offline without blocking (widget test).

## Not in this package
- Barcode scanning (WP 6) — the lookup-by-barcode service method exists and is tested.
- Food edit/delete for user foods, food history beyond search, imperial portion entry (metric only for entry; display units apply to body weight so far).
- Recipes (WP 7).

## Review
No independent review was performed before delivery (the line below was left as written). The acceptance audit of 2026-11-04 is the first independent review of this package.

## CI evidence (WP 5 commits)
| Commit | CI | Android build | iOS build | Debug release | Integration tests |
|---|---|---|---|---|---|
| 9ed0e7d (schema v3) | 41711905248 success | 41711905237 success | 41711905223 success | 41711905224 success | 41711905225 cancelled (concurrency) |
| b852ea4 (features) | 41719172874 success | 41719172996 cancelled | 41719172827 cancelled | 41719172706 success | 41719172859 cancelled |
| af0c763 (integration tests) | 41719826662 success | 41719826764 cancelled | 41719826658 cancelled | 41719826760 success | 41719826746 cancelled |
| 24547dc (system check, probe tool) | 41720337618 **failure** (`flutter analyze --fatal-infos` on `tool/off_probe.dart`; fixed in c899fe4) | 41720337436 success | 41720337509 success | 41720337676 success | 41720337687 cancelled at the 60-minute cap (hung after a timing failure; see WP 3 closure) |

The emulator integration test introduced by af0c763 never completed on CI until the WP 3 closing commits fixed its waits; its first green run is 41790734724, and the WP 4 closure extended it (41819053519 green).

## Acceptance audit (2026-11-04, branch `ccr-9fda2c32-wr163b`)
Conducted after WP 4 acceptance. A fresh reviewer read the WP 5 range `7e892e1..24547dc` against D06 and the D04 NUT P1 criteria; every finding below was then verified directly in the code by the auditor.

### Independent verification
- Local run of the WP 5 commit af0c763 (Flutter 3.47.9, Linux): analyzer clean; **298 tests pass**; hand-written line coverage **77.0 %** (below the 80 % gate that now applies; the branch head is at 87.7 % after the 26 nutrition-screen widget tests added at WP 3 closure).
- Verified true in code: Open Food Facts client never throws and returns typed failures (offline, rate-limited, unavailable, not found); 400 ms debounce with stale-request guard; diacritic-folded `search_key`; online foods cached locally on first log only; g/ml/serving scaling; fibre-null propagation in sums and scaling; saved-meal snapshot copy; day-key boundaries; migration tests v1→v3 and v2→v3; `lib/domain` has no Flutter imports; use cases return `Result`.
- Taps to log a searched food after selecting a result: **1** (the portion sheet opens prefilled with 100 g or the first serving and a time-of-day meal; tap "Log"). The D06 ≤ 4 criterion is met.

### Findings
| ID | Finding (verified) | Severity | Resolution proposed |
|---|---|---|---|
| D1 | **Missing macros are invented as 0.** `open_food_facts_mapper.dart:32-34` maps an absent `proteins_100g`/`carbohydrates_100g`/`fat_100g` to `?? 0`; `NutrientAmounts` cannot hold a null macro and `CreateCustomFood` rejects blank macros. An Open Food Facts hit with energy only logs as "0 g protein, Community data" and silently lowers the day's protein total. Violates D04 **NUT-021 (P1) "the app shall not invent nutrition data"** and NUT-007(1) (macros optional). | **High** (P1 requirement; data integrity) | Fix before acceptance: nullable macros through the model, mapper, custom-food form and display ("not available"); tests for the energy-only hit and the day total. |
| D2 | **Null fibre and absent targets are displayed as 0.** `fuel_screen.dart:234-251` passes `fibreG ?? 0` and `target ?? 0`; `RfMacroBar` renders "30 / 0 g" with an empty bar; only the kcal tile handles a missing target. Violates NUT-021(1) ("fibre: not available") and NUT-015(2). Same defect class as WP 4 B4 (TD-28) on the dashboard. | Medium | Fix before acceptance together with TD-28: "no target" and "not available" states; widget test. |
| D3 | **Weekly summary shows two of the five required measures.** The domain computes averages for all five (`WeeklySummary.averagePerLoggedDay`), but `weekly_summary_screen.dart` shows kcal and protein only, per day and as averages. NUT-016 (P1) requires energy, protein, carbohydrate, fat and fibre. The code cites "NUT-021" for the weekly summary (wrong id). | Medium (P1 requirement) | Fix before acceptance: show all five; widget test; correct the requirement reference. |
| D4 | **Migration 2→3 was not re-runnable** (`CREATE INDEX` without a guard), the same crash-window defect as WP 3 A1. A re-run threw "index idx_saved_meal_items_meal already exists" and the database failed to open. | Medium (data access) | **Fixed in this audit**: index guarded like v1→v2; new test "v2 upgrade can run again after a crash before user_version is recorded" fails on the old code and passes on the fix. |
| D5 | **Search endpoint 404 is reported as "No online matches"**: the client lets any 404 through to the mapper (needed for unknown barcodes), so a moved search endpoint shows an empty result rather than the unavailable state. `LookupNotFound` is never produced by the client. | Low | Treat 404 as unavailable for *search* and as not-found for *barcode*; client test. |
| D6 | Standards: no `Logger` exists in `lib`; the client and mapper drop hits and failures silently (§5). `fuel_flow_test.dart`, `log_food_test.dart` do not mirror `lib/` paths (§7). `tables.dart` comment on saved-meal item snapshots contradicts the domain ("per 100" vs "for the stored amount"). | Low | Fold into TD-25/TD-26; fix the comment with the next schema change. |
| D7 | Minor: `normaliseSearchKey` folds a fixed Latin set (no ø, ß, ł, š); search is a contiguous LIKE so "yogurt greek" misses "Greek yogurt"; malformed-JSON and missing-`nutriments` paths exist but are untested. | Low | Debt; resolve with NUT-014 recent/frequent foods. |
| D8 | **Record accuracy.** WP5.md claims NUT-006, 020 and 021 are "exercised by tests": 006 is barcode *scanning* (WP 6, not built; only the lookup method exists), 020 has no estimation flow (the system-check document itself says "Not started"), 021 fails (D1, D2). The system check lists 011, 012, 015, 016, 021 as "Verified": 011 (rename/reorder meals) is unimplemented, 012 lacks copy-to-date, 015/016/021 fail per D2/D3/D1. | Medium (record accuracy) | Corrected in the criteria table below; both documents to be amended at closure. |

### CI evidence for the audit commit
| Commit | What | CI (gate) | Android build | iOS build | Integration tests |
|---|---|---|---|---|---|
| a216fc2 | D4 fix + re-run test; this audit record | 41823397838 success | 41823397821 success | 41823397991 success | 41823397901 success |

### Scope and acceptance criteria (D06 WP 5) against evidence
| Item | Status | Evidence / gap |
|---|---|---|
| Open Food Facts client with typed errors, debounce, caching | Met | `open_food_facts_client_test.dart` (15), `fuel_flow_test.dart`, `log_food_test.dart` "caches an online food locally on first log only" |
| Custom foods, custom serving sizes | Partial | `custom_food_screen_test.dart` (8); macros mandatory (D1); servings only on custom foods, not "any food" (NUT-009) |
| Portion entry g/ml/servings, meal assignment | Met | `fuel_flow_test.dart`, `custom_food_screen_test.dart`, `portion_sheet.dart` |
| Daily diary with edit/delete, date navigation | Met at branch head | `entry_edit_sheet_test.dart` (added at WP 3 closure), `fuel_flow_test.dart` "day navigation" |
| Fibre | Partial | tracked and summed; display defect D2 |
| Saved meals | Met | `saved_meals_test.dart`, `drift_saved_meal_repository_test.dart` (7), `saved_meals_screen_test.dart` (9) |
| Provenance labels | Met, with a note | badge on every result and entry; `crowdsourced` is a fourth label beyond D04's three (anticipated in D03; weakest-provenance ordering for day totals undefined, NUT-019) |
| Daily and weekly summaries | Partial | D2, D3 |
| NUT P1 pass their acceptance criteria | **Not met as written** | Met: 001, 002, 004, 005, 010, 013. Partial: 003, 007, 009, 012 (no copy), 015, 016, 018. Not met: 011 (meal rename/reorder), 017 (no calculation spec document), 019 (weakest provenance on totals), 020, 021 (D1/D2), 022 (no kg/l entry), 023 (no import date). Out of scope by roadmap: 006 (WP 6), 008, 014. |
| ≤ 4 taps after selection | Met | 1 tap (see above) |
| Offline logging works with airplane mode | Partial | widget test with a fake offline lookup only; no airplane-mode device test recorded |
| Verification: integration test for log/edit/delete | Partial | the integration test logs; edit and delete are covered by widget and use-case tests, not on the device |

### Deviations from approved requirements
1. The record narrowed "NUT P1 pass" to a subset without stating a deviation. The unbuilt or partial P1 items need an owner-approved allocation: 011, 017, 019, 022, 023 and 018(3) are not assigned to any package in D06.
2. Hand-written coverage at the WP 5 commit was 77.0 %, below the threshold the standards required from WP 1 (the gate did not yet exist; the shortfall was closed at WP 3 closure).
3. No independent review before delivery, contrary to the project's practice for WP 1–4.

### Recommendation
**Reject as delivered; re-present after the required fixes** (or, at the owner's discretion, conditionally accept with the same fixes as closure conditions):
- R1. Fix D1, D2 and D3 before acceptance: they are failures of P1 requirements NUT-021, NUT-015 and NUT-016 and D1 corrupts day totals. Each with regression tests.
- R2. D4 is fixed in this audit (owner to confirm, as for WP 3 A1).
- R3. D5 fixed (small) or recorded as debt; D6/D7 folded into existing debt items.
- R4. Correct WP5.md and the system-check document (D8).
- R5. Owner decision on the unassigned NUT P1 items (011, 017, 019, 022, 023, 018(3)): assign to packages or formally descope with a D04 amendment.
- R6. Airplane-mode offline logging recorded by the owner on a device at closure, or accepted on the widget-test evidence.
