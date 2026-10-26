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

## Cómo trabajamos

- Antes de trabajar en una app, leer su `CLAUDE.md`.
- Desarrollo por fases con criterio de aceptación explícito; no avanzar de fase sin cumplirlo.
- Respetar los principios de la familia Quiet por encima de cualquier atajo (nada de SDKs, red ni tracking "temporales").
