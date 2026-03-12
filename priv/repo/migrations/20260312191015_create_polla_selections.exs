defmodule BetPlace.Repo.Migrations.CreatePollaSelections do
  use Ecto.Migration

  def change do
    create table(:polla_selections, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :polla_ticket_id, references(:polla_tickets, type: :binary_id, on_delete: :restrict),
        null: false

      add :game_event_race_id,
          references(:game_event_races, type: :binary_id, on_delete: :restrict), null: false

      add :runner_id, references(:runners, type: :binary_id, on_delete: :restrict), null: false

      add :effective_runner_id, references(:runners, type: :binary_id, on_delete: :restrict),
        null: false

      add :was_replaced, :boolean, null: false, default: false
      add :points_earned, :integer, null: false, default: 0

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:polla_selections, [:polla_ticket_id])
    create index(:polla_selections, [:game_event_race_id])
    create index(:polla_selections, [:runner_id])
    create index(:polla_selections, [:effective_runner_id])
  end
end
