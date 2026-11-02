#!/usr/bin/env python3
"""RepForge logo builder — single source of truth for all logo / icon SVG masters.

Usage:  python3 design/tools/build_logo.py
Writes: design/brand/logo/*.svg, design/brand/icon/*.svg, design/brand/logo/geometry.json

The RF monogram is defined as upright polygons on a 128-unit grid, sheared by the brand
slant (12 degrees), then every corner is rounded with true circular arcs. The wordmark is
set from the bundled Sora variable font (instanced at wght 700) and converted to outlines
with HarfBuzz shaping, so the SVGs need no fonts installed.
"""
import json
import math
import os
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
LOGO_DIR = ROOT / "brand" / "logo"
ICON_DIR = ROOT / "brand" / "icon"
FONT_DIR = ROOT / "fonts"
LOGO_DIR.mkdir(parents=True, exist_ok=True)
ICON_DIR.mkdir(parents=True, exist_ok=True)

# ----------------------------------------------------------------------------------------
# Brand colours
# ----------------------------------------------------------------------------------------
SLATE = "#1F2A3A"
AMBER = "#FF8A00"
LIGHT = "#F5F7FA"
DEEP = "#111923"
SAND = "#F2E8DC"

# ----------------------------------------------------------------------------------------
# Monogram geometry (upright, 128 grid). S = stroke 26, slant 12 degrees.
# ----------------------------------------------------------------------------------------
H = 128.0
STROKE = 26.0
SLANT_DEG = 12.0
TAN = math.tan(math.radians(SLANT_DEG))

R_OUT = 6.0   # convex outer corners
R_IN = 3.0    # concave corners
R_BOWL = 26.0 # bowl shoulder radius
R_CTR = 9.0   # counter radius

# Leg: upper edge passes through the counter's bottom-right corner (58,46), slope 0.55 (29 deg upright).
LEG_M = 0.68
def leg_top(x):
    return 46.0 + LEG_M * (x - 58.0)
def leg_bot(x):
    return 77.4 + LEG_M * (x - 58.0)   # perpendicular thickness ~26
LEG_END = 133.0
BOWL_R = 84.0

# R silhouette, clockwise on screen. (x, y, corner radius)
R_OUTLINE = [
    (0, 0, R_OUT), (BOWL_R, 0, R_BOWL), (BOWL_R, leg_top(BOWL_R), R_IN),
    (LEG_END, leg_top(LEG_END), R_OUT), (LEG_END, 128, R_OUT),
    (58 + (70 - 77.4) / LEG_M, 70, R_OUT), (26, 70, R_IN), (26, 128, R_OUT), (0, 128, R_OUT),
]
# Counter, counter-clockwise (hole under nonzero fill)
R_COUNTER = [(26, 24, R_IN), (26, 46, R_IN), (58, 46, R_CTR), (58, 24, R_CTR)]

# F silhouette, clockwise, drawn behind the R. Stem 100..126 sits on the leg; bars share the R's lines.
F_OUTLINE = [
    (98, 0, R_OUT), (178, 0, R_OUT), (178, 24, R_OUT), (124, 24, R_IN), (124, 46, R_IN),
    (152, 46, R_OUT), (152, 70, R_OUT), (124, 70, R_IN), (124, 95, 0), (98, 95, 0),
]


def shear(pts):
    return [(x + (H - y) * TAN, y, r) for (x, y, r) in pts]


