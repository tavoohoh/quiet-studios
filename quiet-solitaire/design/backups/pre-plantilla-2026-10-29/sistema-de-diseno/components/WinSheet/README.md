# WinSheet

La hoja de fin de partida al ganar: el SummarySheet de la familia con el desglose del puntaje del solitario.

- Título "You won!" en `muted`, puntaje de 56 pt (`score-sheet`) y "New record!" en `accent` al 14 % cuando supera el mejor clásico.
- Tabla sobre `background` (radio 20, filas de 40 pt con `separator`): Time, Moves, Game points, Few-moves bonus (500 − 2 por movimiento sobre 100, mínimo 0), **Time ×N** (×2,0 hasta 3 min, baja lineal hasta ×1,0 a los 15 min en pasos de 0,1; se aplica a puntos de juego + bono; las pistas quedan fuera) y Hints.
- Logros de la partida juntos en una tarjeta con borde `surface2` de 1,5 pt.
- New Game (primario) y Home (secundario); en el reto diario solo Home.
- Fuegos artificiales (`Fireworks` de QuietUI) encima sin tomar toques; con Cascada, las cartas caen de la mesa 1,2 s antes. Nada de esto con Reduce Motion.
