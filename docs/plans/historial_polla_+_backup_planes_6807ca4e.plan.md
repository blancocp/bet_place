---
name: Historial Polla + backup planes
overview: Implementar el rediseño de `/historial` según el plan existente y añadir un flujo para respaldar todos los archivos de planes en `docs/plans`.
todos:
  - id: impl-historial-redesign
    content: Implementar selector de evento, Mis tickets filtrados y resumen global en BettingHistoryLive siguiendo el plan existente
    status: completed
  - id: impl-backup-plans
    content: Crear flujo sencillo para respaldar `/.cursor/plans/*.plan.md` en `docs/plans` (documentado y/o script)
    status: in_progress
isProject: false
---

## Objetivo

- Implementar el rediseño de `/historial` descrito en `rediseño_historial_polla_81520df0.plan.md`.
- Añadir un flujo sencillo para respaldar todos los archivos de planes (`.plan.md`) en `docs/plans`, sin cargar todos los eventos de por vida al entrar a la vista.

## 1. Rediseño de `/historial` (resumen)

Apoyándonos en el plan ya creado, los pasos de implementación concreta serían:

- **Selector de evento finalizado** en `BettingHistoryLive`:
  - En `mount/3` obtener el `last_finished_event` desde una nueva función en `[lib/bet_place/games.ex](lib/bet_place/games.ex)` (por ejemplo `list_recent_finished_events(limit)` y `get_last_finished_event/0`).
  - Asignar `@selected_event_id` al último evento finalizado y una lista `@finished_events` para poblar un `<select>`.
  - Manejar `handle_event("select_event", %{"event_id" => id}, socket)` para actualizar `@selected_event_id` y recargar datos.

- **Mis tickets por evento**:
  - Reutilizar `Betting.list_polla_tickets_for_user_and_event/2` para cargar solo los tickets del usuario y evento seleccionado.
  - Ajustar el bloque actual de "Mis tickets" en `[lib/bet_place_web/live/bettor/betting_history_live.ex](lib/bet_place_web/live/bettor/betting_history_live.ex)` para que consuma esa lista en lugar de todos los tickets.

- **Resumen global (todos los bettors)**:
  - Usar `Betting.list_leaderboard_rows(@selected_event_id)` para poblar `@leaderboard_rows`.
  - Añadir un bloque UI debajo de "Mis tickets" que muestre:
    - Resumen (evento, fecha, número de pollas selladas / combinaciones).
    - Tabla estilo leaderboard: `Usuario | C1(E,Pt) ... | Total`, reutilizando el patrón de `GameEventShowLive`.

- **Optimización de carga**:
  - En el `mount` original, dejar de llamar a `list_polla_tickets_for_user/1` y `list_hvh_bets_for_user/1` completos; solo cargar lo necesario para el evento seleccionado.
  - Mantener HvH sencillo por ahora (misma lógica actual), y si luego es pesado, replicar patrón de filtro por evento.

- **Manejo de parámetros y URLs inválidas**:
  - Permitir `?event_id=` en la URL (`handle_params/3` en `BettingHistoryLive`), validando que el evento exista y esté finalizado.
  - Si el `event_id` no existe o no es finalizado, mostrar un mensaje amigable y caer de vuelta al último evento finalizado.

## 2. Backup de planes a `docs/plans`

- **Directorio de destino**:
  - Crear (o asumir existente) `docs/plans` en la raíz del proyecto.

- **Qué respaldar**:
  - Todos los archivos de planes de Cursor: `/.cursor/plans/*.plan.md`.
  - Opcional: incluir un `README.md` en `docs/plans` explicando el propósito del backup.

- **Flujo de backup propuesto** (manual al principio, automatizable luego):
  - Añadir una pequeña sección en la documentación interna (por ejemplo en `AGENTS.md` o un nuevo doc) indicando:
    - "Al finalizar una feature relacionada con planes, ejecutar un respaldo de planes: copiar `/.cursor/plans/*.plan.md` a `docs/plans/`".
  - Para una futura automatización, se podría crear un script simple (por ejemplo `scripts/backup_plans.sh` o una tarea Mix) que haga:
    - `mkdir -p docs/plans`
    - `cp .cursor/plans/*.plan.md docs/plans/`

- **Criterio de actualización**:
  - Repetir el backup cuando se creen o modifiquen planes relevantes (por ejemplo, después de cerrar un conjunto de cambios grandes).

## 3. Validación final

- Ejecutar `mix compile --warnings-as-errors` y `mix test`.
- Pruebas manuales:
  - Desde `/eventos`, pulsar el botón **Historial** y verificar que:
    - Se carga el último evento finalizado.
    - Se muestran por separado "Mis tickets" y la tabla con todos los bettors.
    - Cambiar de evento en el selector refresca ambos bloques.
  - Verificar que, tras ejecutar el flujo de backup, `docs/plans` contiene copias actualizadas de los `*.plan.md`.