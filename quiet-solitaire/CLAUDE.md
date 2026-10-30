# Quiet Solitaire

**Canvas de diseño:** [Quiet Solitaire](https://claude.ai/artifact/EwWvXPwMtEVpx47drg2AJV) · Sistema de diseño de la familia: [Quiet Studios](https://claude.ai/artifact/59yz1mHLFU3u3jvSfugf7B)

Solitario clásico (Klondike, robar 1): ordenar las 52 cartas en cuatro fundaciones del As al Rey. Gratis, sin anuncios, sin compras y sin recolectar datos. Segunda app de la familia Quiet (ver `../CLAUDE.md`).

Nombre: **Quiet Solitaire** (decidido 2026-10-27). "Klondike" y "Solitaire" son nombres genéricos de la mecánica; nunca usar nombres, arte, reversos ni sonidos de Microsoft Solitaire u otras apps del género. La baraja francesa es de dominio público, pero el diseño de cartas es propio (canvas "Quiet Solitaire · Diseño").

## Principios no negociables

Los mismos de Quiet Numbers:

- Sin anuncios, compras in-app, suscripciones ni tip jar.
- Sin backend, analytics, crash reporters ni SDKs de terceros. Ninguna llamada de red propia.
- 100% offline. Game Center es un extra que sincroniza al reconectar.
- Recompensas solo cosméticas, ganadas con logros. Única excepción, igual que en Quiet Numbers: el easter egg de "Números rojos" (pistas más baratas solo en clásico; nunca en retos diarios).
- Sin identificadores propios, fingerprinting ni App Tracking Transparency.
- Frameworks permitidos: SwiftUI, SwiftData, GameKit y StoreKit **solo** para `requestReview()`.
- El tiempo se muestra y, al ganar, multiplica el puntaje (decisión 2026-10-27, tomando como referencia otra app del género).

## Stack

| Pieza | Decisión |
|---|---|
| UI | SwiftUI nativo. Sin SpriteKit. Si el arrastre de pilas no rinde en SwiftUI, evaluar solo el tablero con `UIViewRepresentable` (decisión en la fase 2, con medición). |
| Kit compartido | `../QuietKit` (decidido 2026-10-27): temas, componentes, tipografía, hápticos, sonido, Game Center y utilidades del reto diario, extraídos de Quiet Numbers. Ver "QuietKit" abajo. |
| Lenguaje | Swift 6, strict concurrency. |
| Sistemas mínimos | iOS 18 / iPadOS 18; en Mac, la app de iPad (igual que Quiet Numbers). |
| Persistencia | SwiftData. |
| Online | GameKit únicamente. |
| Tests | Swift Testing para la lógica del juego. |
| Dependencias externas | Ninguna (QuietKit es nuestro). |

Un solo target iOS (iPhone y iPad), un bundle ID. Proyecto generado con XcodeGen (`project.yml`), como Quiet Numbers.

## Comandos

- El `.xcodeproj` se genera desde `project.yml` con XcodeGen: `xcodegen generate` tras agregar o mover archivos. No editar el `.pbxproj` a mano.
- **Correr en un iPhone:** `Config/Local.xcconfig` (ignorado por git) lleva el Team ID; abrir `QuietSolitaire.xcodeproj`, elegir el iPhone y correr. Con un Personal Team, usar un bundle ID propio y `App/QuietSolitaire-Personal.entitlements` (ver `Config/Local.xcconfig.example`).
- Tests del Core: `cd Packages/QuietSolitaireCore && swift test` (`-c release` para que el solver corra rápido). Tests de QuietKit: `cd ../QuietKit && swift test`.
- Todos los tests (Core, app y UI): `xcodebuild test -project QuietSolitaire.xcodeproj -scheme QuietSolitaire -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/dd`.
- Textos: `scripts/strings.py` escribe `Localizable.xcstrings` e `InfoPlist.xcstrings` (en/es) y falla si un texto que extrajo el compilador (`build/dd`) no tiene español. Correrlo después de compilar con `-derivedDataPath build/dd`.
- Arte: `scripts/card-art.py` escribe los SVG de palos, emblemas y figuras en `Assets.xcassets/Cards` (mismos trazos del canvas); `scripts/render-icon.py` dibuja los íconos (estándar y Gold, claro/oscuro/tinted) con Chrome sin interfaz. El arte pixel se dibuja en código (`DesignSystem/PixelArt.swift`).
- **Publicación** (`AppStore/app-store-connect.md`: todos los campos para crear la app, notas para la revisión y el orden de las imágenes):
  - Capturas: `scripts/screenshots.sh [iphone] [ipad]` (esquema `Screenshots`, estado `-demo` de `App/Debug/DemoData.swift`: sábado 14-nov-2026 10:00, partida a medias jugada por el solver, racha de 8, clasificaciones de ejemplo) → `AppStore/screenshots/<iphone-6.9|ipad-13>/<en|es>/<light|dark>/`. Usa sus propios simuladores ("QS iPhone 6.9", "QS iPad 13") y los apaga al terminar. No correrla a la vez que la de Quiet Numbers: su script apaga todos los simuladores.
  - Imágenes de la App Store: `scripts/store-images.py` (después de las capturas) → `AppStore/store-images/<iphone-6.9|iphone-6.3|ipad-13>/<en|es>/01…05.png`, sin alfa.
  - Textos: `fastlane/metadata/{en-US,es-MX}` (solo inglés de EE. UU. y español de México, decisión 2026-10-28); validar con `scripts/validate-metadata.py`.
  - Subir la ficha por la API (sin fastlane, mismo cliente `scripts/asc.py` que Quiet Numbers; credenciales en `~/.appstoreconnect`): `scripts/upload-metadata.py [--apply] [--replace-screenshots]` sube textos (en-US, es-MX), categoría, copyright e imágenes (iPhone 6.9" e iPad 13"); `scripts/setup-game-center.py [--apply]` crea logros (con imagen) y clasificaciones desde `game-center.json`. Ambos muestran qué cambiaría sin `--apply` y no duplican lo que ya existe.
  - Build a TestFlight: archivar desde una copia limpia de `main` (`git worktree add --detach <carpeta> origin/main`, copiar `Config/Local.xcconfig`), `xcodebuild archive … -configuration Release -destination 'generic/platform=iOS' -allowProvisioningUpdates` y `xcodebuild -exportArchive` con `method app-store-connect`, `destination upload` (mismo `ExportOptions.plist` que Quiet Numbers). La exportación usa la cuenta de Xcode: la clave de la API no tiene permiso de firma en la nube ("Cloud signing permission error").
  - Game Center: `scripts/game-center.py` escribe `AppStore/game-center.{md,json}` y las 13 insignias (`AppStore/achievements/<id>.png`, 1024 sin alfa) y verifica los IDs contra el código.
  - Web: `../docs/quiet-solitaire/{index,privacy,support}.html` (GitHub Pages desde `/docs`).
- Simuladores: para pruebas usar uno solo ("iPhone 17") y apagarlo al terminar (`xcrun simctl shutdown <udid>`).
- Argumentos DEBUG: `-startGame` abre una partida en memoria (`-seedKey <texto>` la hace determinista; `-nearlyWon` arranca a una jugada de autocompletar); `-uiTesting` usa `UITests.store` (`-resetStore` lo borra); `-unlockAll` desbloquea todo; `-date <ISO 8601>` fija el reloj del reto; `-demo` carga el estado de las capturas (en memoria); `-demoClock <segundos>` fija el reloj de una mesa `-startGame`. Recordatorios (con `-demo`): `-showReminders` lista en Ajustes las notificaciones pendientes, `-refreshFriends` corre al abrir lo mismo que la tarea de segundo plano, `-completeToday` da por ganado el reto del 14-nov.

## QuietKit

Paquete Swift en la raíz del repo, compartido por las apps. Dos productos:

- `QuietCore` (sin UI): `SeededRandom` (SplitMix64, idéntico a Quiet Numbers; test con valores de referencia), `DailyKey` (clave del día, cambio a las 19:00, día de la semana), `Streaks`, FNV-1a y `Palette`: los 5 temas como valores hex por rol, más `suitRed`. `PaletteTests` exige 4,5:1 en cada par de texto (reemplaza a `theme-colors.py`).
- `QuietUI`: `Theme` (colores dinámicos claro/oscuro desde `Palette`, en `\.quietTheme`), `Components.swift` (los de Quiet Numbers, públicos), `Layout`, `Typography`, `HapticsService`, `ToneService` (tonos sintetizados), `GameCenterService` genérico (IDs y tipo del snapshot los pone cada app; desempate por tiempo del reto con `dailyEntries`), `DailyReminders` (notificaciones del reto), `FriendsTodayCard` y `FriendProfileView`, y `SplashView` (usa `SplashLockup` y `LaunchBackground` del bundle de la app, que también los necesita para la launch screen).
- Decisión 2026-10-27: los colores van en código y no en un Asset Catalog del paquete, para que `swift test` corra sin Xcode y el contraste quede verificado por un test.

Regla: **Quiet Numbers no se migra a QuietKit mientras su 1.0 está en revisión.** El kit nace copiando el código de Quiet Numbers y lo usa primero Quiet Solitaire; Quiet Numbers se migra en su 1.1, con sus tests (incluido "misma fecha → mismo tablero") como red. Mover `SeededRandom` no puede cambiar ni un bit de su salida.

## Arquitectura

```
quiet-solitaire/
├── project.yml
├── App/
│   ├── QuietSolitaireApp.swift
│   ├── Features/        # Home, Game, DailyChallenge, Leaderboards, Collection, Settings, Tutorial
│   ├── Services/        # persistencia y lo que no sea genérico
│   ├── DesignSystem/    # cartas, reversos, mazos (lo genérico vive en QuietKit)
│   └── Resources/
└── Packages/
    └── QuietSolitaireCore/
        ├── Sources/QuietSolitaireCore/
        │   ├── Card.swift          # rango, palo, color
        │   ├── Deal.swift          # semilla → baraja → reparto
        │   ├── GameState.swift     # stock, waste, fundaciones, tableau; Codable
        │   ├── Moves.swift         # movimientos legales, aplicar, deshacer
        │   ├── Scoring.swift
        │   ├── Solver.swift        # determinista, con presupuesto de nodos
        │   ├── DailyChallenge.swift
        │   └── Achievements.swift
        └── Tests/QuietSolitaireCoreTests/
```

El Core depende solo de `QuietCore`. Modelos `Codable`.

## Reglas del juego

Klondike estándar, **robar 1**, reciclar el mazo **sin límite**.

- **Reparto:** 7 columnas; la columna *n* lleva *n* cartas, solo la de arriba boca arriba. Las 24 restantes al mazo (stock).
- **Tableau:** se apila en orden descendente alternando color (rojo/negro). Se mueve cualquier secuencia válida boca arriba. Una columna vacía solo acepta un Rey (o una secuencia que empiece en Rey).
- **Fundaciones:** una por palo, del As al Rey. La carta de arriba de una fundación puede volver al tableau.
- **Mazo:** tocar el stock pasa una carta al descarte (waste); con el stock vacío, tocarlo recicla el descarte. Cada toque al mazo (robar o reciclar) cuenta como movimiento.
- **Al destaparse** una carta boca abajo en la cima de una columna, se voltea sola.
- **Victoria:** las 52 cartas en las fundaciones. **Autocompletar** aparece cuando todo el tableau está boca arriba y el stock y el descarte están vacíos.
- **Sin movimientos:** si el solver confirma que no hay salida, se ofrece "Sin salida · Nueva partida / Deshacer". Nunca se declara perdida una partida que tiene salida.
- **Deshacer:** ilimitado, paso a paso. Cuenta como movimiento y bloquea el logro "Sin vuelta atrás".
- **Pistas:** ilimitadas, cuestan 10 puntos (como Quiet Numbers), **aunque el puntaje quede negativo** (da el logro "Números rojos"). Con "Números rojos" cuestan 3 solo en clásico (`AppModel.classicScoring`); los retos diarios, puntuables o de práctica, siempre cobran 10 (2026-10-30, regla de la familia; antes la práctica cobraba 3). Cada partida guarda su `Scoring`, así que el cambio aplica desde la siguiente. Si no hay movimiento útil ni mazo que tocar, no cobran. Señalan el mejor movimiento según el solver, si no hay ninguno útil sugieren tocar el mazo.

**Decisiones de implementación (2026-10-27):**
- Las fundaciones tienen palo fijo (♠ ♥ ♦ ♣, como el canvas), no "cualquier as en cualquier hueco".
- Solver (`Solver.swift` + `BestFirst.swift`): búsqueda best-first (expande siempre la posición más prometedora: más cartas en fundaciones, menos boca abajo, menos talón; empates por orden de llegada) con presupuesto de posiciones. Reemplazó a la DFS el 2026-10-27: en una partida real del dispositivo la DFS gastó 3 millones de posiciones en una rama mala sin veredicto y no avisó. Con robar 1 y vueltas ilimitadas, todo el mazo y el descarte es alcanzable, así que se buscan como un solo conjunto ("talón"). Cartas seguras a la fundación de forma automática y posiciones vistas descartadas con un hash FNV-1a, sin `Hasher`, para que el resultado sea igual en todos los dispositivos. Presupuesto de 20.000 posiciones para elegir repartos y pistas, 40.000 para "sin salida".
- Dificultad = posiciones que expande el solver hasta la primera victoria: Fácil < 46, Media < 131, Difícil < 1.940, Experta desde ahí (percentiles 25/50/75/90 de 200 repartos con best-first: 41, 49, 130, 1.939). El reto del día prueba las semillas `"<día>#0"`, `"<día>#1"`… y toma la primera ganable con la dificultad del día (o la primera ganable tras 40 intentos). Cambiar el solver o estos umbrales cambia el reparto de cada fecha.
- Pista = la primera jugada de la solución del solver (si la carta está en el mazo, "toca el mazo"); si el solver no encuentra victoria, una jugada razonable. Se calcula fuera del hilo principal y solo se cobra si encontró algo.
- Deshacer guarda hasta 200 pasos (`GameSession.historyLimit`).
- **Hitos (2026-10-27):** al completar un palo, la fundación destella (anillos que se expanden) y sale "¡Picas completas!"; al quedar todas las cartas boca arriba, "¡Todas las cartas a la vista!" (no durante el autocompletar). **Victoria:** fuegos artificiales clásicos para todos (`Fireworks` en QuietUI, dibujados con `Canvas` según el tiempo y deterministas por semilla; nada con Reduce Motion), por encima de la hoja de victoria sin tomar toques; "Cascada" (logro Cincuenta) suma la caída de las cartas antes. Los logros de la partida van juntos en una tarjeta.
- **Arrastre (revisado 2026-10-27):** el gesto se mide en el espacio del tablero (no en la carta, que se mueve con el dedo); el destino es el lugar válido que más se superpone con la carta arrastrada, o el que está bajo el dedo; al soltar, la carta sigue desde donde quedó hasta su sitio (una sola animación); y el gesto de volver atrás se desactiva en la partida (`SwipeBack.isEnabled` en QuietUI), porque se robaba los arrastres de la primera columna. Tests: `testDragFromLeftEdge`, `testDropOffCenterLands`.
- **Tutorial** (`Features/Tutorial`, mesa en `Tutorial.swift` del Core, verificada por `TutorialTests`): 6 pasos (robar, rojo sobre negro, as a la fundación, mover una escalera, seguir la fundación, rey en columna vacía). Solo vale la jugada señalada, tocando o arrastrando. Sale con la primera "Nueva partida" (sin partidas jugadas ni en curso y sin `tutorialSeen`) y desde Ajustes › Cómo jugar; las reglas quedan en Ajustes › Reglas. Los UI tests lo omiten salvo con `-tutorial`.
- **"Sin salida"** aparece cuando la búsqueda rápida recorre todas sus jugadas sin ganar (no es una prueba estricta: omite partir escaleras salvo para liberar una carta a la fundación). Medido el 2026-10-27 en 1.346 posiciones de partidas jugadas: de las 112 que llamó perdidas, la búsqueda completa ganó 0 (108 demostradas perdidas, 4 sin veredicto). Si se le acaba el presupuesto, no avisa. El aviso **bloquea la mesa** (fondo oscuro, sin jugadas) hasta elegir Deshacer, Nueva partida o "Seguir jugando"; con esta última no vuelve en esa partida (decisión 2026-10-27, para que no se siga jugando sin darse cuenta). Debug: `-lostDeal`.
- **Tiempo:** se cuenta por segundo mientras la partida está en pantalla y la app activa, desde la primera jugada hasta ganar (`GameSession.tick`, guardado con la partida). Encabezado como la referencia: puntaje y debajo Tiempo · Movimientos · Mejor (Reto + dificultad en el diario). También en la hoja de victoria.

**Interacción:** tocar una carta la manda a su mejor destino (fundación primero, luego tableau); arrastrar mueve la carta o la secuencia. Opción "Zurdo" en Ajustes: mazo y descarte a la izquierda.

**Puntaje** (inicial, configurable en `Scoring`):
- Descarte → tableau: 5
- A fundación: 10
- Voltear carta del tableau: 5
- Fundación → tableau: −15
- Reciclar el mazo: 0 (decidido 2026-10-27). No lleva castigo directo: como cada toque al mazo es un movimiento, dar vueltas ya reduce el bono de victoria. Se descartó el −100 por vuelta de Windows, muy duro en robar 1.
- Pista: −10 (−3 con "Números rojos", solo en clásico). Decidido 2026-10-27: las apps móviles suelen dar pistas gratis; aquí cobran para que el leaderboard del reto sea parejo.
- Victoria: bono de 500 menos 2 por movimiento sobre 100 (mínimo 0).
- Multiplicador por tiempo al ganar (2026-10-27): ×2,0 hasta 3 min, baja lineal hasta ×1,0 a los 15 min, en pasos de 0,1 (`Scoring.timeMultiplierTenths`). Se aplica a los puntos de juego más el bono de movimientos; el costo de las pistas queda fuera. La hoja de victoria muestra "Tiempo ×1,8 +N".

## Reto diario

Mismo esquema que Quiet Numbers (clave `yyyy-MM-dd` → FNV-1a → semilla, cambio de día a la **medianoche local** como Quiet Numbers desde el 2026-10-27 (`DailyKey.rolloverHour = 0` en QuietKit; antes 19:00), un intento puntuable, práctica sin puntuar, racha y calendario de 30 días). La clasificación `qs_daily_challenge` recurre cada día desde las 05:00 UTC (medianoche en Colombia).

Lo nuevo: **cada reto diario tiene solución garantizada.** Con un reparto aleatorio se juega "otra partida más"; el reto diario se distingue porque es el mismo para todos y se sabe que se puede ganar.

- Semilla del día → barajar con el PRNG propio (Fisher–Yates con `SeededRandom`, nunca `shuffled()`) → el **solver** intenta resolverlo con un **presupuesto de nodos fijo** (no de tiempo, para que el resultado sea idéntico en cualquier dispositivo). Si no prueba que se gana, se avanza la semilla de forma determinista.
- **Dificultad por día de la semana** (decidido 2026-10-27): lunes y martes Fácil, miércoles a viernes Media, sábado Difícil, domingo Experta. Se mide con el solver (movimientos mínimos, pasadas del mazo, cartas boca abajo bloqueadas) y se avanza la semilla hasta caer en el rango del día. Se muestra en Inicio y en Reto diario ("Dificultad de la semana").
- Plan B si el solver es lento en dispositivos viejos: un script que precalcula las semillas válidas de varios años y la app las trae en un archivo (pocos KB). Mismo resultado, sin cálculo en el dispositivo.
- **Test obligatorio:** la misma fecha produce siempre el mismo reparto, y los retos de un año completo son ganables.
- Modo clásico: "Solo partidas con solución" activado por defecto (mismo solver); se puede apagar en Ajustes.
- **Regla de la familia** (sección "Reto diario" del `CLAUDE.md` de la raíz; alineado el 2026-10-30, tests en `AppTests/DailyRuleTests.swift`):
  - "Completar" = ganar el reparto. El reto puntuable no termina sin ganar: si se sale, se retoma (sigue puntuando).
  - **Práctica** (hoy después del intento puntuable, o un día de los últimos 30): se guarda por día (ranura `practice-<día>`, punto en el calendario, "Continuar" en la tarjeta) y al tocarla pregunta "Continuar / Empezar de nuevo". Se borra al ganarla o al salir de la ventana de 30 días.
  - **Ganar una práctica rellena el día** una sola vez (`AppModel.fillDay`, `PersistenceService.fillDaily`): racha, calendario y logros de retos (`.dailyCompleted` con la racha más larga). Un intento puntuable sin terminar ese día conserva su puntaje. No envía nada a la clasificación.
  - **Desempate por tiempo:** `StoredDaily.seconds` guarda el tiempo al ganar; viaja en el `Snapshot` y va en el `context` del puntaje de `qs_daily_challenge` (segundos + 1). Clasificaciones (pestaña Hoy, con el tiempo junto al puntaje) y el puesto entre amigos reordenan con `GameCenterService.dailyEntries` de QuietKit.
  - Calendario igual al de Quiet Numbers (días reales del mes, bandas, prácticas a medias). La hoja de victoria es el resumen; los fuegos salen en toda victoria (también en clásico, pedido del usuario 2026-10-27), nunca con Reduce Motion.

## Game Center

Igual que Quiet Numbers: opcional, sin sesión todo funciona y se sincroniza al reconectar; `GKAccessPoint` solo en Inicio; partidas guardadas en iCloud con fusión de conflictos.

Leaderboards:
Los mismos tres de Quiet Numbers (decidido 2026-10-27), con la misma pantalla (pestañas Hoy / Mejor puntaje / Racha × Global / Amigos, y estado sin Game Center):
- `qs_daily_challenge` — recurrente 24 h, puntaje del reto (el más reciente, también 0 o negativo).
- `qs_best_score` — clásico, mejor puntaje del modo libre (solo > 0).
- `qs_longest_streak` — clásico, racha más larga de retos (solo > 0).

Prefijo `qs_` en los IDs para no chocar con los de Quiet Numbers si algún día comparten grupo de Game Center.

**Amigos (2026-10-30, con QuietKit):** en Reto diario, la tarjeta "Amigos hoy" (`FriendsTodayCard`: amigos que ya jugaron con puntaje y tiempo, y tu puesto) y en Clasificaciones › Amigos cada fila abre el perfil del amigo (`FriendProfileView`, en `Features/Leaderboards/FriendProfileScreen.swift`): foto, frente a frente en reto de hoy, mejor puntaje y racha más larga, y los últimos 7 retos (`loadPreviousOccurrence`) con "Ganaste N de 7"; "Ver en Game Center" abre el perfil nativo (`GKAccessPoint.trigger(player:)`, iOS 18). Game Center no da logros, calendario ni partidas de otros. Nada se guarda.

## Notificaciones del reto

Locales (`DailyReminders` de QuietKit, sin servidor ni APNs; se mantiene "Data Not Collected"). Decidido 2026-10-30 para la familia (detalle en `quiet-numbers/BACKLOG.md`):
- **19:00** si el reto de hoy no está ganado: "El reto de hoy te espera" o, con racha ≥ 3, "No pierdas tu racha de N días". **21:00** "Tu racha de N días termina a medianoche" si sigue sin ganarse y la racha es ≥ 3. Máximo dos al día; se programan 7 días (solo el próximo día por ganar lleva racha) y se rehacen al abrir, al volver a la app, a medianoche, al cambiar de zona horaria y al ganar o rellenar un reto.
- **Amigos:** `BGAppRefreshTask` `com.tavoohoh.quietsolitaire.friends` (en `project.yml`: `BGTaskSchedulerPermittedIdentifiers` y modo `fetch`) desde las 17:00 carga la clasificación diaria de amigos y reescribe el texto de las 19:00 ("vale ganó el reto de hoy con 1.377. ¿Te animas?" / "3 amigos ya lo jugaron; vale lidera con 1.377."). iOS decide cuándo corre; si no corrió, sale el recordatorio normal.
- **Permiso:** se ofrece una vez al volver de la partida que completó el primer reto ("¿Te aviso a las 7 p. m.?"), nunca al abrir. Ajustes › Reto diario › "Recordatorio del reto" (apagado: no se programa nada; sin permiso, lleva a Ajustes del sistema).
- Textos en `App/Services/Reminders.swift`; los de QuietUI en `KIT` de `scripts/strings.py`. Tests: `AppTests/ReminderTests.swift`, `UITests/ReminderUITests.swift` (sin permiso no hay nada; 19:00 y 21:00 del 14-nov; la tarea de amigos cambia el texto; ganar el reto las pasa a mañana) y `DailyReminderPlanTests` en QuietKit.

## Logros y recompensas

Recompensas cosméticas: mazos (estilo del frente), reversos y tableros (los temas de Quiet Numbers). Diseño en el canvas, artboards "Desbloqueables" y "Mazos desbloqueables · iteración 2".

Mazos (2026-10-27, tras la primera revisión: Contorno y New York se parecían demasiado al de por defecto):
- **Quiet** (por defecto): índice + un palo grande, figuras con emblema geométrico; sigue los colores del tema.
- **Ilustrado:** estilo móvil clásico, índice grande, un palo al centro y figuras de busto planas y de color.
- **Clásico:** baraja de mesa, índices en dos esquinas, palos repartidos según el número y figuras de doble cabeza en marco. Índice chico en iPhone (aceptado por ser estético y opcional).
- **Pixel:** palos (7×8) y figuras (11×14) a pixel, tipografía bitmap, esquinas escalonadas. En iteración.
- Ilustrado, Clásico y Pixel traen su propio color de cara y de palos (blanco/crema, rojo y negro) y no siguen al tema; el tablero y el reverso sí. Figuras dibujadas para Quiet, sin copiar ninguna baraja comercial. La tipografía bitmap del mazo Pixel debe tener licencia que permita incluirla (p. ej. OFL) o dibujarse propia.

| ID | Logro (es / en) | Condición | Recompensa |
|---|---|---|---|
| `qs_first_win` | Primera mano / First Hand | Ganar la primera partida | Mazo Quiet, reverso del tema, Petróleo y coral (por defecto) |
| `qs_no_undo` | Sin vuelta atrás / No Going Back | Ganar sin deshacer | Reverso Coral |
| `qs_no_hints` | A pulso / Steady Hand | Ganar sin pistas | Tablero Salvia y arena |
| `qs_one_pass` | Una sola vuelta / One Pass | Ganar sin reciclar el mazo | Mazo Clásico |
| `qs_ten_wins` | Diez victorias / Ten Wins | Ganar 10 partidas | Tablero Salvia y coral |
| `qs_consistency` | Constancia / Consistency | Racha de 7 retos | Tablero Índigo y durazno |
| `qs_habit` | Hábito / Habit | Racha de 30 retos | Mazo Ilustrado |
| `qs_ladder` | Escalera / Ladder | Tener una columna del Rey al As en el tableau | Reverso Lino |
| `qs_centennial` | Centenario / Centennial | Ganar 100 partidas | Reverso Dorado + ícono dorado |
| `qs_night_owl` | Noctámbulo / Night Owl | Ganar un reto entre 00:00 y 04:00 | Reverso Noche |
| `qs_fifty_wins` | Cincuenta / Fifty | Ganar 50 partidas | Efecto de victoria: cascada (las cartas caen y luego los fuegos) |
| `qs_economy` | Economía / Economy | Ganar en menos de 100 movimientos | Mazo Pixel |
| `qs_in_the_red` | Números rojos / In the Red | Llevar el puntaje por debajo de cero (oculto) | Easter egg: pistas a 3 solo en clásico (desde el 2026-10-30 tampoco en práctica; los retos siguen a 10 para que su leaderboard sea parejo; `qs_best_score` sí se beneficia, aceptado como en Quiet Numbers). No aparece en Colección. Mismo premio que en Quiet Numbers (decidido 2026-10-27). |

Siempre disponibles, sin logro: tema **Alto contraste**, mazo **Cuatro colores** y mazo **Índice grande** (accesibilidad), y los tableros **Petróleo y coral claro** y **oscuro** (2026-10-28, como Quiet Numbers): el de por defecto fijo en un modo aunque el iPhone use el otro.

Noctámbulo y Economía eran ocultos; desde el 2026-10-28 muestran su condición en Colección y en Game Center (`showBeforeEarned`, actualizado con `scripts/setup-game-center.py --apply`), para que se sepa cómo ganar la recompensa. Solo Números rojos sigue oculto y no aparece en Colección.

Categorías en Colección: mazo, reverso, tablero, efecto de victoria, pack de sonido, ícono.

## Estética y UX

- **Misma UI y colores que Quiet Numbers**, vía QuietKit: temas por rol (`Theme`), SF Pro Rounded con `.monospacedDigit()`, botones redondos arriba, puntaje grande centrado, barra inferior al alcance del pulgar, splash de Quiet Studios.
- Token nuevo por tema: `suitRed` (palos rojos). Igual al `accent` salvo Salvia y arena (`#B4503A`, el acento ámbar no se lee como rojo) y Alto contraste (`#B3001B`). Contraste ≥ 4,5:1 sobre la cara de la carta; agregar a `theme-colors.py` del kit.
- **Cartas** (canvas, artboard "Mazo Quiet"): índice (rango + palo chico) arriba a la izquierda, un palo grande abajo; As con el palo grande al centro; J/Q/K con un emblema geométrico de trazo sobre un panel `surface2` (J escudo, Q corona suave con una perla, K corona de picos con tres perlas), sin ilustraciones. Todo lo que va debajo del índice (palo, As, panel de figura) ocupa una misma caja: desde el 34 % del alto (40 % con Índice grande) hasta un margen igual al lateral (8 % del ancho), y el palo va centrado en ella. Esquinas de 10 % del ancho, borde de 1 pt y sombra mínima. En oscuro, cara de la carta oscura (`surface` levantado), no blanca.
- **Tamaño en iPhone:** 7 columnas, carta de 48 × 67 pt con 6 pt entre columnas (ancho − 18 pt de margen). Boca abajo asoman 9 pt; boca arriba 22 pt. En iPad las cartas crecen hasta un tablero de 760 pt (como Quiet Numbers). Si una columna no cabe, se comprime el paso de las cartas boca arriba (mínimo 16 pt).
- **Reverso:** color del tema con rayado diagonal fino, marco interior y la marca "pausa" del estudio al centro.
- **Ícono** (`scripts/render-icon.py`, cambiado el 2026-10-30): dos cartas, una inclinada detrás y al frente una blanca con el corazón del mazo Quiet (antes, la marca de pausa). Colores del ícono de Quiet Numbers: el corazón hace de su línea coral (#FF9A85) y la carta de atrás va en su turquesa claro (#5BC2CF); en tinted el corazón es #A6A6A6 y en dorado #C98F2E (el gris y el crema de Numbers no se veían sobre la carta blanca). También el favicon de `../docs/quiet-solitaire`.
- **Pantalla de juego:** volver y menú (redondos), puntaje de 40 pt y "34 movimientos · Mejor 1.240"; fila de fundaciones (4), hueco, descarte y mazo (con contador); tableau; abajo Deshacer y Pista, y la cápsula "Autocompletar" al centro cuando aplica.
- **Animaciones** (nada bloquea el siguiente toque): mover = spring de 0,25 s; voltear = giro en Y de 180 ms; carta a fundación = pequeño "+10" que sube y se desvanece; inválido = anillo coral y sacudida ±4 pt ×3, la carta vuelve con spring; pista = anillo punteado que parpadea 2 veces en origen y destino; victoria = las cartas suben a las fundaciones una a una (efecto "cascada" desbloqueable). Reduce Motion: sin giros ni flotantes, fundidos de 150 ms.
- **Hápticos:** selección al tomar una carta, medio al soltar en tableau, éxito al completar una fundación y al ganar, error en movimiento inválido.
- **Pantallas** (canvas, fila "Pantallas"): Inicio (ícono, "Tu pausa de 5 minutos.", tarjeta del reto con dificultad y racha, Continuar · N movimientos, Nueva partida, estadísticas: victorias, mejor racha, % ganadas; Clasificaciones, Colección y Ajustes en la cápsula de arriba), Reto diario (tarjeta del día, dificultad de la semana, calendario con bandas), Clasificaciones (Hoy / Victorias / Racha × Global / Amigos), Colección (Mazo, Reverso, Tablero…), Ajustes (Sonido, Hápticos, Tocar para mover, Solo partidas con solución, Modo zurdo; Cuenta; Privacidad; Restablecer) y Victoria (hoja con puntaje, desglose, logro desbloqueado, Nueva partida / Inicio).
- Accesibilidad: VoiceOver por carta ("Reina de corazones, columna 3") y por hueco, acciones personalizadas "Mover a fundación / a columna N", Dynamic Type en textos, Alto contraste, Cuatro colores, Índice grande.

## Localización

Igual que Quiet Numbers: inglés (development language y fallback) y español, String Catalogs, ningún texto fijo en vistas, plurales del catálogo, números con `FormatStyle`. Rangos de cartas: A, J, Q, K en ambos idiomas (no se traducen a "R", "D", "J" del español; decisión por reconocimiento universal en móviles).

## Privacidad

Meta: "Data Not Collected", con el mismo criterio y `PrivacyInfo.xcprivacy` que Quiet Numbers. Política en `../docs/quiet-solitaire/`.

## Fases

Cada fase termina con su criterio de aceptación cumplido antes de pasar a la siguiente.

0. **QuietKit.** Extraer a `../QuietKit` (copiando, sin tocar Quiet Numbers) temas, componentes, tipografía, hápticos, sonido, Game Center genérico y `QuietCore`; agregar `suitRed`.
   Acepta: el kit compila y sus tests pasan; una app vacía de Quiet Solitaire muestra el splash y un Inicio con los componentes del kit en claro y oscuro.
1. **Motor (Core).** Cartas, reparto con semilla, movimientos legales, deshacer, puntaje, solver con presupuesto de nodos.
   Acepta: tests cubren cada regla de movimiento, reciclar el mazo, volteo automático, victoria, deshacer, determinismo del reparto y que el solver resuelve repartos conocidos.
2. **Juego jugable.** Tablero, cartas del canvas, tocar y arrastrar pilas, animaciones, hápticos, autocompletar.
   Acepta: una partida completa en iPhone y iPad, arrastre fluido a 120 Hz en un iPhone con ProMotion.
3. **Persistencia y reto diario.** SwiftData, continuar partida, reto con solución garantizada, racha, calendario.
   Acepta: cerrar y volver mantiene el estado; la misma fecha da el mismo reparto en 3 dispositivos; un año de retos es ganable.
4. **Game Center.** Logros, 3 leaderboards, partidas guardadas.
   Acepta: todo funciona en modo avión y sincroniza al reconectar.
5. **Recompensas y colección.** Mazos, reversos, tableros, efecto de victoria, íconos.
   Acepta: cada logro desbloquea su recompensa y se aplica desde Colección.
6. **Pulido y lanzamiento.** Localización, VoiceOver, PrivacyInfo, capturas, TestFlight.
   Acepta: cero textos sin localizar, auditoría de VoiceOver aprobada, build en TestFlight.

## Estado (2026-10-27)

| Fase | Estado |
|---|---|
| Diseño | 🟡 Canvas [Quiet Solitaire](https://claude.ai/artifact/EwWvXPwMtEVpx47drg2AJV) (plantilla de 5 páginas desde el 2026-10-29; el canvas anterior, con las propuestas de header y búsqueda, está en `design/backups/pre-plantilla-2026-10-29/canvas/`). Aprobados: mazo por defecto, reversos y tableros. En revisión: mazos Ilustrado, Clásico y Pixel (iteración 2) y pantallas (Inicio, Reto diario, Clasificaciones, Colección, Ajustes, Victoria). |
| 0. QuietKit | ✅ Hecha. `../QuietKit` compila y sus tests pasan; Quiet Numbers todavía no lo usa (se migra en su 1.1). |
| 1. Motor | ✅ Hecha. Reglas, deshacer, puntaje, solver, reparto diario con dificultad por día, logros; 24 tests. Solver: 80 de 100 repartos al azar resueltos (máximo teórico ~82 %), ~30 ms por reparto en release. |
| 2. Juego jugable | 🟡 Jugable en el simulador (tocar, arrastrar pilas, voltear, pistas, autocompletar, "sin salida", victoria con cascada). Falta probar en un iPhone real y en iPad. |
| 3. Persistencia y reto diario | 🟡 Implementado (SwiftData como Quiet Numbers, reto con solución garantizada, racha, calendario, dificultad de la semana); falta verificar en dispositivo. |
| 4. Game Center | 🟡 13 logros y 3 clasificaciones creados en App Store Connect (2026-10-28, `scripts/setup-game-center.py`); falta activarlos en la versión y verificar envío y sincronización en el dispositivo. |
| 5. Recompensas y colección | 🟡 Mazos (6), reversos (5), tableros (5), efecto de victoria e ícono dorado, con sus desbloqueos; falta revisión en dispositivo. |
| 6. Pulido y lanzamiento | 🟡 Inglés y español completos (206 textos). Tutorial interactivo hecho. Instalada en iPhone 16 Pro (2026-10-27). Ficha subida por la API y builds 1.0 (1) y 1.0 (2) subidos a TestFlight (2026-10-28). Falta: capturas, metadatos, insignias de Game Center, TestFlight. Auditoría de VoiceOver: pospuesta (decisión del usuario). |

## Preguntas abiertas

- [x] Modalidad: Klondike robar 1 (robar 3 quizá como opción futura).
- [x] Nombre en la App Store (2026-10-28): **Quiet Solitaire: Card Game** ("Quiet Solitaire" y "Quiet Solitaire: Klondike" ya estaban tomados). Subtítulo en inglés "Classic Klondike with no ads" (para no repetir "card game"); "klondike" en las palabras clave. En la pantalla de inicio sigue "Quiet Solitaire". Bundle ID `com.tavoohoh.quietsolitaire`, SKU `quietsolitaire-ios`.
- [x] "UI kit" = paquete compartido QuietKit, no el framework UIKit.
- [x] Dificultad del reto por día de la semana: sí.
- [x] Puntaje: reciclar 0 (cada toque al mazo es movimiento), pista −10, logro "Números rojos" con pistas a 3 fuera del reto.
- [x] Bundle ID: `com.tavoohoh.quietsolitaire`.
