defmodule BetPlace.Repo.Migrations.CreateGameConfigs do
  use Ecto.Migration

  def change do
    create table(:game_configs, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :game_type_id, references(:game_types, type: :binary_id, on_delete: :restrict),
        null: false

      add :house_cut_pct, :decimal, precision: 15, scale: 4, null: false
      add :ticket_value, :decimal, precision: 15, scale: 2
      add :min_stake, :decimal, precision: 15, scale: 2
      add :prize_multiplier, :decimal, precision: 15, scale: 4
      add :max_horses_per_race, :integer
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:game_configs, [:game_type_id])
  end
end
