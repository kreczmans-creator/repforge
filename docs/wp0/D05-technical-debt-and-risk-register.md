# D05 — Technical Debt and Risk Register

Status: Living document (opened at WP 0)
Date: 2026-10-31
Scales: Severity and Impact: Low / Medium / High / Critical. Likelihood: Low / Medium / High. Priority: P1 (act in WP 0–1), P2 (WP 2–4), P3 (later).

## A. Technical debt in the existing implementation

| ID | Description | Severity | Likelihood | Impact | Recommended action | Dependencies | Priority |
|---|---|---|---|---|---|---|---|
| TD-01 | Application source lives only inside ZIP archives in the repo root; git tracks binary blobs, not code. Diffs, reviews and blame are impossible. | Critical | Certain | Critical | Extract source into git (`legacy/android`), build from the tree, retire the ZIPs (ADR-0003). | Owner approval | P1 |
| TD-02 | Two ZIPs with different content (`RepForge-Android-Project.zip` 2026-10-28, `RepForge-v0.3.0-Android-source.zip` 2026-10-31) coexist; only the latter is wired to CI. | High | Certain | Medium | Mark the older archive obsolete; remove with TD-01. | TD-01 | P1 |
| TD-03 | Syntax error `abstract fun dao(): RepForgeDao()` in `RepForgeDatabase.kt:127` blocks compilation (verified from CI log run 9). | Critical | Certain | Critical | Documented; fix only if the legacy app is to be kept buildable (see D08). | — | P1 |
| TD-04 | `collectAsStateWithLifecycle` used without an explicit `lifecycle-runtime-compose` dependency. Verified by build to be **non-blocking**: the artifact arrives transitively. Explicit declaration is hygiene only. | Low | Certain | Low | Declare explicitly if the legacy app is kept buildable. | — | P3 |
| TD-05 | Barcode import `com.google.android.gms.mlkit.codescanner.GmsBarcodeScanning` is not the package shipped by `play-services-code-scanner` (`com.google.mlkit.vision.codescanner`). Hidden by TD-03. | High | Certain | High | As TD-03. | TD-03 | P1 |
| TD-06 | Single 1,053-line `MainActivity.kt` holds UI, data access, business rules and 660 lines of seed recipe data. No separation of concerns, untestable. | High | Certain | High | Do not refactor; reimplement in target architecture (D03). Seed data extracted to a JSON asset. | ADR-0002 | P2 |
| TD-07 | No tests of any kind (unit, instrumentation, UI). No lint configuration. | High | Certain | High | Target architecture mandates tests per layer (D03 §6). | — | P1 |
| TD-08 | No Gradle wrapper in the archive; CI installs its own Gradle. Local/CI drift. | Medium | High | Medium | Irrelevant once Flutter is adopted; for legacy keep, add wrapper. | — | P3 |
| TD-09 | Workout data model stores exercises as a pipe-delimited string (`"Squat|3|5"`) and session results as a free-text summary. No per-set records, no exercise entity, no PRs possible. | High | Certain | High | Reimplement with structured model (D03 §2.3). | — | P2 |
| TD-10 | Food entries from search/barcode are logged as "per 100 g" with no portion input; macros are therefore wrong for any real serving. | High | Certain | High | Portion model in target architecture; requirement NUT portion scaling. | — | P2 |
| TD-11 | Daily targets held in Compose `remember` state only; lost on process death. Settings screen admits this. | Medium | Certain | Medium | Persist settings table. | — | P2 |
| TD-12 | Dates stored as free-text `String`; Progress screen accepts any text as date with no validation. | Medium | High | Medium | ISO-8601 typed dates with validation at use case. | — | P2 |
| TD-13 | Seed recipes insert on every app start (`insertRecipes` with IGNORE in `onCreate`); nutrition values are self-described "planning estimates". | Medium | Certain | Low | Keep recipes as seed data flagged `estimated`; insert once on first run. | — | P2 |
| TD-14 | `exportSchema = false` in Room; no schema history, migration 1→2 untested. | Medium | Certain | Medium | Target: committed schema snapshots and migration tests. | — | P2 |
| TD-15 | Network via raw `HttpURLConnection` with generic `catch (Exception)`; no typed errors, no retry, no offline cache of looked-up products. | Medium | Certain | Medium | Typed `AppError`, cached product table. | — | P2 |
| TD-16 | `android:allowBackup="true"` sends the unencrypted personal-data database to Google backup by default without a stated privacy decision. | Medium | High | Medium | Owner decision (R-08). | — | P2 |
| TD-17 | No app icon, no resources directory, no ProGuard/R8 rules, no release signing configuration. | Low | Certain | Low | Addressed by new app scaffolding. | — | P3 |
| TD-18 | Food search results have no pagination, no debouncing and run on every button press; trend chart has no axis labels or dates. | Low | Certain | Low | Design system chart component. | — | P3 |
| TD-19 | README states "has not been compiled or device-tested" and lists v0.1.0 in Settings while archive says v0.3.0. Version identity inconsistent. | Low | Certain | Low | Single version source in `pubspec.yaml`. | — | P3 |
| TD-20 | GitHub Actions use action majors pinned to Node 20 (deprecated); forced onto Node 24. | Low | High | Low | Upgrade action versions in WP 1. | — | P2 |

