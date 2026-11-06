# Notas para la revisión de Apple

Para la 1.0 (primer envío). Responden por adelantado lo que Apple pide en "Guideline 2.1 - Information Needed" (rechazo de Quiet Numbers del 2026-10-31), con el tono y el orden de `quiet-numbers/AppStore/app-review-notes.md`. Van completas en App Store Connect › versión 1.0 › App Review Information › Notes, y el video como adjunto de esa misma sección. Revisarlas si cambia algo que mencionan (servicios, notificaciones, funciones nuevas).

```text
Hi, thanks for taking a look at Quiet Sudoku.

What it is
Classic 9×9 sudoku, made calm: fill the grid so every row, column and 3×3 box holds 1 to 9 once. We made it for people who want a few quiet minutes with a puzzle, including people who have never played sudoku, without ads, purchases, accounts or tracking. Every puzzle is generated on the device, has exactly one solution and can be solved by logic alone. There's also a daily challenge, the same puzzle for everyone, if you like a reason to come back.

How to try it
No login or demo account needed. Open the app and tap New Game; the first time, a short interactive tutorial teaches the rules (you can replay it from Settings > How to play). After that, New Game asks for a level (Easy to Expert). In a game, Hint (the lightbulb) writes the next digit and explains why, so you can see a solve quickly. The Daily Challenge is on the Home screen. If the device is signed in to Game Center you'll also see leaderboards, achievements and friends who played today; without it, everything else works the same, offline too.

After you finish a first daily challenge, the app asks if you'd like a reminder at 7 pm. These are local notifications scheduled on the device, at most two a day, and they can be turned off in Settings.

The recording
Attached, recorded on an iPhone with the latest iOS and the submitted build. It starts at launch and goes through the tutorial, a game with notes, a hint and undo, the daily challenge and its calendar, the leaderboards, the collection of rewards and Settings. There are no accounts, user content or purchases in the app, so there are no flows for those.

Services
Just Apple's: Game Center (optional) and the player's own iCloud to sync progress between their devices. No servers of our own, no third-party SDKs, analytics, ads, payments or AI.

Regions
It works the same everywhere, in English and Spanish.

Anything regulated or third-party
No. Sudoku is a classic public-domain puzzle; every puzzle comes from our own generator, and the name, art and text are our own.
```

## Guion del video (2–3 min, iPhone, build 1.0 (2))

Lo graba el usuario en su iPhone con el iOS más reciente. Sin audio ni edición; grabación de pantalla del Centro de control.

**Antes de grabar**
1. Borrar Quiet Sudoku del iPhone (instalación limpia, para que salga el tutorial) e instalar el build **1.0 (2)** desde TestFlight.
2. Activar No molestar y dejar Game Center con la sesión iniciada (Ajustes de iOS › Game Center).
3. Sin abrir la app, empezar la grabación desde la pantalla de inicio.

**Grabación**
1. **Abrir** Quiet Sudoku desde la pantalla de inicio: splash → Home. Si sale el aviso de Game Center, dejarlo pasar.
2. **Tutorial:** tocar **New Game** → hacer los 7 pasos del tutorial hasta **You're ready**.
3. **Partida libre:** **Start playing** abre una partida Easy.
   - Tocar una celda y un número (unas 3 jugadas).
   - **Notes:** activarlo, escribir dos candidatos en una celda vacía y desactivarlo.
   - **Hint:** tocar la bombilla; esperar a que se lea la explicación.
   - **Undo:** deshacer la última jugada.
   - Volver a Home con la flecha (la partida queda guardada: se ve **Continue · Easy**).
4. **Reto diario:** tocar la tarjeta **Daily Challenge** → **Play**.
   - Hacer 2 o 3 jugadas.
   - **⋯ › Restart This Sudoku** (el tablero vuelve a empezar) y hacer una jugada nueva.
   - Salir con la flecha y volver a tocar **Play**: sale **Continue this challenge?** → **Continue** (vuelve el intento nuevo, no el primero).
   - Salir otra vez a la pantalla del reto y mostrar el **calendario** (flecha al mes anterior y de vuelta).
5. **Clasificaciones:** Home → trofeo → pestañas **Today**, **Best score** y **Streak**; **Global** y **Friends**.
6. **Colección:** Home → ícono de cuadrícula: estilos de números, notas, resaltado, tableros e ícono (los bloqueados dicen cómo se ganan).
7. **Ajustes:** Home → engranaje: **Show mistakes right away**, **Daily challenge reminder**, **How to play**, **Techniques** y el texto de **Privacy** (sin cuentas).
8. Volver a Home y detener la grabación.

Duración esperada: 2–3 min. Subirlo en la misma sección que las notas (App Review Information › Attachment).
