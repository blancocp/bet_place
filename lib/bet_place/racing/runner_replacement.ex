defmodule BetPlace.Racing.RunnerReplacement do
  use BetPlace.Schema
  import Ecto.Changeset

  schema "runner_replacements" do
    field :reason, Ecto.Enum, values: [:non_runner, :admin_withdrawal]
    field :replaced_at, :utc_datetime

    belongs_to :race, BetPlace.Racing.Race
    belongs_to :original_runner, BetPlace.Racing.Runner, foreign_key: :original_runner_id
    belongs_to :replacement_runner, BetPlace.Racing.Runner, foreign_key: :replacement_runner_id
    belongs_to :replaced_by_user, BetPlace.Accounts.User, foreign_key: :replaced_by

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required_fields ~w(race_id original_runner_id replacement_runner_id reason replaced_at)a

  def changeset(replacement, attrs) do
    replacement
    |> cast(attrs, @required_fields ++ [:replaced_by])
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:race_id)
    |> foreign_key_constraint(:original_runner_id)
    |> foreign_key_constraint(:replacement_runner_id)
  end
end
