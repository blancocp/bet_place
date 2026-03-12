defmodule BetPlace.Racing.Runner do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "runners" do
    field :program_number, :integer
    field :weight, :string
    field :form, :string
    field :morning_line, :decimal
    field :non_runner, :boolean, default: false
    field :position, :integer
    field :distance_beaten, :string

    belongs_to :race, BetPlace.Racing.Race
    belongs_to :horse, BetPlace.Racing.Horse
    belongs_to :jockey, BetPlace.Racing.Jockey
    belongs_to :trainer, BetPlace.Racing.Trainer

    has_many :polla_selections, BetPlace.Betting.PollaSelection, foreign_key: :runner_id

    has_many :effective_polla_selections, BetPlace.Betting.PollaSelection,
      foreign_key: :effective_runner_id

    has_many :hvh_matchup_sides, BetPlace.Betting.HvhMatchupSide

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(race_id horse_id program_number)a
  @optional_fields ~w(jockey_id trainer_id weight form morning_line non_runner position distance_beaten)a

  def changeset(runner, attrs) do
    runner
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
    |> unique_constraint([:race_id, :horse_id])
    |> unique_constraint([:race_id, :program_number])
    |> foreign_key_constraint(:race_id)
    |> foreign_key_constraint(:horse_id)
    |> foreign_key_constraint(:jockey_id)
    |> foreign_key_constraint(:trainer_id)
  end

  def result_changeset(runner, attrs) do
    runner
    |> cast(attrs, [:position, :distance_beaten, :non_runner, :status])
  end
end
