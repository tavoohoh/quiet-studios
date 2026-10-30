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
    "Cancel": "Cancelar",
    "Continue this practice?": "¿Seguir con esta práctica?",
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
    "Past days are practice: they don't score, but winning one counts toward your streak.":
        "Los días pasados son práctica: no suman puntaje, pero ganarlos cuenta para tu racha.",
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
    "Quiet Sudoku doesn't collect any data. Your games, streaks and achievements stay on this device. If you sign in to Game Center, your scores and achievements are shared with Apple's Game Center and your progress is saved in your iCloud.":
        "Quiet Sudoku no recolecta ningún dato. Tus partidas, rachas y logros se quedan en este dispositivo. Si inicias sesión en Game Center, tus puntajes y logros se comparten con Game Center de Apple y tu progreso se guarda en tu iCloud.",
    "Start over": "Empezar de nuevo",
    "You left %@ halfway.": "Dejaste el %@ a medias.",
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
    # Daily reminders (notification texts are this app's).
    "%@ won today's challenge with %@. Up for it?": "%1$@ ganó el reto de hoy con %2$@. ¿Te animas?",
    "%lld friends already played; %@ leads with %@.": "%1$lld amigos ya lo jugaron; %2$@ lidera con %3$@.",
    "Don't lose your %lld-day streak.": "No pierdas tu racha de %lld días.",
    "Today's challenge is waiting.": "El reto de hoy te espera.",
    "Your %lld-day streak ends at midnight.": "Tu racha de %lld días termina a medianoche.",
    "Your streak": "Tu racha",
    "Opens their profile": "Abre su perfil",
}

