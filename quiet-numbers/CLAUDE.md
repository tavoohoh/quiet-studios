# Quiet Numbers

Puzzle de números: vaciar el tablero eliminando parejas de números iguales o que sumen 10. Gratis, sin anuncios, sin compras y sin recolectar datos. Primera app de la familia Quiet (ver `../CLAUDE.md`).

Nombre: **Quiet Numbers** (alternativa evaluada: "Diez"). Nunca usar "Number Match" ni assets de Easybrain.

## Principios no negociables

- Sin anuncios, compras in-app, suscripciones ni tip jar.
- Sin backend, analytics, crash reporters ni SDKs de terceros. Ninguna llamada de red propia.
- 100% offline. Game Center es un extra que sincroniza al reconectar.
- Recompensas solo cosméticas, ganadas con logros.
- Sin identificadores propios, fingerprinting ni App Tracking Transparency.
- Frameworks permitidos: SwiftUI, SwiftData, GameKit y StoreKit **solo** para `requestReview()`.

## Stack

| Pieza | Decisión |
|---|---|
| UI | SwiftUI nativo. Sin SpriteKit. |
| Lenguaje | Swift 6, strict concurrency. |
| Sistemas mínimos | iOS 18 / iPadOS 18 / macOS 15 (pendiente; subir a 26 si se usan Challenges de Game Center). |
| Persistencia | SwiftData (fuente principal de verdad). |
| Online | GameKit únicamente. |
| Tests | Swift Testing para la lógica del juego. |
| Dependencias externas | Ninguna. |
| Estado | `@Observable`; sin frameworks de arquitectura externos. |

Un solo target multiplataforma (iPhone, iPad, Mac), compra universal, un bundle ID.

## Comandos

- El `.xcodeproj` se genera desde `project.yml` con XcodeGen: correr `xcodegen generate` tras agregar o mover archivos. No editar el `.pbxproj` a mano.
- Tests del Core: `cd Packages/QuietNumbersCore && swift test`.
- Todos los tests (Core en iOS, app y UI): `xcodebuild test -project QuietNumbers.xcodeproj -scheme QuietNumbers -destination 'platform=iOS Simulator,name=iPhone 17'`.
- UI test en simulador: `xcodebuild test -project QuietNumbers.xcodeproj -scheme QuietNumbers -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:QuietNumbersUITests`.
- Argumentos DEBUG: `-startGame` abre una partida directo; `-seedKey <texto>` hace el tablero determinista (`2026-10-25` da el tablero golden de los tests); `-boardValues 5,3,7,…` arranca con números exactos; `-slowEffects` pone los efectos en cámara lenta (×6) para inspeccionarlos. `-startGame` usa almacenamiento en memoria; `-uiTesting` usa un archivo propio (`UITests.store`) que `-resetStore` borra, para no tocar los datos reales. `-unlockAll` desbloquea todos los logros (QA y capturas).

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

Tablero de **9 columnas**; arranca con **27 números (3 filas)** del 1 al 9.

**Pareja válida:** dos números iguales (4-4) o que sumen 10 (3-7, 5-5).

**Conexiones válidas** entre las dos celdas:
1. Adyacentes en horizontal, vertical o diagonal.
2. En la misma línea (horizontal, vertical o diagonal) con solo celdas eliminadas entre ellas.
3. Lectura continua: el tablero se lee como tira izquierda→derecha, arriba→abajo; el último número de una fila conecta con el primero de la siguiente, saltando eliminadas.

**Mecánicas:**
- Celdas eliminadas quedan como "fantasma" (número tenue) hasta que su fila se vacía.
- Fila vacía: desaparece, el tablero sube y da puntos extra.
- Botón **+**: copia todos los números restantes, en orden, al final del tablero (regla estándar del género; se evaluó triplicar y se descartó). 5 usos por partida. Limpiar una fila regala 1 uso extra (máximo 5 acumulados). Los números agregados se muestran en azul (`AddedNumber`) para distinguirlos de los originales.
- **Pistas:** ilimitadas; resaltan una pareja válida y cuestan 3 puntos (el puntaje nunca baja de 0). Si no hay parejas, no cobran.
- **Etapas:** vaciar el tablero pasa a la siguiente etapa con tablero nuevo; los usos de + se reinician.
- **Fin de partida:** no quedan parejas válidas ni usos de +.
- La generación garantiza **al menos 3 parejas válidas** al inicio.

