#!/usr/bin/env python3
"""Writes AppStore/game-center.json and game-center.md (achievements and leaderboards for
App Store Connect) and renders the 13 Game Center badges to AppStore/achievements/<id>.png.

    scripts/game-center.py

IDs must match the code: `Achievement.gameCenterID` ("qs_" + the case in snake case) and
`Leaderboard` in App/AppModel.swift; the script checks both. Badges follow Quiet Numbers'
system (a colored square Game Center crops round, a faint ring, a white line motif), drawn
with AppKit through scripts/render-svg.swift: 1024×1024, no alpha.
"""
import json
import pathlib
import re
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "AppStore"

# (case, points, hidden, name en/es, before en/es, after en/es, reward en/es)
ACHIEVEMENTS = [
    ("firstWin", 10, False, ("First Hand", "Primera mano"),
     ("Win your first game.", "Gana tu primera partida."),
     ("You won your first game.", "Ganaste tu primera partida."),
     ("Quiet deck, theme back, Teal & Coral board (defaults)", "Mazo Quiet, reverso del tema, tablero Petróleo y coral (por defecto)")),
    ("noUndo", 30, False, ("No Going Back", "Sin vuelta atrás"),
     ("Win without undo.", "Gana sin deshacer."),
     ("You won without a single undo.", "Ganaste sin deshacer ni una vez."),
     ("Coral back", "Reverso Coral")),
    ("noHints", 40, False, ("Steady Hand", "A pulso"),
     ("Win without hints.", "Gana sin pistas."),
     ("You won without a single hint.", "Ganaste sin usar ni una pista."),
     ("Sage & Sand board", "Tablero Salvia y arena")),
    ("onePass", 50, False, ("One Pass", "Una sola vuelta"),
     ("Win without recycling the stock.", "Gana sin reciclar el mazo."),
     ("You won going through the stock only once.", "Ganaste recorriendo el mazo una sola vez."),
     ("Classic deck", "Mazo Clásico")),
    ("tenWins", 40, False, ("Ten Wins", "Diez victorias"),
     ("Win 10 games.", "Gana 10 partidas."),
     ("You won 10 games.", "Ganaste 10 partidas."),
     ("Sage & Coral board", "Tablero Salvia y coral")),
    ("consistency", 80, False, ("Consistency", "Constancia"),
     ("Complete 7 daily challenges in a row.", "Completa 7 retos diarios seguidos."),
     ("You completed 7 daily challenges in a row.", "Completaste 7 retos diarios seguidos."),
     ("Indigo & Peach board", "Tablero Índigo y durazno")),
    ("habit", 100, False, ("Habit", "Hábito"),
     ("Complete 30 daily challenges in a row.", "Completa 30 retos diarios seguidos."),
     ("You completed 30 daily challenges in a row.", "Completaste 30 retos diarios seguidos."),
     ("Illustrated deck", "Mazo Ilustrado")),
    ("ladder", 60, False, ("Ladder", "Escalera"),
     ("Build a column from king to ace.", "Arma una columna del rey al as."),
     ("You built a column from king to ace.", "Armaste una columna del rey al as."),
     ("Linen back", "Reverso Lino")),
    ("centennial", 100, False, ("Centennial", "Centenario"),
     ("Win 100 games.", "Gana 100 partidas."),
     ("You won 100 games.", "Ganaste 100 partidas."),
     ("Gold back and gold app icon", "Reverso Dorado e ícono dorado")),
    ("nightOwl", 40, False, ("Night Owl", "Noctámbulo"),
     ("Win a daily challenge between midnight and 4 a.m.", "Gana un reto diario entre la medianoche y las 4 a. m."),
     ("You won a daily challenge in the small hours.", "Ganaste un reto diario de madrugada."),
     ("Night back", "Reverso Noche")),
    ("fiftyWins", 80, False, ("Fifty", "Cincuenta"),
     ("Win 50 games.", "Gana 50 partidas."),
     ("You won 50 games.", "Ganaste 50 partidas."),
     ("Cascade victory", "Victoria en cascada")),
    ("economy", 60, False, ("Economy", "Economía"),
     ("Win in fewer than 100 moves.", "Gana en menos de 100 movimientos."),
     ("You won in fewer than 100 moves.", "Ganaste en menos de 100 movimientos."),
     ("Pixel deck", "Mazo Pixel")),
    ("inTheRed", 20, True, ("In the Red", "Números rojos"),
     ("Take your score below zero.", "Lleva tu puntaje por debajo de cero."),
     ("Your score went below zero. It happens.", "Tu puntaje bajó de cero. Pasa."),
     ("Hidden: hints at 3 outside the daily challenge", "Oculta: pistas a 3 fuera del reto diario")),
]

