defmodule BetPlace.Finance.PaymentMethod do
  use BetPlace.Schema
  import Ecto.Changeset

  @mobile_prefixes ~w(0412 0414 0416 0422 0424 0426)

  schema "payment_methods" do
    field :owner_type, Ecto.Enum, values: [:user, :system]
    field :type, Ecto.Enum, values: [:bank_account, :mobile_payment]
    field :bank_code, :string
    field :holder_identity_document, :string
    field :account_number, :string
    field :phone_number, :string
    field :label, :string
    field :active, :boolean, default: true

    belongs_to :user, BetPlace.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(owner_type type bank_code holder_identity_document)a
  @optional_fields ~w(user_id account_number phone_number label active)a

  def changeset(payment_method, attrs) do
    payment_method
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:bank_code, bank_codes())
    |> validate_format(:holder_identity_document, ~r/^[0-9]{6,12}$/,
      message: "la cédula debe contener solo números"
    )
    |> validate_owner()
    |> validate_by_type()
    |> foreign_key_constraint(:user_id)
  end

  def bank_codes do
    ~w(
      0102 0104 0105 0108 0114 0115 0128 0134 0137 0138 0146 0151 0156 0157 0163 0168 0169
      0171 0172 0173 0174 0175 0177 0178 0191
    )
  end

  defp validate_owner(changeset) do
    owner_type = get_field(changeset, :owner_type)
    user_id = get_field(changeset, :user_id)

    cond do
      owner_type == :user and is_nil(user_id) ->
        add_error(changeset, :user_id, "es obligatorio para métodos de usuario")

      owner_type == :system and not is_nil(user_id) ->
        add_error(changeset, :user_id, "debe estar vacío para métodos del sistema")

      true ->
        changeset
    end
  end

  defp validate_by_type(changeset) do
    case get_field(changeset, :type) do
      :bank_account ->
        changeset
        |> validate_required([:account_number])
        |> validate_format(:account_number, ~r/^[0-9]{20}$/, message: "debe tener 20 dígitos")
        |> put_change(:phone_number, nil)

      :mobile_payment ->
        changeset
        |> validate_required([:phone_number])
        |> validate_format(:phone_number, ~r/^[0-9]{11}$/, message: "debe tener 11 dígitos")
        |> validate_change(:phone_number, fn :phone_number, phone ->
          if String.starts_with?(phone, @mobile_prefixes) do
            []
          else
            [phone_number: "prefijo inválido"]
          end
        end)
        |> put_change(:account_number, nil)

      _ ->
        changeset
    end
  end
end
