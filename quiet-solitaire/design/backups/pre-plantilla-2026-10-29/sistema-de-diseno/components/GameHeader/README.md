# GameHeader

El encabezado de la partida: botones redondos de volver y menú (48 pt, `surface`), el puntaje al centro y, debajo, tres estadísticas.

- Puntaje: SF Pro Rounded heavy de 40 pt (`score`), cifras tabulares, transición numérica al cambiar.
- Estadísticas (`stat-value`): **Time** (mm:ss; h:mm:ss pasada una hora), **Moves** y **Best** en clásico; en el reto diario la tercera es **Daily** con la dificultad del día (Easy, Medium, Hard, Expert); en práctica, **Practice** con un guion.
- Etiqueta caption semibold en `muted`, valor en `ink`. A 24 pt de cada borde.
- El tiempo corre por segundo mientras la partida está en pantalla y la app activa, desde la primera jugada hasta ganar.