LEADERBOARDS = [
    dict(id="qs_daily_challenge", codeCase="Leaderboard.daily", type="recurring",
         recurrence="Every 1 day, starting at 05:00 UTC (00:00 in Colombia)",
         name={"en": "Daily Challenge", "es": "Reto diario"}, scoreFormat="Integer",
         formatSuffix={"en": " points", "es": " puntos"}, sortOrder="High to Low", scoreSubmission="Most recent score",
         source="Today's scored daily attempt when it's won (AppModel.pushToGameCenter)",
         scoreRange="None (scores can be negative)"),
    dict(id="qs_best_score", codeCase="Leaderboard.bestScore", type="classic", recurrence=None,
         name={"en": "Best Score", "es": "Mejor puntaje"}, scoreFormat="Integer",
         formatSuffix={"en": " points", "es": " puntos"}, sortOrder="High to Low", scoreSubmission="Best score",
         source="PlayerProgress.bestScore (classic games, including abandoned ones)"),
    dict(id="qs_longest_streak", codeCase="Leaderboard.longestStreak", type="classic", recurrence=None,
         name={"en": "Longest Streak", "es": "Racha más larga"}, scoreFormat="Integer",
         formatSuffix={"en": " days", "es": " días"}, sortOrder="High to Low", scoreSubmission="Best score",
         source="Longest run of completed daily challenges (AppModel.longestStreak)"),
]


def game_center_id(case):
    return "qs_" + re.sub(r"([A-Z])", lambda m: "_" + m.group(1).lower(), case)


# MARK: Badges

TEAL, NIGHT, GOLD, CORAL = "#0E6B78", "#0F1A1D", "#A8741A", "#B9472F"
WHITE, NIGHT_INK = "#FFFFFF", "#5BC2CF"


def circle(cx, cy, r):
    return f"M{cx - r} {cy} a{r} {r} 0 1 0 {2 * r} 0 a{r} {r} 0 1 0 {-2 * r} 0"


def line(d, ink, width=4.5, dash=None):
    dash = f' stroke-dasharray="{dash}"' if dash else ""
    return (f'<path d="{d}" fill="none" stroke="{ink}" stroke-width="{width}"{dash} '
            'stroke-linecap="round" stroke-linejoin="round"/>')


def dot(d, ink):
    return f'<path d="{d}" fill="{ink}"/>'


def card(x, y, w=26, h=36, rotate=0, ink=WHITE, fill=TEAL):
    """A card outline, top-left at (x, y), turned around its center. Filled with the
    badge color so a card in front hides the one behind."""
    cx, cy = x + w / 2, y + h / 2
    d = f"M{x + 4} {y} H{x + w - 4} a4 4 0 0 1 4 4 V{y + h - 4} a4 4 0 0 1 -4 4 H{x + 4} a4 4 0 0 1 -4 -4 V{y + 4} a4 4 0 0 1 4 -4 Z"
    return f'<g transform="rotate({rotate} {cx} {cy})"><path d="{d}" fill="{fill}"/>' + line(d, ink) + "</g>"


HEART = "M50 58.5c-.4 0-7.6-4.7-9-9.3-1-3.2 1-6.2 4.1-6.2 2 0 3.5 1.2 4.9 3 1.4-1.8 2.9-3 4.9-3 3.1 0 5.1 3 4.1 6.2-1.4 4.6-8.6 9.3-9 9.3z"


def calendar(ink):
    return [
        line("M34 32 H66 a4 4 0 0 1 4 4 V68 a4 4 0 0 1 -4 4 H34 a4 4 0 0 1 -4 -4 V36 a4 4 0 0 1 4 -4 Z", ink),
        line("M30 44 H70", ink, 3.5),
        line("M41 27 V36 M59 27 V36", ink),
    ]


