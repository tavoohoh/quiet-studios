"""Estilo editable de las imágenes de la tienda (capturas, header y búsqueda) de un juego.

Cada juego guarda su estilo en `AppStore/store-style.json`: un estilo global (fondo, título,
subtítulo y desplazamiento del teléfono en las capturas) y, en "pieces", lo que una pieza cambia
para ella sola (01-…05- de las capturas, "header", "search"); cada sección de una pieza reemplaza a
la global completa. Los scripts de imágenes lo convierten en variables CSS (`--bg`, `--title-*`,
`--sub-*`, `--phone-offset`) que usan sus páginas;
el editor (studio/store-editor/editor.html) hace la misma cuenta en JavaScript.
"""
import json
import pathlib

# Clave → (nombre, pila de fuentes, familia de Google Fonts o None). "QRounded" solo existe en las
# páginas de las capturas (SF Rounded del sistema); el header y la búsqueda caen en "SF Pro Rounded".
FONTS = {
    "sf-rounded": ("SF Pro Rounded", '"QRounded", "SF Pro Rounded", ui-rounded, Nunito, system-ui, sans-serif', None),
    "sf-pro": ("SF Pro", '"SF Pro Display", "SF Pro", system-ui, -apple-system, sans-serif', None),
    "new-york": ("New York", '"QSerif", "New York", ui-serif, Georgia, serif', None),
    "nunito": ("Nunito", "Nunito, system-ui, sans-serif", "Nunito:wght@200..1000"),
    "fredoka": ("Fredoka", "Fredoka, system-ui, sans-serif", "Fredoka:wght@300..700"),
    "quicksand": ("Quicksand", "Quicksand, system-ui, sans-serif", "Quicksand:wght@300..700"),
    "outfit": ("Outfit", "Outfit, system-ui, sans-serif", "Outfit:wght@100..900"),
    "dm-sans": ("DM Sans", '"DM Sans", system-ui, sans-serif', "DM+Sans:wght@100..1000"),
    "fraunces": ("Fraunces", "Fraunces, Georgia, serif", "Fraunces:wght@100..900"),
}

# New York del sistema, para las páginas que se abren desde el disco.
FONT_FACES = '@font-face { font-family: "QSerif"; src: url("file:///System/Library/Fonts/NewYork.ttf"); font-weight: 1 1000; }'

SECTIONS = ("background", "title", "subtitle", "phone")


def load(game_root):
    return json.loads((pathlib.Path(game_root) / "AppStore/store-style.json").read_text())


def effective(style, piece):
    own = style.get("pieces", {}).get(piece, {})
    return {section: own.get(section, style[section]) for section in SECTIONS}


def _rgba(hex_color, opacity):
    r, g, b = (int(hex_color[i:i + 2], 16) for i in (1, 3, 5))
    return f"rgba({r}, {g}, {b}, {opacity / 100:g})"


def css_vars(style, piece):
    s = effective(style, piece)
    bg, title, sub, phone = s["background"], s["title"], s["subtitle"], s["phone"]
    gradient = bg["top"] if bg["top"].lower() == bg["bottom"].lower() else f"linear-gradient(180deg, {bg['top']}, {bg['bottom']})"
    values = {
        "--bg": gradient,
        "--title-font": FONTS[title["font"]][1],
        "--title-weight": title["weight"],
        "--title-scale": f"{title['size'] / 100:g}",
        "--title-color": title["color"],
        "--title-accent": title["accent"],
        "--sub-font": FONTS[sub["font"]][1],
        "--sub-weight": sub["weight"],
        "--sub-scale": f"{sub['size'] / 100:g}",
        "--sub-color": _rgba(sub["color"], sub["opacity"]),
        # La marca sobre el título del header va un poco más suave que el subtítulo.
        "--eyebrow-color": _rgba(sub["color"], round(sub["opacity"] * 0.944)),
        # Capturas: cuánto baja (o sube, si es negativo) el teléfono, en puntos del marco de iPhone.
        "--phone-offset": f"{phone['offset']}px",
    }
    return ":root { " + " ".join(f"{k}: {v};" for k, v in values.items()) + " }"


def head(style, piece):
    """Lo que va en el <head> de una página: fuentes de Google que use y las variables."""
    families = sorted({FONTS[effective(style, piece)[s]["font"]][2] for s in ("title", "subtitle")} - {None})
    link = (f'<link rel="stylesheet" href="https://fonts.googleapis.com/css2?{"&".join("family=" + f for f in families)}&display=swap">'
            if families else "")
    return f'{link}<style id="store-style">{FONT_FACES}\n{css_vars(style, piece)}</style>'