def rounded_path(pts):
    """Polygon -> SVG path with circular-arc corners (per-vertex radius)."""
    n = len(pts)
    segs = []
    for i in range(n):
        px, py, r = pts[i]
        ax, ay, _ = pts[i - 1]
        bx, by, _ = pts[(i + 1) % n]
        ux, uy = ax - px, ay - py
        vx, vy = bx - px, by - py
        lu = math.hypot(ux, uy)
        lv = math.hypot(vx, vy)
        ux, uy, vx, vy = ux / lu, uy / lu, vx / lv, vy / lv
        cos_t = max(-1.0, min(1.0, ux * vx + uy * vy))
        theta = math.acos(cos_t)
        if r <= 0 or theta <= 1e-6 or abs(theta - math.pi) < 1e-6:
            segs.append(("L", px, py))
            continue
        t = r / math.tan(theta / 2)
        t = min(t, lu / 2 - 0.01, lv / 2 - 0.01)
        rr = t * math.tan(theta / 2)
        p1 = (px + ux * t, py + uy * t)
        p2 = (px + vx * t, py + vy * t)
        cross = ux * vy - uy * vx
        sweep = 0 if cross > 0 else 1
        segs.append(("A", p1, p2, rr, sweep))
    d = []
    first = True
    for s in segs:
        if s[0] == "L":
            d.append(("M" if first else "L") + f"{s[1]:.2f} {s[2]:.2f}")
        else:
            _, p1, p2, rr, sweep = s
            d.append(("M" if first else "L") + f"{p1[0]:.2f} {p1[1]:.2f}")
            d.append(f"A{rr:.2f} {rr:.2f} 0 0 {sweep} {p2[0]:.2f} {p2[1]:.2f}")
        first = False
    d.append("Z")
    return "".join(d)


R_PATH = rounded_path(shear(R_OUTLINE)) + rounded_path(shear(R_COUNTER))
F_PATH = rounded_path(shear(F_OUTLINE))

MONO_W = 178.0 + H * TAN  # right edge of F top bar after shear
MONO_H = H
MONO_W = round(MONO_W, 2)


def monogram_group(r_fill, f_fill, x=0.0, y=0.0, scale=1.0):
    return (f'<g transform="translate({x:.2f} {y:.2f}) scale({scale:.5f})">'
            f'<path fill="{f_fill}" d="{F_PATH}"/>'
            f'<path fill="{r_fill}" fill-rule="nonzero" d="{R_PATH}"/></g>')


def svg(w, h, body, title, bg=None):
    bg_el = f'<rect width="{w:.2f}" height="{h:.2f}" fill="{bg}"/>' if bg else ""
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w:.2f} {h:.2f}" '
            f'width="{w:.2f}" height="{h:.2f}" role="img" aria-label="{title}">'
            f'<title>{title}</title>{bg_el}{body}</svg>\n')


def write(path, content):
    path.write_text(content, encoding="utf-8")
    print("wrote", path.relative_to(ROOT.parent))


# ----------------------------------------------------------------------------------------
# Wordmark outlines (Sora 700 via fontTools instancer + HarfBuzz)
# ----------------------------------------------------------------------------------------
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
import uharfbuzz as hb


def instanced(path, wght):
    font = TTFont(path)
    if "fvar" in font:
        font = instancer.instantiateVariableFont(font, {"wght": wght}, inplace=False)
    return font


def shape_text(font_path, wght, text, size, tracking_em=0.0, oblique=False):
    """Return (glyph path strings positioned at size px, advance width, cap height, metrics)."""
    font = instanced(font_path, wght)
    tmp = pathlib.Path("/tmp/_rf_inst.ttf")
    font.save(tmp)
    data = tmp.read_bytes()
    face = hb.Face(data)
    hbfont = hb.Font(face)
    upem = face.upem
    hbfont.scale = (upem, upem)
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(hbfont, buf, {"kern": True, "liga": True})
    glyph_set = font.getGlyphSet()
    order = font.getGlyphOrder()
    k = size / upem
    x = 0.0
    paths = []
    tracking = tracking_em * size
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        name = order[info.codepoint]
        pen = SVGPathPen(glyph_set)
        tp = TransformPen(pen, (k, 0, k * TAN if oblique else 0, -k, x + pos.x_offset * k, -pos.y_offset * k))
        glyph_set[name].draw(tp)
        paths.append((info.cluster, pen.getCommands()))
        x += pos.x_advance * k + tracking
    x -= tracking
    os2 = font["OS/2"]
    cap = getattr(os2, "sCapHeight", 0) * k or 0.7 * size
    return paths, x, cap


def wordmark_paths(size, rep_fill, forge_fill, tracking=-0.015):
    paths, width, cap = shape_text(FONT_DIR / "Sora[wght].ttf", 700, "RepForge", size, tracking, oblique=True)
    out = []
    for cluster, d in paths:
        fill = rep_fill if cluster < 3 else forge_fill
        out.append(f'<path fill="{fill}" d="{d}"/>')
    return "".join(out), width, cap


