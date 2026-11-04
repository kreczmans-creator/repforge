# Delivery record — WP 5: Nutrition and food database

Date: 2026-11-03
Branch: `ccr-ac6db77c-jcnexo`
Status: **accepted by owner decision on 2026-11-04** at df0f6d9 (closure conditions table below). **The airplane-mode device verification (R6) is unconfirmed and open**: no device, Android version, date or per-step result has been supplied; the auditor has no device access and did not perform the test. The owner's first acceptance statement attributed a confirmation to the auditor that was never given; the owner corrected this on 2026-11-04. Acceptance by owner decision does not make the missing evidence exist. Disposition of the open condition: see "R6 disposition" below. No merge to `main` authorised.

## What was built
- **Food lookup**: `FoodLookupService` interface with an Open Food Facts client (dio) behind it. Search uses the search-a-licious endpoint (the legacy `search.pl` and `api/v2/search` endpoints were returning an HTML "temporarily unavailable" page on the day of implementation); barcode lookup uses `api/v2/product`. Typed failures (offline, rate-limited, unavailable, not found); the client never throws. Community data is labelled `crowdsourced`.
- **Schema v3**: `saved_meals` and `saved_meal_items` (migration 2→3 additive; the v1 path creates the full current schema). Migration tests cover v1→v3 and v2→v3.
- **Use cases**: `LogFood` (portion → nutrient snapshot; online foods cached locally on first log so repeat lookups work offline), `UpdateFoodLogEntry` (rescales the snapshot), `DeleteFoodLogEntry`, `CreateCustomFood` (validated per-100 values, optional servings, brand, barcode), `SaveMealFromEntries`, `LogSavedMeal`, `WeeklySummary` (averages over logged days only).
- **Screens**: Fuel tab (day navigator with previous/next/today, totals vs targets, macro and fibre bars, four meal sections with per-entry provenance badges, "Save as meal"), food search (local results as you type, online results after a 400 ms debounce, explicit offline/busy/unavailable states, local results never hidden), portion sheet (named servings or custom g/ml, meal defaulted by time of day, live nutrient preview), entry edit sheet (amount, meal, delete), new food screen, saved meals screen, last-7-days summary.
- Fuel is no longer a placeholder tab.

## Tests
291 tests pass locally before the Fuel widget tests (see §CI for the final count); analyzer clean. New in WP 5: Open Food Facts mapping and client (15, fixtures captured from the live API), saved-meal repository (7), migration v2→v3 and v1→v3, use cases (log/update/delete/custom food/saved meals), weekly summary rules, and Fuel flow widget tests with a fake online service (search → portion → log → diary; offline keeps local results; day navigation).

## Acceptance criteria (D06 WP 5)
Corrected 2026-11-04 at owner direction (audit D8). The original text claimed "NUT-001..005, 006, 007, 010, 013, 020, 021 exercised by tests"; that claim is withdrawn. Status per NUT P1 requirement, in four states — **tested** (an automated test demonstrates the acceptance criterion), **implemented** (behaviour exists in code without a test of that criterion), **partial** (some criteria met), **not implemented**:

| NUT | Status | Evidence / gap |
|---|---|---|
| 001 energy per day | tested | `daily_targets_test`, `unknown_macros_test` |
| 002 macros per food and day | tested | `nutrition_rules_test`, `log_food_test` |
| 003 fibre | tested after closure | tracked and summed; unknown fibre shown as n/a (D2 fix) |
| 004 reference basis and servings | tested | `custom_food_screen_test`, `create_custom_food` tests |
| 005 local offline database | tested (widget), device test pending R6 | `fuel_flow_test` "offline search still shows local foods" |
| 006 barcode scanning | **not implemented — WP 6**; only the lookup-by-barcode service method exists (`open_food_facts_client_test`) | |
| 007 custom food, optional macros | tested after closure | blank macros stored as unknown (D1 fix, `unknown_macros_test`) |
| 008 edit/delete custom food | not implemented (never allocated to WP 5) | |
| 009 custom serving sizes | partial | servings on custom foods only, not on any food |
| 010 log by weight, volume, servings | tested | `fuel_flow_test`, `custom_food_screen_test` |
| 011 named meals rename/reorder | not implemented → WP 7 | entries are shown under their meal |
| 012 edit, move, copy, delete entry | partial | edit/move/delete tested (`entry_edit_sheet_test`); copy to another day not implemented |
| 013 saved meals | tested | `saved_meals_test`, `saved_meals_screen_test` |
| 014 recent/frequent foods | not implemented (never allocated to WP 5) | |
| 015 daily summary vs targets | tested after closure | no-target and unknown states (D2 fix) |
| 016 weekly summary, five measures | tested after closure | all five shown (D3 fix) |
| 017 calculation specification | not implemented → WP 5 (owner allocation; before further calculation work) | rules are tested but no specification document exists |
| 018 provenance labels | partial | labels on every food and entry; `crowdsourced` approved as a fourth label (D04 §7); part 3 retained in backlog |
| 019 weakest provenance on totals | not implemented → WP 5 (owner allocation) | |
| 020 estimated values only by documented action | not implemented | no estimation flow exists; the original "exercised by tests" claim was wrong |
| 021 no invented data | tested after closure | D1 (unknown macros) and D2 (display) fixes with regression tests |
| 022 unit conversion and imperial entry | partial → WP 5 (owner allocation) | metric conversions tested; imperial entry not offered |
| 023 import source and date | partial → WP 14 | source stored; no import date |

