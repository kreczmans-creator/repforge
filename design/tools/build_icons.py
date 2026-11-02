#!/usr/bin/env python3
"""RepForge icon library builder.

Icons are authored on a 24-unit grid, stroke 2, round caps and joins, 1-unit safe margin.
Outputs:
  design/brand/icons/glyph/<name>.svg   24x24, stroke="currentColor" (UI use at 20/24/32 px)
  design/brand/icons/tile/<name>.svg    128x128 slate tile with the amber glyph (feature tiles, marketing)
  design/brand/icons/icons.json         manifest with path data for inline use
Usage: python3 design/tools/build_icons.py
"""
import json
import math
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]
GLYPH = ROOT / "brand" / "icons" / "glyph"
TILE = ROOT / "brand" / "icons" / "tile"
GLYPH.mkdir(parents=True, exist_ok=True)
TILE.mkdir(parents=True, exist_ok=True)

AMBER = "#FF8A00"


def gear(cx=12, cy=12, teeth=8, r_out=9.2, r_in=7.0):
    pts = []
    n = teeth * 4
    for i in range(n):
        a = 2 * math.pi * i / n - math.pi / 2
        step = i % 4
        r = r_out if step in (1, 2) else r_in
        # tooth edges slightly offset so teeth are narrower than gaps
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d = "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts) + "Z"
    return d


# Each icon: list of (kind, data). kind "s" = stroked path, "f" = filled path (solid detail).
ICONS = {
    "training": {
        "label": "Training", "group": "training",
        "parts": [("s", "M8 12h8"),
                  ("f", "M5 6.5h3v11H5zM16 6.5h3v11h-3z"),
                  ("f", "M1.5 8.5h2.5v7H1.5zM20 8.5h2.5v7H20z"),
                  ("s", "M5.75 7.25h1.5v9.5h-1.5zM16.75 7.25h1.5v9.5h-1.5zM2.25 9.25h1v5.5h-1zM20.75 9.25h1v5.5h-1z")],
    },
    "nutrition": {
        "label": "Nutrition", "group": "nutrition",
        "parts": [("s", "M5 3v4.5a2.5 2.5 0 0 0 5 0V3M7.5 3v18"),
                  ("s", "M17.5 3c-2.2 2.4-3.3 5.3-3.3 8.5h3.3V21M17.5 3v8.5")],
    },
    "progress": {
        "label": "Progress", "group": "progress",
        "parts": [("s", "M3 14.5a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1V21H3zM10 9.5a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1V21h-4zM17 3.5a1 1 0 0 1 1-1h2a1 1 0 0 1 1 1V21h-4z")],
    },
    "plan": {
        "label": "Plan", "group": "application",
        "parts": [("s", "M3 7.5a2.5 2.5 0 0 1 2.5-2.5h13A2.5 2.5 0 0 1 21 7.5v11a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 18.5z"),
                  ("s", "M3 10.5h18M8 3v4M16 3v4"),
                  ("f", "M8.75 14.25a1.25 1.25 0 1 1 2.5 0 1.25 1.25 0 0 1-2.5 0zM12.75 14.25a1.25 1.25 0 1 1 2.5 0 1.25 1.25 0 0 1-2.5 0zM8.75 17.75a1.25 1.25 0 1 1 2.5 0 1.25 1.25 0 0 1-2.5 0z")],
    },
    "goals": {
        "label": "Goals", "group": "goals",
        "parts": [("s", "M19 13a8 8 0 1 1-6-7.75"), ("s", "M15 13a4 4 0 1 1-3-3.87"),
                  ("f", "M9.5 13a1.5 1.5 0 1 1 3 0 1.5 1.5 0 0 1-3 0z"),
                  ("s", "M11 13l9.5-9.5M16.5 3.5h4v4")],
    },
    "body": {
        "label": "Body", "group": "progress",
        "parts": [("s", "M3 9.5A2.5 2.5 0 0 1 5.5 7h13A2.5 2.5 0 0 1 21 9.5v8a2.5 2.5 0 0 1-2.5 2.5h-13A2.5 2.5 0 0 1 3 17.5z"),
                  ("s", "M9 7V5.5A1.5 1.5 0 0 1 10.5 4h3A1.5 1.5 0 0 1 15 5.5V7"),
                  ("s", "M12 10a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5z"), ("s", "M9 17.5h6")],
    },
    "achievements": {
        "label": "Achievements", "group": "goals",
        "parts": [("s", "M8 3.5h8V9a4 4 0 0 1-8 0z"), ("s", "M8 5.5H4.5V7A3 3 0 0 0 7.5 10M16 5.5h3.5V7a3 3 0 0 1-3 3"),
                  ("s", "M12 13v3"), ("s", "M9.5 16h5v2.5a1 1 0 0 1-1 1h-3a1 1 0 0 1-1-1z"), ("s", "M7.5 20.5h9")],
    },
    "streaks": {
        "label": "Streaks", "group": "goals",
        "parts": [("s", "M12 2.5c.6 3.4 4.5 5.2 5.5 9.5a5.5 5.5 0 0 1-11 .6c0-2 .8-3.4 1.9-4.6.5 1.3 1.2 2.1 2.2 2.6C10.3 8.2 10.6 5.6 12 2.5z"),
                  ("f", "M12 11.8c1.4 1.4 2.4 2.6 2.4 4.1a2.4 2.4 0 0 1-4.8 0c0-1.5 1-2.7 2.4-4.1z")],
    },
    "profile": {
        "label": "Profile", "group": "application",
        "parts": [("s", "M12 4.5a3.75 3.75 0 1 1 0 7.5 3.75 3.75 0 0 1 0-7.5z"), ("s", "M4.5 20.5a7.5 7.5 0 0 1 15 0")],
    },
    "settings": {
        "label": "Settings", "group": "application",
        "parts": [("s", gear()), ("s", "M12 9.5a2.5 2.5 0 1 1 0 5 2.5 2.5 0 0 1 0-5z")],
    },
    "sync": {
        "label": "Sync", "group": "application",
        "parts": [("s", "M3.5 8h16M15.5 4l4 4-4 4"), ("s", "M20.5 16h-16M8.5 12l-4 4 4 4")],
    },
    "import-export": {
        "label": "Import/Export", "group": "application",
        "parts": [("s", "M17.8 20.5a4.6 4.6 0 0 0 .3-9.2A7 7 0 0 0 4.9 9.9 5.3 5.3 0 0 0 6.3 20.5z"),
                  ("s", "M9.6 17.5v-6M7.2 13.9l2.4-2.4 2.4 2.4M14.4 11.5v6M12 15.1l2.4 2.4 2.4-2.4")],
    },
    # Additions in the same language (not on the reference sheet)
    "home": {
        "label": "Home", "group": "application",
        "parts": [("s", "M3.5 11.5L12 4l8.5 7.5"), ("s", "M5.5 10v8.5a2 2 0 0 0 2 2h9a2 2 0 0 0 2-2V10"), ("s", "M10 20.5v-6h4v6")],
    },
}


