# Game Center: Quiet Solitaire

Configuración para App Store Connect, generada por `scripts/game-center.py` (también escribe `game-center.json` y las insignias, y verifica que los IDs coincidan con el código: `Achievement.gameCenterID` = "qs_" + el caso en snake case, y `Leaderboard` en `App/AppModel.swift`). Prefijo `qs_` para no chocar con Quiet Numbers.

## Logros (13, 710 / 1000 puntos)

Ninguno se puede ganar más de una vez. Cada uno lleva una imagen de 1024×1024 sin transparencia: `AppStore/achievements/<id>.png` (mismo sistema de insignias que Quiet Numbers).

| ID | Caso en el código | Puntos | Oculto | Nombre (en / es) | Descripción antes de ganarlo (en / es) | Descripción al ganarlo (en / es) | Recompensa |
|---|---|---:|---|---|---|---|---|
| `qs_first_win` | `firstWin` | 10 | No | First Hand / Primera mano | Win your first game. / Gana tu primera partida. | You won your first game. / Ganaste tu primera partida. | Mazo Quiet, reverso del tema, tablero Petróleo y coral (por defecto) |
| `qs_no_undo` | `noUndo` | 30 | No | No Going Back / Sin vuelta atrás | Win without undo. / Gana sin deshacer. | You won without a single undo. / Ganaste sin deshacer ni una vez. | Reverso Coral |
| `qs_no_hints` | `noHints` | 40 | No | Steady Hand / A pulso | Win without hints. / Gana sin pistas. | You won without a single hint. / Ganaste sin usar ni una pista. | Tablero Salvia y arena |
| `qs_one_pass` | `onePass` | 50 | No | One Pass / Una sola vuelta | Win without recycling the stock. / Gana sin reciclar el mazo. | You won going through the stock only once. / Ganaste recorriendo el mazo una sola vez. | Mazo Clásico |
| `qs_ten_wins` | `tenWins` | 40 | No | Ten Wins / Diez victorias | Win 10 games. / Gana 10 partidas. | You won 10 games. / Ganaste 10 partidas. | Tablero Salvia y coral |
| `qs_consistency` | `consistency` | 80 | No | Consistency / Constancia | Complete 7 daily challenges in a row. / Completa 7 retos diarios seguidos. | You completed 7 daily challenges in a row. / Completaste 7 retos diarios seguidos. | Tablero Índigo y durazno |
| `qs_habit` | `habit` | 100 | No | Habit / Hábito | Complete 30 daily challenges in a row. / Completa 30 retos diarios seguidos. | You completed 30 daily challenges in a row. / Completaste 30 retos diarios seguidos. | Mazo Ilustrado |
| `qs_ladder` | `ladder` | 60 | No | Ladder / Escalera | Build a column from king to ace. / Arma una columna del rey al as. | You built a column from king to ace. / Armaste una columna del rey al as. | Reverso Lino |
| `qs_centennial` | `centennial` | 100 | No | Centennial / Centenario | Win 100 games. / Gana 100 partidas. | You won 100 games. / Ganaste 100 partidas. | Reverso Dorado e ícono dorado |
| `qs_night_owl` | `nightOwl` | 40 | No | Night Owl / Noctámbulo | Win a daily challenge between midnight and 4 a.m. / Gana un reto diario entre la medianoche y las 4 a. m. | You won a daily challenge in the small hours. / Ganaste un reto diario de madrugada. | Reverso Noche |
| `qs_fifty_wins` | `fiftyWins` | 80 | No | Fifty / Cincuenta | Win 50 games. / Gana 50 partidas. | You won 50 games. / Ganaste 50 partidas. | Victoria en cascada |
| `qs_economy` | `economy` | 60 | No | Economy / Economía | Win in fewer than 100 moves. / Gana en menos de 100 movimientos. | You won in fewer than 100 moves. / Ganaste en menos de 100 movimientos. | Mazo Pixel |
| `qs_in_the_red` | `inTheRed` | 20 | Sí | In the Red / Números rojos | Take your score below zero. / Lleva tu puntaje por debajo de cero. | Your score went below zero. It happens. / Tu puntaje bajó de cero. Pasa. | Oculta: pistas a 3 fuera del reto diario |

Ocultos: Noctámbulo, Economía y Números rojos son sorpresas; el resto son metas visibles.

## Leaderboards

| ID | Caso en el código | Nombre (en / es) | Tipo | Formato | Sufijo (en / es) | Orden | Envío | Qué se envía |
|---|---|---|---|---|---|---|---|---|
| `qs_daily_challenge` | `Leaderboard.daily` | Daily Challenge / Reto diario | Recurrente (Every 1 day, starting at 05:00 UTC (00:00 in Colombia)) | Entero | " points" / " puntos" | Mayor a menor | **Más reciente** | Today's scored daily attempt when it's won (AppModel.pushToGameCenter) |
| `qs_best_score` | `Leaderboard.bestScore` | Best Score / Mejor puntaje | Clásico | Entero | " points" / " puntos" | Mayor a menor | Mejor puntaje | PlayerProgress.bestScore (classic games, including abandoned ones) |
| `qs_longest_streak` | `Leaderboard.longestStreak` | Longest Streak / Racha más larga | Clásico | Entero | " days" / " días" | Mayor a menor | Mejor puntaje | Longest run of completed daily challenges (AppModel.longestStreak) |

## Notas

- El reto cambia a la medianoche de cada dispositivo (`DailyKey.rolloverHour = 0` en QuietKit). `qs_daily_challenge` recurre cada 24 h desde las 05:00 UTC (00:00 en Colombia) y guarda el puntaje **más reciente**.
- `qs_best_score` y `qs_longest_streak` solo reciben valores > 0.
- Partidas guardadas (`saveGameData`): el progreso se guarda en el iCloud del jugador vía Game Center (requiere sesión). Entitlements en `App/QuietSolitaire.entitlements` (contenedor `iCloud.<bundle id>`, iCloud Documents).
- Restablecer progreso (Ajustes) borra el guardado de iCloud y reinicia los logros con `GKAchievement.resetAchievements()`. Los puntajes ya enviados no se pueden retirar.
