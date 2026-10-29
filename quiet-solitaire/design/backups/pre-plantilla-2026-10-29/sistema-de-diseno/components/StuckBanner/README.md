# StuckBanner

El aviso de que la partida ya no se puede ganar. Bloquea la mesa hasta que el jugador elige.

- Sale solo cuando la búsqueda rápida del solver recorre todas sus jugadas sin ganar (40.000 posiciones). Nunca declara perdida una partida que tiene salida; si al solver se le acaba el presupuesto, no avisa.
- La mesa queda bajo un velo negro y no acepta jugadas. Tarjeta `surface` de 24 pt (`radius-card`) a 24 pt de los bordes: ícono en `accent`, "No way to win from here" (headline), "Undo to go back, or start a new game." (subheadline, `muted`), botones Undo (secundario) y New Game (primario) y "Keep playing" como texto en `primary`.
- Con "Keep playing" el aviso no vuelve en esa partida. Fue decisión del usuario (2026-10-27): que nadie siga jugando sin darse cuenta.
