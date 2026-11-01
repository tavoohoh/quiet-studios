# Notas para la revisión de Apple

Respuesta al rechazo del 2026-10-31 (Guideline 2.1 - Information Needed) de la 1.1 (8). Reenviada el 2026-11-01 como 1.2 (9), con los recordatorios y los amigos. Va completa en App Store Connect › versión › App Review Information › Notes, y el video como adjunto de esa misma sección.

```text
Hi, thanks for taking a look at Quiet Numbers.

What it is
A small, calm number puzzle: you clear the board by pairing numbers that match or add up to ten. We made it for people who want a few quiet minutes with a puzzle, without ads, purchases, accounts or tracking. There's also a daily challenge, the same board for everyone, if you like a reason to come back.

How to try it
No login or demo account needed. Open the app and tap New Game; the first time, a short tutorial shows the rules (you can replay it from Settings > How to Play). The Daily Challenge is on the Home screen. If the device is signed in to Game Center you'll also see leaderboards, achievements and friends who played today; without it, everything else works the same, offline too.

After you finish a first daily challenge, the app asks if you'd like a reminder at 7 pm. These are local notifications scheduled on the device, at most two a day, and they can be turned off in Settings.

The recording
Attached, recorded on an iPhone with the latest iOS and the submitted build. It starts at launch and goes through a classic game, the daily challenge and its calendar, the leaderboards, the achievements collection and Settings. There are no accounts, user content or purchases in the app, so there are no flows for those.

Services
Just Apple's: Game Center (optional) and the player's own iCloud to sync progress between their devices. No servers of our own, no third-party SDKs, analytics, ads, payments or AI.

Regions
It works the same everywhere, in English and Spanish.

Anything regulated or third-party
No. The pairing mechanic is a classic number-puzzle idea; the name, art and text are our own.
```

## Guion del video (2–3 min, iPhone, build en revisión)

El video enviado el 2026-11-01 es de la 1.2 (9).

Ver el procedimiento en la respuesta de la sesión `quiet-studio` del 2026-10-31; resumen:

1. Instalación limpia del build en revisión (TestFlight › Quiet Numbers › builds anteriores › el build enviado), para que salga el tutorial.
2. Grabar desde la pantalla de inicio de iOS: abrir la app (splash → Inicio).
3. Nueva partida → tutorial completo → algunas parejas, una pista, deshacer, +.
4. Volver a Inicio → Reto diario: jugar unas jugadas, salir y ver "Continuar / Empezar de nuevo", calendario.
5. Clasificaciones (Game Center con sesión iniciada), Colección (logros y recompensas), Ajustes (Cómo jugar, sin cuentas).
