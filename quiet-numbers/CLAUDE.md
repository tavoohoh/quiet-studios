# Quiet Numbers

Puzzle de números: vaciar el tablero eliminando parejas de números iguales o que sumen 10. Gratis, sin anuncios, sin compras y sin recolectar datos. Primera app de la familia Quiet (ver `../CLAUDE.md`).

Nombre: **Quiet Numbers** (alternativa evaluada: "Diez"). Nunca usar "Number Match" ni assets de Easybrain.

## Principios no negociables

- Sin anuncios, compras in-app, suscripciones ni tip jar.
- Sin backend, analytics, crash reporters ni SDKs de terceros. Ninguna llamada de red propia.
- 100% offline. Game Center es un extra que sincroniza al reconectar.
- Recompensas solo cosméticas, ganadas con logros. Única excepción: el easter egg de "Números rojos" (pistas más baratas fuera del reto diario puntuable).
- Sin identificadores propios, fingerprinting ni App Tracking Transparency.
- Frameworks permitidos: SwiftUI, SwiftData, GameKit y StoreKit **solo** para `requestReview()`.

## Stack

| Pieza | Decisión |
|---|---|
| UI | SwiftUI nativo. Sin SpriteKit. |
| Lenguaje | Swift 6, strict concurrency. |
| Sistemas mínimos | iOS 18 / iPadOS 18 (decidido 2026-10-26: más dispositivos). En Mac corre la versión de iPad ("Designed for iPad", Apple silicon). |
| Persistencia | SwiftData (fuente principal de verdad). |
| Online | GameKit únicamente. |
| Tests | Swift Testing para la lógica del juego. |
| Dependencias externas | Ninguna. |
| Estado | `@Observable`; sin frameworks de arquitectura externos. |

Un solo target iOS (iPhone y iPad); en Mac con Apple silicon se ofrece la app de iPad (decisión 2026-10-26: sin versión nativa de macOS ni capturas de Mac). Un bundle ID.

## Comandos

- **Instalar en un iPhone propio sin cuenta paga:** copiar `Config/Local.xcconfig.example` a `Config/Local.xcconfig` (ignorado por git), poner el Team ID del Personal Team y un bundle ID propio, `xcodegen generate`, y correr desde Xcode con el iPhone conectado. El Personal Team no admite Game Center ni iCloud (el archivo local usa `QuietNumbers-Personal.entitlements`, sin ellos) y el perfil vence a los 7 días.

- El `.xcodeproj` se genera desde `project.yml` con XcodeGen: correr `xcodegen generate` tras agregar o mover archivos. No editar el `.pbxproj` a mano.
- Tests del Core: `cd Packages/QuietNumbersCore && swift test`.
- Todos los tests (Core en iOS, app y UI): `xcodebuild test -project QuietNumbers.xcodeproj -scheme QuietNumbers -destination 'platform=iOS Simulator,name=iPhone 17'`.
- Capturas de la App Store: `scripts/screenshots.sh [iphone] [ipad]` (esquema `Screenshots`, target `QuietNumbersScreenshots`) → `AppStore/screenshots/<iphone-6.9|ipad-13>/<en|es>/<light|dark>/`. Solo iPhone y iPad (decisión: sin capturas de Mac); el español sirve para es-MX y es-ES.
- Imágenes de la App Store: `scripts/store-images.py` (después de `screenshots.sh`) compone los marcos del canvas (páginas "App Store 01–05": fondo, titular, callouts) alrededor de capturas reales → `AppStore/store-images/<iphone-6.9|ipad-13>/<en|es>/`. Las imágenes 1, 2 y 4 usan el tablero armado del canvas (`-storeScene 1|2|4`, `DemoData.StoreScene`) y sus callouts se anclan a las celdas reales. Sin combos ni textos que la app no tenga (en la 4, "Combo ×4 +120" pasó a "¡10 seguidas!").
- Arte: `scripts/render-artwork.py` genera desde SVG el ícono (claro, oscuro, tinted y Gold), el lockup del splash (`SplashLockup`, también en la launch screen) y las insignias de Game Center (`AppStore/achievements/<id>.png`, 1024 sin alfa; en la app, redondas en `Assets.xcassets/Badges`, para Colección y el aviso de logro). `scripts/theme-colors.py` escribe los colorsets de los temas (`Assets.xcassets/Themes`, `AccentColor`, `LaunchBackground`) y falla si un texto queda bajo 4,5:1. Los valores vienen del canvas "Quiet Numbers · Diseño" (página 6, brief para Claude Code).
- Metadatos: `fastlane/metadata/{en-US,es-MX,es-ES}`; validar con `scripts/validate-metadata.py`. Game Center: `AppStore/game-center.{md,json}`; verificar IDs con `scripts/check-game-center.py`.
- UI test en simulador: `xcodebuild test -project QuietNumbers.xcodeproj -scheme QuietNumbers -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:QuietNumbersUITests`.
- Argumentos DEBUG: `-demo` carga el estado fijo de las capturas (`App/Debug/DemoData.swift`: 14-nov-2026 10:00, partida a medias, racha de 8, leaderboards de ejemplo; en memoria); `-startGame` abre una partida directo; `-seedKey <texto>` hace el tablero determinista; `-boardValues 5,3,7,…` arranca con números exactos; `-slowEffects` pone los efectos en cámara lenta (×6) para inspeccionarlos. `-startGame` usa almacenamiento en memoria; `-uiTesting` usa un archivo propio (`UITests.store`) que `-resetStore` borra, para no tocar los datos reales. `-unlockAll` desbloquea todos los logros (QA y capturas).

