defmodule BetPlace.Finance.PaymentReport do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "payment_reports" do
    field :channel, Ecto.Enum, values: [:bank_transfer, :mobile_payment]
    field :amount, :decimal
    field :payer_identity_document, :string
    field :payer_phone_number, :string
    field :reference_number, :string
    field :reported_at, :utc_datetime
    field :status, Ecto.Enum, values: [:pending, :approved, :rejected], default: :pending
    field :review_note, :string
    field :approved_amount, :decimal

    belongs_to :user, BetPlace.Accounts.User
    belongs_to :payment_method, BetPlace.Finance.PaymentMethod
    belongs_to :reviewed_by_user, BetPlace.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(user_id payment_method_id channel amount payer_identity_document reference_number reported_at)a
  @optional_fields ~w(payer_phone_number status review_note reviewed_by_user_id approved_amount)a

  def create_changeset(payment_report, attrs, opts \\ []) do
    expected_channel = Keyword.get(opts, :expected_channel)

    payment_report
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:amount, greater_than: Decimal.new("0"))
    |> validate_format(:payer_identity_document, ~r/^[0-9]{6,12}$/,
      message: "la cédula debe contener solo números"
    )
    |> validate_length(:reference_number, min: 4, max: 60)
    |> validate_expected_channel(expected_channel)
    |> unique_constraint(:reference_number)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:payment_method_id)
  end

  def review_changeset(payment_report, attrs) do
    payment_report
    |> cast(attrs, [:status, :review_note, :approved_amount, :reviewed_by_user_id])
    |> validate_required([:status, :reviewed_by_user_id])
    |> validate_review()
    |> foreign_key_constraint(:reviewed_by_user_id)
  end

  defp validate_review(changeset) do
    case get_field(changeset, :status) do
      :approved ->
        changeset
        |> validate_required([:approved_amount])
        |> validate_number(:approved_amount, greater_than: Decimal.new("0"))
        |> put_change(:review_note, nil)

      :rejected ->
        changeset
        |> validate_required([:review_note])
        |> validate_length(:review_note, min: 5, max: 255)
        |> put_change(:approved_amount, nil)

      _ ->
        changeset
    end
  end

  defp validate_expected_channel(changeset, nil), do: changeset

  defp validate_expected_channel(changeset, expected_channel) do
    validate_change(changeset, :channel, fn :channel, channel ->
      if channel == expected_channel,
        do: [],
        else: [channel: "canal inválido para el método seleccionado"]
    end)
  end
end
