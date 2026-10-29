---
name: quiet-design-canvas
description: Crear, actualizar y revisar el canvas de diseño (artefacto de tipo Design en claude.ai) de un juego de Quiet Studios con la plantilla de 5 páginas (Overview, App Store, Screens, Styles, Components). Usar al empezar un juego nuevo, al cambiar pantallas, imágenes de la tienda, estilos o componentes de un juego, o al hacer QA de su canvas.
---

# Canvas de diseño de un juego

Hay dos niveles de diseño, sin información repetida entre ellos:

- **Sistema de diseño de Quiet Studios** (tipo "Design System", link en el `CLAUDE.md` de la raíz): temas y colores por rol, tipografía, botones, tarjetas, segmentos, toast, ajustes, hápticos, sonido, splash, estructura de pantallas y reglas de la App Store. Lo genera `QuietKit`.
- **Un canvas por juego** (tipo "Design", título `Quiet <App>`, link en la primera línea del `CLAUDE.md` de la app): solo lo que es de ese juego. Referencia: el de Quiet Numbers.

Un juego no tiene sistema de diseño propio ni otros artefactos de diseño.

## Páginas (exactamente estas, en este orden)

| Página | Artboards de la plantilla | Qué lleva |
|---|---|---|
| **Overview** | `Main` | Ícono, nombre y la mecánica en una frase; qué hay en el canvas; qué hereda de Quiet Studios (con link); qué es propio del juego; datos (nombre en la tienda, subtítulo, Bundle ID, versiones, carpeta, scripts de imágenes). |
| **App Store** | `StoreIcons`, `StoreIPhoneEN`, `StoreIPhoneES`, `StoreIPadEN`, `StoreIPadES`, `StoreHeader`, `StoreSearch`, `StoreAchievements` | Íconos (estándar, oscuro, tinted sobre fondo oscuro, dorado); las 5 imágenes de la ficha lado a lado para iPhone 6.9" e iPad 13", en inglés y español; header 21:9 y búsqueda 3:2 con inglés y español juntos; las insignias de los logros con condición y recompensa. Solo imágenes finales (las de `AppStore/`), no propuestas. |
| **Screens** | `ScreenHome`, `ScreenGame`, `ScreenSummary`, `ScreenDaily`, `ScreenLeaderboards`, `ScreenCollection`, `ScreenSettings` | Cada pantalla de la app actual con su captura clara y oscura una al lado de la otra (capturas reales de `scripts/design-screens.sh`, iPhone 6.9", inglés). Pantalla nueva = artboard nuevo con el mismo formato. |
| **Styles** | `StylesColor`, `StylesType`, `StylesMetrics`, `StylesMotion` | Solo estilos propios del juego: qué rol del tema usa cada estado del tablero o la pieza, tipografía de los números o cartas, medidas, duraciones y curvas. Lo que ya está en Quiet Studios no va. Si un estilo no aplica, se borra el artboard. |
| **Components** | `CompExample` (copiar uno por pieza) | Una tarjeta por componente que solo tiene este juego (tablero, carta, barra de acciones, hoja de resumen…), con el nombre del código, claro y oscuro lado a lado y datos reales. Botones, tarjetas, toast, etc. son de Quiet Studios y no van. |

No hay páginas de Assets, Files, propuestas ni iteraciones: los assets sueltos están en el repo, y las propuestas se muestran en un artefacto aparte que se borra al decidir; lo elegido entra a este canvas.

## Archivos

- `template/`: la plantilla (`canvas.json` con las 5 páginas, el layout y el sistema de diseño de Quiet Studios instalado, y los 21 artboards). Cada artboard tiene el diseño en el HTML y el contenido en `renderVals()`: llenar datos, no rediseñar. Los `TODO`, `__APP__` y `__DATE__` marcan lo que falta.
- `qa.py`: revisa y renderiza un canvas (abajo).
- `dc2static.js`: pasa un `.dc.html` a HTML estático (lo usa `qa.py`).
- `quiet-<app>/design/canvas-assets.tsv` (en el repo): ruta de cada imagen subida al canvas → id del asset (`/_blob/<id>`). Se actualiza cada vez que se sube una imagen.

## Crear el canvas de un juego

1. Copiar la plantilla al scratchpad: `cp -R .claude/skills/quiet-design-canvas/template <scratchpad>/<app>-canvas/project` y reemplazar `__APP__` (nombre) y `__DATE__` (ISO, p. ej. `2026-10-29T12:00:00Z`) en todos los archivos.
2. Copiar `tokens.json` del sistema de diseño de Quiet Studios a `project/ds/quiet-studios/tokens.json` (leerlo del artefacto con `Artifact` action `read`, `path`).
3. Crear el artefacto: `quickstart` con intent `design`, publicar con el `type_url` del tipo Design y `title` = `Quiet <App>`; luego publicar `project/canvas.json` con `root` = `<scratchpad>/<app>-canvas` y todos los `project/*` en `files`.
4. Subir las imágenes (abajo), llenar `renderVals()` de cada artboard, ajustar alturas, correr `qa.py` y volver a publicar.
5. Poner el link en la primera línea del `CLAUDE.md` de la app.

## Actualizar

- Leer el canvas publicado antes de cambiarlo (`Artifact` action `read` con `path` de cada archivo) si no está en el scratchpad de esta sesión; otra sesión pudo editarlo.
- **Imágenes:** reducir a ≤ 1600 px del lado mayor en el scratchpad (`sips -Z 1600 in.png --out out.png`), subir con `Artifact` (`url` del canvas, `asset: true`, `file_paths`, hasta 25 por llamada) y anotar cada id en `design/canvas-assets.tsv` con la ruta original del repo. Una imagen que cambia se sube de nuevo y se reemplaza su id en el artboard y en el tsv.
- **Screens:** `scripts/design-screens.sh` (o el equivalente del juego) captura todas las pantallas en claro y oscuro; no usar las imágenes de la tienda como capturas de pantalla.
- **Alturas:** el ancho y alto del div raíz, `$preview` y `boards` en `canvas.json` deben coincidir. Artboards de una misma página apilados con 120 px de separación (App Store) o en grilla (Screens 980 × 1180, Styles y Components 1360 × lo que mida + 120).
- Lo aprobado no se pisa sin decisión del usuario.

## QA (obligatorio antes de avisar que el canvas está listo)

```bash
python3 .claude/skills/quiet-design-canvas/qa.py <scratchpad>/<app>-canvas/project quiet-<app> <scratchpad>/qa-<app>
```

Revisa: las 5 páginas exactas, el sistema de diseño de Quiet Studios instalado, que cada `.dc.html` esté en `boards`/`order` y viceversa, tamaños coherentes, artboards que no se superpongan, restos de la plantilla, imágenes que no estén en `canvas-assets.tsv`, títulos repetidos, contenido que se sale del artboard o llega al borde inferior, y espacio vacío al final. Deja un PNG por artboard y una hoja por página (`page-<id>.png`).

Después **mirar cada hoja** (Read de los PNG) y revisar a ojo: imágenes que cargan, texto cortado, ícono tinted visible, claro y oscuro lado a lado, nada que repita a Quiet Studios ni otra página del canvas, textos que digan lo que el juego hace hoy. Corregir, volver a correr hasta 0 errores y 0 avisos (o avisos justificados), publicar y dar el link.

## Reglas

- Copias reales en los mocks y datos que el juego produce; sin lorem ipsum.
- Los valores de Styles que usa el código también quedan en el `CLAUDE.md` de la app; los de la familia, en QuietKit y en el sistema de diseño de Quiet Studios.
- Respaldo: con cada versión aprobada en la App Store, exportar el canvas como HTML a `quiet-<app>/design/backups/<versión>/` (ver `quiet-release`).