## Arquitectura

Dos capas: el paquete `QuietNumbersCore` (lógica pura y testeable) y la app SwiftUI que lo consume.

- El Core **no importa** SwiftUI, SwiftData ni GameKit.
- Los modelos del Core son `Codable` (se guardan en SwiftData y en partidas de Game Center).

```
quiet-numbers/
├── QuietNumbers.xcodeproj          # target multiplataforma
├── App/
│   ├── QuietNumbersApp.swift
│   ├── Features/
│   │   ├── Home/
│   │   ├── Game/                   # tablero, celdas, barra superior
│   │   ├── DailyChallenge/         # reto + calendario
│   │   ├── Leaderboards/
│   │   ├── Collection/             # logros y personalización
│   │   └── Settings/
│   ├── Services/
│   │   ├── GameCenterService.swift
│   │   ├── PersistenceService.swift
│   │   ├── HapticsService.swift
│   │   └── SoundService.swift
│   ├── DesignSystem/               # temas, colores, tipografía, estilos de ficha
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Localizable.xcstrings
│       ├── InfoPlist.xcstrings
│       └── PrivacyInfo.xcprivacy
└── Packages/
    └── QuietNumbersCore/
        ├── Sources/QuietNumbersCore/
        │   ├── Board.swift          # grilla, celdas, compactar filas
        │   ├── MatchRules.swift     # validación de parejas y conexiones
        │   ├── GameSession.swift    # +, pistas, puntaje, etapas, fin
        │   ├── BoardGenerator.swift
        │   ├── SeededRandom.swift   # PRNG determinista
        │   ├── DailyChallenge.swift # fecha → semilla → tablero
        │   └── Achievements.swift   # reglas de logros y desbloqueos
        └── Tests/QuietNumbersCoreTests/
```

## Reglas del juego

Tablero de **9 columnas**; arranca con **42 números** del 1 al 9 (4 filas y media; antes 27, se igualó a otros juegos del género). Que un número no tenga pareja al inicio (p. ej. tres 5) es normal: el + duplica todo lo que queda.

**Pareja válida:** dos números iguales (4-4) o que sumen 10 (3-7, 5-5).

**Conexiones válidas** entre las dos celdas:
1. Adyacentes en horizontal, vertical o diagonal.
2. En la misma línea (horizontal, vertical o diagonal) con solo celdas eliminadas entre ellas.
3. Lectura continua: el tablero se lee como tira izquierda→derecha, arriba→abajo; el último número de una fila conecta con el primero de la siguiente, saltando eliminadas.

