defmodule BetPlace.Accounts.Scope do
  @moduledoc "Represents the current authenticated scope (user + role)."

  alias BetPlace.Accounts.User

  @enforce_keys [:user]
  defstruct [:user]

  @doc "Builds a scope for an authenticated user."
  def for_user(%User{} = user), do: %__MODULE__{user: user}

  @doc "Returns true if the scope belongs to an admin."
  def admin?(%__MODULE__{user: %User{role: :admin}}), do: true
  def admin?(_), do: false
end
