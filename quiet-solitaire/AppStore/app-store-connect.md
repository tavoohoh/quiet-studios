# App Store Connect: Quiet Solitaire

Todo lo necesario para crear y publicar la app. App creada el 2026-10-28 (ID `6828074077`); `scripts/upload-metadata.py --apply` subió textos, categoría, copyright e imágenes, y `scripts/setup-game-center.py --apply` creó Game Center. Textos en `fastlane/metadata/{en-US,es-MX}` (validar con `scripts/validate-metadata.py`), imágenes en `AppStore/store-images/`, Game Center en `game-center.md`.

## Crear la app (Apps › +)

| Campo | Valor |
|---|---|
| Plataforma | iOS (iPhone y iPad; en Mac se ofrece la app de iPad) |
| Nombre | **Quiet Solitaire: Card Game** ("Quiet Solitaire" y "Quiet Solitaire: Klondike" ya estaban tomados; en la pantalla de inicio sigue "Quiet Solitaire") |
| Idioma principal | English (U.S.) |
| Bundle ID | `com.tavoohoh.quietsolitaire` (ya registrado por Xcode al instalar en el iPhone) |
| SKU | `quietsolitaire-ios` |
| Acceso | Acceso completo |

## Información de la app

| Campo | Valor |
|---|---|
| Subtítulo | Ver `subtitle.txt` por idioma |
| Categoría | Juegos, subcategorías **Cartas** y Puzle (sin categoría secundaria) |
| Clasificación por edad | Todas las preguntas en "Ninguno"/"No" → **4+**. Sin contenido generado por usuarios, sin navegador web, sin compras, sin juegos de azar con dinero (es solitario de un jugador, sin apuestas) |
| Derechos de contenido | No contiene contenido de terceros (arte, figuras y palos dibujados para la app) |
| Copyright | © 2026 Quiet Studios |
| Localizaciones | English (U.S.) y Spanish (Mexico) |

## Precio y disponibilidad

Gratis, todos los países. Sin compras dentro de la app.

## Privacidad

- URL de la política: `https://tavoohoh.github.io/quiet-studios/quiet-solitaire/privacy.html` (se publica con GitHub Pages desde `/docs` al hacer push).
- Etiqueta: **Data Not Collected** (mismo criterio que Quiet Numbers: Game Center e iCloud los gestiona Apple y nunca vemos esos datos). `App/Resources/PrivacyInfo.xcprivacy`: sin rastreo, cero tipos de datos, `UserDefaults` con razón `CA92.1`.

## Versión 1.0

| Campo | Valor |
|---|---|
| Capturas iPhone 6.9" (1320×2868) | `AppStore/store-images/iphone-6.9/<en|es>/01…05.png` |
| Capturas iPhone 6.3" (1206×2622) | `AppStore/store-images/iphone-6.3/<en|es>/` (si App Store Connect las pide aparte) |
| Capturas iPad 13" (2064×2752) | `AppStore/store-images/ipad-13/<en|es>/` |
| Texto promocional, descripción, palabras clave, novedades | `fastlane/metadata/<idioma>/*.txt` |
| URL de soporte | `https://tavoohoh.github.io/quiet-studios/quiet-solitaire/support.html` |
| URL de marketing | `https://tavoohoh.github.io/quiet-studios/quiet-solitaire/` |
| Game Center | 13 logros y 3 clasificaciones creados (`scripts/setup-game-center.py`). Falta activar Game Center en la versión y elegirlos ahí |
| Cifrado | No usa cifrado propio (`ITSAppUsesNonExemptEncryption = NO` en el Info.plist) |
| Publicación | Automática al aprobarse (como Quiet Numbers) |

### Notas para la revisión de Apple

En `app-review-notes.md` (notas en inglés y guion del video).

### Pendiente para enviar la 1.0 (revisado el 2026-11-05, solo lectura por la API)

| Punto | Estado |
|---|---|
| Nombre, subtítulo, categoría (Cartas y Puzle), edad 4+, copyright, URL de privacidad | Listo |
| Textos en/es (descripción, palabras clave, promocional, soporte, marketing) | Listo en App Store Connect; la descripción local cambió el 2026-11-02 ("juégalo las veces que quieras"): subirla con `scripts/upload-metadata.py` |
| Capturas iPhone 6.9" y iPad 13", 5 por idioma | La 02 (reto diario) regenerada en local el 2026-11-05 (en/es, iPhone e iPad; ya sin "Past days are practice…"); falta reemplazarla en App Store Connect con `scripts/upload-metadata.py --replace-screenshots` |
| Build | 1.0 (4) procesado (VALID); falta elegirlo en la versión |
| Game Center en la versión | Falta activarlo y elegir los 13 logros y 3 clasificaciones |
| App Review Information | Falta: contacto, notas (`app-review-notes.md`), sin cuenta de prueba, video adjunto |
| Precio | Sin precio en la API: elegir Gratis (web) |
| Disponibilidad | No se pudo leer por la API: confirmar todos los países (web) |
| Derechos de contenido | Sin declarar: "no contiene contenido de terceros" (web) |
| Privacidad de la app | No se lee por la API: confirmar "Data Not Collected" publicada (web) |
| Web de soporte, privacidad y portada | Publicadas y al día |

## Imágenes de la App Store

Cinco por dispositivo e idioma, en este orden (`scripts/screenshots.sh` y luego `scripts/store-images.py`):

Línea "la capa gratis de Quiet Studios" (aprobada el 2026-11-05): qué es el juego y por qué existe; "gratis" no va en las imágenes, el porqué está al final de la descripción y en la web de soporte.

| # | Archivo | English | Español |
|---|---|---|---|
| 1 | `01-classic` (partida en curso, claro) | **Classic solitaire.** Klondike, draw one. | **Solitario clásico.** Klondike, robando de a una. |
| 2 | `02-daily` (reto de hoy ganado, claro) | **A new challenge every day.** The same deal for everyone. · *9-day streak* | **Un reto nuevo cada día.** El mismo reparto para todos. · *Racha de 9 días* |
| 3 | `03-friends` (clasificaciones, Amigos, oscuro) | **Play with your friends.** See who clears it best. | **Juega con tus amigos.** A ver quién lo hace mejor. |
| 4 | `04-rewards` (Índigo, mazo Pixel, reverso Noche, oscuro) | **Earned by playing.** Card backs, themes and more. | **Todo se gana jugando.** Reversos, temas y más. |
| 5 | `05-winnable` (victoria, claro) | **Every deal can be won.** With "Only winnable deals", on from the start. | **Cada reparto tiene solución.** Con "Solo partidas con solución", activado desde el inicio. |

Header (B, las dos cartas): **Classic solitaire.** Nothing to sell. Just play. / **Solitario clásico.** Nada que venderte. Solo juega. Búsqueda (A, reto diario): **Classic solitaire.** Daily challenge with friends. Calm, no catch. / **Solitario clásico.** Reto diario con tus amigos. Tranquilo, sin trampas. Fuentes en `AppStore/creative/`, exportadas con `scripts/creative-assets.py`.

Sin nombres ni estética de otras apps de solitario.

## Qué falta hacer a mano en App Store Connect

La API no cubre bien estos pasos, o conviene revisarlos con calma:

- Clasificación por edad (cuestionario: todo "No"/"Ninguno" → 4+).
- Precio (gratis) y disponibilidad.
- Privacidad de la app: "Data Not Collected".
- En la versión 1.0: activar Game Center y elegir los logros y clasificaciones, elegir el build, las notas para la revisión (arriba) y la publicación automática.
- Revisar la ficha generada (textos e imágenes en inglés y español de México).
