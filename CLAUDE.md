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

## Reto diario (igual en todos los juegos)

Todos los juegos tienen modo libre y reto diario, y el reto funciona como el de Quiet Numbers (decisión 2026-10-30). Lo genérico vive en QuietKit (`DailyKey`, `Streaks`, `GameCenterService`); cada juego solo define su tablero, su meta y su puntaje.

- **El mismo para todos:** clave `yyyy-MM-dd` → FNV-1a → semilla → PRNG propio (`SeededRandom`); nada que dependa de la plataforma. Cambia a la medianoche local. Test obligatorio: la misma fecha da siempre el mismo tablero.
- **Un intento puntuable por día:** empieza al tocar "Jugar" ese día; si se sale a mitad, se guarda y se retoma (sigue puntuando). Es lo único que se envía a la clasificación diaria.
- **Se puede repetir:** hoy después del intento puntuable y cualquier día de los últimos 30, como práctica que no envía puntaje.
- **Completar un día pasado cuenta para la racha:** rellena ese día una sola vez (racha, calendario y logros de retos; un hueco rellenado puede unir dos rachas). Si ese día hubo un intento fallido, se conserva su puntaje.
- **Salir guarda:** cada práctica a medias se guarda por día (con una marca en el calendario). Al volver a un reto en curso se pregunta **"Continuar" o "Empezar de nuevo"**.
- **Mismas reglas para todos en el reto:** las pistas cuestan siempre lo normal (sin el descuento de "Números rojos"), puntuable o práctica.
- **Termina con un resumen:** hoja con puntaje, tiempo y estadísticas del juego y los logros de la partida; fuegos artificiales de QuietUI solo al completar el reto (nada con Reduce Motion).
- **Clasificación diaria:** recurrente cada 24 h desde las 05:00 UTC. A igual puntaje gana el menor tiempo: el tiempo va en el `context` del puntaje (segundos + 1) y la app reordena (`GameCenterService.rankedByTime`).
- **Calendario mensual:** muestra los días reales de cada mes (28 a 31), con flechas para ir al mes anterior, los completados (bandas entre días seguidos), las prácticas a medias y el día de hoy; racha y mejor racha a la vista. Se pueden jugar los días que caen dentro de los últimos 30; los más viejos se ven pero no se abren.

- **Notificaciones (locales, sin servidor):** recordatorio a las 19:00 si no se ha completado el reto de hoy, con lo que hicieron los amigos si ya se sabe; "racha en riesgo" a las 21:00 si sigue sin hacerse y hay racha de 3 o más. Detalle en el backlog de Quiet Numbers.

Un juego que no cumpla algo de esto lo anota en su `BACKLOG.md` hasta alinearlo.

## Diseño

- **Sistema de diseño de Quiet Studios:** https://claude.ai/artifact/59yz1mHLFU3u3jvSfugf7B (tokens de color por tema, tipografía, componentes de QuietUI, pantallas que se repiten, reglas de la App Store, logos). Lo genera el código de `QuietKit`; si no coinciden, manda el código y se actualiza el artefacto.
- **Cada app tiene un solo artefacto de diseño:** un canvas (tipo "Design", título `Quiet <App>`) con 5 páginas: Overview, App Store, Screens, Styles y Components. Solo lleva lo propio del juego; nada que ya esté en el sistema de Quiet Studios (decisión 2026-10-29). Plantilla, QA y procedimiento en `.claude/skills/quiet-design-canvas`. Su link va en la primera línea del `CLAUDE.md` de la app. Una app nueva no empieza a programar pantallas sin él.
- Links: [Quiet Numbers](https://claude.ai/artifact/3Z4eY31mrvGeqPvR8hUaZL) · [Quiet Solitaire](https://claude.ai/artifact/EwWvXPwMtEVpx47drg2AJV). Los artefactos anteriores (un sistema de diseño y un canvas por app) se borraron el 2026-10-29; sus archivos están en `quiet-<app>/design/backups/pre-plantilla-2026-10-29/`.
- **Respaldos:** con cada versión aprobada en la App Store se exporta el canvas de esa app como HTML a `quiet-<app>/design/backups/<versión>/` (procedimiento en `quiet-release`). Los artefactos son privados: para compartirlos, menú Share.

## Estudio

- `studio/roadmap.md`: juegos publicados, el siguiente (Sudoku) y las ideas; **todos** con la misma estructura (modo libre + retos diarios). Incluye los prerrequisitos antes de lanzar un juego de pago.
- `studio/medicion.md`: qué medir en App Store Connect y cuándo (empieza con las apps publicadas).

## Skills para agentes

En `.claude/skills/`: `quiet-new-app` (crear una app), `quiet-project-structure` (estructura y convenciones de código), `quiet-design-canvas` (canvas de un juego: páginas y contenido), `quiet-ui` (componentes, pantallas y patrones) `quiet-release` (TestFlight, ficha, Game Center, web) y `quiet-backlog` (backlog de cada juego en `quiet-<app>/BACKLOG.md`). Al cambiar una forma de trabajar, actualizar la skill correspondiente en el mismo cambio.

## Cómo trabajamos

- Antes de trabajar en una app, leer su `CLAUDE.md`.
- Desarrollo por fases con criterio de aceptación explícito; no avanzar de fase sin cumplirlo.
- Respetar los principios de la familia Quiet por encima de cualquier atajo (nada de SDKs, red ni tracking "temporales").
