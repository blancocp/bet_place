defmodule BetPlace.Racing.Jockey do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "jockeys" do
    field :name, :string

    has_many :runners, BetPlace.Racing.Runner

    timestamps(type: :utc_datetime)
  end

  def changeset(jockey, attrs) do
    jockey
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
