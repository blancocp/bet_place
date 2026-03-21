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

  def list_recent_finished_game_events(limit \\ 20) when is_integer(limit) and limit > 0 do
    GameEvent
    |> where([ge], ge.status == :finished)
    |> order_by([ge], desc: ge.betting_closes_at)
    |> limit(^limit)
    |> preload([:game_type, :course])
    |> Repo.all()
  end

  def get_last_finished_game_event do
    GameEvent
    |> where([ge], ge.status == :finished)
    |> order_by([ge], desc: ge.betting_closes_at)
    |> limit(1)
    |> preload([:game_type, :course])
    |> Repo.one()
  end

  def list_open_game_events do
    GameEvent
    |> where([ge], ge.status in [:open, :closed])
    |> order_by([ge], desc: ge.betting_closes_at)
    |> preload([:game_type, :course])
    |> Repo.all()
  end

  def get_game_event!(id) do
    GameEvent
    |> preload([:game_type, :game_config, :course, game_event_races: :race])
    |> Repo.get!(id)
  end

  def create_game_event(attrs) do
    %GameEvent{} |> GameEvent.changeset(sanitize_event_attrs(attrs)) |> Repo.insert()
  end

  def update_game_event(%GameEvent{} = event, attrs) do
    event |> GameEvent.changeset(sanitize_event_attrs(attrs)) |> Repo.update()
  end

  def update_game_event_status(%GameEvent{} = event, status) do
    case event |> GameEvent.status_changeset(status) |> Repo.update() do
      {:ok, updated} ->
        Phoenix.PubSub.broadcast(
          BetPlace.PubSub,
          "game_events",
          {:game_event_status_changed, updated.id}
        )

        {:ok, updated}

      {:error, _} = err ->
        err
    end
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
    attrs = sanitize_event_attrs(attrs)

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

  def enable_dynamic_polla_window(%GameEvent{} = event) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    minutes = event.dynamic_window_minutes || 3

    update_game_event(event, %{
      dynamic_enabled_at: now,
      dynamic_closes_at: DateTime.add(now, minutes * 60, :second)
    })
  end

  def dynamic_window_open?(%GameEvent{} = event) do
    event.dynamic_polla &&
      not is_nil(event.dynamic_enabled_at) &&
      not is_nil(event.dynamic_closes_at) &&
      DateTime.compare(DateTime.utc_now(), event.dynamic_closes_at) != :gt
  end

  defp sanitize_event_attrs(attrs) when is_map(attrs) do
    game_type_id = attrs[:game_type_id] || attrs["game_type_id"]
    game_type = if game_type_id, do: Repo.get(GameType, game_type_id), else: nil
    ticket_value = attrs[:ticket_value] || attrs["ticket_value"] || Decimal.new("100.00")

    attrs
    |> Map.put(:ticket_value, ticket_value)
    |> maybe_sanitize_dynamic(game_type)
  end

  defp maybe_sanitize_dynamic(attrs, %GameType{code: :polla}), do: attrs

  defp maybe_sanitize_dynamic(attrs, _other) do
    attrs
    |> Map.put(:dynamic_polla, false)
    |> Map.put(:dynamic_window_minutes, nil)
    |> Map.put(:dynamic_enabled_at, nil)
    |> Map.put(:dynamic_closes_at, nil)
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
