defmodule BetPlace.Repo.Migrations.CreateUsers do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :username, :string, null: false
      add :password_hash, :string, null: false
      add :role, :string, null: false, default: "bettor"
      add :balance, :decimal, precision: 15, scale: 2, null: false, default: 0
      add :status, :string, null: false, default: "active"
      add :confirmed_at, :utc_datetime
      add :last_login_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create unique_index(:users, [:email])
    create unique_index(:users, [:username])
  end
end
