#!/usr/bin/env python3
"""QA de un canvas de diseño de Quiet Studios (plantilla de 5 páginas).

Uso:
  python3 .claude/skills/quiet-design-canvas/qa.py <carpeta del canvas> <app> <salida>

  <carpeta del canvas>  la carpeta con canvas.json y los .dc.html (la que se publica con Artifact).
  <app>                 carpeta de la app en el repo (quiet-numbers); de ahí sale design/canvas-assets.tsv.
  <salida>              carpeta para los PNG (una por artboard y una hoja por página). Usar el scratchpad.

Revisa la estructura (páginas, tablero, medidas, imágenes conocidas), renderiza cada artboard con
Chrome cambiando /_blob/<id> por el archivo del repo, y avisa si el contenido se sale del artboard
si sobra espacio vacío al final o si el contenido llega al borde inferior. Sale con código 1 si hay errores.
"""
import json
import os
import re
import subprocess
import sys

from PIL import Image

PAGES = [("overview", "Overview"), ("appstore", "App Store"), ("screens", "Screens"),
         ("styles", "Styles"), ("components", "Components")]
QUIET_STUDIOS_DS = "https://claude.ai/artifact/59yz1mHLFU3u3jvSfugf7B"
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
HERE = os.path.dirname(os.path.abspath(__file__))
SLACK = 300          # alto extra renderizado debajo del artboard para ver si algo se sale
MAX_EMPTY = 90       # px vacíos al final del artboard antes de avisar
MIN_MARGIN = 24      # px libres mínimos al final (si no, algo quedó cortado o pegado al borde)

errors, warnings = [], []
titles = {}


def lint(project, assets):
    canvas = json.load(open(os.path.join(project, "canvas.json")))
    pages = [(p["id"], p["name"]) for p in canvas.get("pages", [])]
    if pages != PAGES:
        errors.append(f"páginas {pages}; deben ser exactamente {PAGES}")
    if not any(ds.get("artifact") == QUIET_STUDIOS_DS for ds in canvas.get("designSystems", [])):
        errors.append("falta instalar el sistema de diseño de Quiet Studios (designSystems)")
    boards = canvas.get("boards", {})
    files = {f for f in os.listdir(project) if f.endswith(".dc.html")}
    for f in sorted(files - set(boards)):
        errors.append(f"{f} no está en boards")
    for f in sorted(set(boards) - files):
        errors.append(f"boards apunta a {f}, que no existe")
    if set(canvas.get("order", [])) != set(boards):
        errors.append("order no tiene los mismos artboards que boards")

    raw = open(os.path.join(project, "canvas.json")).read()
    for left in sorted(set(re.findall(r"TODO|__APP__|__DATE__", raw))):
        errors.append(f"canvas.json: quedó {left} de la plantilla")

    for name, b in boards.items():
        if name not in files:
            continue
        if b.get("page") not in dict(PAGES):
            errors.append(f"{name}: página {b.get('page')!r} no existe")
        src = open(os.path.join(project, name)).read()
        preview = re.search(r'"\$preview":\{"width":(\d+),"height":(\d+)\}', src)
        root = re.search(r'<x-dc>.*?</helmet>\s*<div style="width: (\d+)px; height: (\d+)px', src, re.S)
        sizes = {(b["w"], b["h"])}
        if preview:
            sizes.add((int(preview[1]), int(preview[2])))
        if root:
            sizes.add((int(root[1]), int(root[2])))
        if len(sizes) > 1 or not preview or not root:
            errors.append(f"{name}: tamaño distinto entre canvas.json, $preview y el div raíz {sorted(sizes)}")
        for left in sorted(set(re.findall(r"TODO|__APP__|__DATE__", src))):
            errors.append(f"{name}: quedó {left} de la plantilla")
        for blob in re.findall(r"/_blob/([0-9a-f]{32})", src):
            if blob not in assets:
                errors.append(f"{name}: /_blob/{blob} no está en design/canvas-assets.tsv")

    by_page = {}
    for name, b in boards.items():
        by_page.setdefault(b.get("page"), []).append((name, b))
    for page, items in by_page.items():
        for i, (a, ba) in enumerate(items):
            for c, bc in items[i + 1:]:
                if (ba["x"] < bc["x"] + bc["w"] and bc["x"] < ba["x"] + ba["w"]
                        and ba["y"] < bc["y"] + bc["h"] and bc["y"] < ba["y"] + ba["h"]):
                    errors.append(f"{a} y {c} se superponen en {page}")
    return canvas


