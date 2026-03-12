defmodule BetPlace.Repo.Migrations.CreateGameEventRaces do
  use Ecto.Migration

  def change do
    create table(:game_event_races, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :game_event_id, references(:game_events, type: :binary_id, on_delete: :restrict),
        null: false

      add :race_id, references(:races, type: :binary_id, on_delete: :restrict), null: false
      add :race_order, :integer, null: false
      add :status, :string, null: false, default: "pending"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:game_event_races, [:game_event_id, :race_order])
    create unique_index(:game_event_races, [:game_event_id, :race_id])
    create index(:game_event_races, [:game_event_id])
    create index(:game_event_races, [:race_id])
  end
end
