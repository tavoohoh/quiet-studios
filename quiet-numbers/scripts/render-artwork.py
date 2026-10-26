#!/usr/bin/env python3
"""Renders the app icons, the splash lockup and the Game Center badges from SVG.

    scripts/render-artwork.py

The SVGs below are the source of truth (canvas "Quiet Numbers · Diseño", pages 2 and 4).
PNGs go to the asset catalog and AppStore/achievements/. Rendering uses AppKit via
scripts/render-svg.swift, so it only needs macOS and Xcode's Swift.
"""
import json
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "App/Resources/Assets.xcassets"
RENDERER = ROOT / "scripts/render-svg.swift"

# MARK: App icon ("Long shot": a 3×3 grid, two numbers joined across the board)

FAINT_DOTS = [(50, 26), (74, 26), (26, 50), (74, 50), (26, 74), (50, 74)]


def icon(background, faint, line, solid):
    """100-unit grid. `background` None leaves it transparent (tinted variant)."""
    rect = f'<rect width="100" height="100" fill="{background}"/>' if background else ""
    dots = "".join(f'<circle cx="{x}" cy="{y}" r="5.5"/>' for x, y in FAINT_DOTS)
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">'
        f'{rect}<g fill="{faint}" fill-opacity="0.35">{dots}</g>'
        f'<line x1="26" y1="26" x2="74" y2="74" stroke="{line}" stroke-width="8" stroke-linecap="round"/>'
        f'<circle cx="26" cy="26" r="10" fill="{solid}"/><circle cx="74" cy="74" r="10" fill="{solid}"/>'
        "</svg>"
    )


ICONS = {
    "AppIcon": {
        "light": icon("#0E6B78", "#FFFFFF", "#FF9A85", "#FFFFFF"),
        "dark": icon("#0B1517", "#5BC2CF", "#FF9A85", "#5BC2CF"),
        "tinted": icon(None, "#FFFFFF", "#D0D0D0", "#FFFFFF"),
    },
    # Alternate icon, unlocked by Centennial.
    "AppIcon-Gold": {
        "light": icon("#A8741A", "#FFFFFF", "#FFE2A8", "#FFFFFF"),
        "dark": icon("#1A1408", "#E8B04A", "#FFE2A8", "#E8B04A"),
        "tinted": icon(None, "#FFFFFF", "#D0D0D0", "#FFFFFF"),
    },
}

# MARK: Splash lockup ("Q en pausa" + "quiet studios"), same image in the launch screen

LOCKUP_SIZE = (240, 136)  # points


def lockup(ring, bar, text):
    # Symbol on a 48 grid drawn at 80 pt, 18 pt above 30 pt SF Pro Rounded Heavy.
    scale = 80 / 48
    x = (LOCKUP_SIZE[0] - 80) / 2
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{LOCKUP_SIZE[0]}" height="{LOCKUP_SIZE[1]}" '
        f'viewBox="0 0 {LOCKUP_SIZE[0]} {LOCKUP_SIZE[1]}">'
        f'<g transform="translate({x} 0) scale({scale})">'
        f'<circle cx="21" cy="22" r="14" fill="none" stroke="{ring}" stroke-width="5"/>'
        f'<line x1="31" y1="38" x2="43" y2="38" stroke="{bar}" stroke-width="5" stroke-linecap="round"/></g>'
        f'<text x="{LOCKUP_SIZE[0] / 2}" y="122" text-anchor="middle" font-family="SF Pro Rounded" '
        f'font-weight="800" font-size="30" letter-spacing="-0.3" fill="{text}">quiet studios</text>'
        "</svg>"
    )


LOCKUPS = {
    "light": lockup("#0E6B78", "#B9472F", "#16201F"),
    "dark": lockup("#5BC2CF", "#FF9A85", "#E8F1F2"),
}

# MARK: Game Center badges (a square of the badge color; Game Center crops it round)

TEAL, NIGHT, GOLD, CORAL = "#0E6B78", "#0F1A1D", "#A8741A", "#B9472F"
WHITE, NIGHT_INK = "#FFFFFF", "#5BC2CF"


def circle(cx, cy, r):
    return f"M{cx - r} {cy} a{r} {r} 0 1 0 {2 * r} 0 a{r} {r} 0 1 0 {-2 * r} 0"


def line(d, ink, width=4.5, dash=None):
    dash = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<path d="{d}" fill="none" stroke="{ink}" stroke-width="{width}"{dash} '
            'stroke-linecap="round" stroke-linejoin="round"/>')


def dot(d, ink):
    return f'<path d="{d}" fill="{ink}"/>'


def calendar(ink):
    return [
        line("M34 32 H66 a4 4 0 0 1 4 4 V68 a4 4 0 0 1 -4 4 H34 a4 4 0 0 1 -4 -4 V36 a4 4 0 0 1 4 -4 Z", ink),
        line("M30 44 H70", ink, 3.5),
        line("M41 27 V36 M59 27 V36", ink),
    ]


