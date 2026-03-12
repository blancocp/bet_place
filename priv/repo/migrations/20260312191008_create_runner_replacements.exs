defmodule BetPlace.Repo.Migrations.CreateRunnerReplacements do
  use Ecto.Migration

  def change do
    create table(:runner_replacements, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :race_id, references(:races, type: :binary_id, on_delete: :restrict), null: false

      add :original_runner_id, references(:runners, type: :binary_id, on_delete: :restrict),
        null: false

      add :replacement_runner_id, references(:runners, type: :binary_id, on_delete: :restrict),
        null: false

      add :reason, :string, null: false
      add :replaced_by, references(:users, type: :binary_id, on_delete: :restrict)
      add :replaced_at, :utc_datetime, null: false

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:runner_replacements, [:race_id])
    create index(:runner_replacements, [:original_runner_id])
    create index(:runner_replacements, [:replacement_runner_id])
  end
end