def tagline_paths(size, fill, tracking=0.22):
    paths, width, cap = shape_text(FONT_DIR / "Manrope[wght].ttf", 600,
                                   "TRAIN • FUEL • TRACK • TRANSFORM", size, tracking)
    return "".join(f'<path fill="{fill}" d="{d}"/>' for _, d in paths), width, cap


# ----------------------------------------------------------------------------------------
# Build monogram files
# ----------------------------------------------------------------------------------------
PAD = 8.0
variants = {
    "rf-monogram.svg": (LIGHT, AMBER, None, "RepForge RF monogram (for dark backgrounds)"),
    "rf-monogram-on-light.svg": (SLATE, AMBER, None, "RepForge RF monogram (for light backgrounds)"),
    "rf-monogram-mono-dark.svg": (SLATE, SLATE, None, "RepForge RF monogram, monochrome slate"),
    "rf-monogram-mono-light.svg": (LIGHT, LIGHT, None, "RepForge RF monogram, monochrome light"),
    "rf-monogram-mono-amber.svg": (AMBER, AMBER, None, "RepForge RF monogram, monochrome amber"),
}
for name, (rf, ff, bg, title) in variants.items():
    body = monogram_group(rf, ff, PAD, PAD)
    write(LOGO_DIR / name, svg(MONO_W + 2 * PAD, MONO_H + 2 * PAD, body, title, bg))

# Gradient variants for hero and marketing use (flat versions remain the UI masters)
GRAD_DEFS = ('<defs><linearGradient id="rfAmber" x1="0" y1="0" x2="1" y2="1">'
             '<stop offset="0" stop-color="#FFB13B"/><stop offset="0.55" stop-color="#FF8A00"/><stop offset="1" stop-color="#E96B00"/></linearGradient>'
             '<linearGradient id="rfSilver" x1="0" y1="0" x2="1" y2="1">'
             '<stop offset="0" stop-color="#FFFFFF"/><stop offset="1" stop-color="#BBC4CF"/></linearGradient>'
             '<linearGradient id="rfSlate" x1="0" y1="0" x2="1" y2="1">'
             '<stop offset="0" stop-color="#3B4A5A"/><stop offset="1" stop-color="#1F2A3A"/></linearGradient></defs>')
write(LOGO_DIR / "rf-monogram-gradient.svg",
      svg(MONO_W + 2 * PAD, MONO_H + 2 * PAD, GRAD_DEFS + monogram_group("url(#rfSilver)", "url(#rfAmber)", PAD, PAD),
          "RepForge RF monogram, gradient, for dark backgrounds"))
write(LOGO_DIR / "rf-monogram-gradient-on-light.svg",
      svg(MONO_W + 2 * PAD, MONO_H + 2 * PAD, GRAD_DEFS + monogram_group("url(#rfSlate)", "url(#rfAmber)", PAD, PAD),
          "RepForge RF monogram, gradient, for light backgrounds"))

# Amber-on-slate: all-amber monogram on a slate rounded panel
panel_w, panel_h = MONO_W + 64, MONO_H + 64
body = (f'<rect width="{panel_w:.2f}" height="{panel_h:.2f}" rx="24" fill="{SLATE}"/>'
        + monogram_group(AMBER, AMBER, 32, 32))
write(LOGO_DIR / "rf-monogram-amber-on-slate.svg", svg(panel_w, panel_h, body, "RepForge RF monogram, amber on slate"))

# ----------------------------------------------------------------------------------------
# Wordmark + lockups
# ----------------------------------------------------------------------------------------
WM_SIZE = 125.0  # font size so that cap height ~ 0.70 * monogram height
_, _, cap_probe = wordmark_paths(WM_SIZE, SLATE, AMBER)
WM_SIZE = WM_SIZE * (0.74 * MONO_H) / cap_probe
wm_body, wm_w, wm_cap = wordmark_paths(WM_SIZE, SLATE, AMBER)
DESC = 0.26 * WM_SIZE  # room for p / g descenders