# Quiet Sudoku (2026-10-30).
ES.update({
    "10 to 30 points per digit, by level. Solve it for 500 more, doubled if you're fast.":
        "De 10 a 30 puntos por número, según el nivel. Al resolverlo, 500 más, el doble si eres rápido.",
    "2-String Kite": "Cometa (2-String Kite)",
    "A cell {x, y, z} sees cells {x, z} and {y, z}. One of the three is z, so a cell seeing all three can't be z.":
        "Una casilla {x, y, z} ve a las casillas {x, z} e {y, z}. Una de las tres es z, así que una casilla que ve a las tres no puede ser z.",
    "A cell {x, y} sees cells {x, z} and {y, z}. One of those two is z, so a cell seeing both can't be z.":
        "Una casilla {x, y} ve a las casillas {x, z} e {y, z}. Una de esas dos es z, así que una casilla que ve a ambas no puede ser z.",
    "A cell's row, column and box already hold eight different digits: the ninth goes there.":
        "La fila, la columna y la caja de una casilla ya tienen ocho números distintos: el noveno va ahí.",
    "A digit fits twice on two rows, in the same two columns. It takes those columns there, so not elsewhere in them (or rows and columns swapped).":
        "Un número cabe dos veces en dos filas, en las mismas dos columnas. Ocupa esas columnas ahí, así que no va en el resto de ellas (o al revés, con filas y columnas).",
    "A digit that isn't the solution's is a mistake and costs 20 points, shown right away or not. The game never ends: fix it and go on.":
        "Un número que no es el de la solución es un error y cuesta 20 puntos, se marque al instante o no. La partida nunca se pierde: corrígelo y sigue.",
    "A hint writes the next digit you can find by logic and explains why. Each hint costs 10 points.":
        "Una pista escribe el siguiente número que se puede deducir y explica por qué. Cada pista cuesta 10 puntos.",
    "A row and a column with two spots each for a digit, linked through a box. One of the far ends holds it: a cell seeing both can't.":
        "Una fila y una columna con dos lugares cada una para un número, unidas por una caja. Uno de los extremos lejanos lo tiene: una casilla que ve a ambos no puede tenerlo.",
    "A row, column or box with one empty cell: it takes the missing digit.":
        "Una fila, columna o caja con una sola casilla vacía: lleva el número que falta.",
    "A wrong digit is a mistake: it costs 20 points, and the game goes on. Stuck? Tap Hint: it writes the next digit and says why, for 10 points.":
        "Un número equivocado es un error: cuesta 20 puntos y la partida sigue. ¿Atascado? Toca Pista: escribe el siguiente número y dice por qué, por 10 puntos.",
    "And boxes": "Y las cajas",
    "Bigger digits and notes on the board.": "Números y notas más grandes en el tablero.",
    "Box and line": "Caja y línea",
    "Choose a level": "Elige un nivel",
    "Clean Sheet": "Sin tachones",
    "Close": "Cerrar",
    "Columns too": "También las columnas",
    "Continue · %@": "Continuar · %@",
    "Digits": "Números",
    "Each 3×3 box needs 1 to 9 once too. Fill the empty cell of this box.":
        "Cada caja de 3×3 también lleva del 1 al 9 una vez. Llena la casilla vacía de esta caja.",
    "Each row holds 1 to 9": "Cada fila lleva del 1 al 9",
    "Easy needs only the basics. Each level up needs one more kind of reasoning.":
        "Fácil solo pide lo básico. Cada nivel más pide un tipo de razonamiento más.",
    "Erase": "Borrar",
    "Every Quiet Sudoku can be solved with these, without guessing. A puzzle's level is the hardest one it needs. A house is a row, a column or a box.":
        "Todo Quiet Sudoku se resuelve con estas técnicas, sin adivinar. El nivel de un sudoku es la más difícil que necesita. Un grupo es una fila, una columna o una caja.",
    "Every column also needs 1 to 9 once. Which digit is missing from this column?":
        "Cada columna también lleva del 1 al 9 una vez. ¿Qué número le falta a esta columna?",
    "Every row needs the digits 1 to 9, once each. This row is missing one: tap it on the keypad.":
        "Cada fila lleva los números del 1 al 9, una vez cada uno. A esta fila le falta uno: tócalo en el teclado.",
    "Fill every row, column and box with 1 to 9. Start with an easy one: it needs only what you just learned.":
        "Llena cada fila, columna y caja con el 1 al 9. Empieza con uno Fácil: solo necesita lo que acabas de aprender.",
    "Fill the grid so every row, every column and every 3×3 box holds the digits 1 to 9 once each.":
        "Llena la cuadrícula para que cada fila, cada columna y cada caja de 3×3 tenga los números del 1 al 9 una vez cada uno.",
    "Find where the %lld goes in this box. The ringed %llds rule out every other empty cell: their rows and columns already have one.":
        "Busca dónde va el %1$lld en esta caja. Los %2$lld con anillo descartan las demás casillas vacías: sus filas y columnas ya tienen uno.",
    "First Sudoku": "Primer sudoku",
    "From Memory": "De memoria",
    "Hidden pair": "Par oculto",
    "Hidden triple": "Trío oculto",
    "Highlight": "Resaltado",
    "Hints %lld × −%lld": "Pistas %1$lld × −%2$lld",
    "In %@, the %lld fits only here.": "En %1$@, el %2$lld solo cabe aquí.",
    "In a box, a digit's only cells lie on one line. It must be there, so it's not elsewhere on that line.":
        "En una caja, los únicos lugares de un número están en una misma línea. Tiene que ir ahí, así que no va en el resto de esa línea.",
    "In a row, column or box, a digit fits in only one cell because its other copies rule out the rest.":
        "En una fila, columna o caja, un número cabe en una sola casilla porque sus otras copias descartan las demás.",
    "In color": "En color",
    "It's the last empty cell of %@: the %lld goes here.": "Es la última casilla vacía de %1$@: aquí va el %2$lld.",
    "Large digits": "Números grandes",
    "Last empty cell": "Última casilla",
    "Level": "Nivel",
    "Like an X-Wing with three rows and three columns.": "Como un X-Wing, con tres filas y tres columnas.",
    "Mistake": "Error",
    "Mistakes": "Errores",
    "Mistakes %lld × −%lld": "Errores %1$lld × −%2$lld",
    "Mistakes and hints": "Errores y pistas",
    "Naked pair": "Par desnudo",
    "Naked triple": "Trío desnudo",
    "Not sure yet? Take notes. With Notes on, tap %@: the digits that could still go here.":
        "¿Todavía no sabes? Toma notas. Con Notas activado, toca %@: los números que todavía pueden ir aquí.",
    "Note %lld": "Nota %lld",
    "Notes": "Notas",
    "Off": "Desactivado",
    "Off: they're checked when the board is full. Each mistake costs the same either way.":
        "Apagado: se revisan al llenar el tablero. Cada error cuesta lo mismo de las dos formas.",
    "On": "Activado",
    "On Your Own": "Por tu cuenta",
    "On a row or column, a digit's only cells lie in one box. It's not in the rest of that box.":
        "En una fila o columna, los únicos lugares de un número están en una misma caja. No va en el resto de esa caja.",
    "One sudoku for everyone each day, with one solution and no guessing. Easy on Monday, expert on Sunday.":
        "Un sudoku para todos cada día, con una sola solución y sin adivinar. Fácil el lunes, experto el domingo.",
    "Only digit": "Único posible",
    "Only place": "Único lugar",
    "Only the %lld fits here: its row, column and box hold the other eight.":
        "Aquí solo cabe el %lld: su fila, su columna y su caja tienen los otros ocho.",
    "Pen": "Pluma",
    "Plain": "Sencillas",
    "Pointing": "Apuntando",
    "Quick": "Rápido",
    "Restart This Sudoku": "Reiniciar este sudoku",
    "Rounded": "Redondos",
    "Row %lld, column %lld, %lld": "Fila %1$lld, columna %2$lld, %3$lld",
    "Row %lld, column %lld, %lld, wrong": "Fila %1$lld, columna %2$lld, %3$lld, equivocado",
    "Row %lld, column %lld, empty": "Fila %1$lld, columna %2$lld, vacía",
    "Row %lld, column %lld, empty, notes %@": "Fila %1$lld, columna %2$lld, vacía, notas %3$@",
    "Row, column and box": "Fila, columna y caja",
    "Same digit only": "Solo el mismo número",
    "Show mistakes right away": "Marcar errores al instante",
    "Skyscraper": "Rascacielos (Skyscraper)",
    "Solve 10 sudokus.": "Resuelve 10 sudokus.",
    "Solve 100 sudokus.": "Resuelve 100 sudokus.",
    "Solve a daily challenge between midnight and 4 a.m.": "Resuelve un reto diario entre la medianoche y las 4 a. m.",
    "Solve a medium or harder sudoku without notes.": "Resuelve un sudoku de nivel Media o más sin notas.",
    "Solve a sudoku without hints.": "Resuelve un sudoku sin pistas.",
    "Solve a sudoku without mistakes.": "Resuelve un sudoku sin errores.",
    "Solve an easy sudoku in under 4 minutes.": "Resuelve un sudoku Fácil en menos de 4 minutos.",
    "Solve an expert sudoku.": "Resuelve un sudoku Experto.",
    "Solve bonus": "Bono por resolver",
    "Solve your first sudoku.": "Resuelve tu primer sudoku.",
    "Solved!": "¡Resuelto!",
    "Swordfish": "Swordfish",
    "Tap a cell, then a digit. Digits in dark ink came with the puzzle and can't change.":
        "Toca una casilla y luego un número. Los números en tinta oscura vienen con el sudoku y no se cambian.",
    "Techniques": "Técnicas",
    "Ten Sudokus": "Diez sudokus",
    "This cell's row, column and box already hold eight different digits. Which one is left?":
        "La fila, la columna y la caja de esta casilla ya tienen ocho números distintos. ¿Cuál queda?",
    "This digit doesn't go here. It's been cleared.": "Este número no va aquí. Se borró.",
    "Three cells of a house holding only three digits between them: not elsewhere in the house.":
        "Tres casillas de un grupo con solo tres números entre ellas: esos números no van en el resto del grupo.",
    "Three digits that fit in only the same three cells of a house: those cells hold nothing else.":
        "Tres números que caben solo en las mismas tres casillas de un grupo: esas casillas no llevan otra cosa.",
    "To see it, first rule out candidates with %@. See Settings › Techniques.":
        "Para verlo, primero hay que descartar candidatos con %@. Mira Ajustes › Técnicas.",
    "Turn on Notes to jot the digits that could go in a cell. A digit you place clears itself from the notes it sees.":
        "Activa Notas para anotar los números que podrían ir en una casilla. Al poner un número, se borra de las notas que ve.",
    "Two cells of a house with the same two candidates: those digits go there, so not in the house's other cells.":
        "Dos casillas de un grupo con los mismos dos candidatos: esos números van ahí, así que no en las demás casillas del grupo.",
    "Two cells {x, y} linked by a house where x has two spots, one seen by each. One of the two cells is y: a cell seeing both can't be.":
        "Dos casillas {x, y} unidas por un grupo donde x tiene dos lugares, cada uno visto por una. Una de las dos casillas es y: una casilla que ve a ambas no puede serlo.",
    "Two digits that fit in only the same two cells of a house: those cells hold nothing else.":
        "Dos números que caben solo en las mismas dos casillas de un grupo: esas casillas no llevan otra cosa.",
    "Two rows with two spots each for a digit, one pair lined up. One of the other two ends holds it: a cell seeing both can't.":
        "Dos filas con dos lugares cada una para un número, un par alineado. Uno de los otros dos extremos lo tiene: una casilla que ve a ambos no puede tenerlo.",
    "Typewriter": "Máquina",
    "W-Wing": "W-Wing",
    "Wave and fireworks": "Ola y fuegos artificiales",
    "X-Wing": "X-Wing",
    "XY-Wing": "XY-Wing",
    "XYZ-Wing": "XYZ-Wing",
    "box %lld": "la caja %lld",
    "column %lld": "la columna %lld",
    "row %lld": "la fila %lld",
})

