#!/usr/bin/env python3
"""Writes AppStore/game-center.json and game-center.md (achievements and leaderboards for
App Store Connect) and renders the 12 Game Center badges to AppStore/achievements/<id>.png.

    scripts/game-center.py

IDs must match the code: `Achievement.gameCenterID` ("qsu_" + the case in snake case) and
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
    ("firstWin", 10, False, ("First Sudoku", "Primer sudoku"),
     ("Solve your first sudoku.", "Resuelve tu primer sudoku."),
     ("You solved your first sudoku.", "Resolviste tu primer sudoku."),
     ("Rounded digits, Teal & Coral board (defaults)", "Números Redondos, tablero Petróleo y coral (por defecto)")),
    ("noMistakes", 40, False, ("Clean Sheet", "Sin tachones"),
     ("Solve a sudoku without mistakes.", "Resuelve un sudoku sin errores."),
     ("You solved a sudoku without a single mistake.", "Resolviste un sudoku sin un solo error."),
     ("Classic digits (New York)", "Números Clásicos (New York)")),
    ("noHints", 40, False, ("On Your Own", "Por tu cuenta"),
     ("Solve a sudoku without hints.", "Resuelve un sudoku sin pistas."),
     ("You solved a sudoku without a single hint.", "Resolviste un sudoku sin usar ni una pista."),
     ("Sage & Sand board", "Tablero Salvia y arena")),
    ("noNotes", 60, False, ("From Memory", "De memoria"),
     ("Solve a medium or harder sudoku without notes.", "Resuelve un sudoku de nivel Media o más sin notas."),
     ("You solved a medium or harder sudoku without notes.", "Resolviste un sudoku de nivel Media o más sin notas."),
     ("Typewriter digits (SF Mono)", "Números Máquina (SF Mono)")),
    ("tenWins", 40, False, ("Ten Sudokus", "Diez sudokus"),
     ("Solve 10 sudokus.", "Resuelve 10 sudokus."),
     ("You solved 10 sudokus.", "Resolviste 10 sudokus."),
     ("Notes in color", "Notas en color")),
    ("consistency", 80, False, ("Consistency", "Constancia"),
     ("Complete 7 daily challenges in a row.", "Completa 7 retos diarios seguidos."),
     ("You completed 7 daily challenges in a row.", "Completaste 7 retos diarios seguidos."),
     ("Indigo & Peach board", "Tablero Índigo y durazno")),
    ("habit", 100, False, ("Habit", "Hábito"),
     ("Complete 30 daily challenges in a row.", "Completa 30 retos diarios seguidos."),
     ("You completed 30 daily challenges in a row.", "Completaste 30 retos diarios seguidos."),
     ("Wave victory", "Victoria en ola")),
    ("expert", 80, False, ("Expert", "Experto"),
     ("Solve an expert sudoku.", "Resuelve un sudoku Experto."),
     ("You solved an expert sudoku.", "Resolviste un sudoku Experto."),
     ("Pen digits (Noteworthy)", "Números Pluma (Noteworthy)")),
    ("quick", 50, False, ("Quick", "Rápido"),
     ("Solve an easy sudoku in under 4 minutes.", "Resuelve un sudoku Fácil en menos de 4 minutos."),
     ("You solved an easy sudoku in under 4 minutes.", "Resolviste un sudoku Fácil en menos de 4 minutos."),
     ("Soft highlight (same digit only)", "Resaltado suave (solo el mismo número)")),
    ("nightOwl", 40, False, ("Night Owl", "Noctámbulo"),
     ("Solve a daily challenge between midnight and 4 a.m.", "Resuelve un reto diario entre la medianoche y las 4 a. m."),
     ("You solved a daily challenge in the small hours.", "Resolviste un reto diario de madrugada."),
     ("Sage & Coral board", "Tablero Salvia y coral")),
    ("centennial", 100, False, ("Centennial", "Centenario"),
     ("Solve 100 sudokus.", "Resuelve 100 sudokus."),
     ("You solved 100 sudokus.", "Resolviste 100 sudokus."),
     ("Gold app icon", "Ícono dorado")),
    ("inTheRed", 20, True, ("In the Red", "Números rojos"),
     ("Take your score below zero.", "Lleva tu puntaje por debajo de cero."),
     ("Your score went below zero. It happens.", "Tu puntaje bajó de cero. Pasa."),
     ("Hidden: hints at 3 in classic games only", "Oculta: pistas a 3 solo en clásico")),
]

LEADERBOARDS = [
    dict(id="qsu_daily_challenge", codeCase="Leaderboard.daily", type="recurring",
         recurrence="Every 1 day, starting at 05:00 UTC (00:00 in Colombia)",
         name={"en": "Daily Challenge", "es": "Reto diario"}, scoreFormat="Integer",
         formatSuffix={"en": " points", "es": " puntos"}, sortOrder="High to Low", scoreSubmission="Most recent score",
         source="Today's scored daily attempt when it's solved (AppModel.pushToGameCenter)",
         scoreRange="None (scores can be negative)"),
    dict(id="qsu_best_score", codeCase="Leaderboard.bestScore", type="classic", recurrence=None,
         name={"en": "Best Score", "es": "Mejor puntaje"}, scoreFormat="Integer",
         formatSuffix={"en": " points", "es": " puntos"}, sortOrder="High to Low", scoreSubmission="Best score",
         source="PlayerProgress.bestScore (best solved classic game)"),
    dict(id="qsu_longest_streak", codeCase="Leaderboard.longestStreak", type="classic", recurrence=None,
         name={"en": "Longest Streak", "es": "Racha más larga"}, scoreFormat="Integer",
         formatSuffix={"en": " days", "es": " días"}, sortOrder="High to Low", scoreSubmission="Best score",
         source="Longest run of completed daily challenges (AppModel.longestStreak)"),
]


def game_center_id(case):
    return "qsu_" + re.sub(r"([A-Z])", lambda m: "_" + m.group(1).lower(), case)


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


def grid(x, y, size, ink, filled=None, fill=TEAL):
    """The board as 3×3 rounded cells, like the app icon; `filled` (row, column), or "all", is solid."""
    gap = size * 0.12
    cell = (size - 2 * gap) / 3
    parts = []
    for r in range(3):
        for c in range(3):
            cx, cy = x + c * (cell + gap), y + r * (cell + gap)
            parts.append(f'<rect x="{cx:.1f}" y="{cy:.1f}" width="{cell:.1f}" height="{cell:.1f}" rx="2.5" '
                         f'fill="{ink if filled == "all" or (r, c) == filled else fill}" stroke="{ink}" stroke-width="2.5"/>')
    return "".join(parts)


def calendar(ink):
    return [
        line("M34 32 H66 a4 4 0 0 1 4 4 V68 a4 4 0 0 1 -4 4 H34 a4 4 0 0 1 -4 -4 V36 a4 4 0 0 1 4 -4 Z", ink),
        line("M30 44 H70", ink, 3.5),
        line("M41 27 V36 M59 27 V36", ink),
    ]


STAR = "M50 26 L56.5 42 L73.5 43 L60.5 54 L64.5 71 L50 62 L35.5 71 L39.5 54 L26.5 43 L43.5 42 Z"
PENCIL = "M36 66 L39 55 L61 33 L69 41 L47 63 Z M58 36 L66 44"

BADGES = {
    # The board, one cell filled.
    "qsu_first_win": (TEAL, WHITE, [grid(29, 29, 42, WHITE, filled=(2, 0))]),
    # A seal with a check: no mistakes.
    "qsu_no_mistakes": (TEAL, WHITE, [line(circle(50, 50, 21), WHITE), line("M40 50 L47 57 L61 43", WHITE)]),
    # Light bulb, crossed out (as Quiet Numbers' No Help).
    "qsu_no_hints": (TEAL, WHITE, [line(circle(50, 44, 14), WHITE), line("M44 64 H56 M45.5 71 H54.5", WHITE), line("M31 28 L69 74", WHITE)]),
    # A pencil, crossed out.
    "qsu_no_notes": (TEAL, WHITE, [line(PENCIL, WHITE), line("M30 30 L70 72", WHITE)]),
    # Two boards, one behind the other.
    # The board full: many solved.
    "qsu_ten_wins": (TEAL, WHITE, [grid(29, 29, 42, WHITE, filled="all")]),
    "qsu_consistency": (TEAL, WHITE, calendar(WHITE) + [dot(" ".join(
        [circle(x, 54, 2.8) for x in (38, 46, 54, 62)] + [circle(x, 63, 2.8) for x in (38, 46, 54)]), WHITE)]),
    "qsu_habit": (TEAL, WHITE, calendar(WHITE) + [line("M40 57 L47 64 L61 50", WHITE)]),
    # A star: the hardest level.
    "qsu_expert": (NIGHT, NIGHT_INK, [line(STAR, NIGHT_INK)]),
    # A bolt: quick.
    "qsu_quick": (TEAL, WHITE, [line("M54 26 L36 54 H50 L46 74 L64 46 H50 Z", WHITE)]),
    # Moon and stars (as Quiet Numbers' Night Owl).
    "qsu_night_owl": (NIGHT, NIGHT_INK, [line("M60 28 a22 22 0 1 0 14 38 a17 17 0 1 1 -14 -38 Z", NIGHT_INK), line("M32 30 V40 M27 35 H37", NIGHT_INK, 3.5), line("M30 56 V62 M27 59 H33", NIGHT_INK, 3)]),
    # Gold rosette (as Quiet Numbers' Centennial).
    "qsu_centennial": (GOLD, WHITE, [line(circle(50, 42, 14), WHITE), dot(circle(50, 42, 5), WHITE), line("M43 55 L37 75 L45 70 L50 77 L55 70 L63 75 L57 55", WHITE)]),
    "qsu_in_the_red": (CORAL, WHITE, [line("M30 50 H70", WHITE, 8)]),
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
    source = (ROOT / "Packages/QuietSudokuCore/Sources/QuietSudokuCore/Achievements.swift").read_text()
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
    (OUT / "game-center.md").write_text(f"""# Game Center: Quiet Sudoku

