#!/usr/bin/env python3
"""Composes the App Store images: a colored frame with a headline around a real screenshot
of the app, in the style of Quiet Solitaire's and Quiet Numbers' images.

    scripts/screenshots.sh            # first: real screenshots (-demo state)
    scripts/store-images.py           # then: AppStore/store-images/<device>/<en|es>/NN-name.png

Rendered with Chrome headless: iPhone 6.9" at 1320×2868 (scaled to 6.3", 1206×2622, the
size App Store Connect asks for first) and iPad 13" at 2064×2752, no alpha.
"""
import pathlib
import subprocess
import tempfile

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS = ROOT / "AppStore/screenshots"
OUT = ROOT / "AppStore/store-images"
IPHONE_63 = (1206, 2622)
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

DEVICES = {
    "iphone-6.9": dict(size=(440, 956), scale=3, phone_left=50, phone_width=340, bezel=8, radius=52,
                       inner_radius=44, text_scale=1, pad=(60, 36), callout_scale=1),
    "ipad-13": dict(size=(1032, 1376), scale=2, phone_left=136, phone_width=760, bezel=14, radius=48,
                    inner_radius=34, text_scale=1.55, pad=(84, 72), callout_scale=1.6),
}

# Quiet Studios' free-collection copy (2026-11-05): say why the game exists, never sell
# "free" or "no ads" as an offer.
# Title in two lines (white, then peach) and a subtitle broken at its punctuation, never
# leaving a word alone (quiet-release, "Composición de header, búsqueda y capturas").
TEXT = {
    "en": {
        1: ("Classic<br><span>sudoku.</span>", "One solution, no guessing."),
        2: ("A new challenge<br><span>every day.</span>", "Easy on Monday,<br>expert on Sunday."),
        3: ("Play with<br><span>your friends.</span>", "Same sudoku,<br>see who's faster."),
        4: ("Earned<br><span>by playing.</span>", "Themes, number styles<br>and more."),
        5: ("Solve fast,<br><span>score double.</span>", ""),
    },
    "es": {
        1: ("Sudoku<br><span>clásico.</span>", "Una solución, sin adivinar."),
        2: ("Un reto nuevo<br><span>cada día.</span>", "Fácil el lunes,<br>experto el domingo."),
        3: ("Juega con<br><span>tus amigos.</span>", "El mismo sudoku, a ver<br>quién va más rápido."),
        4: ("Todo se gana<br><span>jugando.</span>", "Temas, estilos de números<br>y más."),
        5: ("Resuelve rápido,<br><span>suma el doble.</span>", ""),
    },
}

CALLOUT_TEXT = {
    "en": {"streak": "9-day streak", "double": "×2"},
    "es": {"streak": "Racha de 9 días", "double": "×2"},
}

ICON = {
    "flame": '<svg viewBox="0 0 24 24"><path d="M12 2c1 4 5 6 5 11a5 5 0 0 1-10 0c0-2 1-3.5 2-4.5 0 2 1 3 2 3 0-3-1-6 1-9.5z" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"/></svg>',
    "check": '<svg viewBox="0 0 24 24"><path d="M5 12.5l4.5 4.5L19 7.5" fill="none" stroke="currentColor" stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "timer": '<svg viewBox="0 0 24 24"><circle cx="12" cy="13.5" r="8" fill="none" stroke="currentColor" stroke-width="2.2"/><path d="M12 9.5v4l2.6 1.8M9.5 2.5h5" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>',
}

