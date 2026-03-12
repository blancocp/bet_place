defmodule BetPlace.Accounts.User do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "users" do
    field :email, :string
    field :username, :string
    field :password_hash, :string
    field :password, :string, virtual: true, redact: true
    field :role, Ecto.Enum, values: [:admin, :bettor], default: :bettor
    field :balance, :decimal, default: Decimal.new("0.00")
    field :status, Ecto.Enum, values: [:active, :suspended, :banned], default: :active
    field :confirmed_at, :utc_datetime
    field :last_login_at, :utc_datetime

    has_many :polla_tickets, BetPlace.Betting.PollaTicket
    has_many :hvh_bets, BetPlace.Betting.HvhBet
    has_many :transactions, BetPlace.Finance.Transaction

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(email username password)a
  @update_fields ~w(role status confirmed_at last_login_at)a

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "formato de correo inválido")
    |> validate_length(:username, min: 3, max: 30)
    |> validate_length(:password, min: 8)
    |> unique_constraint(:email)
    |> unique_constraint(:username)
    |> hash_password()
  end

  def update_changeset(user, attrs) do
    user
    |> cast(attrs, @update_fields)
    |> validate_required([])
  end

  def balance_changeset(user, attrs) do
    user
    |> cast(attrs, [:balance])
    |> validate_required([:balance])
    |> validate_number(:balance, greater_than_or_equal_to: Decimal.new("0"))
  end

  defp hash_password(%Ecto.Changeset{valid?: true, changes: %{password: password}} = changeset) do
    put_change(changeset, :password_hash, Bcrypt.hash_pwd_salt(password))
  end

  defp hash_password(changeset), do: changeset
end