for name, rep, forge, bg, title in [
    ("repforge-wordmark.svg", SLATE, AMBER, None, "RepForge wordmark (for light backgrounds)"),
    ("repforge-wordmark-reversed.svg", LIGHT, AMBER, None, "RepForge wordmark (for dark backgrounds)"),
    ("repforge-wordmark-mono-dark.svg", SLATE, SLATE, None, "RepForge wordmark, monochrome slate"),
    ("repforge-wordmark-mono-light.svg", LIGHT, LIGHT, None, "RepForge wordmark, monochrome light"),
]:
    paths, w, cap = wordmark_paths(WM_SIZE, rep, forge)
    body = f'<g transform="translate({PAD:.2f} {PAD + cap:.2f})">{paths}</g>'
    write(LOGO_DIR / name, svg(w + 2 * PAD, cap + DESC + PAD, body, title, bg))

GAP = 0.30 * MONO_H


def lockup(r_fill, f_fill, rep_fill, forge_fill, tagline_fill=None, bg=None, title="", defs=""):
    paths, w, cap = wordmark_paths(WM_SIZE, rep_fill, forge_fill)
    total_w = MONO_W + GAP + w + 2 * PAD
    base_y = PAD + MONO_H
    body = defs + monogram_group(r_fill, f_fill, PAD, PAD)
    body += f'<g transform="translate({PAD + MONO_W + GAP:.2f} {base_y:.2f})">{paths}</g>'
    total_h = base_y + DESC
    if tagline_fill:
        tl_size = 0.155 * MONO_H
        tl, tl_w, tl_cap = tagline_paths(tl_size, tagline_fill)
        ty = base_y + DESC + tl_cap + 0.02 * MONO_H
        tx = PAD + MONO_W + GAP
        body += f'<g transform="translate({tx:.2f} {ty:.2f})">{tl}</g>'
        total_h = ty + PAD
        total_w = max(total_w, tx + tl_w + PAD)
    return svg(total_w, total_h, body, title, bg)


write(LOGO_DIR / "repforge-lockup-horizontal.svg",
      lockup(SLATE, AMBER, SLATE, AMBER, title="RepForge primary horizontal lockup"))
write(LOGO_DIR / "repforge-lockup-horizontal-reversed.svg",
      lockup(LIGHT, AMBER, LIGHT, AMBER, title="RepForge reversed horizontal lockup"))
write(LOGO_DIR / "repforge-lockup-horizontal-mono-dark.svg",
      lockup(SLATE, SLATE, SLATE, SLATE, title="RepForge horizontal lockup, monochrome slate"))
write(LOGO_DIR / "repforge-lockup-horizontal-mono-light.svg",
      lockup(LIGHT, LIGHT, LIGHT, LIGHT, title="RepForge horizontal lockup, monochrome light"))
write(LOGO_DIR / "repforge-lockup-horizontal-gradient.svg",
      lockup("url(#rfSlate)", "url(#rfAmber)", SLATE, "url(#rfAmber)", title="RepForge horizontal lockup, gradient", defs=GRAD_DEFS))
write(LOGO_DIR / "repforge-lockup-horizontal-gradient-reversed.svg",
      lockup("url(#rfSilver)", "url(#rfAmber)", LIGHT, "url(#rfAmber)", title="RepForge horizontal lockup, gradient, reversed", defs=GRAD_DEFS))
write(LOGO_DIR / "repforge-lockup-tagline.svg",
      lockup(SLATE, AMBER, SLATE, AMBER, tagline_fill="#6B7B8C", title="RepForge lockup with tagline"))
write(LOGO_DIR / "repforge-lockup-tagline-reversed.svg",
      lockup(LIGHT, AMBER, LIGHT, AMBER, tagline_fill="#BBC4CF", title="RepForge lockup with tagline, reversed"))

# Stacked lockup (monogram above wordmark) for splash / square placements
def stacked(r_fill, f_fill, rep_fill, forge_fill, title):
    paths, w, cap = wordmark_paths(WM_SIZE * 0.8, rep_fill, forge_fill)
    mono_scale = 1.35
    mw, mh = MONO_W * mono_scale, MONO_H * mono_scale
    total_w = max(mw, w) + 2 * PAD
    body = monogram_group(r_fill, f_fill, (total_w - mw) / 2, PAD, mono_scale)
    ty = PAD + mh + 0.32 * MONO_H + cap
    body += f'<g transform="translate({(total_w - w) / 2:.2f} {ty:.2f})">{paths}</g>'
    return svg(total_w, ty + DESC * 0.8 + PAD, body, title)


