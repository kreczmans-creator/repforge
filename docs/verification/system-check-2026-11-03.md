# System check against the recovery brief — 2026-11-03

Purpose: answer the owner's question "is what we have so far a functioning system?" against the original recovery brief (sections 1–8) and the D04 requirements baseline. Every claim below names its evidence. "Verified" means demonstrated by an automated test or a CI run; "device" means also exercised on the owner's phone or the CI emulator.

Branch `ccr-ac6db77c-jcnexo`; app commit under check: see the CI table at the end.

## 1. Headline

The application builds, installs and runs on Android, builds for the iOS simulator, and the features delivered so far work end to end on the CI emulator: body-weight logging with real on-device persistence, daily nutrition targets, a food diary with local and online search, custom foods, saved meals, and the dashboard that reads all of it. It is a functioning **foundation plus nutrition slice**, not yet the product described in section 5 of the brief: recipes, training, body measurements beyond weight, goals beyond nutrition targets, analytics, backup UI, barcode scanning and health integrations are not built. Nothing in the app pretends otherwise; unbuilt pillars show labelled "not yet available" screens.

## 2. Brief section by section

| Brief area | Status | Evidence |
|---|---|---|
| §1.2 Cross-platform, Android and iOS from one codebase | Verified (build level) | Android debug APK and iOS simulator build in every CI run; owner installed the WP 1 APK on a phone. iOS has never run on a device or been signed (needs Apple Developer account, D07 §2.4). |
| §2 Baseline established; ZIPs retired | Done | D01; ZIPs and legacy workflow removed under ADR-0003; `legacy/android` retained read-only. |
| §3 Framework decision | Done, accepted | D02, ADR-0002 (Flutter). |
| §4 Layered architecture, DI, boundaries | Implemented | `lib/domain` has no Flutter imports (standards §3); use cases return `Result`; repositories behind interfaces; platform adapters not yet needed (no camera/health yet). Reviewed independently after each package. |
| §4.1 Testability, migrations, data integrity | Verified | 298 unit/widget tests; schema v1→v3 migration tests with drift `SchemaVerifier`; backup round-trip tests; validation at use-case boundary. |
| §4.2 Local-first, no remote dependency | Verified | Logging works with the online lookup failing (widget test "offline search still shows local foods"); all data in SQLite; no accounts, no network except food lookup. |
| §4.3 Platform integrations abstracted | Partly | `FoodLookupService` abstraction exists; camera, barcode, Health Connect/HealthKit, notifications, background, secure storage: not built (WP 6, 13). |
| §5.1 Nutrition | Partly (see §3 below) | Daily kcal, protein, carbs, fat, fibre; food database (local + Open Food Facts); custom foods and servings; meal logging; saved meals; food history via local search; daily and weekly summaries; provenance labels. Missing: barcode scanning, recipes, meal planning, food edit/delete, recent/frequent suggestions. |
| §5.2 Recipes | Not built (data model and repository exist and are tested; no UI) | WP 7. |
| §5.3 Strength training | Not built (data model, rules and repositories exist and are tested; no UI) | WP 8–9. |
| §5.4 Body composition | Weight only | Weight logging/history/delete verified on device; 12 circumference sites exist in the schema and repository with tests, no UI; no charts yet (chart component exists). |
| §5.5 Goals and analytics | Nutrition targets only | Calorie/macro/fibre targets persisted as goals and shown on the dashboard; weekly nutrition summary. No weight/measurement/training goals UI, no combined weekly summary. No AI/coaching (GOL-011 respected). |
| §6 Design system | Implemented | Tokens, two themes (dark default), 14 components, gallery goldens, WCAG contrast tests, 48 dp targets, text scaling test. Manual TalkBack/VoiceOver pass not yet done. |
| §7 Governance | Implemented | ADR-0001..0005; engineering standards; delivery records WP0–WP5; independent review on every package with findings applied. |
| §8 CI/CD | Implemented for debug | Format, analyse, codegen check, tests, Android APK, iOS simulator build, emulator integration tests, rolling debug release. Not yet: signed release, store distribution, coverage gate, dependency audit workflow. |

## 3. Requirement coverage (D04, P1 only)

Counts of P1 requirements by state. "Verified" = automated test or CI; "Implemented" = code exists without a specific test; "Partial" = some acceptance criteria met; "Not started" = nothing beyond the data model.

