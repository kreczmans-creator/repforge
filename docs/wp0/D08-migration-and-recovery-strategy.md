# D08 — Migration and Recovery Strategy

Status: Proposed
Date: 2026-10-31

## 1. Summary

The existing Android prototype is **not migrated to the new stack**. It is a 1,500-line single-activity Kotlin application that has never compiled, has no tests, and stores training data as delimited strings. Its value is as a specification by example, not as code. Everything user-facing is reimplemented in the target architecture (D03). Useful data and knowledge are carried across deliberately.

## 2. Disposition of existing assets

| Asset | Location | Disposition | Rationale |
|---|---|---|---|
| `RepForge-v0.3.0-Android-source.zip` | repo root | **Deprecate → Remove** (after ADR-0003 approval and extraction to `legacy/android`) | Binary blob in git; not reviewable; CI builds from it. History remains in git. |
| `RepForge-Android-Project.zip` | repo root | **Remove** (after ADR-0003) | Superseded by v0.3.0 archive; older, with literal `\n` syntax errors. |
| `.github/workflows/build-android-apk.yml` | | **Deprecate** (manual trigger only) then **Remove** with the ZIPs | Builds the wrong artefact; no gates (D07). |
| Kotlin source (`MainActivity.kt`, `RepForgeDatabase.kt`, `OpenFoodFacts.kt`) | inside ZIP | **Retain read-only** under `legacy/android/` for reference; **Reimplement** in Dart | Not architecturally sound; serves as behavioural reference. |
| Room entities (`NutritionEntry`, `WorkoutLog`, `MeasurementEntry`, `WorkoutTemplate`, `Recipe`) | `RepForgeDatabase.kt` | **Refactor as design input**: field lists inform the new domain model; `MeasurementEntry` site list reused as-is; `WorkoutTemplate`/`WorkoutLog` replaced by structured model | Measurement fields match the product vision; training model is unsuitable (TD-09). |
| 22 seed recipes | `defaultStarterRecipes()` in `MainActivity.kt` | **Retain as data**: extract to `assets/seed/recipes.json` with `provenance: estimated` and the existing nutrition notes | Genuine authored content; nutrition values labelled estimated as the source already states. |
| Open Food Facts client | `OpenFoodFacts.kt` | **Reimplement**: reuse endpoint shapes (`/cgi/search.pl`, `/api/v2/product/{code}.json`, field names `energy-kcal_100g`, `proteins_100g`, `carbohydrates_100g`, `fat_100g`) and the User-Agent convention | Small; rewrite in Dart with typed errors and caching. |
| Colour tokens (Ink, Panel, Panel2, Electric, Purple, Green, Muted, Border) | `MainActivity.kt` | **Retain as starting palette** for the design system; add a light theme; verify contrast | Only visual identity that exists. |
| Navigation structure (Home, Food, Recipes, Train, Progress, Settings) | `RepForgeApp` | **Retain as information architecture** for WP 4 | Matches product domains. |
| README in archive | | **Retain** content as historical record under `legacy/android/README.md`; new root README written in WP 1 | |
| Room migration 1→2 | | **Remove** (no users on new stack) | New schema starts at version 1 in drift. |
| Existing on-device data from prototype installs | user devices | **No migration path**; prototype was never built, so no installs exist | Confirmed: no APK artefact has ever been produced by CI. |

## 3. Recovery steps for the legacy prototype (optional)

If the owner wants the Kotlin prototype buildable as a historical artefact, the minimum change set is documented in D01 §5 (two edits: the DAO declaration and the barcode import). This is optional and must not consume effort that belongs to WP 1. It is recommended only if a working Android build is needed as a stop-gap for personal use before the Flutter app reaches parity (estimated at WP 6).

## 4. Rules during transition

1. The `main` branch is not modified until WP 0 is accepted; WP 1 lands via a pull request from a feature branch.
2. Nothing is deleted from `main` without an accepted ADR (ADR-0003 covers the ZIPs and legacy workflow).
3. The legacy source is extracted verbatim (no fixes applied) so that the record matches what was uploaded.
4. Parity tracking: a table in `docs/delivery-record/` maps each prototype capability to the work package that reimplements it, so nothing is silently dropped.

## 5. Parity map (prototype capability → target WP)

| Prototype capability | Target WP |
|---|---|
| Daily calories and macro summary (Home) | WP 4, WP 5 |
| Food search (Open Food Facts) | WP 5 |
| Barcode scan → lookup → log | WP 6 |
| Quick-add custom food with servings | WP 5 |
| Today's diary list with delete | WP 5 |
| Recipe library with ingredients/method, log one serving | WP 7 |
| Workout template builder and session log | WP 8, WP 9 |
| Workout history | WP 9 |
| Measurements (weight + 12 sites) with trend chart and history | WP 10 |
| Daily targets (in-memory) | WP 3 (persisted settings), WP 11 (goals) |
