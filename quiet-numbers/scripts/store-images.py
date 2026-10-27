#!/usr/bin/env python3
"""Composes the App Store images: the canvas frames (pages "App Store 01–05") around real
screenshots of the app.

    scripts/screenshots.sh            # first: real screenshots, incl. the store scenes
    scripts/store-images.py           # then: AppStore/store-images/<device>/<en|es>/NN-name.png

Frames, copy and callouts come from the canvas "Quiet Numbers · Diseño". The phone shows the
real screenshot; callouts drawn over the board (pills, rings) are anchored to the real cells,
using the cell positions ScreenshotTests saves next to each store scene. Rendered with Chrome
headless: iPhone 6.9" at 1320×2868 (scaled to 6.3", 1206×2622, the size App Store Connect asks
for first) and iPad 13" at 2064×2752, no alpha.
"""
import html
import pathlib
import subprocess
import tempfile

from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS = ROOT / "AppStore/screenshots"
OUT = ROOT / "AppStore/store-images"
IPHONE_63 = (1206, 2622)
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

# Canvas geometry (iPhone frame, 440×956): phone 340 wide at x 50, 8 of bezel, a 324-wide
# screen. The canvas board has 32×40 cells whose first center is at (92, grid top + 20).
CANVAS_CELL = (32, 40)

DEVICES = {
    "iphone-6.9": dict(size=(440, 956), scale=3, screen_points=(440, 956), phone_left=50, phone_width=340,
                       bezel=8, radius=52, inner_radius=44, text_scale=1, pad=(60, 36), callout_scale=1),
    "ipad-13": dict(size=(1032, 1376), scale=2, screen_points=(1032, 1376), phone_left=136, phone_width=760,
                    bezel=14, radius=48, inner_radius=34, text_scale=1.55, pad=(84, 72), callout_scale=1.6),
}

TEXT = {
    "en": {
        1: ("Your 5-minute<br><span>break.</span>", "One quick round of numbers. Clear your head, beat your best, back to your day."),
        2: ("Match.<br><span>Pop.</span> <em>Clear.</em>", "Pair equal numbers or two that add up to 10. Horizontal, vertical or diagonal."),
        3: ("Beat your friends.<br><span>Or just yesterday's you.</span>", "New challenges every day. Keep your streak alive."),
        4: ("No ads.<br><span>No purchases.</span>", "Always free, no hidden charges. Just focus on playing."),
        5: ("Climb to<br><span>the top</span>", "Daily, best score and streak leaderboards with your friends and the world, on Game Center."),
    },
    "es": {
        1: ("Tu pausa de<br><span>5 minutos.</span>", "Una ronda rápida de números. Despeja la mente, supera tu récord y vuelve a tu día."),
        2: ("Junta.<br><span>Explota.</span> <em>Limpia.</em>", "Junta números iguales o dos que sumen 10. En horizontal, vertical o diagonal."),
        3: ("Gánales a tus amigos.<br><span>O a tu yo de ayer.</span>", "Un reto nuevo cada día. Mantén viva tu racha."),
        4: ("Sin anuncios.<br><span>Sin compras.</span>", "Gratis siempre, sin cobros ocultos. Solo concéntrate en jugar."),
        5: ("Llega a<br><span>la cima</span>", "Clasificaciones del día, de mejor puntaje y de racha con tus amigos y el mundo, en Game Center."),
    },
}

CALLOUT_TEXT = {
    "en": {"long_shot": "Long shot! +4", "double_row": "Double row!", "best": "Best", "streak": "8-day streak",
           "in_a_row": "10 in a row!"},
    "es": {"long_shot": "¡Tiro largo! +4", "double_row": "¡Doble fila!", "best": "Mejor", "streak": "Racha de 8 días",
           "in_a_row": "¡10 seguidas!"},
}

# The canvas's shared board (DemoData.StoreScene), for numbers redrawn on top of pills.
BOARD = [
    9, 7, 1, 7, 1, 9, 3, 5, 8, 2, 1, 9, 7, 4, 8, 8, 3, 8, 2, 8, 9, 4, 6, 5, 1, 5, 4,
    5, 5, 8, 9, 1, 3, 7, 1, 1, 7, 1, 9, 3, 5, 4, 8, 8, 3, 8, 9, 4, 6, 5, 1, 5, 4, 5,
    5, 8, 3, 7, 7, 1, 9, 3, 5, 4, 8, 8, 3, 8, 9, 5, 1, 5, 4, 8, 3, 7, 7, 9, 3, 4, 8,
    8, 3, 4, 6, 1, 5, 4, 3, 7,
]

