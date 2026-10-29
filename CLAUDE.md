# The Quiet Project

Nombre del estudio (marca visible en las apps, p. ej. el splash): **Quiet Studios**.

Estudio que construye, con ayuda de AI, apps y juegos para la App Store. Cada app parte de una mecánica conocida y no patentada (2048, Number Match, idle/incremental donde las tareas generan moneda del juego para mejorar y facilitar las siguientes tareas, etc.) y la reinterpreta con identidad propia.

## Filosofía de la familia Quiet

Apps que respetan la atención y la privacidad del usuario:

- **Sin anuncios, sin compras in-app, sin suscripciones, sin tip jar.**
- **Sin backend propio, sin analytics, sin SDKs de terceros.** Todo corre en el dispositivo; meta: etiqueta "Data Not Collected" en la App Store.
- **Offline primero.** Los servicios de Apple (Game Center, iCloud) son extras que sincronizan cuando hay conexión.
- **Recompensas cosméticas**, ganadas jugando, nunca pagando, y sin alterar la jugabilidad.
- **Minimalismo tranquilo:** la personalidad está en animaciones y hápticos, no en ruido visual.

## Propiedad intelectual

Tomamos mecánicas genéricas, nunca nombres, marcas, assets, textos ni arte de los juegos originales. Cada app tiene nombre y estética propios.

## Plataforma

Solo ecosistema Apple (iPhone, iPad, Mac). Ecosistema controlado: lo que funciona en un iPhone con el target soportado funciona en el resto.

Stack por defecto (cada app puede ajustarlo en su propio CLAUDE.md):

- SwiftUI nativo, Swift 6 con strict concurrency.
- Un solo target multiplataforma por app, compra universal (un bundle ID).
- SwiftData para persistencia local; GameKit como único servicio online.
- La lógica del juego en un Swift Package propio sin dependencias de UI, testeado con Swift Testing.
- Cero dependencias externas.
- Localización con String Catalogs: inglés (development language y fallback) y español.

## Estructura del repositorio

Cada app vive en su propio directorio en la raíz, con su propio `CLAUDE.md` que contiene el brief y las decisiones específicas:

- `quiet-numbers/` — puzzle de números (emparejar iguales o que sumen 10). Primera app de la familia.
- `quiet-solitaire/` — solitario clásico (Klondike, robar 1). Segunda app, jugable en el simulador.
- `QuietKit/` — paquete compartido: `QuietCore` (PRNG, día del reto, rachas, paleta de temas) y `QuietUI` (tema, componentes, hápticos, tonos, Game Center, splash). Lo usan Quiet Solitaire y Quiet Numbers (migrado el 2026-10-28, para su 1.1; sin cambios visibles ni en los tableros de cada fecha).

## Diseño

- **Sistema de diseño de Quiet Studios:** https://claude.ai/artifact/59yz1mHLFU3u3jvSfugf7B (tokens de color por tema, tipografía, componentes de QuietUI, pantallas que se repiten, reglas de la App Store, logos). Lo genera el código de `QuietKit`; si no coinciden, manda el código y se actualiza el artefacto.
- **Cada app tiene dos artefactos**, con sus links en la primera línea de su `CLAUDE.md` (decisión 2026-10-29):
  - **Sistema de diseño** (tipo "Design System", `Quiet <App> · Sistema de diseño`), con la misma estructura que el de Quiet Studios: lo propio del juego (tokens, componentes como la celda o la carta, guía) y sus assets (íconos, insignias, imágenes de la tienda). Hereda todo lo demás del de Quiet Studios.
  - **Canvas** (tipo "Design", `Quiet <App> · Diseño`): mocks, animaciones, propuestas y arte de la tienda, con las páginas estándar de `.claude/skills/quiet-design-canvas`.
  - Una app nueva no empieza a programar pantallas sin los dos.
- Links: Quiet Numbers [sistema de diseño](https://claude.ai/artifact/Aax49mxVrB93wQghnC2Scx) y [canvas](https://claude.ai/artifact/9GbZHUxhTZPMznhag8dtj4) · Quiet Solitaire [sistema de diseño](https://claude.ai/artifact/RejZUocVbapjFepmuzdixP) y [canvas](https://claude.ai/artifact/S5U6E4QDFsqpmrj4kvHrGL).
- **Respaldos:** con cada versión aprobada en la App Store se exportan los artefactos de esa app (canvas y sistema de diseño) como HTML a `quiet-<app>/design/backups/<versión>/` (procedimiento en `quiet-release`). Los artefactos son privados: para compartirlos, menú Share.

## Estudio

- `studio/roadmap.md`: juegos publicados, el siguiente (Sudoku) y las ideas; **todos** con la misma estructura (modo libre + retos diarios). Incluye los prerrequisitos antes de lanzar un juego de pago.
- `studio/medicion.md`: qué medir en App Store Connect y cuándo (empieza con las apps publicadas).

## Skills para agentes

En `.claude/skills/`: `quiet-new-app` (crear una app), `quiet-project-structure` (estructura y convenciones de código), `quiet-design-canvas` (canvas de un juego: páginas y contenido), `quiet-ui` (componentes, pantallas y patrones) y `quiet-release` (TestFlight, ficha, Game Center, web). Al cambiar una forma de trabajar, actualizar la skill correspondiente en el mismo cambio.

## Cómo trabajamos

- Antes de trabajar en una app, leer su `CLAUDE.md`.
- Desarrollo por fases con criterio de aceptación explícito; no avanzar de fase sin cumplirlo.
- Respetar los principios de la familia Quiet por encima de cualquier atajo (nada de SDKs, red ni tracking "temporales").
