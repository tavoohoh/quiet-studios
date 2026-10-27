#!/usr/bin/env python3
"""Writes the card art to the asset catalog as vector SVGs.

    scripts/card-art.py

Same shapes as the "Quiet Solitaire · Diseño" canvas (Card.dc.html, Portrait.dc.html):
- Cards/suit-<s|h|d|c>: suits, template images (tinted in code).
- Cards/emblem-<J|Q|K>: Quiet deck emblems, stroked, template.
- Cards/portrait-<look>-<J|Q|K>-<red|black>: Illustrated and Classic courts, full color.
Pixel art (suits, ranks, courts) is drawn in code from bitmaps (CardArt.swift).
"""
import json
import pathlib
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "App/Resources/Assets.xcassets/Cards"

SUITS = {
    "s": "M12 2.5c-1.8 2.6-8.5 7-8.5 11.3 0 2.6 2 4.4 4.3 4.4 1.4 0 2.6-.6 3.3-1.6-.2 1.9-.9 3.4-2.3 4.9h6.4c-1.4-1.5-2.1-3-2.3-4.9.7 1 1.9 1.6 3.3 1.6 2.3 0 4.3-1.8 4.3-4.4 0-4.3-6.7-8.7-8.5-11.3z",
    "h": "M12 20.5c-.4 0-7.9-4.9-9.4-9.6C1.5 7.6 3.6 4.5 6.8 4.5c2.1 0 3.7 1.2 5.2 3.1 1.5-1.9 3.1-3.1 5.2-3.1 3.2 0 5.3 3.1 4.2 6.4-1.5 4.7-9 9.6-9.4 9.6z",
    "d": "M12 2.8c2.4 3.4 4.9 6.3 7.6 9.2-2.7 2.9-5.2 5.8-7.6 9.2-2.4-3.4-4.9-6.3-7.6-9.2 2.7-2.9 5.2-5.8 7.6-9.2z",
    "c": "M12 3a4.1 4.1 0 0 0-3.7 5.9A4.1 4.1 0 1 0 10.6 16c-.3 1.9-1 3.4-2.3 4.9h7.4c-1.3-1.5-2-3-2.3-4.9a4.1 4.1 0 1 0 2.3-7.1A4.1 4.1 0 0 0 12 3z",
}
EMBLEMS = {
    "K": "M4.5 18h15M5.2 18L4 9.2l4.6 3.4L12 7l3.4 5.6L20 9.2 18.8 18M4 6.3a1.1 1.1 0 1 1 0 2.2 1.1 1.1 0 1 1 0-2.2zM12 4.1a1.1 1.1 0 1 1 0 2.2 1.1 1.1 0 1 1 0-2.2zM20 6.3a1.1 1.1 0 1 1 0 2.2 1.1 1.1 0 1 1 0-2.2z",
    "Q": "M5 18h14M5.6 18L5 10.2c2.2 2 4 1.6 4.8-.9C10.4 7.4 11.1 6.5 12 6.5s1.6.9 2.2 2.8c.8 2.5 2.6 2.9 4.8.9L18.4 18M12 2.6a1.2 1.2 0 1 1 0 2.4 1.2 1.2 0 1 1 0-2.4z",
    "J": "M12 4.5l6.5 2.4v5c0 3.9-2.8 6.3-6.5 7.3-3.7-1-6.5-3.4-6.5-7.3v-5zM12 8.5v7M9 11.5h6",
}
# Robe colors per suit color, per look (Illustrated uses the deck's own red and black).
ROBES = {"illus": {"red": "#D7322A", "black": "#1B1B1B"}, "classic": {"red": "#C8102E", "black": "#111111"}}
ROBE_PATH = {"illus": "M4 40C5 31 11 27 20 27S35 31 36 40Z", "classic": "M5 40V33.5C5 29.5 11 27 20 27s15 2.5 15 6.5V40Z"}


