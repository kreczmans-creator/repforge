# Delivery record — WP 2: Application foundation and design system

Status: **delivered for owner acceptance** (started 2026-11-03 after WP 1 acceptance and merge of PR #1; design implementation complete, CI green on the final WP 2 commit 06cadb6 except the integration assertion fixed in WP 3)
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
- Theme mode: dark by default (owner direction 2026-11-03); light theme implemented and tested, user selection deferred to WP 3 settings.
- Shell: five-pillar navigation Home · Train · Fuel · Track · Goals; Train/Fuel/Goals show labelled "not yet available" placeholders; Track hosts body-weight logging; brand mark in the app bar; debug-only component gallery (`/gallery`).
- Assets: fonts (11 TTFs, SIL OFL, `assets/fonts/LICENSE.md`), logo masters and rendered PNGs (`assets/brand/logo`), twelve icon tiles (`assets/brand/icons`), Android launcher + adaptive icons, iOS app icon set, all generated from the brand SVG masters.
- Tests added: contrast (WCAG AA for every text/surface pair in both themes), component behaviour (button, number/integer fields, macro bar, trend chart 0/1/2/n/flat, list tile height, text scaling), gallery goldens in both themes with real fonts. Suite: 90 tests, all passing locally; analyzer clean with `--fatal-infos`.

## Review
Independent review of the design-system code produced ten findings, all applied in a32aad4: the integration test followed the renamed Track tab and the split value/unit tile; `RfButton` no longer nests a second semantics button node; the trend chart handles a single instant chart-wide, sizes its value axis to the widest label with one-line labels, and repaints only when data changes; the shell applies side safe-area insets; dead `cardTheme` removed; `RfIconTile` extracted and shared by the list tile and empty state; placeholders carry `TODO(placeholder)` and engineering standard §10 now allows only the labelled `RfNotYetAvailable` screen in release builds.

## Owner decisions carried into WP 2
- Dark is the default theme state (2026-11-03). Light theme is implemented and tested; user selection arrived with WP 4 settings.
- The approved "RepForge Brand Reconstruction" (Forge Slate / Forge Amber, Sora · Manrope · IBM Plex Mono) is the design source; four deviations are recorded in `docs/design-system.md` §7 for approval.

## CI evidence
| Commit | Workflow | Run ID | Conclusion |
|---|---|---|---|
| f2baa74 | CI / Android / iOS / Debug release | 41697263658 / 41697263484 / 41697263863 / 41697263476 | success |
| f2baa74 | Integration tests | 41697263437 | failure (integration test still targeted the old `nav-weight` key; fixed in a32aad4) |
| 06cadb6 (dark default) | CI / Android / iOS / Debug release | 41699874953 / 41699874428 / 41699874379 / 41699874318 | success |
| 06cadb6 | Integration tests | 41699874286 | failure (`textContaining('83.2 kg')` matched the activity row and the still-visible snackbar; assertion relaxed in the WP 3 commit) |

## Outstanding
- Manual TalkBack/VoiceOver pass on devices (owner, WP 14 checklist).
- Stage 2 glyph exports from the brand (navigation currently uses Material icons; the twelve tile icons are bundled unused).
- Owner review of the four deviations in `docs/design-system.md` §7.
