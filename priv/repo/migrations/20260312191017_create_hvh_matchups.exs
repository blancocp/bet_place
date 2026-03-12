defmodule BetPlace.Repo.Migrations.CreateHvhMatchups do
  use Ecto.Migration

  def change do
    create table(:hvh_matchups, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :game_event_id, references(:game_events, type: :binary_id, on_delete: :restrict),
        null: false

      add :race_id, references(:races, type: :binary_id, on_delete: :restrict), null: false
      add :created_by, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :status, :string, null: false, default: "open"
      add :result_side, :string
      add :total_side_a, :decimal, precision: 15, scale: 2, null: false, default: 0
      add :total_side_b, :decimal, precision: 15, scale: 2, null: false, default: 0
      add :total_pool, :decimal, precision: 15, scale: 2, null: false, default: 0
      add :void_reason, :string
      add :resolved_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:hvh_matchups, [:game_event_id])
    create index(:hvh_matchups, [:race_id])
    create index(:hvh_matchups, [:status])
    create index(:hvh_matchups, [:created_by])
  end
end