- "Logging a searched food takes ≤ 4 taps after selection": 1 tap (portion sheet opens prefilled; tap Log). Met.
- Offline logging: widget test with a fake offline service only. The airplane-mode device test (R6) is the acceptance evidence and is recorded below when performed.

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

## Owner decision (2026-11-04): rejected as delivered
Closure conditions R1–R6 recorded verbatim in effect; progress is tracked in "Closure" below.

### R6 — Airplane-mode device verification (owner to perform; results recorded here)
Build: the debug APK from the rolling `debug-latest` release built from the final closure commit (named in "Closure"). Device: owner's Android phone (record model and Android version).

| Step | Action | Expected | Result |
|---|---|---|---|
| 1 | With network on, open Fuel → Log food, search an online food (for example "greek yogurt"), log one portion. | Entry appears in today's diary; the food is now cached locally. | |
| 2 | Enable airplane mode (Wi-Fi and mobile data off). Open Fuel → Log food, search the same name. | The cached food appears under local results immediately; the online section shows the offline state; the screen does not block. | |
| 3 | Log the cached food again from the offline search. | Second entry appears in the diary with correct nutrients; no spinner persists. | |
| 4 | Kill the app from recents and reopen while still offline. Open Fuel. | Both entries still listed; dashboard totals match. | |
| 5 | Disable airplane mode, return to the app, pull the diary (navigate away and back). | No duplicate entries, no changed values. | |
| 6 | Delete the two test entries. | Diary and dashboard return to the previous state. | |

Record: device model, Android version, build commit, date, and the result column. Any deviation is a defect against GEN-004/NUT-005 and reopens R1.

## Closure (2026-11-04)
Scope kept to the owner's instruction: the three nutrition defects, the search 404 handling, the migration re-run guard, documentation accuracy and the agreed verification. No other feature work.

### What changed
| Condition | Commit | Change | Regression tests |
|---|---|---|---|
| D1 unknown macros stay unknown | 864065f | `NutrientAmounts` macros nullable; sums add known values and are null only when no input knows; `NutrientTotals` carries unknown counts; Open Food Facts mapper passes null through; `CreateCustomFood` accepts blank macros as unknown; schema v4 makes the snapshot columns of `foods`, `food_log_entries`, `saved_meal_items` nullable via `TableMigration` with foreign keys off around the rebuild, idempotent on re-run | `open_food_facts_mapper_test` (energy-only → null, explicit 0 stays 0), `unknown_macros_test` (day protein total unchanged with one unknown entry; only-unknown day → null; rescale preserves null; blank custom-food macros → null), `nutrition_rules_test` "unknown nutrients" (9), `migration_test` (v3→v4 keeps food, servings child row, log entry, saved-meal item; v3 re-run after crash; v1/v2→v4) |
| D2 known / unknown / no-target states | ca90c49, df0f6d9 | `RfMacroBar` nullable amount and target with unknown-count marker; "n/a" and "no target", no bar without a target; Fuel screen, dashboard (closes TD-28), portion sheet, diary subtitles, saved-meal totals share the semantics; weekly day row draws no bar without a calorie target; custom-food form labels "blank if unknown" | `components_test` RfMacroBar (4), `fuel_screen_test` (4), `home_screen_test` "nutrition panel semantics" (3), `portion_sheet_test`, `saved_meals_screen_test` (2 new) |
| D3 weekly summary, five measures | ca90c49, df0f6d9 | all five measures per day and as averages; a nutrient's average is over the logged days that know it (a day with no known value is excluded, never counted as 0) and the tile says how many days were left out; reference corrected to NUT-016 | `weekly_summary_screen_test` (2 new), `summaries_test` "average leaves out days that do not know a nutrient" |
| D4 migration re-run guard | a216fc2 | retained as approved | `migration_test` "v2 upgrade can run again…" |
| D5 search 404 | 82a4670 | search 404 → unavailable; barcode 404 → not found | `open_food_facts_client_test` "search 404 is unavailable, not an empty result" |
| D6/D7 debt | 82a4670 | TD-32 (no Logger in the lookup layer), TD-33 (search normalisation, untested client paths); TD-26 extended; `tables.dart` saved-meal comment corrected | — |
| R4 documents | e0efce6 | this record (per-requirement NUT table) and the system check corrected | — |
| R5 allocations | 82a4670 | D06 and D04 §7: NUT-011 → WP 7; NUT-017, 019, 022 → WP 5; NUT-023 → WP 14; NUT-018(3) retained verbatim; `crowdsourced` approved as a fourth label with aggregate ordering | — |

