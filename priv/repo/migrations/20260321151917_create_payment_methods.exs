defmodule BetPlace.Repo.Migrations.CreatePaymentMethods do
  use Ecto.Migration

  def change do
    create table(:payment_methods, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :owner_type, :string, null: false
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all)
      add :type, :string, null: false
      add :bank_code, :string, null: false
      add :holder_identity_document, :string, null: false
      add :account_number, :string
      add :phone_number, :string
      add :label, :string
      add :active, :boolean, null: false, default: true

      timestamps(type: :utc_datetime)
    end

    create index(:payment_methods, [:user_id])
    create index(:payment_methods, [:owner_type])
    create index(:payment_methods, [:type])

    create constraint(:payment_methods, :owner_type_must_be_valid,
             check: "owner_type IN ('user', 'system')"
           )

    create constraint(:payment_methods, :type_must_be_valid,
             check: "type IN ('bank_account', 'mobile_payment')"
           )

    create constraint(:payment_methods, :user_owner_requires_user_id,
             check:
               "(owner_type = 'user' AND user_id IS NOT NULL) OR (owner_type = 'system' AND user_id IS NULL)"
           )

    create constraint(:payment_methods, :bank_account_number_valid,
             check:
               "(type <> 'bank_account') OR (account_number IS NOT NULL AND account_number ~ '^[0-9]{20}$')"
           )

    create constraint(:payment_methods, :mobile_phone_valid,
             check:
               "(type <> 'mobile_payment') OR (phone_number IS NOT NULL AND phone_number ~ '^(0412|0414|0416|0422|0424|0426)[0-9]{7}$')"
           )
  end
end
