defmodule BetPlace.Settings do
  @moduledoc """
  Contexto para configuraciones globales de la aplicación persistidas en DB.
  """

  import Ecto.Query
  alias BetPlace.Repo
  alias BetPlace.Settings.Setting

  @doc "Lee el valor de una clave. Retorna `default` si no existe."
  def get(key, default \\ nil) do
    case Repo.one(from s in Setting, where: s.key == ^key) do
      nil -> default
      %Setting{value: value} -> value
    end
  end

  @doc "Guarda o actualiza el valor de una clave."
  def put(key, value) when is_binary(value) do
    result =
      case Repo.get_by(Setting, key: key) do
        nil ->
          %Setting{}
          |> Setting.changeset(%{key: key, value: value})
          |> Repo.insert()

        setting ->
          setting
          |> Setting.changeset(%{value: value})
          |> Repo.update()
      end

    case result do
      {:ok, _} -> :ok
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc "Retorna true/false para claves booleanas."
  def get_bool(key, default \\ false) do
    get(key, to_string(default)) == "true"
  end

  @doc "Guarda un booleano como string."
  def put_bool(key, value) when is_boolean(value) do
    put(key, to_string(value))
  end
end
