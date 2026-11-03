# Delivery record — WP 2: Application foundation and design system

Status: **in progress** (started 2026-11-03 after WP 1 acceptance and merge of PR #1)
Branch: `ccr-ac6db77c-jcnexo`, restarted from `main` at 30e51b0.

## Task 1 — ADR-0003 step 2: remove ZIP archives and legacy workflow (done)
- Removed: `RepForge-Android-Project.zip`, `RepForge-v0.3.0-Android-source.zip`, `.github/workflows/build-android-apk.yml`.
- Retained: `legacy/android/` (verbatim extraction, read-only), git history of the archives (78cffbd, bfd0b34).
- Docs updated: ADR-0003 (execution record), D01 (historical note), D07 (transition complete), `legacy/android/NOTICE.md`, root README.
- Verification: `git ls-files '*.zip'` returns nothing; remaining workflows are `ci.yml`, `android.yml`, `ios.yml`, `integration.yml`, `debug-release.yml`.

## Task 2 — Design system implementation (done, pending CI and owner review)
Implements "RepForge Design System v1.0" (the brand reconstruction the owner approved) in Flutter. Details and recorded deviations: `docs/design-system.md`.
- Tokens: `lib/ui/tokens.dart` (brand primitives, dark/light surface sets, Sora · Manrope · IBM Plex Mono roles, 4-pt spacing, radius, motion, icon sizes, type scale, `RfSemanticColors` and `RfTextStyles` theme extensions).
- Theme: `lib/ui/theme.dart` builds both themes from tokens (buttons, inputs, navigation bar, cards, snackbar, chips, sheets, dialogs, progress).
- Components: `RfBrandMark`, `RfScreenTitle`, `RfSectionHeader`, `RfCard`, `RfStatTile`, `RfMacroBar`, `RfTrendChart`, `RfButton`, `RfTextField` (+ number/integer), `RfListTile`, `RfEmptyState`, `RfLoading`, `RfErrorState`, `RfNotYetAvailable`.
- Shell: five-pillar navigation Home · Train · Fuel · Track · Goals; Train/Fuel/Goals show labelled "not yet available" placeholders; Track hosts body-weight logging; brand mark in the app bar; debug-only component gallery (`/gallery`).
- Assets: fonts (11 TTFs, SIL OFL, `assets/fonts/LICENSE.md`), logo masters and rendered PNGs (`assets/brand/logo`), twelve icon tiles (`assets/brand/icons`), Android launcher + adaptive icons, iOS app icon set, all generated from the brand SVG masters.
- Tests added: contrast (WCAG AA for every text/surface pair in both themes), component behaviour (button, number/integer fields, macro bar, trend chart 0/1/2/n/flat, list tile height, text scaling), gallery goldens in both themes with real fonts. Suite: 90 tests, all passing locally; analyzer clean with `--fatal-infos`.

## Remaining WP 2 scope (D06)
Manual TalkBack/VoiceOver pass on devices (owner); Stage 2 glyph exports from the brand (navigation currently uses Material icons); owner review of the four deviations listed in `docs/design-system.md` §7; CI evidence for this commit (filled in below once runs complete).
