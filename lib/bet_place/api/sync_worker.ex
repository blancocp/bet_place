defmodule BetPlace.Api.SyncWorker do
  @moduledoc """
  GenServer that periodically syncs horse racing data from the API.

  Schedule:
  - Racecards: every 30 minutes
  - Results: every 60 seconds (during race hours: 12:00–23:00 UTC)
  """

  use GenServer
  require Logger

  alias BetPlace.Api.{SyncService, SyncSettings}

  @racecards_interval :timer.minutes(30)
  @results_interval :timer.seconds(60)

  # Race hours in UTC (12:00 to 23:00)
  @race_hour_start 12
  @race_hour_end 23

  # ── Public API ────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def sync_now(type \\ :all) do
    GenServer.cast(__MODULE__, {:sync, type})
  end

  # ── GenServer callbacks ───────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    if api_key_configured?() do
      schedule_racecards()
      schedule_results()

      Logger.info(
        "SyncWorker started — racecards every 30min, results every 60s during race hours"
      )
    else
      Logger.warning("SyncWorker: RACING_API_KEY not set — sync disabled")
    end

    {:ok, %{}}
  end

  @impl true
  def handle_info(:sync_racecards, state) do
    if SyncSettings.auto_sync_enabled?() do
      today = Date.to_string(Date.utc_today())
      SyncService.sync_racecards(today)
    else
      Logger.info("SyncWorker: auto-sync disabled — skipping scheduled racecards sync")
    end

    schedule_racecards()
    {:noreply, state}
  end

  @impl true
  def handle_info(:poll_results, state) do
    if SyncSettings.auto_sync_enabled?() and within_race_hours?() do
      today = Date.to_string(Date.utc_today())
      SyncService.sync_results(today)
    end

    schedule_results()
    {:noreply, state}
  end

  @impl true
  def handle_cast({:sync, :racecards}, state) do
    today = Date.to_string(Date.utc_today())
    SyncService.sync_racecards(today)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:sync, :results}, state) do
    today = Date.to_string(Date.utc_today())
    SyncService.sync_results(today)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:sync, :all}, state) do
    today = Date.to_string(Date.utc_today())
    SyncService.sync_racecards(today)
    SyncService.sync_results(today)
    {:noreply, state}
  end

  # ── Private ───────────────────────────────────────────────────────────────

  defp schedule_racecards do
    Process.send_after(self(), :sync_racecards, @racecards_interval)
  end

  defp schedule_results do
    Process.send_after(self(), :poll_results, @results_interval)
  end

  defp within_race_hours? do
    hour = DateTime.utc_now().hour
    hour >= @race_hour_start and hour < @race_hour_end
  end

  defp api_key_configured? do
    key = Application.get_env(:bet_place, :racing_api_key)
    is_binary(key) and key != ""
  end
end
