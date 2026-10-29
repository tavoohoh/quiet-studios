# Hoja de ruta de Quiet Studios

Objetivo (2026-10-29): probar el mercado con juegos gratis, sin anuncios ni compras, y más adelante lanzar un juego más completo **de pago** para recuperar la licencia de Apple (USD 99 al año) y el costo de crear los juegos.

**Gratis para siempre (decisión 2026-10-29):** la familia de juegos simples (Quiet Numbers, Quiet Solitaire, Sudoku, Snake) es gratis siempre, sin anuncios ni compras. El de pago será un juego exclusivo que aún no existe; cuáles de las demás ideas son de pago se decide al revisar esta lista.

## Regla para todos los juegos

Misma estructura en todos: **modo libre** (partidas sin fin, mejor puntaje) y **retos diarios** (mismo reto para todos según la fecha, meta del día, racha, calendario de 30 días con práctica), más Clasificaciones, Colección, Ajustes y Tutorial. Si una mecánica no admite un reto diario determinista, no entra a la familia sin rediseñarla. Ver `.claude/skills/quiet-new-app`.

## Juegos

| Estado | Juego | Mecánica | Notas |
|---|---|---|---|
| Publicado (1.0 en revisión) | Quiet Numbers | Emparejar números iguales o que sumen 10 | Primera app. 1.1 en TestFlight. |
| En desarrollo | Quiet Solitaire | Klondike, robar 1 | Retos con solución garantizada. |
| **Siguiente** | Sudoku | Sudoku 9×9 clásico | Reto diario con dificultad por día de la semana (como Solitaire). Generador con solución única y semilla del día; pistas con costo; notas a lápiz. "Sudoku" es nombre genérico. |
| Idea | Defensa con monedas | Soldados que pelean solos; cada enemigo vencido suelta monedas que el jugador recoge y lleva a puntos de compra para pagar torres o más soldados | Género "idle arcade" de defensa (híbrido entre tower defense y recolección). No identificamos el juego del anuncio de Instagram; tomar solo la mecánica genérica. Mucho más grande que los demás (tiempo real, personajes, oleadas): candidato a **juego de pago**. Reto diario: misma oleada para todos. |
| Idea | Bloques | Armar figuras con bloques encastrables | Por definir la mecánica. **Nunca** usar "LEGO" ni formas de su marca: decir "bloques". |
| Idea | Números (otro) | Por definir | Distinto de Quiet Numbers y Sudoku. |
| Idea | Snake | La serpiente clásica que crece al comer | "Snake" es genérico; no usar "Nokia". Reto diario: mismo mapa y misma secuencia de comida para todos. |

## Prerrequisitos antes de lanzar un juego de pago

1. Decidir el modelo con tiempo (antes de crear la app en App Store Connect): **pago único al descargar** es lo único compatible hoy con "sin compras in-app"; "gratis + desbloqueo" obliga a cambiar los principios de la familia y se decide aparte.
2. Firmar el **Paid Apps Agreement** en App Store Connect › Business.
3. Cargar **datos bancarios** (cuenta que reciba USD) y **fiscales** (formulario W-8BEN como persona en Colombia; revisar tratado y retenciones).
4. Inscribirse al **App Store Small Business Program** (comisión del 15 % en vez del 30 %).
5. Definir precio y países; revisar si cambia la etiqueta de edad o la de privacidad (no debería: sigue "Data Not Collected").
6. Ficha y web: decir qué incluye sin precio en las imágenes (Apple no permite precios en los assets).
7. Revisar con los números de `studio/medicion.md` que los juegos gratis justifican el esfuerzo.
