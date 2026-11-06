# Notas para la revisión de Apple

Para el primer envío de la 1.0 (build 4, 2026-11-05), con la plantilla de `quiet-numbers/AppStore/app-review-notes.md` (skill `quiet-release` › Envío a revisión). Va completa en App Store Connect › versión › App Review Information › Notes, y el video como adjunto de esa misma sección.

```text
Hi, thanks for taking a look at Quiet Solitaire.

What it is
Classic Klondike solitaire, draw one: move all 52 cards to the foundations, from ace to king. We made it for people who want a few calm minutes with a card game, without ads, purchases, accounts or tracking. Every deal can be won, and there's a daily challenge, the same deal for everyone, if you like a reason to come back.

How to try it
No login or demo account needed. Open the app and tap New Game; the first time, a short tutorial walks through the moves (you can replay it from Settings > How to play). The Daily Challenge is on the Home screen; past days can be played from its calendar. Leaderboards, Collection and Settings are the three icons at the top right of Home. If the device is signed in to Game Center you'll also see leaderboards, achievements and friends who played today; without it, everything else works the same, offline too.

To see a win quickly, tap Hint (the lightbulb) a few times: hints follow a winning line.

After you win a first daily challenge, the app asks if you'd like a reminder at 7 pm. These are local notifications scheduled on the device, at most two a day, and they can be turned off in Settings.

The recording
Attached, recorded on an iPhone with the latest iOS and the submitted build. It starts at launch and goes through the tutorial, a classic game, the daily challenge and its calendar, the leaderboards, the Collection and Settings. There are no accounts, user content or purchases in the app, so there are no flows for those.

Services
Just Apple's: Game Center (optional) and the player's own iCloud to sync progress between their devices. No servers of our own, no third-party SDKs, analytics, ads, payments or AI.

Regions
It works the same everywhere, in English and Spanish.

Anything regulated or third-party
No. Klondike is a traditional card game; there's no betting or money of any kind. The name, card designs and text are our own.
```

## Guion del video (2–3 min, iPhone, build 1.0 (4))

Antes de grabar:

- Borrar Quiet Solitaire del iPhone e instalar el build 1.0 (4) desde TestFlight (TestFlight › Quiet Solitaire › Builds anteriores si hiciera falta), para que salga el tutorial.
- iOS al día, No molestar activado, Game Center con sesión iniciada (para que se vean las clasificaciones).
- Grabación de pantalla desde el Centro de control, sin audio ni edición.

Guion (nombres de la interfaz en inglés, con el iPhone en inglés):

1. **Abrir la app** desde la pantalla de inicio de iOS: splash de Quiet Studios → Home.
2. **New Game** → el tutorial completo (seis jugadas guiadas) → arranca una partida.
3. **Partida clásica:** tocar el mazo un par de veces (robar), mover una carta a una columna y otra a una fundación, **Undo**, **Hint** (se marca la jugada) y hacerla.
4. Volver a Home (flecha atrás) → **Daily Challenge** → **Play**. Hacer unas jugadas.
5. **⋯ › Restart This Deal** → hacer una jugada distinta → flecha atrás (vuelve a Daily Challenge).
6. Tocar **Continue** → aparece "Continue this challenge?" → **Continue**: vuelve la partida reiniciada, con la jugada nueva. Volver atrás.
7. **Calendario:** mostrar el mes, la racha y tocar un día pasado (se abre ese reto) → atrás.
8. Home → **Leaderboards** (trofeo): pestañas de hoy, mejor puntaje y racha; Global y Friends.
9. Home → **Collection** (cuadrícula): mazos, reversos, tableros y el ícono; lo bloqueado dice cómo ganarlo.
10. Home → **Settings** (engranaje): opciones de juego, "Daily challenge reminder", Game Center, **How to play**, **Rules** y el texto de privacidad. Fin.

Si alguna vez se envía un build distinto, el video se graba de nuevo con ese build.
