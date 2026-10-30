# Quiet Sudoku

**Canvas de diseño:** [Quiet Sudoku](https://claude.ai/artifact/CUwSvM9TWjrAphXWbcrGFL) · Sistema de diseño de la familia: [Quiet Studios](https://claude.ai/artifact/59yz1mHLFU3u3jvSfugf7B)

Sudoku clásico 9×9: llenar la cuadrícula para que cada fila, cada columna y cada caja de 3×3 tenga los números del 1 al 9 una sola vez. Gratis para siempre, sin anuncios, sin compras y sin recolectar datos. Tercera app de la familia Quiet (ver `../CLAUDE.md` y `../studio/roadmap.md`).

Nombre: **Quiet Sudoku** (propuesto 2026-10-30). "Sudoku" es el nombre genérico de la mecánica; nunca usar nombres, arte, textos ni tableros de otras apps o publicaciones del género. Todos los tableros los genera el motor propio.

## Principios no negociables

Los mismos de Quiet Numbers y Quiet Solitaire:

- Sin anuncios, compras in-app, suscripciones ni tip jar.
- Sin backend, analytics, crash reporters ni SDKs de terceros. Ninguna llamada de red propia: **todos los tableros se generan en el dispositivo** (o se precalculan con un script y viajan en la app, plan B).
- 100% offline. Game Center es un extra que sincroniza al reconectar.
- Recompensas solo cosméticas, ganadas con logros. Única excepción de la familia: el easter egg de "Números rojos" (pistas más baratas solo en clásico; nunca en retos diarios).
- Sin identificadores propios, fingerprinting ni App Tracking Transparency.
- Frameworks permitidos: SwiftUI, SwiftData, GameKit y StoreKit **solo** para `requestReview()`.

## Stack

| Pieza | Decisión |
|---|---|
| UI | SwiftUI nativo. El tablero es una grilla de 81 celdas con `Canvas` para líneas y notas si hace falta rendimiento. |
| Kit compartido | `../QuietKit`: temas, componentes, tipografía, hápticos, tonos, Game Center, `DailyKey`/`Streaks`, `DailyReminders`, amigos, splash, fuegos artificiales. |
| Lenguaje | Swift 6, strict concurrency. |
| Sistemas mínimos | iOS 18 / iPadOS 18; en Mac, la app de iPad. |
| Persistencia | SwiftData. |
| Online | GameKit únicamente. |
| Tests | Swift Testing para el motor (`QuietSudokuCore`). |
| Dependencias externas | Ninguna. |

Un solo target iOS (iPhone y iPad), un bundle ID. Proyecto generado con XcodeGen (`project.yml`), como Quiet Solitaire.

## Comandos

- `xcodegen generate` tras agregar o mover archivos. No editar el `.pbxproj` a mano.
- Tests del motor: `cd Packages/QuietSudokuCore && swift test -c release` (47 tests, ~45 s; incluye un año de retos. En debug tardan mucho más).
- Canvas: `scripts/design-screens.sh` captura las 8 pantallas en claro y oscuro (iPhone 17, inglés; un solo simulador, lo apaga) → `AppStore/design-screens/iphone/en/`; ids de las imágenes subidas en `design/canvas-assets.tsv`.
- Ícono: `scripts/render-icon.py` (caja de 3×3 con una casilla en coral; estándar y Gold, claro/oscuro/tinted, con `scripts/render-svg.swift`).
- Argumentos DEBUG: `-startGame` abre una partida (`-seedKey <texto>` determinista, `-level <0-3>` el nivel, `-nearlyWon` deja una casilla, `-hint` aplica una pista); `-open <daily|leaderboards|collection|settings|tutorial>` abre esa pantalla; `-uiTesting`, `-resetStore`, `-tutorial`, `-unlockAll`, `-demo`, `-demoClock`, `-showReminders`, `-refreshFriends` y `-completeToday` como en Quiet Solitaire.
- Todos los tests: `xcodebuild test -project QuietSudoku.xcodeproj -scheme QuietSudoku -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/dd`.
- Textos: `scripts/strings.py` (como Quiet Solitaire).
- Simulador: uno solo ("iPhone 17"), apagarlo por udid al terminar.

## QuietKit

Usa `QuietCore` (`SeededRandom`, `FNV1a`, `DailyKey`, `Streaks`, `Palette`, `DailyReminderPlan`) y `QuietUI` (todo lo de la tabla de la skill `quiet-ui`). No se modifica sin coordinarlo con la sesión quiet-studio. Lo que necesite el juego y no esté en el kit vive en la app; si una tercera app lo usaría, se propone para el kit.

## Arquitectura

```
quiet-sudoku/
├── project.yml
├── App/                        # misma estructura que Quiet Solitaire (copiada y adaptada 2026-10-30)
│   ├── Features/               # Home, Game, DailyChallenge, Leaderboards, Collection, Settings, Tutorial
│   ├── Services/
│   ├── DesignSystem/           # números, celdas, recompensas propias
│   └── Resources/
└── Packages/
    └── QuietSudokuCore/
        ├── Sources/QuietSudokuCore/
        │   ├── Grid.swift           # 81 celdas, unidades (filas, columnas, cajas), vecinos
        │   ├── DancingLinks.swift   # Algorithm X (Knuth): resolver y contar soluciones
        │   ├── Backtracker.swift    # segundo resolvedor, independiente, para cruzar resultados en tests
        │   ├── LogicSolver.swift    # técnicas humanas paso a paso; da la dificultad y las pistas
        │   ├── Techniques.swift     # cada técnica: dónde aplica, qué elimina o coloca
        │   ├── Generator.swift      # semilla → solución → quitar pistas con solución única → graduar
        │   ├── GameSession.swift    # valores, notas, errores, deshacer, tiempo; Codable
        │   ├── Scoring.swift
        │   ├── DailyChallenge.swift # fecha → tablero con la dificultad del día
        │   ├── Tutorial.swift
        │   └── Achievements.swift
        └── Tests/QuietSudokuCoreTests/
```

El Core depende solo de `QuietCore`. Modelos `Codable`.

## Motor (propuesta 2026-10-30)

Lo que hace bueno a un sudoku: **una sola solución** y **una dificultad honesta**. Ambas se verifican con tests, porque el usuario no juega sudoku y no puede probarlo a mano.

**Solución única: Dancing Links (Knuth, "Dancing Links", 2000).** El sudoku es un problema de cobertura exacta: 324 restricciones (cada celda tiene un número; cada fila, columna y caja tiene cada número una vez) y 729 candidatos (celda × número), cada uno cubre 4 restricciones. Algorithm X con enlaces dobles elige siempre la restricción con menos opciones y cuenta soluciones hasta 2: si encuentra la segunda, el tablero no sirve. Un segundo resolvedor independiente (backtracking con máscaras de bits) cruza los resultados en los tests: los dos tienen que estar de acuerdo en cada tablero.

**Dificultad por técnicas, no por cantidad de pistas.** Un resolvedor lógico aplica siempre la técnica más simple que avance (como Sudoku Explainer y HoDoKu); la dificultad del tablero es la técnica más difícil que necesitó:

| Nivel | Técnicas que puede necesitar | Pistas dadas (medido) |
|---|---|---|
| Fácil | Última casilla (full house), único lugar (hidden single), único posible (naked single) | 36 (piso) |
| Media | + candidatos bloqueados (pointing, claiming), pares desnudos y ocultos | ~28 (piso 28) |
| Difícil | + tríos desnudos y ocultos, X-Wing, XY-Wing | ~26 |
| Experta | + Skyscraper, 2-String Kite, Swordfish, XYZ-Wing, W-Wing | ~26 |

**Ajuste medido (2026-10-30):** con la tabla de la propuesta, Difícil salía en 1 de cada 100 intentos: el XY-Wing aparece 19 veces más que el X-Wing y los tríos, así que pasó a Difícil (como en HoDoKu). Para Experta se agregaron tres técnicas estándar de un dígito (Skyscraper, 2-String Kite, W-Wing). Los cuartetos (naked/hidden quad) se quitaron: en 3.000 tableros nunca hicieron falta, y un tablero que los necesite el generador lo descarta. Aciertos por intento, en release en una Mac: Media 11 %, Difícil 11,5 %, Experta 19,5 %, a 5–37 ms por intento; un tablero tarda ~0,05–0,2 s (en Debug, 1–2 s: la app prepara el siguiente de cada nivel en segundo plano). **No hace falta el plan B.**

- Nunca se entrega un tablero que el resolvedor lógico no pueda terminar con estas técnicas: **todo tablero se resuelve sin adivinar** y la pista siempre tiene un paso lógico que mostrar.
- Test de la dificultad: con las técnicas de su nivel el resolvedor lo termina, y con las del nivel anterior se atasca.

**Generador** (determinista, solo `SeededRandom`, nunca `shuffled()` ni `Hasher`):
1. Semilla → solución completa al azar (Algorithm X con el orden de candidatos barajado).
2. Quitar pistas por parejas simétricas (simetría central, la clásica), en orden aleatorio, mientras el resolvedor lógico limitado al nivel lo siga resolviendo (como sus pasos son deducciones, eso ya implica solución única); parar en el piso de pistas del nivel (Fácil 36, Media 28). En Difícil y Experta, si no llegó al nivel, se rompe la simetría quitando casillas sueltas hasta llegar.
3. Graduar y confirmar con Dancing Links: si el nivel no es el pedido, se prueba la clave siguiente (`"<día>#0"`, `"<día>#1"`…, hasta 400; como el reparto diario de Quiet Solitaire). Si ninguna da el nivel, el más cercano por debajo (nunca uno más difícil); el test del año comprueba que no pasa.
- Presupuesto por intentos, no por tiempo: mismo resultado en cualquier dispositivo. Medir en un iPhone viejo: si Experta tarda más de ~1 s, **plan B**: un script precalcula los tableros diarios de varios años (81 caracteres por día, ~150 KB para 5 años) y la app los trae; el modo libre usa una reserva precalculada por nivel.

## Reglas del juego

- **Tablero:** 9×9 con algunas pistas fijas (no se pueden cambiar). Se toca una celda y se elige un número en el teclado de abajo (1–9, con cuántos quedan de cada uno; un número completo se atenúa).
- **Errores:** un número que no es el de la solución es un error; se borra o se reemplaza. Sin vidas ni "game over": la partida nunca se pierde (decisión 2026-10-30, para alguien que está aprendiendo). Un número correcto queda fijo (no se borra), para que no se pueda poner y sacar sumando puntos.
- **"Marcar errores al instante"** (Ajustes, activado por defecto; revisión de quiet-studio 2026-10-30): activado, el error se pone en rojo apenas se escribe. Apagado, nada se marca durante la partida y se revisa al llenar las 81 celdas: si hay errores, el tablero no se da por resuelto, los números equivocados se marcan en rojo (y siguen marcados hasta corregirlos), sale "3 números no van. Corrígelos." y la partida sigue hasta que todo esté bien.
- **Cobro del error, igual en los dos modos** (para que apagar la revisión no ayude en la clasificación): cada número equivocado que se escribe cuesta −20 en el momento de escribirlo, se vea o no; borrarlo o deshacer no lo devuelve. Con la revisión apagada, durante la partida el puntaje y el contador no muestran los errores (si no, delatarían cuál está mal); el cobro aparece en la hoja de resumen ("Errores 3 × −20"). La opción vale también en el reto, puntuable o práctica: es solo una forma de ver, no cambia lo que se cobra.
- **Notas (lápiz):** botón "Notas" para escribir candidatos chicos en una celda. Al poner un número, se borra ese candidato de las notas de su fila, columna y caja.
- **Ayudas visuales:** se resaltan la fila, la columna y la caja de la celda elegida y todas las celdas con el mismo número.
- **Deshacer:** ilimitado (hasta 200 pasos), también las notas. **Borrar** quita el número o las notas de una celda que no sea pista.
- **Pista:** muestra el siguiente paso del resolvedor lógico con su técnica explicada ("En esta caja, el 7 solo cabe aquí"), resalta las celdas que lo justifican y pone el número. Cuesta 10 puntos (−3 con "Números rojos", solo en clásico).
- **Victoria:** las 81 celdas correctas. Hoja de resumen con puntaje, tiempo, errores, pistas y logros; fuegos artificiales de QuietUI (nada con Reduce Motion).

## Puntaje

- Cada número correcto puesto por el jugador: +10 Fácil, +15 Media, +20 Difícil, +30 Experta. Un número puesto por la pista no suma.
- Error: −20. Pista: −10.
- Victoria: bono de 500 × multiplicador de tiempo: ×2,0 hasta el tiempo objetivo del nivel (Fácil 5 min, Media 10, Difícil 15, Experta 25), baja lineal hasta ×1,0 al triple, en pasos de 0,1. Se multiplica lo ganado (números + bono); errores y pistas quedan fuera, como en Quiet Solitaire.
- El puntaje puede quedar negativo (logro oculto "Números rojos").

## Reto diario

Regla de la familia (sección "Reto diario" del `CLAUDE.md` de la raíz), sin excepciones: clave `yyyy-MM-dd` → FNV-1a → semilla, cambio a medianoche local, un intento puntuable que se retoma, práctica de los últimos 30 días que rellena la racha, "Continuar / Empezar de nuevo", pistas siempre a 10, resumen con fuegos, desempate por tiempo (`context` = segundos + 1), calendario mensual y notificaciones de 19:00 y 21:00.

Lo propio del sudoku:
- **Dificultad por día de la semana** (como Quiet Solitaire): lunes y martes Fácil, miércoles a viernes Media, sábado Difícil, domingo Experta.
- "Completar" = resolver el tablero. Clasificación `qsu_daily_challenge`, recurrente cada 24 h desde las 05:00 UTC.
- **Tests obligatorios:** la misma fecha da siempre el mismo tablero (valores de referencia fijos de varias fechas), y los tableros de un año completo tienen solución única y la dificultad de su día.

## Game Center

Prefijo `qsu_` (Quiet Numbers no usa prefijo y Quiet Solitaire usa `qs_`). Las tres clasificaciones de la familia:
- `qsu_daily_challenge`: recurrente 24 h, puntaje del reto (desempate por tiempo).
- `qsu_best_score`: mejor puntaje del modo libre.
- `qsu_longest_streak`: racha más larga de retos.

Amigos (`FriendsTodayCard`, `FriendProfileView`), partidas guardadas en iCloud y `GKAccessPoint` solo en Inicio, como en Quiet Solitaire.

## Logros y recompensas (propuesta)

Recompensas cosméticas: tableros (los temas de QuietKit), estilo de los números, efecto de victoria e ícono dorado. Estilos de números solo con fuentes del sistema (SF Pro Rounded, New York, SF Mono, Noteworthy), sin licencias aparte. Cada logro da algo que no estaba disponible antes (Noctámbulo da un tema real, como en Quiet Numbers; revisión 2026-10-30).

| ID | Logro (es / en) | Condición | Recompensa |
|---|---|---|---|
| `qsu_first_win` | Primer sudoku / First Sudoku | Resolver el primero | Números Redondos y Petróleo y coral (por defecto) |
| `qsu_no_mistakes` | Sin tachones / Clean Sheet | Resolver sin errores | Números Clásicos (New York) |
| `qsu_no_hints` | Por tu cuenta / On Your Own | Resolver sin pistas | Tablero Salvia y arena |
| `qsu_no_notes` | De memoria / From Memory | Resolver uno de nivel Media o más sin notas | Números Máquina (SF Mono) |
| `qsu_ten_wins` | Diez sudokus / Ten Sudokus | Resolver 10 | Notas en color (candidatos con el acento) |
| `qsu_consistency` | Constancia / Consistency | Racha de 7 retos | Tablero Índigo y durazno |
| `qsu_habit` | Hábito / Habit | Racha de 30 retos | Efecto de victoria: ola (las celdas se encienden en onda antes de los fuegos) |
| `qsu_expert` | Experto / Expert | Resolver uno de nivel Experta | Números Pluma (Noteworthy, fuente del sistema) |
| `qsu_quick` | Rápido / Quick | Resolver un Fácil en menos de 4 min | Resaltado suave (solo el número elegido, sin fila ni columna) |
| `qsu_night_owl` | Noctámbulo / Night Owl | Resolver un reto entre 00:00 y 04:00 | Tablero Salvia y coral |
| `qsu_centennial` | Centenario / Centennial | Resolver 100 | Ícono dorado |
| `qsu_in_the_red` | Números rojos / In the Red | Puntaje bajo cero (oculto) | Pistas a 3 solo en clásico |

Siempre disponibles, sin logro: tema **Alto contraste**, **Números grandes** (accesibilidad) y los tableros **Petróleo y coral claro** y **oscuro**.

## Tutorial (propuesta)

Para quien nunca jugó. Interactivo, sobre tableros reales del motor, en el que **solo vale la jugada correcta** (como Quiet Solitaire). Sale con la primera partida y desde Ajustes › Cómo jugar.

1. **La meta:** una fila con un hueco. "Cada fila lleva del 1 al 9 sin repetir. ¿Cuál falta?"
2. **Columnas:** lo mismo en una columna.
3. **Cajas:** lo mismo en una caja de 3×3.
4. **Cruzar pistas:** un número que solo cabe en un lugar de una caja porque las filas y columnas vecinas ya lo tienen (único lugar).
5. **Descartar:** una celda donde solo cabe un número porque su fila, columna y caja ya tienen los otros ocho (único posible).
6. **Notas:** activar Notas y escribir los candidatos de una celda.
7. **Errores y pistas:** qué pasa con un número equivocado (rojo, −20) y cómo pedir una pista (−10).

Tests: cada paso tiene **una sola** respuesta válida, que se deduce **solo** con lo que enseñan ese paso y los anteriores (lo comprueba el resolvedor lógico limitado a esas técnicas), y el tablero del tutorial es consistente con una solución única. Al terminar: "Ya sabes jugar. Empieza con un Fácil." Ajustes › Reglas resume todo, y Ajustes › Técnicas explica cada técnica que puede mostrar una pista.

## Estética y UX

- Misma UI que la familia vía QuietKit: Inicio, Juego, Resumen, Reto diario, Clasificaciones, Colección, Ajustes, Tutorial y Splash; colores solo por rol.
- **Tablero:** cuadrado, ancho completo menos 16 pt de margen (iPad hasta 760 pt). Líneas finas (`separator`) entre celdas y gruesas (`ink`) entre cajas. Pistas en `ink`, números del jugador en `primary`, errores en `accent` con fondo suave y subrayados (no solo color, regla del sistema de diseño), notas en `muted` en una mini grilla de 3×3. Selección: `primary` suave; mismo número: `surface2`.
- **Pantalla de juego:** volver y menú arriba; puntaje grande; debajo Tiempo · Errores · Nivel (Reto + nivel en el diario); tablero; barra Deshacer · Borrar · Notas · Pista; teclado de 9 números.
- **Animaciones:** poner número = escala 0,9 → 1 con spring; error = sacudida ±4 pt y háptico; completar una fila, columna o caja = barrido de luz por esas celdas (+ háptico suave); victoria = onda desde la última celda y fuegos. Nada bloquea el siguiente toque; Reduce Motion: fundidos de 150 ms.
- **Hápticos:** selección al elegir celda, `.place` al poner número, `.success` al completar una unidad y al ganar, `.invalid` en error.
- **iPad:** mismo layout centrado; teclado físico: números 1–9, flechas para moverse, N para notas, ⌘Z deshacer, H pista, borrar con ⌫.
- **Accesibilidad:** VoiceOver por celda ("Fila 3, columna 7, vacía, notas 2, 5, 8"), acciones para poner números, objetivos ≥ 44 pt en el teclado, Dynamic Type salvo en el tablero (que tiene "Números grandes").

## Localización

Inglés (development language) y español, String Catalogs, plurales del catálogo. Nombres de técnicas traducidos (Naked single → "Único posible", Hidden single → "Único lugar", X-Wing se queda igual en los dos idiomas).

## Privacidad

"Data Not Collected", mismo `PrivacyInfo.xcprivacy` que Quiet Solitaire. Política en `../docs/quiet-sudoku/`.

## Fases

Cada fase termina con su criterio de aceptación cumplido antes de pasar a la siguiente.

0. **Propuesta y diseño.** Este documento y el canvas `Quiet Sudoku` con la plantilla (`quiet-design-canvas`, `qa.py` sin errores).
   Acepta: propuesta revisada por quiet-studio; canvas publicado con QA limpio.
1. **Motor.** Grid, Dancing Links, segundo resolvedor, resolvedor lógico con las técnicas de la tabla, generador, sesión (valores, notas, errores, deshacer), puntaje, reto diario, tutorial.
   Acepta: tests de solución única (cruzada con el segundo resolvedor) en cientos de tableros por nivel; dificultad = técnicas necesarias; cada técnica probada con un tablero conocido; misma fecha → mismo tablero con valores fijos; un año de retos válido; pasos del tutorial con respuesta única; tiempo de generación medido.
2. **Juego jugable.** Tablero, teclado, notas, pistas con explicación, deshacer, victoria, tutorial.
   Acepta: una partida completa de cada nivel en el simulador de iPhone y en iPad.
3. **Persistencia y reto diario.** SwiftData, continuar, regla de la familia completa, calendario, notificaciones.
   Notificaciones del reto con `DailyReminders` de QuietKit: 19:00 si el reto de hoy no está resuelto y "racha en riesgo" a las 21:00 con racha ≥ 3; permiso ofrecido al volver del primer reto completado; tarea de amigos en segundo plano (`com.tavoohoh.quietsudoku.friends`); textos propios del juego en `App/Services/Reminders.swift`, como Quiet Solitaire.
   Acepta: tests de la regla del reto como `AppTests/DailyRuleTests.swift` de Quiet Solitaire, y `ReminderTests` (19:00 y 21:00, resolver el reto las pasa a mañana).
4. **Game Center.** Logros, 3 clasificaciones, partidas guardadas, y amigos con `FriendsTodayCard` (en Reto diario) y `FriendProfileView` (Clasificaciones › Amigos, en `Features/Leaderboards/FriendProfileScreen.swift`), con los textos del juego.
   Acepta: todo funciona en modo avión y sincroniza al reconectar.
5. **Recompensas y colección.**
6. **Pulido y lanzamiento.** Localización completa, accesibilidad, PrivacyInfo, capturas, ficha y TestFlight (con el usuario: Bundle ID y App Store Connect).

## Estado (2026-10-30)

| Fase | Estado |
|---|---|
| 0. Propuesta y diseño | ✅ Propuesta aprobada por quiet-studio (2026-10-30). Canvas [Quiet Sudoku](https://claude.ai/artifact/CUwSvM9TWjrAphXWbcrGFL) publicado con `qa.py` en 0 errores y 0 avisos: Overview, ícono, 8 pantallas en claro y oscuro, estilos y componentes (tablero, teclado, tarjeta de pista). Faltan en App Store las capturas de la ficha, el header, la búsqueda y las insignias (fase 6). |
| 1. Motor | ✅ 47 tests (`swift test -c release`): dos resolvedores que coinciden (también en puzzles mínimos), cada técnica usada y nunca contradice la solución, 40 tableros por nivel con solución única y nivel exacto (resuelve con su nivel, no con el anterior), un año de retos, valores de referencia por fecha, sesión, puntaje, logros y tutorial. |
| 2. Juego jugable | 🟡 Jugable en el simulador: tablero, teclado con restantes, notas, borrar, deshacer, pista con explicación, errores al instante u ocultos, victoria con resumen y fuegos, tutorial de 7 pasos. UI tests: pista, notas, ganar y el tutorial completo. Falta probar en iPhone real e iPad. |
| 3. Persistencia y reto diario | 🟡 Heredado de Quiet Solitaire y adaptado (regla de la familia, calendario, recordatorios); `DailyRuleTests`, `ReminderTests` y `ReminderUITests` pasan. Falta verificar en dispositivo. |
| 4–6 | ⬜ Código de Game Center, colección y ajustes ya adaptado; sin App Store Connect (se hace con el usuario). |

## Preguntas abiertas

- [ ] Nombre en la App Store: buscar si "Quiet Sudoku" está libre; si no, "Quiet Sudoku: Logic Puzzle". Bundle ID propuesto `com.tavoohoh.quietsudoku`, SKU `quietsudoku-ios` (no registrar sin el usuario).
- [x] Errores: al instante por defecto, con "Marcar errores al instante" en Ajustes (revisión de quiet-studio 2026-10-30); mismo cobro en los dos modos.
- [ ] ¿Auto-notas (llenar todos los candidatos) como ayuda gratis en clásico? Propuesta: backlog.
