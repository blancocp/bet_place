defmodule BetPlace.Repo.Migrations.AddPersonalProfileFieldsToUsers do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :first_name, :string
      add :last_name, :string
      add :birth_date, :date
      add :identity_document, :string
      add :address, :string
      add :phone_number, :string
    end

    create unique_index(:users, [:identity_document])
  end
end
