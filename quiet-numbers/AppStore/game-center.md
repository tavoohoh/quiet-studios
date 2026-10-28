# Game Center: Quiet Numbers

Configuración para App Store Connect. La fuente de los IDs es el código: `Achievement.gameCenterID` en `App/Services/GameCenterService.swift` y `GameCenterService.Leaderboard`. El JSON equivalente está en `game-center.json`; `scripts/check-game-center.py` verifica que coincidan con el código.

## Logros (11, 620 / 1000 puntos)

Ninguno se puede ganar más de una vez. Cada uno lleva una imagen de 1024×1024 sin transparencia: `AppStore/achievements/<id>.png`, generadas con `scripts/render-artwork.py` (insignias del canvas de diseño, página 4).

| ID | Caso en el código | Puntos | Oculto | Nombre (en / es) | Descripción antes de ganarlo (en / es) | Descripción al ganarlo (en / es) | Recompensa |
|---|---|---:|---|---|---|---|---|
| `first_step` | `firstStep` | 10 | No | First Step / Primer paso | Clear your first board or finish your first game. / Vacía tu primer tablero o termina tu primera partida. | You cleared your first board or finished your first game. / Vaciaste tu primer tablero o terminaste tu primera partida. | Tema Petróleo y coral (por defecto) |
| `clean_slate` | `cleanSlate` | 30 | No | Clean Slate / Tabla rasa | Clear a board without using +. / Vacía un tablero sin usar +. | You cleared a board without using +. / Vaciaste un tablero sin usar +. | Fichas: círculo |
| `no_help` | `noHelp` | 50 | No | No Help / Sin ayuda | Clear a board without using hints. / Vacía un tablero sin usar pistas. | You cleared a board without a single hint. / Vaciaste un tablero sin usar ni una pista. | Tema Salvia y arena |
| `consistency` | `consistency` | 80 | No | Consistency / Constancia | Complete 7 daily challenges in a row. / Completa 7 retos diarios seguidos. | You completed 7 daily challenges in a row. / Completaste 7 retos diarios seguidos. | Tema Índigo y durazno |
| `habit` | `habit` | 100 | No | Habit / Hábito | Complete 30 daily challenges in a row. / Completa 30 retos diarios seguidos. | You completed 30 daily challenges in a row. / Completaste 30 retos diarios seguidos. | Tipografía New York (serif) |
| `sweeper` | `sweeper` | 60 | No | Sweeper / Barrendero | Clear 100 rows. / Limpia 100 filas. | You cleared 100 rows. / Limpiaste 100 filas. | Efecto de limpieza: ola |
| `stage_five` | `stageFive` | 70 | No | Stage 5 / Etapa 5 | Reach stage 5 in one game. / Llega a la etapa 5 en una partida. | You reached stage 5 in one game. / Llegaste a la etapa 5 en una partida. | Fichas: contorno |
| `centennial` | `centennial` | 100 | No | Centennial / Centenario | Complete 100 daily challenges. / Completa 100 retos diarios. | You completed 100 daily challenges. / Completaste 100 retos diarios. | Ícono dorado (iPhone y iPad) |
| `night_owl` | `nightOwl` | 40 | Sí | Night Owl / Noctámbulo | Complete a daily challenge between midnight and 4 a.m. / Completa un reto diario entre la medianoche y las 4 a. m. | You completed a daily challenge in the small hours. / Completaste un reto diario de madrugada. | Tema Salvia y coral |
| `monotone` | `monotone` | 60 | Sí | Monotone / Monótono | Make 10 pairs of equal numbers in a row. / Haz 10 parejas de números iguales seguidas. | You made 10 pairs of equal numbers in a row. / Hiciste 10 parejas de números iguales seguidas. | Pack de sonido: marimba |
| `in_the_red` | `inTheRed` | 20 | Sí | In the Red / Números rojos | Take your score below zero. / Lleva tu puntaje por debajo de cero. | Your score went below zero. It happens. / Tu puntaje bajó de cero. Pasa. | Oculta: pistas a 3 fuera del reto diario |

Ocultos: Noctámbulo, Monótono y Números rojos son sorpresas; el resto son metas visibles.

## Leaderboards

| ID | Caso en el código | Nombre (en / es) | Tipo | Formato | Sufijo (en / es) | Orden | Envío | Qué se envía |
|---|---|---|---|---|---|---|---|---|
| `daily_challenge` | `daily` | Daily Challenge / Reto diario | Recurrente (Every 1 day, starting at 05:00 UTC (00:00 in Colombia)) | Entero | " points" / " puntos" | Mayor a menor | **Más reciente** | El intento puntuable del día, siempre que termine, aunque sea 0 o negativo (`AppModel.pushToGameCenter`). Sin rango de puntaje, para aceptar negativos. |
| `best_score` | `bestScore` | Best Score / Mejor puntaje | Clásico | Entero | " points" / " puntos" | Mayor a menor | Mejor puntaje | PlayerProgress.bestScore (classic games, including abandoned ones) |
| `longest_streak` | `longestStreak` | Longest Streak / Racha más larga | Clásico | Entero | " days" / " días" | Mayor a menor | Mejor puntaje | Longest run of completed daily challenges (AppModel.longestStreak) |

## Notas

- El reto cambia a la medianoche de cada dispositivo. `daily_challenge` recurre cada 24 h desde las 05:00 UTC (00:00 en Colombia) y guarda el puntaje **más reciente**: cada envío cae en la ventana UTC vigente al terminar. Fuera de UTC-5 un mismo reto puede quedar en la ventana anterior o siguiente.
- `best_score` y `longest_streak` solo reciben valores > 0.
- Partidas guardadas (`saveGameData`): el progreso se guarda en el iCloud del jugador vía Game Center (requiere sesión). Entitlements en `App/QuietNumbers.entitlements` (contenedor `iCloud.<bundle id>`, iCloud Documents); falta activar iCloud en el App ID y crear el contenedor.
- Restablecer progreso (Ajustes) borra el guardado de iCloud y reinicia los logros con `GKAchievement.resetAchievements()`. Los puntajes ya enviados a leaderboards no se pueden retirar.
