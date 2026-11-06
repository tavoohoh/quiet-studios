#!/usr/bin/env python3
"""Renders the App Store header (21:9) and search result (3:2) creative assets (iOS 27+).

Sources: `AppStore/creative/{header,search}.<lang>.html`, the options chosen on 2026-11-05 (header
B, search A; the search phone is `AppStore/creative/daily.<lang>.png`, from
`ScreenshotTests.testSearchDaily`). Same script as Quiet Numbers. Output: `AppStore/creative-assets/<lang>/`,
header 3840×1646 and search 3840×2560, RGB (the App Store rejects alpha). Uses headless Chrome.
Background, title and subtitle come from AppStore/store-style.json (store editor), set as CSS
variables in each page's head.
"""
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT.parent / "studio/store-editor"))
import store_style  # noqa: E402

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
# Artboard size in CSS px, device scale, and the exact size Apple asks for.
ASSETS = {
    "header": ((1280, 549), 3, (3840, 1646)),
    "search": ((1200, 800), 3.2, (3840, 2560)),
}


def main():
    style = store_style.load(ROOT)
    for source in sorted((ROOT / "AppStore/creative").glob("*.html")):
        name, lang = source.stem.split(".")
        (w, h), scale, size = ASSETS[name]
        with tempfile.TemporaryDirectory() as tmp:
            raw = pathlib.Path(tmp) / "raw.png"
            page = pathlib.Path(tmp) / "page.html"
            head = f'<base href="{source.parent.as_uri()}/">' + store_style.head(style, name)
            page.write_text(source.read_text().replace("</head>", head + "\n</head>", 1))
            subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                            f"--force-device-scale-factor={scale}", f"--window-size={w},{h}",
                            "--virtual-time-budget=3000", f"--screenshot={raw}", page.as_uri()],
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