def portrait(look, rank, color):
    robe = ROBES[look][color]
    parts = [f'<path d="{ROBE_PATH[look]}" fill="{robe}"/>',
             '<path d="M15 27.6L20 34l5-6.4c-1.5-.4-3.2-.6-5-.6s-3.5.2-5 .6Z" fill="#FFFFFF"/>',
             '<path d="M11 31.5Q20 37.5 29 31.5" fill="none" stroke="#E3B341" stroke-width="1.4"/>',
             '<rect x="17.5" y="22" width="5" height="6" fill="#EDC29A"/>']
    if rank == "Q":
        parts.append('<path d="M11 17C11 9 15 6 20 6s9 3 9 11l1 11-5-2v-9H15v9l-5 2Z" fill="#8A4B2A"/>')
    parts += ['<ellipse cx="20" cy="17" rx="6" ry="7" fill="#EDC29A"/>',
              '<circle cx="17.6" cy="16.6" r="0.85" fill="#1B1B1B"/>',
              '<circle cx="22.4" cy="16.6" r="0.85" fill="#1B1B1B"/>',
              '<path d="M18.4 20.6Q20 21.8 21.6 20.6" fill="none" stroke="#1B1B1B" stroke-width="0.7" stroke-linecap="round"/>']
    if rank == "K":
        parts += ['<path d="M14.2 18.5c.3 5.5 2.8 8 5.8 8s5.5-2.5 5.8-8c-1.3 2.5-3.3 3.1-5.8 3.1s-4.5-.6-5.8-3.1Z" fill="#DAD2C4"/>',
                  '<path d="M13 12V5l3.3 3L20 3.5 23.7 8 27 5v7Z" fill="#E3B341" stroke="#1B1B1B" stroke-width="0.6" stroke-linejoin="round"/>',
                  f'<circle cx="20" cy="9.6" r="1.1" fill="{robe}"/>']
    if rank == "Q":
        parts += ['<path d="M14 13c1-3.5 3.5-4.5 6-4.5s5 1 6 4.5c-2-1.5-4-2-6-2s-4 .5-6 2Z" fill="#8A4B2A"/>',
                  '<path d="M14.5 10.5l1-4.5L18 8l2-3 2 3 2.5-2 1 4.5Z" fill="#E3B341" stroke="#1B1B1B" stroke-width="0.6" stroke-linejoin="round"/>']
    if rank == "J":
        parts += ['<path d="M14 13v5h1.5v-5ZM24.5 13v5H26v-5Z" fill="#6B4A2E"/>',
                  '<path d="M12.5 12.5C12.5 7 16 5 20.5 5S28 7.5 28 11Z" fill="#3B5BA5"/>',
                  '<path d="M26 7c3-4 6-4 8-5" fill="none" stroke="#E3B341" stroke-width="1.4" stroke-linecap="round"/>']
    return svg("0 0 40 40", "".join(parts))


def svg(view_box, body):
    w, h = view_box.split()[2:]
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="{view_box}">{body}</svg>\n'


def imageset(name, content, template):
    folder = OUT / f"{name}.imageset"
    folder.mkdir(parents=True)
    (folder / f"{name}.svg").write_text(content)
    properties = {"preserves-vector-representation": True}
    if template:
        properties["template-rendering-intent"] = "template"
    contents = {"images": [{"filename": f"{name}.svg", "idiom": "universal"}],
                "info": {"author": "xcode", "version": 1}, "properties": properties}
    (folder / "Contents.json").write_text(json.dumps(contents, indent=2) + "\n")


def main():
    shutil.rmtree(OUT, ignore_errors=True)
    OUT.mkdir(parents=True)
    (OUT / "Contents.json").write_text(json.dumps({"info": {"author": "xcode", "version": 1}, "properties": {"provides-namespace": False}}, indent=2) + "\n")
    for key, d in SUITS.items():
        imageset(f"suit-{key}", svg("0 0 24 24", f'<path d="{d}" fill="#000000"/>'), template=True)
    for rank, d in EMBLEMS.items():
        imageset(f"emblem-{rank}", svg("0 0 24 24", f'<path d="{d}" fill="none" stroke="#000000" stroke-width="1.7" stroke-linejoin="round" stroke-linecap="round"/>'), template=True)
    for look in ROBES:
        for rank in "JQK":
            for color in ("red", "black"):
                imageset(f"portrait-{look}-{rank}-{color}", portrait(look, rank, color), template=False)
    print(f"Card art written to {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
