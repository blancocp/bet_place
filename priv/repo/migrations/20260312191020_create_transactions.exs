defmodule BetPlace.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false
      add :type, :string, null: false
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :direction, :string, null: false
      add :reference_type, :string
      add :reference_id, :binary_id
      add :balance_before, :decimal, precision: 15, scale: 2, null: false
      add :balance_after, :decimal, precision: 15, scale: 2, null: false
      add :status, :string, null: false, default: "pending"
      add :description, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:transactions, [:user_id])
    create index(:transactions, [:type])
    create index(:transactions, [:reference_type, :reference_id])
    create index(:transactions, [:inserted_at])
  end
end