**Mecánicas:**
- Celdas eliminadas quedan como "fantasma" (número tenue) hasta que su fila se vacía.
- Fila vacía: desaparece, el tablero sube y da puntos extra.
- Botón **+**: copia todos los números restantes, en orden, al final del tablero (regla estándar del género; se evaluó triplicar y se descartó). **Máximo 5 usos por tablero**; limpiar filas no devuelve usos (cambio del 2026-10-26). Sin parejas ni usos, la partida termina. Los números agregados se muestran en el acento coral del tema para distinguirlos de los originales.
- **Pistas:** ilimitadas; resaltan una pareja válida y cuestan 10 puntos, **aunque el puntaje quede negativo** (cambio del 2026-10-26; da el logro "Números rojos"). Con "Números rojos" cuestan 3 en clásico y práctica (`Scoring.cheapHints`, `AppModel.unscoredScoring`); el reto diario puntuable siempre cobra 10. Cada partida guarda su `Scoring`, así que el cambio aplica desde la siguiente. Si no hay parejas, no cobran.
- **Etapas:** vaciar el tablero pasa a la siguiente etapa con tablero nuevo; los usos de + se reinician. Cada etapa es más difícil (decisión 2026-10-26): números al inicio 42, 44, 48, 50 y 54 desde la etapa 5 (siempre pares, por `isPairable`); usos de + 5, 5, 4, 4 y 3; parejas al inicio 3–5, 2–4 y 2–3 desde la etapa 3 (decisión 2026-10-27; ver generación abajo); desde la etapa 3 cada pareja vale 1 punto más. El reto diario es una sola etapa con las reglas de la 1.
- **Partida terminada:** solo cuando ya no quedan parejas ni usos de + (vaciar el tablero no la termina en clásico). Para el Inicio, "Partidas" cuenta las terminadas más las clásicas abandonadas con al menos una jugada (`gamesPlayed`); el mejor puntaje se actualiza en vivo durante la partida y se envía a Game Center al salir. "Racha récord" (Top streak) es la racha más larga de retos completados en días seguidos.
- **Fin de partida:** no quedan parejas válidas ni usos de +.
- **Deshacer:** retrocede la última pareja o el último + (un solo paso; no se encadena). No se puede después de vaciar un tablero ni con la partida terminada. No devuelve el costo de pistas ni restaura una racha rota, y descuenta del progreso lo que la jugada había sumado.
- **Generación (2026-10-27):** un tablero al azar arranca con ~30 parejas (mediana 28 con 42 números) y se sentía demasiado fácil. Ahora se construye: cada número evita la familia de sus vecinos ya puestos (izquierda/lectura, arriba y diagonales de arriba), y luego se cambian unas pocas celdas para dejar las parejas del rango de la etapa (3–5, 2–4, 2–3; nunca menos de 2, para que la primera jugada sea una elección). También exige que cada familia ({1,9}, {2,8}, {3,7}, {4,6}, {5}) tenga cantidad par, para que "Sin ayuda" sea posible en principio. Además, para que jugando se abran parejas nuevas, el tablero solo se acepta si la mediana de 15 partidas al azar (sin +) llega a 8, 7, 6, 6 y 5 jugadas por etapa (`typicalMoves`; ajuste del 2026-10-27 tras probar en el iPhone: sin esto, a veces solo había 3–5 jugadas antes del +). Generar toma ~15 ms (máx. ~90). Con un jugador simulado que elige al azar, vaciar el tablero quedó en ~50 % en las etapas 1–2, ~25 % en la 3 y ~19 % en la 5 (antes, al azar: 77 % y 55 %). Referencia: en 4 de 5 tableros iniciales de otros juegos del género, la jugada típica se traba a las 3. Cambiar el generador cambia el tablero de cada fecha: dos versiones con generadores distintos no pueden convivir en la tienda sin una fecha de corte.

**Puntaje** (valores iniciales, ajustables — mantenerlos configurables):
- Pareja adyacente: 1 (+1 desde la etapa 3)
- Pareja con eliminadas entre medio: 4 (+1 desde la etapa 3)
- Fila limpiada: 10
- Tablero limpiado: 150 × número de etapa
- Pista: −10 (−3 con "Números rojos", salvo en el reto diario)

## Reto diario

Tablero único por día, igual para todo el mundo, generado en el dispositivo sin servidor.

