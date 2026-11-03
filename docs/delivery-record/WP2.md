# Delivery record — WP 2: Application foundation and design system

Status: **in progress** (started 2026-11-03 after WP 1 acceptance and merge of PR #1)
Branch: `ccr-ac6db77c-jcnexo`, restarted from `main` at 30e51b0.

## Task 1 — ADR-0003 step 2: remove ZIP archives and legacy workflow (done)
- Removed: `RepForge-Android-Project.zip`, `RepForge-v0.3.0-Android-source.zip`, `.github/workflows/build-android-apk.yml`.
- Retained: `legacy/android/` (verbatim extraction, read-only), git history of the archives (78cffbd, bfd0b34).
- Docs updated: ADR-0003 (execution record), D01 (historical note), D07 (transition complete), `legacy/android/NOTICE.md`, root README.
- Verification: `git ls-files '*.zip'` returns nothing; remaining workflows are `ci.yml`, `android.yml`, `ios.yml`, `integration.yml`, `debug-release.yml`.

## Remaining WP 2 scope (D06)
Design tokens finalised (colour, type scale, spacing, radii, elevation), light/dark themes, component set (`RfButton`, `RfTextField` numeric/unit variants, `RfMacroBar`, `RfTrendChart`, `RfListTile`, plus existing card/stat/state widgets), navigation shell polish, accessibility baseline (48 dp targets, semantics, text scaling), debug-only component gallery, golden tests, `docs/design-system.md`.
