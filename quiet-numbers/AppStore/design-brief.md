# Brief para Claude Design: Quiet Numbers

Cuatro encargos:
1. Revisar la paleta, sobre todo el color secundario.
2. Diseñar las 11 imágenes de logros de Game Center.
3. Diseñar las imágenes de marketing de la App Store (iPhone y iPad, inglés y español).
4. Proponer el logo de Quiet Studios y el splash de la app.

Adjuntar al pedido:
- `App/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png` (ícono actual).
- Las capturas crudas de `AppStore/screenshots/` (iPhone 6.9" y iPad 13", `en` y `es`, claro y oscuro; 5 escenas: `01-game`, `02-daily`, `03-leaderboards`, `04-collection`, `05-theme`).
- `AppStore/screenshot-captions.md` (titulares propuestos).
- `fastlane/metadata/en-US/description.txt` y `es-MX/description.txt` (mensaje y tono).

## Contexto

Quiet Numbers es un puzzle de números (emparejar iguales o que sumen 10) de **Quiet Studios**, para iPhone y iPad. Filosofía: sin anuncios, sin compras, sin recolectar datos. Minimalismo tranquilo: la personalidad está en animaciones y hápticos, no en ruido visual. Tipografía SF Pro Rounded con dígitos monoespaciados; fichas sin borde, solo el número.

Nunca usar nombres, marcas ni estética de otras apps del género (p. ej. "Number Match").

## 1. Paleta

Paleta actual (claro / oscuro). Los neutros son los del sistema iOS.

| Rol | Token | Claro | Oscuro | Uso |
|---|---|---|---|---|
| Primario | `AccentColor` | `#0A5CFF` | `#4D8DFF` | Botones, selección, pistas, línea de unión, borde de fila, días completados del calendario. **Decidido: azul eléctrico.** |
| Secundario | `Highlight` | `#B45309` | `#FBBF24` | Números agregados con +, elogios ("¡Desde lejos!"), racha, "¡Nuevo récord!". **Provisional: al dueño no le convence el ámbar.** |

Temas desbloqueables (reemplazan fondo, superficie, tinta y acento):

| Tema | Fondo | Superficie | Tinta | Acento | Modo |
|---|---|---|---|---|---|
| Papel (por defecto) | sistema | sistema | sistema | primario | claro/oscuro |
| Pizarra | `#2F3B37` | `#3A4843` | `#EDEFEA` | `#E8C872` | solo oscuro |
| Arena | `#F4ECDD` / `#2A241C` | `#EADFCB` / `#362E24` | `#3D3427` / `#EFE6D6` | `#B5763A` / `#D9A066` | claro/oscuro |
| Medianoche | `#0E1626` | `#18233A` | `#DCE6F5` | `#7FA8FF` | solo oscuro |
| Brasa | `#1A1210` | `#2A1D19` | `#F5E6DF` | `#FF6B5A` | solo oscuro |

Qué pedimos:
- **Secundario:** 2 o 3 propuestas que acompañen al azul eléctrico, se distingan bien de él (los números agregados conviven con la selección azul en el mismo tablero) y funcionen en claro y oscuro. Alternativas ya consideradas: coral `#D63B4B`/`#FF7A85`, violeta `#7C3AED`/`#A78BFA`, menta `#0F8A6B`/`#34D3A6`.
- **Contraste:** texto del secundario sobre el fondo del sistema (blanco / negro) **≥ 4.5:1** (WCAG AA); el primario con texto blanco encima ≥ 4.5:1.
- **Daltonismo:** el secundario no puede depender solo del tono para distinguirse del primario (revisar deuteranopia/protanopia).
- Revisar si los acentos de los temas siguen siendo coherentes con la paleta final; proponer ajustes si no.
- **Formato de entrega:** hex claro y oscuro de cada token, con su contraste calculado.

## 2. Imágenes de logros (Game Center)

- 11 imágenes, **1024×1024 PNG**, opacas (sin transparencia). Game Center las muestra recortadas en **círculo**: el motivo tiene que leerse dentro del círculo inscrito y en tamaño pequeño (~60 pt).
- Un mismo sistema visual para todas: fondo, trazo y uso de color consistentes; relacionadas con el ícono de la app (azul eléctrico, número "10").
- Sin texto (se localizan en inglés y español), sin números fuera de los que sean el motivo.
- Que se vean bien sobre el fondo claro y el oscuro de Game Center.

