defmodule BetPlace.Games.GameType do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "game_types" do
    field :code, Ecto.Enum, values: [:polla, :horse_vs_horse]
    field :name, :string
    field :description, :string
    field :active, :boolean, default: true

    has_many :game_configs, BetPlace.Games.GameConfig
    has_many :game_events, BetPlace.Games.GameEvent

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @fields ~w(code name description active)a

  def changeset(game_type, attrs) do
    game_type
    |> cast(attrs, @fields)
    |> validate_required(~w(code name)a)
    |> unique_constraint(:code)
  end
end
