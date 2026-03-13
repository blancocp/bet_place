defmodule BetPlace.Games do
  @moduledoc "Context for game types, configs, events, and event races."

  import Ecto.Query
  alias BetPlace.Repo
  alias BetPlace.Games.{GameType, GameConfig, GameEvent, GameEventRace}

  # ── GameType ──────────────────────────────────────────────────────────────

  def list_game_types do
    Repo.all(from gt in GameType, where: gt.active == true)
  end

  def get_game_type!(id), do: Repo.get!(GameType, id)

  def get_game_type_by_code!(code) do
    Repo.get_by!(GameType, code: code)
  end

  def create_game_type(attrs) do
    %GameType{} |> GameType.changeset(attrs) |> Repo.insert()
  end

  # ── GameConfig ────────────────────────────────────────────────────────────

  def get_game_config!(id), do: Repo.get!(GameConfig, id)

  def get_active_config_for_game_type(game_type_id) do
    GameConfig
    |> where([gc], gc.game_type_id == ^game_type_id and gc.active == true)
    |> order_by([gc], desc: gc.inserted_at)
    |> limit(1)
    |> Repo.one()
  end

  def create_game_config(attrs) do
    %GameConfig{} |> GameConfig.changeset(attrs) |> Repo.insert()
  end

  # ── GameEvent ─────────────────────────────────────────────────────────────

  def list_game_events do
    GameEvent
    |> order_by([ge], desc: ge.inserted_at)
    |> preload([:game_type, :course])
    |> Repo.all()
  end

  def list_open_game_events do
    GameEvent
    |> where([ge], ge.status in [:open, :closed])
    |> order_by([ge], ge.betting_closes_at)
    |> preload([:game_type, :course])
    |> Repo.all()
  end

  def get_game_event!(id) do
    GameEvent
    |> preload([:game_type, :game_config, :course, game_event_races: :race])
    |> Repo.get!(id)
  end

  def create_game_event(attrs) do
    %GameEvent{} |> GameEvent.changeset(attrs) |> Repo.insert()
  end

  def update_game_event(%GameEvent{} = event, attrs) do
    event |> GameEvent.changeset(attrs) |> Repo.update()
  end

  def update_game_event_status(%GameEvent{} = event, status) do
    event |> GameEvent.status_changeset(status) |> Repo.update()
  end

  # ── GameEventRace ─────────────────────────────────────────────────────────

  def list_game_event_races(game_event_id) do
    GameEventRace
    |> where([ger], ger.game_event_id == ^game_event_id)
    |> order_by([ger], ger.race_order)
    |> preload(:race)
    |> Repo.all()
  end

  def get_game_event_race!(id), do: Repo.get!(GameEventRace, id)

  def create_game_event_race(attrs) do
    %GameEventRace{} |> GameEventRace.changeset(attrs) |> Repo.insert()
  end

  def update_game_event_race_status(%GameEventRace{} = event_race, status) do
    event_race |> GameEventRace.status_changeset(status) |> Repo.update()
  end

  # ── Game event creation with races (atomic) ───────────────────────────────

  @doc """
  Creates a game event and its 6 associated game_event_races in one transaction.
  `races` is an ordered list of Race structs (race_order 1..N).
  """
  def create_game_event_with_races(attrs, races) when length(races) >= 1 do
    betting_closes_at =
      races
      |> Enum.map(& &1.post_time)
      |> Enum.reject(&is_nil/1)
      |> Enum.min(DateTime, fn ->
        # Fallback: primera race_date disponible a las 23:59 UTC
        races
        |> Enum.map(& &1.race_date)
        |> Enum.reject(&is_nil/1)
        |> Enum.min(Date, fn -> Date.utc_today() end)
        |> DateTime.new!(~T[23:59:00], "Etc/UTC")
      end)

    event_attrs = Map.merge(attrs, %{betting_closes_at: betting_closes_at, status: :open})

    Ecto.Multi.new()
    |> Ecto.Multi.insert(:game_event, GameEvent.changeset(%GameEvent{}, event_attrs))
    |> Ecto.Multi.run(:game_event_races, fn repo, %{game_event: event} ->
      Enum.with_index(races, 1)
      |> Enum.each(fn {race, order} ->
        repo.insert!(%GameEventRace{
          game_event_id: event.id,
          race_id: race.id,
          race_order: order
        })
      end)

      {:ok, length(races)}
    end)
    |> Repo.transaction()
  end

  # ── Stats ─────────────────────────────────────────────────────────────────

  def count_game_events_by_status do
    GameEvent
    |> group_by([ge], ge.status)
    |> select([ge], {ge.status, count(ge.id)})
    |> Repo.all()
    |> Map.new()
  end
end