**Puntaje** (valores iniciales, ajustables — mantenerlos configurables):
- Pareja adyacente: 1
- Pareja con eliminadas entre medio: 4
- Fila limpiada: 10
- Tablero limpiado: 150 × número de etapa
- Pista: −3

## Reto diario

Tablero único por día, igual para todo el mundo, generado en el dispositivo sin servidor.

- **Semilla:** fecha UTC `yyyy-MM-dd` → hash estable (p. ej. FNV-1a). Cambia a las 00:00 UTC.
- **PRNG:** propio y determinista (SplitMix64 o Xoshiro256). **Nunca** `SystemRandomNumberGenerator`. Evitar cualquier API cuyo resultado dependa de plataforma (p. ej. `Hasher`, `shuffled()` sin generador propio).
- **Validación:** si el tablero no cumple el mínimo de parejas, avanzar la semilla de forma determinista hasta obtener uno válido.
- **Formato:** una sola etapa, mismas reglas y límites. Un solo intento puntuable por día; se puede rejugar sin enviar puntaje.
- **Racha:** días consecutivos completados, guardada localmente, usada para logros.
- **Calendario:** vista mensual de retos completados; los últimos 30 días se pueden jugar sin puntuar.
- **Decisiones de implementación (fase 3):**
  - "Completar" un reto = vaciar el tablero. Terminar sin vaciarlo guarda el puntaje (cuenta como intento) pero no suma a la racha.
  - El intento puntuable empieza al tocar "Jugar" por primera vez ese día; si se sale a mitad, se reanuda (sigue puntuando).
  - Repeticiones y días pasados son "Práctica": no se guardan ni cambian el calendario.
  - Las fechas de los retos se muestran en UTC (en Colombia el reto del día siguiente aparece a las 7 pm).
- **Test obligatorio:** la misma fecha produce siempre el mismo tablero en iPhone, iPad y Mac.

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

1. Crear el App ID y activar las capacidades **Game Center** e **iCloud** (iCloud es necesario para `saveGameData`; agregar su entitlement en `project.yml`).
2. En App Store Connect, crear los leaderboards `daily_challenge` (recurrente, 24 h, inicio 00:00 UTC), `best_score` y `longest_streak` (clásicos), y los logros `first_step`, `clean_slate`, `no_help`, `consistency`, `habit`, `sweeper`, `stage_five`, `centennial`, `night_owl`, `monotone`, con textos en inglés y español.
3. Probar con una cuenta sandbox: modo avión → jugar → reconectar → verificar envío.

Decisiones:
- No se fuerza el inicio de sesión (no se presenta la pantalla de login de Game Center); el jugador inicia sesión desde Ajustes del sistema. `GKAccessPoint` solo en Inicio y con sesión.
- Partidas guardadas: se guarda un `Snapshot` (progreso + resultados diarios). Los conflictos se resuelven **fusionando** (unión de logros, máximo de cada contador, mejor resultado por día), lo que siempre conserva el mayor progreso. La partida clásica en curso no se sincroniza.
- macOS: `ENABLE_OUTGOING_NETWORK_CONNECTIONS` solo porque GameKit lo necesita dentro del sandbox; la app no hace llamadas propias.

## Logros y recompensas

Toda recompensa es cosmética y nunca altera la jugabilidad ni el layout del tablero. Los desbloqueos se calculan y guardan localmente.