| Group | P1 total | Verified | Partial | Not started | Notes |
|---|---|---|---|---|---|
| GEN | 15 | 9 | 3 | 3 | Verified: 001 (build), 002, 003, 004, 005, 006, 007, 009, 010, 012. Partial: 011 (contrast/targets tested, screen-reader pass pending), 013 (≤4 taps by design, not timed), 015 (persistence proven; kill-during-write not tested). Not started: 008 (backup UI; repository tested), 014 (cold start not measured). |
| NUT | 23 | 14 | 3 | 6 | Verified: 001–005, 007, 009–013, 015, 016, 018, 021. Partial: 017 (rules tested, spec document is `data-model.md` not a standalone spec), 019 (per-entry provenance shown; day totals do not yet show the weakest provenance), 022 (metric conversions tested, imperial entry not offered). Not started: 006 (barcode), 008 (edit/delete custom food), 014 (recent/frequent), 020 (estimated-value creation flow), 023 (import date on OFF foods: source stored, date is createdAt). |
| BCM | 9 | 1 | 1 | 7 | Verified: 001 (weight, on device). Partial: 004 (dated, delete; no back-date/edit UI). Not started: 002, 003 (schema + repo tested, no UI), 005–009. |
| GOL | 7 | 3 | 1 | 3 | Verified: 001, 002, 011. Partial: 006 (startDate recorded, not shown). Not started: 003, 007, 008. |
| DAT | 9 | 5 | 1 | 3 | Verified: 001, 002, 003/004 (repository round-trip, no UI), 007 (migrations up; downgrade not handled), 009 (no auth exists). Partial: 005 (JSON export exists as repository). Not started: 006 (CSV), 012 (delete all). |
| UXD | 9 | 7 | 2 | 0 | Verified: 001, 002, 003, 004, 006, 007, 009 (chart component tested; no chart on a live screen yet). Partial: 005 (labels on components; full audit pending), 008 (food logging ≤ 4 taps; repeat-food shortcut missing). |
| PLT | 5 | 0 | 0 | 5 | No platform integrations yet (WP 6, 13). Secure storage not needed until sync. |
| RCP / TRN | 11 / 22 | 0 | 0 | 33 | Domain rules and repositories tested; no UI. |

## 4. What "functioning" means today, concretely

Verified on the CI Android emulator (integration test, see CI table) and locally:
1. Install and launch; dashboard shows empty states.
2. Log a body weight; it persists in the real on-device SQLite file across an app rebuild; delete it.
3. Set a calorie target in Settings; the dashboard and diary use it after restart.
4. Create a custom food in the UI, log 150 g of it to a meal, see 570 kcal in the diary and "570 of 2100" on the dashboard after restart.
5. Search Open Food Facts (fake service in tests; real client tested against captured responses), choose a portion, log; offline keeps local results.

Also verified from the build container with the app's own client against the live Open Food Facts API (`app/tool/off_probe.dart`, 2026-11-03): search "greek yogurt" returned 5 crowdsourced foods with per-100 g values; barcode 3017624010701 resolved to Nutella (Ferrero) 539 kcal; an unknown barcode returned "not found".

Not verified anywhere: behaviour on a physical iOS device; Open Food Facts traffic from a phone over mobile data; the v1→v3 migration on the owner's phone (tested in CI against the v1 snapshot; the owner's device holds v1 data from the WP 1 APK and will migrate on first launch of the new build).

## 5. Risks to call out
- The owner's phone has WP 1 data in schema v1. The next installed build runs the v1→v3 migration. It is tested, but this is the first real migration; the owner should note the weight entries before updating and confirm they are still listed after.
- Open Food Facts' legacy search endpoint was down on the implementation day; the app uses the newer search service. If OFF changes it, search degrades to local-only (handled, labelled) rather than failing.
- iOS remains build-only.

## 6. Recommendation
Treat the current build as a usable personal food-and-weight logger for the owner to live with while WP 6–10 add barcode scanning, recipes, training and measurements. Before WP 6: owner installs the latest debug APK, confirms the migration kept the WP 1 weight entries, and logs a few real foods including an Open Food Facts search over mobile data.

## CI evidence
Appended when the runs for the integration-test commit complete.
