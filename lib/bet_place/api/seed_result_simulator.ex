defmodule BetPlace.Api.SeedResultSimulator do
  @moduledoc """
  Applies curated race results from local seed data to simulate API sync behavior.
  """

  import Ecto.Query

  alias BetPlace.{Betting, Repo}
  alias BetPlace.Betting.Settlement
  alias BetPlace.Games.GameEventRace
  alias BetPlace.Racing

  @results_data_file Path.expand(
                       "../../../priv/repo/seeds/data/curated_results_data.exs",
                       __DIR__
                     )

  def run_today do
    today = Date.utc_today()
    payload = load_results_payload()

    summary =
      payload
      |> Map.get(:results, [])
      |> Enum.reduce(%{total: 0, applied: 0, skipped: 0}, fn row, acc ->
        acc = %{acc | total: acc.total + 1}

        case apply_race_result(today, row) do
          :ok -> %{acc | applied: acc.applied + 1}
          :skip -> %{acc | skipped: acc.skipped + 1}
        end
      end)

    Phoenix.PubSub.broadcast(
      BetPlace.PubSub,
      "sync_admin",
      {:sync_completed,
       %{kind: :seed_results, target: Date.to_string(today), result: {:ok, summary}}}
    )

    {:ok, summary}
  end

  defp load_results_payload do
    case Code.eval_file(@results_data_file) do
      {payload, _binding} when is_map(payload) -> payload
      _ -> %{results: []}
    end
  end

  defp apply_race_result(today, row) do
    race_external_id = Map.get(row, :race_external_id) || Map.get(row, "race_external_id")

    race =
      from(r in BetPlace.Racing.Race,
        where: r.external_id == ^race_external_id and r.race_date == ^today,
        limit: 1
      )
      |> Repo.one()

    if is_nil(race) do
      :skip
    else
      race_attrs = Map.get(row, :race, %{})

      {:ok, race} =
        Racing.update_race(race, %{
          status: normalize_status(Map.get(race_attrs, :status, :finished)),
          finished: Map.get(race_attrs, :finished, true),
          canceled: Map.get(race_attrs, :canceled, false),
          synced_at: DateTime.utc_now() |> DateTime.truncate(:second)
        })

      runners = Map.get(row, :runners, [])

      Enum.each(runners, fn rr ->
        program_number = Map.get(rr, :program_number)

        case Racing.get_runner_by_race_and_program_number(race.id, program_number) do
          nil ->
            :ok

          runner ->
            Racing.update_runner(runner, %{
              position: Map.get(rr, :position),
              distance_beaten: Map.get(rr, :distance_beaten),
              non_runner: Map.get(rr, :non_runner, false)
            })
        end
      end)

      post_race_sync(race)
      :ok
    end
  end

  defp post_race_sync(race) do
    event_races =
      GameEventRace
      |> where([ger], ger.race_id == ^race.id)
      |> Repo.all()

    if race.canceled do
      Enum.each(event_races, fn ger ->
        if ger.status not in [:canceled, :finished], do: Settlement.handle_canceled_race(ger.id)
      end)
    end

    if race.finished do
      Enum.each(event_races, fn ger ->
        if ger.status not in [:finished, :canceled], do: Settlement.score_race(ger.id)
      end)

      Betting.list_hvh_matchups_for_race(race.id)
      |> Enum.filter(&(&1.status in [:open, :closed]))
      |> Enum.each(&Settlement.resolve_hvh_matchup(&1.id, settlement_source: :auto_sync))
    end

    Racing.list_runners_for_race(race.id)
    |> Enum.filter(& &1.non_runner)
    |> Enum.each(fn runner ->
      Settlement.handle_non_runner(race.id, runner.program_number)
      Settlement.void_hvh_for_non_runner(race.id, runner.id)
    end)
  end

  defp normalize_status(status) when is_binary(status), do: String.to_existing_atom(status)
  defp normalize_status(status) when is_atom(status), do: status
  defp normalize_status(_), do: :finished
end
