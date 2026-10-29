---
name: quiet-project-structure
description: Estructura de proyecto, arquitectura y convenciones de código de las apps de Quiet Studios (SwiftUI, Swift 6, SwiftData, GameKit, QuietKit, XcodeGen). Usar al crear archivos o módulos nuevos, al mover código a QuietKit, o cuando haya dudas de dónde va algo o cómo se prueba.
---

# Estructura y arquitectura

## El repositorio

```
Quiet/                       repo público tavoohoh/quiet-studios
├── CLAUDE.md                filosofía de la familia, links a los sistemas de diseño
├── QuietKit/                paquete Swift compartido (QuietCore + QuietUI)
├── quiet-<app>/             una carpeta por app, con su CLAUDE.md
├── docs/quiet-<app>/        web de cada app (GitHub Pages): index, privacy, support (en/es)
└── .claude/skills/          estas skills
```

## Una app

```
quiet-<app>/
├── CLAUDE.md
├── project.yml              XcodeGen: fuente de verdad del proyecto (nunca editar el .pbxproj)
├── Config/                  Base.xcconfig + Local.xcconfig (Team ID, ignorado por git) + .example
├── App/
│   ├── Quiet<App>App.swift
│   ├── AppModel.swift       estado de la app: partida activa, reto diario, progreso, Game Center
│   ├── Features/<Pantalla>/ Home, Game, DailyChallenge, Leaderboards, Collection, Settings, Tutorial
│   ├── Services/            Persistence (SwiftData), GameCenterService (extensión del kit), Feedback
│   ├── DesignSystem/        solo lo propio de la app (recompensas, arte del juego); lo genérico en QuietUI
│   ├── Debug/DemoData.swift estado fijo para capturas (-demo)
│   └── Resources/           Assets, Localizable.xcstrings, InfoPlist.xcstrings, PrivacyInfo.xcprivacy
├── Packages/Quiet<App>Core/ lógica pura: sin SwiftUI, SwiftData ni GameKit; depende de QuietCore
├── AppTests/ UITests/ Screenshots/
├── AppStore/                capturas, imágenes de tienda, game-center.{json,md}, insignias
├── fastlane/metadata/       textos de la ficha por idioma (no se usa fastlane: lo sube scripts/)
└── scripts/                 asc.py (API de App Store Connect), setup-game-center.py, screenshots.sh, store-images.py, render-*.py, validate-metadata.py
```

## Capas

- **Core** (`Packages/Quiet<App>Core`): reglas, generador con semilla, sesión de juego (`GameSession`, `Codable`, `Hashable`), puntaje (`Scoring` configurable), logros (`PlayerProgress`, `Achievement`). Todo testeado con Swift Testing. Al agregar campos a un modelo guardado, hacerlos opcionales para que las partidas viejas sigan cargando, y testear que cargan.
- **QuietCore** (kit, sin UI): `SeededRandom` (SplitMix64), `FNV1a`, `DailyKey`, `Streaks`, `Palette`, `Contrast`. Nunca `SystemRandomNumberGenerator`, `Hasher` ni `shuffled()` sin generador propio en nada que deba dar lo mismo en todos los dispositivos.
- **QuietUI** (kit): `Theme` en `\.quietTheme`, componentes, `Layout`, tipografía, `HapticsService`, `ToneService`, `GameCenterService` genérico, `SplashView`, `Fireworks`.
- **App**: `@Observable` + `@MainActor`; `AppModel` dueño del estado, un `GameModel` por partida en pantalla (selección, animaciones, feedback) sobre la `GameSession` del Core. Sin frameworks de arquitectura.

## Reglas de código

- Swift 6 con strict concurrency, cero dependencias externas.
- Ningún color fijo en vistas: todo sale de `\.quietTheme`. Ningún texto fijo: String Catalogs (en y es, sin claves sin traducir).
- Comentarios cortos que dicen el porqué, en inglés, como el código existente.
- Imitar el estilo del archivo vecino (nombres, densidad de comentarios, idioma).
- Si algo se repite en dos apps, va a QuietKit; al tocar el kit, correr sus tests (`cd QuietKit && swift test`) y los de todas las apps, y compilar cada una.

## Datos

- SwiftData es la fuente de verdad; Game Center e iCloud son espejo (partidas guardadas con fusión que nunca pierde progreso).
- Preferencias en `UserDefaults` (`@AppStorage`); progreso y partidas en SwiftData.
- Ningún dato sale del dispositivo salvo lo que va a Game Center/iCloud del usuario ("Data Not Collected").

## Pruebas

- Core: `swift test` en el paquete. App: `xcodebuild test` en un solo simulador ("iPhone 17"), apagarlo después por udid (`xcrun simctl shutdown <udid>`, nunca `shutdown all`, puede haber otra sesión usando simuladores).
- Argumentos DEBUG comunes: `-startGame`, `-seedKey`, `-uiTesting`, `-resetStore`, `-unlockAll`, `-demo`, `-slowEffects`. Documentarlos en el CLAUDE.md de la app.
- Test obligatorio: la misma fecha produce el mismo reto en todos los dispositivos (valores de referencia fijos).

## Git

- Repo público: nada de Team ID, claves (.p8), perfiles ni `.env`. Revisar `.gitignore` antes de agregar tipos de archivo nuevos.
- Commit y push solo cuando el usuario lo pida. Borrar con `rm`, no `git rm` (puede haber otra sesión trabajando en el mismo repo).
