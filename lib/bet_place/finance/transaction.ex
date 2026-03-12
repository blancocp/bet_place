defmodule BetPlace.Finance.Transaction do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "transactions" do
    field :type, Ecto.Enum, values: [:deposit, :withdrawal, :bet, :payout, :refund]
    field :amount, :decimal
    field :direction, Ecto.Enum, values: [:credit, :debit]
    field :reference_type, :string
    field :reference_id, :binary_id
    field :balance_before, :decimal
    field :balance_after, :decimal
    field :status, Ecto.Enum, values: [:pending, :completed, :failed], default: :pending
    field :description, :string

    belongs_to :user, BetPlace.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required_fields ~w(user_id type amount direction balance_before balance_after)a
  @optional_fields ~w(reference_type reference_id status description)a

  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:amount, greater_than: Decimal.new("0"))
    |> foreign_key_constraint(:user_id)
  end
end
