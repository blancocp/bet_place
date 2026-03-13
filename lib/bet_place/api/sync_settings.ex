defmodule BetPlace.Api.SyncSettings do
  @moduledoc """
  Caché en memoria del flag `auto_sync_enabled`.

  - Carga el valor desde la base de datos al arrancar.
  - Persiste en DB al cambiar, para sobrevivir reinicios.
  - Los syncs automáticos del SyncWorker consultan este módulo.
  - Los syncs manuales del admin ignoran este flag.
  """

  use Agent
  require Logger

  alias BetPlace.Settings

  @key "auto_sync_enabled"

  def start_link(_opts) do
    value = Settings.get_bool(@key, false)
    Logger.info("SyncSettings: auto_sync_enabled=#{value} (cargado desde DB)")
    Agent.start_link(fn -> value end, name: __MODULE__)
  end

  def auto_sync_enabled? do
    Agent.get(__MODULE__, & &1)
  end

  def set_auto_sync(enabled) when is_boolean(enabled) do
    case Settings.put_bool(@key, enabled) do
      :ok ->
        Agent.update(__MODULE__, fn _ -> enabled end)
        Logger.info("SyncSettings: auto_sync_enabled=#{enabled} guardado en DB")
        :ok

      {:error, changeset} ->
        Logger.error("SyncSettings: error guardando en DB — #{inspect(changeset.errors)}")
        {:error, changeset}
    end
  end
end
