defmodule BetPlace.Betting.PollaSelection do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "polla_selections" do
    field :was_replaced, :boolean, default: false
    field :points_earned, :integer, default: 0

    belongs_to :polla_ticket, BetPlace.Betting.PollaTicket
    belongs_to :game_event_race, BetPlace.Games.GameEventRace
    belongs_to :runner, BetPlace.Racing.Runner, foreign_key: :runner_id
    belongs_to :effective_runner, BetPlace.Racing.Runner, foreign_key: :effective_runner_id

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required_fields ~w(polla_ticket_id game_event_race_id runner_id effective_runner_id)a

  def changeset(selection, attrs) do
    selection
    |> cast(attrs, @required_fields ++ [:was_replaced, :points_earned])
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:polla_ticket_id)
    |> foreign_key_constraint(:game_event_race_id)
    |> foreign_key_constraint(:runner_id)
    |> foreign_key_constraint(:effective_runner_id)
  end

  def score_changeset(selection, points) do
    selection
    |> cast(%{points_earned: points}, [:points_earned])
  end

  def replacement_changeset(selection, replacement_runner_id) do
    selection
    |> cast(
      %{effective_runner_id: replacement_runner_id, was_replaced: true},
      [:effective_runner_id, :was_replaced]
    )
  end
end