Configuración para App Store Connect, generada por `scripts/game-center.py` (también escribe `game-center.json` y las insignias, y verifica que los IDs coincidan con el código: `Achievement.gameCenterID` = "qsu_" + el caso en snake case, y `Leaderboard` en `App/AppModel.swift`). Prefijo `qsu_` (Quiet Numbers no usa prefijo y Quiet Solitaire usa `qs_`).

## Logros ({len(achievements)}, {total} / 1000 puntos)

Ninguno se puede ganar más de una vez. Cada uno lleva una imagen de 1024×1024 sin transparencia: `AppStore/achievements/<id>.png` (mismo sistema de insignias que Quiet Numbers).

| ID | Caso en el código | Puntos | Oculto | Nombre (en / es) | Descripción antes de ganarlo (en / es) | Descripción al ganarlo (en / es) | Recompensa |
|---|---|---:|---|---|---|---|---|
{rows}

Oculto: solo Números rojos (el easter egg de la familia); el resto son metas visibles para que se sepa cómo ganar cada recompensa.

## Leaderboards

| ID | Caso en el código | Nombre (en / es) | Tipo | Formato | Sufijo (en / es) | Orden | Envío | Qué se envía |
|---|---|---|---|---|---|---|---|---|
{boards}

## Notas

- El reto cambia a la medianoche de cada dispositivo (`DailyKey.rolloverHour = 0` en QuietKit). `qsu_daily_challenge` recurre cada 24 h desde las 05:00 UTC (00:00 en Colombia) y guarda el puntaje **más reciente**.
- `qsu_best_score` y `qsu_longest_streak` solo reciben valores > 0.
- Partidas guardadas (`saveGameData`): el progreso se guarda en el iCloud del jugador vía Game Center (requiere sesión). Entitlements en `App/QuietSudoku.entitlements` (contenedor `iCloud.<bundle id>`, iCloud Documents).
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
