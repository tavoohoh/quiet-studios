# Backlog · Quiet Numbers

## En curso

## Siguiente

### Challenges y activities de Game Center (iOS 26+)
- **Cuándo:** después de que la 1.1 esté publicada en la App Store.
- **Por qué:** los challenges convierten el reto diario en una competencia con amigos y contactos (hasta 16) que el sistema promociona en el Games app y con notificaciones; las activities llevan directo del Games app o de una notificación a la parte del juego que corresponde.
- **Qué:**
  - **Clasificación nueva `daily_time`:** recurrente cada 24 h desde las 05:00 UTC (como `daily_challenge`), formato de tiempo, menor es mejor, Best Score. Solo la envía el intento puntuable al llegar a la meta. Hace falta porque Game Center compara solo el puntaje y en `daily_challenge` casi todos terminan empatados en la meta (el tiempo que va en el `context` no lo usan los challenges).
  - **Challenge "Reto del día" / "Daily Challenge":** sobre `daily_time`, no repetible (un intento, como el reto puntuable; si ya jugó hoy, su tiempo cuenta). Dura lo que queda del día del reto.
  - **Activity "Reto del día":** deep link al reto de hoy (o continuarlo); clasificaciones `daily_challenge` y `daily_time`; logros Constancia, Hábito, Centenario y Noctámbulo.
  - **Activity "Partida clásica":** continuar o empezar una partida clásica; clasificación `best_score`; logros Tabla rasa, Sin ayuda, Etapa 5, Barrendero y Monótono.
  - **En la app (solo iOS 26 y con sesión):** botón "Retar a un amigo" en la tarjeta del Reto diario y en la hoja de resumen al completar el reto (`GKAccessPoint.shared.trigger(challengeDefinitionID:)`); marca "Reto con amigos" si `hasActiveChallenges`; `GKGameActivityListener` que lleva al reto o a la partida clásica, en arranque en frío o en caliente, después del tutorial si no se ha visto.
  - **QuietKit:** el listener, los disparadores y el chequeo de iOS 26 van en `GameCenterService` de QuietUI para que Quiet Solitaire lo adopte igual.
  - **App Store Connect:** la API tiene `gameCenterChallenges` y `gameCenterActivities` (verificado el 2026-10-29: 0 de cada uno); crearlos con `scripts/setup-game-center.py` y `AppStore/game-center.json`, textos en/es. Configurar la versión mínima del challenge a la que traiga el código.
  - Privacidad sin cambios ("Data Not Collected"): todo pasa por Game Center.
