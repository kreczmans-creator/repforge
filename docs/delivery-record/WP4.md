# Delivery record — WP 4: Navigation, dashboard and application shell

Date: 2026-11-03
Branch: `ccr-ac6db77c-jcnexo`
Status: **delivered for owner acceptance**; acceptance audit completed 2026-11-04 (see “Acceptance audit” below). Not accepted until the owner records a decision.

## What was built
- **Settings screen** (`/settings`, gear icon in the app bar): daily calorie, protein, carbohydrate, fat and fibre targets persisted as active goals (blank clears a target; validation per `validateTarget`); units (metric/imperial display), theme (dark default / light / system), effort scale (RPE/RIR), week start; a plain statement of the local-first storage posture (ADR-0005).
- **Theme preference is live**: the app reads the persisted preference; dark remains the default.
- **Dashboard** now shows live data from the database with an explicit empty state per panel: calories left and protein against targets (stat tiles with progress), macro bars (protein, carbs, fat, optional fibre), next plan (from workout plans), latest weight and entry count, and a merged recent-activity list of weigh-ins and sessions. No mock data.
- **Application layer**: `DailyTargets` (derived from goals), `DailySummary` (intake vs targets), `validateTarget`, `SaveDailyTargets` (creates/replaces/deactivates goals), `SaveSettings`; providers for goals, targets, today's entries, today's summary, recent sessions, plans and the day key (honours the day-start setting).
- Navigation unchanged from WP 2 (five pillars) plus the pushed Settings route.

## Tests
251 tests pass locally; analyzer clean. New: `daily_targets_test` (goal selection, validation ranges, summary maths), `save_daily_targets_test` (create, replace, keep-unchanged, deactivate, reject), `settings_screen_test` (targets persisted to the goals table, field-level error, units and theme persisted), `home_screen_test` (empty states; intake against targets rendered from the database). The on-device integration test now also sets a calorie target in Settings, rebuilds the whole app on the same database (simulated restart) and verifies the dashboard shows the target and the earlier weight.

## Acceptance criteria (D06 WP 4)
Corrected 2026-11-04 at owner direction (audit B8). "Implemented" means the behaviour exists in code; "tested" names the test that demonstrates it.
- Dashboard reflects database changes live: implemented (every dashboard provider is a drift `watch()` stream). Tested since the WP 4 closure by `home_screen_test` group "updates live while mounted" (weigh-ins appear, change and disappear; a target and a food entry update the nutrition panel) without remounting.
- Targets persist across restart: implemented (goals table). Tested at the goal-repository and use-case level (`save_daily_targets_test`, `drift_goal_repository_test`), and since the WP 4 closure on the device by the integration test "real on-device database …": a target saved in Settings is shown by the dashboard after the ProviderScope is disposed (file database closed) and the app is rebuilt on a fresh connection to the same file.
- Widget tests for each panel state: tested for all-empty and nutrition-populated (`home_screen_test`) and, since the closure, for body/activity-populated and live changes. Not tested: training-populated, loading and error states of the panels. No test exercises `RfErrorState` directly; the earlier claim of a component test was wrong and is withdrawn.

## Review
Independent review produced ten findings, all applied: the day key now rolls over while the app is open (minute tick), target replacement is atomic in the goal repository and the use case reads current goals itself, the units preference is applied to every body-weight display, the activity panel has explicit loading and error states, the training panel no longer presents an arbitrary plan as "next", one shared number formatter and a shared `IdGenerator` typedef, settings watched with `select`, and upstream stack traces preserved.

## Outstanding
- Food logging and plans do not exist yet, so the nutrition and training panels show empty states until WP 5 and WP 8/9.
- ~~Imperial display conversion is stored as a preference but not yet applied to screens.~~ Corrected 2026-11-04: the units preference is applied to every body-weight display (dashboard tiles, activity rows, Track history) and tested in `weight_screen_test`/`home_screen_test`; input stays in kg (stated in the UI). Imperial *entry* is not offered (D04 NUT-022 partial).
- Day-start hour has no UI control yet (stored, default midnight).

