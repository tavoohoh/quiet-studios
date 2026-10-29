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

## Ideas

## Hecho