# QuietKit's texts (QuietUI looks them up in the app's catalog). The compiler doesn't
# extract them for the app, so they're listed here by hand.
KIT = {
    "Remind you at %@?": "¿Te aviso a las %@?",
    "Remind me": "Avísame",
    "Not now": "Ahora no",
    "Only on days you haven't played the challenge yet. You can change it in Settings.":
        "Solo los días que aún no hayas jugado el reto. Puedes cambiarlo en Ajustes.",
    "Daily challenge reminder": "Recordatorio del reto",
    "At %@ if you haven't played; with a streak of 3 or more, another at %@.":
        "A las %1$@ si no has jugado; con una racha de 3 o más, otro a las %2$@.",
    "Notifications are off for this app. Turn them on in Settings.":
        "Las notificaciones de esta app están desactivadas. Actívalas en Ajustes.",
    "Friends today": "Amigos hoy",
    "You're #%lld": "Vas #%lld",
    "None of your friends has played today's challenge yet.": "Ninguno de tus amigos ha jugado el reto de hoy.",
    "Couldn't load this profile. Check your connection and try again.":
        "No se pudo cargar este perfil. Revisa tu conexión e inténtalo de nuevo.",
    "View in Game Center": "Ver en Game Center",
    "You": "Tú",
    "Today's challenge": "Reto de hoy",
    "Best score": "Mejor puntaje",
    "Longest streak": "Racha más larga",
    "Last %lld challenges": "Últimos %lld retos",
    "You won %lld of %lld": "Ganaste %1$lld de %2$lld",
    "No past challenges yet.": "Todavía no hay retos anteriores.",
}

