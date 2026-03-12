defmodule BetPlace.Accounts.UserToken do
  use BetPlace.Schema
  import Ecto.Query

  @rand_size 32
  @session_validity_in_days 60

  schema "user_tokens" do
    field :token, :binary
    field :context, :string

    belongs_to :user, BetPlace.Accounts.User

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @doc "Builds a session token for a user. Returns {raw_token, %UserToken{}}."
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %BetPlace.Accounts.UserToken{token: token, context: "session", user_id: user.id}}
  end

  @doc "Query to verify a session token and return the associated user."
  def verify_session_token_query(token) do
    from t in BetPlace.Accounts.UserToken,
      join: user in assoc(t, :user),
      where: t.token == ^token and t.context == "session",
      where: t.inserted_at > ago(@session_validity_in_days, "day"),
      select: user
  end

  @doc "Query for a token by value and context."
  def token_and_context_query(token, context) do
    from BetPlace.Accounts.UserToken, where: [token: ^token, context: ^context]
  end
end
