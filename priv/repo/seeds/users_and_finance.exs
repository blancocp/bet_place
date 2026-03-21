alias BetPlace.{Accounts, Finance, Repo}
alias BetPlace.Accounts.User
alias BetPlace.Finance.PaymentMethod
import Ecto.Query

common_password = "12345678"
initial_balance = Decimal.new("1000.00")

users_data = [
  %{
    email: "admin@betplace.local",
    username: "admin",
    role: :admin,
    profile: %{
      first_name: "Carlos",
      last_name: "Blanco",
      birth_date: ~D[1990-01-15],
      identity_document: "12074023",
      address: "Av Principal, Caracas",
      phone_number: "04124993391"
    }
  },
  %{
    email: "bettor1@betplace.local",
    username: "juan.perez",
    role: :bettor,
    profile: %{
      first_name: "Juan",
      last_name: "Perez",
      birth_date: ~D[1992-03-08],
      identity_document: "24567890",
      address: "Av Libertador, Caracas",
      phone_number: "04141234567"
    }
  },
  %{
    email: "bettor2@betplace.local",
    username: "maria.gomez",
    role: :bettor,
    profile: %{
      first_name: "Maria",
      last_name: "Gomez",
      birth_date: ~D[1995-07-21],
      identity_document: "27890123",
      address: "Av Sucre, Valencia",
      phone_number: "04241234567"
    }
  }
]

ensure_identity_document_available = fn identity_document, user_id ->
  existing_user_id =
    from(u in User, where: u.identity_document == ^identity_document, select: u.id, limit: 1)
    |> Repo.one()

  if is_nil(existing_user_id) or existing_user_id == user_id do
    identity_document
  else
    generated =
      "99" <> String.pad_leading(Integer.to_string(:erlang.phash2(user_id, 9_999_999)), 7, "0")

    if generated == identity_document do
      "98" <>
        String.pad_leading(Integer.to_string(:erlang.phash2({user_id, "alt"}, 9_999_999)), 7, "0")
    else
      generated
    end
  end
end

ensure_user = fn data ->
  user =
    Accounts.get_user_by_email(data.email) ||
      case Accounts.create_user(%{
             email: data.email,
             username: data.username,
             password: common_password
           }) do
        {:ok, user} -> user
        {:error, changeset} -> raise "Error creating user #{data.email}: #{inspect(changeset.errors)}"
      end

  {:ok, user} = Accounts.update_user(user, %{role: data.role, status: :active})

  profile =
    Map.put(
      data.profile,
      :identity_document,
      ensure_identity_document_available.(data.profile.identity_document, user.id)
    )

  {:ok, user} = Accounts.update_user_profile(user, profile)

  {:ok, user} =
    user
    |> User.balance_changeset(%{balance: initial_balance})
    |> Repo.update()

  user
end

[admin, bettor1, bettor2] = Enum.map(users_data, ensure_user)

upsert_payment_method = fn attrs ->
  account_number = Map.get(attrs, :account_number)
  phone_number = Map.get(attrs, :phone_number)
  user_id = Map.get(attrs, :user_id)

  base_query =
    from(pm in PaymentMethod,
      where:
        pm.owner_type == ^attrs.owner_type and pm.type == ^attrs.type and pm.bank_code == ^attrs.bank_code
    )

  base_query =
    if is_nil(user_id),
      do: from(pm in base_query, where: is_nil(pm.user_id)),
      else: from(pm in base_query, where: pm.user_id == ^user_id)

  base_query =
    if is_nil(account_number),
      do: from(pm in base_query, where: is_nil(pm.account_number)),
      else: from(pm in base_query, where: pm.account_number == ^account_number)

  base_query =
    if is_nil(phone_number),
      do: from(pm in base_query, where: is_nil(pm.phone_number)),
      else: from(pm in base_query, where: pm.phone_number == ^phone_number)

  existing = Repo.one(base_query)

  if existing do
    {:ok, existing}
  else
    Finance.create_payment_method(attrs)
  end
end

# User methods
upsert_payment_method.(%{
  owner_type: :user,
  user_id: admin.id,
  type: :mobile_payment,
  bank_code: "0102",
  holder_identity_document: admin.identity_document,
  phone_number: "04124993391",
  label: "Pago movil admin"
})

upsert_payment_method.(%{
  owner_type: :user,
  user_id: bettor1.id,
  type: :bank_account,
  bank_code: "0134",
  holder_identity_document: bettor1.identity_document,
  account_number: "01340000000000000001",
  label: "Cuenta Juan"
})

upsert_payment_method.(%{
  owner_type: :user,
  user_id: bettor2.id,
  type: :mobile_payment,
  bank_code: "0105",
  holder_identity_document: bettor2.identity_document,
  phone_number: "04241234567",
  label: "Pago movil Maria"
})

# System methods
upsert_payment_method.(%{
  owner_type: :system,
  type: :bank_account,
  bank_code: "0102",
  holder_identity_document: admin.identity_document,
  account_number: "01020000000000000099",
  label: "Cuenta cobros sistema"
})

upsert_payment_method.(%{
  owner_type: :system,
  type: :mobile_payment,
  bank_code: "0102",
  holder_identity_document: admin.identity_document,
  phone_number: "04124993391",
  label: "Pago movil cobros sistema"
})

IO.puts("Users and finance seed loaded (admin + 2 bettors, password 12345678)")
