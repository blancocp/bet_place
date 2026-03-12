defmodule BetPlace.Racing.Race do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "races" do
    field :external_id, :string
    field :race_date, :date
    field :post_time, :utc_datetime
    field :distance_raw, :string
    field :distance_meters, :integer
    field :age_restriction, :string

    field :status, Ecto.Enum,
      values: [:scheduled, :open, :closed, :finished, :canceled],
      default: :scheduled

    field :finished, :boolean, default: false
    field :canceled, :boolean, default: false
    field :synced_at, :utc_datetime

    belongs_to :course, BetPlace.Racing.Course

    has_many :runners, BetPlace.Racing.Runner
    has_many :game_event_races, BetPlace.Games.GameEventRace
    has_many :hvh_matchups, BetPlace.Betting.HvhMatchup

    timestamps(type: :utc_datetime)
  end

  @fields ~w(external_id course_id race_date post_time distance_raw distance_meters
             age_restriction status finished canceled synced_at)a

  def changeset(race, attrs) do
    race
    |> cast(attrs, @fields)
    |> validate_required(~w(external_id course_id race_date)a)
    |> unique_constraint(:external_id)
    |> foreign_key_constraint(:course_id)
  end
end
