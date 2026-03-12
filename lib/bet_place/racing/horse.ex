defmodule BetPlace.Racing.Horse do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "horses" do
    field :external_id, :string
    field :name, :string

    has_many :runners, BetPlace.Racing.Runner

    timestamps(type: :utc_datetime)
  end

  @fields ~w(external_id name)a

  def changeset(horse, attrs) do
    horse
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> unique_constraint(:external_id)
  end
end
