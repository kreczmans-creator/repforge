# Changelog

All notable changes to RepForge are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) and the project uses
[Semantic Versioning](https://semver.org/).

**No release has been tagged yet.** The application version in
`app/pubspec.yaml` is **0.4.0+1**, but no `v0.4.0` (or any other) tag has been
cut, and no signed release exists; the only distributed builds are the debug
test builds of the rolling `debug-latest` release. The work delivered so far is
therefore listed under *Unreleased*, grouped by work package as recorded in
`docs/delivery-record/`. Acceptance status is stated per package; it is the
status recorded in each delivery record, not a claim made by this file.

Release rule (`.github/workflows/release.yml`): a tag `vX.Y.Z` is released only
when `app/pubspec.yaml` has version `X.Y.Z` and this file has a `## [X.Y.Z]`
heading. To release, move the `[Unreleased]` entries under a new
`## [X.Y.Z] - YYYY-MM-DD` heading, bump the pubspec version in the same commit
and tag that commit. The release workflow copies the text from that heading up
to the next `## ` heading into the GitHub Release notes, so the history section
at the end of this file is never included. The pubspec build number (`+N`, the
Android `versionCode`) must also increase with every release, because Google
Play rejects an upload whose versionCode is not higher than the previous one;
bump it in the same commit as the version name.

## [Unreleased]

### Added

- WP 14: release workflow `.github/workflows/release.yml` (verify gates, check
  that tag, pubspec version and this changelog agree, signed Android APK and
  AAB, GitHub Release with these notes, iOS simulator build only).
- WP 14: `release` signing configuration in `app/android/app/build.gradle.kts`,
  read from `RF_KEYSTORE_PATH`, `RF_KEYSTORE_PASSWORD`, `RF_KEY_ALIAS` and
  `RF_KEY_PASSWORD`; without them the build keeps the debug signing as before.
- WP 14: this changelog.
- NUT-023 (WP 14): the portion sheet shows where a food came from, for example
  "Source: Open Food Facts · 3017620422003 · imported 2026-11-03", or
  "Your food · created 2026-11-03" for foods the user created; an online
  search hit that has not been saved yet reads "not saved yet".

### Changed

- WP 14: the rolling debug release creates the Android debug keystore once and
  saves it to the Actions cache; it and the Android build restore it, so
  successive CI test builds share one signing certificate and can be installed
  over each other, and each run checks that the built APK's signer matches the
  keystore. If the cache entry is evicted a new certificate is created and
  testers uninstall once.

## History before the first tag

Work delivered before any version was tagged, by work package, as recorded in
`docs/delivery-record/`. It is history, not release notes: when the first
release is cut, only the `[Unreleased]` entries move under the version heading;
this section stays where it is and is not copied into the release notes.

### WP 0 — Recovery and technical baseline (2026-10-31; accepted 2026-11-01)

- Recovery report, framework evaluation, target architecture, requirements
  baseline, work-package roadmap, CI/CD strategy and engineering standards
  (`docs/wp0/D01`..`D08`, `docs/engineering-standards.md`); ADR-0001..0004.
- Legacy Kotlin prototype extracted verbatim under `legacy/android/` (read-only).
  Its CI failed in 9 of 9 runs; the cause was reproduced locally.

### WP 1 — Cross-platform framework and architecture foundation (2026-11-01; accepted 2026-11-03)

- Flutter 3.47.9 application under `app/`: body-weight logging end to end,
  Riverpod, drift (SQLite), go_router, freezed, design-system basics.
- Workflows `ci.yml`, `android.yml`, `ios.yml`, `integration.yml`; 29 automated
  tests at delivery; debug APK confirmed on a physical device by the owner.

### WP 2 — Application foundation and design system (2026-11-03; accepted 2026-11-03)

- Design system v1.0 (tokens, light and dark themes, components, fonts, brand
  assets, launcher icons) and the five-pillar navigation shell; dark is default.
- Legacy ZIP archives and the legacy workflow removed (ADR-0003). 90 tests at
  delivery; four recorded design deviations approved by the owner.

### WP 3 — Domain models and local persistence (2026-11-03; accepted 2026-11-04)

- Domain value objects and models for nutrition, recipes, training,
  measurements, goals and settings; drift schema v2 with 13 tables and
  sync-ready columns; repositories; JSON backup export/restore.
- 236 tests at delivery; the 80 % hand-written coverage gate was set by the
  owner at acceptance and is enforced in CI (`app/tool/coverage_gate.dart`).

### WP 4 — Navigation, dashboard and application shell (2026-11-03; accepted 2026-11-04)

- Settings screen (daily targets, units, theme, effort scale, week start) and a
  live dashboard (calories and macros against targets, next plan, latest
  weight, recent activity). Recorded debt TD-27..31 remains open.

### WP 5 — Nutrition and food database (2026-11-03; accepted by owner decision 2026-11-04)

- Open Food Facts lookup with typed errors, local-first search, custom foods
  and serving sizes, portion sheet, daily diary with edit and delete, saved
  meals, weekly summary, provenance labels, schema v3/v4.
- The airplane-mode device verification (D05 V-01) is recorded as unconfirmed
  and open.

### WP 6 — Barcode scanning and food logging (2026-11-04; conditional acceptance, not closed)

- Barcode scanning behind a `BarcodeScanner` adapter (`mobile_scanner`),
  EAN-13, EAN-8, UPC-A and UPC-E validation, camera permission flow, not-found
  path into custom-food creation, cached product lookup; ADR-0006.
- 429 tests at delivery. Physical-device verification on Android and iOS is
  outstanding and owner-performed.

### WP 7 — Recipe management and meal planning (2026-11-04; accepted and closed 2026-11-05)

- Nutrition calculation specification (NUT-017) with executable worked
  examples; recipes with computed per-portion nutrition, scaling,
  substitutions, favourites; the 22 legacy recipes imported as estimated;
  28-day meal plan and prep batches; meal rename and reorder (NUT-011);
  schema v5.

### WP 8 — Exercise library and training architecture (2026-11-05; active, not accepted)

- Stages 1 and 2 delivered: exercise taxonomy, 89-exercise seed library,
  library queries, `RecordSet` validation, workout plans and splits, schema v6
  with CHECK constraints, Train-tab library screens, independent review fixes.
- Stage 3b (schema v8, decision baseline, backup format 3) is not part of the
  integrated build and waits for an owner decision (OB-WP8-04). The scope was
  expanded on 2026-11-05 to the comprehensive exercise library; stages 3 to 6
  remain.

### WP 9 — Workout planning and workout execution (2026-11-05; accepted and closed 2026-11-06)

- Plan builder, splits, scheduling, workout session screen with per-set weight,
  reps and RPE or RIR, rest timer with opt-in local notifications (ADR-0007),
  previous-performance hints, derived personal records, volume, notes, history
  with edit, delete and undo; schema v7. 1186 tests at delivery.
- Device behaviour of the rest-timer notifications is not verified.

### WP 10 — Body composition and measurement tracking (2026-11-05; accepted and closed 2026-11-05)

- Weight and twelve circumference sites with strict validation, history with
  edit and delete, trend charts with ranges, comparison, summary, CSV export
  and a backup screen through a file-output port (ADR-0011). No schema change.
  1470 tests at delivery. Spreadsheet compatibility and device checks are
  deferred and recorded.

### WP 15 — Nutrition entry units (2026-11-06; in progress, not accepted)

- Entry in kg and l with exact conversion to canonical g and ml in the portion
  sheet and the recipe ingredient sheet (mg in the domain only); no schema
  change. Imperial entry units (OQ-02) and custom-food serving units remain
  open owner decisions.

### WP 17 — Fuel and Train workflow completion (2026-11-06; in progress, not accepted)

- Fuel: pick from library and recent items in the add flow, recipe duplicate
  and category filter. Train: plan duplicate and delete, save a session as a
  plan, session elapsed time, drag reorder of session exercises.
- The 9.00-point allocation is proposed and not yet approved by the owner.

### Overnight integrated delivery campaign (2026-11-06 to 2026-11-07)

- Release candidate `aa59021`: WP 15 stages 1 and 2 and WP 17 S3 and S4
  integrated with their review fixes, eight corrections from a cross-package
  review, and the Owner Actions & Delivery Blockers workspace (Settings >
  Delivery). WP 8 stage 3b was left out.
- All four workflows green on that commit: 2,742 tests passed, 5 skipped,
  93.0 % hand-written coverage, 8 of 8 emulator integration tests. Debug APK
  built and signature-verified; no physical-device run.
- CI fixes (WP 14): emulator disk space and boot wait, APK signature and
  metadata verification steps, presentation-isolation architecture test.
  Finding: each hosted runner signed with its own debug keystore, so CI builds
  could not be installed over each other (addressed above).
- Report: `docs/verification/overnight-campaign-2026-11-06.md`.

### Parallel workstream assessment (2026-11-06)

- Repository-grounded baseline and plan for the Fuel recipe library, workout
  library and free-workout capability; opened WP 15 and WP 17 work and the
  owner decisions D-1..D-7. No code change in the assessment itself.
- Report: `docs/verification/parallel-workstream-assessment-2026-11-06.md`.
