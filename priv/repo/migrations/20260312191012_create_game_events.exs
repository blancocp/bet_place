defmodule BetPlace.Repo.Migrations.CreateGameEvents do
  use Ecto.Migration

  def change do
    create table(:game_events, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :game_type_id, references(:game_types, type: :binary_id, on_delete: :restrict),
        null: false

      add :game_config_id, references(:game_configs, type: :binary_id, on_delete: :restrict),
        null: false

      add :course_id, references(:courses, type: :binary_id, on_delete: :restrict), null: false
      add :created_by, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :name, :string, null: false
      add :status, :string, null: false, default: "draft"
      add :betting_closes_at, :utc_datetime
      add :total_pool, :decimal, precision: 15, scale: 2, null: false, default: 0
      add :house_amount, :decimal, precision: 15, scale: 2, null: false, default: 0
      add :prize_pool, :decimal, precision: 15, scale: 2, null: false, default: 0
      add :canceled_reason, :string

      timestamps(type: :utc_datetime)
    end

    create index(:game_events, [:game_type_id])
    create index(:game_events, [:course_id])
    create index(:game_events, [:status])
    create index(:game_events, [:created_by])
  end
end