- **Decidido (2026-10-29):** se hace después de publicar la 1.1. Recomendación pendiente de confirmar: solo `daily_time` + "Reto del día" + las 2 activities.
- **Abierto:** ¿agregar también el clásico semanal (abajo)?
- **Referencias:** [Creating engaging challenges from leaderboards](https://developer.apple.com/documentation/gamekit/creating-engaging-challenges-from-leaderboards), [Choosing a leaderboard for your challenges](https://developer.apple.com/documentation/gamekit/choosing-a-leaderboard-for-your-challenges), [Creating activities for your game](https://developer.apple.com/documentation/gamekit/creating-activities-for-your-game), [WWDC25: Get started with Game Center](https://developer.apple.com/videos/play/wwdc2025/214/).

### Challenge "Clásico de la semana" (opcional)
- **Cuándo:** después del anterior, si los challenges se usan.
- **Por qué:** un challenge sobre `best_score` (clásica) no sirve: si no es repetible arrastra el récord de siempre y gana el veterano; los repetibles necesitan una clasificación recurrente.
- **Qué:** clasificación `classic_week` recurrente semanal (lunes 05:00 UTC), Best Score, enviada al terminar o abandonar cada partida clásica (también si no supera el mejor). Challenge repetible (1, 3 o ilimitados intentos, lo elige quien reta) que dura lo que queda de la semana. Agregar `classic_week` a la activity "Partida clásica".

### Notificaciones del reto diario (locales)
- **Cuándo:** después de publicar la 1.1; antes que los challenges, porque no depende de iOS 26.
- **Por qué:** traer de vuelta al jugador sin anuncios, tracking ni servidor.
- **Decidido (2026-10-30):** probar estas tres; hora fija 19:00.
- **Qué:** todo con `UNUserNotificationCenter` (programadas en el dispositivo, sin APNs ni backend: se mantienen "sin backend" y "Data Not Collected"). Máximo dos al día.
  1. **Recordatorio, 19:00 hora local**, si no se completó el reto de hoy: "El reto de hoy te espera" / "Today's challenge is waiting". Con racha ≥ 3: "No pierdas tu racha de 8 días".
  2. **Un amigo ya lo hizo (dentro del mismo recordatorio):** la forma más liviana, sin servidor ni notificación extra. Una tarea en segundo plano (`BGAppRefreshTask`, a partir de las 17:00) carga la clasificación diaria de amigos con lo que ya existe (`GameCenterService`, el mismo que da el puesto entre amigos) y, si algún amigo ya jugó, reescribe el texto del recordatorio de las 19:00: "Ana completó el reto con 560. ¿Te animas?" / "3 amigos ya lo hicieron; Ana va primera con 560". No llega enseguida (iOS decide cuándo corre la tarea); si no corrió, sale el recordatorio normal. No se guarda nada de Game Center: solo se reemplaza el texto pendiente.
  3. **Racha en riesgo, 21:00**, si sigue sin completarse y hay racha ≥ 3: "Tu racha de 8 días termina a medianoche" / "Your 8-day streak ends at midnight".
  - Al completar el reto se cancelan las de hoy. Se programan los próximos días al abrir la app y se rehacen al cambiar de día o de zona horaria.
  - Permiso: se pide en contexto al completar el primer reto ("¿Te aviso a las 7 p. m. si no has jugado?"), nunca al abrir la app. Ajustes: interruptor "Recordatorio del reto" (apagado = no se programa nada).
  - Textos localizados en/es; con plurales del catálogo.
- **Va a QuietKit:** el programador de notificaciones del reto y la tarea de amigos; cada juego da sus textos.
- **Aceptación:** con el simulador en una fecha fija, se programan 19:00 y 21:00; completar el reto las cancela; sin permiso no se programa nada; la tarea de segundo plano (forzada desde Xcode) cambia el texto con los datos de ejemplo de `-demo`.

### Perfil de amigos y amigos en el reto diario
- **Cuándo:** después de publicar la 1.1.
- **Decidido (2026-10-30):** se hace.
- **Por qué:** hoy los puntajes de amigos solo se ven en la pestaña Amigos de Clasificaciones; no hay una forma clara de compararse en el reto.
- **Qué (todo con lo que Game Center entrega):**
  - En **Reto diario**, una tarjeta "Amigos hoy": los amigos que ya jugaron con su puntaje y tiempo, y tu posición (ya existe el puesto entre amigos).
  - Tocar un amigo (en esa tarjeta o en Clasificaciones › Amigos) abre su **perfil**: foto (`loadPhoto`), nombre, y frente a frente contigo: reto de hoy (puntaje y tiempo, del `context`), mejor puntaje clásico y racha más larga (`loadEntries(for: [jugadores], timeScope:)` en las 3 clasificaciones), y los últimos 7 retos (ocurrencias anteriores de la clasificación recurrente, `loadPreviousOccurrence`) con "Le ganaste 4 de 7". Botón "Retar" (con los challenges de iOS 26) y "Ver en Game Center".
  - Game Center **no** entrega: logros de otros jugadores, su calendario ni sus partidas. Amigos = los de Game Center (permiso `NSGKFriendListUsageDescription`, ya está).
  - Privacidad: solo se muestra en pantalla, no se guarda (condición de "Data Not Collected" del `CLAUDE.md`).
- **Va a QuietKit:** la vista de perfil y la carga de entradas por jugador en `GameCenterService`.
- **Abierto:** verificar la API para abrir el perfil nativo de un jugador en iOS 18 y 26.

## Ideas

- **Más notificaciones (locales), si las primeras funcionan:** "te faltan N retos para Constancia/Hábito/Centenario" una sola vez; resumen semanal el domingo ("5 de 7 retos esta semana"); partida clásica a medias al día siguiente. Los challenges de Game Center (iOS 26) traen además sus propias notificaciones del sistema.

## Hecho
