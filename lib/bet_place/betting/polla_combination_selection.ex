defmodule BetPlace.Betting.PollaCombinationSelection do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "polla_combination_selections" do
    belongs_to :polla_combination, BetPlace.Betting.PollaCombination
    belongs_to :game_event_race, BetPlace.Games.GameEventRace
    belongs_to :runner, BetPlace.Racing.Runner

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required_fields ~w(polla_combination_id game_event_race_id runner_id)a

  def changeset(record, attrs) do
    record
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:polla_combination_id)
    |> foreign_key_constraint(:game_event_race_id)
    |> foreign_key_constraint(:runner_id)
    |> unique_constraint([:polla_combination_id, :game_event_race_id])
  end
end
