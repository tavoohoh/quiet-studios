---
name: quiet-ui
description: Componentes, pantallas que se repiten y patrones de interacción de las apps de Quiet Studios (QuietUI). Usar al construir o modificar cualquier pantalla, al agregar un componente, o al decidir animaciones, hápticos, textos y accesibilidad.
---

# UI de la familia

Fuente: el sistema de diseño de Quiet Studios (link en `CLAUDE.md` de la raíz; leer su `README.md`, `pantallas.md` y la tarjeta del componente) y el código de `QuietKit/Sources/QuietUI/`. Si no coinciden, manda el código y se corrige el sistema de diseño.

## Componentes (QuietUI)

| Necesito | Uso |
|---|---|
| Botón principal / secundario | `.buttonStyle(CapsuleButtonStyle())` / `CapsuleButtonStyle(isProminent: false)` |
| Acción secundaria con energía | `AccentButtonStyle()` |
| Volver, menú | `RoundIconLabel(systemImage:tint:)` (48 pt, arriba) |
| Tarjeta | `.card()` o `SurfaceShape(shape:)` |
| Pantalla empujada | `.screen(Text("Título")) { trailing }` (barra del sistema oculta) |
| Segmentos | `Segments(selection:options:)` |
| Ajustes | `GroupSection(title:)` + `ThemedToggleStyle()` |
| Elogio, aviso corto | `Toast(text:)` |
| Celebración | `Fireworks(colors:seed:)` (nada con Reduce Motion) |
| Feedback | `HapticsService` (`.select`, `.place`, `.success`, `.invalid`) y `ToneService` |
| Anchos | `Layout.boardWidth/column/buttons/calendar(sizeClass)`, `.readableColumn()` |
| Tipografía | `Font.score`, `.counter`, `.stat`; `Animation.quiet` |
| Recordatorio del reto | `DailyReminders` (19:00 y 21:00, plan en `DailyReminderPlan` de QuietCore), `.dailyReminderTriggers`, `.dailyReminderOffer`, `DailyReminderToggle` en Ajustes |
| Amigos | `FriendsTodayCard` (Reto diario), `FriendProfileView` (frente a frente, últimos 7 retos), `PlayerAvatar`; datos con `GameCenterService.dailyEntries`, `headToHead`, `friendsToday` |

Algo que no está en la tabla y se usará en dos apps: va a QuietUI (con su tarjeta en el sistema de diseño), no a la app.

## Pantallas que se repiten

Inicio, Juego, Resumen de partida, Reto diario, Clasificaciones, Colección, Ajustes, Tutorial y Splash, con la estructura de `pantallas.md` del sistema de diseño. Copiar la pantalla equivalente de la otra app y cambiar el contenido del juego; no rediseñar el esqueleto.

## Patrones

- Colores solo por rol (`@Environment(\.quietTheme)`); probar cada pantalla en Petróleo y coral claro y oscuro, en un tema de un modo y en Alto contraste.
- Un toque nunca espera a una animación: el siguiente toque la termina.
- Animaciones con `withAnimation(reduceMotion ? .easeInOut(duration: 0.15) : .quiet)`; efectos largos solo para celebrar.
- Elogios: uno a la vez, 1,2 s. Errores: sacudida + háptico, sin texto.
- Fin de partida: hoja de resumen con estadísticas; fuegos solo al completar/ganar; logros de la partida en una tarjeta, sin avisos encima.
- Textos: verbo que dice lo que pasa, en String Catalog con español; plurales del catálogo; números con `FormatStyle` y `.monospacedDigit()`.
- Accesibilidad: `accessibilityLabel` en todo lo que es solo ícono, etiquetas útiles por celda o carta, objetivos ≥ 44 pt, Dynamic Type salvo el tablero (que tiene su opción de tamaño).
- Textos de QuietUI: `Text("…", bundle: .main)`; cada app los pone en su catálogo (el compilador no los extrae de la app: listarlos a mano, como `KIT` en `quiet-solitaire/scripts/strings.py`). Los textos de las notificaciones los arma cada app.
- Notificaciones: permiso solo en contexto (al volver de un primer reto completado, `.dailyReminderOffer`), nunca al abrir la app; máximo 2 al día; nada de Game Center se guarda.
- iPad: mismo layout centrado con anchos máximos; atajos de teclado (⌘Z deshacer, H pista).

## Antes de dar algo por terminado

- Compilar y correr los tests; mirar la pantalla en el simulador (un solo simulador, apagarlo después).
- Revisar que no quedaron textos sin traducir (el catálogo no debe tener claves sin español).
- Si cambió el diseño acordado, actualizar el canvas de la app o avisar al usuario.
