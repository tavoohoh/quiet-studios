#!/usr/bin/env python3
"""Renders the app icons (standard and Gold; light, dark and tinted) from SVG with AppKit
(scripts/render-svg.swift, like Quiet Numbers). Light and dark are opaque; tinted keeps a
transparent background, which iOS tints.

    scripts/render-icon.py

Two cards, the front one with a heart (2026-10-30; it had the studio's pause mark). Colors
follow Quiet Numbers' icon (scripts/render-artwork.py there): the heart plays the part of its
coral line, the accent. The heart is the deck's own glyph (Assets.xcassets/Cards/suit-h.svg,
written by scripts/card-art.py).
"""
import json
import pathlib
import re
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "App/Resources/Assets.xcassets"

# name → (background, back card, front card, heart). From Quiet Numbers' icon (scripts/
# render-artwork.py there), palette "A2" since 2026-11-02: vivid teal gradient #19BFCD → #0A8AA5
# (dark: #03171B), the dark icon's nodes (#2FD6E4) on the back card, its coral line (#FF9277)
# on the heart. Only the icon and the store art; the app's themes don't change. Because the
# heart sits on a white card, not on the background:
# - tinted: Numbers' line gray (#D0D0D0) barely shows on white at 60 px → #A6A6A6;
# - gold: the heart stays coral, like the standard icon (the user's call, 2026-11-02), with a
#   pale gold back card (#F7D27E; dark: #F0BC4E).
VARIANTS = {
    "light": (("#19BFCD", "#0A8AA5"), "#2FD6E4", "#FFFFFF", "#FF9277"),
    "dark": ("#03171B", "#2FD6E4", "#E8F1F2", "#FF9277"),
    "tinted": (None, "#7A7A7A", "#FFFFFF", "#A6A6A6"),
}
GOLD = {
    "light": (("#E3B043", "#B27A17"), "#F7D27E", "#FFFFFF", "#FF9277"),
    "dark": ("#1A1408", "#F0BC4E", "#F5E9CC", "#FF9277"),
    "tinted": VARIANTS["tinted"],
}

HEART = re.search(r'd="([^"]+)"', (ASSETS / "Cards/suit-h.imageset/suit-h.svg").read_text()).group(1)
# The glyph's 24-point box: the heart spans x 1.5–22.5 and y 4.5–20.5, centered on (12, 12.5).
HEART_WIDTH = 230
HEART_SCALE = HEART_WIDTH / 21
CARD_CENTER = (592, 542)


def svg(background, back, front, heart):
    """`background` None leaves it transparent (tinted); a (top, bottom) pair is a vertical
    gradient, as in Quiet Numbers."""
    if isinstance(background, tuple):
        rect = ('<defs><linearGradient id="bg" x1="0" y1="0" x2="0" y2="1">'
                f'<stop offset="0" stop-color="{background[0]}"/><stop offset="1" stop-color="{background[1]}"/>'
                '</linearGradient></defs><rect width="1024" height="1024" fill="url(#bg)"/>')
    else:
        rect = f'<rect width="1024" height="1024" fill="{background}"/>' if background else ""
    tx, ty = CARD_CENTER[0] - 12 * HEART_SCALE, CARD_CENTER[1] - 12.5 * HEART_SCALE
    glyph = f'<path d="{HEART}" fill="{heart}" transform="translate({tx:.1f} {ty:.1f}) scale({HEART_SCALE:.4f})"/>'
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
{rect}
<g transform="rotate(-12 420 500)"><rect x="232" y="232" width="384" height="540" rx="56" fill="{back}"/></g>
<g transform="rotate(7 600 540)">
<rect x="400" y="272" width="384" height="540" rx="56" fill="{front}"/>
{glyph}
</g></svg>"""


def render(content, out, opaque):
    with tempfile.TemporaryDirectory() as tmp:
        source = pathlib.Path(tmp) / "icon.svg"
        source.write_text(content)
        subprocess.run(["swift", str(ROOT / "scripts/render-svg.swift"), str(source), str(out), "1024", "1024",
                        "opaque" if opaque else "alpha"], check=True)


def iconset(name, variants):
    folder = ASSETS / f"{name}.appiconset"
    folder.mkdir(parents=True, exist_ok=True)
    images = []
    for mode, colors in variants.items():
        filename = "icon-1024.png" if mode == "light" else f"icon-1024-{mode}.png"
        render(svg(*colors), folder / filename, opaque=mode != "tinted")
        image = {"filename": filename, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
        if mode != "light":
            image["appearances"] = [{"appearance": "luminosity", "value": mode}]
        images.append(image)
    (folder / "Contents.json").write_text(json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")


def main():
    iconset("AppIcon", VARIANTS)
    iconset("AppIcon-Gold", GOLD)
    # Home shows the standard icon.
    home = ASSETS / "HomeIcon.imageset"
    home.mkdir(exist_ok=True)
    (home / "icon.png").write_bytes((ASSETS / "AppIcon.appiconset/icon-1024.png").read_bytes())
    (home / "Contents.json").write_text(json.dumps({"images": [{"filename": "icon.png", "idiom": "universal"}], "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")
    print("Icons written.")


if __name__ == "__main__":
    main()
