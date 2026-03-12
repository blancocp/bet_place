defmodule BetPlace.Repo do
  use Ecto.Repo,
    otp_app: :bet_place,
    adapter: Ecto.Adapters.Postgres
end