def render(project, app, assets, out, name, w, h):
    html = os.path.join(out, "html", name + ".html")
    png = os.path.join(out, "png", name.replace(".dc.html", ".png"))
    subprocess.run(["node", os.path.join(HERE, "dc2static.js"), os.path.join(project, name), html, ""],
                   check=True, env={**os.environ, "PROPS": "{}"})
    text = open(html).read()
    text = re.sub(r"/_blob/([0-9a-f]{32})",
                  lambda m: "file://" + os.path.join(app, assets.get(m[1], "missing")), text)
    open(html, "w").write(text)
    h2 = re.search(r"<h[12][^>]*>(.*?)</h[12]>", text, re.S)
    if h2:
        titles.setdefault(re.sub(r"<[^>]+>", "", h2[1]).strip(), []).append(name)
    # Perfil propio para no chocar con otro Chrome headless; a veces falla al arrancar, se reintenta.
    command = [CHROME, "--headless=new", "--hide-scrollbars", "--force-device-scale-factor=1",
               "--allow-file-access-from-files", "--virtual-time-budget=4000",
               f"--user-data-dir={os.path.join(out, 'chrome-profile')}",
               f"--window-size={w},{h + SLACK}", f"--screenshot={png}", "file://" + html]
    for attempt in range(3):
        if subprocess.run(command, capture_output=True).returncode == 0:
            break
        if attempt == 2:
            raise SystemExit(f"Chrome no pudo renderizar {name}")
    image = Image.open(png).convert("RGB")

    below = image.crop((0, h, w, h + SLACK))
    if below.getextrema() != ((255, 255), (255, 255), (255, 255)):
        errors.append(f"{name}: el contenido se sale por debajo del artboard ({h}px)")

    board = image.crop((0, 0, w, h))
    bg = board.getpixel((2, h - 2))
    empty = 0
    for y in range(h - 1, 0, -1):
        row = board.crop((0, y, w, y + 1))
        if row.getextrema() != tuple((c, c) for c in bg):
            break
        empty += 1
    padding = 64
    if empty < MIN_MARGIN:
        warnings.append(f"{name}: el contenido llega al borde inferior ({empty}px libres); subir la altura")
    elif empty - padding > MAX_EMPTY:
        warnings.append(f"{name}: {empty}px vacíos al final; bajar la altura a ~{h - empty + padding}")
    board.save(png)
    return png


def sheet(canvas, out, page, pngs):
    boards = {n: b for n, b in canvas["boards"].items() if b["page"] == page and n in pngs}
    if not boards:
        return None
    gap = 40
    x0 = min(b["x"] for b in boards.values())
    y0 = min(b["y"] for b in boards.values())
    W = max(b["x"] + b["w"] for b in boards.values()) - x0 + 2 * gap
    H = max(b["y"] + b["h"] for b in boards.values()) - y0 + 2 * gap
    canvas_img = Image.new("RGB", (W, H), (214, 219, 221))
    for n, b in boards.items():
        canvas_img.paste(Image.open(pngs[n]), (b["x"] - x0 + gap, b["y"] - y0 + gap))
    scale = min(1, 2400 / W)
    canvas_img = canvas_img.resize((int(W * scale), int(H * scale)), Image.LANCZOS)
    path = os.path.join(out, f"page-{page}.png")
    canvas_img.save(path)
    return path


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    project, app, out = (os.path.abspath(a) for a in sys.argv[1:])
    assets = {}
    tsv = os.path.join(app, "design", "canvas-assets.tsv")
    if not os.path.exists(tsv):
        errors.append(f"falta {tsv}")
    for line in open(tsv) if os.path.exists(tsv) else []:
        if line.strip() and not line.startswith("#"):
            path, blob = line.rstrip("\n").split("\t")
            if not os.path.exists(os.path.join(app, path)):
                errors.append(f"canvas-assets.tsv: {path} no existe")
            assets[blob] = path
    os.makedirs(os.path.join(out, "html"), exist_ok=True)
    os.makedirs(os.path.join(out, "png"), exist_ok=True)

    canvas = lint(project, assets)
    pngs = {}
    for name, b in canvas.get("boards", {}).items():
        if os.path.exists(os.path.join(project, name)):
            pngs[name] = render(project, app, assets, out, name, b["w"], b["h"])
    for page, _ in PAGES:
        path = sheet(canvas, out, page, pngs)
        if path:
            print("hoja:", path)

    for title, names in titles.items():
        if len(names) > 1:
            warnings.append(f"mismo título «{title}» en {', '.join(names)}")
    for w in warnings:
        print("aviso:", w)
    for e in errors:
        print("error:", e)
    print(f"{len(pngs)} artboards · {len(errors)} errores · {len(warnings)} avisos")
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
