defmodule BetPlace.Games.GameConfig do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "game_configs" do
    field :house_cut_pct, :decimal
    field :ticket_value, :decimal
    field :min_stake, :decimal
    field :prize_multiplier, :decimal
    field :max_horses_per_race, :integer
    field :active, :boolean, default: true

    belongs_to :game_type, BetPlace.Games.GameType

    has_many :game_events, BetPlace.Games.GameEvent

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(game_type_id house_cut_pct)a
  @optional_fields ~w(ticket_value min_stake prize_multiplier max_horses_per_race active)a

  def changeset(config, attrs) do
    config
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:house_cut_pct,
      greater_than: Decimal.new("0"),
      less_than: Decimal.new("1")
    )
    |> foreign_key_constraint(:game_type_id)
  end
end