ICON = {
    "timer": '<svg viewBox="0 0 24 24"><circle cx="12" cy="13.5" r="8" fill="none" stroke="currentColor" stroke-width="2.2"/><path d="M12 9.5v4l2.6 1.8M9.5 2.5h5" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/></svg>',
    "vertical": '<svg viewBox="0 0 24 24"><path d="M12 3v18M8 7l4-4 4 4M8 17l4 4 4-4" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "horizontal": '<svg viewBox="0 0 24 24"><path d="M3 12h18M7 8l-4 4 4 4M17 8l4 4-4 4" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "diagonal": '<svg viewBox="0 0 24 24"><path d="M5 5l14 14M5 11V5h6M19 13v6h-6" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/></svg>',
    "flame": '<svg viewBox="0 0 24 24"><path d="M12 2c1 4 5 6 5 11a5 5 0 0 1-10 0c0-2 1-3.5 2-4.5 0 2 1 3 2 3 0-3-1-6 1-9.5z" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linejoin="round"/></svg>',
}

# Callouts: (style, content, anchor). Anchors are canvas iPhone coordinates of the callout's
# top-left ("left") or top-right ("right") corner, relative to the board ("cell"), the score
# ("score") or the phone's top-right corner ("phone").
FRAMES = {
    1: dict(name="01-break", shot="store1", appearance="light", bg="#0E6B78", ink="#FFFFFF", span="#FFC2B5",
            em="#FFC2B5", sub="rgba(255,255,255,0.92)", h1=52, phone_top=330, grid_top=504, score_top=428,
            bezel_color="#0A1416", shadow="0 30px 70px rgba(2,30,36,0.45)",
            rings=[1, 82], dotted=(1, 82, "#B9472F"),
            callouts=[
                ("card", f'<i class="icon" style="color:#0E6B78">{ICON["timer"]}</i><b style="font-size:30px;color:#0E6B78">4:12</b>', ("right", "score", 424, 426)),
                ("pill coral", "{long_shot}", ("left", "cell", 176, 718)),
            ]),
    2: dict(name="02-match", shot="store2", appearance="dark", bg="#0F1A1D", ink="#E8F1F2", span="#5BC2CF",
            em="#FF9A85", sub="rgba(232,241,242,0.85)", h1=54, phone_top=320, grid_top=494, score_top=418,
            bezel_color="#000000", shadow="0 0 0 1px rgba(91,194,207,0.22), 0 30px 70px rgba(0,0,0,0.55)",
            pills=[(14, 15), (57, 66), (50, 60)],
            callouts=[
                ("pill teal", f'<i class="icon">{ICON["vertical"]}</i>7 + 3 = 10', ("left", "cell", 63, 685)),
                ("pill teal", f'<i class="icon">{ICON["horizontal"]}</i>8 = 8', ("right", "cell", 428, 540)),
                ("pill teal", f'<i class="icon">{ICON["diagonal"]}</i>1 + 9 = 10', ("left", "cell", 280, 669)),
                ("praise peach", '<b>{double_row}</b><small>+20</small>', ("right", "cell", 422, 840)),
            ]),
    3: dict(name="03-daily", shot="02-daily", appearance="light", bg="#DCEEF0", ink="#16201F", span="#0E6B78",
            em="#0E6B78", sub="#2E4A4E", h1=46, phone_top=360, bezel_color="#0A1416",
            shadow="0 30px 70px rgba(14,107,120,0.3)",
            callouts=[
                ("pill coral small", f'<i class="icon">{ICON["flame"]}</i>{{streak}}', ("right", "phone", 422, 344)),
            ]),
    4: dict(name="04-no-ads", shot="store4", appearance="dark", bg="#FCE9E3", ink="#16201F", span="#B9472F",
            em="#B9472F", sub="#4A5B5E", h1=52, phone_top=320, grid_top=494, score_top=418,
            bezel_color="#000000", shadow="0 30px 70px rgba(120,50,30,0.3)",
            pills=[(75, 76)],
            callouts=[
                ("card best", '<small>{best}</small><b>12,840</b>', ("right", "score", 424, 412)),
                ("praise coral", "<b>{in_a_row}</b>", ("right", "cell", 426, 588)),
            ]),
    5: dict(name="05-leaderboards", shot="06-leaderboards-friends", appearance="dark", bg="#0A4E58", ink="#FFFFFF",
            span="#9FE3EC", em="#9FE3EC", sub="rgba(255,255,255,0.88)", h1=52, phone_top=330,
            bezel_color="#000000", shadow="0 30px 70px rgba(0,20,24,0.5)", callouts=[]),
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
header p { margin: 0; font-size: %(sub_size)spx; line-height: 1.35; font-weight: 600; color: %(sub)s; }
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

# Shrinks a headline line that would overflow the frame (Spanish runs longer).
FIT = """
<script>
for (const h1 of document.querySelectorAll('h1')) {
  const max = h1.parentElement.clientWidth - 2 * parseFloat(getComputedStyle(h1.parentElement).paddingLeft);
  let size = parseFloat(getComputedStyle(h1).fontSize);
  while (h1.scrollWidth > max && size > 20) { size -= 1; h1.style.fontSize = size + 'px'; }
}
</script>
"""


def read_geometry(path):
    x0, y0, x89, y89, score_x, score_y = map(float, path.read_text().split(","))
    return dict(x0=x0, y0=y0, px=(x89 - x0) / 8, py=(y89 - y0) / 9, score_x=score_x, score_y=score_y)


def build(device, language, number):
    spec, frame = DEVICES[device], FRAMES[number]
    w, h = spec["size"]
    k = spec["text_scale"]
    phone_top = frame["phone_top"] if k == 1 else round(spec["pad"][0] + 300 + (frame["phone_top"] - 320) * 0.5)
    screen_left = spec["phone_left"] + spec["bezel"]
    screen_top = phone_top + spec["bezel"]
    s = (spec["phone_width"] - 2 * spec["bezel"]) / spec["screen_points"][0]

    shot = SHOTS / device / language / frame["appearance"] / f"{frame['shot']}.png"
    geometry_file = shot.with_name(f"{frame['shot']}-cells.txt")
    geometry = read_geometry(geometry_file) if geometry_file.exists() else None

    def cell_xy(index):
        c, r = index % 9, index // 9
        return (screen_left + (geometry["x0"] + c * geometry["px"]) * s,
                screen_top + (geometry["y0"] + r * geometry["py"]) * s)

    def place(anchor):
        side, relative, x, y = anchor
        if relative == "cell":
            c = (x - 92) / CANVAS_CELL[0]
            r = (y - frame["grid_top"] - 20) / CANVAS_CELL[1]
            px = screen_left + (geometry["x0"] + c * geometry["px"]) * s
            py = screen_top + (geometry["y0"] + r * geometry["py"]) * s
        elif relative == "score":
            px = (w - (440 - x) * spec["callout_scale"]) if side == "right" else x
            py = screen_top + geometry["score_y"] * s + (y - frame["score_top"]) * spec["callout_scale"]
        else:  # the phone's top-right corner
            px = spec["phone_left"] + spec["phone_width"] + (x - 390) * spec["callout_scale"]
            py = phone_top + (y - frame["phone_top"]) * spec["callout_scale"]
        origin = "top right" if side == "right" else "top left"
        position = f"right:{w - px:.1f}px" if side == "right" else f"left:{px:.1f}px"
        return f"{position};top:{py:.1f}px;transform:scale({spec['callout_scale']});transform-origin:{origin}"

    svg = []
    if geometry:
        pitch = geometry["px"] * s
        if "dotted" in frame:
            a, b, color = frame["dotted"]
            (x1, y1), (x2, y2) = cell_xy(a), cell_xy(b)
            svg.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="{color}" stroke-width="{3 * pitch / 32}" '
                       f'stroke-linecap="round" stroke-dasharray="{pitch / 32} {7 * pitch / 32}"/>')
        for index in frame.get("rings", []):
            x, y = cell_xy(index)
            # The app's selection ring: 40 pt on a 46 pt row.
            svg.append(f'<circle cx="{x}" cy="{y}" r="{20 / 46 * geometry["py"] * s}" fill="rgba(14,107,120,0.16)" stroke="#0E6B78" stroke-width="2"/>')
        for a, b in frame.get("pills", []):
            (x1, y1), (x2, y2) = cell_xy(a), cell_xy(b)
            svg.append(f'<line x1="{x1}" y1="{y1}" x2="{x2}" y2="{y2}" stroke="#5BC2CF" stroke-width="{pitch}" stroke-linecap="round"/>')
            for index in (a, b):
                x, y = cell_xy(index)
                svg.append(f'<text x="{x}" y="{y}" text-anchor="middle" dominant-baseline="central" font-family="QRounded" '
                           f'font-weight="800" font-size="{27 / 46 * geometry["py"] * s}" fill="#062327">{BOARD[index]}</text>')

    words = CALLOUT_TEXT[language]
    callouts = "".join(
        f'<div class="callout {style}" style="{place(anchor)}">{content.format(**words)}</div>'
        for style, content, anchor in frame["callouts"]
        if geometry or anchor[1] == "phone"
    )
    title, subtitle = TEXT[language][number]
    css = CSS % dict(
        w=w, h=h, bg=frame["bg"], ink=frame["ink"], span=frame["span"], em=frame["em"], sub=frame["sub"],
        pad_top=round(spec["pad"][0] * (56 / 60 if number == 3 else 1)), pad_x=spec["pad"][1],
        gap=round(16 * k), h1=round(frame["h1"] * k), sub_size=round(20 * k),
        phone_left=spec["phone_left"], phone_top=phone_top, phone_width=spec["phone_width"], bezel=spec["bezel"],
        radius=spec["radius"], inner_radius=spec["inner_radius"], bezel_color=frame["bezel_color"], shadow=frame["shadow"],
    )
    return f"""<!doctype html><html lang="{language}"><head><meta charset="utf-8"><style>{css}</style></head><body>
<header><h1>{title}</h1><p>{html.escape(subtitle)}</p></header>
<div class="phone"><img src="{shot.as_uri()}"></div>
<svg class="overlay" viewBox="0 0 {w} {h}">{"".join(svg)}</svg>
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
