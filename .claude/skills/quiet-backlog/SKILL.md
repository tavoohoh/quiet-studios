---
name: quiet-backlog
description: Administrar el backlog de cada juego de Quiet Studios (quiet-<app>/BACKLOG.md) - anotar ideas y pendientes, revisar y priorizar, mover algo a "en curso" y cerrarlo al publicarlo. Usar cuando el usuario diga "déjalo en el backlog", pregunte qué falta o qué sigue en un juego, o al terminar una versión.
---

# Backlog de un juego

Cada juego tiene su backlog en `quiet-<app>/BACKLOG.md`. Es la lista de lo que se decidió **no** hacer todavía; lo que ya se hizo vive en el `CLAUDE.md` de la app (reglas y decisiones) y en git. Lo que es de toda la familia va al backlog de cada juego afectado (y, si toca QuietKit, se dice en el ítem).

## Formato

```markdown
# Backlog · Quiet <App>

## En curso
<!-- lo que se está haciendo ahora; máximo 1–2 ítems -->

## Siguiente
<!-- ordenado por prioridad: el primero es lo próximo -->

### <Título corto>
- **Cuándo:** <condición o versión: "después de publicar la 1.1", "1.2", "sin fecha">
- **Por qué:** <el problema o la oportunidad, en una o dos frases>
- **Qué:** <la propuesta concreta: pantallas, reglas, Game Center, App Store Connect>
- **Decidido:** <lo que el usuario ya eligió, con fecha>
- **Abierto:** <preguntas que faltan, si hay>
- **Referencias:** <links a docs de Apple, archivos, artefactos>

## Ideas
<!-- sin priorizar; una línea cada una hasta que se vuelvan "Siguiente" -->

## Hecho
<!-- "- <título> · <versión> · <fecha>" (una línea; el detalle queda en CLAUDE.md) -->
```

## Cómo trabajar

- **Anotar** ("déjalo en el backlog"): crear el ítem con todo lo investigado y decidido hasta ese momento (que otra sesión pueda retomarlo sin repetir la investigación), en "Siguiente" con su **Cuándo**, o en "Ideas" si es una línea. Si el archivo no existe, crearlo con el formato de arriba.
- **Revisar** ("qué falta", "qué sigue"): leer el backlog del juego (o de todos: `quiet-*/BACKLOG.md`), decir qué ítems ya cumplen su **Cuándo** (p. ej. la versión ya está publicada: revisar el estado en App Store Connect o en el `CLAUDE.md`), qué tiene preguntas abiertas y recomendar el siguiente. No empezar nada sin que el usuario lo elija.
- **Empezar:** mover el ítem a "En curso" y trabajar con las fases y criterios de aceptación de siempre.
- **Cerrar:** cuando sale en una versión publicada (o el usuario lo descarta), pasar el detalle que importe al `CLAUDE.md` de la app y dejar una línea en "Hecho" (o borrarlo si se descartó, diciendo por qué en el commit).
- Al terminar una versión (`quiet-release`), revisar el backlog: lo que quedó esperando esa versión pasa a "Siguiente" arriba.
- El backlog se commitea con el resto de los cambios; no lleva secretos ni datos de App Store Connect que no sean públicos.
