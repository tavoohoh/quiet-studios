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

# name → (background, back card, front card, heart). From Quiet Numbers' icon: background,
# its light teal (#5BC2CF, the dark icon's nodes) on the back card, its coral line (#FF9A85)
# on the heart. Two changes, because the heart sits on a white card, not on the background:
# - tinted: Numbers' line gray (#D0D0D0) barely shows on white at 60 px → #A6A6A6;
# - gold: its cream line (#FFE2A8) disappears on the card → a darker gold, #C98F2E (between
#   Numbers' #E8B04A and its #A8741A background), on the gold back card #E8B04A.
VARIANTS = {
    "light": ("#0E6B78", "#5BC2CF", "#FFFFFF", "#FF9A85"),
    "dark": ("#0B1517", "#5BC2CF", "#E8F1F2", "#FF9A85"),
    "tinted": (None, "#7A7A7A", "#FFFFFF", "#A6A6A6"),
}
GOLD = {
    "light": ("#A8741A", "#E8B04A", "#FFFFFF", "#C98F2E"),
    "dark": ("#1A1408", "#E8B04A", "#F5E9CC", "#C98F2E"),
    "tinted": VARIANTS["tinted"],
}

HEART = re.search(r'd="([^"]+)"', (ASSETS / "Cards/suit-h.imageset/suit-h.svg").read_text()).group(1)
# The glyph's 24-point box: the heart spans x 1.5–22.5 and y 4.5–20.5, centered on (12, 12.5).
HEART_WIDTH = 230
HEART_SCALE = HEART_WIDTH / 21
CARD_CENTER = (592, 542)


def svg(background, back, front, heart):
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
