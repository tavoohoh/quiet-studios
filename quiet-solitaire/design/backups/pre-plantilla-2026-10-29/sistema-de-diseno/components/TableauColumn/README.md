# TableauColumn

Una de las 7 columnas del tableau. Las cartas se apilan con paso fijo: boca abajo asoman `step-face-down` (19 % del ancho, 9 pt), boca arriba `step-face-up` (46 %, 22 pt: justo el índice).

- Si la columna no cabe sobre la barra inferior, el paso boca arriba se comprime hasta `step-min` (16 pt); el de boca abajo no cambia.
- La carta que queda arriba al destaparse una boca abajo se voltea sola (giro en Y de 180 ms).
- Se arrastra cualquier escalera válida boca arriba; el destino es el lugar válido que más se superpone con lo arrastrado.
- Columna vacía: hueco sin palo; solo acepta un Rey o una escalera que empiece en Rey.
- Las columnas empiezan `tableau-gap` (17 pt) debajo de la fila de fundaciones.
