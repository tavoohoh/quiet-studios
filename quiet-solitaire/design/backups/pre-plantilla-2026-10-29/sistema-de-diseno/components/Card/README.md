# Card

La carta boca arriba, en sus seis mazos; mide 48 × 67 pt en iPhone (`card-width`, `card-height`) y todo se calcula como proporción del ancho.

**Anatomía (Quiet, Cuatro colores, Índice grande, Ilustrado y Pixel):**
- Índice arriba a la izquierda: rango (34 % del ancho, bold rounded; 36 % heavy en Ilustrado; 42 % en Índice grande) y palo chico (24 %; 30 % en Índice grande), a un margen de `card-margin` (8 %) y 6 % desde arriba.
- Caja del cuerpo desde `card-body-top` (34 %; 40 % en Índice grande) hasta el 8 % de cada borde. En ella: palo grande (`card-pip`, 50 %; 60 % en el As; 40 % en Índice grande) o, en J/Q/K, el panel de figura.
- Panel de figura: `surface2` con radio del 6 % y el emblema de trazo al 72 % (J escudo, Q corona con perla, K corona de picos). Ilustrado y Pixel ponen ahí su figura de busto o a pixel.
- Cara `surface`, borde de 1 pt en `ghost` (2 pt en `ink` con Alto contraste), radio `card-radius` (10 % del ancho, mínimo 4) y `shadow-card`.

**Clásico:** índices en dos esquinas (New York bold al 23 %, palo al 15 %, el de abajo girado 180°), palos repartidos según el número (16 % del ancho; los de la mitad de abajo girados), As al 42 % al centro, figuras de doble cabeza en un marco a 25 % / 9 % de los bordes. Radio del 7 %.

**Colores:** Quiet, Cuatro colores e Índice grande siguen al tema (`ink`, `suit-red`, `four-diamonds`, `four-clubs`). Ilustrado, Clásico y Pixel traen su cara y sus palos (`illus-*`, `classic-*`, `pixel-*`) en cualquier tema; todos pasan 4,5:1.

**Rangos:** A, 2–10, J, Q, K en ambos idiomas. El 10 se aprieta (tracking −3 % del ancho).

Lo que el código pone y aquí no se ve: las figuras de busto de Ilustrado y Clásico (SVG en `Assets.xcassets/Cards`, dibujados por `scripts/card-art.py`) y las figuras pixel de 11 × 14 (`PixelArt.swift`).
