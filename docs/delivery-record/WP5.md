# Delivery record — WP 5: Nutrition and food database

Date: 2026-11-03
Branch: `ccr-ac6db77c-jcnexo`
Status: **in progress → delivered for owner acceptance** (CI evidence appended when the runs complete).

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
Independent review pending at time of writing; outcomes appended below.
