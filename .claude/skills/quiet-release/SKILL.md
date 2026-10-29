---
name: quiet-release
description: Publicar y mantener una app de Quiet Studios en la App Store - subir builds a TestFlight, versiones, ficha (textos, capturas, header y búsqueda), Game Center por la API y la web de soporte. Usar cuando se pida subir un build, preparar una versión, cambiar la ficha o revisar el estado en App Store Connect.
---

# Publicar y mantener

Cada app documenta sus comandos exactos en su CLAUDE.md ("Comandos" y "Publicación"); esta skill es el procedimiento común.

## Credenciales (nunca en el repo)

- Team ID solo en `quiet-<app>/Config/Local.xcconfig` (ignorado por git).
- Clave de la API de App Store Connect en `~/.appstoreconnect/` (JSON con Key ID e Issuer, y `private_keys/AuthKey_<id>.p8`). Nunca copiar la `.p8` ni pegar su contenido.
- La clave no tiene permiso de firma en la nube: exportar y subir usa la cuenta de Xcode del usuario. Si falla con "Failed to Use Accounts", pedirle que renueve la sesión en Xcode › Settings › Accounts.
- No tocar el equipo "Heal Room, inc".

## Build a TestFlight

1. Versión: si la versión actual está en revisión o publicada, subir la siguiente (`MARKETING_VERSION` 1.0 → 1.1); el build (`CURRENT_PROJECT_VERSION`) siempre sube y nunca se repite. Cambiarlos en `project.yml`, `xcodegen generate`, commit "Quiet <App>: <versión> build <n>" y push (el usuario lo pide al pedir el build).
2. Archivar desde una copia limpia de `main`: `git worktree add --detach <scratch>/<app>-release origin/main`, copiar `Config/Local.xcconfig`, `xcodegen generate`, `xcodebuild archive -configuration Release -destination 'generic/platform=iOS' -allowProvisioningUpdates`.
3. `xcodebuild -exportArchive` con `ExportOptions.plist` (`method app-store-connect`, `destination upload`, `teamID`, firma automática). Si el iPhone del usuario está bloqueado, solo afecta la instalación local, no la subida.
4. Borrar la copia (`git worktree remove --force`). No quedarse esperando el procesamiento salvo que el usuario lo pida: tarda.
5. Una versión nueva en la beta externa pasa por revisión de Apple; agregar el build al grupo externo solo si el usuario lo pide.

## Instalar en el iPhone del usuario

`xcodebuild build … -destination 'id=<udid>' -allowProvisioningUpdates` y `xcrun devicectl device install app --device <id> <ruta .app>`. Si dice que el dispositivo está bloqueado, pedir que lo desbloquee y reintentar.

## Ficha de la App Store

- Textos en `fastlane/metadata/<locale>/` (en-US y es-MX; es-ES si la app lo usa); validar con `scripts/validate-metadata.py` y subir con el script de la app (`upload-metadata.py` en Solitaire) mostrando primero qué cambia y aplicando solo con permiso explícito.
- Una versión en revisión no se edita: los cambios de texto van a la versión siguiente.
- Capturas con `scripts/screenshots.sh` (no correrlo a la vez que el de otra app: comparten simuladores) e imágenes con `scripts/store-images.py` desde el canvas.
- Header, búsqueda y universal (iOS 27+): medidas y reglas en `app-store.md` del sistema de diseño; propuestas en la página "Header y búsqueda" del canvas de la app. Lo elegido se guarda como HTML estático en `AppStore/creative/` y se exporta con `scripts/creative-assets.py`. Se suben por la API con `scripts/creative-upload.py` (biblioteca de assets: reservar `appAssetLibraryImages` con categoría `CREATIVE_ASSETS`, subir las partes, `uploaded: true`; luego `appAssetLibraryPlacements` `PRODUCT_PAGE_HEADER_ASSET` / `APP_STORE_SEARCH_RESULTS_ASSET` por localización de una versión editable). Una versión en revisión no admite colocarlas.
- Al cambiar cualquier imagen de la tienda, subirla también al sistema de diseño de la app (Assets › Store) y actualizar su sección "Galería App Store".
- Reglas: apto 4+, sin precios ni descuentos, sin URLs ni ©, nada que la app no tenga, localizado en/es. Excepción (decisión 2026-10-29): los juegos gratis para siempre pueden decir "Gratis siempre" / "Always free" en las capturas (p. ej. la imagen 04 de Quiet Numbers); el header y la búsqueda no lo dicen.

## Game Center

Logros y clasificaciones se definen en `AppStore/game-center.json` y se crean con `scripts/setup-game-center.py` (muestra qué haría; `--apply` solo con permiso). Los IDs del código se verifican con `check-game-center.py` / `game-center.py`. Una clasificación publicada no cambia de formato: si hace falta otro criterio, es otra clasificación.

## Escrituras en App Store Connect

Todo cambio por la API (nombres, precios, textos, grupos de beta) es visible para Apple o el público: hacerlo solo cuando el usuario lo pidió explícitamente, mostrando antes qué va a cambiar.

## Web

`docs/quiet-<app>/` (GitHub Pages, se publica con el push a main): página, privacidad y soporte en/es. Si cambia una regla del juego que la página de soporte explica, actualizarla cuando esa versión salga a la tienda, no antes.

## Respaldo de diseño (cada versión aprobada)

Cuando Apple aprueba una versión, exportar los dos artefactos de esa app (canvas y sistema de diseño) a `quiet-<app>/design/backups/<versión>/`:
- Canvas: leer con la herramienta Artifact cada archivo de `project/` (`canvas.json` y cada `.dc.html`, que ya son HTML) y guardarlos tal cual; agregar un `index.html` simple que liste los artboards por página con su título.
- Sistema de diseño: `project/README.md`, las demás secciones `.md`, `tokens.json`, `design-system.json` y cada `components/<Comp>/preview.html`; los assets se respaldan desde el repo (ya están ahí).
- Commit "Quiet <App>: respaldo de diseño <versión>" cuando el usuario lo pida.

## Después de publicar

Actualizar el estado en el CLAUDE.md de la app (versión, build, fecha) y avisar al usuario qué queda pendiente (revisión, beta externa).
