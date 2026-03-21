---
name: Rediseño historial Polla
overview: Rediseñar `/historial` para separar claramente mis tickets del resumen global por evento, mostrando por defecto el último evento finalizado y evitando cargar todos los eventos de la historia.
todos:
  - id: historial-event-selector
    content: Agregar selección de evento finalizado (último por defecto) en BettingHistoryLive y cargar solo datos de ese evento
    status: pending
  - id: historial-my-tickets-per-event
    content: Adaptar bloque de Mis tickets en `/historial` para usar solo tickets del usuario y evento seleccionado
    status: pending
  - id: historial-leaderboard-per-event
    content: Reutilizar `Betting.list_leaderboard_rows/1` para mostrar resumen global del evento en `/historial`
    status: pending
  - id: historial-validation
    content: Compilar/tests y prueba manual de navegación y cambio de evento en `/historial`
    status: pending
isProject: false
---

## Objetivo

- En `/historial`:
  - Distinguir claramente entre **"Mis tickets"** y **"Resumen del evento (todos los bettors)"**.
  - Mostrar por defecto el **último evento finalizado**, con selector para cambiar de evento.
  - Evitar cargar todos los eventos/tickets de por vida al entrar.

## Diseño propuesto

### 1. Estructura general de `/historial`

- Archivo principal: `[lib/bet_place_web/live/bettor/betting_history_live.ex](lib/bet_place_web/live/bettor/betting_history_live.ex)`.
- Mantener tabs superiores `Polla` / `Horse vs Horse`.
- Dentro de la tab **Polla**:
  - Sección A: **Mis tickets** (similar a la actual, pero solo para el evento seleccionado o con filtros simplificados).
  - Sección B: **Resumen del evento** (tabla estilo captura de referencia, con todos los usuarios y combinaciones del evento seleccionado).

### 2. Selección de evento

- Añadir un selector de evento en la parte superior de la tab `Polla`:
  - Cargar solo **eventos finalizados recientes** (por ejemplo últimos N días o últimos 20 eventos, configurable en el contexto `Games`).
  - Al montar la vista:
    - Calcular `last_finished_event` (consulta en `[lib/bet_place/games.ex](lib/bet_place/games.ex)`).
    - Asignar `@selected_event_id` a ese último evento.
  - `handle_event("select_event", %{"event_id" => id}, socket)` recarga los datos de Mis tickets y del resumen solo para ese evento.

### 3. Mis tickets (por evento seleccionado)

- En el mount/`handle_event` correspondiente, usar contexto `Betting`:
  - Nueva función o reutilizar `list_polla_tickets_for_user_and_event(user_id, event_id)` para cargar **solo los tickets del usuario y del evento seleccionado**.
- UI:
  - Mostrar tarjetas de tickets como ahora (ID, fecha, total pagado, puntos, rank) pero ya filtradas por evento.
  - Mantener el detalle de combinaciones por ticket usando `polla_combinations` + `total_points`.

### 4. Resumen global del evento (todos los bettors)

- Reutilizar la lógica de leaderboard ya creada para `GameEventShowLive`:
  - El plan anterior implementó `Betting.list_leaderboard_rows(event_id)` con:
    - Una fila por combinación.
    - Columnas por carrera: selección (program_number) y puntos.
    - Total de puntos por combinación.
- Para `/historial`:
  - Añadir en `BettingHistoryLive` un assign `@leaderboard_rows` que llame a `Betting.list_leaderboard_rows(@selected_event_id)`.
  - Añadir también datos agregados: número de combinaciones (`length(@leaderboard_rows)`) y, si se desea, suma de tickets/combinaciones.
- UI sugerida (resumen):
  - Bloque resumen encima (similar al de resultados del evento):
    - "Evento: nombre + fecha".
    - "Selladas" = cantidad de combinaciones o tickets.
  - Tabla con estructura similar a la captura y a la que ya usamos en `GameEventShowLive`:
    - Columnas: `Usuario | C1 (E, Pt) | ... | Total`.

### 5. Optimización de carga de datos

- Modificar `BettingHistoryLive.mount/3` para **no cargar todo**:
  - En lugar de `Betting.list_polla_tickets_for_user(user_id)` y `list_hvh_bets_for_user(user_id)` completos:
    - Cargar solo para el evento seleccionado en Polla.
    - Para HvH se puede mantener el historial completo o, si es pesado, aplicar estrategia similar.
- Cuando cambie `@selected_event_id`:
  - Volver a cargar Mis tickets (`list_polla_tickets_for_user_and_event`) y `leaderboard_rows` para ese evento.
  - Mantener filtros de estado (`@filter_status`) pero ahora sobre subconjunto mucho menor.

### 6. Rutas y errores de URL

- Verificar ruta en `[lib/bet_place_web/router.ex](lib/bet_place_web/router.ex)`: ya existe `live "/historial", Bettor.BettingHistoryLive`.
- Manejo de URLs inexistentes:
  - A nivel Phoenix, rutas inexistentes ya devuelven 404.
  - Si se intenta acceder a `/historial?event_id=XYZ` con evento inexistente, capturar el caso en `mount/handle_params` y:
    - Mostrar mensaje amigable (“Evento no encontrado”) y no intentar cargar leaderboard.

## Validación

- `mix compile --warnings-as-errors`.
- `mix test`.
- Pruebas manuales:
  - Entrar a `/eventos` → botón Historial → `/historial` se abre sin error.
  - Ver que por defecto aparece último evento finalizado con:
    - Mis tickets del usuario para ese evento.
    - Resumen global (tabla) con todas las combinaciones de todos los bettors.
  - Cambiar de evento en el selector y comprobar que ambos bloques se actualizan sin recargar la página.

