---
name: Validar fecha carreras
overview: Filtrar carreras por fecha actual al crear eventos, bloqueando la creación si no hay carreras del día de hoy para el hipódromo seleccionado.
todos:
  - id: filter-today
    content: Agregar filtro race_date == Date.utc_today() en Racing.list_last_races_for_game_event/2
    status: completed
  - id: update-warning
    content: Actualizar mensaje de advertencia en game_event_new_live.ex para indicar que se requieren carreras del dia
    status: completed
isProject: false
---

# Validar carreras del día al crear evento

## Problema actual

La función `list_last_races_for_game_event/2` en [racing.ex](lib/bet_place/racing.ex) solo filtra por `status in [:scheduled, :open]` sin considerar la fecha. Esto permite crear eventos con carreras de días anteriores (ej: carreras del 12/03 cuando hoy es 14/03).

## Cambios

### 1. Filtrar por fecha actual en `Racing.list_last_races_for_game_event/2`

En [lib/bet_place/racing.ex](lib/bet_place/racing.ex), agregar filtro `r.race_date == ^Date.utc_today()` a la query:

```elixir
def list_last_races_for_game_event(course_id, limit \\ 6) do
  today = Date.utc_today()

  Race
  |> where([r], r.course_id == ^course_id and r.race_date == ^today and r.status in [:scheduled, :open])
  |> order_by([r], asc: r.race_date, asc: r.post_time)
  |> limit(^limit)
  |> Repo.all()
end
```

### 2. Mejorar mensaje de advertencia en el formulario

En [lib/bet_place_web/live/admin/game_event_new_live.ex](lib/bet_place_web/live/admin/game_event_new_live.ex), actualizar el bloque de alerta (linea 97-104) para que el mensaje refleje que se requieren carreras del día actual:

```
No hay carreras programadas para hoy en este hipódromo.
Ejecuta una sincronización de racecards primero.
```

### Comportamiento resultante

- Al seleccionar un hipódromo, solo se previsualizan carreras con `race_date` igual a hoy
- Si no hay carreras de hoy: se muestra advertencia y el botón "Crear evento" queda deshabilitado (ya existente: `disabled={@preview_races == []}`)
- No se requiere lógica adicional de bloqueo: el botón ya está controlado por la lista vacía
