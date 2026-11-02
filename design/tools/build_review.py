#!/usr/bin/env python3
"""Assemble design/review/stage1-brand-reconstruction.html from the SVG masters, tokens and
the dashboard partial. Self-contained output (fonts via Google Fonts link only).

Usage: python3 design/tools/build_review.py
"""
import json
import pathlib
import re

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOGO = ROOT / "brand" / "logo"
ICON = ROOT / "brand" / "icon"
OUT = ROOT / "review" / "stage1-brand-reconstruction.html"

tokens_css = (ROOT / "tokens" / "repforge.tokens.css").read_text()
geom = json.loads((LOGO / "geometry.json").read_text())
dash = (ROOT / "review" / "partials" / "dashboard-mock.html").read_text()


def svg_inline(path, cls="", height=None, title=None):
    s = pathlib.Path(path).read_text().strip()
    s = re.sub(r'\swidth="[\d.]+"\sheight="[\d.]+"', "", s, count=1)
    attrs = []
    if cls:
        attrs.append(f'class="{cls}"')
    if height:
        attrs.append(f'style="height:{height};width:auto"')
    return s.replace("<svg ", "<svg " + " ".join(attrs) + " ", 1)


def mark(height, r="#F5F7FA", f="#FF8A00"):
    return (f'<svg viewBox="0 0 {geom["grid"]["width"]} 128" style="height:{height};width:auto" aria-hidden="true">'
            f'<path fill="{f}" d="{geom["paths"]["F"]}"/><path fill="{r}" d="{geom["paths"]["R"]}"/></svg>')


# ---------------------------------------------------------------- contrast maths
def lum(hexstr):
    h = hexstr.lstrip("#")
    r, g, b = (int(h[i:i + 2], 16) / 255 for i in (0, 2, 4))
    lin = lambda c: c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)


def contrast(a, b):
    la, lb = lum(a), lum(b)
    hi, lo = max(la, lb), min(la, lb)
    return (hi + 0.05) / (lo + 0.05)


def badge(ratio, large=False):
    aa = 3.0 if large else 4.5
    aaa = 4.5 if large else 7.0
    if ratio >= aaa:
        cls, txt = "ok", "AAA"
    elif ratio >= aa:
        cls, txt = "ok", "AA"
    elif ratio >= 3.0:
        cls, txt = "warn", "AA large only"
    else:
        cls, txt = "fail", "Fails"
    return f'<span class="pill {cls}">{ratio:.1f}:1 · {txt}</span>'


dark_pairs = [
    ("Primary text #F5F7FA", "#F5F7FA", "Surface 2 #1F2A3A", "#1F2A3A", False),
    ("Secondary text #BBC4CF", "#BBC4CF", "Surface 2 #1F2A3A", "#1F2A3A", False),
    ("Muted text (brief) #8291A2", "#8291A2", "Surface 2 #1F2A3A", "#1F2A3A", False),
    ("Muted text (revised) #8E9DAE", "#8E9DAE", "Surface 2 #1F2A3A", "#1F2A3A", False),
    ("Amber text #FF8A00", "#FF8A00", "Background #111923", "#111923", False),
    ("Amber text #FF8A00", "#FF8A00", "Elevated #304357", "#304357", False),
    ("Slate label #1F2A3A on amber button", "#1F2A3A", "Amber #FF8A00", "#FF8A00", False),
    ("White label #FFFFFF on amber button", "#FFFFFF", "Amber #FF8A00", "#FF8A00", False),
    ("Success #22C55E", "#22C55E", "Surface 1 #182331", "#182331", False),
    ("Alert #EF4444", "#EF4444", "Surface 1 #182331", "#182331", False),
    ("Info #3B82F6", "#3B82F6", "Surface 1 #182331", "#182331", False),
    ("Focus #8B5CF6", "#8B5CF6", "Surface 1 #182331", "#182331", False),
]
light_pairs = [
    ("Primary text #1F2A3A", "#1F2A3A", "Background #FBF9F6", "#FBF9F6", False),
    ("Secondary text #3B4A5A", "#3B4A5A", "Surface #FFFFFF", "#FFFFFF", False),
    ("Muted text (Stone) #6B7B8C", "#6B7B8C", "Surface #FFFFFF", "#FFFFFF", False),
    ("Muted text (revised) #5E6E7F", "#5E6E7F", "Surface #FFFFFF", "#FFFFFF", False),
    ("Amber text #FF8A00", "#FF8A00", "Surface #FFFFFF", "#FFFFFF", False),
    ("Amber Ink text #B45F00", "#B45F00", "Surface #FFFFFF", "#FFFFFF", False),
    ("Slate label #1F2A3A on amber button", "#1F2A3A", "Amber #FF8A00", "#FF8A00", False),
    ("Success #22C55E", "#22C55E", "Surface #FFFFFF", "#FFFFFF", False),
    ("Alert #EF4444", "#EF4444", "Surface #FFFFFF", "#FFFFFF", False),
]


def contrast_rows(pairs):
    rows = []
    for fg_label, fg, bg_label, bg, large in pairs:
        rows.append(f'<tr><td><span class="sw" style="background:{fg}"></span>{fg_label}</td>'
                    f'<td><span class="sw" style="background:{bg}"></span>{bg_label}</td>'
                    f'<td>{badge(contrast(fg, bg), large)}</td></tr>')
    return "".join(rows)