BADGES = {
    "first_step": (TEAL, WHITE, [line("M26 70 H42 V57 H57 V44 H74", WHITE), dot(circle(34, 61, 4.5), WHITE)]),
    "clean_slate": (TEAL, WHITE, [line("M35 30 H65 a5 5 0 0 1 5 5 V65 a5 5 0 0 1 -5 5 H35 a5 5 0 0 1 -5 -5 V35 a5 5 0 0 1 5 -5 Z", WHITE, dash="7 7")]),
    "no_help": (TEAL, WHITE, [line(circle(50, 44, 14), WHITE), line("M44 64 H56 M45.5 71 H54.5", WHITE), line("M31 28 L69 74", WHITE)]),
    "consistency": (TEAL, WHITE, calendar(WHITE) + [dot(" ".join(
        [circle(x, 54, 2.8) for x in (38, 46, 54, 62)] + [circle(x, 63, 2.8) for x in (38, 46, 54)]), WHITE)]),
    "habit": (TEAL, WHITE, calendar(WHITE) + [line("M40 57 L47 64 L61 50", WHITE)]),
    "sweeper": (TEAL, WHITE, [line("M26 41 H60 a8 8 0 1 0 -8 -8", WHITE), line("M26 52 H72", WHITE), line("M26 63 H54 a8 8 0 1 1 -8 8", WHITE)]),
    "stage_five": (TEAL, WHITE, [line("M62 29 H43 L40 48 C47 43 64 44 64 58 C64 72 47 76 38 68", WHITE, 6)]),
    "centennial": (GOLD, WHITE, [line(circle(50, 42, 14), WHITE), dot(circle(50, 42, 5), WHITE), line("M43 55 L37 75 L45 70 L50 77 L55 70 L63 75 L57 55", WHITE)]),
    "night_owl": (NIGHT, NIGHT_INK, [line("M60 28 a22 22 0 1 0 14 38 a17 17 0 1 1 -14 -38 Z", NIGHT_INK), line("M32 30 V40 M27 35 H37", NIGHT_INK, 3.5), line("M30 56 V62 M27 59 H33", NIGHT_INK, 3)]),
    "monotone": (NIGHT, NIGHT_INK, [line("M31 42 H69 M31 58 H69", NIGHT_INK, 7)]),
    "in_the_red": (CORAL, WHITE, [line("M30 50 H70", WHITE, 8)]),
}


def badge(background, ink, paths):
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">'
        f'<rect width="100" height="100" fill="{background}"/>'
        f'<circle cx="50" cy="50" r="41" fill="none" stroke="{ink}" stroke-opacity="0.3" stroke-width="1.5"/>'
        + "".join(paths) + "</svg>"
    )


# MARK: Output


def render(svg, out, width, height, opaque, tmp):
    source = pathlib.Path(tmp) / (out.stem + ".svg")
    source.write_text(svg)
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["swift", str(RENDERER), str(source), str(out), str(width), str(height),
                    "opaque" if opaque else "alpha"], check=True)


def write_json(path, value):
    path.write_text(json.dumps(value, indent=2) + "\n")


def main():
    info = {"author": "xcode", "version": 1}
    with tempfile.TemporaryDirectory() as tmp:
        for name, variants in ICONS.items():
            folder = ASSETS / f"{name}.appiconset"
            images = []
            for variant, svg in variants.items():
                filename = "icon-1024.png" if variant == "light" else f"icon-1024-{variant}.png"
                # The primary icon can't have alpha; dark is opaque too, tinted needs it.
                render(svg, folder / filename, 1024, 1024, variant != "tinted", tmp)
                image = {"filename": filename, "idiom": "universal", "platform": "ios", "size": "1024x1024"}
                if variant != "light":
                    image["appearances"] = [{"appearance": "luminosity", "value": variant}]
                images.append(image)
            write_json(folder / "Contents.json", {"images": images, "info": info})

        # The icon as an image for Home (clipped to a rounded square in SwiftUI).
        folder = ASSETS / "HomeIcon.imageset"
        images = []
        for variant in ("light", "dark"):
            filename = f"home-icon-{variant}.png"
            render(ICONS["AppIcon"][variant], folder / filename, 256, 256, True, tmp)
            image = {"filename": filename, "idiom": "universal"}
            if variant == "dark":
                image["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
            images.append(image)
        write_json(folder / "Contents.json", {"images": images, "info": info})

        folder = ASSETS / "SplashLockup.imageset"
        images = []
        for variant, svg in LOCKUPS.items():
            for scale in (2, 3):
                filename = f"lockup-{variant}@{scale}x.png"
                render(svg, folder / filename, LOCKUP_SIZE[0] * scale, LOCKUP_SIZE[1] * scale, False, tmp)
                image = {"filename": filename, "idiom": "universal", "scale": f"{scale}x"}
                if variant == "dark":
                    image["appearances"] = [{"appearance": "luminosity", "value": "dark"}]
                images.append(image)
        write_json(folder / "Contents.json", {"images": images, "info": info})

        for identifier, (background, ink, paths) in BADGES.items():
            render(badge(background, ink, paths), ROOT / f"AppStore/achievements/{identifier}.png", 1024, 1024, True, tmp)


if __name__ == "__main__":
    main()
