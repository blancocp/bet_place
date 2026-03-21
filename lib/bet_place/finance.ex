defmodule BetPlace.Finance do
  @moduledoc "Context for financial transactions and balance management."

  import Ecto.Query
  alias Ecto.Multi
  alias BetPlace.Accounts
  alias BetPlace.Accounts.User
  alias BetPlace.Repo
  alias BetPlace.Finance.{Transaction, PaymentMethod, PaymentReport}

  def list_transactions_for_user(user_id) do
    Transaction
    |> where([t], t.user_id == ^user_id)
    |> order_by([t], desc: t.inserted_at)
    |> Repo.all()
  end

  def get_transaction!(id), do: Repo.get!(Transaction, id)

  def create_transaction(attrs) do
    %Transaction{} |> Transaction.changeset(attrs) |> Repo.insert()
  end

  def list_user_payment_methods(user_id) do
    PaymentMethod
    |> where([pm], pm.owner_type == :user and pm.user_id == ^user_id and pm.active == true)
    |> order_by([pm], desc: pm.inserted_at)
    |> Repo.all()
  end

  def list_system_payment_methods do
    PaymentMethod
    |> join(:left, [pm], u in User, on: pm.user_id == u.id)
    |> where(
      [pm, u],
      pm.active == true and
        (pm.owner_type == :system or
           (pm.owner_type == :user and not is_nil(u.id) and u.role == :admin))
    )
    |> order_by([pm], asc: pm.bank_code, asc: pm.type)
    |> Repo.all()
  end

  def get_payment_method!(id), do: Repo.get!(PaymentMethod, id)

  def create_payment_method(attrs) do
    %PaymentMethod{}
    |> PaymentMethod.changeset(attrs)
    |> validate_holder_matches_user()
    |> Repo.insert()
  end

  def update_payment_method(%PaymentMethod{} = method, attrs) do
    method
    |> PaymentMethod.changeset(attrs)
    |> validate_holder_matches_user()
    |> Repo.update()
  end

  def change_payment_method(%PaymentMethod{} = method, attrs \\ %{}) do
    PaymentMethod.changeset(method, attrs)
  end

  def list_payment_reports(status \\ nil) do
    query =
      PaymentReport
      |> preload([:user, :payment_method, :reviewed_by_user])
      |> order_by([pr], desc: pr.inserted_at)

    query =
      if is_nil(status), do: query, else: where(query, [pr], pr.status == ^status)

    Repo.all(query)
  end

  def list_payment_reports_for_user(user_id) do
    PaymentReport
    |> where([pr], pr.user_id == ^user_id)
    |> preload([:payment_method, :reviewed_by_user])
    |> order_by([pr], desc: pr.inserted_at)
    |> Repo.all()
  end

  def create_payment_report(attrs) do
    attrs = attrs |> Map.new() |> stringify_keys()
    reported_at = DateTime.utc_now() |> DateTime.truncate(:second)
    payment_method_id = fetch_attr(attrs, :payment_method_id)

    with payment_method_id when is_binary(payment_method_id) <- payment_method_id,
         %PaymentMethod{} = method <- get_allowed_payment_method(payment_method_id) do
      forced_channel =
        if method.type == :mobile_payment, do: "mobile_payment", else: "bank_transfer"

      attrs =
        attrs
        |> Map.put("channel", forced_channel)
        |> Map.put_new("reported_at", reported_at)

      expected_channel =
        case forced_channel do
          "mobile_payment" -> :mobile_payment
          _ -> :bank_transfer
        end

      %PaymentReport{}
      |> PaymentReport.create_changeset(attrs, expected_channel: expected_channel)
      |> Repo.insert()
      |> case do
        {:ok, report} ->
          Phoenix.PubSub.broadcast(
            BetPlace.PubSub,
            "admin:payment_reports",
            {:payment_report_created, report.id}
          )

          {:ok, report}

        error ->
          error
      end
    else
      _ ->
        changeset =
          %PaymentReport{}
          |> PaymentReport.create_changeset(%{
            "user_id" => fetch_attr(attrs, :user_id),
            "payment_method_id" => payment_method_id,
            "channel" => fetch_attr(attrs, :channel) || "bank_transfer",
            "amount" => fetch_attr(attrs, :amount) || "0",
            "payer_identity_document" => fetch_attr(attrs, :payer_identity_document) || "0",
            "reference_number" => fetch_attr(attrs, :reference_number) || "tmp",
            "reported_at" => fetch_attr(attrs, :reported_at) || reported_at
          })
          |> Ecto.Changeset.add_error(:payment_method_id, "método de pago inválido")

        {:error, changeset}
    end
  end

  def change_payment_report(%PaymentReport{} = report, attrs \\ %{}) do
    PaymentReport.create_changeset(report, attrs)
  end

  def approve_payment_report(report_id, admin_user_id, approved_amount, note \\ nil) do
    report =
      PaymentReport
      |> Repo.get!(report_id)
      |> Repo.preload([:user])

    amount = approved_amount
    before_balance = report.user.balance
    after_balance = Decimal.add(before_balance, amount)

    Multi.new()
    |> Multi.update(
      :report,
      PaymentReport.review_changeset(report, %{
        status: :approved,
        reviewed_by_user_id: admin_user_id,
        approved_amount: amount,
        review_note: note
      })
    )
    |> Multi.update(:user, User.balance_changeset(report.user, %{balance: after_balance}))
    |> Multi.insert(
      :transaction,
      Transaction.changeset(%Transaction{}, %{
        user_id: report.user_id,
        type: :deposit,
        amount: amount,
        direction: :credit,
        reference_type: "payment_report",
        reference_id: report.id,
        balance_before: before_balance,
        balance_after: after_balance,
        status: :completed,
        description: "Recarga aprobada por admin"
      })
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{user: user, report: report} = results} ->
        Phoenix.PubSub.broadcast(
          BetPlace.PubSub,
          "user:#{user.id}",
          {:balance_updated, user.balance}
        )

        Phoenix.PubSub.broadcast(
          BetPlace.PubSub,
          "user:#{user.id}",
          {:payment_report_reviewed, report.id, :approved}
        )

        Phoenix.PubSub.broadcast(
          BetPlace.PubSub,
          "admin:payment_reports",
          {:payment_report_reviewed, report.id, :approved}
        )

        {:ok, results}

      error ->
        error
    end
  end

  def reject_payment_report(report_id, admin_user_id, reason) do
    report = Repo.get!(PaymentReport, report_id)

    report
    |> PaymentReport.review_changeset(%{
      status: :rejected,
      reviewed_by_user_id: admin_user_id,
      review_note: reason
    })
    |> Repo.update()
    |> case do
      {:ok, reviewed_report} ->
        Phoenix.PubSub.broadcast(
          BetPlace.PubSub,
          "user:#{reviewed_report.user_id}",
          {:payment_report_reviewed, reviewed_report.id, :rejected}
        )

        Phoenix.PubSub.broadcast(
          BetPlace.PubSub,
          "admin:payment_reports",
          {:payment_report_reviewed, reviewed_report.id, :rejected}
        )

        {:ok, reviewed_report}

      error ->
        error
    end
  end

  def apply_manual_balance_adjustment(user_id, admin_user_id, amount, description) do
    user = Repo.get!(User, user_id)
    before_balance = user.balance
    after_balance = Decimal.add(before_balance, amount)
    direction = if Decimal.compare(amount, Decimal.new("0")) == :lt, do: :debit, else: :credit

    Multi.new()
    |> Multi.update(:user, User.balance_changeset(user, %{balance: after_balance}))
    |> Multi.insert(
      :transaction,
      Transaction.changeset(%Transaction{}, %{
        user_id: user.id,
        type: :manual_adjustment,
        amount: Decimal.abs(amount),
        direction: direction,
        reference_type: "admin_user",
        reference_id: admin_user_id,
        balance_before: before_balance,
        balance_after: after_balance,
        status: :completed,
        description: description
      })
    )
    |> Repo.transaction()
    |> case do
      {:ok, %{user: updated_user} = results} ->
        Phoenix.PubSub.broadcast(
          BetPlace.PubSub,
          "user:#{updated_user.id}",
          {:balance_updated, updated_user.balance}
        )

        Phoenix.PubSub.broadcast(
          BetPlace.PubSub,
          "admin:payment_reports",
          {:manual_balance_adjusted, updated_user.id}
        )

        {:ok, results}

      error ->
        error
    end
  end

  def bank_options do
    [
      {"0102 - BANCO DE VENEZUELA", "0102"},
      {"0104 - BANCO VENEZOLANO DE CREDITO", "0104"},
      {"0105 - BANCO MERCANTIL", "0105"},
      {"0108 - BBVA PROVINCIAL", "0108"},
      {"0114 - BANCARIBE", "0114"},
      {"0115 - BANCO EXTERIOR", "0115"},
      {"0128 - BANCO CARONI", "0128"},
      {"0134 - BANESCO", "0134"},
      {"0137 - BANCO SOFITASA", "0137"},
      {"0138 - BANCO PLAZA", "0138"},
      {"0146 - BANGENTE", "0146"},
      {"0151 - BANCO FONDO COMUN", "0151"},
      {"0156 - 100% BANCO", "0156"},
      {"0157 - DELSUR BANCO UNIVERSAL", "0157"},
      {"0163 - BANCO DEL TESORO", "0163"},
      {"0168 - BANCRECER", "0168"},
      {"0169 - R4 BANCO MICROFINANCIERO C.A.", "0169"},
      {"0171 - BANCO ACTIVO", "0171"},
      {"0172 - BANCAMIGA BANCO UNIVERSAL, C.A.", "0172"},
      {"0173 - BANCO INTERNACIONAL DE DESARROLLO", "0173"},
      {"0174 - BANPLUS", "0174"},
      {"0175 - BANCO DIGITAL DE LOS TRABAJADORES, BANCO UNIVERSAL", "0175"},
      {"0177 - BANFANB", "0177"},
      {"0178 - N58 BANCO DIGITAL BANCO MICROFINANCIERO S A", "0178"},
      {"0191 - BANCO NACIONAL DE CREDITO", "0191"}
    ]
  end

  defp validate_holder_matches_user(%Ecto.Changeset{} = changeset) do
    owner_type = Ecto.Changeset.get_field(changeset, :owner_type)
    user_id = Ecto.Changeset.get_field(changeset, :user_id)
    holder = Ecto.Changeset.get_field(changeset, :holder_identity_document)

    if owner_type == :user and not is_nil(user_id) do
      case Repo.get(User, user_id) do
        %User{identity_document: id_doc} when is_binary(id_doc) and id_doc == holder ->
          changeset

        %User{} ->
          Ecto.Changeset.add_error(
            changeset,
            :holder_identity_document,
            "debe coincidir con tu cédula"
          )

        nil ->
          Ecto.Changeset.add_error(changeset, :user_id, "usuario inválido")
      end
    else
      changeset
    end
  end

  defp get_allowed_payment_method(id) do
    PaymentMethod
    |> join(:left, [pm], u in User, on: pm.user_id == u.id)
    |> where(
      [pm, u],
      pm.id == ^id and pm.active == true and
        (pm.owner_type == :system or
           (pm.owner_type == :user and not is_nil(u.id) and u.role == :admin))
    )
    |> Repo.one()
  end

  defp fetch_attr(attrs, key) do
    Map.get(attrs, key) || Map.get(attrs, Atom.to_string(key))
  end

  defp stringify_keys(attrs) do
    Map.new(attrs, fn
      {key, value} when is_atom(key) -> {Atom.to_string(key), value}
      {key, value} -> {key, value}
    end)
  end

  def refresh_user_scope(user_id) do
    user_id
    |> Accounts.get_user!()
    |> Accounts.build_scope()
  end
end