BADGES = {
    # One card with a heart: the first hand won.
    "qs_first_win": (TEAL, WHITE, [card(35, 29, 30, 42), dot(HEART, WHITE)]),
    # Undo arrow, crossed out.
    "qs_no_undo": (TEAL, WHITE, [line("M40 40 L32 48 L40 56 M32 48 H58 a10 10 0 0 1 0 20 H50", WHITE), line("M30 30 L70 72", WHITE)]),
    # Light bulb, crossed out (as Quiet Numbers' No Help).
    "qs_no_hints": (TEAL, WHITE, [line(circle(50, 44, 14), WHITE), line("M44 64 H56 M45.5 71 H54.5", WHITE), line("M31 28 L69 74", WHITE)]),
    # One loop around, ending in an arrow: the stock, once.
    "qs_one_pass": (TEAL, WHITE, [line("M66 50 a16 16 0 1 1 -6 -12.5", WHITE), line("M54 33 L61 38 L55 45", WHITE)]),
    # Two cards fanned.
    "qs_ten_wins": (TEAL, WHITE, [card(30, 31, 26, 36, -12), card(44, 31, 26, 36, 10)]),
    "qs_consistency": (TEAL, WHITE, calendar(WHITE) + [dot(" ".join(
        [circle(x, 54, 2.8) for x in (38, 46, 54, 62)] + [circle(x, 63, 2.8) for x in (38, 46, 54)]), WHITE)]),
    "qs_habit": (TEAL, WHITE, calendar(WHITE) + [line("M40 57 L47 64 L61 50", WHITE)]),
    # Stairs: king down to ace.
    "qs_ladder": (TEAL, WHITE, [line("M28 70 H40 V60 H50 V50 H60 V40 H72", WHITE), line("M28 70 H72", WHITE, 3)]),
    # Gold rosette (as Quiet Numbers' Centennial).
    "qs_centennial": (GOLD, WHITE, [line(circle(50, 42, 14), WHITE), dot(circle(50, 42, 5), WHITE), line("M43 55 L37 75 L45 70 L50 77 L55 70 L63 75 L57 55", WHITE)]),
    # Moon and stars (as Quiet Numbers' Night Owl).
    "qs_night_owl": (NIGHT, NIGHT_INK, [line("M60 28 a22 22 0 1 0 14 38 a17 17 0 1 1 -14 -38 Z", NIGHT_INK), line("M32 30 V40 M27 35 H37", NIGHT_INK, 3.5), line("M30 56 V62 M27 59 H33", NIGHT_INK, 3)]),
    # Three cards fanned.
    "qs_fifty_wins": (TEAL, WHITE, [card(26, 33, 24, 34, -18), card(38, 29, 24, 34, 0), card(50, 33, 24, 34, 18)]),
    # A bolt: quick and lean.
    "qs_economy": (NIGHT, NIGHT_INK, [line("M54 26 L36 54 H50 L46 74 L64 46 H50 Z", NIGHT_INK)]),
    "qs_in_the_red": (CORAL, WHITE, [line("M30 50 H70", WHITE, 8)]),
}


def badge(background, ink, paths):
    return ('<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100">'
            f'<rect width="100" height="100" fill="{background}"/>'
            f'<circle cx="50" cy="50" r="41" fill="none" stroke="{ink}" stroke-opacity="0.3" stroke-width="1.5"/>'
            + "".join(paths) + "</svg>")


def render(svg, out, tmp):
    source = pathlib.Path(tmp) / (out.stem + ".svg")
    source.write_text(svg)
    out.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(["swift", str(ROOT / "scripts/render-svg.swift"), str(source), str(out), "1024", "1024", "opaque"], check=True)


# MARK: Checks against the code

def check_code():
    problems = []
    source = (ROOT / "Packages/QuietSolitaireCore/Sources/QuietSolitaireCore/Achievements.swift").read_text()
    enum = source[source.index("public enum Achievement"):source.index("/// Amount needed")]
    cases = re.findall(r"^\s+case (\w+)$", enum, re.MULTILINE)
    listed = [a[0] for a in ACHIEVEMENTS]
    if cases != listed:
        problems.append(f"Achievement cases {cases} differ from this list {listed}")
    model = (ROOT / "App/AppModel.swift").read_text()
    for board in LEADERBOARDS:
        if f'"{board["id"]}"' not in model:
            problems.append(f"Leaderboard {board['id']} not in AppModel.swift")
    hidden = re.search(r"isHidden: Bool \{ (.+) \}", source).group(1)
    for case, _, is_hidden, *_ in ACHIEVEMENTS:
        if (f".{case}" in hidden) != is_hidden:
            problems.append(f"{case}: hidden here is {is_hidden}, not in the code")
    return problems


