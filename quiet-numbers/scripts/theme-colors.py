#!/usr/bin/env python3
"""Writes the theme colors to the asset catalog and checks their contrast (WCAG).

    scripts/theme-colors.py

Values come from the design brief (canvas "Quiet Numbers · Diseño", page 6). Teal & Coral
has light and dark variants and follows the system; every other theme has a single mode.
Exits with an error if a text color falls under 4.5:1 on the surfaces it's used on.
"""
import json
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "App/Resources/Assets.xcassets"

ROLES = ["background", "surface", "surface2", "ink", "muted", "primary", "onPrimary", "accent", "ghost", "separator"]

# Asset name prefix → role → (light, dark). Single-mode themes give one value.
THEMES = {
    "TealCoral": {
        "background": ("#F3F7F8", "#0F1A1D"),
        "surface": ("#FFFFFF", "#172629"),
        "surface2": ("#E3EEF0", "#1F3236"),
        "ink": ("#16201F", "#E8F1F2"),
        "muted": ("#5E6F72", "#8A9DA0"),
        "primary": ("#0E6B78", "#5BC2CF"),
        "onPrimary": ("#FFFFFF", "#062327"),
        "accent": ("#B9472F", "#FF9A85"),
        "ghost": ("#CFD8DA", "#2C3A3D"),
        "separator": ("#E3EAEC", "#263A3E"),
    },
    # Light only.
    "SageSand": {
        "background": "#F6F4EE", "surface": "#FFFFFF", "surface2": "#ECE9E0", "ink": "#1F2622",
        "muted": "#5F665F", "primary": "#387454",  # brief: #3E7A5A (4.18:1 on surface2)
        "onPrimary": "#FFFFFF", "accent": "#9A5B16",
        "ghost": "#D5D3CB", "separator": "#E6E2D8",
    },
    # Dark only.
    "IndigoPeach": {
        "background": "#13121F", "surface": "#1C1B2C", "surface2": "#27253A", "ink": "#ECEBF7",
        "muted": "#9593AE", "primary": "#9A98FF", "onPrimary": "#15133A", "accent": "#FFAE82",
        "ghost": "#302E44", "separator": "#2A2840",
    },
    # Light only.
    "SageCoral": {
        "background": "#F7F3EC", "surface": "#FFFFFF", "surface2": "#EFEAE0",  # brief: #EDE7DC (4.47:1)
        "ink": "#1E2420",
        "muted": "#646A64", "primary": "#4D7157", "onPrimary": "#FFFFFF", "accent": "#B4503A",
        "ghost": "#D9D4CA", "separator": "#E8E2D6",
    },
    # Light only. Surfaces also get a 2 pt black border (in code).
    "HighContrast": {
        "background": "#FFFFFF", "surface": "#FFFFFF", "surface2": "#E6EEF9", "ink": "#000000",
        "muted": "#3A3A3C", "primary": "#003F91", "onPrimary": "#FFFFFF", "accent": "#B85500",
        "ghost": "#B0B0B5", "separator": "#000000",
    },
}

# Text roles and the backgrounds they sit on.
TEXT_ON = {
    "ink": ["background", "surface", "surface2"],
    "muted": ["background", "surface"],
    "primary": ["background", "surface", "surface2"],
    "accent": ["background", "surface"],
    "onPrimary": ["primary"],
}


def components(hex_color):
    value = hex_color.lstrip("#")
    return [int(value[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def luminance(hex_color):
    def channel(c):
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = map(channel, components(hex_color))
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    la, lb = sorted([luminance(a), luminance(b)], reverse=True)
    return (la + 0.05) / (lb + 0.05)


def colorset(light, dark=None):
    def entry(hex_color, appearance=None):
        r, g, b = components(hex_color)
        item = {
            "color": {"color-space": "srgb", "components": {
                "alpha": "1.000", "red": f"{r:.3f}", "green": f"{g:.3f}", "blue": f"{b:.3f}"}},
            "idiom": "universal",
        }
        if appearance:
            item["appearances"] = [{"appearance": "luminosity", "value": appearance}]
        return item
    colors = [entry(light)] + ([entry(dark, "dark")] if dark else [])
    return {"colors": colors, "info": {"author": "xcode", "version": 1}}


def write(name, value, folder=ASSETS / "Themes"):
    path = folder / f"{name}.colorset"
    path.mkdir(parents=True, exist_ok=True)
    (path / "Contents.json").write_text(json.dumps(value, indent=2) + "\n")


def main():
    problems = []
    folder = ASSETS / "Themes"
    shutil.rmtree(folder, ignore_errors=True)
    folder.mkdir()
    (folder / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}}, indent=2) + "\n")

    for theme, roles in THEMES.items():
        assert set(roles) == set(ROLES), theme
        modes = {"light": {}, "dark": {}}
        for role, value in roles.items():
            light, dark = value if isinstance(value, tuple) else (value, None)
            write(theme + role[0].upper() + role[1:], colorset(light, dark))
            modes["light"][role] = light
            if dark:
                modes["dark"][role] = dark
        for mode, colors in modes.items():
            for text, backgrounds in TEXT_ON.items():
                for background in backgrounds:
                    if text in colors and background in colors:
                        ratio = contrast(colors[text], colors[background])
                        if ratio < 4.5:
                            problems.append(f"{theme} {mode}: {text} on {background} is {ratio:.2f}:1")

    # The app-wide tint and the launch screen follow the default theme.
    teal = THEMES["TealCoral"]
    write("AccentColor", colorset(*teal["primary"]), ASSETS)
    write("LaunchBackground", colorset(*teal["background"]), ASSETS)

    for problem in problems:
        print(problem)
    if problems:
        sys.exit(1)
    print("Theme colors written; all text pairs pass 4.5:1.")


if __name__ == "__main__":
    main()