- **Semilla:** clave del día `yyyy-MM-dd` → hash estable (FNV-1a).
- **Cambio de día:** a la **medianoche de la zona horaria del dispositivo** (`DailyChallenge.rolloverHour = 0`, cambio del 2026-10-27 para poder jugar el reto a cualquier hora; antes 19:00). La clasificación `daily_challenge` recurre desde las 05:00 UTC, la medianoche de Colombia. La misma clave da el mismo tablero en todo el mundo, pero cada dispositivo la habilita según su reloj.
- **PRNG:** propio y determinista (SplitMix64 o Xoshiro256). **Nunca** `SystemRandomNumberGenerator`. Evitar cualquier API cuyo resultado dependa de plataforma (p. ej. `Hasher`, `shuffled()` sin generador propio).
- **Validación:** si el tablero no cumple el mínimo de parejas, avanzar la semilla de forma determinista hasta obtener uno válido.
- **Formato (2026-10-27, idea de una probadora):** meta de puntos del día, 400–700 en pasos de 50 (`DailyChallenge.goal`, de un flujo aparte de la semilla para no cambiar los tableros). Se juegan etapas como en clásico, con tableros que también salen de la semilla (el generador solo avanza al crear un tablero, nunca con jugadas), así que son iguales para todos. El reto se completa **al llegar a la meta** (racha, calendario y logros en ese momento) y se puede seguir jugando por más puntaje; termina sin parejas ni +. La clasificación diaria recibe el puntaje al terminar o al salir del juego después de la meta. Retos guardados antes del cambio (`goal == nil`) siguen con la regla vieja: una etapa, completado al vaciarla. Un solo intento puntuable por día; se puede rejugar sin enviar puntaje.
- **Racha:** días consecutivos completados, guardada localmente, usada para logros.
- **Calendario:** vista mensual de retos completados; los últimos 30 días se pueden jugar sin puntuar.
- **Decisiones de implementación (fase 3):**
  - "Completar" un reto = llegar a su meta de puntos (antes: vaciar el tablero). Terminar sin llegar guarda el puntaje (cuenta como intento) pero no suma a la racha.
  - El intento puntuable empieza al tocar "Jugar" por primera vez ese día; si se sale a mitad, se reanuda (sigue puntuando).
  - Repeticiones y días pasados son "Práctica": no cuentan para racha, clasificación ni logros de retos. Una práctica a medias se guarda por día (ranura `practice-<día>`; "Continue" y un punto en el calendario) y se borra al terminar o al salir de la ventana de 30 días (2026-10-27). Un día pasado vaciado como práctica se marca con relleno suave (`PlayerProgress.practicedDays`, viaja con el progreso).
- **Test obligatorio:** la misma fecha produce siempre el mismo tablero en todos los dispositivos.

## Game Center

Opcional: sin sesión, el juego funciona completo y los logros se guardan localmente; al autenticarse se sincroniza lo pendiente.

- Autenticación con `GKLocalPlayer.local.authenticateHandler` al iniciar, sin bloquear la UI.
- Logros: `GKAchievement` con progreso porcentual; se reportan también offline.
- Leaderboards:
  - `daily_challenge` — recurrente, se reinicia cada 24 h.
  - `best_score` — clásico, mejor puntaje del modo libre.
  - `longest_streak` — clásico, racha más larga de retos diarios.
- Global y amigos vía `GKLeaderboard.loadEntries(for: .global | .friendsOnly, timeScope:range:)`. Incluir `NSGKFriendListUsageDescription`.
- UI: pantalla propia minimalista (pestañas Global / Amigos) + `GKAccessPoint` al panel nativo.
- Partidas guardadas: `saveGameData` / `fetchSavedGames` (iCloud del usuario). SwiftData es siempre la fuente principal. Conflictos: `resolveConflictingSavedGames` conservando el estado con más progreso.
- Challenges (iOS 26+): evaluar integración con el reto diario y la app Games.

### Estado de la integración (fase 4)

El código está completo (`GameCenterService`, `LeaderboardsView`, sincronización en `AppModel.syncGameCenter`), pero **no está verificado contra Game Center real**: falta registrar la app. Sin sesión todo funciona y se guarda localmente (verificado con UI test). Pendiente cuando exista el bundle ID:

1. Crear el App ID y activar las capacidades **Game Center** e **iCloud** (iCloud Documents, contenedor `iCloud.<bundle id>`; el entitlement ya está en `App/QuietNumbers.entitlements`).
2. En App Store Connect, crear los leaderboards `daily_challenge` (recurrente, 24 h, inicio 05:00 UTC = 00:00 en Colombia; en otras zonas la ventana del leaderboard no coincide exactamente con el cambio de reto local), `best_score` y `longest_streak` (clásicos), y los logros `first_step`, `clean_slate`, `no_help`, `in_the_red`, `consistency`, `habit`, `sweeper`, `stage_five`, `centennial`, `night_owl`, `monotone`, con textos en inglés y español.
3. Probar con una cuenta sandbox: modo avión → jugar → reconectar → verificar envío.

