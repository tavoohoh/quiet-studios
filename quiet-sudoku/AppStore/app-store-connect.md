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

Completas, con el guion del video que las acompaña, en `app-review-notes.md` (skill `quiet-release`, "Envío a revisión").

## Antes de enviar a revisión (revisado el 2026-11-05, solo lectura por la API)

Listo:
- App creada (app ID `6828993446`), nombre y URL de privacidad en en-US y es-MX, categoría Juegos.
- Versión 1.0 en "Prepare for Submission", con publicación automática al aprobarse.
- Textos de la 1.0 en en-US y es-MX: descripción, palabras clave, texto promocional, URL de soporte y de marketing.
- Game Center activado en la versión 1.0; 12 logros y 3 clasificaciones creados.
- Build **1.0 (2)** procesado (válido) en TestFlight.
- Web publicada (página, privacidad y soporte, con las reglas del reto del 2026-11-02).
- Notas para Apple y guion del video en `app-review-notes.md`.

Falta (preparado aquí, se sube cuando el usuario lo pida):
- Capturas de iPhone e iPad (`scripts/screenshots.sh` + `scripts/store-images.py`): pendientes de aprobación del usuario; la versión no tiene ninguna todavía.
- Header y búsqueda: propuestas en un artefacto aparte; lo elegido pasa al canvas y a `AppStore/creative/`.
- Elegir el build: la versión todavía tiene el **1.0 (1)**; cambiarlo al **1.0 (2)**.
- Notas para la revisión: la versión no tiene notas ni datos de contacto.

Solo en la web de App Store Connect (lo hace el usuario):
- **Clasificación por edad:** responder el cuestionario, todo "Ninguno"/"No" → 4+ (hoy está sin responder).
- **Precio y disponibilidad:** gratis, todos los países (hoy no hay precio ni disponibilidad).
- **Derechos de contenido:** "No contiene contenido de terceros" (hoy sin responder).
- **Privacidad de la app:** "Data Not Collected" (la API no lo deja leer: confirmarlo en App Privacy).
- **Versión 1.0 › Game Center:** confirmar que estén elegidos los 12 logros y las 3 clasificaciones.
- **App Review Information:** nombre, teléfono y correo de contacto; pegar las notas de `app-review-notes.md`; adjuntar el video.
- Enviar a revisión (el mismo día que Apple apruebe Quiet Numbers).
