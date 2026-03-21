---
name: Combo selections storage
overview: Crear tabla polla_combination_selections para almacenar la composicion de cada combinacion (que runner en cada carrera), modificar place_polla_ticket para guardarla, y simplificar el scoring para usarla directamente.
todos:
  - id: migration
    content: Generar migracion add_polla_combination_selections con tabla, indices y FKs
    status: completed
  - id: schema
    content: Crear schema PollaCombinationSelection y agregar has_many en PollaCombination
    status: completed
  - id: place-ticket
    content: "Modificar place_polla_ticket para guardar combo_selections con returning: true"
    status: completed
  - id: scoring
    content: Simplificar score_ticket_combinations para leer de polla_combination_selections
    status: completed
  - id: context
    content: Actualizar CONTEXT.md con el nuevo schema
    status: completed
  - id: precommit
    content: Ejecutar mix precommit, commit y push
    status: completed
isProject: false
---

# Almacenar composicion de combinaciones de Polla

## Problema

`polla_combinations` solo guarda `combination_index` y `total_points`. La composicion (que runner corresponde a cada carrera en esa combinacion) se descarta al guardar y se re-calcula en el scoring via `cartesian_product`. Esto impide mostrar al usuario el detalle de cada combo y hace fragil el scoring.

## Nueva tabla: `polla_combination_selections`

```
polla_combination_selections
  id                      :binary_id, PK
  polla_combination_id    :binary_id, FK -> polla_combinations
  game_event_race_id      :binary_id, FK -> game_event_races
  runner_id               :binary_id, FK -> runners
  inserted_at             :utc_datetime

  UNIQUE INDEX: (polla_combination_id, game_event_race_id)
```

Cada fila = "en la combinacion X, para la carrera Y, el runner elegido es Z". Una combinacion de 6 carreras genera 6 filas.

## Cambios

### 1. Migracion

Generar via `mix ecto.gen.migration add_polla_combination_selections`.

### 2. Schema Ecto

Nuevo archivo [lib/bet_place/betting/polla_combination_selection.ex](lib/bet_place/betting/polla_combination_selection.ex):

```elixir
schema "polla_combination_selections" do
  belongs_to :polla_combination, PollaCombination
  belongs_to :game_event_race, GameEventRace
  belongs_to :runner, Runner
  timestamps(type: :utc_datetime, updated_at: false)
end
```

Agregar `has_many :polla_combination_selections` en [lib/bet_place/betting/polla_combination.ex](lib/bet_place/betting/polla_combination.ex).

### 3. Modificar `place_polla_ticket` en [lib/bet_place/betting.ex](lib/bet_place/betting.ex)

En el `Ecto.Multi`:

- Cambiar `insert_all(:combinations, ...)` para usar `returning: true` y asi obtener los IDs insertados
- Agregar un nuevo step `insert_all(:combo_selections, ...)` que, usando los combos retornados y la lista de `combinations` (del cartesian product), inserte la composicion:

```elixir
|> Ecto.Multi.insert_all(:combinations, PollaCombination, ..., returning: true)
|> Ecto.Multi.insert_all(:combo_selections, PollaCombinationSelection, fn %{combinations: {_, combos}} ->
  sorted_combos = Enum.sort_by(combos, & &1.combination_index)
  for {combo_record, combo_runners} <- Enum.zip(sorted_combos, combinations),
      {runner_id, ger} <- Enum.zip(combo_runners, ordered_races) do
    %{
      polla_combination_id: combo_record.id,
      game_event_race_id: ger.id,
      runner_id: runner_id,
      inserted_at: now
    }
  end
end)
```

### 4. Simplificar `score_ticket_combinations` en [lib/bet_place/betting/settlement.ex](lib/bet_place/betting/settlement.ex)

Actualmente (linea 410-458) re-genera el cartesian product para mapear runners a combos por indice. Con la tabla nueva, se lee directamente de `polla_combination_selections`:

```elixir
defp score_ticket_combinations(ticket, _ordered_races) do
  combos = PollaCombination
  |> where([pc], pc.polla_ticket_id == ^ticket.id)
  |> preload(:polla_combination_selections)
  |> Repo.all()

  points_lookup = build_points_lookup(ticket.id)

  Enum.each(combos, fn combo ->
    total_pts = Enum.reduce(combo.polla_combination_selections, 0, fn cs, acc ->
      acc + Map.get(points_lookup, {cs.game_event_race_id, cs.runner_id}, 0)
    end)
    combo |> PollaCombination.result_changeset(%{total_points: total_pts}) |> Repo.update!()
  end)
end
```

Eliminar la funcion privada `cartesian_product/1` de settlement.ex (solo mantenerla en betting.ex).

### 5. Actualizar CONTEXT.md

Agregar el schema de `polla_combination_selections` en la seccion Database Schema, despues de `polla_combinations`.

## Datos existentes

Los 2 tickets existentes del evento Charles Town no tendran `polla_combination_selections`. Se puede backfill regenerando el cartesian product una sola vez, o simplemente aceptar que los tickets antiguos no tienen ese detalle (solo afecta la visualizacion, no el scoring que sigue funcionando por indice como fallback).