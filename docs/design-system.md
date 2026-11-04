# RepForge design system (Flutter implementation)

Status: WP 2 implementation of "RepForge Design System v1.0" (brand reconstruction approved by the owner). Source of truth for values: `app/lib/ui/tokens.dart`; theme assembly: `app/lib/ui/theme.dart`; components: `app/lib/ui/components/`; live catalogue: the debug-only Component gallery (palette icon in the app bar of debug builds, route `/gallery`).

## 1. Brand
- Forge Slate `#1F2A3A`, Forge Amber `#FF8A00` (the only accent), Steel, Stone, Mist, Sand; semantic Success `#22C55E`, Info `#3B82F6`, Alert `#EF4444`, Focus `#8B5CF6`.
- Logo masters (SVG) and rendered PNGs: `app/assets/brand/logo/`. App bar uses `RfBrandMark` (RF monogram + wordmark, dark/light masters chosen by theme). Minimum monogram height 20 px.
- Launcher icons generated from the brand master: Android legacy + adaptive layers under `android/app/src/main/res/mipmap-*`, iOS `AppIcon.appiconset` (flattened on slate; iOS forbids alpha).
- Icon tiles for the twelve pillar icons: `app/assets/brand/icons/*-tile.svg` (not yet wired into UI; Material icons are used for navigation until the Stage 2 glyph exports arrive).

## 2. Colour tokens
Two themes. **Dark is the default state of the app** (`ThemeMode.dark`, owner direction 2026-11-03); light is implemented and tested and becomes selectable when persisted settings land in WP 3. Values are the brand document's dark and light tables; deviations are listed in §7.

| Role | Dark | Light |
|---|---|---|
| Background | `#111923` | `#FBF9F6` |
| Surface 1 / 2 / 3 | `#182331` / `#1F2A3A` / `#263648` | `#FFFFFF` / `#F5F1EB` / `#ECE6DE` |
| Elevated | `#304357` | `#FFFFFF` |
| Text primary / secondary / muted | `#F5F7FA` / `#BBC4CF` / `#8E9DAE` | `#1F2A3A` / `#3B4A5A` / `#5E6E7F` |
| Accent fill | `#FF8A00` | `#FF8A00` |
| Accent text | `#FF8A00` | Amber Ink `#A85800` |
| Text on accent (buttons) | Slate `#1F2A3A` | Slate `#1F2A3A` |
| Border / strong | `#354557` / `#46586D` | `#E4DED6` / `#CFC7BD` |
| Semantic fills | brand primitives | inks `#14763A` / `#1D4ED8` / `#C62828` |
| Semantic small text | tints `#4ADE80` / `#60A5FA` / `#F87171` | same inks as fills |

Access: `context.rf.<token>` (ThemeExtension `RfSemanticColors`), or `Theme.of(context).colorScheme` for the Material mapping (primary = accent, onPrimary = slate, surfaceContainer = Surface 1, surfaceContainerHigh = Surface 2, outline = border, onSurfaceVariant = muted).

## 3. Typography
Sora (brand/headings, 500–800), Manrope (UI/body, 400–700), IBM Plex Mono (data, 400–600), bundled under `app/assets/fonts` (SIL OFL). Scale (size/line height):

| Token | Family | Size | Slot |
|---|---|---|---|
| Display | Sora 700 | 40/44 | `textTheme.displaySmall` |
| H1 | Sora 700 | 28/34 | `headlineLarge` |
| H2 | Sora 600 | 22/28 | `headlineMedium` |
| H3 | Sora 600 | 18/24 | `headlineSmall` |
| H4 | Sora 600 | 16/22 | `titleMedium` |
| Body large / Body / Body small | Manrope 500 | 17/26 · 15/22 · 13/18 | `bodyLarge` · `bodyMedium` · `bodySmall` |
| Label (kicker) | Manrope 600, +8 % tracking, caps | 11/14 | `labelSmall`, `context.rfText.kicker` |
| Caption | Manrope 500 | 12/16 | `context.rfText.caption` |
| Data XL / L / M / S | Plex Mono 600/600/500/500, tabular figures | 36/40 · 28/32 · 17/22 · 13/18 | `context.rfText.dataXl…dataS` |
| Meta | Plex Mono 400, +4 % | 11/16 | `context.rfText.meta` |

User text scaling is always respected; no fixed-height text containers.