## B. Project and delivery risks

| ID | Description | Severity | Likelihood | Impact | Recommended action | Dependencies | Priority |
|---|---|---|---|---|---|---|---|
| R-01 | Framework decision (ADR-0002) is not accepted and work continues on the Android-only prototype, re-creating the iOS gap. | Critical | Medium | Critical | Owner decides ADR-0002 before WP 1 starts. | — | P1 |
| R-02 | Solo owner learning Dart; early velocity lower than expected. | Medium | High | Medium | WP 1 vertical slice sized to one to two weeks; strong lint and tests catch mistakes early. | ADR-0002 | P1 |
| R-03 | iOS signing and distribution blocked by lack of Apple Developer account or macOS runner budget. | High | Medium | High | Decide account and budget during WP 1; simulator builds until then. | Owner | P1 |
| R-04 | Scope pressure: the product vision lists over 100 requirements; attempting many at once repeats the prototype's failure mode. | High | High | High | Strict work-package sequencing (D06); each WP has acceptance criteria and a delivery record. | — | P1 |
| R-05 | Nutrition data quality: Open Food Facts is crowdsourced and incomplete; users may trust wrong numbers. | High | High | Medium | Provenance labels on every value; allow user correction; consider licensed database later. | — | P2 |
| R-06 | Health platform APIs change (Health Connect permission model, HealthKit entitlements) and cannot be tested in CI. | Medium | Medium | Medium | Adapter boundary; manual device checklist; WP 13 late in roadmap. | D03 | P3 |
| R-07 | Data loss from an untested migration or a bug in export/import. | Critical | Medium | Critical | Migration tests from every prior version; backup before migration; export round-trip tests. | WP 3 | P1 |
| R-08 | Privacy: personal body data backed up or synced without explicit consent or policy. | High | Medium | High | Owner decides backup posture; no cloud sync before a privacy policy exists. | Owner | P2 |
| R-09 | Plugin abandonment (barcode, health) in the Flutter ecosystem. | Medium | Low | Medium | Adapter interfaces so a plugin swap touches one file; pin versions; weekly dependency report. | D03 | P3 |
| R-10 | Legacy ZIP workflow keeps running and keeps failing, creating noise and confusion about project health. | Low | High | Low | Disable automatic trigger in WP 1 (D07 §4). | — | P2 |
| R-11 | Recipe nutrition seeds are estimates presented as numbers; users may treat them as facts. | Medium | High | Medium | Store with `estimated` provenance and show the label in UI. | — | P2 |
| R-12 | No documented product decisions (units, markets, food database licence). | Medium | High | Medium | D04 open questions answered before WP 5. | Owner | P2 |