def main():
    problems = check_code()
    for problem in problems:
        print(problem)
    if problems:
        sys.exit(1)
    achievements = []
    for case, points, hidden, name, before, after, reward in ACHIEVEMENTS:
        identifier = game_center_id(case)
        achievements.append(dict(
            id=identifier, codeCase=f"Achievement.{case}", points=points, hidden=hidden, achievableMoreThanOnce=False,
            reward={"en": reward[0], "es": reward[1]}, name={"en": name[0], "es": name[1]},
            preEarnedDescription={"en": before[0], "es": before[1]}, earnedDescription={"en": after[0], "es": after[1]},
            image=f"AppStore/achievements/{identifier}.png"))
    total = sum(a["points"] for a in achievements)
    (OUT / "game-center.json").write_text(json.dumps(
        {"achievements": achievements, "totalPoints": total, "leaderboards": LEADERBOARDS}, ensure_ascii=False, indent=2) + "\n")

    rows = "\n".join(
        f"| `{a['id']}` | `{a['codeCase'].split('.')[1]}` | {a['points']} | {'Sí' if a['hidden'] else 'No'} | "
        f"{a['name']['en']} / {a['name']['es']} | {a['preEarnedDescription']['en']} / {a['preEarnedDescription']['es']} | "
        f"{a['earnedDescription']['en']} / {a['earnedDescription']['es']} | {a['reward']['es']} |" for a in achievements)
    boards = "\n".join(
        f"| `{b['id']}` | `{b['codeCase']}` | {b['name']['en']} / {b['name']['es']} | "
        f"{'Recurrente (' + b['recurrence'] + ')' if b['recurrence'] else 'Clásico'} | Entero | "
        f"\"{b['formatSuffix']['en']}\" / \"{b['formatSuffix']['es']}\" | Mayor a menor | "
        f"{'**Más reciente**' if b['scoreSubmission'] == 'Most recent score' else 'Mejor puntaje'} | {b['source']} |" for b in LEADERBOARDS)
    (OUT / "game-center.md").write_text(f"""# Game Center: Quiet Solitaire

Configuración para App Store Connect, generada por `scripts/game-center.py` (también escribe `game-center.json` y las insignias, y verifica que los IDs coincidan con el código: `Achievement.gameCenterID` = "qs_" + el caso en snake case, y `Leaderboard` en `App/AppModel.swift`). Prefijo `qs_` para no chocar con Quiet Numbers.

## Logros ({len(achievements)}, {total} / 1000 puntos)

Ninguno se puede ganar más de una vez. Cada uno lleva una imagen de 1024×1024 sin transparencia: `AppStore/achievements/<id>.png` (mismo sistema de insignias que Quiet Numbers).

| ID | Caso en el código | Puntos | Oculto | Nombre (en / es) | Descripción antes de ganarlo (en / es) | Descripción al ganarlo (en / es) | Recompensa |
|---|---|---:|---|---|---|---|---|
{rows}

Ocultos: Noctámbulo, Economía y Números rojos son sorpresas; el resto son metas visibles.

## Leaderboards

| ID | Caso en el código | Nombre (en / es) | Tipo | Formato | Sufijo (en / es) | Orden | Envío | Qué se envía |
|---|---|---|---|---|---|---|---|---|
{boards}

## Notas

- El reto cambia a la medianoche de cada dispositivo (`DailyKey.rolloverHour = 0` en QuietKit). `qs_daily_challenge` recurre cada 24 h desde las 05:00 UTC (00:00 en Colombia) y guarda el puntaje **más reciente**.
- `qs_best_score` y `qs_longest_streak` solo reciben valores > 0.
- Partidas guardadas (`saveGameData`): el progreso se guarda en el iCloud del jugador vía Game Center (requiere sesión). Entitlements en `App/QuietSolitaire.entitlements` (contenedor `iCloud.<bundle id>`, iCloud Documents).
- Restablecer progreso (Ajustes) borra el guardado de iCloud y reinicia los logros con `GKAchievement.resetAchievements()`. Los puntajes ya enviados no se pueden retirar.
""")
    with tempfile.TemporaryDirectory() as tmp:
        for identifier, (background, ink, paths) in BADGES.items():
            render(badge(background, ink, paths), OUT / "achievements" / f"{identifier}.png", tmp)
    missing = {a["id"] for a in achievements} - set(BADGES)
    if missing:
        sys.exit(f"Badges missing for {sorted(missing)}")
    print(f"{len(achievements)} achievements ({total} points), {len(LEADERBOARDS)} leaderboards, {len(BADGES)} badges.")


if __name__ == "__main__":
    main()
