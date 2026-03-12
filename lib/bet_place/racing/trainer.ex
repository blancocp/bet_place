defmodule BetPlace.Racing.Trainer do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "trainers" do
    field :name, :string

    has_many :runners, BetPlace.Racing.Runner

    timestamps(type: :utc_datetime)
  end

  def changeset(trainer, attrs) do
    trainer
    |> cast(attrs, [:name])
    |> validate_required([:name])
    |> unique_constraint(:name)
  end
end
