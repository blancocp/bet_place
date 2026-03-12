defmodule BetPlace.Racing.Course do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "courses" do
    field :external_id, :string
    field :name, :string
    field :full_name, :string
    field :country, :string
    field :active, :boolean, default: true

    has_many :races, BetPlace.Racing.Race
    has_many :game_events, BetPlace.Games.GameEvent

    timestamps(type: :utc_datetime)
  end

  @fields ~w(external_id name full_name country active)a

  def changeset(course, attrs) do
    course
    |> cast(attrs, @fields)
    |> validate_required(~w(external_id name full_name country)a)
    |> unique_constraint(:external_id)
  end
end