# ---------------------------------------------------------------- construction diagram
W = geom["grid"]["width"]
TAN = 0.2125565617
def construction_svg():
    g = []
    g.append(f'<svg viewBox="-36 -24 {W + 84} 184" class="construct" aria-label="RF monogram construction grid">')
    # sheared grid, 8-unit cells, drawn in upright space then skewed like the letters
    g.append(f'<g transform="translate({128 * TAN:.3f} 0) skewX(-12)">')
    for x in range(0, 161, 8):
        g.append(f'<line x1="{x}" y1="-16" x2="{x}" y2="144" class="grid"/>')
    for y in range(-16, 145, 8):
        g.append(f'<line x1="0" y1="{y}" x2="160" y2="{y}" class="grid"/>')
    # key horizontals: cap, bar, counter, mid bar, baseline
    for y, lab in [(0, "cap"), (24, "bar"), (46, "counter"), (70, "mid bar"), (128, "baseline")]:
        g.append(f'<line x1="-8" y1="{y}" x2="168" y2="{y}" class="guide"/>')
    g.append('</g>')
    g.append(f'<path fill="#FF8A00" opacity="0.55" d="{geom["paths"]["F"]}"/>')
    g.append(f'<path fill="currentColor" opacity="0.55" d="{geom["paths"]["R"]}"/>')
    # labels (unsheared text)
    labels = [(-14, 0, "0"), (-14, 24, "24"), (-14, 46, "46"), (-14, 70, "70"), (-14, 128, "128")]
    for x, y, t in labels:
        g.append(f'<text x="{x}" y="{y + 3}" class="lbl" text-anchor="end">{t}</text>')
    g.append(f'<text x="{W / 2:.1f}" y="148" class="lbl" text-anchor="middle" style="font-size:4.6px">stroke 26 / 24 · slant 12° · leg 34° · shoulder R26 · counter R9 · corners R6 / R3 · grid 8</text>')
    g.append('</svg>')
    return "".join(g)


# ---------------------------------------------------------------- dashboard partial
mono_small = mark("26px")
dash_dark = dash.replace('<span class="rf-mark" aria-hidden="true"></span>',
                         f'<span class="rf-mark" aria-hidden="true">{mono_small}</span>')
dash_dark = dash_dark.replace('<span class="rf-wordmark">Rep<b>Forge</b></span>', '__WM__')
dash_dark = dash_dark.replace(".rf-phone .rf-mark { display: inline-block; width: 34px; height: 26px; }",
                              ".rf-phone .rf-mark { display: inline-flex; width: auto; height: 26px; }")
style_block, markup_tpl = dash_dark.split("</style>", 1)
wm_dark = svg_inline(LOGO / "repforge-wordmark-reversed.svg", height="19px").replace("<svg ", '<svg style="height:19px;width:auto;display:block" ', 1)
wm_light = svg_inline(LOGO / "repforge-wordmark.svg", height="19px").replace("<svg ", '<svg style="height:19px;width:auto;display:block" ', 1)
markup = markup_tpl.replace("__WM__", wm_dark)
style_block += "</style>"
markup_light = markup_tpl.replace("__WM__", wm_light).replace('data-theme="dark"', 'data-theme="light"', 1)
# light phone: slate R in the app-bar mark
markup_light = markup_light.replace(f'<path fill="#F5F7FA" d="{geom["paths"]["R"]}"/>',
                                    f'<path fill="#1F2A3A" d="{geom["paths"]["R"]}"/>', 1)

