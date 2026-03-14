# Eliminar requests zombie + Reemplazo circular de non-runners

## 1. Filtro de horario para racecards auto-sync

**Archivo:** [lib/bet_place/api/sync_worker.ex](lib/bet_place/api/sync_worker.ex)

**Problema:** `handle_info(:sync_racecards, ...)` no verificaba `within_race_hours?()`. Si auto-sync estaba activo, hacia 1 request cada 30 minutos las 24 horas — 48 requests/dia innecesarios fuera de jornada.

**Cambio:** Se agrego la misma guarda que ya tiene `handle_info(:poll_results, ...)`:

```elixir
def handle_info(:sync_racecards, state) do
  if SyncSettings.auto_sync_enabled?() and within_race_hours?() do
    ...
```

Esto reduce los requests automaticos de racecards de ~48/dia a ~22/dia (solo entre 12:00–23:00 UTC).

---

## 2. Reemplazo circular de non-runners

**Archivo:** [lib/bet_place/betting/settlement.ex](lib/bet_place/betting/settlement.ex)

**Problema:** La funcion `handle_non_runner/2` buscaba el reemplazo con `program_number + 1`. Si se retiraba el caballo 8 (ultimo) y no existia el 9, devolvia `nil` y no hacia reemplazo.

**Regla de negocio:**

- Caballo 3 se retira -> reemplaza el 4
- Caballo 8 (ultimo) se retira -> reemplaza el 1 (wrap-around)
- Si el siguiente tambien es non-runner, saltar al que sigue

**Cambio:** Nueva funcion `find_next_active_runner/2` en `Racing`:

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

En `settlement.ex`, se reemplazo:

```elixir
replacement = Racing.find_next_active_runner(race_id, original_program_number)
```

---

## 3. Texto descriptivo del dashboard

Se actualizo el texto del auto-sync en el dashboard admin para indicar que ambos syncs respetan horario de carreras: "(solo 12–23 UTC)".
