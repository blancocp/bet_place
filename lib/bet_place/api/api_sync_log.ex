defmodule BetPlace.Api.ApiSyncLog do
  use BetPlace.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias BetPlace.Repo

  schema "api_sync_logs" do
    field :endpoint, Ecto.Enum, values: [:racecards, :race, :results]
    field :external_ref, :string
    field :status, Ecto.Enum, values: [:ok, :error]
    field :response_hash, :string
    field :error_message, :string
    field :synced_at, :utc_datetime

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @required_fields ~w(endpoint status synced_at)a
  @optional_fields ~w(external_ref response_hash error_message)a

  def changeset(log, attrs) do
    log
    |> cast(attrs, @required_fields ++ @optional_fields)
    |> validate_required(@required_fields)
  end

  # ── Usage queries ──────────────────────────────────────────────────────────

  def requests_today do
    today = Date.utc_today()
    requests_for_date(today)
  end

  def requests_for_date(date) do
    {start_dt, end_dt} = date_range(date)

    __MODULE__
    |> where([l], l.synced_at >= ^start_dt and l.synced_at < ^end_dt)
    |> group_by([l], l.status)
    |> select([l], {l.status, count(l.id)})
    |> Repo.all()
    |> build_counts()
  end

  def requests_this_month do
    today = Date.utc_today()
    requests_for_month(today.year, today.month)
  end

  def requests_for_month(year, month) do
    start_date = Date.new!(year, month, 1)
    end_date = Date.add(start_date, Date.days_in_month(start_date))
    start_dt = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_dt = DateTime.new!(end_date, ~T[00:00:00], "Etc/UTC")

    __MODULE__
    |> where([l], l.synced_at >= ^start_dt and l.synced_at < ^end_dt)
    |> group_by([l], l.status)
    |> select([l], {l.status, count(l.id)})
    |> Repo.all()
    |> build_counts()
  end

  def daily_history(days \\ 30) do
    since = Date.utc_today() |> Date.add(-days)
    since_dt = DateTime.new!(since, ~T[00:00:00], "Etc/UTC")

    __MODULE__
    |> where([l], l.synced_at >= ^since_dt)
    |> group_by([l], [fragment("?::date", l.synced_at), l.status])
    |> select([l], {fragment("?::date", l.synced_at), l.status, count(l.id)})
    |> order_by([l], desc: fragment("?::date", l.synced_at))
    |> Repo.all()
    |> Enum.group_by(fn {date, _status, _count} -> date end)
    |> Enum.map(fn {date, entries} ->
      counts = entries |> Enum.map(fn {_, s, c} -> {s, c} end) |> build_counts()
      Map.put(counts, :date, date)
    end)
    |> Enum.sort_by(& &1.date, {:desc, Date})
  end

  def daily_history_for_month(year, month) do
    start_date = Date.new!(year, month, 1)
    end_date = Date.add(start_date, Date.days_in_month(start_date))
    start_dt = DateTime.new!(start_date, ~T[00:00:00], "Etc/UTC")
    end_dt = DateTime.new!(end_date, ~T[00:00:00], "Etc/UTC")

    __MODULE__
    |> where([l], l.synced_at >= ^start_dt and l.synced_at < ^end_dt)
    |> group_by([l], [fragment("?::date", l.synced_at), l.status, l.endpoint])
    |> select([l], {fragment("?::date", l.synced_at), l.status, l.endpoint, count(l.id)})
    |> order_by([l], desc: fragment("?::date", l.synced_at))
    |> Repo.all()
    |> Enum.group_by(fn {date, _s, _e, _c} -> date end)
    |> Enum.map(fn {date, entries} ->
      counts = entries |> Enum.map(fn {_, s, _e, c} -> {s, c} end) |> build_counts()

      by_endpoint =
        entries
        |> Enum.group_by(fn {_, _, ep, _} -> ep end)
        |> Map.new(fn {ep, ep_entries} ->
          {ep, ep_entries |> Enum.map(fn {_, _, _, c} -> c end) |> Enum.sum()}
        end)

      counts |> Map.put(:date, date) |> Map.put(:by_endpoint, by_endpoint)
    end)
    |> Enum.sort_by(& &1.date, {:desc, Date})
  end

  defp date_range(date) do
    start_dt = DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
    end_dt = DateTime.new!(Date.add(date, 1), ~T[00:00:00], "Etc/UTC")
    {start_dt, end_dt}
  end

  defp build_counts(status_counts) do
    ok = Enum.find_value(status_counts, 0, fn {s, c} -> if s == :ok, do: c end)
    error = Enum.find_value(status_counts, 0, fn {s, c} -> if s == :error, do: c end)
    %{ok: ok, error: error, total: ok + error}
  end
end
