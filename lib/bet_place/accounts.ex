defmodule BetPlace.Accounts do
  @moduledoc "Context for user accounts, authentication, and session tokens."

  import Ecto.Query
  alias BetPlace.Repo
  alias BetPlace.Accounts.{User, UserToken, Scope}

  def list_users do
    Repo.all(User)
  end

  def get_user(id), do: Repo.get(User, id)
  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email) when is_binary(email) do
    Repo.get_by(User, email: String.downcase(email))
  end

  def get_user_by_username(username) when is_binary(username) do
    Repo.get_by(User, username: username)
  end

  def create_user(attrs) do
    %User{}
    |> User.registration_changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.update_changeset(attrs)
    |> Repo.update()
  end

  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      user && user.status == :active && Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}

      user && user.status != :active ->
        {:error, :account_inactive}

      true ->
        Bcrypt.no_user_verify()
        {:error, :invalid_credentials}
    end
  end

  def active_users do
    User
    |> where([u], u.status == :active)
    |> Repo.all()
  end

  # ── Registration changeset (for LiveView forms) ───────────────────────────

  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  # ── Session tokens ────────────────────────────────────────────────────────

  def create_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  def get_user_by_session_token(token) do
    Repo.one(UserToken.verify_session_token_query(token))
  end

  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.token_and_context_query(token, "session"))
    :ok
  end

  # ── Scope ─────────────────────────────────────────────────────────────────

  def build_scope(%User{} = user), do: Scope.for_user(user)
end
