defmodule BetPlace.Repo.Migrations.CreateHvhBets do
  use Ecto.Migration

  def change do
    create table(:hvh_bets, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :hvh_matchup_id, references(:hvh_matchups, type: :binary_id, on_delete: :restrict),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :side_chosen, :string, null: false
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :potential_payout, :decimal, precision: 15, scale: 2, null: false
      add :actual_payout, :decimal, precision: 15, scale: 2
      add :status, :string, null: false, default: "pending"
      add :placed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:hvh_bets, [:hvh_matchup_id])
    create index(:hvh_bets, [:user_id])
    create index(:hvh_bets, [:status])
  end
end
