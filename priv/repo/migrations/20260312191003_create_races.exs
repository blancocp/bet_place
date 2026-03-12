defmodule BetPlace.Repo.Migrations.CreateRaces do
  use Ecto.Migration

  def change do
    create table(:races, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :external_id, :string, null: false
      add :course_id, references(:courses, type: :binary_id, on_delete: :restrict), null: false
      add :race_date, :date, null: false
      add :post_time, :utc_datetime
      add :distance_raw, :string
      add :distance_meters, :integer
      add :age_restriction, :string
      add :status, :string, null: false, default: "scheduled"
      add :finished, :boolean, null: false, default: false
      add :canceled, :boolean, null: false, default: false
      add :synced_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:races, [:external_id])
    create index(:races, [:course_id])
    create index(:races, [:race_date])
    create index(:races, [:status])
  end
end