def glyph_svg(name, icon, color="currentColor", size=24):
    body = []
    for kind, d in icon["parts"]:
        if kind == "s":
            body.append(f'<path d="{d}"/>')
        else:
            body.append(f'<path fill="{color}" stroke="none" d="{d}"/>')
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="{size}" height="{size}" '
            f'fill="none" stroke="{color}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" '
            f'role="img" aria-label="{icon["label"]}"><title>{icon["label"]}</title>{"".join(body)}</svg>\n')


def tile_svg(name, icon):
    inner = "".join(
        (f'<path d="{d}"/>' if kind == "s" else f'<path fill="{AMBER}" stroke="none" d="{d}"/>')
        for kind, d in icon["parts"])
    return (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128" width="128" height="128" role="img" aria-label="{icon["label"]}">'
            f'<title>{icon["label"]}</title>'
            f'<defs><linearGradient id="tile" x1="0" y1="0" x2="0.6" y2="1"><stop offset="0" stop-color="#2B3A4C"/><stop offset="1" stop-color="#182331"/></linearGradient></defs>'
            f'<rect width="128" height="128" rx="30" fill="url(#tile)"/>'
            f'<rect x="0.75" y="0.75" width="126.5" height="126.5" rx="29.5" fill="none" stroke="#46586D" stroke-opacity="0.5" stroke-width="1.5"/>'
            f'<g transform="translate(28 28) scale(3)" fill="none" stroke="{AMBER}" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">{inner}</g>'
            f'</svg>\n')


manifest = {"grid": 24, "stroke": 2, "caps": "round", "icons": {}}
for name, icon in ICONS.items():
    (GLYPH / f"{name}.svg").write_text(glyph_svg(name, icon))
    (TILE / f"{name}.svg").write_text(tile_svg(name, icon))
    manifest["icons"][name] = {"label": icon["label"], "group": icon["group"],
                               "parts": [{"kind": k, "d": d} for k, d in icon["parts"]]}
(ROOT / "brand" / "icons" / "icons.json").write_text(json.dumps(manifest, indent=2) + "\n")
print(f"wrote {len(ICONS)} icons -> {GLYPH.relative_to(ROOT.parent)}, {TILE.relative_to(ROOT.parent)}")