| Logro | Condición | Recompensa |
|---|---|---|
| Primer paso | Completar la primera partida | Tema Papel (por defecto) |
| Tabla rasa | Limpiar un tablero completo | Ficha: círculo |
| Sin ayuda | Limpiar un tablero sin + ni pistas | Tema Pizarra |
| Constancia | Racha de 7 retos diarios | Tema Arena |
| Hábito | Racha de 30 retos diarios | Tipografía New York (serif) |
| Barrendero | Limpiar 100 filas en total | Efecto de limpieza: ola |
| Etapa 5 | Llegar a la etapa 5 en una partida | Ficha: contorno |
| Centenario | Completar 100 retos diarios | Ícono alternativo dorado |
| Noctámbulo | Completar un reto entre 00:00 y 04:00 | Tema Medianoche |
| Monótono | 10 parejas seguidas del mismo número | Pack de sonido: marimba |

Categorías de personalización: tema de color, estilo de ficha, tipografía, efecto al limpiar fila, pack de sonido, ícono de la app. Se eligen en "Colección"; lo bloqueado muestra su condición.

Decisiones de implementación (fase 5):
- "Monótono" se interpreta como 10 parejas seguidas de números iguales (4-4, 7-7…), no 10 veces el mismo dígito. **Supuesto a confirmar.**
- Las opciones por defecto (Papel, Simple, SF Rounded, Contorno, Suave, ícono estándar) están siempre disponibles.
- Los colores de los temas están en el Asset Catalog (`SlateBackground`, `SandInk`…). Pizarra y Medianoche fuerzan modo oscuro; Arena tiene variante clara y oscura; Papel usa los estilos del sistema.
- Los sonidos se sintetizan en el dispositivo (AVAudioEngine, sin archivos), categoría `.ambient` (respeta el modo silencio). Sonido y hápticos activados por defecto.
- El ícono dorado es solo iOS (macOS no soporta íconos alternativos).
- Preferencias en `UserDefaults` (`@AppStorage`); progreso y logros en SwiftData (`StoredProgress`). Las partidas de práctica también cuentan para logros de juego.

## Estética y UX

- Colores semánticos del sistema, un solo color de acento, animaciones suaves.
- Claro/oscuro sigue al sistema. Colores en el Asset Catalog con variantes; **nada de colores fijos en código**.
- Fondo `systemBackground`; superficies secundarias `secondarySystemBackground`.
- SF Pro Rounded con `.monospacedDigit()`.
- Fichas sin bordes, solo el número. Seleccionada: círculo suave del acento. Eliminada: gris muy tenue.
- Animaciones: pareja válida = línea que crece desde el centro hasta ambos números y luego fade + leve escala a fantasma; inválida = pequeña sacudida; fila limpiada = borde que se dibuja alrededor de la fila y luego colapso suave hacia arriba. Respetar Reduce Motion (sin línea ni trazo).
- Tres tipos de línea según las celdas eliminadas entre la pareja: sutil (0, delgada y tenue), media (1–3) y dramática (4+, gruesa con brillo; coincide con "¡Desde lejos!"). En lectura continua entre filas, la línea entra desde los bordes del tablero. Color azul metálico (`MatchLine` + `MatchLineSheen`), también en el borde de fila limpiada.
- Ritmo: animaciones rápidas y con algo de rebote (`Animation.quiet` = snappy 0.2 s); el emparejamiento completo dura menos de ~0.6 s y un toque nuevo lo termina al instante.
- Pista sin parejas: no cobra, muestra "No hay parejas. Prueba +" y hace rebotar el botón +.
- Racha ("¡N seguidas!"): se reinicia con un intento inválido o al pedir pista; el + no la reinicia.
- Hápticos (iOS): ligero al seleccionar, medio al emparejar, éxito al limpiar fila.
- Barra superior: puntaje, etapa, contador de + y costo de la pista. Nada más.
- Feedback por jugada: "+N" flotante junto al puntaje (acento; costos en gris) y elogios breves centrados en la barra: "¡Desde lejos!" (4+ celdas eliminadas entre la pareja), "¡Doble/Triple fila!", "¡N seguidas!" (cada 5 parejas sin error). Solo texto, no dan puntos.
- Pantallas: Inicio (Continuar, Nueva partida, Reto diario), Juego, Leaderboards, Colección, Ajustes (sonido, hápticos, privacidad).
- iPad/Mac: tablero centrado con ancho máximo. Mac: ratón, trackpad y atajos de teclado.
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

