# BoardCell

Una celda del tablero: el número solo, sin ficha (con la ficha Círculo o Contorno de Colección, aparece un círculo detrás). `CellView` en `App/Features/Game`.

Estados: en juego (`number`), agregado con + (`number-added`), seleccionado (anillo `selection` de 40 pt, trazo 2, relleno al 14 %), pista (anillo punteado 4/3 que parpadea dos veces), error (anillo `miss` y sacudida de ±4 pt × 3) y eliminado (`number-cleared`). VoiceOver: "7, fila 3, columna 2".
