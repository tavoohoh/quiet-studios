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
- UI test en simulador: `xcodebuild test -project QuietNumbers.xcodeproj -scheme QuietNumbers -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:QuietNumbersUITests`.
- Argumentos DEBUG: `-startGame` abre una partida directo; `-seedKey <texto>` hace el tablero determinista (`2026-10-25` da el tablero golden de los tests); `-boardValues 5,3,7,…` arranca con números exactos; `-slowEffects` pone los efectos en cámara lenta (×6) para inspeccionarlos.

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
- Botón **+**: copia todos los números restantes, en orden, al final del tablero (regla estándar del género; se evaluó triplicar y se descartó). 5 usos por partida. Limpiar una fila regala 1 uso extra (máximo 5 acumulados). Los números agregados se muestran en el color de acento para distinguirlos de los originales.
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

## Estética y UX

- Colores semánticos del sistema, un solo color de acento, animaciones suaves.
- Claro/oscuro sigue al sistema. Colores en el Asset Catalog con variantes; **nada de colores fijos en código**.
- Fondo `systemBackground`; superficies secundarias `secondarySystemBackground`.
- SF Pro Rounded con `.monospacedDigit()`.
- Fichas sin bordes, solo el número. Seleccionada: círculo suave del acento. Eliminada: gris muy tenue.
- Animaciones: pareja válida = línea que crece desde el centro hasta ambos números y luego fade + leve escala a fantasma; inválida = pequeña sacudida; fila limpiada = borde que se dibuja alrededor de la fila y luego colapso suave hacia arriba. Respetar Reduce Motion (sin línea ni trazo).
- Tres tipos de línea según las celdas eliminadas entre la pareja: sutil (0, delgada y tenue), media (1–3) y dramática (4+, gruesa con brillo; coincide con "¡Desde lejos!"). En lectura continua entre filas, la línea entra desde los bordes del tablero.
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

## Preguntas abiertas

- [ ] Nombre final (propuesto: Quiet Numbers).
- [ ] Versión mínima de iOS/macOS: 18 o 26.
- [ ] Color de acento del tema por defecto.