write(LOGO_DIR / "repforge-lockup-stacked.svg", stacked(SLATE, AMBER, SLATE, AMBER, "RepForge stacked lockup"))
write(LOGO_DIR / "repforge-lockup-stacked-reversed.svg", stacked(LIGHT, AMBER, LIGHT, AMBER, "RepForge stacked lockup, reversed"))

# ----------------------------------------------------------------------------------------
# App icons
# ----------------------------------------------------------------------------------------
def icon_512(bg_fill, r_fill, f_fill, title, radius=112, content_w=340, gradient=None):
    size = 512.0
    scale = content_w / MONO_W
    mw, mh = MONO_W * scale, MONO_H * scale
    defs = ""
    fill = bg_fill
    if gradient:
        defs = (f'<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
                f'<stop offset="0" stop-color="{gradient[0]}"/><stop offset="1" stop-color="{gradient[1]}"/>'
                f'</linearGradient></defs>')
        fill = "url(#bg)"
    body = defs + f'<rect width="{size}" height="{size}" rx="{radius}" fill="{fill}"/>'
    # optical centre: nudge the slanted mark 2% left so the visual mass sits centred
    body += monogram_group(r_fill, f_fill, (size - mw) / 2 - 0.02 * size, (size - mh) / 2, scale)
    return svg(size, size, body, title)


write(ICON_DIR / "app-icon-dark.svg", icon_512(SLATE, LIGHT, AMBER, "RepForge app icon, dark", gradient=("#26344A", "#182331")))
write(ICON_DIR / "app-icon-amber.svg", icon_512(AMBER, LIGHT, SLATE, "RepForge app icon, amber"))
write(ICON_DIR / "app-icon-light.svg", icon_512("#F4F1EC", SLATE, AMBER, "RepForge app icon, light"))
# PWA maskable: content inside the 80% safe circle (diameter 410) -> width 328
write(ICON_DIR / "pwa-icon-maskable-512.svg", icon_512(SLATE, LIGHT, AMBER, "RepForge PWA maskable icon", radius=0, content_w=310, gradient=("#26344A", "#182331")))
write(ICON_DIR / "pwa-icon-any-512.svg", icon_512(SLATE, LIGHT, AMBER, "RepForge PWA icon", gradient=("#26344A", "#182331")))

# Android adaptive icon layers (108dp canvas; safe zone = 66dp circle)
def adaptive_fg():
    size = 108.0
    content_w = 56.0  # fits inside the 66dp safe circle (aspect 1.63 -> diagonal 65.7)
    scale = content_w / MONO_W
    mw, mh = MONO_W * scale, MONO_H * scale
    body = monogram_group(LIGHT, AMBER, (size - mw) / 2 - 0.02 * size, (size - mh) / 2, scale)
    return svg(size, size, body, "RepForge adaptive icon foreground")


write(ICON_DIR / "android-adaptive-foreground.svg", adaptive_fg())
write(ICON_DIR / "android-adaptive-background.svg",
      svg(108, 108, '<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
          '<stop offset="0" stop-color="#26344A"/><stop offset="1" stop-color="#182331"/></linearGradient></defs>'
          '<rect width="108" height="108" fill="url(#bg)"/>', "RepForge adaptive icon background"))
write(ICON_DIR / "android-adaptive-monochrome.svg",
      svg(108, 108, monogram_group(LIGHT, LIGHT, (108 - 56) / 2 - 2.16, (108 - MONO_H * 56 / MONO_W) / 2, 56 / MONO_W),
          "RepForge adaptive icon monochrome layer"))

# ----------------------------------------------------------------------------------------
# Geometry export for the design system docs / inline use
# ----------------------------------------------------------------------------------------
geom = {
    "grid": {"height": H, "width": MONO_W, "stroke": STROKE, "slantDeg": SLANT_DEG,
             "radii": {"outer": R_OUT, "inner": R_IN, "bowlShoulder": R_BOWL, "counter": R_CTR}},
    "paths": {"R": R_PATH, "F": F_PATH},
    "wordmark": {"font": "Sora", "weight": 700, "tracking": -0.015, "capHeightRatio": 0.74, "gapRatio": 0.30, "oblique": SLANT_DEG},
}
write(LOGO_DIR / "geometry.json", json.dumps(geom, indent=2) + "\n")
print("monogram box", MONO_W, MONO_H)
