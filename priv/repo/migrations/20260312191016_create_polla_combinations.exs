defmodule BetPlace.Repo.Migrations.CreatePollaCombinations do
  use Ecto.Migration

  def change do
    create table(:polla_combinations, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :polla_ticket_id, references(:polla_tickets, type: :binary_id, on_delete: :restrict),
        null: false

      add :combination_index, :integer, null: false
      add :total_points, :integer, null: false, default: 0
      add :prize_amount, :decimal, precision: 15, scale: 2
      add :is_winner, :boolean, null: false, default: false

      timestamps(type: :utc_datetime)
    end

    create index(:polla_combinations, [:polla_ticket_id])
    create index(:polla_combinations, [:is_winner])
  end
end
