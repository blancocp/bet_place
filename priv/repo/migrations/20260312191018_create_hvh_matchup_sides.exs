defmodule BetPlace.Repo.Migrations.CreateHvhMatchupSides do
  use Ecto.Migration

  def change do
    create table(:hvh_matchup_sides, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :hvh_matchup_id, references(:hvh_matchups, type: :binary_id, on_delete: :restrict),
        null: false

      add :side, :string, null: false
      add :runner_id, references(:runners, type: :binary_id, on_delete: :restrict), null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:hvh_matchup_sides, [:hvh_matchup_id])
    create index(:hvh_matchup_sides, [:runner_id])
  end
end
