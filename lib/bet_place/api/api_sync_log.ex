defmodule BetPlace.Api.ApiSyncLog do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "api_sync_logs" do
    field :endpoint, Ecto.Enum, values: [:racecards, :race, :results]
    field :external_ref, :string
    field :status, Ecto.Enum, values: [:ok, :error]
    field :response_hash, :string
    field :error_message, :string
    field :synced_at, :utc_datetime

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required_fields ~w(endpoint status synced_at)a
  @optional_fields ~w(external_ref response_hash error_message)a

  def changeset(log, attrs) do
    log
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end
end
