---
name: quiet-new-app
description: Crear una app o juego nuevo de la familia Quiet (Quiet Studios), desde la idea hasta el primer build en TestFlight. Usar cuando se pida empezar un juego nuevo, evaluar una mecánica o armar el CLAUDE.md de un proyecto nuevo.
---

# Crear una app nueva de Quiet Studios

Antes de nada leer `CLAUDE.md` de la raíz (filosofía y reglas de la familia) y el sistema de diseño de Quiet Studios (link en ese CLAUDE.md). Las dos apps existentes son la referencia viva: `quiet-numbers/` (primera, la más completa) y `quiet-solitaire/` (nació ya sobre QuietKit).

## 0. Decidir la idea (con el usuario)

- Una mecánica conocida y **no patentada**, reinterpretada con identidad propia. Nunca nombres, arte, textos ni sonidos del juego original.
- Debe caber en "una pausa de 5 minutos": partidas cortas, se puede dejar y retomar.
- Debe tener reto diario determinista (misma semilla para todos, sin servidor). Si la mecánica no lo permite, decirlo antes de empezar.
- Modelo de negocio: por defecto gratis sin anuncios ni compras. Si el usuario quiere cobrar, decidir el modelo con él antes de crear la app en App Store Connect (pago único al descargar es lo único compatible hoy con la filosofía) y dejarlo escrito en el `CLAUDE.md` de la raíz.

## 1. Nombre e identificadores

- Nombre `Quiet <Algo>` (en inglés, genérico de la mecánica). Buscar en la App Store que no exista; si el nombre corto está tomado, usar subtítulo en el nombre de la tienda ("Quiet Numbers: Calm Puzzle") y dejar el corto en la pantalla de inicio.
- Carpeta `quiet-<algo>/`, bundle ID `com.tavoohoh.quiet<algo>`, SKU `quiet<algo>-ios`, prefijo de IDs de Game Center si puede chocar (`qs_` en Solitaire).
- Confirmar nombre y bundle ID con el usuario antes de registrarlos: no se pueden borrar.

## 2. Diseño

Crear el canvas de diseño de la app con la plantilla de la skill `quiet-design-canvas`. El diseño se cierra antes de escribir pantallas; sus links van en el CLAUDE.md de la app. Revisar `studio/roadmap.md`: el juego debe tener modo libre y retos diarios como los demás.

## 3. Proyecto

Seguir `quiet-project-structure`: XcodeGen, paquete Core propio que depende de `QuietCore`, app que usa `QuietUI`. Copiar de la app más parecida lo que sea de app (Persistence, AppModel, DemoData, scripts) y llevar a QuietKit lo que vaya a repetirse por tercera vez.

## 4. CLAUDE.md de la app

Mismas secciones que `quiet-solitaire/CLAUDE.md`, en este orden: brief y nombre; principios no negociables (los de la familia); stack; comandos; QuietKit (qué usa); arquitectura (árbol); reglas del juego (con números exactos); puntaje; reto diario; Game Center (IDs); logros y recompensas (tabla con ID, condición y recompensa); estética y UX; localización; privacidad; fases con criterio de aceptación; estado; preguntas abiertas. Arriba, el link al canvas de diseño. Cada decisión con fecha (`2026-10-27`) y el porqué.

## 5. Fases (no avanzar sin cumplir el criterio)

0. QuietKit: lo que falte en el kit para esta app, agregado y con tests.
1. Motor (Core): reglas, semilla, puntaje, deshacer, fin de partida; tests con Swift Testing, incluido "misma fecha → mismo tablero".
2. Juego jugable: tablero, animaciones, hápticos; una partida completa en iPhone y iPad.
3. Persistencia y reto diario: SwiftData, continuar, racha, calendario, práctica de 30 días.
4. Game Center: logros, 3 clasificaciones (reto, mejor puntaje, racha), partidas guardadas en iCloud.
5. Recompensas y colección.
6. Pulido y lanzamiento: localización en/es completa, accesibilidad, PrivacyInfo, capturas, ficha, TestFlight (skill `quiet-release`).

## 6. Al terminar cada sesión

- Actualizar el CLAUDE.md de la app (estado, decisiones con fecha) y, si cambió algo de la familia, el de la raíz.
- Si se tocó QuietKit: tests del kit y de todas las apps que lo usan.
- Commit solo cuando el usuario lo pida.
