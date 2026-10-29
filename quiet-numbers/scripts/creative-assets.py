#!/usr/bin/env python3
"""Renders the App Store header (21:9) and search result (3:2) creative assets (iOS 27+).

Sources: `AppStore/creative/{header,search}.<lang>.html`, static copies of the chosen artboards
in the design canvas (page "Header y búsqueda"). Output: `AppStore/creative-assets/<lang>/`,
header 3840×1646 and search 3840×2560, RGB (the App Store rejects alpha). Uses headless Chrome.
"""
import pathlib
import subprocess
import tempfile

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
# Artboard size in CSS px, device scale, and the exact size Apple asks for.
ASSETS = {
    "header": ((1280, 549), 3, (3840, 1646)),
    "search": ((1200, 800), 3.2, (3840, 2560)),
}


def main():
    for source in sorted((ROOT / "AppStore/creative").glob("*.html")):
        name, lang = source.stem.split(".")
        (w, h), scale, size = ASSETS[name]
        with tempfile.TemporaryDirectory() as tmp:
            raw = pathlib.Path(tmp) / "raw.png"
            subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars",
                            f"--force-device-scale-factor={scale}", f"--window-size={w},{h}",
                            "--virtual-time-budget=3000", f"--screenshot={raw}", source.as_uri()],
                           check=True, capture_output=True)
            out = ROOT / "AppStore/creative-assets" / lang / f"{name}.png"
            out.parent.mkdir(parents=True, exist_ok=True)
            image = Image.open(raw).convert("RGB")
            if image.size != size:
                image = image.crop((0, 0, *size)) if image.size[0] >= size[0] and image.size[1] >= size[1] else image.resize(size)
            image.save(out)
            print(out.relative_to(ROOT), image.size)


if __name__ == "__main__":
    main()
