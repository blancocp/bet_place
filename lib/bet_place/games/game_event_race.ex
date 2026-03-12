defmodule BetPlace.Games.GameEventRace do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "game_event_races" do
    field :race_order, :integer

    field :status, Ecto.Enum,
      values: [:pending, :running, :finished, :canceled],
      default: :pending

    belongs_to :game_event, BetPlace.Games.GameEvent
    belongs_to :race, BetPlace.Racing.Race

    has_many :polla_selections, BetPlace.Betting.PollaSelection

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(game_event_id race_id race_order)a

  def changeset(event_race, attrs) do
    event_race
    |> cast(attrs, @required_fields ++ [:status])
    |> validate_required(@required_fields)
    |> validate_number(:race_order, greater_than_or_equal_to: 1, less_than_or_equal_to: 6)
    |> unique_constraint([:game_event_id, :race_order])
    |> unique_constraint([:game_event_id, :race_id])
    |> foreign_key_constraint(:game_event_id)
    |> foreign_key_constraint(:race_id)
  end

  def status_changeset(event_race, status) do
    event_race
    |> cast(%{status: status}, [:status])
    |> validate_required([:status])
  end
end