### Fresh independent review of the fixes (owner condition)
A reviewer with no part in the fixes read `d40690a..ca90c49`. Outcome: D1, D2, D5 and the v4 migration **resolved** (atomicity, data preservation incl. `food_servings`, re-runnability and snapshot consistency confirmed; every remaining `?? 0` in `lib` judged and none converts a nutrient null to 0). Findings:
- **F1 (medium, fixed in df0f6d9):** the weekly average divided the known sum by all logged days, so a day with no known protein counted as 0 g; the widget test encoded it. Averages now exclude days that do not know the nutrient; both tests corrected.
- **F2 (low, fixed in df0f6d9):** weekly day row drew a 0 % bar when no calorie target was set.
- **F3 (low, fixed in df0f6d9):** custom-food form did not say that a blank macro means unknown.
- **F4 (low, recorded):** `LookupNotFound` is never produced (barcode not-found is `Ok(null)` by contract) — folded into TD-33; "n/a"/"no target" strings exist in both `RfMacroBar` and the feature helper — acceptable (the component cannot import feature code), noted for the design-system glossary.

### Test, coverage and CI evidence
Local at df0f6d9 (Flutter 3.47.9): **372 tests pass**, analyzer and formatter clean, hand-written coverage **88.1 %** (gate 80 %).

| Commit | CI (gate) | Android build | iOS build | Integration tests |
|---|---|---|---|---|
| 82a4670 (D5, allocations) | 41825207117 success | 41825207142 success | 41825207147 success | 41825207345 success |
| 864065f (D1, schema v4) | 41827033870 success | 41827033764 success | 41827033864 success | 41827033811 success |
| ca90c49 (D2/D3 UI) | 41828763729 success | 41828763777 success | 41828764033 success | 41828763827 success |
| df0f6d9 (review F1–F3, final closure commit) | 41830059871 success | 41830059855 success | 41830059827 success | 41830059924 success |

### Closure conditions
| Condition | Status |
|---|---|
| D1, D2, D3 fixed with regression tests | done (864065f, ca90c49, df0f6d9) |
| D4 retained | done |
| D5 fixed | done (82a4670) |
| D6/D7 recorded as debt | done (TD-32, TD-33, TD-26) |
| WP 5 record and system check corrected | done (e0efce6, this section) |
| NUT P1 ownership recorded in D04/D06 | done (82a4670) |
| Airplane-mode device verification | **OPEN — unconfirmed.** Result fields blank; no device, version or date supplied; not performed or confirmed by the auditor. Must not be represented as passed. See "R6 disposition". |
| Coverage gate ≥ 80 % on the final head | done (88.1 %) |
| Four workflows green on the final closure commit | done (df0f6d9, table above) |
| Fresh independent review with findings resolved | done (F1–F3 fixed, F4 recorded) |

Not merged to `main`.

## Owner acceptance (2026-11-04)
WP 5 accepted and closed by owner decision at df0f6d9: D1–D5 resolved and regression-tested; D6/D7 recorded as TD-32/TD-33; requirements and roadmap allocations corrected; fresh independent review completed with F4 documented; coverage gate 88.1 %; four workflows green on df0f6d9. The airplane-mode device verification is **not** among the satisfied conditions: it is unconfirmed and open (owner correction, 2026-11-04). No merge to `main` authorised.

### R6 disposition (auditor decision, 2026-11-04)
The test can only be performed by the owner on a physical Android device; the auditor cannot supply or invent the evidence. Disposition:
1. **Status: open verification item, owner-owned**, tracked as D05 V-01 (not technical debt: nothing in the code is known to be wrong; the evidence is missing).
2. **Due: at WP 6 acceptance**, in the same owner device session as the WP 6 physical-device checklist (D06 WP 6 verification requires device tests on both platforms anyway). The six-step procedure above is the test; results, device model, Android version, build commit and date are entered in the table above by the owner.
3. **Blocking:** not a blocker to *starting* WP 6 implementation (WP 6 depends on WP 5's accepted code, not on this evidence). It **is** a blocker to WP 6 acceptance and to the R0 internal release point (D06), because offline-first behaviour is a core architectural promise (GEN-004, NUT-005).
4. **If the test fails**, the failure is a WP 5 defect, reopens WP 5 under the owner's rule "a demonstrated defect", and is fixed before WP 6 acceptance.
5. Until the data is entered, every document that mentions R6 says "unconfirmed, open".