# Callouts: (style, content, anchor), anchored to the phone's top-right corner in canvas
# iPhone coordinates (the phone's right edge is x 390, its top is `phone_top`).
FRAMES = {
    1: dict(name="01-classic", shot="01-game", appearance="light", bg="linear-gradient(180deg, #19BFCD, #0A8AA5)", ink="#FFFFFF", span="#FFD3C6", em="#FFD3C6", sub="rgba(255,255,255,0.92)", h1=50, phone_top=330, bezel_color="#0A1416",
            shadow="0 30px 70px rgba(2,40,48,0.4)", callouts=[]),
    2: dict(name="02-daily", shot="02-daily", appearance="light", bg="linear-gradient(180deg, #19BFCD, #0A8AA5)", ink="#FFFFFF", span="#FFD3C6", em="#FFD3C6", sub="rgba(255,255,255,0.92)", h1=46, phone_top=330, bezel_color="#0A1416",
            shadow="0 30px 70px rgba(2,40,48,0.4)",
            callouts=[("pill coral small", f'<i class="icon">{ICON["flame"]}</i>{{streak}}', (404, 312))]),
    3: dict(name="03-friends", shot="03-leaderboards", appearance="dark", bg="linear-gradient(180deg, #19BFCD, #0A8AA5)", ink="#FFFFFF", span="#FFD3C6", em="#FFD3C6", sub="rgba(255,255,255,0.92)", h1=50, phone_top=330,
            bezel_color="#000000", shadow="0 30px 70px rgba(2,40,48,0.4)", callouts=[]),
    4: dict(name="04-rewards", shot="04-collection", appearance="dark", bg="linear-gradient(180deg, #19BFCD, #0A8AA5)", ink="#FFFFFF", span="#FFD3C6", em="#FFD3C6", sub="rgba(255,255,255,0.92)", h1=50, phone_top=330, bezel_color="#000000",
            shadow="0 30px 70px rgba(2,40,48,0.4)", callouts=[]),
    5: dict(name="05-win", shot="05-win", appearance="light", bg="linear-gradient(180deg, #19BFCD, #0A8AA5)", ink="#FFFFFF", span="#FFD3C6", em="#FFD3C6", sub="rgba(255,255,255,0.92)", h1=50, phone_top=330, bezel_color="#0A1416",
            shadow="0 30px 70px rgba(2,40,48,0.4)",
            callouts=[("card", f'<i class="icon" style="color:#0E6B78">{ICON["timer"]}</i><b style="font-size:30px;color:#0E6B78">{{double}}</b>', (404, 312))]),
}

CSS = """
@font-face { font-family: "QRounded"; src: url("file:///System/Library/Fonts/SFNSRounded.ttf"); font-weight: 1 1000; }
* { box-sizing: border-box; }
html, body { margin: 0; }
body { width: %(w)spx; height: %(h)spx; position: relative; overflow: hidden; background: %(bg)s; color: %(ink)s;
       font-family: "QRounded", system-ui, sans-serif; }
header { position: absolute; left: 0; right: 0; top: 0; padding: %(pad_top)spx %(pad_x)spx 0; display: flex; flex-direction: column; gap: %(gap)spx; }
h1 { margin: 0; font-size: %(h1)spx; line-height: 1.02; font-weight: 900; letter-spacing: -0.015em; white-space: nowrap; }
h1 span { color: %(span)s; } h1 em { font-style: normal; color: %(em)s; }
header p { margin: 0; font-size: %(sub_size)spx; line-height: 1.3; font-weight: 700; white-space: nowrap; color: %(sub)s; }
.phone { position: absolute; left: %(phone_left)spx; top: %(phone_top)spx; width: %(phone_width)spx; padding: %(bezel)spx;
         border-radius: %(radius)spx; background: %(bezel_color)s; box-shadow: %(shadow)s; }
.phone img { display: block; width: 100%%; border-radius: %(inner_radius)spx; }
.overlay { position: absolute; left: 0; top: 0; width: %(w)spx; height: %(h)spx; overflow: visible; }
.callout { position: absolute; display: flex; align-items: center; gap: 8px; font-weight: 900; white-space: nowrap; }
.callout .icon { display: flex; width: 20px; height: 20px; } .callout .icon svg { width: 100%%; height: 100%%; }
.pill { padding: 10px 16px; border-radius: 999px; font-size: 18px; box-shadow: 0 12px 28px rgba(0,0,0,0.45); }
.pill.coral { padding: 11px 18px; font-size: 22px; background: #B9472F; color: #FFFFFF; box-shadow: 0 14px 30px rgba(90,25,10,0.4); }
.pill.coral.small { padding: 10px 18px; font-size: 20px; box-shadow: 0 12px 28px rgba(120,40,20,0.3); }
.pill.teal { background: #5BC2CF; color: #062327; }
.card { gap: 10px; padding: 12px 18px; border-radius: 22px; background: #FFFFFF; color: #16201F; box-shadow: 0 14px 30px rgba(2,30,36,0.35); }
.card .icon { width: 26px; height: 26px; }
.card.best { flex-direction: column; align-items: flex-end; gap: 2px; padding: 10px 18px; box-shadow: 0 12px 28px rgba(120,50,30,0.25); }
.card.best small { font-size: 13px; font-weight: 800; letter-spacing: 0.06em; text-transform: uppercase; color: #4A5B5E; }
.card.best b { font-size: 28px; color: #0E6B78; }
.praise { flex-direction: column; gap: 0; padding: 12px 22px; border-radius: 26px; box-shadow: 0 14px 32px rgba(0,0,0,0.5); }
.praise b { font-size: 30px; line-height: 1; } .praise small { font-size: 16px; font-weight: 800; }
.praise.peach { background: #FF9A85; color: #2A0E06; }
.praise.coral { background: #B9472F; color: #FFFFFF; box-shadow: 0 14px 32px rgba(90,25,10,0.4); }
"""

