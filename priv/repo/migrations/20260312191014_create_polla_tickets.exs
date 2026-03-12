defmodule BetPlace.Repo.Migrations.CreatePollaTickets do
  use Ecto.Migration

  def change do
    create table(:polla_tickets, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :game_event_id, references(:game_events, type: :binary_id, on_delete: :restrict),
        null: false

      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :combination_count, :integer, null: false
      add :ticket_value, :decimal, precision: 15, scale: 2, null: false
      add :total_paid, :decimal, precision: 15, scale: 2, null: false
      add :total_points, :integer
      add :rank, :integer
      add :status, :string, null: false, default: "active"
      add :sealed_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime)
    end

    create index(:polla_tickets, [:game_event_id])
    create index(:polla_tickets, [:user_id])
    create index(:polla_tickets, [:status])
  end
end
