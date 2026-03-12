defmodule BetPlace.Repo.Migrations.CreateApiSyncLogs do
  use Ecto.Migration

  def change do
    create table(:api_sync_logs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :endpoint, :string, null: false
      add :external_ref, :string
      add :status, :string, null: false
      add :response_hash, :string
      add :error_message, :string
      add :synced_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:api_sync_logs, [:endpoint])
    create index(:api_sync_logs, [:synced_at])
  end
end
