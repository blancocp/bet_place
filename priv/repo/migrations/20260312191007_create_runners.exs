defmodule BetPlace.Repo.Migrations.CreateRunners do
  use Ecto.Migration

  def change do
    create table(:runners, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :race_id, references(:races, type: :binary_id, on_delete: :restrict), null: false
      add :horse_id, references(:horses, type: :binary_id, on_delete: :restrict), null: false
      add :jockey_id, references(:jockeys, type: :binary_id, on_delete: :restrict)
      add :trainer_id, references(:trainers, type: :binary_id, on_delete: :restrict)
      add :program_number, :integer, null: false
      add :weight, :string
      add :form, :string
      add :morning_line, :decimal, precision: 15, scale: 2
      add :non_runner, :boolean, null: false, default: false
      add :position, :integer
      add :distance_beaten, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:runners, [:race_id, :horse_id])
    create unique_index(:runners, [:race_id, :program_number])
    create index(:runners, [:race_id])
    create index(:runners, [:horse_id])
    create index(:runners, [:jockey_id])
    create index(:runners, [:trainer_id])
  end
end
