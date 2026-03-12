defmodule BetPlace.Betting.PollaTicket do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "polla_tickets" do
    field :combination_count, :integer
    field :ticket_value, :decimal
    field :total_paid, :decimal
    field :total_points, :integer
    field :rank, :integer

    field :status, Ecto.Enum,
      values: [:active, :winner, :loser, :refunded],
      default: :active

    field :sealed_at, :utc_datetime

    belongs_to :game_event, BetPlace.Games.GameEvent
    belongs_to :user, BetPlace.Accounts.User

    has_many :polla_selections, BetPlace.Betting.PollaSelection
    has_many :polla_combinations, BetPlace.Betting.PollaCombination

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(game_event_id user_id combination_count ticket_value total_paid sealed_at)a
  @optional_fields ~w(total_points rank status)a

  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> validate_number(:combination_count, greater_than: 0)
    |> validate_number(:total_paid, greater_than: Decimal.new("0"))
    |> foreign_key_constraint(:game_event_id)
    |> foreign_key_constraint(:user_id)
  end

  def result_changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:total_points, :rank, :status])
  end
end
