defmodule BetPlace.Repo.Migrations.CreatePaymentReports do
  use Ecto.Migration

  def change do
    create table(:payment_reports, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :restrict), null: false

      add :payment_method_id,
          references(:payment_methods, type: :binary_id, on_delete: :restrict), null: false

      add :channel, :string, null: false
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :payer_identity_document, :string, null: false
      add :payer_phone_number, :string
      add :reference_number, :string, null: false
      add :reported_at, :utc_datetime, null: false
      add :status, :string, null: false, default: "pending"
      add :review_note, :string
      add :reviewed_by_user_id, references(:users, type: :binary_id, on_delete: :restrict)
      add :approved_amount, :decimal, precision: 15, scale: 2

      timestamps(type: :utc_datetime)
    end

    create index(:payment_reports, [:user_id])
    create index(:payment_reports, [:payment_method_id])
    create index(:payment_reports, [:reviewed_by_user_id])
    create index(:payment_reports, [:status])
    create unique_index(:payment_reports, [:reference_number])

    create constraint(:payment_reports, :channel_must_be_valid,
             check: "channel IN ('bank_transfer', 'mobile_payment')"
           )

    create constraint(:payment_reports, :status_must_be_valid,
             check: "status IN ('pending', 'approved', 'rejected')"
           )
  end
end
