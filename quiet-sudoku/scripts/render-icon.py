#!/usr/bin/env python3
"""Renders the app icons (standard and Gold; light, dark and tinted) from SVG with AppKit
(scripts/render-svg.swift, like Quiet Solitaire). Light and dark are opaque; tinted keeps a
transparent background, which iOS tints.

    scripts/render-icon.py

A 3×3 box of rounded tiles (2026-10-30): eight in the light tile color and one in the accent,
the digit the player is about to find. Colors from Quiet Solitaire's icon (and so Quiet
Numbers'): background, light teal (#5BC2CF) and coral (#FF9A85).
"""
import json
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "App/Resources/Assets.xcassets"

# name → (background, tiles, the found tile).
VARIANTS = {
    "light": ("#0E6B78", "#FFFFFF", "#FF9A85"),
    "dark": ("#0B1517", "#5BC2CF", "#FF9A85"),
    "tinted": (None, "#FFFFFF", "#A6A6A6"),
}
GOLD = {
    "light": ("#A8741A", "#FFFFFF", "#E8B04A"),
    "dark": ("#1A1408", "#E8B04A", "#F5E9CC"),
    "tinted": VARIANTS["tinted"],
}

TILE = 196
GAP = 44
FOUND = (2, 0)  # row, column of the accent tile


def svg(background, tile, found):
    rect = f'<rect width="1024" height="1024" fill="{background}"/>' if background else ""
    start = (1024 - (3 * TILE + 2 * GAP)) / 2
    tiles = []
    for row in range(3):
        for column in range(3):
            x, y = start + column * (TILE + GAP), start + row * (TILE + GAP)
            fill = found if (row, column) == FOUND else tile
            tiles.append(f'<rect x="{x:.0f}" y="{y:.0f}" width="{TILE}" height="{TILE}" rx="44" fill="{fill}"/>')
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
{rect}
{''.join(tiles)}
</svg>"""


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
