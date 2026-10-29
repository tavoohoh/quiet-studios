# Quiet Solitaire

Solitario clásico (Klondike, robar 1) de Quiet Studios: ordenar las 52 cartas en cuatro fundaciones, del As al Rey. Sin anuncios, sin compras y sin recolectar datos. Este documento es lo propio del juego; todo lo demás lo hereda del sistema de la familia.

- **Familia:** [Quiet Studios · Sistema de diseño](https://claude.ai/artifact/59yz1mHLFU3u3jvSfugf7B): principios, voz, roles de color, tipografía, componentes de QuietUI y pantallas que se repiten. Si algo no está aquí, vale lo de la familia.
- **Canvas:** [Quiet Solitaire · Diseño](https://claude.ai/artifact/S5U6E4QDFsqpmrj4kvHrGL): mocks, iteraciones, propuestas y arte de la tienda. Lo aprobado allí pasa a este sistema y al código.
- **Código:** `quiet-solitaire/` (repositorio `tavoohoh/quiet-studios`). Cartas y reversos en `App/DesignSystem/CardView.swift`, medidas de la mesa en `App/Features/Game/BoardLayout.swift`, colores en `QuietKit/Sources/QuietCore/Palette.swift`. Si este documento y el código no coinciden, manda el código.

## Qué hereda de la familia

Todo menos la mesa y las cartas: los 6 temas por rol (Petróleo y coral sigue al sistema; el resto fija un modo), SF Pro Rounded para todo lo que es juego, botones cápsula de 56 pt, botones redondos de 48 pt arriba, tarjetas `surface` de 24 pt, `Animation.quiet`, hápticos y tonos de QuietUI, splash "quiet studios", fuegos artificiales al ganar y las pantallas de la familia (ver Pantallas).

## Qué agrega

- **Un rol de color:** `suit-red`, los palos rojos. Igual al `accent` salvo Salvia y arena (`#B4503A`) y Alto contraste (`#B3001B`). Pasa 4,5:1 sobre la cara de la carta en todos los temas (`PaletteTests`).
- **La carta**, sus 6 mazos y 5 reversos, los huecos y la columna (ver Componentes y la familia de tokens `card`).
- **Lo de la mesa:** encabezado con Tiempo · Movimientos · Mejor, barra de Deshacer / Autocompletar / Pista y el aviso "sin salida".

## Reglas en breve

Klondike estándar, robar 1, reciclar el mazo sin límite. Se apila en orden descendente alternando color; una columna vacía solo acepta un Rey. Tocar una carta la manda a su mejor destino (fundación primero); arrastrar mueve la carta o la escalera. Cada toque al mazo cuenta como movimiento. Deshacer ilimitado. Pistas a −10 (−3 con Números rojos fuera del reto diario). Al ganar: bono de 500 − 2 por movimiento sobre 100 y multiplicador por tiempo (×2,0 hasta 3 min, baja hasta ×1,0 a los 15 min).

## Voz

La de la familia: frases cortas, segunda persona, sin presión. Ejemplos reales del juego:

- Hitos: "Spades complete!" / "¡Picas completas!", "All cards face up!" / "¡Todas las cartas a la vista!". Uno a la vez, como Toast.
- Sin salida: "No way to win from here" / "Undo to go back, or start a new game." Botones: Undo, New Game, Keep playing.
- Victoria: "You won!", "New record!".
- Rangos A, J, Q, K en ambos idiomas (no R, D, J del español): se reconocen en cualquier móvil.

## La carta

- **Medidas en iPhone:** 48 × 67 pt (ancho × 1,4), 6 pt entre columnas, mesa a 9 pt del borde. Boca abajo asoman 9 pt (19 % del ancho), boca arriba 22 pt (46 %, solo el índice); una columna larga comprime el paso hasta 16 pt. En iPad la mesa crece hasta 760 pt con 12 pt entre columnas.
- **Mazo Quiet (por defecto):** índice (rango + palo chico) arriba a la izquierda; debajo, una caja del cuerpo desde el 34 % del alto hasta un margen del 8 % del ancho. En ella: un palo grande (50 % del ancho; 60 % en el As) o, en J/Q/K, un emblema de trazo sobre un panel `surface2` (J escudo, Q corona con perla, K corona de picos con tres perlas). Cara `surface`, borde de 1 pt en `ghost`, esquinas del 10 % del ancho. En oscuro la cara es oscura.
- **Mazos desbloqueables:** Ilustrado (índice grande, figuras de busto planas), Clásico (índices en dos esquinas en New York, palos repartidos según el número, figuras de doble cabeza en marco) y Pixel (palos 7×8 y figuras 11×14 a pixel, tipografía bitmap propia, esquinas escalonadas). Traen su propia cara y sus rojos y negros (`illus-*`, `classic-*`, `pixel-*`); el tablero y el reverso siguen al tema.
- **Accesibilidad, siempre disponibles:** Cuatro colores (diamantes en `four-diamonds`, tréboles en `four-clubs`) e Índice grande (índice al 42 %, cuerpo desde el 40 %).
- **Reverso:** color del tema con rayado fino, marco interior y la marca de pausa del estudio al centro. Desbloqueables: Coral, Lino, Noche, Dorado.

## Recompensas

13 logros de Game Center (insignias en Assets › Badges). Desbloquean: mazos Clásico (Una sola vuelta), Ilustrado (Hábito) y Pixel (Economía); reversos Coral (Sin vuelta atrás), Lino (Escalera), Noche (Noctámbulo) y Dorado + ícono dorado (Centenario); tableros Salvia y arena (A pulso), Salvia y coral (Diez victorias) e Índigo y durazno (Constancia); efecto Cascada (Cincuenta). Números rojos es el easter egg: pistas a 3 fuera del reto, no aparece en Colección. Siempre disponibles: Alto contraste, Petróleo y coral claro y oscuro, Cuatro colores e Índice grande.

## Movimiento y hápticos

- Mover: spring de 0,25 s. Voltear: giro en Y de 180 ms. Carta a fundación: "+10" que sube y se desvanece. Inválido: anillo en `accent` y sacudida ±4 pt × 3; la carta vuelve con spring. Pista: anillo punteado que parpadea dos veces en origen y destino.
- Hitos: al completar un palo la fundación destella con anillos que se expanden.
- Victoria: fuegos artificiales para todos; Cascada (las cartas caen de la mesa antes) como recompensa. Reduce Motion: sin giros, flotantes ni fuegos; fundidos de 150 ms.
- Hápticos: selección al tomar una carta, medio al soltar en el tableau, éxito al completar una fundación y al ganar, error en movimiento inválido.

## Accesibilidad

VoiceOver por carta ("Reina de corazones, columna 3") y por hueco, con acciones "Mover a fundación / a columna N"; Dynamic Type en todo menos la mesa; Alto contraste (bordes de 2 pt en cartas, reversos y huecos punteados); Cuatro colores e Índice grande; opción Zurdo (mazo y descarte a la izquierda).

## Iconografía e ícono

SF Symbols de la familia en la interfaz (`arrow.uturn.backward`, `lightbulb`, `arrow.clockwise` en el mazo vacío). Ícono de la app: dos cartas sobre `primary`, una blanca al frente con la marca de pausa y otra en el primary claro detrás; variantes claro, oscuro, tinted y Gold (Centenario). Ver Assets › Icons.
