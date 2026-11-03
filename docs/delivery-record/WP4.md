# Delivery record — WP 4: Navigation, dashboard and application shell

Date: 2026-11-03
Branch: `ccr-ac6db77c-jcnexo`
Status: **delivered for owner acceptance** (CI evidence appended when the runs complete).

## What was built
- **Settings screen** (`/settings`, gear icon in the app bar): daily calorie, protein, carbohydrate, fat and fibre targets persisted as active goals (blank clears a target; validation per `validateTarget`); units (metric/imperial display), theme (dark default / light / system), effort scale (RPE/RIR), week start; a plain statement of the local-first storage posture (ADR-0005).
- **Theme preference is live**: the app reads the persisted preference; dark remains the default.
- **Dashboard** now shows live data from the database with an explicit empty state per panel: calories left and protein against targets (stat tiles with progress), macro bars (protein, carbs, fat, optional fibre), next plan (from workout plans), latest weight and entry count, and a merged recent-activity list of weigh-ins and sessions. No mock data.
- **Application layer**: `DailyTargets` (derived from goals), `DailySummary` (intake vs targets), `validateTarget`, `SaveDailyTargets` (creates/replaces/deactivates goals), `SaveSettings`; providers for goals, targets, today's entries, today's summary, recent sessions, plans and the day key (honours the day-start setting).
- Navigation unchanged from WP 2 (five pillars) plus the pushed Settings route.

## Tests
251 tests pass locally; analyzer clean. New: `daily_targets_test` (goal selection, validation ranges, summary maths), `save_daily_targets_test` (create, replace, keep-unchanged, deactivate, reject), `settings_screen_test` (targets persisted to the goals table, field-level error, units and theme persisted), `home_screen_test` (empty states; intake against targets rendered from the database). The on-device integration test now also sets a calorie target in Settings, rebuilds the whole app on the same database (simulated restart) and verifies the dashboard shows the target and the earlier weight.

## Acceptance criteria (D06 WP 4)
- Dashboard reflects database changes live: covered by `home_screen_test` and the integration test.
- Targets persist across restart: covered by the integration test's rebuild on the same database.
- Widget tests for each panel state: empty and populated nutrition/training/activity states covered; error states are rendered by the shared `RfErrorState` (component test).

## Review
Independent review produced ten findings, all applied: the day key now rolls over while the app is open (minute tick), target replacement is atomic in the goal repository and the use case reads current goals itself, the units preference is applied to every body-weight display, the activity panel has explicit loading and error states, the training panel no longer presents an arbitrary plan as "next", one shared number formatter and a shared `IdGenerator` typedef, settings watched with `select`, and upstream stack traces preserved.

## Outstanding
- Food logging and plans do not exist yet, so the nutrition and training panels show empty states until WP 5 and WP 8/9.
- Imperial display conversion is stored as a preference but not yet applied to screens (first consumer is WP 5's portion entry).
- Day-start hour has no UI control yet (stored, default midnight).

## CI evidence
Appended for the WP 4 commit below.
