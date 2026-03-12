defmodule BetPlace.Games.GameEvent do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "game_events" do
    field :name, :string

    field :status, Ecto.Enum,
      values: [:draft, :open, :closed, :processing, :finished, :canceled],
      default: :draft

    field :betting_closes_at, :utc_datetime
    field :total_pool, :decimal, default: Decimal.new("0.00")
    field :house_amount, :decimal, default: Decimal.new("0.00")
    field :prize_pool, :decimal, default: Decimal.new("0.00")
    field :canceled_reason, :string

    belongs_to :game_type, BetPlace.Games.GameType
    belongs_to :game_config, BetPlace.Games.GameConfig
    belongs_to :course, BetPlace.Racing.Course
    belongs_to :creator, BetPlace.Accounts.User, foreign_key: :created_by

    has_many :game_event_races, BetPlace.Games.GameEventRace
    has_many :polla_tickets, BetPlace.Betting.PollaTicket
    has_many :hvh_matchups, BetPlace.Betting.HvhMatchup

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(game_type_id game_config_id course_id created_by name)a
  @optional_fields ~w(status betting_closes_at total_pool house_amount prize_pool canceled_reason)a

  def changeset(event, attrs) do
    event
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:game_type_id)
    |> foreign_key_constraint(:game_config_id)
    |> foreign_key_constraint(:course_id)
    |> foreign_key_constraint(:created_by)
  end

  def status_changeset(event, status) do
    event
    |> cast(%{status: status}, [:status])
    |> validate_required([:status])
  end

  def pool_changeset(event, attrs) do
    event
    |> cast(attrs, [:total_pool, :house_amount, :prize_pool])
  end
end