FIT = """
<script>
for (const h1 of document.querySelectorAll('h1, header p')) {
  const max = h1.parentElement.clientWidth - 2 * parseFloat(getComputedStyle(h1.parentElement).paddingLeft);
  let size = parseFloat(getComputedStyle(h1).fontSize);
  while (h1.scrollWidth > max && size > 20) { size -= 1; h1.style.fontSize = size + 'px'; }
}
</script>
"""



def build(device, language, number):
    spec, frame = DEVICES[device], FRAMES[number]
    w, h = spec["size"]
    k = spec["text_scale"]
    phone_top = frame["phone_top"] if k == 1 else round(spec["pad"][0] + 300 + (frame["phone_top"] - 320) * 0.5)
    shot = SHOTS / device / language / frame["appearance"] / f"{frame['shot']}.png"

    def place(anchor):
        x, y = anchor
        px = spec["phone_left"] + spec["phone_width"] + (x - 390) * spec["callout_scale"]
        py = phone_top + (y - frame["phone_top"]) * spec["callout_scale"]
        return f"right:{w - px:.1f}px;top:{py:.1f}px;transform:scale({spec['callout_scale']});transform-origin:top right"

    words = CALLOUT_TEXT[language]
    callouts = "".join(f'<div class="callout {style}" style="{place(anchor)}">{content.format(**words)}</div>'
                       for style, content, anchor in frame["callouts"])
    title, subtitle = TEXT[language][number]
    css = CSS % dict(
        w=w, h=h, bg=frame["bg"], ink=frame["ink"], span=frame["span"], em=frame["em"], sub=frame["sub"],
        pad_top=spec["pad"][0], pad_x=spec["pad"][1], gap=round(16 * k), h1=round(frame["h1"] * k), sub_size=round(24 * k),
        phone_left=spec["phone_left"], phone_top=phone_top, phone_width=spec["phone_width"], bezel=spec["bezel"],
        radius=spec["radius"], inner_radius=spec["inner_radius"], bezel_color=frame["bezel_color"], shadow=frame["shadow"],
    )
    return f"""<!doctype html><html lang="{language}"><head><meta charset="utf-8"><style>{css}</style></head><body>
<header><h1>{title}</h1>{f"<p>{subtitle}</p>" if subtitle else ""}</header>
<div class="phone"><img src="{shot.as_uri()}"></div>
{callouts}{FIT}</body></html>"""


def render(page, out, spec, tmp):
    source = pathlib.Path(tmp) / "page.html"
    source.write_text(page)
    raw = pathlib.Path(tmp) / "raw.png"
    w, h = spec["size"]
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    f"--force-device-scale-factor={spec['scale']}", f"--window-size={w},{h}",
                    "--virtual-time-budget=3000", f"--screenshot={raw}", source.as_uri()],
                   check=True, capture_output=True)
    out.parent.mkdir(parents=True, exist_ok=True)
    Image.open(raw).convert("RGB").save(out)  # The App Store rejects alpha.


def main():
    with tempfile.TemporaryDirectory() as tmp:
        for device, spec in DEVICES.items():
            for language in TEXT:
                for number, frame in FRAMES.items():
                    shot = SHOTS / device / language / frame["appearance"] / f"{frame['shot']}.png"
                    if not shot.exists():
                        print(f"Missing {shot.relative_to(ROOT)}; run scripts/screenshots.sh first")
                        continue
                    out = OUT / device / language / f"{frame['name']}.png"
                    render(build(device, language, number), out, spec, tmp)
                    print(out.relative_to(ROOT))
                    if device == "iphone-6.9":
                        # App Store Connect's base iPhone size is now 6.3" (1206×2622); same
                        # aspect ratio within 0.1%, so the 6.9" image is scaled down.
                        small = OUT / "iphone-6.3" / language / out.name
                        small.parent.mkdir(parents=True, exist_ok=True)
                        Image.open(out).resize(IPHONE_63, Image.LANCZOS).save(small)
                        print(small.relative_to(ROOT))


if __name__ == "__main__":
    main()
