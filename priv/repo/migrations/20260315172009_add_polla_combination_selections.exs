defmodule BetPlace.Repo.Migrations.AddPollaCombinationSelections do
  use Ecto.Migration

  def change do
    create table(:polla_combination_selections, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :polla_combination_id,
          references(:polla_combinations, type: :binary_id, on_delete: :delete_all), null: false

      add :game_event_race_id,
          references(:game_event_races, type: :binary_id, on_delete: :delete_all), null: false

      add :runner_id, references(:runners, type: :binary_id, on_delete: :nothing), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:polla_combination_selections, [:polla_combination_id])
    create index(:polla_combination_selections, [:game_event_race_id])
    create index(:polla_combination_selections, [:runner_id])

    create unique_index(:polla_combination_selections, [
             :polla_combination_id,
             :game_event_race_id
           ])
  end
end
