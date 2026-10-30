# Game Center: Quiet Sudoku

Configuración para App Store Connect, generada por `scripts/game-center.py` (también escribe `game-center.json` y las insignias, y verifica que los IDs coincidan con el código: `Achievement.gameCenterID` = "qsu_" + el caso en snake case, y `Leaderboard` en `App/AppModel.swift`). Prefijo `qsu_` (Quiet Numbers no usa prefijo y Quiet Solitaire usa `qs_`).

## Logros (12, 660 / 1000 puntos)

Ninguno se puede ganar más de una vez. Cada uno lleva una imagen de 1024×1024 sin transparencia: `AppStore/achievements/<id>.png` (mismo sistema de insignias que Quiet Numbers).

| ID | Caso en el código | Puntos | Oculto | Nombre (en / es) | Descripción antes de ganarlo (en / es) | Descripción al ganarlo (en / es) | Recompensa |
|---|---|---:|---|---|---|---|---|
| `qsu_first_win` | `firstWin` | 10 | No | First Sudoku / Primer sudoku | Solve your first sudoku. / Resuelve tu primer sudoku. | You solved your first sudoku. / Resolviste tu primer sudoku. | Números Redondos, tablero Petróleo y coral (por defecto) |
| `qsu_no_mistakes` | `noMistakes` | 40 | No | Clean Sheet / Sin tachones | Solve a sudoku without mistakes. / Resuelve un sudoku sin errores. | You solved a sudoku without a single mistake. / Resolviste un sudoku sin un solo error. | Números Clásicos (New York) |
| `qsu_no_hints` | `noHints` | 40 | No | On Your Own / Por tu cuenta | Solve a sudoku without hints. / Resuelve un sudoku sin pistas. | You solved a sudoku without a single hint. / Resolviste un sudoku sin usar ni una pista. | Tablero Salvia y arena |
| `qsu_no_notes` | `noNotes` | 60 | No | From Memory / De memoria | Solve a medium or harder sudoku without notes. / Resuelve un sudoku de nivel Media o más sin notas. | You solved a medium or harder sudoku without notes. / Resolviste un sudoku de nivel Media o más sin notas. | Números Máquina (SF Mono) |
| `qsu_ten_wins` | `tenWins` | 40 | No | Ten Sudokus / Diez sudokus | Solve 10 sudokus. / Resuelve 10 sudokus. | You solved 10 sudokus. / Resolviste 10 sudokus. | Notas en color |
| `qsu_consistency` | `consistency` | 80 | No | Consistency / Constancia | Complete 7 daily challenges in a row. / Completa 7 retos diarios seguidos. | You completed 7 daily challenges in a row. / Completaste 7 retos diarios seguidos. | Tablero Índigo y durazno |
| `qsu_habit` | `habit` | 100 | No | Habit / Hábito | Complete 30 daily challenges in a row. / Completa 30 retos diarios seguidos. | You completed 30 daily challenges in a row. / Completaste 30 retos diarios seguidos. | Victoria en ola |
| `qsu_expert` | `expert` | 80 | No | Expert / Experto | Solve an expert sudoku. / Resuelve un sudoku Experto. | You solved an expert sudoku. / Resolviste un sudoku Experto. | Números Pluma (Noteworthy) |
| `qsu_quick` | `quick` | 50 | No | Quick / Rápido | Solve an easy sudoku in under 4 minutes. / Resuelve un sudoku Fácil en menos de 4 minutos. | You solved an easy sudoku in under 4 minutes. / Resolviste un sudoku Fácil en menos de 4 minutos. | Resaltado suave (solo el mismo número) |
| `qsu_night_owl` | `nightOwl` | 40 | No | Night Owl / Noctámbulo | Solve a daily challenge between midnight and 4 a.m. / Resuelve un reto diario entre la medianoche y las 4 a. m. | You solved a daily challenge in the small hours. / Resolviste un reto diario de madrugada. | Tablero Salvia y coral |
| `qsu_centennial` | `centennial` | 100 | No | Centennial / Centenario | Solve 100 sudokus. / Resuelve 100 sudokus. | You solved 100 sudokus. / Resolviste 100 sudokus. | Ícono dorado |
| `qsu_in_the_red` | `inTheRed` | 20 | Sí | In the Red / Números rojos | Take your score below zero. / Lleva tu puntaje por debajo de cero. | Your score went below zero. It happens. / Tu puntaje bajó de cero. Pasa. | Oculta: pistas a 3 solo en clásico |

Oculto: solo Números rojos (el easter egg de la familia); el resto son metas visibles para que se sepa cómo ganar cada recompensa.

## Leaderboards

| ID | Caso en el código | Nombre (en / es) | Tipo | Formato | Sufijo (en / es) | Orden | Envío | Qué se envía |
|---|---|---|---|---|---|---|---|---|
| `qsu_daily_challenge` | `Leaderboard.daily` | Daily Challenge / Reto diario | Recurrente (Every 1 day, starting at 05:00 UTC (00:00 in Colombia)) | Entero | " points" / " puntos" | Mayor a menor | **Más reciente** | Today's scored daily attempt when it's solved (AppModel.pushToGameCenter) |
| `qsu_best_score` | `Leaderboard.bestScore` | Best Score / Mejor puntaje | Clásico | Entero | " points" / " puntos" | Mayor a menor | Mejor puntaje | PlayerProgress.bestScore (best solved classic game) |
| `qsu_longest_streak` | `Leaderboard.longestStreak` | Longest Streak / Racha más larga | Clásico | Entero | " days" / " días" | Mayor a menor | Mejor puntaje | Longest run of completed daily challenges (AppModel.longestStreak) |

## Notas

- El reto cambia a la medianoche de cada dispositivo (`DailyKey.rolloverHour = 0` en QuietKit). `qsu_daily_challenge` recurre cada 24 h desde las 05:00 UTC (00:00 en Colombia) y guarda el puntaje **más reciente**.
- `qsu_best_score` y `qsu_longest_streak` solo reciben valores > 0.
- Partidas guardadas (`saveGameData`): el progreso se guarda en el iCloud del jugador vía Game Center (requiere sesión). Entitlements en `App/QuietSudoku.entitlements` (contenedor `iCloud.<bundle id>`, iCloud Documents).
- Restablecer progreso (Ajustes) borra el guardado de iCloud y reinicia los logros con `GKAchievement.resetAchievements()`. Los puntajes ya enviados no se pueden retirar.
