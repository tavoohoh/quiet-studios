#!/usr/bin/env python3
"""Writes App/Resources/Localizable.xcstrings and InfoPlist.xcstrings (en source, es).

    scripts/strings.py

Keys are the English strings in code. Run after adding text to views; it fails if a key
the compiler extracted (build/dd, from `xcodebuild … -derivedDataPath build/dd`) has no
Spanish here.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent

ES = {
    "%@ of %@": "%1$@ de %2$@",
    "%@ · %@": "%1$@ · %2$@",
    "%@ · Best %@": "%1$@ · Mejor %2$@",
    "%@ · Daily challenge": "%@ · Reto diario",
    "%@ · Practice": "%@ · Práctica",
    "%@, column %lld": "%1$@, columna %2$lld",
    "%@, foundation": "%@, fundación",
    "%@, waste": "%@, descarte",
    "5 for a card from the waste to a column, 10 for each card on a foundation, 5 for each card turned over. Win in 100 moves or fewer for a 500 bonus.":
        "5 por llevar una carta del descarte a una columna, 10 por cada carta en una fundación y 5 por cada carta que se voltea. Gana en 100 movimientos o menos y suma un bono de 500.",
    "A hint shows a move that leads to a win when there is one. Each hint costs 10 points.":
        "Una pista muestra una jugada que lleva a ganar, si la hay. Cada pista cuesta 10 puntos.",
    "A tapped card goes to its best place.": "La carta va sola a su mejor sitio.",
    "Account": "Cuenta",
    "Ace": "As",
    "Achievement unlocked": "Logro desbloqueado",
    "Achievements": "Logros",
    "Always available for low vision.": "Siempre disponible para baja visión.",
    "Always available to tell suits apart.": "Siempre disponible para distinguir los palos.",
    "App icon": "Ícono de la app",
    "Auto-complete": "Autocompletar",
    "Back": "Volver",
    "Best score": "Mejor puntaje",
    "Best streak": "Mejor racha",
    "Board": "Tablero",
    "Build a column from king to ace.": "Arma una columna del rey al as.",
    "Build down in alternating colors: a red 6 on a black 7. Move a whole run at once. Only a king goes on an empty column.":
        "Baja alternando colores: un 6 rojo sobre un 7 negro. Puedes mover una escalera completa. En una columna vacía solo va un rey.",
    "Card back": "Reverso",
    "Centennial": "Centenario",
    "Check your connection and try again.": "Revisa tu conexión e inténtalo de nuevo.",
    "Classic": "Clásico",
    "Collection": "Colección",
    "Columns": "Columnas",
    "Complete 30 daily challenges in a row.": "Completa 30 retos diarios seguidos.",
    "Complete 7 daily challenges in a row.": "Completa 7 retos diarios seguidos.",
    "Completed": "Completado",
    "Consistency": "Constancia",
    "Continue": "Continuar",
    "Coral": "Coral",
    "Couldn't load": "No se pudo cargar",
    "Daily Challenge": "Reto diario",
    "Daily challenge": "Reto diario",
    "Deck": "Mazo",
    "Deletes games, daily results, streaks, achievements and unlocked rewards, here and in iCloud.":
        "Borra partidas, retos, rachas, logros y recompensas, aquí y en iCloud.",
    "Draw": "Robar",
    "Easy": "Fácil",
    "Economy": "Economía",
    "Empty": "Vacío",
    "Every classic deal can be won.": "Cada reparto clásico se puede ganar.",
    "Expert": "Experto",
    "Face-down card": "Carta boca abajo",
    "Few-moves bonus": "Bono por pocos movimientos",
    "Fifty": "Cincuenta",
    "First Hand": "Primera mano",
    "Follows your device's light or dark mode.": "Sigue el modo claro u oscuro de tu dispositivo.",
    "Four colors": "Cuatro colores",
    "Friends": "Amigos",
    "Game Center": "Game Center",
    "Game points": "Puntos de juego",
    "Global": "Global",
    "Goal": "Objetivo",
    "Gold": "Dorado",
    "Habit": "Hábito",
    "Haptics": "Hápticos",
    "Hard": "Difícil",
    "High contrast": "Alto contraste",
    "Hint": "Pista",
    "Hints": "Pistas",
    "Home": "Inicio",
    "How to play": "Cómo jugar",
    "Illustrated": "Ilustrado",
    "In progress": "En curso",
    "In the Red": "Números rojos",
    "Indigo & Peach": "Índigo y durazno",
    "Jack": "Jota",
    "King": "Rey",
    "Ladder": "Escalera",
    "Large index": "Índice grande",
    "Leaderboards": "Clasificaciones",
    "Left-handed": "Modo zurdo",
    "Linen": "Lino",
    "Medium": "Media",
    "Monday and Tuesday easy, Wednesday to Friday medium, Saturday hard, Sunday expert.":
        "Lunes y martes fácil, de miércoles a viernes media, sábado difícil, domingo experto.",
    "More": "Más",
    "Move all 52 cards to the four foundations, one per suit, from ace to king.":
        "Lleva las 52 cartas a las cuatro fundaciones, una por palo, del as al rey.",
    "Moves": "Movimientos",
    "New Game": "Nueva partida",
    "New record!": "¡Nuevo récord!",
    "Next challenge in %@": "Próximo reto en %@",
    "Next month": "Mes siguiente",
    "Night": "Noche",
    "Night Owl": "Noctámbulo",
    "No Going Back": "Sin vuelta atrás",
    "No moves left. Try undo.": "No quedan jugadas. Prueba deshacer.",
    "No scores yet": "Aún no hay puntajes",
    "No way to win from here": "Desde aquí ya no se puede ganar",
    "Not played yet": "Aún no lo juegas",
    "Not signed in": "Sin sesión",
    "One Pass": "Una sola vuelta",
    "One deal for everyone each day, always winnable. Easy on Monday, expert on Sunday.":
        "Un reparto para todos cada día, que siempre se puede ganar. Fácil el lunes, experto el domingo.",
    "Only winnable deals": "Solo partidas con solución",
    "Open Settings": "Abrir Ajustes",
    "Past days are practice: they don't count toward your streak.": "Los días pasados son práctica: no cuentan para la racha.",
    "Pixel": "Pixel",
    "Play": "Jugar",
    "Play again": "Jugar de nuevo",
    "Play with friends": "Juega con amigos",
    "Played": "Jugado",
    "Practiced": "Practicado",
    "Previous month": "Mes anterior",
    "Privacy": "Privacidad",
    "Queen": "Reina",
    "Quiet": "Quiet",
    "Quiet Solitaire doesn't collect any data. Your games, streaks and achievements stay on this device. If you sign in to Game Center, your scores and achievements are shared with Apple's Game Center and your progress is saved in your iCloud.":
        "Quiet Solitaire no recolecta ningún dato. Tus partidas, rachas y logros se quedan en este dispositivo. Si inicias sesión en Game Center, tus puntajes y logros se comparten con Game Center de Apple y tu progreso se guarda en tu iCloud.",
    "Replays don't count toward your score.": "Las repeticiones no cuentan para tu puntaje.",
    "Reset Progress": "Restablecer progreso",
    "Reset Progress…": "Restablecer progreso…",
    "Reset all progress?": "¿Restablecer todo el progreso?",
    "Restart This Deal": "Reiniciar este reparto",
    "Sage & Coral": "Salvia y coral",
    "Sage & Sand": "Salvia y arena",
    "Score": "Puntaje",
    "Score %lld": "Puntaje %lld",
    "Scores from Game Center · updated just now": "Puntajes de Game Center · actualizado hace un momento",
    "Settings": "Ajustes",
    "Sign in to Game Center in Settings to see leaderboards. Your progress is saved on this device either way.":
        "Inicia sesión en Game Center para ver las clasificaciones. Tu progreso se guarda en este dispositivo de todos modos.",
    "Signed in as %@": "Sesión iniciada como %@",
    "Sound": "Sonido",
    "Standard": "Estándar",
    "Steady Hand": "A pulso",
    "Stock": "Mazo",
    "Stock and waste on the left.": "Mazo y descarte a la izquierda.",
    "Streak": "Racha",
    "Take your score below zero.": "Lleva tu puntaje por debajo de cero.",
    "Tap a card to send it to its best place, or drag it where you want.": "Toca una carta para mandarla a su mejor sitio, o arrástrala a donde quieras.",
    "Tap or drag": "Toca o arrastra",
    "Tap the stock to turn one card. When it runs out, tap again to turn the waste over. As many times as you like.":
        "Toca el mazo para voltear una carta. Cuando se acabe, tócalo otra vez para dar vuelta el descarte. Todas las veces que quieras.",
    "Tap to move": "Tocar para mover",
    "Teal & Coral": "Petróleo y coral",
    "Teal & Coral Dark": "Petróleo y coral oscuro",
    "Teal & Coral Light": "Petróleo y coral claro",
    "Ten Wins": "Diez victorias",
    "Theme": "Del tema",
    "This week": "Dificultad de la semana",
    "Today": "Hoy",
    "Today: %@": "Hoy: %@",
    "Top streak": "Mejor racha",
    "Turn the waste over": "Dar vuelta el descarte",
    "Undo": "Deshacer",
    "Unlocked": "Desbloqueado",
    "Version": "Versión",
    "Victory": "Victoria",
    "Win 10 games.": "Gana 10 partidas.",
    "Win 100 games.": "Gana 100 partidas.",
    "Win 50 games.": "Gana 50 partidas.",
    "Win a daily challenge between midnight and 4 a.m.": "Gana un reto diario entre la medianoche y las 4 a. m.",
    "Win in fewer than 100 moves.": "Gana en menos de 100 movimientos.",
    "Win without hints.": "Gana sin pistas.",
    "Win without recycling the stock.": "Gana sin reciclar el mazo.",
    "Win without undo.": "Gana sin deshacer.",
    "Win your first game.": "Gana tu primera partida.",
    "Wins": "Victorias",
    "Won": "Ganadas",
    "Won · %@": "Ganado · %@",
    "You won!": "¡Ganaste!",
    "Your 5-minute break.": "Tu pausa de 5 minutos.",
    "Your games, daily challenge results, streaks, achievements and unlocked rewards will be deleted on this device and in iCloud. Scores already on Game Center leaderboards stay there. This can't be undone.":
        "Se borrarán tus partidas, retos, rachas, logros y recompensas en este dispositivo y en iCloud. Los puntajes que ya están en las clasificaciones de Game Center se quedan ahí. No se puede deshacer.",
    "Your stats": "Tus estadísticas",
    "Turn a card": "Voltea una carta",
    "Tap the stock to turn its top card over onto the waste.": "Toca el mazo para voltear su primera carta al descarte.",
    "Red on black": "Rojo sobre negro",
    "Cards go on a column one rank lower and in the other color. Tap the 7♥ to put it on the 8♠.": "En una columna, cada carta va sobre una de un número más y del otro color. Toca el 7♥ para ponerlo sobre el 8♠.",
    "Aces first": "Primero los ases",
    "Each suit builds up from its ace in the foundations at the top. Tap the A♦. The card under it turns over.": "Cada palo se arma desde su as en las fundaciones de arriba. Toca el A♦. La carta de abajo se voltea.",
    "Move a run": "Mueve una escalera",
    "A run in order moves together. Tap the 8♠ to move it with the 7♥ onto the 9♥.": "Una escalera en orden se mueve completa. Toca el 8♠ para llevarlo con el 7♥ sobre el 9♥.",
    "Keep building": "Sigue subiendo",
    "The 2♦ goes on the A♦. Foundations go up to the king.": "El 2♦ va sobre el A♦. Las fundaciones suben hasta el rey.",
    "Keep playing": "Seguir jugando",
    "Time": "Tiempo",
    "Best": "Mejor",
    "Daily": "Reto",
    "Practice": "Práctica",
    "Undo to go back, or start a new game.": "Deshace para volver atrás, o empieza una partida nueva.",
    "Fireworks": "Fuegos artificiales",
    "Cascade and fireworks": "Cascada y fuegos artificiales",
    "Time ×%@": "Tiempo ×%@",
    "Spades complete!": "¡Picas completas!",
    "Hearts complete!": "¡Corazones completos!",
    "Diamonds complete!": "¡Diamantes completos!",
    "Clubs complete!": "¡Tréboles completos!",
    "Achievements unlocked": "Logros desbloqueados",
    "All cards face up!": "¡Todas las cartas a la vista!",
    "Kings on empty columns": "Reyes en columnas vacías",
    "Only a king goes on an empty column. Tap the K♣. You can also drag any card where you want it.": "En una columna vacía solo va un rey. Toca el K♣. También puedes arrastrar cualquier carta a donde quieras.",
    "You're ready": "Ya sabes jugar",
    "Move every card to the foundations to win. Stuck? Undo, or ask for a hint for a few points.": "Lleva todas las cartas a las fundaciones para ganar. ¿Te trabaste? Deshace o pide una pista por unos puntos.",
    "Start playing": "Empezar a jugar",
    "Done": "Listo",
    "Skip": "Saltar",
    "Rules": "Reglas",
    "Step %lld of %lld": "Paso %1$lld de %2$lld",
    "clubs": "tréboles",
    "diamonds": "diamantes",
    "hearts": "corazones",
    "spades": "picas",
}

# Plurals: key → (en one, en other, es one, es other).
PLURALS = {
    "%lld moves": ("%lld move", "%lld moves", "%lld movimiento", "%lld movimientos"),
    "%lld-day streak": ("%lld-day streak", "%lld-day streak", "Racha de %lld día", "Racha de %lld días"),
    "Continue · %lld moves": ("Continue · %lld move", "Continue · %lld moves", "Continuar · %lld movimiento", "Continuar · %lld movimientos"),
    "Stock, %lld cards": ("Stock, %lld card", "Stock, %lld cards", "Mazo, %lld carta", "Mazo, %lld cartas"),
}

# Not translated: ranks shown as is, and the empty key.
VERBATIM = {"", "2", "3", "4", "5", "6", "7", "8", "9", "10"}


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def plural(one, other):
    return {"variations": {"plural": {"one": unit(one), "other": unit(other)}}}


def extracted_keys():
    keys = set()
    for f in (ROOT / "build/dd").rglob("*.stringsdata"):
        if "QuietSolitaire.build" not in str(f):
            continue
        data = json.loads(f.read_text())
        for entries in data.get("tables", {}).values():
            keys.update(e["key"] for e in entries)
    return keys


def main():
    strings = {}
    for key, es in ES.items():
        strings[key] = {"localizations": {"es": unit(es)}}
    for key, (en_one, en_other, es_one, es_other) in PLURALS.items():
        strings[key] = {"localizations": {"en": plural(en_one, en_other), "es": plural(es_one, es_other)}}
    for key in VERBATIM:
        strings[key] = {"shouldTranslate": False}
    catalog = {"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}
    (ROOT / "App/Resources/Localizable.xcstrings").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")

    info = {"sourceLanguage": "en", "version": "1.0", "strings": {
        "CFBundleDisplayName": {"shouldTranslate": False},
        "CFBundleName": {"shouldTranslate": False},
        "NSGKFriendListUsageDescription": {"localizations": {
            "en": unit("Show your Game Center friends on Quiet Solitaire leaderboards."),
            "es": unit("Muestra a tus amigos de Game Center en las clasificaciones de Quiet Solitaire.")}},
    }}
    (ROOT / "App/Resources/InfoPlist.xcstrings").write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n")

    missing = sorted(extracted_keys() - set(strings))
    for key in missing:
        print(f"Missing Spanish: {key!r}")
    if missing:
        sys.exit(1)
    print(f"{len(strings)} strings written; every extracted key has Spanish.")


if __name__ == "__main__":
    main()
