defmodule BetPlace.Betting.HvhBet do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "hvh_bets" do
    field :side_chosen, Ecto.Enum, values: [:a, :b]
    field :amount, :decimal
    field :potential_payout, :decimal
    field :actual_payout, :decimal

    field :status, Ecto.Enum,
      values: [:pending, :won, :lost, :void, :refunded],
      default: :pending

    field :placed_at, :utc_datetime

    belongs_to :hvh_matchup, BetPlace.Betting.HvhMatchup
    belongs_to :user, BetPlace.Accounts.User

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(hvh_matchup_id user_id side_chosen amount potential_payout placed_at)a
  @optional_fields ~w(actual_payout status)a

  def changeset(bet, attrs) do
    bet
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:amount, greater_than: Decimal.new("0"))
    |> foreign_key_constraint(:hvh_matchup_id)
    |> foreign_key_constraint(:user_id)
  end

  def result_changeset(bet, attrs) do
    bet
    |> cast(attrs, [:status, :actual_payout])
  end
end
