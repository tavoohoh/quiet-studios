# App Store Connect: Quiet Solitaire

Todo lo necesario para crear y publicar la app. Textos en `fastlane/metadata/{en-US,es-MX}` (validar con `scripts/validate-metadata.py`), imágenes en `AppStore/store-images/`, Game Center en `game-center.md`.

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
| Categoría principal | Juegos › **Cartas** |
| Categoría secundaria | Juegos › Puzle |
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
| Game Center | Activar en la versión y agregar los 13 logros y las 3 clasificaciones (`scripts/setup-game-center.py`, pendiente) |
| Cifrado | No usa cifrado propio (`ITSAppUsesNonExemptEncryption = NO` en el Info.plist) |
| Publicación | Automática al aprobarse (como Quiet Numbers) |

### Notas para la revisión de Apple

> Quiet Solitaire is a free, single-player Klondike solitaire with no ads, purchases or accounts. Game Center is optional: everything works signed out. To see a win quickly, play any game and use Hint (lightbulb) repeatedly; the hints follow a winning line. No login or demo account is needed.

## Imágenes de la App Store

Cinco por dispositivo e idioma, en este orden (`scripts/screenshots.sh` y luego `scripts/store-images.py`):

| # | Archivo | English | Español |
|---|---|---|---|
| 1 | `01-no-ads` (partida en curso, claro) | **Classic solitaire. No ads. Ever.** Klondike, draw one. No purchases, no data collected. Just you and the cards. · *Every deal can be won* | **Solitario clásico. Sin anuncios.** Klondike, robando de a una. Sin compras y sin recolectar datos. Solo tú y las cartas. · *Cada reparto se puede ganar* |
| 2 | `02-daily` (reto diario, claro) | **A new deal every day.** The same deal for everyone, always winnable. Easy on Monday, expert on Sunday. · *8-day streak* | **Un reparto nuevo cada día.** El mismo para todos, y siempre se puede ganar. Fácil el lunes, experto el domingo. · *Racha de 8 días* |
| 3 | `03-win` (victoria con fuegos, claro) | **Win fast, score double.** Finish in under 3 minutes for ×2 points. Every win ends in fireworks. · *×2* | **Gana rápido, suma el doble.** Termina en menos de 3 minutos y gana ×2 puntos. Cada victoria acaba en fuegos artificiales. · *×2* |
| 4 | `04-rewards` (Índigo, mazo Pixel, reverso Noche, oscuro) | **Earned, never bought.** Pixel, Classic and Illustrated decks, card backs and boards, unlocked by playing. | **Se gana, nunca se compra.** Mazos Pixel, Clásico e Ilustrado, reversos y tableros que desbloqueas jugando. |
| 5 | `05-leaderboards` (amigos, oscuro) | **Climb to the top.** Daily, best-score and streak leaderboards with friends and the world, on Game Center. | **Llega a la cima.** Clasificaciones del día, de mejor puntaje y de racha con tus amigos y el mundo, en Game Center. |

Sin nombres ni estética de otras apps de solitario.
