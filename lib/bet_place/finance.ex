defmodule BetPlace.Finance do
  @moduledoc "Context for financial transactions and balance management."

  import Ecto.Query
  alias BetPlace.Repo
  alias BetPlace.Finance.Transaction

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
end