Decisiones:
- No se fuerza el inicio de sesión: la pantalla de login de Game Center solo aparece si el jugador la pide ("Abrir Ajustes" en Clasificaciones o la fila de Game Center en Ajustes); si GameKit no la ofrece, se abren los Ajustes de la app. `GKAccessPoint` solo en Inicio y con sesión.
- **Progreso en iCloud: requerido.** Vía partidas guardadas de Game Center (necesita sesión). Entitlements de iCloud Documents con contenedor `iCloud.$(CFBundleIdentifier)` en `App/QuietNumbers.entitlements` (el de Personal Team no los tiene).
- **Restablecer progreso** (Ajustes): borra partidas, retos, rachas, logros y recompensas en local, el guardado de iCloud y los logros de Game Center (`resetAchievements`). Sin sesión, queda pendiente (`pendingCloudReset`) y se hace al iniciar sesión, antes de sincronizar. Los puntajes de leaderboards no se pueden retirar; otros dispositivos conservan su copia local.
- `daily_challenge` guarda el puntaje **más reciente** (también 0 o negativo); `best_score` y `longest_streak` solo valores > 0.
- Partidas guardadas: se guarda un `Snapshot` (progreso + resultados diarios). Los conflictos se resuelven **fusionando** (unión de logros, máximo de cada contador, mejor resultado por día), lo que siempre conserva el mayor progreso. La partida clásica en curso no se sincroniza.

## Logros y recompensas

Toda recompensa es cosmética y nunca altera la jugabilidad ni el layout del tablero, salvo el easter egg de "Números rojos". Los desbloqueos se calculan y guardan localmente.

| Logro | Condición | Recompensa |
|---|---|---|
| Primer paso | Vaciar el primer tablero o terminar la primera partida | Tema Petróleo y coral (por defecto) |
| Tabla rasa | Vaciar un tablero sin usar + | Ficha: círculo |
| Sin ayuda | Vaciar un tablero sin usar pistas (el + sí vale) | Tema Salvia y arena |
| Constancia | Racha de 7 retos diarios | Tema Índigo y durazno |
| Hábito | Racha de 30 retos diarios | Tipografía New York (serif) |
| Barrendero | Limpiar 100 filas en total | Efecto de limpieza: ola |
| Etapa 5 | Llegar a la etapa 5 en una partida | Ficha: contorno |
| Centenario | Completar 100 retos diarios | Ícono alternativo dorado |
| Noctámbulo | Completar un reto entre 00:00 y 04:00 | Tema Salvia y coral |
| Monótono | 10 parejas seguidas del mismo número | Pack de sonido: marimba |
| Números rojos | Llevar el puntaje por debajo de cero | Easter egg oculto: pistas a 3 en clásico y práctica (decisión 2026-10-26, opción B: el reto diario sigue a 10 para que su leaderboard sea parejo; `best_score` sí se beneficia, aceptado). No aparece en Colección. |

El tema **Alto contraste** (accesibilidad) está siempre disponible, sin logro.

Categorías de personalización: tema de color, estilo de ficha, tipografía, efecto al limpiar fila, pack de sonido, ícono de la app. Se eligen en "Colección"; lo bloqueado muestra su condición.

Decisiones de implementación (fase 5):
- "Monótono" se interpreta como 10 parejas seguidas de números iguales (4-4, 7-7…), no 10 veces el mismo dígito. Confirmado.
- Las opciones por defecto (Petróleo y coral, Simple, SF Rounded, Contorno, Suave, ícono estándar) están siempre disponibles.
- Rediseño 2026-10-26: los temas viejos se reemplazaron conservando el desbloqueo (Papel → Petróleo y coral, Pizarra → Salvia y arena, Arena → Índigo y durazno, Medianoche → Salvia y coral, Brasa → Alto contraste). La preferencia guardada se migra al arrancar (`ThemeChoice.migrateSavedChoice`).
- Colores por rol (`Theme`: background, surface, surface2, ink, muted, primary, onPrimary, accent, ghost, separator) en el Asset Catalog (`TealCoralPrimary`, `SageSandInk`…). Solo Petróleo y coral tiene claro y oscuro: sigue al sistema, y sus variantes Claro y Oscuro (siempre disponibles, 2026-10-27) fijan un modo para quien quiere el juego distinto al teléfono; Salvia y arena, Salvia y coral y Alto contraste son solo claros, Índigo y durazno solo oscuro, y fuerzan ese esquema. Alto contraste además pone borde de 2 pt a las superficies y subraya los números agregados.
- Los sonidos se sintetizan en el dispositivo (AVAudioEngine, sin archivos), categoría `.ambient` (respeta el modo silencio). Sonido y hápticos activados por defecto.
- El ícono dorado funciona en iPhone y iPad (en Mac, la app de iPad no cambia de ícono).
- Preferencias en `UserDefaults` (`@AppStorage`); progreso y logros en SwiftData (`StoredProgress`). Las partidas de práctica también cuentan para logros de juego.

