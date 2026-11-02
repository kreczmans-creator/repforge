# RepForge Design System v1.0

Single source of truth for the RepForge brand and product design system.
Independent of TempestOS. Dark mode first, light mode fully supported.

## Status

| Stage | Scope | State |
|---|---|---|
| 1 | Brand reconstruction (monogram, wordmark, lockups, app icon, palette, typography, dashboard) | **Awaiting approval** — see `review/stage1-brand-reconstruction.html` |
| 2 | Tokens, type scale, spacing, radius, elevation, iconography, themes | Not started |
| 3 | Component library | Not started |
| 4 | Application screens | Not started |
| 5 | Documentation and developer handover | Not started |

## Directory

| Path | Contents |
|---|---|
| `brand/logo/` | SVG masters: RF monogram (5 flat colour variants, amber-on-slate, 2 gradient), oblique wordmark (4), horizontal lockups (4 flat + 2 gradient), tagline lockups (2), stacked lockups (2). `geometry.json` holds the monogram path data and grid. |
| `brand/icon/` | App icons (dark, amber, light, 512), PWA icons (any + maskable), Android adaptive layers (foreground, background, monochrome, 108 dp). |
| `brand/reference/approved-artwork/` | Supplied vector logo artwork (reference only; masters are generated). |
| `brand/icons/` | Icon library: `glyph/` (24 px, currentColor), `tile/` (128 px slate tiles), `icons.json` manifest, `reference/` approved raster sheet. |
| `brand/png/` | PNG previews rendered from the SVG masters. |
| `tokens/repforge.tokens.css` | Draft CSS design tokens (brand primitives, dark and light themes, spacing, radius, motion). JSON and Compose views follow in Stage 2. |
| `fonts/` | Sora, Manrope and IBM Plex Mono (SIL OFL) used to outline the wordmark. |
| `tools/build_logo.py` | Generates every logo and icon SVG from the geometry definition. Run after any geometry change. |
| `tools/build_icons.py` | Generates the icon library from the 24-grid path definitions. |
| `tools/render_previews.js` | Renders the PNG previews with headless Chromium. |
| `tools/build_review.py` | Assembles the Stage 1 review page from masters, tokens and the dashboard partial. |
| `review/` | Review presentations and the dashboard mock-up partial. |

## Rebuild

```bash
pip install fonttools uharfbuzz          # once
python3 design/tools/build_logo.py
python3 design/tools/build_icons.py
node design/tools/render_previews.js
python3 design/tools/build_review.py
```

## Governance (v1.0)

1. Screens use approved tokens only; no new colours or font families without a documented change.
2. Components are reused, not recreated, and support both themes.
3. Logo and icon artwork comes only from `tools/build_logo.py`; never edit exported SVGs by hand.
4. Every change is recorded in `CHANGELOG.md`.
