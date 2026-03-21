defmodule BetPlace.Betting.HvhMatchup do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "hvh_matchups" do
    field :status, Ecto.Enum,
      values: [:open, :closed, :finished, :void],
      default: :open

    field :result_side, Ecto.Enum, values: [:side_a, :side_b, :void]
    field :total_side_a, :decimal, default: Decimal.new("0.00")
    field :total_side_b, :decimal, default: Decimal.new("0.00")
    field :total_pool, :decimal, default: Decimal.new("0.00")
    field :void_reason, :string
    field :resolved_at, :utc_datetime
    field :payout_pct, :decimal, default: Decimal.new("80.00")
    field :settlement_source, Ecto.Enum, values: [:auto_sync, :manual_admin]
    field :settled_at, :utc_datetime

    belongs_to :game_event, BetPlace.Games.GameEvent
    belongs_to :race, BetPlace.Racing.Race
    belongs_to :creator, BetPlace.Accounts.User, foreign_key: :created_by
    belongs_to :settled_by_user, BetPlace.Accounts.User

    has_many :hvh_matchup_sides, BetPlace.Betting.HvhMatchupSide
    has_many :hvh_bets, BetPlace.Betting.HvhBet

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(game_event_id race_id created_by)a
  @optional_fields ~w(status result_side total_side_a total_side_b total_pool void_reason resolved_at payout_pct settlement_source settled_at settled_by_user_id)a

  def changeset(matchup, attrs) do
    matchup
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:game_event_id)
    |> foreign_key_constraint(:race_id)
    |> foreign_key_constraint(:created_by)
  end

  def result_changeset(matchup, attrs) do
    matchup
    |> cast(attrs, [
      :status,
      :result_side,
      :total_side_a,
      :total_side_b,
      :total_pool,
      :void_reason,
      :resolved_at,
      :payout_pct,
      :settlement_source,
      :settled_at,
      :settled_by_user_id
    ])
    |> validate_number(:payout_pct, greater_than: Decimal.new("0"))
  end
end
