#!/usr/bin/env python3
"""Renders the app icons (standard and Gold; light, dark and tinted) from SVG with headless Chrome.

    scripts/render-icon.py

Two cards, the front one with the studio's pause mark, like the Home mock in the canvas.
"""
import json
import pathlib
import subprocess
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
ASSETS = ROOT / "App/Resources/Assets.xcassets"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# name → (background, back card, front card, pause bars)
VARIANTS = {
    "light": ("#0E6B78", "#5BC2CF", "#FFFFFF", "#0E6B78"),
    "dark": ("#0F1A1D", "#1D5961", "#E8F1F2", "#0E6B78"),
    "tinted": ("#000000", "#4A4A4A", "#D8D8D8", "#000000"),
}
GOLD = {
    "light": ("#9A7628", "#E3C27A", "#FFFBF0", "#9A7628"),
    "dark": ("#1E1A12", "#7D6224", "#F5E9CC", "#9A7628"),
    "tinted": VARIANTS["tinted"],
}


def svg(background, back, front, bars):
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<rect width="1024" height="1024" fill="{background}"/>
<g transform="rotate(-12 420 500)"><rect x="232" y="232" width="384" height="540" rx="56" fill="{back}"/></g>
<g transform="rotate(7 600 540)">
<rect x="400" y="272" width="384" height="540" rx="56" fill="{front}"/>
<rect x="545" y="460" width="34" height="164" rx="17" fill="{bars}"/>
<rect x="605" y="460" width="34" height="164" rx="17" fill="{bars}"/>
</g></svg>"""


def render(content, out):
    with tempfile.TemporaryDirectory() as tmp:
        page = pathlib.Path(tmp) / "icon.html"
        page.write_text(f'<html><body style="margin:0">{content}</body></html>')
        subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--window-size=1024,1024",
                        f"--screenshot={out}", page.as_uri()], check=True, capture_output=True)
    # Opaque PNG (the App Store rejects alpha).
    subprocess.run(["sips", "-s", "format", "jpeg", str(out), "--out", str(out) + ".jpg"], check=True, capture_output=True)
    subprocess.run(["sips", "-s", "format", "png", str(out) + ".jpg", "--out", str(out)], check=True, capture_output=True)
    pathlib.Path(str(out) + ".jpg").unlink()


def iconset(name, variants):
    folder = ASSETS / f"{name}.appiconset"
    folder.mkdir(parents=True, exist_ok=True)
    images = []
    for mode, colors in variants.items():
        filename = "icon-1024.png" if mode == "light" else f"icon-1024-{mode}.png"
        render(svg(*colors), folder / filename)
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