## Estética y UX

- Diseño cerrado en el canvas "Quiet Numbers · Diseño" (Claude Design, 2026-10-26); la página 6 es el brief con todos los valores.
- **Paleta principal Petróleo y coral** (tema por defecto, claro y oscuro): primario `#0E6B78` / `#5BC2CF` (botones, selección, línea de unión, iconos), acento coral `#B9472F` / `#FF9A85` (números agregados con +, racha, elogios, rayos del tiro largo), fondo `#F3F7F8` / `#0F1A1D` (nunca blanco puro salvo Alto contraste). Ajustes por contraste frente al brief: primario de Salvia y arena `#387454` (era `#3E7A5A`) y surface2 de Salvia y coral `#EFEAE0` (era `#EDE7DC`).
- Nada de colores fijos en vistas: todo sale de `appearance.theme`. Componentes en `DesignSystem/Components.swift` (botón cápsula de 56 pt, tarjetas, segmentos, secciones agrupadas, switch, toast, encabezado con botón redondo de volver; la barra de navegación del sistema va oculta).
- SF Pro Rounded con `.monospacedDigit()`.
- Tablero: celdas de (ancho − 48) / 9 × 46 pt (52 con "Números más grandes"; cuadradas en iPad), números de 27 pt (32). Fichas sin bordes, solo el número. Seleccionada: anillo de 40 pt, trazo 2 pt del primario sobre 14 % de relleno. Eliminada: `ghost`.
- Animaciones (brief, sección 7; nada bloquea el siguiente toque): selección = anillo 0,6→1 con spring; pareja válida = línea de 120 ms; al llegar, cada número estalla en 8 rayos (15→25 pt, 260 ms; coral en tiro largo) y queda como fantasma; "+N" sale del punto medio de la pareja, sube 24 pt y se desvanece (600 ms) mientras el puntaje cuenta; inválida = ambos anillos en coral y sacudida de ±4 pt ×3 (240 ms); pista = anillo punteado que parpadea 2 veces; fila completa = se ilumina y colapsa en 280 ms; + = los números entran uno a uno (160 ms, 25 ms entre cada uno, máx. 1,2 s). Reduce Motion: sin rayos, flotantes ni sacudida; el par se funde en 150 ms.
- Tres grosores de línea según las celdas eliminadas entre la pareja: sutil (0), media (1–3) y dramática (4+, coincide con "¡Tiro largo!"). En lectura continua entre filas, la línea entra desde los bordes del tablero.
- Ritmo: `Animation.quiet` = snappy 0.2 s para el resto; un toque nuevo termina la jugada en curso al instante.
- **Arrastrar para juntar** (2026-10-26): además de tocar uno y otro, se arrastra de un número a otro (línea del primario hasta el dedo; al soltar se intenta la pareja). Arrastrar desde un fantasma o un hueco desplaza el tablero.
- **Tutorial interactivo** (`Features/Tutorial`): sale al tocar "Nueva partida" la primera vez (sin partidas terminadas ni en curso y sin `tutorialSeen`, que Restablecer progreso borra) y desde Ajustes › Cómo jugar. Tablero armado a mano (`TutorialScript`, verificado por `TutorialScriptTests`) con 7 pasos: iguales en horizontal, suman 10 en vertical, diagonal, tiro largo, cambio de fila, vaciar una fila y +. Solo vale la jugada señalada (anillo de pista); no suma progreso. "Saltar" siempre visible. Los UI tests lo omiten salvo con `-tutorial`.
- Pista sin parejas: no cobra, muestra "No hay parejas. Prueba +" y hace rebotar el botón +.
- Racha ("¡N seguidas!"): se reinicia con un intento inválido o al pedir pista; el + no la reinicia.
- Hápticos (iOS): selección al seleccionar y al pedir pista, medio al emparejar, éxito en tiro largo y al limpiar fila, error en pareja inválida.
- Barra superior: volver y menú (redondos); debajo, puntaje de 44 pt y "Etapa 2 · Mejor 1.234" (récord siempre visible en clásico, aunque sea 0), con los elogios como toast a la derecha.
- Barra inferior: Deshacer, + (con usos restantes) y Pista (con su costo), al alcance del pulgar.
- Récord (mejor puntaje clásico) también en Inicio ("Tus estadísticas": mejor puntaje, mejor racha y partidas, totales que ya se guardan) y "¡Nuevo récord!" en el fin de partida. Una partida clásica abandonada con "Nueva partida" también cuenta para el récord (sin contar como partida terminada).
- Splash al abrir: lockup "quiet studios" (Q en pausa + nombre en minúsculas, marca sin traducir). La launch screen (`UILaunchScreen` en project.yml) muestra la misma imagen sobre `LaunchBackground`; el splash se queda 1,2 s y hace crossfade de 250 ms al Inicio (corte directo con Reduce Motion). Un toque lo salta. Se omite con `-startGame`/`-uiTesting`/`-demo`.
- Feedback por jugada: "+N" desde la pareja (costos de pista y deshacer: en gris junto al puntaje; con Reduce Motion todo junto al puntaje) y elogios en un toast junto al puntaje (entra en 180 ms, queda 1,2 s): "¡Tiro largo!" (4+ celdas eliminadas entre la pareja), "¡Doble/Triple fila!", "¡Ya no hay más 7!" (se eliminó el último de un dígito), "¡N seguidas!" (cada 5 parejas sin error). Solo texto, no dan puntos. El juego no tiene combos.
- Pantallas: Inicio (ícono, "Tu pausa de 5 minutos.", reto diario con racha, "Continuar · Etapa N", Nueva partida, estadísticas; Clasificaciones, Colección y Ajustes en una cápsula arriba a la derecha), Juego, Reto diario (tarjeta del día en primario con racha, mejor racha y puesto entre amigos; calendario con bandas entre días seguidos), Clasificaciones (medallas, avatar con inicial, fila propia resaltada; sin Game Center, filas esqueleto y botón que abre el inicio de sesión de Game Center si GameKit lo ofrece, o Ajustes), Colección, Ajustes (Juego, Cuenta con Game Center y Cómo jugar, Privacidad, Restablecer progreso, Versión).
- Responsivo por size class (`DesignSystem/Layout.swift`): en regular (iPad) el tablero crece hasta 760 pt, el calendario y los botones se agrandan, y listas/formularios usan una columna centrada de 680 pt (`readableColumn()`). Teclado (⌘Z, +, h) en iPad con teclado y en Mac.
- Accesibilidad: Dynamic Type, VoiceOver por celda ("7, fila 3, columna 2"), contraste suficiente, opción de números más grandes.

