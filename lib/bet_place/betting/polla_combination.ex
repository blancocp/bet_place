defmodule BetPlace.Betting.PollaCombination do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "polla_combinations" do
    field :combination_index, :integer
    field :total_points, :integer, default: 0
    field :prize_amount, :decimal
    field :is_winner, :boolean, default: false

    belongs_to :polla_ticket, BetPlace.Betting.PollaTicket

    timestamps(type: :utc_datetime)
  end

  @required_fields ~w(polla_ticket_id combination_index)a

  def changeset(combination, attrs) do
    combination
    |> cast(attrs, @required_fields ++ [:total_points, :prize_amount, :is_winner])
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:polla_ticket_id)
  end

  def result_changeset(combination, attrs) do
    combination
    |> cast(attrs, [:total_points, :prize_amount, :is_winner])
  end
end
