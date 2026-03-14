defmodule BetPlace.Api.SyncWorker do
  @moduledoc """
  GenServer that periodically syncs horse racing data from the API.

  Schedule:
  - Racecards: every 30 minutes
  - Results: every 10 minutes (during race hours: 12:00–23:00 UTC)
  """

  use GenServer
  require Logger

  alias BetPlace.Api.{SyncService, SyncSettings}

  @racecards_interval :timer.minutes(30)
  @results_interval :timer.minutes(10)

  # Race hours in UTC (12:00 to 23:00)
  @race_hour_start 12
  @race_hour_end 23

  # ── Public API ────────────────────────────────────────────────────────────

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def sync_now(type \\ :all)

  def sync_now(type) when type in [:all, :racecards, :results] do
    today = Date.to_string(Date.utc_today())
    sync_now(type, today)
  end

  def sync_now(type, date) when is_binary(date) do
    GenServer.cast(__MODULE__, {:sync, type, date})
  end

  def sync_event(game_event_id) do
    GenServer.cast(__MODULE__, {:sync_event, game_event_id})
  end

  # ── GenServer callbacks ───────────────────────────────────────────────────

  @impl true
  def init(_opts) do
    if api_key_configured?() do
      schedule_racecards()
      schedule_results()

      Logger.info(
        "SyncWorker started — racecards every 30min, results every 10min during race hours"
      )
    else
      Logger.warning("SyncWorker: RACING_API_KEY not set — sync disabled")
    end

    {:ok, %{}}
  end

  @impl true
  def handle_info(:sync_racecards, state) do
    if SyncSettings.auto_sync_enabled?() and within_race_hours?() do
      today = Date.to_string(Date.utc_today())
      SyncService.sync_racecards(today)
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
  def handle_cast({:sync, :racecards, date}, state) do
    SyncService.sync_racecards(date)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:sync, :results, date}, state) do
    SyncService.sync_results(date)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:sync, :all, date}, state) do
    SyncService.sync_racecards(date)
    SyncService.sync_results(date)
    {:noreply, state}
  end

  @impl true
  def handle_cast({:sync_event, game_event_id}, state) do
    SyncService.sync_event_results(game_event_id)
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