## 4. Spacing, radius, motion, sizes
- Spacing 4-pt: 4, 8, 12, 16, 20, 24, 32, 40, 48 (`RfSpace.s1…s12`); page gutter 20.
- Radius: xs 6 (chips), sm 10 (inputs, secondary buttons), md 14 (primary buttons, rows), lg 18 (cards), xl 24 (sheets, dialogs), pill.
- Motion: fast 120 ms, base 200 ms, slow 320 ms, curve `cubic(0.2, 0, 0, 1)`.
- Icons 20 / 24 / 32. Minimum touch target 48 dp on both platforms.

## 5. Components (`Rf*`)
| Component | Purpose | Rules |
|---|---|---|
| `RfBrandMark` | App bar identity | Theme-selected masters; semantics label "RepForge" |
| `RfScreenTitle` | H1 + muted caption | One per screen |
| `RfSectionHeader` | H4 + optional amber text action | |
| `RfCard` | Surface 1 panel, border, radius 18, soft shadow; optional amber leading edge; optional tap | Content padding 16 |
| `RfStatTile` | Kicker, Plex Mono value + unit, optional amber progress, mono caption | Use for key figures |
| `RfMacroBar` | Labelled progress against a target | Clamped 0–1; semantics value with percent. Three states: known amount ("30 / 50 g" + bar), no target ("30 g · no target", no bar), unknown amount ("n/a", no bar); optional `unknownCount` appends "· N unknown" |
| `RfTrendChart` | Time-proportional line chart, value axis, first/last dates, multi-series legend | Handles 0/1/2/n points and flat series; semantics summary |
| `RfButton` | primary (amber, slate label) / secondary (outlined) / tertiary (amber text) / danger; loading and disabled states | ≥ 48 dp; loading blocks taps |
| `RfTextField` + `.number` + `.integer` | Inputs with unit suffix, decimal/integer formatters | Error text up to 3 lines |
| `RfIconTile` | 36 px amber-tinted icon tile | Used by `RfListTile` and `RfEmptyState` |
| `RfListTile` | Activity row with icon tile | ≥ 48 dp |
| `RfEmptyState`, `RfLoading`, `RfErrorState` | Mandatory states for every data panel | Error state offers retry when possible |
| `RfNotYetAvailable` | Labelled placeholder for features of later work packages | The only placeholder allowed in release builds (standards §10) |

Navigation: five-pillar bottom bar Home · Train · Fuel · Track · Goals (brand mock-up option), Surface 1 background with top border, amber active icon, Amber-Ink/amber active label.

## 6. Accessibility
- Contrast enforced by `test/ui/contrast_test.dart` (text ≥ 4.5:1 on background, Surface 1 and Surface 2 in both themes; fills ≥ 3:1; button labels ≥ 4.5:1).
- Touch targets ≥ 48 dp via theme minimum sizes and `RfListTile` constraints (tested).
- Semantics on charts and progress bars; icon buttons carry tooltips.
- Text scaling test at 2× in `components_test.dart`.
- Manual TalkBack and VoiceOver pass: not yet performed (owner device checklist, WP 14).

## 7. Deviations from the brand document (recorded for approval)

**All four deviations were approved by the owner on 2026-11-03** (`docs/delivery-record/WP2.md`, “Owner acceptance”). Deviation 4 is approved as an interim implementation: the Material navigation icons are to be replaced when the approved glyph exports arrive.
1. Amber Ink darkened from `#B45F00` to `#A85800` so amber text also passes 4.5:1 on Surface 2 (`#F5F1EB`), not only on white.
2. Light-mode semantic inks (`#14763A` success, `#1D4ED8` info, `#C62828` alert) chosen for small text, as the document defers to "Stage 2"; dark-mode small semantic text uses tints (`#4ADE80`, `#60A5FA`, `#F87171`) because the brand fills are AA-large-only on Surface 1.
3. Light-theme snackbars are inverted (slate background, light text) so they read as transient; the document does not specify snackbars.
4. Navigation uses Material icons until the Stage 2 glyph exports (20/24/32) are supplied; the twelve tile icons are bundled unused.

## 8. Goldens
`test/ui/golden/goldens/gallery_{dark,light}.png` are the reference renders of the gallery with real brand fonts loaded. Regenerate only with `flutter test --update-goldens test/ui/golden` and review the image diff in the pull request.