# Plurals: key → (en one, en other, es one, es other).
PLURALS = {
    "%lld digits don't fit. Fix them.": ("%lld digit doesn't fit. Fix it.", "%lld digits don't fit. Fix them.", "%lld número no va. Corrígelo.", "%lld números no van. Corrígelos."),
    "%lld left": ("%lld left", "%lld left", "Queda %lld", "Quedan %lld"),
    "%lld moves": ("%lld move", "%lld moves", "%lld movimiento", "%lld movimientos"),
    "%lld-day streak": ("%lld-day streak", "%lld-day streak", "Racha de %lld día", "Racha de %lld días"),
    "Continue · %lld moves": ("Continue · %lld move", "Continue · %lld moves", "Continuar · %lld movimiento", "Continuar · %lld movimientos"),
    "Stock, %lld cards": ("Stock, %lld card", "Stock, %lld cards", "Mazo, %lld carta", "Mazo, %lld cartas"),
}

# Not translated: ranks shown as is, and the empty key.
VERBATIM = {"", "%lld", "2", "3", "4", "5", "6", "7", "8", "9", "10"}


def unit(value):
    return {"stringUnit": {"state": "translated", "value": value}}


def plural(one, other):
    return {"variations": {"plural": {"one": unit(one), "other": unit(other)}}}


def extracted_keys():
    keys = set()
    for f in (ROOT / "build/dd").rglob("*.stringsdata"):
        if "QuietSudoku.build" not in str(f):
            continue
        data = json.loads(f.read_text())
        for entries in data.get("tables", {}).values():
            keys.update(e["key"] for e in entries)
    return keys


def main():
    strings = {}
    used = extracted_keys()
    # Only what the app uses (the extracted keys) plus the kit's texts: no stale entries.
    for key, es in ES.items():
        if key in used:
            strings[key] = {"localizations": {"es": unit(es)}}
    for key, es in KIT.items():
        strings[key] = {"localizations": {"es": unit(es)}}
    for key, (en_one, en_other, es_one, es_other) in PLURALS.items():
        if key not in used:
            continue
        strings[key] = {"localizations": {"en": plural(en_one, en_other), "es": plural(es_one, es_other)}}
    for key in VERBATIM:
        strings[key] = {"shouldTranslate": False}
    catalog = {"sourceLanguage": "en", "strings": dict(sorted(strings.items())), "version": "1.0"}
    (ROOT / "App/Resources/Localizable.xcstrings").write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + "\n")

    info = {"sourceLanguage": "en", "version": "1.0", "strings": {
        "CFBundleDisplayName": {"shouldTranslate": False},
        "CFBundleName": {"shouldTranslate": False},
        "NSGKFriendListUsageDescription": {"localizations": {
            "en": unit("Show your Game Center friends on Quiet Sudoku leaderboards."),
            "es": unit("Muestra a tus amigos de Game Center en las clasificaciones de Quiet Sudoku.")}},
    }}
    (ROOT / "App/Resources/InfoPlist.xcstrings").write_text(json.dumps(info, ensure_ascii=False, indent=2) + "\n")

    missing = sorted(used - set(strings))
    for key in missing:
        print(f"Missing Spanish: {key!r}")
    if missing:
        sys.exit(1)
    print(f"{len(strings)} strings written; every extracted key has Spanish.")


if __name__ == "__main__":
    main()
