#!/usr/bin/env python3
"""Arma el editor de estilo de la tienda de un juego, listo para publicar como artefacto.

    python3 studio/store-editor/build.py numbers <carpeta>

Escribe en <carpeta>: index.html (el editor), game.json, style.json (el estilo del repo),
fonts.json, pages/<en|es>/<pieza>.html (las mismas páginas que generan los PNG, con las capturas
como JPG livianos en shots/) y la lista de archivos para publicar (files.json). El editor cambia
las variables CSS de esas páginas; lo que el usuario guarda queda en la base del artefacto y se
lleva al repo copiándolo a AppStore/store-style.json.
"""
import importlib.util
import json
import pathlib
import shutil
import sys

from PIL import Image

HERE = pathlib.Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(HERE))
import store_style  # noqa: E402

GAMES = {
    "numbers": dict(dir="quiet-numbers", name="Quiet Numbers",
                    labels={"01-pairs": "Parejas", "02-daily": "Reto diario", "03-friends": "Amigos",
                            "04-rewards": "Recompensas", "05-stages": "Etapas"}),
    "solitaire": dict(dir="quiet-solitaire", name="Quiet Solitaire",
                      labels={"01-classic": "Clásico", "02-daily": "Reto diario", "03-friends": "Amigos",
                              "04-rewards": "Recompensas", "05-winnable": "Con solución"}),
    "sudoku": dict(dir="quiet-sudoku", name="Quiet Sudoku",
                   labels={"01-classic": "Clásico", "02-daily": "Reto diario", "03-friends": "Amigos",
                           "04-rewards": "Recompensas", "05-win": "Victoria"}),
}
CREATIVE = {"header": ("Header", 1280, 549), "search": ("Búsqueda", 1200, 800)}

# Lo que cada página escucha del editor: variables, fuentes de Google y volver a ajustar el título.
LISTENER = """<script>
addEventListener('message', (event) => {
  const data = event.data;
  if (!data || data.type !== 'store-style') return;
  const root = document.documentElement;
  for (const [name, value] of Object.entries(data.vars)) root.style.setProperty(name, value);
  for (const href of data.links) {
    if (document.querySelector(`link[data-font="${href}"]`)) continue;
    const link = Object.assign(document.createElement('link'), { rel: 'stylesheet', href });
    link.dataset.font = href;
    document.head.append(link);
  }
  const fit = () => window.fitTitles && window.fitTitles();
  fit();
  document.fonts.ready.then(fit);
  setTimeout(fit, 400);
});
parent.postMessage({ type: 'store-page-ready' }, '*');
</script>"""


def load_module(path):
    spec = importlib.util.spec_from_file_location("store_images", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def main():
    key, out = sys.argv[1], pathlib.Path(sys.argv[2])
    game = GAMES[key]
    root = REPO / game["dir"]
    images = load_module(root / "scripts/store-images.py")
    style = store_style.load(root)
    if out.exists():
        shutil.rmtree(out)
    files = ["game.json", "style.json", "fonts.json"]
    pieces = []

    for kind, (label, w, h) in CREATIVE.items():
        pieces.append(dict(id=kind, label=label, w=w, h=h, row=0))
    for number, frame in images.FRAMES.items():
        pieces.append(dict(id=frame["name"], label=f"{number} · {game['labels'][frame['name']]}", w=440, h=956, row=1))

    for lang in ("en", "es"):
        pages = out / "pages" / lang
        pages.mkdir(parents=True)
        # Imágenes que usan el header o la búsqueda (p. ej. el teléfono de la búsqueda de Solitaire).
        for image in sorted((root / "AppStore/creative").glob(f"*.{lang}.png")):
            shutil.copy(image, pages / image.name)
            files.append(f"pages/{lang}/{image.name}")
        for kind in CREATIVE:
            source = (root / "AppStore/creative" / f"{kind}.{lang}.html").read_text()
            page = source.replace("</head>", store_style.head(style, kind) + "\n</head>", 1)
            (pages / f"{kind}.html").write_text(page.replace("</body>", LISTENER + "\n</body>", 1))
            files.append(f"pages/{lang}/{kind}.html")
        for number, frame in images.FRAMES.items():
            shot = images.SHOTS / "iphone-6.9" / lang / frame["appearance"] / f"{frame['shot']}.png"
            jpg = out / "shots" / f"{lang}-{frame['name']}.jpg"
            jpg.parent.mkdir(exist_ok=True)
            image = Image.open(shot).convert("RGB")
            image.resize((660, round(image.height * 660 / image.width)), Image.LANCZOS).save(jpg, quality=86)
            files.append(f"shots/{jpg.name}")
            page = images.build("iphone-6.9", lang, number, style, image_src=f"../../shots/{jpg.name}")
            (pages / f"{frame['name']}.html").write_text(page.replace("</body>", LISTENER + "\n</body>", 1))
            files.append(f"pages/{lang}/{frame['name']}.html")

    (out / "game.json").write_text(json.dumps(dict(id=key, name=game["name"], pieces=pieces), ensure_ascii=False, indent=1))
    (out / "style.json").write_text(json.dumps(style, indent=1))
    fonts = [dict(id=k, label=label, stack=stack, google=google) for k, (label, stack, google) in store_style.FONTS.items()]
    (out / "fonts.json").write_text(json.dumps(fonts, indent=1))
    editor = (HERE / "editor.html").read_text()
    (out / "index.html").write_text(editor.replace("<title>Estilo de la tienda</title>", f"<title>Tienda de {game['name']}</title>", 1))
    (out / "files.json").write_text(json.dumps(files, indent=1))
    print(f"{len(files)} archivos en {out}")


if __name__ == "__main__":
    main()
