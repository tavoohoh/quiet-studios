# App Store Connect: Quiet Sudoku

Todo lo necesario para crear y publicar la app. Textos en `fastlane/metadata/{en-US,es-MX}` (validar con `scripts/validate-metadata.py`, subir con `scripts/upload-metadata.py [--apply]`), Game Center en `game-center.md` (crear con `scripts/setup-game-center.py [--apply]`). Bundle ID `com.tavoohoh.quietsudoku` ya registrado (Xcode, con Game Center e iCloud).

## Crear la app (Apps › +, en la web: la API no crea apps)

| Campo | Valor |
|---|---|
| Plataforma | iOS (iPhone y iPad; en Mac se ofrece la app de iPad) |
| Nombre | **Quiet Sudoku: Logic Puzzle** ("Quiet Sudoku" ya existe dos veces y "Quiet Sudoku: Classic Puzzles" también, búsqueda del 2026-10-30; en la pantalla de inicio sigue "Quiet Sudoku") |
| Idioma principal | English (U.S.) |
| Bundle ID | `com.tavoohoh.quietsudoku` |
| SKU | `quietsudoku-ios` |
| Acceso | Acceso completo |

## Información de la app

| Campo | Valor |
|---|---|
| Subtítulo | Ver `subtitle.txt` por idioma ("Classic sudoku with no ads" / "Sudoku clásico sin anuncios") |
| Categoría | Juegos, subcategorías **Puzle** y Juegos de mesa (`upload-metadata.py` la pone) |
| Clasificación por edad | Todas las preguntas en "Ninguno"/"No" → **4+** |
| Derechos de contenido | No contiene contenido de terceros (todos los tableros los genera el motor propio) |
| Copyright | © 2026 Quiet Studios |
| Localizaciones | English (U.S.) y Spanish (Mexico) |

## Precio y disponibilidad

Gratis para siempre (familia "gratis para siempre", `studio/roadmap.md`), todos los países. Sin compras dentro de la app.

## Privacidad

- URL de la política: `https://tavoohoh.github.io/quiet-studios/quiet-sudoku/privacy.html` (GitHub Pages desde `/docs`, se publica con el push a main).
- Etiqueta: **Data Not Collected**. `App/Resources/PrivacyInfo.xcprivacy`: sin rastreo, cero tipos de datos, `UserDefaults` con razón `CA92.1`.

## Versión 1.0

| Campo | Valor |
|---|---|
| Capturas | Fase 6 (no hacen falta para TestFlight interno) |
| Texto promocional, descripción, palabras clave, novedades | `fastlane/metadata/<idioma>/*.txt` |
| URL de soporte | `https://tavoohoh.github.io/quiet-studios/quiet-sudoku/support.html` |
| URL de marketing | `https://tavoohoh.github.io/quiet-studios/quiet-sudoku/` |
| Game Center | 12 logros y 3 clasificaciones (`game-center.json`); activar Game Center en la versión y elegirlos |
| Cifrado | No usa cifrado propio (`ITSAppUsesNonExemptEncryption = NO`) |
| Publicación | Automática al aprobarse |

### Notas para la revisión de Apple

> Quiet Sudoku is a free, single-player sudoku with no ads, purchases or accounts. Game Center is optional: everything works signed out. To see a solve quickly, start a New Game (Easy) and tap Hint (lightbulb) repeatedly; each hint writes the next digit and explains why. No login or demo account is needed.

## Qué falta hacer a mano en App Store Connect

- Crear la app (arriba).
- Clasificación por edad, precio (gratis) y disponibilidad, privacidad ("Data Not Collected").
- En la versión 1.0: activar Game Center y elegir logros y clasificaciones, elegir el build, notas para la revisión y publicación automática.
