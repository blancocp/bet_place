defmodule BetPlace.Repo.Migrations.AddDynamicPollaFieldsToGameEvents do
  use Ecto.Migration

  def change do
    alter table(:game_events) do
      add :ticket_value, :decimal, precision: 10, scale: 2, null: false, default: 100.00
      add :dynamic_polla, :boolean, null: false, default: false
      add :dynamic_window_minutes, :integer
      add :dynamic_enabled_at, :utc_datetime
      add :dynamic_closes_at, :utc_datetime
    end

    create constraint(:game_events, :dynamic_window_minutes_range,
             check:
               "dynamic_window_minutes IS NULL OR (dynamic_window_minutes >= 1 AND dynamic_window_minutes <= 3)"
           )
  end
end