| ID | Nombre (en / es) | Condición | Idea de motivo (libre) |
|---|---|---|---|
| `first_step` | First Step / Primer paso | Terminar la primera partida | Un paso, un punto de partida |
| `clean_slate` | Clean Slate / Tabla rasa | Limpiar un tablero completo | Cuadrícula vacía |
| `no_help` | No Help / Sin ayuda | Terminar una partida sin pistas | Bombilla tachada / mano |
| `consistency` | Consistency / Constancia | Racha de 7 retos diarios | Calendario, 7 días |
| `habit` | Habit / Hábito | Racha de 30 retos diarios | Calendario completo |
| `sweeper` | Sweeper / Barrendero | Limpiar 100 filas | Viento, filas que se van |
| `stage_five` | Stage 5 / Etapa 5 | Llegar a la etapa 5 | Un 5, escalones |
| `centennial` | Centennial / Centenario | Completar 100 retos diarios | Roseta, medalla (oro) |
| `night_owl` | Night Owl / Noctámbulo | Reto entre 00:00 y 04:00 (oculto) | Luna y estrellas |
| `monotone` | Monotone / Monótono | 10 parejas iguales seguidas (oculto) | Signo igual repetido |
| `in_the_red` | In the Red / Números rojos | Puntaje bajo cero (oculto) | Signo menos, rojo/coral |

Los íconos SF Symbols que usa hoy la app para cada logro (referencia, no obligatorios): `figure.walk`, `square.dashed`, `hand.raised.slash`, `calendar`, `calendar.badge.checkmark`, `wind`, `5.circle`, `rosette`, `moon.stars`, `equal.circle`, `minus.circle`.

**Entrega:** PNG 1024×1024 nombrados con el ID (`first_step.png`…). Se guardarán en `AppStore/game-center/`.

## 3. Imágenes de la App Store

Las capturas actuales son pantallas crudas: genéricas y nada marketeras. Queremos imágenes que vendan la idea de un juego **tranquilo y honesto**, coherentes con la paleta final y con el tono de la descripción.

- **Mensajes, en este orden** (titulares de partida en `screenshot-captions.md`, se pueden reescribir):
  1. **Sin anuncios. Nunca.** / *No ads. Ever.* (obligatorio y primero; es lo que nos diferencia).
  2. Reto diario: el mismo tablero para todos, racha.
  3. Game Center opcional: leaderboards con amigos.
  4. Recompensas que se ganan, nunca se compran.
  5. Sin recolectar datos / temas.
  Proponer si conviene una sexta (p. ej. cómo se juega: "iguales o que sumen 10") o cambiar el orden.
- **Tamaños** (vertical, PNG o JPEG sin transparencia):
  - iPhone 6.9": **1320×2868**.
  - iPad 13": **2064×2752**.
  - Apple escala estas a los tamaños menores; no hacen falta otras.
- **Idiomas:** inglés y español (un solo set en español sirve para México y España). El idioma de la barra de estado no importa; lo que importa es el texto.
- **Libertad visual:** fondo de color, captura dentro o fuera del marco del dispositivo, recortes ampliados del tablero, composiciones que crucen dos imágenes seguidas, etc. Que se lea en la miniatura de los resultados de búsqueda (las 3 primeras imágenes son las que se ven).
- **Restricciones de Apple:** mostrar la app real (se pueden usar las capturas tal cual o recortes); no imitar la interfaz de iOS ni usar marcas de Apple fuera de lo permitido; nada de precios ni "gratis" engañoso.
- Sin nombres, marcas ni estética de otros juegos del género.
- **Entrega:** archivos nombrados `<dispositivo>-<idioma>-<NN>.png` (p. ej. `iphone-es-01.png`), más el archivo fuente editable si es posible, para poder actualizar textos.

## 4. Logo de Quiet Studios y splash

**Logo del estudio.** Quiet Studios hace apps y juegos que respetan la atención y la privacidad: tranquilos, minimalistas, sin ruido. La primera app es Quiet Numbers y vendrán otras (cada una con identidad propia), así que el logo tiene que funcionar para toda la familia.

- **Variantes:**
  - Símbolo + logotipo horizontal.
  - Solo símbolo.
  - Solo logotipo.
- **Fondos:** que funcione en claro y en oscuro, y en un solo color.
- **Tamaños:** que se lea en tamaño muy pequeño (favicon de 32 px) y en el splash.
- **Entrega:** SVG y PNG @1x/@2x/@3x, más el color o colores exactos.
- **Dónde se usará:** splash de la app, página web (`docs/index.html`), avatar de GitHub y redes, pie de las páginas.

**Splash de Quiet Numbers.** Hoy, al abrir la app, aparece ~1,5 s "Quiet Studios" con un punto azul sobre el fondo del sistema y se desvanece hacia Inicio (un toque lo salta).

- Proponer cómo debería verse con el logo nuevo, en claro y oscuro.
- **Movimiento:** cómo entra y cómo sale. Animación simple que se pueda hacer en SwiftUI (opacidad, escala, trazo que se dibuja, etc.), con una alternativa estática para Reducir movimiento.
- **Duración:** máximo ~1,5 s; tiene que sentirse tranquilo, no hacer esperar.
- **Limitación:** el launch screen del sistema (lo que se ve antes de que cargue la app) solo admite un color de fondo y una imagen fija. El splash animado viene después y tiene que empalmar sin salto visual.
- **Opcional:** si al diseñar el logo surge una propuesta de ícono para Quiet Numbers, bienvenida.