# ---------------------------------------------------------------- page
page = f"""<title>RepForge Brand Reconstruction</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Sora:wght@500;600;700&family=Manrope:wght@400;500;600;700&family=IBM+Plex+Mono:wght@400;500;600&display=swap">
<style>
{tokens_css}
/* ---- Review page chrome: dark-first, uses the system tokens as its own palette ---- */
/* Layout: single 1120px column, sections as quiet bands, assets on contrasting slabs. */
:root {{
  --pg-bg: #111923; --pg-fg: #F5F7FA; --pg-fg2: #BBC4CF; --pg-muted: #8E9DAE;
  --pg-surface: #182331; --pg-surface2: #1F2A3A; --pg-border: #354557; --pg-accent: #FF8A00; --pg-accent-text: #FF8A00;
  --pg-ok: #22C55E; --pg-warn: #F59E0B; --pg-fail: #EF4444;
  color-scheme: dark;
}}
@media (prefers-color-scheme: light) {{ :root:not([data-theme="dark"]) {{
  --pg-bg: #FBF9F6; --pg-fg: #1F2A3A; --pg-fg2: #3B4A5A; --pg-muted: #5E6E7F;
  --pg-surface: #FFFFFF; --pg-surface2: #F5F1EB; --pg-border: #E4DED6; --pg-accent: #FF8A00; --pg-accent-text: #B45F00;
  color-scheme: light;
}} }}
:root[data-theme="light"] {{
  --pg-bg: #FBF9F6; --pg-fg: #1F2A3A; --pg-fg2: #3B4A5A; --pg-muted: #5E6E7F;
  --pg-surface: #FFFFFF; --pg-surface2: #F5F1EB; --pg-border: #E4DED6; --pg-accent: #FF8A00; --pg-accent-text: #B45F00;
  color-scheme: light;
}}
* {{ box-sizing: border-box; }}
body {{ margin: 0; background: var(--pg-bg); color: var(--pg-fg); font: 500 15px/1.6 "Manrope", system-ui, sans-serif; -webkit-font-smoothing: antialiased; }}
.wrap {{ max-width: 1120px; margin: 0 auto; padding-block: 40px 80px; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }}
.wrap :is(h1, h2, h3):not(.rf-phone *) {{ font-family: "Sora", system-ui, sans-serif; text-wrap: balance; margin: 0; }}
.wrap h1:not(.rf-phone *) {{ font-size: clamp(28px, 4vw, 40px); font-weight: 700; letter-spacing: -0.02em; line-height: 1.1; }}
.wrap h2:not(.rf-phone *) {{ font-size: 24px; font-weight: 600; letter-spacing: -0.01em; margin-bottom: 6px; }}
.wrap h3:not(.rf-phone *) {{ font-size: 17px; font-weight: 600; }}
.wrap p:not(.rf-phone *) {{ margin: 0; max-width: 68ch; }}
.lead {{ color: var(--pg-fg2); font-size: 16px; }}
.eyebrow {{ font: 600 11px/1 "Manrope", sans-serif; letter-spacing: .12em; text-transform: uppercase; color: var(--pg-accent-text); margin-bottom: 10px; }}
.wrap > section {{ margin-top: 64px; }}
.sub {{ color: var(--pg-muted); font-size: 13px; }}
.hero {{ display: grid; gap: 24px; padding: 32px; border-radius: 24px; background: linear-gradient(120deg, #1F2A3A 0%, #182331 55%, #2A2A2E 100%); color: #F5F7FA; border: 1px solid #354557; position: relative; overflow: hidden; }}
.hero::after {{ content: ""; position: absolute; inset: auto -10% -60% auto; width: 60%; aspect-ratio: 1; background: radial-gradient(closest-side, rgba(255,138,0,.22), transparent 70%); pointer-events: none; }}
.hero .meta {{ display: flex; flex-wrap: wrap; gap: 8px 24px; font-size: 13px; color: #BBC4CF; }}
.hero .meta b {{ color: #F5F7FA; font-weight: 600; }}
.grid {{ display: grid; gap: 16px; }}
.g2 {{ grid-template-columns: repeat(auto-fit, minmax(280px, 1fr)); }}
.g3 {{ grid-template-columns: repeat(auto-fit, minmax(220px, 1fr)); }}
.g4 {{ grid-template-columns: repeat(auto-fit, minmax(160px, 1fr)); }}
.slab {{ border-radius: 18px; padding: 28px; display: flex; align-items: center; justify-content: center; min-height: 160px; border: 1px solid var(--pg-border); }}
.slab.dark {{ background: #111923; color: #F5F7FA; }}
.slab.deep {{ background: #1F2A3A; color: #F5F7FA; }}
.slab.light {{ background: #FFFFFF; color: #1F2A3A; }}
.slab.sand {{ background: #F2E8DC; color: #1F2A3A; }}
.slab.amber {{ background: #FF8A00; color: #1F2A3A; }}
.slab svg {{ max-width: 100%; height: auto; }}
.cap {{ display: block; margin-top: 10px; font-size: 13px; color: var(--pg-muted); }}
.cap b {{ color: var(--pg-fg); font-weight: 600; }}
.card {{ background: var(--pg-surface); border: 1px solid var(--pg-border); border-radius: 18px; padding: 20px 22px; }}
.wrap table:not(.rf-phone *) {{ width: 100%; border-collapse: collapse; font-size: 14px; }}
.wrap :is(th, td):not(.rf-phone *) {{ text-align: left; padding: 10px 12px; border-bottom: 1px solid var(--pg-border); vertical-align: top; }}
.wrap th:not(.rf-phone *) {{ font: 600 11px/1.2 "Manrope", sans-serif; letter-spacing: .1em; text-transform: uppercase; color: var(--pg-muted); }}
.tscroll {{ overflow-x: auto; }}
.sw {{ display: inline-block; width: 14px; height: 14px; border-radius: 4px; vertical-align: -2px; margin-right: 8px; border: 1px solid rgba(127,127,127,.35); }}
.pill {{ display: inline-block; padding: 3px 9px; border-radius: 999px; font: 600 12px/1.4 "IBM Plex Mono", monospace; white-space: nowrap; }}
.pill.ok {{ background: rgba(34,197,94,.14); color: var(--pg-ok); }}
.pill.warn {{ background: rgba(245,158,11,.16); color: var(--pg-warn); }}
.pill.fail {{ background: rgba(239,68,68,.14); color: var(--pg-fail); }}
.chip {{ display: inline-block; padding: 3px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; }}
.chip.keep {{ background: rgba(34,197,94,.14); color: var(--pg-ok); }}
.chip.refine {{ background: rgba(255,138,0,.16); color: var(--pg-accent-text); }}
.chip.new {{ background: rgba(59,130,246,.16); color: #3B82F6; }}
.swatches {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 12px; }}
.swatch {{ border-radius: 14px; overflow: hidden; border: 1px solid var(--pg-border); background: var(--pg-surface); }}
.swatch .c {{ height: 72px; }}
.swatch .t {{ padding: 10px 12px; font-size: 13px; }}
.swatch .t b {{ display: block; font-weight: 600; }}
.swatch .t code {{ font: 500 12px "IBM Plex Mono", monospace; color: var(--pg-muted); }}
.tokens {{ display: grid; grid-template-columns: repeat(auto-fit, minmax(120px, 1fr)); gap: 8px; }}
.tok {{ border-radius: 12px; padding: 12px; font-size: 12px; border: 1px solid rgba(127,127,127,.25); }}
.tok b {{ display: block; font-weight: 600; }}
.tok code {{ font: 500 11px "IBM Plex Mono", monospace; opacity: .8; }}
.type-sample {{ display: grid; gap: 18px; }}
.type-row {{ display: grid; grid-template-columns: 150px 1fr; gap: 16px; align-items: baseline; border-bottom: 1px solid var(--pg-border); padding-bottom: 14px; }}
.type-row .k {{ font: 500 12px "IBM Plex Mono", monospace; color: var(--pg-muted); }}
.type-row .k b {{ display: block; color: var(--pg-fg); font: 600 13px "Manrope", sans-serif; }}
.sora {{ font-family: "Sora", sans-serif; }}
.manrope {{ font-family: "Manrope", sans-serif; }}
.mono {{ font-family: "IBM Plex Mono", monospace; font-variant-numeric: tabular-nums; }}
.construct {{ width: 100%; max-width: 720px; height: auto; color: var(--pg-fg); }}
.construct .grid {{ stroke: currentColor; stroke-opacity: .12; stroke-width: .5; }}
.construct .guide {{ stroke: #FF8A00; stroke-opacity: .7; stroke-width: .6; stroke-dasharray: 3 2; }}
.construct .lbl {{ font: 500 5px "IBM Plex Mono", monospace; fill: currentColor; opacity: .8; }}
.phones {{ display: flex; flex-wrap: wrap; gap: 40px; justify-content: center; padding: 40px 0; }}
.phone-scale {{ width: 390px; max-width: 100%; }}
@media (max-width: 440px) {{ .phone-scale {{ zoom: .85; }} }}
.phone-cap {{ text-align: center; margin-top: 18px; font-size: 13px; color: var(--pg-muted); }}
.wrap ul:not(.rf-phone *) {{ margin: 8px 0 0; padding-left: 20px; }}
.wrap li:not(.rf-phone *) {{ margin: 4px 0; }}
.q {{ counter-reset: q; display: grid; gap: 10px; }}
.q .card {{ padding: 14px 18px; display: grid; grid-template-columns: 28px 1fr; gap: 12px; align-items: start; }}
.q .n {{ font: 600 14px "IBM Plex Mono", monospace; color: var(--pg-accent-text); }}
.icon48 {{ display: flex; gap: 20px; align-items: flex-end; }}
.icon48 img, .icon48 svg {{ border-radius: 22%; }}
.sizes {{ display: flex; align-items: flex-end; gap: 28px; flex-wrap: wrap; }}
.sizes > div {{ text-align: center; font: 500 11px "IBM Plex Mono", monospace; color: inherit; }}
.sizes svg {{ display: block; margin: 0 auto 6px; }}
footer {{ margin-top: 64px; padding-top: 20px; border-top: 1px solid var(--pg-border); color: var(--pg-muted); font-size: 13px; }}
{style_block[len("<style>"):-len("</style>")]}
</style>

<div class="wrap">

<div class="hero">
  <div>{svg_inline(LOGO / "repforge-lockup-tagline-reversed.svg", height="88px")}</div>
  <div>
    <div class="eyebrow" style="color:#FF8A00">RepForge Design System v1.0 · Stage 1</div>
    <h1>Brand reconstruction for review</h1>
    <p class="lead" style="color:#BBC4CF;margin-top:12px">The approved RF monogram direction, Forge Amber / Slate palette and Sora · Manrope · IBM Plex Mono typography, rebuilt as true vector geometry and shown on a working dark-mode dashboard. Nothing below is final until you approve it.</p>
  </div>
  <div class="meta"><span><b>Status</b> Awaiting approval</span><span><b>Source</b> Commission brief + branding board</span><span><b>Assets</b> 24 SVG masters, 8 icon layers, tokens draft</span></div>
</div>

<section>
  <div class="eyebrow">Summary</div>
  <h2>What is reproduced and what is refined</h2>
  <p class="lead">Green items reproduce the established direction. Amber items are refinements that preserve the concept but need your sign-off. Blue items are additions the brief leaves open.</p>
  <div class="tscroll" style="margin-top:16px"><table>
    <tr><th>Element</th><th>Decision</th><th>Detail</th></tr>
    <tr><td>RF monogram concept</td><td><span class="chip keep">Reproduced</span></td><td>Light/slate R in front, long leg sweeping under the amber F, F resting on the leg. Italic slant, heavy weight, rounded corners, shared cap line.</td></tr>
    <tr><td>Monogram geometry</td><td><span class="chip refine">Refined</span></td><td>Rebuilt on a 128-unit grid from the board: stroke 26, 12° slant, R26 shoulders, R6 / R3 corners, leg sweeping under the F at 34°, F sitting on the leg with a 14-unit gap from the bowl.</td></tr>
    <tr><td>Wordmark oblique</td><td><span class="chip refine">Refined</span></td><td>The board wordmark is italic. Sora has no italic, so the wordmark is Sora Bold with a 12° synthetic oblique, matching the monogram slant.</td></tr>
    <tr><td>Gradient logo variants</td><td><span class="chip new">Added</span></td><td>Board shows amber and silver gradients on the mark. Flat masters are the UI default; gradient variants (#FFB13B → #FF8A00 → #E96B00, white → Mist) are supplied for hero and marketing use only.</td></tr>
    <tr><td>Iconography</td><td><span class="chip new">Open</span></td><td>No icon set is approved yet. The icon library is designed in Stage 2 to the brief's rounded geometric spec.</td></tr>
    <tr><td>Wordmark</td><td><span class="chip keep">Reproduced</span></td><td>Oblique Sora Bold, "Rep" in slate/light and "Forge" in amber. Outlined to paths, −1.5% tracking.</td></tr>
    <tr><td>Tagline</td><td><span class="chip keep">Reproduced</span></td><td>TRAIN · FUEL · TRACK · TRANSFORM in Manrope SemiBold, +22% tracking, Stone grey.</td></tr>
    <tr><td>Palette</td><td><span class="chip keep">Reproduced</span></td><td>Forge Slate #1F2A3A, Forge Amber #FF8A00, Steel, Stone, Mist, Sand and the four semantic colours, unchanged.</td></tr>
    <tr><td>Light muted text</td><td><span class="chip refine">Refined</span></td><td>Stone #6B7B8C on white is 4.3:1. Light-mode muted text uses #5E6E7F (5.2:1); Stone stays for borders, icons and large text.</td></tr>
    <tr><td>Dark theme tokens</td><td><span class="chip refine">Refined</span></td><td>Brief values kept except Muted Text, lifted from #8291A2 to #8E9DAE so it passes 4.5:1 on Surface 2.</td></tr>
    <tr><td>Text on amber</td><td><span class="chip refine">Refined</span></td><td>The board shows white labels on amber buttons (2.4:1, fails AA). Primary buttons use Forge Slate labels on amber (6.2:1).</td></tr>
    <tr><td>Amber text in light mode</td><td><span class="chip new">Added</span></td><td>#FF8A00 on white is 2.4:1. "Amber Ink" #B45F00 is added for links and small amber text on light surfaces. Fills and icons keep #FF8A00.</td></tr>
    <tr><td>Amber interaction scale</td><td><span class="chip new">Added</span></td><td>Hover #FFA033, pressed #E67C00, subtle tint 14% for icon tiles and selected states.</td></tr>
    <tr><td>App icon</td><td><span class="chip keep">Reproduced</span></td><td>Rounded square, deep slate with a subtle top-to-bottom slate gradient, light R, amber F. Amber and light variants as on the board.</td></tr>
    <tr><td>Typography</td><td><span class="chip keep">Reproduced</span></td><td>Sora 500–700 headings, Manrope 400–700 UI, IBM Plex Mono 400–600 data. Draft scale below.</td></tr>
  </table></div>
</section>

<section>
  <div class="eyebrow">1 · Logo</div>
  <h2>RF monogram</h2>
  <p class="lead">The R is the structure. Its leg sweeps down and right under the F, and the amber F rests on that leg, its stem cut by the leg's upper edge. The F's bars sit on the R's cap and bowl lines, so the pair reads as one object.</p>
  <div class="grid g2" style="margin-top:20px">
    <div><div class="slab dark">{svg_inline(LOGO / "rf-monogram.svg", height="150px")}</div><span class="cap"><b>Primary monogram</b> · light R, amber F, for dark surfaces</span></div>
    <div><div class="slab light">{svg_inline(LOGO / "rf-monogram-on-light.svg", height="150px")}</div><span class="cap"><b>Monogram on light</b> · slate R, amber F</span></div>
  </div>
  <div class="grid g4" style="margin-top:16px">
    <div><div class="slab light">{svg_inline(LOGO / "rf-monogram-mono-dark.svg", height="84px")}</div><span class="cap"><b>Monochrome dark</b></span></div>
    <div><div class="slab deep">{svg_inline(LOGO / "rf-monogram-mono-light.svg", height="84px")}</div><span class="cap"><b>Monochrome light</b></span></div>
    <div><div class="slab deep" style="padding:0">{svg_inline(LOGO / "rf-monogram-amber-on-slate.svg", height="160px")}</div><span class="cap"><b>Amber on slate</b></span></div>
    <div><div class="slab amber">{svg_inline(LOGO / "rf-monogram-mono-dark.svg", height="84px")}</div><span class="cap"><b>Slate on amber</b> · for amber brand panels</span></div>
  </div>
  <div class="grid g2" style="margin-top:16px">
    <div><div class="slab dark">{svg_inline(LOGO / "rf-monogram-gradient.svg", height="120px")}</div><span class="cap"><b>Gradient variant</b> · hero, splash and marketing only</span></div>
    <div><div class="slab dark">{svg_inline(LOGO / "repforge-lockup-horizontal-gradient-reversed.svg", height="72px")}</div><span class="cap"><b>Gradient lockup, reversed</b> · as on the board</span></div>
  </div>

  <h3 style="margin-top:36px">Construction</h3>
  <p class="sub" style="margin-top:6px">Upright geometry on a 128-unit grid, sheared 12°, then every corner rounded with true arcs. Horizontal lines at 0, 24, 46, 70 and 128 are shared by both letters. Vector masters are generated from this definition, not traced from the board.</p>
  <div class="card" style="margin-top:14px;display:flex;justify-content:center">{construction_svg()}</div>
  <div class="grid g3" style="margin-top:16px">
    <div class="card"><h3>Proportions</h3><ul class="sub">
      <li>Verticals 26, horizontals 24 (20% / 19% of cap height) for both letters.</li>
      <li>Bowl 0–70, counter 24–46 × 26–58, leg from the bowl junction to x 133 at 34° after slant.</li>
      <li>Monogram box 205 × 128 (aspect 1.6:1). F stem 98–124, 14 units clear of the bowl.</li>
      <li>F top bar extends 54 past its stem, mid bar 28, so the F stays an F at small sizes.</li>
    </ul></div>
    <div class="card"><h3>Corners and mass</h3><ul class="sub">
      <li>Outer corners R6, inner corners R3, counter R9, bowl shoulder R26.</li>
      <li>Only two colours, no outlines, no gradients on the mark itself.</li>
      <li>The F is drawn behind the R; the leg cuts the F stem. Monochrome versions are the union.</li>
    </ul></div>
    <div class="card"><h3>Clear space and minimum size</h3><ul class="sub">
      <li>Clear space on all sides = one stem width (26 units, 20% of mark height).</li>
      <li>Minimum: monogram 20 px tall on screen, 6 mm in print. Lockup 28 px tall.</li>
      <li>Below 20 px use the app icon, never the lockup.</li>
    </ul></div>
  </div>
  <h3 style="margin-top:28px">Small-size check</h3>
  <div class="slab dark" style="margin-top:12px;display:block"><div class="sizes" style="color:#BBC4CF">
    <div>{mark("96px", "#F5F7FA")}96 px</div><div>{mark("48px", "#F5F7FA")}48 px</div><div>{mark("32px", "#F5F7FA")}32 px</div><div>{mark("24px", "#F5F7FA")}24 px</div><div>{mark("20px", "#F5F7FA")}20 px</div><div>{mark("16px", "#F5F7FA")}16 px</div>
  </div><p class="sub" style="margin-top:12px;color:#8E9DAE">Shown with the light R on the dark background. On light pages the slate R version is used at the same sizes.</p></div>
</section>

<section>
  <div class="eyebrow">2 · Wordmark and lockups</div>
  <h2>Wordmark and lockups</h2>
  <p class="lead">Sora Bold at a 12° oblique, set as outlines, Rep in the neutral and Forge in amber. The wordmark cap height is 74% of the monogram height and sits on the monogram baseline, with a gap of 30% of the mark height.</p>
  <div class="grid g2" style="margin-top:20px">
    <div><div class="slab light">{svg_inline(LOGO / "repforge-lockup-horizontal.svg", height="72px")}</div><span class="cap"><b>Primary horizontal lockup</b></span></div>
    <div><div class="slab dark">{svg_inline(LOGO / "repforge-lockup-horizontal-reversed.svg", height="72px")}</div><span class="cap"><b>Reversed horizontal lockup</b></span></div>
    <div><div class="slab light">{svg_inline(LOGO / "repforge-wordmark.svg", height="60px")}</div><span class="cap"><b>Wordmark only</b></span></div>
    <div><div class="slab dark">{svg_inline(LOGO / "repforge-lockup-tagline-reversed.svg", height="90px")}</div><span class="cap"><b>Lockup with tagline</b> · marketing and splash use</span></div>
    <div><div class="slab light">{svg_inline(LOGO / "repforge-lockup-horizontal-mono-dark.svg", height="72px")}</div><span class="cap"><b>Monochrome dark lockup</b></span></div>
    <div><div class="slab deep">{svg_inline(LOGO / "repforge-lockup-horizontal-mono-light.svg", height="72px")}</div><span class="cap"><b>Monochrome light lockup</b></span></div>
    <div><div class="slab dark" style="min-height:260px">{svg_inline(LOGO / "repforge-lockup-stacked-reversed.svg", height="220px")}</div><span class="cap"><b>Stacked lockup</b> · splash screen and square placements</span></div>
  </div>
</section>

<section>
  <div class="eyebrow">3 · App icon</div>
  <h2>Launcher and PWA icon</h2>
  <p class="lead">Standalone monogram in a rounded square, 22% corner radius. The dark version is primary. The mark is nudged 2% left of centre to balance the slanted mass.</p>
  <div class="grid g3" style="margin-top:20px">
    <div><div class="slab" style="background:linear-gradient(135deg,#3B4A5A,#1F2A3A)">{svg_inline(ICON / "app-icon-dark.svg", height="160px")}</div><span class="cap"><b>Primary (dark)</b> · Forge Slate gradient #26344A → #182331</span></div>
    <div><div class="slab" style="background:linear-gradient(135deg,#3B4A5A,#1F2A3A)">{svg_inline(ICON / "app-icon-amber.svg", height="160px")}</div><span class="cap"><b>Accent (amber)</b> · light R, slate F</span></div>
    <div><div class="slab" style="background:linear-gradient(135deg,#3B4A5A,#1F2A3A)">{svg_inline(ICON / "app-icon-light.svg", height="160px")}</div><span class="cap"><b>Light (neutral)</b> · #F4F1EC, slate R, amber F</span></div>
  </div>
  <div class="grid g2" style="margin-top:16px">
    <div class="card"><h3>Android adaptive icon</h3><p class="sub" style="margin-top:6px">Foreground and background layers on the 108 dp canvas. The mark fits inside the 66 dp safe circle so it survives circle, squircle and rounded-square masks. A monochrome layer is included for themed icons.</p>
      <div style="display:flex;gap:16px;margin-top:14px;align-items:center;flex-wrap:wrap">
        <div style="position:relative;width:108px;height:108px">{svg_inline(ICON / "android-adaptive-background.svg", height="108px")}<div style="position:absolute;inset:0">{svg_inline(ICON / "android-adaptive-foreground.svg", height="108px")}</div><div style="position:absolute;inset:21px;border:1px dashed #FF8A00;border-radius:50%;opacity:.8"></div></div>
        <div style="width:108px;height:108px;border-radius:50%;overflow:hidden;position:relative">{svg_inline(ICON / "android-adaptive-background.svg", height="108px")}<div style="position:absolute;inset:0">{svg_inline(ICON / "android-adaptive-foreground.svg", height="108px")}</div></div>
        <div style="width:108px;height:108px;border-radius:30px;overflow:hidden;position:relative">{svg_inline(ICON / "android-adaptive-background.svg", height="108px")}<div style="position:absolute;inset:0">{svg_inline(ICON / "android-adaptive-foreground.svg", height="108px")}</div></div>
      </div></div>
    <div class="card"><h3>Launcher sizes</h3><p class="sub" style="margin-top:6px">Rendered from the same SVG at common launcher sizes.</p>
      <div class="sizes" style="margin-top:14px">
        <div>{svg_inline(ICON / "app-icon-dark.svg", height="96px")}96</div>
        <div>{svg_inline(ICON / "app-icon-dark.svg", height="72px")}72</div>
        <div>{svg_inline(ICON / "app-icon-dark.svg", height="48px")}48</div>
        <div>{svg_inline(ICON / "app-icon-dark.svg", height="36px")}36</div>
        <div>{svg_inline(ICON / "app-icon-dark.svg", height="24px")}24</div>
      </div></div>
  </div>
</section>

<section>
  <div class="eyebrow">4 · Colour</div>
  <h2>Forge Amber / Slate</h2>
  <p class="lead">Core palette and semantic colours exactly as approved. Amber is the only brand accent. Semantic colours appear only where their meaning applies.</p>
  <div class="swatches" style="margin-top:20px">
    <div class="swatch"><div class="c" style="background:#1F2A3A"></div><div class="t"><b>Forge Slate</b><code>#1F2A3A</code></div></div>
    <div class="swatch"><div class="c" style="background:#FF8A00"></div><div class="t"><b>Forge Amber</b><code>#FF8A00</code></div></div>
    <div class="swatch"><div class="c" style="background:#3B4A5A"></div><div class="t"><b>Steel</b><code>#3B4A5A</code></div></div>
    <div class="swatch"><div class="c" style="background:#6B7B8C"></div><div class="t"><b>Stone</b><code>#6B7B8C</code></div></div>
    <div class="swatch"><div class="c" style="background:#BBC4CF"></div><div class="t"><b>Mist</b><code>#BBC4CF</code></div></div>
    <div class="swatch"><div class="c" style="background:#F2E8DC"></div><div class="t"><b>Sand</b><code>#F2E8DC</code></div></div>
  </div>
  <div class="swatches" style="margin-top:12px">
    <div class="swatch"><div class="c" style="background:#22C55E"></div><div class="t"><b>Success</b><code>#22C55E</code></div></div>
    <div class="swatch"><div class="c" style="background:#3B82F6"></div><div class="t"><b>Information</b><code>#3B82F6</code></div></div>
    <div class="swatch"><div class="c" style="background:#EF4444"></div><div class="t"><b>Alert</b><code>#EF4444</code></div></div>
    <div class="swatch"><div class="c" style="background:#8B5CF6"></div><div class="t"><b>Focus</b><code>#8B5CF6</code></div></div>
  </div>

  <h3 style="margin-top:36px">Dark theme (primary)</h3>
  <div class="tokens" style="margin-top:12px;padding:16px;border-radius:18px;background:#111923;border:1px solid #354557">
    <div class="tok" style="background:#111923;color:#F5F7FA"><b>Background</b><code>#111923</code></div>
    <div class="tok" style="background:#182331;color:#F5F7FA"><b>Surface 1</b><code>#182331</code></div>
    <div class="tok" style="background:#1F2A3A;color:#F5F7FA"><b>Surface 2</b><code>#1F2A3A</code></div>
    <div class="tok" style="background:#263648;color:#F5F7FA"><b>Surface 3</b><code>#263648</code></div>
    <div class="tok" style="background:#304357;color:#F5F7FA"><b>Elevated</b><code>#304357</code></div>
    <div class="tok" style="background:#1F2A3A;color:#F5F7FA"><b>Primary text</b><code>#F5F7FA</code></div>
    <div class="tok" style="background:#1F2A3A;color:#BBC4CF"><b>Secondary text</b><code>#BBC4CF</code></div>
    <div class="tok" style="background:#1F2A3A;color:#8E9DAE"><b>Muted text</b><code>#8E9DAE ↑</code></div>
    <div class="tok" style="background:#1F2A3A;color:#FF8A00"><b>Accent</b><code>#FF8A00</code></div>
    <div class="tok" style="background:#1F2A3A;color:#F5F7FA;border-color:#354557"><b>Border</b><code>#354557</code></div>
  </div>
  <h3 style="margin-top:28px">Light theme</h3>
  <div class="tokens" style="margin-top:12px;padding:16px;border-radius:18px;background:#FBF9F6;border:1px solid #E4DED6">
    <div class="tok" style="background:#FBF9F6;color:#1F2A3A"><b>Background</b><code>#FBF9F6</code></div>
    <div class="tok" style="background:#FFFFFF;color:#1F2A3A"><b>Surface 1</b><code>#FFFFFF</code></div>
    <div class="tok" style="background:#F5F1EB;color:#1F2A3A"><b>Surface 2</b><code>#F5F1EB</code></div>
    <div class="tok" style="background:#ECE6DE;color:#1F2A3A"><b>Surface 3</b><code>#ECE6DE</code></div>
    <div class="tok" style="background:#FFFFFF;color:#1F2A3A"><b>Primary text</b><code>#1F2A3A</code></div>
    <div class="tok" style="background:#FFFFFF;color:#3B4A5A"><b>Secondary text</b><code>#3B4A5A</code></div>
    <div class="tok" style="background:#FFFFFF;color:#5E6E7F"><b>Muted text</b><code>#5E6E7F ↑</code></div>
    <div class="tok" style="background:#FFFFFF;color:#B45F00"><b>Amber Ink (text)</b><code>#B45F00 +</code></div>
    <div class="tok" style="background:#FF8A00;color:#1F2A3A"><b>Accent fill</b><code>#FF8A00</code></div>
    <div class="tok" style="background:#FFFFFF;color:#1F2A3A;border-color:#E4DED6"><b>Border</b><code>#E4DED6</code></div>
  </div>

  <div class="grid g2" style="margin-top:24px">
    <div class="card"><h3>Contrast, dark theme</h3><div class="tscroll"><table style="margin-top:8px"><tr><th>Foreground</th><th>Background</th><th>WCAG</th></tr>{contrast_rows(dark_pairs)}</table></div></div>
    <div class="card"><h3>Contrast, light theme</h3><div class="tscroll"><table style="margin-top:8px"><tr><th>Foreground</th><th>Background</th><th>WCAG</th></tr>{contrast_rows(light_pairs)}</table></div>
      <p class="sub" style="margin-top:12px">Semantic colours are used for icons, fills and large status text. Small semantic text gets a darker ink in light mode in Stage 2.</p></div>
  </div>
</section>

<section>
  <div class="eyebrow">5 · Typography</div>
  <h2>Sora · Manrope · IBM Plex Mono</h2>
  <p class="lead">Three families with fixed roles. No additional families. The scale below is the Stage 2 starting point and is shown here so the dashboard can be judged against it.</p>
  <div class="grid g3" style="margin-top:20px">
    <div class="card"><div class="eyebrow">Brand and headings</div><div class="sora" style="font-size:40px;font-weight:700;letter-spacing:-.02em;line-height:1.05">Sora</div><p class="sora sub" style="font-size:18px;font-weight:600;margin-top:10px;color:var(--pg-fg)">Upper Body Strength</p><p class="sub" style="margin-top:8px">Weights 500–700. Page titles, section headings, hero figures.</p></div>
    <div class="card"><div class="eyebrow">Interface and body</div><div class="manrope" style="font-size:40px;font-weight:700;letter-spacing:-.01em;line-height:1.05">Manrope</div><p class="manrope sub" style="font-size:15px;margin-top:10px;color:var(--pg-fg)">Day 2 · 6 exercises · about 45 minutes. Rest 90 seconds between working sets.</p><p class="sub" style="margin-top:8px">Weights 400–700. Body, navigation, labels, buttons.</p></div>
    <div class="card"><div class="eyebrow">Technical and numerical</div><div class="mono" style="font-size:40px;font-weight:600;line-height:1.05">Plex Mono</div><p class="mono sub" style="font-size:15px;margin-top:10px;color:var(--pg-fg)">86.8 kg · 1,420 / 2,600 kcal · 4 × 8 @ 92.5</p><p class="sub" style="margin-top:8px">Weights 400–600. Stats, weights, reps, macros, timestamps.</p></div>
  </div>
  <div class="card" style="margin-top:16px">
    <div class="type-sample">
      <div class="type-row"><div class="k"><b>Display</b>Sora 700 · 40/44 · −2%</div><div class="sora" style="font-size:40px;font-weight:700;letter-spacing:-.02em;line-height:1.1">Train. Fuel. Track. Transform.</div></div>
      <div class="type-row"><div class="k"><b>H1</b>Sora 700 · 28/34 · −1.5%</div><div class="sora" style="font-size:28px;font-weight:700;letter-spacing:-.015em;line-height:1.2">Good morning, Steven</div></div>
      <div class="type-row"><div class="k"><b>H2</b>Sora 600 · 22/28 · −1%</div><div class="sora" style="font-size:22px;font-weight:600;letter-spacing:-.01em;line-height:1.27">Upper Body Strength</div></div>
      <div class="type-row"><div class="k"><b>H3</b>Sora 600 · 18/24</div><div class="sora" style="font-size:18px;font-weight:600;line-height:1.33">Nutrition today</div></div>
      <div class="type-row"><div class="k"><b>H4</b>Sora 600 · 16/22</div><div class="sora" style="font-size:16px;font-weight:600;line-height:1.37">Bodyweight goal</div></div>
      <div class="type-row"><div class="k"><b>Body large</b>Manrope 500 · 17/26</div><div class="manrope" style="font-size:17px;line-height:1.53">Keep rest periods consistent so progression data stays comparable week to week.</div></div>
      <div class="type-row"><div class="k"><b>Body</b>Manrope 500 · 15/22</div><div class="manrope" style="font-size:15px;line-height:1.47">Keep rest periods consistent so progression data stays comparable week to week.</div></div>
      <div class="type-row"><div class="k"><b>Body small</b>Manrope 500 · 13/18</div><div class="manrope" style="font-size:13px;line-height:1.38">Product data is crowdsourced. Verify the label and serving size.</div></div>
      <div class="type-row"><div class="k"><b>Label</b>Manrope 600 · 11/14 · +8% caps</div><div class="manrope" style="font-size:11px;font-weight:600;letter-spacing:.08em;text-transform:uppercase;color:var(--pg-muted)">Workouts this week</div></div>
      <div class="type-row"><div class="k"><b>Caption</b>Manrope 500 · 12/16</div><div class="manrope" style="font-size:12px;line-height:1.33;color:var(--pg-muted)">Yesterday · 52 min · 12,400 kg volume</div></div>
      <div class="type-row"><div class="k"><b>Data XL</b>Plex Mono 600 · 36/40</div><div class="mono" style="font-size:36px;font-weight:600;line-height:1.1">1,180 <span style="font-size:14px;font-weight:400;color:var(--pg-muted)">kcal</span></div></div>
      <div class="type-row"><div class="k"><b>Data L</b>Plex Mono 600 · 28/32</div><div class="mono" style="font-size:28px;font-weight:600;line-height:1.14">86.8 kg</div></div>
      <div class="type-row"><div class="k"><b>Data M</b>Plex Mono 500 · 17/22</div><div class="mono" style="font-size:17px;font-weight:500">4 × 8 @ 92.5 kg</div></div>
      <div class="type-row"><div class="k"><b>Data S</b>Plex Mono 500 · 13/18</div><div class="mono" style="font-size:13px;font-weight:500">142 / 200 g</div></div>
      <div class="type-row"><div class="k"><b>Meta</b>Plex Mono 400 · 11/16 · +4%</div><div class="mono" style="font-size:11px;letter-spacing:.04em;color:var(--pg-muted)">2026-11-02 07:41 · SYNCED</div></div>
    </div>
  </div>
</section>

<section>
  <div class="eyebrow">6 · Dashboard</div>
  <h2>Representative dashboard, dark theme</h2>
  <p class="lead">Built with the draft tokens only. Amber appears on progress fills, the primary action, the active tab and small icon tiles. Everything else is slate surface hierarchy and type. The screen scrolls, so the second phone shows the lower half. The third phone switches the same markup to the light tokens to check that both themes feel like one product.</p>
  <div class="phones">
    <div><div class="phone-scale">{markup}</div><div class="phone-cap">Dark · top of screen</div></div>
    <div><div class="phone-scale scrolled">{markup}</div><div class="phone-cap">Dark · scrolled</div></div>
    <div><div class="phone-scale">{markup_light}</div><div class="phone-cap">Light theme · same components</div></div>
  </div>
</section>

<section>
  <div class="eyebrow">7 · Approval</div>
  <h2>Decisions needed before Stage 2</h2>
  <div class="q" style="margin-top:16px">
    <div class="card"><div class="n">1</div><div><b>Monogram geometry.</b> Approve the rebuilt mark (12° slant, stroke 20% of height, leg at 34°, F resting on the leg), or request changes to the leg angle, bowl size or F position.</div></div>
    <div class="card"><div class="n">1b</div><div><b>Flat or gradient.</b> Flat masters for the app and icons, gradient variants only for hero, splash and marketing (as shown). Confirm, or make gradient the primary treatment.</div></div>
    <div class="card"><div class="n">2</div><div><b>Slate labels on amber buttons.</b> Approve dark labels on primary buttons (AA) in place of the board's white labels.</div></div>
    <div class="card"><div class="n">3</div><div><b>Amber Ink #B45F00</b> for amber text and links on light surfaces, with #FF8A00 kept for fills and icons.</div></div>
    <div class="card"><div class="n">4</div><div><b>Muted text #8E9DAE</b> in dark mode, replacing the brief's #8291A2.</div></div>
    <div class="card"><div class="n">5</div><div><b>App icon background</b>: subtle slate gradient (shown) or flat Forge Slate.</div></div>
    <div class="card"><div class="n">6</div><div><b>Bottom navigation labels</b>: Home · Train · Fuel · Track · Goals (pillar-based, shown) or the board's Home · Plan · Log · Progress · You.</div></div>
    <div class="card"><div class="n">7</div><div><b>Iconography.</b> The uploaded icon set is withdrawn. Confirm the brief's rounded geometric stroke icons (as in the dashboard mock) as the Stage 2 direction.</div></div>
  </div>
  <p class="sub" style="margin-top:20px">After approval, Stage 2 delivers the full token set (JSON + CSS + Compose), the complete type scale, spacing, radius and elevation, and the icon library. Stage 3 the component library, Stage 4 the remaining screens, Stage 5 the developer handover.</p>
</section>

<footer>RepForge Design System v1.0 · Stage 1 · Brand reconstruction · Generated from design/tools in the repforge repository. Fonts: Sora, Manrope and IBM Plex Mono under the SIL Open Font License.</footer>
</div>
<script>
document.querySelectorAll('.scrolled .rf-content').forEach(function (el) {{ el.scrollTop = 560; }});
</script>
"""

OUT.write_text(page, encoding="utf-8")
print("wrote", OUT.relative_to(ROOT.parent), f"{OUT.stat().st_size / 1024:.0f} KB")