## Localización

- El idioma lo decide el sistema; sin selector propio. Idiomas: `en` (development language y fallback) y `es`.
- `Localizable.xcstrings` + `InfoPlist.xcstrings`. **Ningún texto fijo en vistas**: usar `String(localized:)` o `LocalizedStringKey`.
- Plurales con variaciones del catálogo ("1 pista" / "3 pistas").
- Números, fechas y puntajes con `FormatStyle` según el locale.
- Logros y leaderboards se localizan en App Store Connect (en/es).
- Agregar un idioma debe requerir solo traducir el catálogo.
- Test: en un idioma no soportado (p. ej. francés) todo aparece en inglés.

## Privacidad

Meta: "Data Not Collected". Ningún dato sale del dispositivo salvo lo que el usuario envía a Game Center / iCloud.

Entregables:
- `PrivacyInfo.xcprivacy` con las Required Reason APIs usadas (p. ej. `UserDefaults`) y cero datos recolectados.
- Política de privacidad corta en inglés y español.
- Verificar en la documentación de Apple cómo declarar Game Center en la etiqueta de privacidad.

Decisión de la etiqueta: **Data Not Collected**. Investigado (2026-10-25): Apple define "recolectar" como enviar datos fuera del dispositivo de forma que el desarrollador pueda accederlos, y aclara "You are not responsible for disclosing data collected by Apple". La indicación de declarar "Gameplay Content" por partidas guardadas aplica cuando el desarrollador las recibe (servidor propio); aquí van al iCloud del usuario vía GameKit y nunca las vemos. Condición para mantenerla: **no** guardar ni enviar nada leído de Game Center (nombres, amigos, puntajes de otros); los leaderboards solo se muestran en pantalla.