Estado (fase 6):
- `App/Resources/PrivacyInfo.xcprivacy`: sin tracking, cero tipos de datos recolectados, `UserDefaults` con razón `CA92.1`.
- Política de privacidad en/es: `docs/privacy-policy.md` (falta definir correo de soporte y URL pública).
- Etiqueta de privacidad, según [App privacy details](https://developer.apple.com/app-store/app-privacy-details/): "You are not responsible for disclosing data collected by Apple" y "recolectar" = enviar datos fuera del dispositivo de forma que el desarrollador pueda accederlos. Game Center e iCloud los gestiona Apple y no tenemos acceso, por lo que se responde **Data Not Collected**. Riesgo: la misma guía dice "Your app includes game saves… Declare Gameplay Content"; revisarlo al llenar el cuestionario en App Store Connect.

## Fases

Cada fase termina con su criterio de aceptación cumplido antes de pasar a la siguiente.

1. **Motor del juego (Core).** Tablero, parejas y conexiones, +, pistas, puntaje, etapas, PRNG con semilla.
   Acepta: tests cubren las 3 conexiones, filas vacías, fin de partida y determinismo del generador.
2. **Juego jugable.** Pantalla de juego, selección, animaciones, hápticos, claro/oscuro.
   Acepta: una partida completa se juega en iPhone, iPad y Mac.
3. **Persistencia y reto diario.** SwiftData, continuar partida, reto diario, racha, calendario.
   Acepta: cerrar y volver mantiene el estado; la misma fecha genera el mismo reto en los 3 dispositivos.
4. **Game Center.** Autenticación, logros, 3 leaderboards (global y amigos), partidas guardadas.
   Acepta: todo funciona en modo avión y sincroniza al reconectar.
5. **Recompensas y colección.** Temas, fichas, tipografías, efectos, sonidos, íconos alternativos.
   Acepta: cada logro desbloquea su recompensa y se aplica desde Colección.
6. **Pulido y lanzamiento.** Localización completa, accesibilidad, PrivacyInfo, capturas, TestFlight.
   Acepta: cero textos sin localizar, auditoría de VoiceOver aprobada, build en TestFlight.

## Estado (2026-10-25)

| Fase | Estado |
|---|---|
| 1. Motor | ✅ Hecha |
| 2. Juego jugable | ✅ Hecha (probada en iPhone; Mac compila; iPad sin probar en simulador) |
| 3. Persistencia y reto diario | ✅ Hecha |
| 4. Game Center | 🟡 Código completo; falta App ID + App Store Connect para verificarlo |
| 5. Recompensas y colección | ✅ Hecha |
| 6. Pulido y lanzamiento | 🟡 Localización auditada (0 textos sin traducir, fallback a inglés verificado), PrivacyInfo, política de privacidad, Dynamic Type en Inicio/Juego. Falta: auditoría de VoiceOver manual, capturas, TestFlight, rediseño de la animación de unión |

## Anotaciones de diseño

- **Animación al unir números: no satisface (2026-10-25).** La versión actual (línea que crece desde el centro en 3 niveles, azul metálico, luego fantasma) funciona pero hay que rediseñarla. Retomar antes del pulido final (fase 6).

## Preguntas abiertas

- [ ] ¿Limpiar una fila debe devolver un uso de +? Hoy sí (regla del brief) y en la práctica el + casi nunca se agota. Alternativa propuesta: 5 usos fijos por etapa.

- [ ] Nombre final (propuesto: Quiet Numbers).
- [ ] Versión mínima de iOS/macOS: 18 o 26.
- [ ] Color de acento del tema por defecto.
