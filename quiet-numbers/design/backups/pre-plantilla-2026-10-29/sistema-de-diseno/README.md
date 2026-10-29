# Quiet Numbers

Sistema de diseño del juego de números de la familia: vaciar el tablero juntando números iguales o que sumen 10. **Hereda todo de [Quiet Studios](https://claude.ai/artifact/59yz1mHLFU3u3jvSfugf7B)** (principios, voz, temas, tipografía, componentes de QuietUI, pantallas que se repiten); aquí solo va lo propio del juego. Exploración y mocks: [canvas Quiet Numbers · Diseño](https://claude.ai/artifact/9GbZHUxhTZPMznhag8dtj4). Código: `quiet-numbers/` y `QuietKit`.

## Identidad

- **Una pausa de 5 minutos.** Frase de la marca: "Your 5-minute break." / "Tu pausa de 5 minutos."
- El tablero es la estrella: números sin fichas ni bordes, grandes y en SF Pro Rounded, sobre el fondo del tema. Todo lo demás se aparta.
- El coral (`accent`) marca lo nuevo y lo que celebra: números agregados con +, racha, elogios, tiro largo. El petróleo (`primary`) marca la acción: selección, línea, pista.

## El tablero

- 9 columnas; celda = (ancho − 48) / 9 por 46 pt de alto (52 con Números más grandes), cuadrada en iPad hasta 760 pt de tablero.
- Estados de una celda: en juego (`number`), agregada con + (`number-added`), seleccionada (anillo de 40 pt, trazo 2 pt en `selection` sobre relleno al 14 %), pista (anillo punteado 4/3 que parpadea dos veces), error (anillo en `miss` + sacudida), eliminada (`number-cleared`, fantasma).
- Línea de unión en `selection` con tres grosores según las eliminadas en medio: 2, 3 y 4 pt (tiro largo). En lectura continua entre filas, entra desde los bordes.
- Fila 1–9 sobre el tablero: el dígito que ya no queda se tacha y pasa a `number-cleared`.

## Movimiento (ver tokens de duración)

Línea → estallido de rayos (coral en tiro largo) → "+N" sube 24 pt → la fila se ilumina y colapsa. Un toque nuevo termina la secuencia al instante. Con Reduce Motion solo un fundido de 150 ms.

## Voz propia

Elogios: "Long shot!", "Double row!", "Triple row!", "No more 7s!", "10 in a row!", "Goal reached!". Sin combos: el juego no los tiene.

## Pantallas y tienda

- **Pantallas** (grupo "Pantallas"): los mocks aprobados de Inicio, Partida (claro, oscuro y tiro largo), Reto diario, Clasificaciones, Colección, Ajustes y Splash. Detalle en la sección "Pantallas en Quiet Numbers".
- **App Store** (grupo "App Store"): las 5 imágenes de la ficha, y el header y la búsqueda elegidos; en Assets › Store, todas las imágenes finales de iPhone 6.9", 6.3" e iPad 13" en inglés y español.

## Recompensas

Temas de la familia, fichas (Simple, Círculo, Contorno), tipografía New York, efecto de limpieza (Suave, Ola), pack de sonido (Suave, Marimba) e ícono dorado. Las insignias de los 11 logros están en Assets.
