# Plan de medición

Sin analytics propias ni SDKs: todo sale de **App Store Connect** (Analytics, Trends, Ratings and Reviews), que Apple agrega y no rompe la etiqueta "Data Not Collected". Algunos datos (sesiones, retención, crashes) solo cuentan a quienes aceptaron compartir datos con desarrolladores, así que se leen como tendencia, no como total.

**Empieza cuando las apps estén publicadas.** Hasta entonces, solo comentarios de TestFlight.

## Qué mirar, por app

| Pregunta | Métrica en App Store Connect | Dónde |
|---|---|---|
| ¿Nos ven? | Impresiones, vistas de la ficha | Analytics › Acquisition |
| ¿La ficha convence? | Conversión (descargas / vistas de ficha) | Analytics › Acquisition |
| ¿De dónde llegan? | Fuente: Búsqueda, Explorar, referidos web y de apps | Analytics › Sources |
| ¿Cuántos la bajan? | Descargas por primera vez, redescargas | Analytics › Overview / Trends |
| ¿Vuelven? | Sesiones por dispositivo activo, dispositivos activos, retención día 1 / 7 / 28 | Analytics › Usage, Retention |
| ¿Funciona bien? | Crashes | Analytics › Usage; Xcode Organizer |
| ¿Les gusta? | Calificación promedio, reseñas (en/es) | Ratings and Reviews |
| ¿Dónde? | Países (Colombia, México, EE. UU., España…) | Filtro por territorio |

Para la ficha: **Product Page Optimization** (pruebas A/B de ícono, capturas y header) y páginas personalizadas cuando haya volumen.

## Cuándo

- Primer mes tras publicar: revisión semanal.
- Después: mensual, el primer día hábil del mes.
- Cada revisión queda como una fila en `studio/medicion-registro.md` (fecha, app, versión, cifras de la tabla, notas, decisión).

## Cómo decidimos (umbrales por definir con el usuario tras el primer mes)

- Conversión de la ficha baja → probar otro ícono, capturas o header (Product Page Optimization).
- Retención día 7 baja → revisar la primera partida y el tutorial antes de agregar contenido.
- Reseñas que repiten un problema → va al CLAUDE.md de la app como pendiente.
- Juego de pago: se empieza cuando los gratis muestren [umbral de descargas y retención a definir].

## Automatizar (más adelante)

La API de App Store Connect tiene reportes de Analytics (`analyticsReportRequests`): un script en `scripts/` que baje los reportes con la misma clave de `~/.appstoreconnect` y agregue la fila del mes. Solo cuando la revisión manual ya esté funcionando.
