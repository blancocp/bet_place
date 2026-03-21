---
name: Zombie Sync y Reemplazo Circular
overview: Agregar filtro de horario al auto-sync de racecards para evitar requests innecesarios fuera de horas de carrera, y corregir la lógica de reemplazo de non-runners para usar wrap-around circular cuando el caballo retirado es el último.
todos:
  - id: racecards-guard
    content: Agregar within_race_hours?() al handle_info(:sync_racecards) en sync_worker.ex
    status: completed
  - id: circular-replacement
    content: Crear find_next_active_runner/2 en Racing y usarla en settlement.ex handle_non_runner
    status: completed
  - id: dashboard-text
    content: Actualizar texto descriptivo del auto-sync en dashboard_live.ex
    status: completed
  - id: precommit
    content: Ejecutar mix precommit y commit
    status: completed
isProject: false
---

# Eliminar requests zombie + Reemplazo circular de non-runners

## 1. Filtro de horario para racecards auto-sync

**Archivo:** [lib/bet_place/api/sync_worker.ex](lib/bet_place/api/sync_worker.ex)

**Problema:** `handle_info(:sync_racecards, ...)` (línea 62) no verifica `within_race_hours?()`. Si auto-sync está activo, hace 1 request cada 30 minutos las 24 horas — 48 requests/día innecesarios fuera de jornada.

**Cambio:** Agregar la misma guarda que ya tiene `handle_info(:poll_results, ...)`:

```elixir
# Antes (línea 62-71):
def handle_info(:sync_racecards, state) do
  if SyncSettings.auto_sync_enabled?() do
    ...

# Después:
def handle_info(:sync_racecards, state) do
  if SyncSettings.auto_sync_enabled?() and within_race_hours?() do
    ...
```

Esto reduce los requests automáticos de racecards de ~48/día a ~22/día (solo entre 12:00–23:00 UTC).

---

## 2. Reemplazo circular de non-runners

**Archivo:** [lib/bet_place/betting/settlement.ex](lib/bet_place/betting/settlement.ex), línea 184

**Problema:** La función `handle_non_runner/2` busca el reemplazo con `program_number + 1`. Si se retira el caballo 8 (último) y no existe el 9, devuelve `nil` y no hace reemplazo.

**Regla de negocio:**

- Caballo 3 se retira -> reemplaza el 4
- Caballo 8 (último) se retira -> reemplaza el 1 (wrap-around)
- Si el siguiente también es non-runner, saltar al que sigue (edge case a considerar a futuro)

**Cambio:** Crear una función auxiliar `find_replacement_runner/2` en `Racing` que busque circularmente:

En [lib/bet_place/racing.ex](lib/bet_place/racing.ex), agregar:

```elixir
def find_next_active_runner(race_id, program_number) do
  runners =
    Runner
    |> where([r], r.race_id == ^race_id and r.non_runner != true)
    |> order_by([r], r.program_number)
    |> Repo.all()

  after_current = Enum.find(runners, fn r -> r.program_number > program_number end)
  after_current || List.first(runners)
end
```

Esto busca el primer runner activo (`non_runner != true`) con `program_number` mayor. Si no existe (es el último), toma el primero de la lista (wrap-around). Cubre también el edge case de que el siguiente inmediato sea otro non-runner.

En `settlement.ex`, reemplazar la línea 189-190:

```elixir
# Antes:
replacement =
  Racing.get_runner_by_race_and_program_number(race_id, original_program_number + 1)

# Después:
replacement = Racing.find_next_active_runner(race_id, original_program_number)
```

---

## 3. Actualizar texto descriptivo del dashboard

En [lib/bet_place_web/live/admin/dashboard_live.ex](lib/bet_place_web/live/admin/dashboard_live.ex), actualizar el texto del auto-sync que dice "Racecards cada 30 min" para indicar que también respeta horario de carreras.