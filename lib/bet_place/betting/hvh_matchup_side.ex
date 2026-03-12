defmodule BetPlace.Betting.HvhMatchupSide do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "hvh_matchup_sides" do
    field :side, Ecto.Enum, values: [:a, :b]

    belongs_to :hvh_matchup, BetPlace.Betting.HvhMatchup
    belongs_to :runner, BetPlace.Racing.Runner

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required_fields ~w(hvh_matchup_id side runner_id)a

  def changeset(side, attrs) do
    side
    |> cast(attrs, @required_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:hvh_matchup_id)
    |> foreign_key_constraint(:runner_id)
  end
end
