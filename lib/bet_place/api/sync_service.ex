defmodule BetPlace.Api.SyncService do
  @moduledoc """
  Orchestrates API syncs: racecards, race details, and results.
  Called by SyncWorker but testable independently.
  """

  require Logger

  alias BetPlace.Api.{Client, Parser}
  alias BetPlace.Api.ApiSyncLog
  alias BetPlace.Racing
  alias BetPlace.Games.GameEventRace
  alias BetPlace.Betting.Settlement
  alias BetPlace.Repo

  import Ecto.Query

  # ── Public API ────────────────────────────────────────────────────────────

  @doc "Sync racecards for a given date string (YYYY-MM-DD), then fetch each race detail."
  def sync_racecards(date) do
    Logger.info("API sync: fetching racecards for #{date}")

    case Client.fetch_racecards(date) do
      {:ok, body} when is_list(body) ->
        hash = md5(body)
        log_sync(:racecards, date, :ok, hash)

        body
        |> Parser.parse_racecards()
        |> Enum.each(fn %{course: course_attrs, race: race_attrs} ->
          with {:ok, course} <- Racing.upsert_course(course_attrs),
               {:ok, _race} <- Racing.upsert_race(Map.put(race_attrs, :course_id, course.id)) do
            :ok
          else
            {:error, reason} ->
              Logger.error(
                "Failed upserting race #{race_attrs[:external_id]}: #{inspect(reason)}"
              )
          end
        end)

        {:ok, length(body)}

      {:error, reason} ->
        log_sync(:racecards, date, :error, nil, inspect(reason))
        {:error, reason}
    end
  end

  @doc "Fetch and sync full detail for a single race by external_id."
  def sync_race_detail(external_id) do
    Logger.info("API sync: fetching race detail for #{external_id}")

    case Client.fetch_race(external_id) do
      {:ok, body} when is_map(body) ->
        hash = md5(body)
        log_sync(:race, external_id, :ok, hash)

        %{course: course_attrs, race: race_attrs, runners: runners} =
          Parser.parse_race_detail(body)

        with {:ok, course} <- Racing.upsert_course(course_attrs),
             {:ok, race} <- Racing.upsert_race(Map.put(race_attrs, :course_id, course.id)) do
          Enum.each(runners, fn runner_data ->
            upsert_runner_with_associations(race.id, runner_data)
          end)

          post_race_sync(race)
          {:ok, race}
        else
          {:error, reason} ->
            Logger.error("Failed syncing race detail #{external_id}: #{inspect(reason)}")
            {:error, reason}
        end

      {:error, reason} ->
        log_sync(:race, external_id, :error, nil, inspect(reason))
        {:error, reason}
    end
  end

  @doc "Poll results for a date. Returns :no_change if hash matches last sync."
  def sync_results(date) do
    Logger.info("API sync: polling results for #{date}")

    case Client.fetch_results(date) do
      {:ok, body} when is_list(body) ->
        hash = md5(body)

        if hash_unchanged?(:results, date, hash) do
          :no_change
        else
          log_sync(:results, date, :ok, hash)

          body
          |> Parser.parse_results()
          |> Enum.filter(fn %{race: r} -> r.finished end)
          |> Enum.each(fn %{race: %{external_id: id}} ->
            sync_race_detail(id)
          end)

          {:ok, :updated}
        end

      {:error, reason} ->
        log_sync(:results, date, :error, nil, inspect(reason))
        {:error, reason}
    end
  end

  # ── Private helpers ───────────────────────────────────────────────────────

  defp upsert_runner_with_associations(race_id, %{
         horse: horse_attrs,
         jockey_name: jockey_name,
         trainer_name: trainer_name,
         runner: runner_attrs
       }) do
    with {:ok, horse} <- Racing.upsert_horse(horse_attrs),
         {:ok, jockey} <- maybe_upsert_jockey(jockey_name),
         {:ok, trainer} <- maybe_upsert_trainer(trainer_name) do
      runner_attrs
      |> Map.merge(%{
        race_id: race_id,
        horse_id: horse.id,
        jockey_id: jockey && jockey.id,
        trainer_id: trainer && trainer.id
      })
      |> Racing.upsert_runner()
    else
      {:error, reason} ->
        Logger.error("Failed upserting runner for race #{race_id}: #{inspect(reason)}")
    end
  end

  # Called after each race detail sync to trigger scoring, settlement, and non-runner handling.
  defp post_race_sync(race) do
    event_races =
      GameEventRace
      |> where([ger], ger.race_id == ^race.id)
      |> Repo.all()

    if race.canceled do
      Enum.each(event_races, fn ger ->
        if ger.status not in [:canceled, :finished] do
          Settlement.handle_canceled_race(ger.id)
        end
      end)
    end

    if race.finished do
      Enum.each(event_races, fn ger ->
        if ger.status not in [:finished, :canceled] do
          Settlement.score_race(ger.id)
        end
      end)
    end

    # Handle any new non-runners (idempotent check)
    Racing.list_runners_for_race(race.id)
    |> Enum.filter(& &1.non_runner)
    |> Enum.each(fn runner ->
      Settlement.handle_non_runner(race.id, runner.program_number)
    end)
  end

  defp maybe_upsert_jockey(nil), do: {:ok, nil}
  defp maybe_upsert_jockey(""), do: {:ok, nil}
  defp maybe_upsert_jockey(name), do: Racing.get_or_create_jockey(name)

  defp maybe_upsert_trainer(nil), do: {:ok, nil}
  defp maybe_upsert_trainer(""), do: {:ok, nil}
  defp maybe_upsert_trainer(name), do: Racing.get_or_create_trainer(name)

  defp hash_unchanged?(endpoint, external_ref, hash) do
    endpoint_str = Atom.to_string(endpoint)

    latest_hash =
      ApiSyncLog
      |> where(
        [l],
        l.endpoint == ^endpoint_str and l.external_ref == ^external_ref and l.status == :ok
      )
      |> order_by([l], desc: l.synced_at)
      |> limit(1)
      |> select([l], l.response_hash)
      |> Repo.one()

    latest_hash == hash
  end

  defp log_sync(endpoint, external_ref, status, hash, error_message \\ nil) do
    Repo.insert(%ApiSyncLog{
      endpoint: endpoint,
      external_ref: to_string(external_ref),
      status: status,
      response_hash: hash,
      error_message: error_message,
      synced_at: DateTime.utc_now()
    })
  end

  defp md5(term) do
    :crypto.hash(:md5, :erlang.term_to_binary(term))
    |> Base.encode16(case: :lower)
  end
end
