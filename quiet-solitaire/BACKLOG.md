# Backlog · Quiet Solitaire

## En curso

## Siguiente

### Alinear el reto diario con la regla de la familia
- **Cuándo:** antes de mandar Quiet Solitaire a revisión.
- **Por qué:** desde el 2026-10-30 todos los retos funcionan como el de Quiet Numbers (sección "Reto diario (igual en todos los juegos)" del `CLAUDE.md` de la raíz).
- **Qué:** revisar punto por punto contra el código y corregir lo que falte. Ya se sabe que difiere:
  - **Retos en curso (confirmado por el usuario 2026-10-30):** falta guardar la práctica a medias por día (ranura `practice-<día>`, marca en el calendario) y preguntar "Continuar / Empezar de nuevo" al volver a un reto en curso.
  - **Racha (confirmado):** completar un día pasado debe rellenarlo para la racha, calendario y logros de retos, una vez por día (conserva el puntaje de un intento fallido).
  - **Pistas:** con "Números rojos" cuestan 3 en la práctica; deben costar 10 en todo reto (puntuable o práctica).
  - **Verificar:** calendario mensual con los días reales del mes; desempate por tiempo en `qs_daily_challenge` (`context` = segundos + 1 y `rankedByTime`); hoja de resumen con fuegos solo al completar.
- **Referencias:** `quiet-numbers/CLAUDE.md` (Reto diario, Game Center › desempate) y su código (`AppModel.fillDay`, `PersistenceService.fillDaily`, `GameView`).

### Notificaciones del reto, perfil de amigos y challenges de Game Center
- **Cuándo:** cuando Quiet Numbers los tenga (se construyen en QuietKit y se adoptan aquí).
- **Qué:** ver `quiet-numbers/BACKLOG.md` (mismo diseño; en Solitaire la clasificación de tiempo sería `qs_daily_time`).

## Ideas

## Hecho