## CI evidence
| Commit | CI | Android build | iOS build | Debug release | Integration tests |
|---|---|---|---|---|---|
| 961ea50 | 41709941612 success | 41709941638 success | 41709941695 cancelled (concurrency) | 41709941686 success | 41709942516 cancelled (concurrency) |
| 7e892e1 | 41711410956 success | 41711411022 cancelled (concurrency) | 41711410943 cancelled (concurrency) | 41711410814 success | 41711410799 cancelled (concurrency) |

Neither WP 4 commit has its own iOS or integration result: both were cancelled by the next push. The first iOS success on the branch after WP 4 is 41711905223 (9ed0e7d, WP 5). The integration test that carries the WP 4 verification ("change target, restart, verify") first ran to completion on the WP 3 closing commits (see the audit below).

## Acceptance audit (2026-11-04, branch `ccr-9fda2c32-wr163b`)
Conducted after WP 3 acceptance. Independent of the review pass above: a fresh reviewer read the WP 4 diff (`eeab56e..7e892e1`) against the D06 criteria, and every finding below was then verified directly in the code by the auditor before being recorded.

### Independent verification
- Local run of the WP 4 commit 7e892e1 (Flutter 3.47.9, Linux): analyzer clean; **254 tests pass** (the record says 251; the three extra are counted in the same suite, no discrepancy in content); hand-written line coverage 85.9 %.
- The integration test's "restart" (`app_test.dart`, `restart()`) is a widget remount over the same in-memory database object, not a process restart. On the emulator (CI) it had never completed: the run on af0c763 was cancelled by concurrency, and the run on 24547dc and on the WP 3 audit commit failed on `Targets saved` and hung to the 60-minute timeout, because `pumpAndSettle` returns during database I/O on a device. Fixed in the WP 3 closing commits 33b0730, ecd924b and 7c9067f (`pumpUntil`/`pumpUntilGone` after every async action, `scrollUntilVisible` for the lazily built save buttons, bounded database close, job timeout 40 min). First green emulator run: **41790734724** on 7c9067f, covering weight, targets, custom food creation, logging, dashboard after remount, and the real on-device database open/migrate/persist/delete.

### Findings
| ID | Finding (verified in code) | Severity | Resolution proposed |
|---|---|---|---|
| B1 | "Targets persist across restart" is demonstrated by a remount on the same database object, not a restart. The file-database integration test proves persistence of a weight entry across remount, not of a target. The goals-table round trip is unit-tested (`save_daily_targets_test`, `drift_goal_repository_test`). | Medium (evidence gap, not a defect) | Extend the file-database integration test to set a target and verify it after remount; owner may accept the unit + remount evidence instead. |
| B2 | "Dashboard reflects database changes live" is correct by construction (every dashboard provider is a drift `watch()` stream) but no test mutates the database while the dashboard is mounted; the WP 4 commit's integration test did (`nav-home` after a weigh-in), WP 5 removed that step. | Low | Add one widget test that inserts a row after pumping the dashboard, or restore the integration step. |
| B3 | Training panel: `recentSessionsProvider` uses `watchAll(limit: 5)` and the panel prints that length as "N recent session(s)"; with more than five sessions it says 5. "Next session" is explicitly deferred to WP 9 (`home_screen.dart:177`). | Low (no sessions can be logged before WP 9) | Count query in WP 9. Scope item "next session" is NOT MET by design until WP 9. |
| B4 | Macro bars render "0 / 0 g" for macros without a target once any target exists (`home_screen.dart:122-133` pass `?? 0`); the integration test's own path (calories only) shows three such rows. | Low (cosmetic, misleading) | Show "no target" for null targets. |
| B5 | Header date/greeting reads the clock once (`home_screen.dart:27`) and does not watch the minute tick; across midnight the nutrition panel moves to the new day while the caption shows yesterday. | Low | Watch the minute tick for the caption. |
| B6 | Training panel uses `sessions.value?.length ?? 0`; a stream error shows "0 sessions" instead of an error state. | Low | Use the same `when` pattern as the activity panel. |
| B7 | Standards: `settings_screen.dart:95` reads the settings repository directly from presentation (read-modify-write in UI, exception not wrapped in `Result`, §5); `save_daily_targets.dart:53-74` replaces goals kind by kind in separate transactions, so a mid-loop failure leaves a partial save while returning `StorageError`. | Low / Medium | Move the read into `SaveSettings`; wrap the kind loop in one transaction. |
| B8 | Record claims not supported: "error states are rendered by the shared RfErrorState (component test)" — no test references `RfErrorState`, `RfEmptyState` or `RfLoading`; "imperial not yet applied to screens" (Outstanding) contradicts the Review section and the code, which applies it to every body-weight display. | Low (record accuracy) | Corrected here; the record text above is left as delivered. |

