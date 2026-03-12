defmodule BetPlace.Repo.Migrations.CreateGameTypes do
  use Ecto.Migration

  def change do
    create table(:game_types, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string, null: false
      add :name, :string, null: false
      add :description, :text
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create unique_index(:game_types, [:code])
  end
end
