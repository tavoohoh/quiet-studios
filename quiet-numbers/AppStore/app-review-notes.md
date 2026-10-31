# Notas para la revisión de Apple

Respuesta al rechazo del 2026-10-31 (Guideline 2.1 - Information Needed) de la 1.1 (8). Va completa en App Store Connect › versión › App Review Information › Notes, y el video como adjunto de esa misma sección.

```text
1. Screen recording
Attached: recorded on an iPhone running the latest iOS with the submitted build. It starts by launching the app and shows the typical flow: the first-run tutorial, a classic game (pairs, hint, undo, adding numbers with +), the daily challenge and its calendar, Game Center leaderboards, the achievements collection and Settings.
The app has no account registration or login, no user-generated content and no paid content or in-app purchases, so none of those flows exist.

2. Purpose and audience
Quiet Numbers is a free, calm number puzzle for adults and teens who want a short, relaxing brain break without ads, purchases or tracking. Players clear a board of digits by pairing numbers that are equal or add up to ten. A daily challenge (the same board for everyone) gives a reason to come back, with an optional Game Center leaderboard. The value is a focused, respectful game: no ads, no in-app purchases, no accounts and no data collected.

3. How to access the main features
No login, demo account or sample files are needed. Open the app and tap New Game; the first time, a short interactive tutorial explains the rules (it can be replayed from Settings > How to Play). Daily Challenge is on the Home screen. Leaderboards and achievements use Game Center if the device is signed in; everything else works signed out and offline. Cosmetic rewards (themes, tile styles, icons) unlock automatically from achievements and are shown in Collection.

4. External services
Only Apple's Game Center (optional leaderboards and achievements) and the user's own iCloud via SwiftData/CloudKit for syncing progress between their devices. No third-party SDKs, analytics, ads, payment processors, authentication services or AI services. No server of our own.

5. Regional differences
None. The app works the same in all regions; it is localized in English and Spanish.

6. Regulated industry / third-party material
Not applicable. The app does not operate in a regulated industry and contains no third-party protected material; the pairing mechanic is a generic number-puzzle mechanic, and all names, art and text are our own.
```

## Guion del video (2–3 min, iPhone, build en revisión)

Ver el procedimiento en la respuesta de la sesión `quiet-studio` del 2026-10-31; resumen:

1. Instalación limpia del build en revisión (TestFlight › Quiet Numbers › builds anteriores › 1.1 (8)), para que salga el tutorial.
2. Grabar desde la pantalla de inicio de iOS: abrir la app (splash → Inicio).
3. Nueva partida → tutorial completo → algunas parejas, una pista, deshacer, +.
4. Volver a Inicio → Reto diario: jugar unas jugadas, salir y ver "Continuar / Empezar de nuevo", calendario.
5. Clasificaciones (Game Center con sesión iniciada), Colección (logros y recompensas), Ajustes (Cómo jugar, sin cuentas).