Verified true: ten review findings applied as described (atomic `replaceActive`, use case reads goals itself, settings watched with `select`, stack traces preserved, shared `IdGenerator`/`formatNumber`, minute tick for the day key); no stream leaks (app-scoped providers, periodic stream cancelled on dispose); units applied to body-weight displays; domain has no Flutter imports; presentation imports no `lib/data`.

### Acceptance criteria and scope (D06 WP 4)
| Item | Status | Evidence |
|---|---|---|
| go_router routes | Met | `router.dart`; `test/app/router_test.dart` |
| Bottom navigation Home, Food, Recipes, Train, Progress, Settings | Partial (deviation) | Tabs are Home, Train, Fuel, Track, Goals per the approved brand mock-up (WP 2); Settings is a pushed route. D06 wording not updated. |
| Dashboard: today's calories/macros vs targets | Met | `home_screen_test` "shows intake against targets from the database" (B4 caveat) |
| Dashboard: next session | Not met (deferred to WP 9 by design) | `home_screen.dart:177` |
| Dashboard: latest weight | Met | integration test; no widget test of the populated body panel |
| Dashboard: workouts count | Partial | B3 |
| Settings with persisted targets and units | Met | `settings_screen_test` (3), `save_daily_targets_test` (4), goal repository `replaceActive` tests |
| Empty states for every panel | Met | `home_screen_test` "shows empty states when nothing is stored" |
| Dashboard reflects database changes live | Met in code, evidence partial | B2 |
| Targets persist across restart | Partial | B1 |
| Widget tests for each panel state | Partial | all-empty and nutrition-populated covered; training-populated, body-populated, loading and error states not covered |
| Integration test "change target, restart, verify" | Partial | remount, not restart (B1); green on the emulator in run 41790734724 |

### Deviations from approved requirements
1. Navigation tabs follow the brand mock-up (Home, Train, Fuel, Track, Goals) rather than the D06 list; Settings is pushed from the app bar. Approved implicitly with WP 2; D06 should be amended.
2. "Next session" deferred to WP 9.
3. Day-start hour stored but has no UI control.

### Recommendation
**Conditionally accept**, with conditions for the owner to confirm:
- C1. B1/B2 evidence: either accept the unit tests plus remount as sufficient for "persist across restart" and "live", or require the two small test additions before acceptance.
- C2. B3–B7 are tracked as debt with resolution packages (B3 → WP 9; B4, B5, B6 → next dashboard change, WP 10 at the latest; B7 → WP 6 as the next package touching settings and use cases). None risks user data.
- C3. D06 WP 4 scope line amended to the approved tab set.

## Owner decision on the audit (2026-11-04) and closure actions
- **C1 (B1, B2): changes required.** Both evidence gaps closed with tests, no implementation change: integration test extended (target saved in Settings, ProviderScope disposed so the file database closes, app rebuilt on a fresh connection, dashboard shows the target; target then cleared); `home_screen_test` group "updates live while mounted" (two tests).
- **C2: deferrals approved** with B7 split. B3 → WP 9 (TD-27), B4 → WP 10 at latest (TD-28), B5 → WP 10 at latest (TD-29), B6 → WP 10 at latest (TD-30), B7a → WP 6 (TD-31). **B7b fixed before acceptance**: `GoalRepository.replaceActiveAll` applies every kind in one transaction and `SaveDailyTargets` issues a single call; regression tests "rolls back every kind when a later entry fails" (repository) and "applies all changed kinds in one repository transaction" (use case).
- **C3: approved.** D06 WP 4 scope line amended to the five approved tabs.
- **B8: record corrected** in place above.

### CI evidence for the closure commit
Appended when the runs complete.