Estado (fase 6):
- `App/Resources/PrivacyInfo.xcprivacy`: sin tracking, cero tipos de datos recolectados, `UserDefaults` con razón `CA92.1`.
- Política de privacidad, soporte y página de la app en/es: `../docs/quiet-numbers/` (GitHub Pages desde `/docs` en la raíz del repo; falta el correo de soporte y activar Pages).
- Etiqueta de privacidad, según [App privacy details](https://developer.apple.com/app-store/app-privacy-details/): "You are not responsible for disclosing data collected by Apple" y "recolectar" = enviar datos fuera del dispositivo de forma que el desarrollador pueda accederlos. Ver decisión arriba.

## Fases

Cada fase termina con su criterio de aceptación cumplido antes de pasar a la siguiente.

1. **Motor del juego (Core).** Tablero, parejas y conexiones, +, pistas, puntaje, etapas, PRNG con semilla.
   Acepta: tests cubren las 3 conexiones, filas vacías, fin de partida y determinismo del generador.
2. **Juego jugable.** Pantalla de juego, selección, animaciones, hápticos, claro/oscuro.
   Acepta: una partida completa se juega en iPhone y iPad.
3. **Persistencia y reto diario.** SwiftData, continuar partida, reto diario, racha, calendario.
   Acepta: cerrar y volver mantiene el estado; la misma fecha genera el mismo reto en los 3 dispositivos.
4. **Game Center.** Autenticación, logros, 3 leaderboards (global y amigos), partidas guardadas.
   Acepta: todo funciona en modo avión y sincroniza al reconectar.
5. **Recompensas y colección.** Temas, fichas, tipografías, efectos, sonidos, íconos alternativos.
   Acepta: cada logro desbloquea su recompensa y se aplica desde Colección.
6. **Pulido y lanzamiento.** Localización completa, accesibilidad, PrivacyInfo, capturas, TestFlight.
   Acepta: cero textos sin localizar, auditoría de VoiceOver aprobada, build en TestFlight.

## Estado (2026-10-27)

| Fase | Estado |
|---|---|
| 1. Motor | ✅ Hecha |
| 2. Juego jugable | ✅ Hecha (probada en iPhone real; iPad en simulador con layout responsivo) |
| 3. Persistencia y reto diario | ✅ Hecha |
| 4. Game Center | 🟡 App ID, 11 logros y 3 clasificaciones creados en App Store Connect (`scripts/setup-game-center.py`); falta verificar envío y sincronización en el dispositivo |
| 5. Recompensas y colección | ✅ Hecha |
| 6. Pulido y lanzamiento | 🟡 Localización auditada (0 textos sin traducir, fallback a inglés verificado), PrivacyInfo, política de privacidad, Dynamic Type en Inicio/Juego. Capturas de iPhone y iPad, metadatos y web listos. Build 1.0 (1) en TestFlight (beta externa en revisión) y versión 1.0 enviada a revisión de la App Store el 2026-10-27, con publicación automática al aprobarse. Pendiente (decidido posponer): auditoría de VoiceOver; la ficha no declara VoiceOver |

## Anotaciones de diseño

- **Rediseño visual (2026-10-26, rama `design/teal-coral`)** según el brief del canvas: temas, ícono, splash, pantallas y animaciones. Pendiente la revisión del usuario en el dispositivo.

## Preguntas abiertas

- [x] + : máximo 5 por tablero, sin devolución al limpiar filas.
- [x] Color primario: petróleo (reemplazó al azul eléctrico).
- [x] Paleta: Petróleo y coral (diseño cerrado con Claude Design el 2026-10-26, canvas "Quiet Numbers · Diseño").
- [x] Nombre en la App Store (2026-10-27): **Quiet Numbers: Calm Puzzle** ("Quiet Numbers" ya estaba reservado), subtítulo "Match equal pairs or make 10" / "Junta iguales o que sumen 10". En la pantalla de inicio sigue "Quiet Numbers". Bundle ID `com.tavoohoh.quietnumbers`, cuenta individual (el Team ID solo va en `Config/Local.xcconfig`), app en App Store Connect con SKU `quietnumbers-ios`; Game Center creado con `scripts/setup-game-center.py`.
- [x] Nombre final: **Quiet Numbers**; estudio **Quiet Studios**. Búsqueda (2026-10-26): ninguna app con esos nombres en la App Store; existen quietnumbers.com (plantillas financieras) y quietstudios.com (estudio de arquitectura/diseño), rubros distintos. No se hizo búsqueda formal de marcas (USPTO / SIC).
- [x] Versión mínima: iOS/iPadOS 18.
- [ ] Team de Apple Developer (pendiente de crear; bloquea Game Center, TestFlight y App Store).
